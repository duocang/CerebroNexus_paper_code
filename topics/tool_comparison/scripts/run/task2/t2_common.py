"""Shared pieces of the Task 2 drivers (PROTOCOL 6)."""
import json, os, subprocess, sys, time
import numpy as np
import anndata as ad
HERE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
sys.path.insert(0, os.path.join(HERE, "scripts", "run")); sys.path.insert(0, os.path.join(HERE, "scripts", "run", "task2"))
import harness, calib
import warnings; warnings.filterwarnings("ignore")


def load_sets():
    """Truth sets and the UMAP coordinates of their datasets."""
    a1 = ad.read_h5ad(os.path.join(HERE, "data", "raw", "pbmc3k.h5ad"))
    a2 = ad.read_h5ad(os.path.join(HERE, "data", "inputs", "I2.h5ad"))
    s1 = set(a1.obs_names[a1.obs["louvain"].astype(str) == "B cells"])
    vc = a2.obs["CTaa"].dropna().astype(str).value_counts()
    top = sorted(vc[vc == vc.max()].index)[0]
    s2 = set(a2.obs_names[a2.obs["CTaa"].astype(str) == top])
    return {
        "S1": dict(dataset="I1", truth=s1, ids=np.array(a1.obs_names), umap=np.asarray(a1.obsm["X_umap"], float), label="louvain == 'B cells'"),
        "S2": dict(dataset="I2", truth=s2, ids=np.array(a2.obs_names), umap=np.asarray(a2.obsm["X_umap"], float), label=f"CTaa == '{top}'"),
    }


def metrics(exported, truth):
    e, t = set(exported), set(truth)
    inter = len(e & t)
    return dict(n_exported=len(e), n_truth=len(t), n_intersection=inter, jaccard=inter / len(e | t) if (e | t) else None,
                precision=inter / len(e) if e else None, recall=inter / len(t) if t else None)


def start_server(spec, port, timeout=120):
    import requests
    p = subprocess.Popen(spec["cmd"], cwd=HERE, env=spec["env"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    t0 = time.time()
    while time.time() - t0 < timeout:
        try:
            if requests.get(f"http://127.0.0.1:{port}/", timeout=2).status_code == 200:
                return p
        except Exception:
            pass
        time.sleep(0.3)
    harness.kill_tree(p)
    raise RuntimeError("server did not start")


def stop_server(p, port):
    harness.kill_tree(p)
    for _ in range(50):
        if harness.port_free(port):
            break
        time.sleep(0.2)


def drag_polygon(page, pts, steps=6):
    page.mouse.move(*pts[0]); page.mouse.down()
    for q in list(pts[1:]) + [pts[0]]:
        page.mouse.move(*q, steps=steps)
    page.mouse.up()


def save_row(row, name):
    d = os.path.join(HERE, "results", "task2"); os.makedirs(d, exist_ok=True)
    json.dump(row, open(os.path.join(d, name + ".json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False, default=str)
