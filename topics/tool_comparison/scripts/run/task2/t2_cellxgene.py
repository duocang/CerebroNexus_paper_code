"""Task 2 for cellxgene 1.3.0. Usage: t2_cellxgene.py <S1|S2> <region|attribute> [repeats]
Export route: Create new category -> add a label -> 'Add label & assign N cells' writes the annotation CSV on the server
(<user-generated-data-dir>/<name>-cell-labels-<ID>.csv); the cell IDs of the label are read from that file. cellxgene 1.3.0 has no
browser download of a selection. Launch flags: those of PROTOCOL 7.2 plus --user-generated-data-dir (D8)."""
import glob, os, sys, time
import numpy as np, pandas as pd
from t2_common import *
S = load_sets()
sname, route = sys.argv[1], sys.argv[2]; reps = int(sys.argv[3]) if len(sys.argv) > 3 else 3
st = S[sname]; PORT = 8842
h5 = {"S1": "data/raw/pbmc3k.h5ad", "S2": "data/inputs/I2.h5ad"}[sname]
col = {"S1": ("louvain", "B cells"), "S2": ("CTaa", st["label"].split("'")[1])}[sname]
UGD = os.path.join(HERE, "data", "builds", "t2", "cx_ugd")
if route == "region":
    steps = ["lasso tool", "calibrate data->pixel on a screenshot of the canvas (fit quality recorded)", "lasso drag along the (margin-expanded) convex hull of the target cells",
             "name the user generated data directory (dialog)", "Create new category 'sel'", "'+' add label 'S' and 'Add label & assign N cells'", "read the cell IDs of label S from the annotation CSV the server wrote"]
else:
    steps = ["name the user generated data directory (dialog)", f"in category '{col[0]}' untick all values, tick the target value (selects the cells)",
             "Create new category 'sel'", "'+' add label 'S' and 'Add label & assign N cells'", "read the cell IDs of label S from the annotation CSV"]
for rep in range(1, reps + 1):
    row = dict(tool="cellxgene", set=sname, set_definition=st["label"], route=("region (lasso)" if route == "region" else "attribute (category value)"),
               export_route="annotation CSV written by the server (no browser download in 1.3.0)", route_steps=steps, repeat=rep, status="ok")
    before = set(glob.glob(os.path.join(UGD, "*.csv")))
    srv = start_server(dict(cmd=[os.path.join(HERE, "env", "py", "Scripts", "cellxgene.exe"), "launch", os.path.join(HERE, h5), "--host", "127.0.0.1", "--port", str(PORT),
                                 "--disable-gene-sets-save", "--user-generated-data-dir", UGD], env=harness.cellxgene_env()), PORT)
    br = harness.BrowserRun(); pg = br.page
    try:
        pg.goto(f"http://127.0.0.1:{PORT}/"); time.sleep(6)
        if pg.locator(".bp3-dialog input").count():
            pg.locator(".bp3-dialog input").first.click(); pg.keyboard.type("t2", delay=60); time.sleep(0.5)
            pg.get_by_role("button", name="Create user generated data directory").click(); time.sleep(3)
        if route == "region":
            pg.locator("[data-testid='mode-lasso']").click()
            el = pg.locator("canvas.graph-canvas"); box = el.bounding_box()
            png = el.screenshot(); w, h = box["width"], box["height"]
            excl = [(w - 460, 0, w, 55), (0, h - 45, 260, h), (w - 130, h - 40, w, h)]
            f = calib.fit_both(png, st["umap"], exclude=excl, dot_radius=3)
            row["calibration"] = {k: (round(v, 4) if isinstance(v, float) else v) for k, v in f.items()}
            tgt = np.isin(st["ids"], list(st["truth"]))
            hull = calib.expanded_hull(calib.to_pixels(f, st["umap"][tgt])); row["margin_px"] = calib.MARGIN_PX
            box2 = el.bounding_box(); pts = [(box2["x"] + x, box2["y"] + y) for x, y in hull]; row["polygon_px"] = [[round(a), round(b)] for a, b in pts]
            drag_polygon(pg, pts); time.sleep(2)
        else:
            cname, val = col
            pg.locator(f"[data-testid='{cname}:category-expand']").click(); time.sleep(1)
            pg.locator(f"[data-testid='{cname}:category-select']").click(force=True); time.sleep(1)
            pg.locator(f"[data-testid='categorical-value-select-{cname}-{val}']").click(force=True); time.sleep(2)
        row["ui_selected_text"] = pg.evaluate("() => (document.body.innerText.match(/umap: [0-9,]+ out of [0-9,]+ cells/) || [null])[0]")
        pg.screenshot(path=os.path.join(HERE, "results", "evidence", "task2", f"cellxgene_{sname}_{route}_{rep}_selection.png"))
        pg.locator("[data-testid='open-annotation-dialog']").click(); time.sleep(1)
        pg.locator(".bp3-dialog input").first.click(); pg.keyboard.type("sel", delay=40)
        pg.get_by_role("button", name="Create new category").last.click(); time.sleep(2)
        pg.locator("[data-testid='sel:add-new-label-to-category']").click(); time.sleep(1)
        pg.keyboard.type("S", delay=40); time.sleep(0.5)
        pg.get_by_role("button", name="Add label & assign").click(); time.sleep(3)
        files = sorted(set(glob.glob(os.path.join(UGD, "*.csv"))) - before, key=os.path.getmtime)
        if not files: raise RuntimeError("no annotation CSV written")
        df = pd.read_csv(files[-1], comment="#")
        exported = df.loc[df["sel"] == "S", "index"].astype(str).tolist()
        row.update(metrics(exported, st["truth"])); row["export_file"] = os.path.relpath(files[-1], HERE)
    except Exception as e:
        row.update(status="error", error=f"{type(e).__name__}: {e}"[:400])
    finally:
        br.close(); stop_server(srv, PORT)
    print(sname, route, rep, row["status"], row.get("jaccard"), row.get("n_exported"), row.get("calibration", {}).get("quality"), row.get("error", ""), flush=True)
    save_row(row, f"cellxgene_{sname}_{route}_{rep}")
