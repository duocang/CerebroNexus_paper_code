"""Task 2 for Vitessce (3.8.4 / JS 3.9.9). Usage: t2_vitessce.py <S1|S2> <region|attribute> [repeats]
Region: 'Select lasso' in the scatterplot -> 'My Selections' > Selection 1. Attribute: expand the hierarchy in the Cell Sets panel, three-dot menu
of the value's set > 'Export set (to JSON file)'. Region export: three-dot menu of 'My Selections' > 'Export hierarchy (to CSV file)'."""
import csv, os, sys, time
import numpy as np
from t2_common import *
S = load_sets()
sname, route = sys.argv[1], sys.argv[2]; reps = int(sys.argv[3]) if len(sys.argv) > 3 else 3
st = S[sname]; PORT = 8843
art = {"S1": os.path.join(HERE, "artifacts", "pilot_vitessce_I1"), "S2": os.path.join(HERE, "artifacts", "t1", "vit_I2")}[sname]
grp, val = {"S1": ("louvain", "B cells"), "S2": ("CTaa", st["label"].split("'")[1])}[sname]
if route == "region":
    steps = ["scatterplot shows UMAP", "calibrate data->pixel on a screenshot of the plot canvas (fit quality recorded)", "toolbar 'Select lasso'", "lasso drag along the (margin-expanded) convex hull of the target cells",
             "Cell Sets: three-dot menu of 'My Selections' > 'Export hierarchy (to CSV file)' (browser download)"]
else:
    steps = [f"Cell Sets: expand '{grp}'", f"three-dot menu of the set '{val}' > 'Export set (to JSON file)' (browser download)"]
srv = start_server(dict(cmd=[harness.PY, os.path.join(HERE, "scripts", "serve_vitessce.py"), art, str(PORT)], env=harness.py_env()), PORT)
try:
    for rep in range(1, reps + 1):
        row = dict(tool="Vitessce", set=sname, set_definition=st["label"], route=("region (lasso)" if route == "region" else "attribute (cell set)"),
                   export_route=("Cell Sets > My Selections > Export hierarchy (to CSV file)" if route == "region" else "Cell Sets > set menu > Export set (to JSON file)"), route_steps=steps, repeat=rep, status="ok")
        br = harness.BrowserRun(); pg = br.page
        try:
            pg.goto(f"http://127.0.0.1:{PORT}/"); time.sleep(8)
            if route == "region":
                el = pg.locator("canvas#deckgl-overlay-A"); box = el.bounding_box(); png = el.screenshot(); w, h = box["width"], box["height"]
                f = calib.fit_both(png, st["umap"], exclude=[(0, 0, 150, 60), (w - 150, h - 30, w, h)], dot_radius=1.5)
                row["calibration"] = {k: (round(v, 4) if isinstance(v, float) else v) for k, v in f.items()}
                tgt = np.isin(st["ids"], list(st["truth"]))
                hull = calib.expanded_hull(calib.to_pixels(f, st["umap"][tgt])); row["margin_px"] = calib.MARGIN_PX
                box2 = el.bounding_box(); pts = [(box2["x"] + x, box2["y"] + y) for x, y in hull]; row["polygon_px"] = [[round(a), round(b)] for a, b in pts]
                pg.get_by_title("Select lasso").click(); time.sleep(0.5)
                drag_polygon(pg, pts); time.sleep(3)
            else:
                # expand the hierarchy: click the triangle left of its name
                row_el = pg.get_by_text(grp, exact=True).first
                bb = row_el.bounding_box(); pg.mouse.click(bb["x"] - 18, bb["y"] + bb["height"] / 2); time.sleep(1)
                vel = pg.get_by_text(val, exact=True).first; vel.scroll_into_view_if_needed(); time.sleep(0.5); vb = vel.bounding_box()
                pg.mouse.click(vb["x"] + vb["width"] + 17, vb["y"] + vb["height"] / 2); time.sleep(1)   # three-dot menu sits right of the name
            pg.screenshot(path=os.path.join(HERE, "logs", "task2", f"vitessce_{sname}_{route}_{rep}_selection.png"))
            if route == "region":
                sel = pg.get_by_text("My Selections", exact=True).first; sb = sel.bounding_box()
                pg.mouse.click(sb["x"] + sb["width"] + 12, sb["y"] + sb["height"] / 2); time.sleep(1)
                with pg.expect_download(timeout=30000) as dl:
                    pg.get_by_text("(to CSV file)").click()
                path = os.path.join(HERE, "logs", "task2", f"vitessce_{sname}_{route}_{rep}.csv"); dl.value.save_as(path)
                rows = list(csv.DictReader(open(path, encoding="utf-8")))
                ids = [r["obsId"] for r in rows if r["groupName"] == "My Selections"]
                row["export_sets"] = sorted({r["setName"] for r in rows})
            else:
                with pg.expect_download(timeout=30000) as dl:
                    pg.get_by_text("(to JSON file)").first.click()
                path = os.path.join(HERE, "logs", "task2", f"vitessce_{sname}_{route}_{rep}.json"); dl.value.save_as(path)
                import json as _j
                j = _j.load(open(path, encoding="utf-8"))
                row["export_json_keys"] = list(j.keys()) if isinstance(j, dict) else str(type(j))
                items = j["set"] if isinstance(j, dict) and "set" in j else j
                ids = [str(x[0]) if isinstance(x, (list, tuple)) else str(x) for x in items]
            row.update(metrics(ids, st["truth"])); row["export_file"] = os.path.relpath(path, HERE)
        except Exception as e:
            row.update(status="error", error=f"{type(e).__name__}: {e}"[:400])
        finally:
            br.close()
        print(sname, route, rep, row["status"], row.get("jaccard"), row.get("n_exported"), row.get("calibration", {}).get("quality"), row.get("error", ""), flush=True)
        save_row(row, f"vitessce_{sname}_{route}_{rep}")
finally:
    stop_server(srv, PORT)
