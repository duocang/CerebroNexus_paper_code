"""Task 1 for cellxgene 1.3.0: launch on each dataset .h5ad, read /api/v0.2/schema. Usage: cellxgene.py <out dir>"""
import json, os, subprocess, sys, time, requests
HERE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
sys.path.insert(0, os.path.join(HERE, "scripts", "run"))
import harness
OUT = sys.argv[1]; os.makedirs(OUT, exist_ok=True)
FILES = {"I1": "data/raw/pbmc3k.h5ad", "I2": "data/inputs/I2.h5ad", "I3": "data/raw/visium_hne_adata.h5ad", "I4": "data/inputs/I4.h5ad"}
PORT = 8830
for ds, f in FILES.items():
    row = dict(tool="cellxgene", dataset=ds, route="cellxgene launch <h5ad>", required_args="<path to .h5ad>")
    log = os.path.join(HERE, "results", "evidence", "task1", f"cellxgene_{ds}.log")
    shot = os.path.join(HERE, "results", "evidence", "task1", f"cellxgene_{ds}.png")
    spec = harness.serve_spec("cellxgene", None, os.path.join(HERE, f), PORT)
    with open(log, "w", encoding="utf-8", errors="replace") as lf:
        p = subprocess.Popen(spec["cmd"], cwd=HERE, env=spec["env"], stdout=lf, stderr=subprocess.STDOUT)
        t0 = time.time(); schema = None
        while time.time() - t0 < 120:
            if p.poll() is not None:
                break
            try:
                r = requests.get(f"http://127.0.0.1:{PORT}/api/v0.2/schema", timeout=3)
                if r.status_code == 200:
                    schema = r.json()["schema"]; break
            except requests.RequestException:
                pass
            time.sleep(0.5)
        if schema is not None:
            row["status"] = "ok"
            sc = schema
            row["n_cells"] = sc["dataframe"]["nObs"]; row["n_genes"] = sc["dataframe"]["nVar"]
            row["embeddings"] = [l["name"] for l in sc["layout"]["obs"]]
            row["obs_columns"] = [c["name"] for c in sc["annotations"]["obs"]["columns"]]
            row["categorical_annotations"] = [c["name"] for c in sc["annotations"]["obs"]["columns"] if c["type"] == "categorical"]
            row["ctaa_column_in_metadata"] = "CTaa" in row["obs_columns"]
            row["obs_index_name"] = sc["annotations"]["obs"]["index"]
            # unique cell names as served: names come from /annotations/obs? only counted here via a column fetch
            try:
                import anndata, numpy as np
                a = anndata.read_h5ad(os.path.join(HERE, f), backed="r")
                row["unique_cell_names_in_file"] = bool(a.obs_names.is_unique)
            except Exception as e:
                row["unique_cell_names_in_file"] = None
            try:
                br = harness.BrowserRun(); br.page.goto(f"http://127.0.0.1:{PORT}/"); time.sleep(8); br.page.screenshot(path=shot)
                row["screenshot"] = os.path.relpath(shot, HERE); br.close()
            except Exception as e:
                row["screenshot_error"] = str(e)[:200]
        else:
            row["status"] = "error" if p.poll() is not None else "timeout"
        harness.kill_tree(p)
    txt = open(log, encoding="utf-8", errors="replace").read()
    lines = [l for l in txt.splitlines() if "rror" in l or "Exception" in l]
    row["error_message"] = ("\n".join(lines))[-500:] if row["status"] != "ok" else None
    row["warnings"] = [l[:160] for l in txt.splitlines() if "Warning" in l][:6]
    json.dump(row, open(os.path.join(OUT, f"cellxgene_{ds}.json"), "w"), indent=1)
    print(ds, row["status"], row.get("n_cells"), row.get("embeddings"), (row.get("error_message") or "")[:200], flush=True)
    for _ in range(30):
        if harness.port_free(PORT): break
        time.sleep(0.3)
