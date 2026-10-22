"""Task 2 for CerebroNexus: Projection tab -> lasso -> 'Table of selected cells' -> page length 1,000 -> Download -> CSV.
Usage: t2_cerebronexus.py <S1|S2> [repeats]"""
import io, os, sys, time, csv
import numpy as np
from t2_common import *
S = load_sets()
sname = sys.argv[1]; reps = int(sys.argv[2]) if len(sys.argv) > 2 else 3
st = S[sname]; PORT = 8841
crb = {"S1": os.path.join(HERE, "artifacts", "pilot_cerebronexus_default_I1", "cerebro_pbmc3k.crb"),
       "S2": os.path.join(HERE, "artifacts", "t1", "cn_I2_seurat", "I2_seurat.crb")}[sname]
proj = {"S1": "UMAP", "S2": "umap"}[sname]
srv = start_server(harness.R("cerebronexus_serve.R", crb, PORT, "embedded"), PORT)
steps = ["open Projection tab", f"set Projection = {proj}", "calibrate data->pixel on a screenshot of the plot (fit quality recorded)",
         "lasso drag along the convex hull of the target cells", "scroll to 'Table of selected cells', set 'Show' = 1,000 entries", "Download > CSV (browser download)"]
try:
    for rep in range(1, reps + 1):
        row = dict(tool="CerebroNexus", set=sname, set_definition=st["label"], route="region (lasso)", export_route="Table of selected cells > Download > CSV",
                   route_steps=steps, repeat=rep, status="ok")
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
            png = el.screenshot(); w = box["width"]
            f = calib.fit_both(png, st["umap"], exclude=[(w - 230, 0, w, 40)], dot_radius=3)
            row["calibration"] = {k: (round(v, 4) if isinstance(v, float) else v) for k, v in f.items()}
            tgt = np.isin(st["ids"], list(st["truth"]))
            hull = calib.expanded_hull(calib.to_pixels(f, st["umap"][tgt])); row["margin_px"] = calib.MARGIN_PX
            box2 = el.bounding_box(); row["box_at_calibration"] = box; row["box_at_drag"] = box2
            pts = [(box2["x"] + x, box2["y"] + y) for x, y in hull]
            drag_polygon(pg, pts); time.sleep(3)
            pg.screenshot(path=os.path.join(HERE, "logs", "task2", f"cerebronexus_{sname}_{rep}_selection.png")); row["polygon_px"] = [[round(a), round(b)] for a, b in pts]
            row["ui_selected_text"] = pg.evaluate("() => { const t = document.body.innerText; const m = t.match(/Selected [0-9,]+ \/ [0-9,]+ cells/); return m ? m[0] : null }")
            sel = pg.locator("select[name$='_length']").last
            sel.scroll_into_view_if_needed(); sel.select_option("1000"); time.sleep(2)
            pg.get_by_text("Download", exact=True).first.click(); time.sleep(1)
            with pg.expect_download(timeout=30000) as dl:
                pg.locator(".dropdown-menu a:has-text('CSV'), a:has-text('CSV')").first.click()
            path = os.path.join(HERE, "logs", "task2", f"cerebronexus_{sname}_{rep}.csv"); os.makedirs(os.path.dirname(path), exist_ok=True)
            dl.value.save_as(path)
            rows = list(csv.DictReader(open(path, encoding="utf-8")))
            col = "cell_barcode" if "cell_barcode" in rows[0] else list(rows[0].keys())[0]
            exported = [r[col] for r in rows]
            row.update(metrics(exported, st["truth"])); row["export_file"] = os.path.relpath(path, HERE)
            pg.screenshot(path=os.path.join(HERE, "logs", "task2", f"cerebronexus_{sname}_{rep}.png"))
        except Exception as e:
            row.update(status="error", error=f"{type(e).__name__}: {e}"[:400])
        finally:
            br.close()
        print(sname, rep, row["status"], row.get("jaccard"), row.get("n_exported"), row.get("calibration", {}).get("quality"), row.get("error", ""), flush=True)
        save_row(row, f"cerebronexus_{sname}_region_{rep}")
finally:
    stop_server(srv, PORT)
