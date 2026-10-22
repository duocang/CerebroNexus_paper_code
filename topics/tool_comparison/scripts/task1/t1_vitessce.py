"""Task 1 for Vitessce (python 3.8.4, JS 3.9.9). Usage: vitessce.py <out dir>
Route: .h5ad -> Zarr (optimize_adata) -> VitessceConfig/AnnDataWrapper with every component path written by hand
(that is the capability finding: paths are never inferred) -> page served on one origin -> read what the page shows."""
import json, os, sys, time, importlib.util, warnings, subprocess
warnings.filterwarnings("ignore")
HERE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(HERE, "scripts")); import harness
import anndata as ad, numpy as np, vitessce
from vitessce import VitessceConfig, ViewType as vt, CoordinationType as ct, AnnDataWrapper
OUT = sys.argv[1]
spec = importlib.util.spec_from_file_location("vu", os.path.join(os.path.dirname(vitessce.__file__), "data_utils", "anndata.py"))
du = importlib.util.module_from_spec(spec); spec.loader.exec_module(du)
FILES = {"I1": "data/pbmc3k.h5ad", "I2": "inputs/I2.h5ad", "I3": "data/visium_hne_adata.h5ad", "I4": "inputs/I4.h5ad"}
CLUSTER = {"I1": "louvain", "I2": "seurat_clusters", "I3": "cluster", "I4": "louvain"}
PORT = 8831
for ds, f in FILES.items():
    row = dict(tool="Vitessce", dataset=ds, route="optimize_adata -> write_zarr -> AnnDataWrapper (paths by hand)", workaround=False)
    paths_by_hand = []
    art = os.path.join(HERE, "artifacts", "t1", f"vit_{ds}"); os.makedirs(art, exist_ok=True)
    try:
        a = ad.read_h5ad(os.path.join(HERE, f))
        row["n_cells"], row["n_genes"] = a.n_obs, a.n_vars
        row["unique_cell_names"] = bool(a.obs_names.is_unique)
        row["obsm_keys_in_file"] = list(a.obsm.keys())
        embs = [k for k in a.obsm.keys() if k in ("X_umap", "X_tsne", "X_pca", "X_draw_graph_fr", "spatial") and a.obsm[k].shape[1] >= 2]
        a2 = du.optimize_adata(a, obs_cols=[CLUSTER[ds]] + (["CTaa"] if "CTaa" in a.obs else []), obsm_keys=embs, optimize_X=False)
        zp = os.path.join(art, "data.zarr")
        import shutil; shutil.rmtree(zp, ignore_errors=True)
        a2.write_zarr(zp)
        opts = {"obsEmbedding": [{"path": f"obsm/{k}", "dims": [0, 1], "embeddingType": k.replace("X_", "").upper()} for k in embs],
                "obsSets": [{"name": CLUSTER[ds], "path": f"obs/{CLUSTER[ds]}"}], "obsFeatureMatrix": {"path": "X"}}
        paths_by_hand = [o["path"] for o in opts["obsEmbedding"]] + [o["path"] for o in opts["obsSets"]] + ["X"]
        if "CTaa" in a.obs:
            opts["obsSets"].append({"name": "CTaa", "path": "obs/CTaa"}); paths_by_hand.append("obs/CTaa")
        vc = VitessceConfig(schema_version="1.0.17", name="t1")
        w = AnnDataWrapper(adata_url="__ORIGIN__/data.zarr", obs_embedding_paths=[o["path"] for o in opts["obsEmbedding"]],
                           obs_embedding_names=[o["embeddingType"] for o in opts["obsEmbedding"]],
                           obs_set_paths=[o["path"] for o in opts["obsSets"]], obs_set_names=[o["name"] for o in opts["obsSets"]],
                           obs_feature_matrix_path="X")
        if ds == "I3":   # spatial variant: spots from obsm/spatial, again written by hand
            w = AnnDataWrapper(adata_url="__ORIGIN__/data.zarr", obs_embedding_paths=[o["path"] for o in opts["obsEmbedding"] if "spatial" not in o["path"]],
                               obs_embedding_names=[o["embeddingType"] for o in opts["obsEmbedding"] if "spatial" not in o["path"]],
                               obs_spots_path="obsm/spatial", obs_set_paths=[o["path"] for o in opts["obsSets"]], obs_set_names=[o["name"] for o in opts["obsSets"]],
                               obs_feature_matrix_path="X")
            paths_by_hand.append("obsm/spatial (obs_spots_path)")
        d = vc.add_dataset(name="d").add_object(w)
        sc = vc.add_view(vt.SCATTERPLOT, dataset=d, mapping=opts["obsEmbedding"][0]["embeddingType"]); st = vc.add_view(vt.OBS_SETS, dataset=d); ft = vc.add_view(vt.FEATURE_LIST, dataset=d)
        if ds == "I3":
            sp_view = vc.add_view(vt.SPATIAL, dataset=d)
            row["notes"] = ("Spatial view added with obs_spots_path='obsm/spatial' written by hand; with no spot-layer coordination the view stays black. "
                            "A hand-written 'spotLayer' coordination (python enum has no spot-layer type in 3.8.4) failed config validation ('Expected string, received object'); not pursued further.")
            vc.layout((sc / sp_view) | (st / ft))
        else:
            vc.layout(sc | (st / ft))
        json.dump(vc.to_dict(), open(os.path.join(art, "config.json"), "w"))
        row["status"] = "ok"; row["paths_written_by_hand"] = paths_by_hand
        row["embeddings_offered_in_config"] = [o["embeddingType"] for o in opts["obsEmbedding"]]
        row["categorical_annotations"] = [o["name"] for o in opts["obsSets"]]
        row["obs_columns_in_file"] = list(a.obs.columns)
        row["spatial_in_file"] = "spatial" in a.obsm
        row["images_in_file"] = "spatial" in a.uns
        # serve and read what the page shows
        sp = dict(cmd=[harness.PY, os.path.join(HERE, "scripts", "serve_vitessce.py"), art, str(PORT)], env=harness.py_env())
        p = subprocess.Popen(sp["cmd"], cwd=HERE, env=sp["env"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL); time.sleep(2)
        br = harness.BrowserRun(); br.page.goto(f"http://127.0.0.1:{PORT}/"); time.sleep(10)
        shot = os.path.join(HERE, "logs", "task1", f"vitessce_{ds}.png"); br.page.screenshot(path=shot); row["screenshot"] = os.path.relpath(shot, HERE)
        row["page_text"] = br.page.evaluate("() => document.body.innerText")[:500]
        row["console_errors"] = br.console[:5]
        br.close(); harness.kill_tree(p)
    except Exception as e:
        row["status"] = "error"; row["error_message"] = f"{type(e).__name__}: {e}"[:500]
    json.dump(row, open(os.path.join(OUT, f"vitessce_{ds}.json"), "w"), indent=1)
    print(ds, row["status"], row.get("n_cells"), row.get("embeddings_offered_in_config"), row.get("unique_cell_names"), (row.get("error_message") or "")[:200], flush=True)
