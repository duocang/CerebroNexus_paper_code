"""Task 2 for iSEE 2.22.0. Usage: t2_isee.py <S1|S2> <region|region-box|attribute> [repeats]
Region: lasso on 'Reduced dimension plot 1' (Shift+click waypoints, Shift+click on the first point closes it); region-box: rectangular brush; 'Column data table 1' receives the plot selection
(Selection parameters) and then lists only the selected cells. Attribute: column filter of 'Column data table 1' (DataTables search on the column).
Export: top bar Export > 'Download panel output' > tick 'Column data table 1' > Download (browser download)."""
import glob, io, os, re, sys, time, zipfile
import numpy as np, pandas as pd
from t2_common import *
S = load_sets()
sname, route = sys.argv[1], sys.argv[2]; reps = int(sys.argv[3]) if len(sys.argv) > 3 else 3
st = S[sname]; PORT = 8845
rds = {"S1": os.path.join(HERE, "artifacts", "pilot_isee_I1", "sce.rds"), "S2": os.path.join(HERE, "artifacts", "t1", "ui_isee_I2_sce_orig_w0", "sce.rds")}[sname]
emb = {"S1": "X_umap", "S2": "UMAP"}[sname]
colname, val = {"S1": ("louvain", "B cells"), "S2": ("CTaa", st["label"].split("'")[1])}[sname]
common = ["Export > Download panel output > tick 'Column data table 1' > Download (browser download)"]
steps = (["Data parameters of 'Reduced dimension plot 1': embedding = " + emb, "calibrate data->pixel on a screenshot of the plot (fit quality recorded)", ("Shift+click the vertices of the margin-expanded convex hull of the target cells, Shift+click the first vertex to close" if route == "region" else "brush (rectangle) over the margin-expanded bounding box of the target cells"),
          "Selection parameters of 'Column data table 1': column selection source = Reduced dimension plot 1"] if route.startswith("region") else
         [f"'Column data table 1': column filter on '{colname}' = '{val}'"]) + common
srv = start_server(harness.R("isee_serve.R", rds, PORT), PORT, timeout=180)
try:
    for rep in range(1, reps + 1):
        row = dict(tool="iSEE", set=sname, set_definition=st["label"], route={"region": "region (lasso, Shift+click waypoints)", "region-box": "region (box brush)", "attribute": "attribute (table column filter)"}[route],
                   export_route="Export > Download panel output (table CSV)", route_steps=steps, repeat=rep, status="ok")
        br = harness.BrowserRun(); pg = br.page
        try:
            pg.goto(f"http://127.0.0.1:{PORT}/"); time.sleep(10)
            if route.startswith("region"):
                pg.evaluate(f"() => document.getElementById('ReducedDimensionPlot1_Type').selectize.setValue('{emb}')"); time.sleep(3)
                el = pg.locator("#ReducedDimensionPlot1"); box = el.bounding_box(); png = el.screenshot(); w, h = box["width"], box["height"]
                excl = [(0, 0, 54, h), (w - 18, 0, w, h), (0, 0, w, 28), (0, h - 36, w, h)]   # axes, labels, title: only the panel interior is used
                f = calib.fit_both(png, st["umap"], exclude=excl, dot_radius=1.5, thr=70)
                row["calibration"] = {k: (round(v, 4) if isinstance(v, float) else v) for k, v in f.items()}
                tgt = np.isin(st["ids"], list(st["truth"]))
                box2 = el.bounding_box()
                pix = calib.to_pixels(f, st["umap"][tgt]); row["margin_px"] = calib.MARGIN_PX
                if route == "region":
                    hull = calib.expanded_hull(pix, n_angles=8); row["polygon_px"] = [[round(a), round(b)] for a, b in hull]; row["n_vertices"] = len(hull)
                    for (x, y) in list(hull) + [hull[0]]:
                        pg.keyboard.down("Shift"); pg.mouse.click(box2["x"] + x, box2["y"] + y); pg.keyboard.up("Shift"); time.sleep(0.5)
                    time.sleep(3)
                else:
                    bb = calib.expanded_bbox(pix); (x0, y0), (x1, _), (_, y1) = bb[0], bb[1], bb[2]
                    row["bbox_px"] = [round(x0), round(y0), round(x1), round(y1)]
                    pg.mouse.move(box2["x"] + x0, box2["y"] + y0); pg.mouse.down(); pg.mouse.move(box2["x"] + x1, box2["y"] + y1, steps=10); pg.mouse.up(); time.sleep(3)
                row["ui_selected_text"] = (re.findall(r"[0-9,]+ of [0-9,]+ columns in active selection.*", pg.evaluate("() => document.body.innerText")) or [None])[0]
                pg.screenshot(path=os.path.join(HERE, "logs", "task2", f"isee_{sname}_{route}_{rep}_selection.png"))
                pg.evaluate("() => document.getElementById('ColumnDataTable1_ColumnSelectionSource').selectize.setValue('ReducedDimensionPlot1')"); time.sleep(3)
            else:
                idx = pg.evaluate(f"() => {{ const t = $('#ColumnDataTable1 table').DataTable(); return t.columns().header().toArray().map(h => h.innerText.trim()).indexOf('{colname}') }}")
                row["filter_column_index"] = idx
                # DT factor columns take their filter as a JSON array of levels; free-text columns take a regular expression
                is_factor = pg.evaluate("(i) => $('#ColumnDataTable1 .dataTables_scrollHead, #ColumnDataTable1').find('thead select, thead .selectized').length > 0", idx)
                if colname == "louvain":
                    pg.evaluate("([i, v]) => { const t = $('#ColumnDataTable1 table').DataTable(); t.column(i).search('[\"' + v + '\"]', true, false, false).draw() }", [idx, val])
                else:
                    pg.evaluate("([i, v]) => { const t = $('#ColumnDataTable1 table').DataTable(); t.column(i).search('^' + v + '$', true, false, false).draw() }", [idx, val])
                time.sleep(3)
                row["ui_rows_text"] = (re.findall(r"Showing.*", pg.evaluate("() => document.querySelector('#ColumnDataTable1').innerText")) or [None])[0]
            pg.evaluate("() => document.getElementById('iSEE_INTERNAL_export_content').click()"); time.sleep(2)
            pg.get_by_role("button", name="Select none").click(); time.sleep(0.5)
            pg.locator(".modal-content").get_by_text("Column data table 1", exact=True).click(); time.sleep(0.5)
            with pg.expect_download(timeout=60000) as dl:
                pg.locator(".modal-content").get_by_role("link", name="Download").click() if pg.locator(".modal-content a:has-text('Download')").count() else pg.locator(".modal-content").get_by_role("button", name="Download").click()
            path = os.path.join(HERE, "logs", "task2", f"isee_{sname}_{route}_{rep}_{dl.value.suggested_filename}"); dl.value.save_as(path)
            row["export_file"] = os.path.relpath(path, HERE)
            if path.endswith(".zip"):
                z = zipfile.ZipFile(path); names = z.namelist(); row["zip_members"] = names
                csvn = [n for n in names if n.lower().endswith(".csv")][0]
                df = pd.read_csv(z.open(csvn), index_col=0)
            else:
                df = pd.read_csv(path, index_col=0)
            exported = df.index.astype(str).tolist()
            row.update(metrics(exported, st["truth"]))
        except Exception as e:
            row.update(status="error", error=f"{type(e).__name__}: {e}"[:400])
        finally:
            br.close()
        print(sname, route, rep, row["status"], row.get("jaccard"), row.get("n_exported"), row.get("calibration", {}).get("quality"), row.get("error", ""), flush=True)
        save_row(row, f"isee_{sname}_{route}_{rep}")
finally:
    stop_server(srv, PORT)
