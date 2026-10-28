"""Task 2 for CerebroNexus.
Usage: t2_cerebronexus.py <S1|S2> [repeats] [region|attribute]      (route defaults to region)

region:    Projection tab -> lasso along the margin-expanded hull of the target cells -> 'Table of selected cells' -> page length 1,000 -> Download -> CSV.
attribute: Projection tab -> Settings -> Group filters: keep only the target value (All off, target on) -> lasso around the whole plot area (inset 2 px) ->
           same table export. In CerebroNexus 6.0.0 a cell removed by a group filter is inactive and not selectable (cell_views.js, activeCell()), so the
           filter, not the outline, decides which cells are selected. Rows go to results/task2/cerebronexus_<set>_attribute_<rep>.json.
"""
import io, os, sys, time, csv
import numpy as np
from t2_common import *
S = load_sets()
sname = sys.argv[1]; reps = int(sys.argv[2]) if len(sys.argv) > 2 else 3
route = sys.argv[3] if len(sys.argv) > 3 else "region"
assert route in ("region", "region-box", "attribute")
st = S[sname]; PORT = 8841
crb = {"S1": os.path.join(HERE, "data", "builds", "pilot_cerebronexus_default_I1", "cerebro_pbmc3k.crb"),
       "S2": os.path.join(HERE, "data", "builds", "t1", "cn_I2_seurat", "I2_seurat.crb")}[sname]
proj = {"S1": "UMAP", "S2": "umap"}[sname]
group, level = {"S1": ("louvain", "B cells"), "S2": ("CTaa", st["label"].split("'")[1])}[sname]
tag = {"region": "", "region-box": "box_", "attribute": "attribute_"}[route]          # region file names are unchanged from the first run
common = ["lasso", "scroll to 'Table of selected cells', set 'Show' = 1,000 entries", "Download > CSV (browser download)"]
if route in ("region", "region-box"):
    steps = ["open Projection tab", f"set Projection = {proj}", "calibrate data->pixel on a screenshot of the plot (fit quality recorded)",
             ("lasso drag along the convex hull of the target cells" if route == "region" else "toolbar: Box select, then drag the margin-expanded bounding box of the target cells"), *common[1:]]
else:
    steps = ["open Projection tab", f"set Projection = {proj}", "Settings > Group filters", f"open the '{group}' filter, click None, tick '{level}' only, close Settings",
             "lasso drag around the whole plot area, inset 2 px from the canvas edge (the filter decides which cells can be selected)", *common[1:]]
srv = start_server(harness.R("cerebronexus_serve.R", crb, PORT, "embedded"), PORT)
logdir = os.path.join(HERE, "results", "evidence", "task2"); os.makedirs(logdir, exist_ok=True)
try:
    for rep in range(1, reps + 1):
        row = dict(tool="CerebroNexus", set=sname, set_definition=st["label"],
                   route={"region": "region (lasso)", "region-box": "region (box select)", "attribute": "attribute (group filter + lasso)"}[route],
                   export_route="Table of selected cells > Download > CSV", route_steps=steps, repeat=rep, status="ok")
        br = harness.BrowserRun(); pg = br.page
        try:
            pg.goto(f"http://127.0.0.1:{PORT}/"); time.sleep(4)
            pg.get_by_text("Projection", exact=True).first.click(); time.sleep(3)
            pg.evaluate(f"() => document.getElementById('overview_projection_to_display').selectize.setValue('{proj}')"); time.sleep(3)
            el = pg.locator("#cv-cv-a"); box = el.bounding_box()
            for _ in range(20):   # wait for the layout to settle (a banner appears after switching projection)
                time.sleep(0.5); b2 = el.bounding_box()
                if b2 == box: break
                box = b2
            if route in ("region", "region-box"):
                png = el.screenshot(); w = box["width"]
                f = calib.fit_both(png, st["umap"], exclude=[(w - 230, 0, w, 40)], dot_radius=3)
                row["calibration"] = {k: (round(v, 4) if isinstance(v, float) else v) for k, v in f.items()}
                tgt = np.isin(st["ids"], list(st["truth"]))
                pix = calib.to_pixels(f, st["umap"][tgt]); hull = calib.expanded_hull(pix) if route == "region" else calib.expanded_bbox(pix); row["margin_px"] = calib.MARGIN_PX
                box2 = el.bounding_box(); row["box_at_calibration"] = box; row["box_at_drag"] = box2
                pts = [(box2["x"] + x, box2["y"] + y) for x, y in hull]
            else:
                pg.locator("button:has-text('Settings')").first.click(); time.sleep(2)
                offered = pg.evaluate("() => [...document.querySelectorAll('.cv-filt-btn')].filter(b => b.offsetParent !== null).map(b => b.querySelector('span').textContent.trim() + ' ' + b.querySelector('.cv-filt-ct').textContent.trim())")
                row["group_filters_offered"] = offered
                if not any(o.split(" ")[0] == group for o in offered):
                    pg.screenshot(path=os.path.join(logdir, f"cerebronexus_{sname}_attribute_{rep}_groupfilters.png"))
                    row.update(status="route not found", error=f"the Group filters offer only: {offered}; '{group}' is not a registered grouping variable of this CRB")
                    raise StopIteration
                pg.locator(".cv-filt-btn", has_text=group).first.click(); time.sleep(1)
                pg.locator(".cerebro-group-filters button:has-text('None')").first.click(); time.sleep(1)
                pg.locator(f"input[name='overview_projection_group_filter_{group}'][value='{level}']").first.click(force=True); time.sleep(2)
                row["group_filter_values_set"] = pg.evaluate(f"() => [...document.querySelectorAll(\"input[name='overview_projection_group_filter_{group}']\")].filter(i => i.checked).map(i => i.value)")
                pg.screenshot(path=os.path.join(logdir, f"cerebronexus_{sname}_attribute_{rep}_groupfilters.png"))
                pg.locator("button.cerebro-settings-close:visible").first.click(); time.sleep(2)
                for _ in range(20):
                    time.sleep(0.5); b2 = el.bounding_box()
                    if b2 == box: break
                    box = b2
                box2 = el.bounding_box(); row["box_at_drag"] = box2
                x0, y0, x1, y1 = box2["x"] + 2, box2["y"] + 2, box2["x"] + box2["width"] - 2, box2["y"] + box2["height"] - 2
                pts = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
                row["inset_px"] = 2
            if route == "region-box":
                el.hover(); time.sleep(0.5); pg.locator("button.cv-tbtn[data-act='box']").first.click(force=True); time.sleep(1)
                (bx0, by0), (bx1, by1) = pts[0], pts[2]
                pg.mouse.move(bx0, by0); pg.mouse.down(); pg.mouse.move(bx1, by1, steps=12); pg.mouse.up()
            else:
                drag_polygon(pg, pts)
            time.sleep(3)
            pg.screenshot(path=os.path.join(logdir, f"cerebronexus_{sname}_{tag}{rep}_selection.png")); row["polygon_px"] = [[round(a), round(b)] for a, b in pts]
            row["ui_selected_text"] = pg.evaluate("() => { const t = document.body.innerText; const m = t.match(/Selected [0-9,]+ \/ [0-9,]+ cells/); return m ? m[0] : null }")
            sel = pg.locator("select[name$='_length']").last
            sel.scroll_into_view_if_needed(); sel.select_option("1000"); time.sleep(2)
            pg.get_by_text("Download", exact=True).first.click(); time.sleep(1)
            with pg.expect_download(timeout=30000) as dl:
                pg.locator(".dropdown-menu a:has-text('CSV'), a:has-text('CSV')").first.click()
            path = os.path.join(logdir, f"cerebronexus_{sname}_{tag}{rep}.csv")
            dl.value.save_as(path)
            rows = list(csv.DictReader(open(path, encoding="utf-8")))
            col = "cell_barcode" if "cell_barcode" in rows[0] else list(rows[0].keys())[0]
            exported = [r[col] for r in rows]
            row.update(metrics(exported, st["truth"])); row["export_file"] = os.path.relpath(path, HERE)
            pg.screenshot(path=os.path.join(logdir, f"cerebronexus_{sname}_{tag}{rep}.png"))
        except StopIteration:
            pass
        except Exception as e:
            row.update(status="error", error=f"{type(e).__name__}: {e}"[:400])
        finally:
            br.close()
        print(sname, route, rep, row["status"], row.get("jaccard"), row.get("n_exported"), row.get("ui_selected_text"), row.get("error", ""), flush=True)
        save_row(row, f"cerebronexus_{sname}_{route}_{rep}")
finally:
    stop_server(srv, PORT)
