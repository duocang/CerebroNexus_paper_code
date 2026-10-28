"""Python side of Task 4 (PROTOCOL_task4.md).

Usage:
  pytools.py rewrite <in.h5ad> <out.h5ad>             read and write with anndata (current layout), as Tasks 1-3
  pytools.py minus100 <in.h5ad> <out.h5ad>            changed input: first 100 cells removed
  pytools.py copy <in.h5ad> <outdir>                   cellxgene: the .h5ad is the artifact (outdir/data.h5ad)
  pytools.py vitessce <in.h5ad> <outdir>               Vitessce build (Zarr + config.json), as Tasks 1-3
  pytools.py cx_annotate <url> <h5ad> <name> <n>       save a cellxgene annotation: label the first n cells
                                                       through the server's annotations/obs PUT, in the
                                                       deflated flatbuffer format the cellxgene UI sends
  pytools.py cx_annotations <url>                      print the saved annotation columns and labelled cells (JSON)
  pytools.py n_obs <path>                              cells in an .h5ad or a Vitessce data.zarr
"""
import json, os, sys, time, zlib, importlib.util, warnings
warnings.filterwarnings("ignore")


def rewrite(src, out):
    import anndata as ad
    ad.read_h5ad(src).write_h5ad(out)


def minus100(src, out):
    import anndata as ad
    a = ad.read_h5ad(src)
    a[100:].copy().write_h5ad(out)


def copy(src, out):
    import shutil
    os.makedirs(out, exist_ok=True)
    shutil.copyfile(src, os.path.join(out, "data.h5ad"))


def vitessce(src, out):
    import anndata as ad
    import vitessce as v
    from vitessce import VitessceConfig, ViewType as vt, AnnDataWrapper
    os.makedirs(out, exist_ok=True)
    spec = importlib.util.spec_from_file_location(
        "vitessce_adata_utils", os.path.join(os.path.dirname(v.__file__), "data_utils", "anndata.py"))
    du = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(du)
    a = ad.read_h5ad(src)
    a2 = du.optimize_adata(a, obs_cols=["louvain"], obsm_keys=["X_umap"], optimize_X=False)
    a2.write_zarr(os.path.join(out, "data.zarr"))
    vc = VitessceConfig(schema_version="1.0.17", name="task4")
    ds = vc.add_dataset(name="d").add_object(AnnDataWrapper(
        adata_url="__ORIGIN__/data.zarr", obs_embedding_paths=["obsm/X_umap"], obs_embedding_names=["UMAP"],
        obs_set_paths=["obs/louvain"], obs_set_names=["louvain"], obs_feature_matrix_path="X"))
    sc = vc.add_view(vt.SCATTERPLOT, dataset=ds, mapping="UMAP")
    sets = vc.add_view(vt.OBS_SETS, dataset=ds)
    feat = vc.add_view(vt.FEATURE_LIST, dataset=ds)
    vc.layout(sc | (sets / feat))
    json.dump(vc.to_dict(), open(os.path.join(out, "config.json"), "w"))


def cx_annotate(url, h5ad, name, n):
    import anndata as ad, pandas as pd, requests
    from server.common.fbs.matrix import encode_matrix_fbs
    obs = ad.read_h5ad(h5ad, backed="r").obs
    labels = pd.Categorical(["task4"] * int(n) + ["unassigned"] * (obs.shape[0] - int(n)),
                            categories=["unassigned", "task4"])
    df = pd.DataFrame({name: labels})
    body = zlib.compress(encode_matrix_fbs(df, col_idx=df.columns))
    r = requests.put(url.rstrip("/") + "/api/v0.2/annotations/obs?annotation-collection-name=task4", data=body,
                     headers={"Content-Type": "application/octet-stream"}, timeout=30)
    print(json.dumps({"status": r.status_code, "body": r.text[:200]}))


def cx_annotations(url):
    """Labels of collection task4 as the UI loads them after a restart."""
    import requests
    from server.common.fbs.matrix import decode_matrix_fbs
    r = requests.get(url.rstrip("/") + "/api/v0.2/annotations/obs?annotation-collection-name=task4"
                     "&annotation-name=task4_label",
                     headers={"Accept": "application/octet-stream"}, timeout=30)
    if r.status_code != 200:
        print(json.dumps({"status": r.status_code}))
        return
    df = decode_matrix_fbs(r.content)
    out = {c: int((df[c].astype(str) == "task4").sum()) for c in df.columns}
    print(json.dumps({"status": 200, "labelled_cells": out}))


def n_obs(path):
    if path.endswith(".zarr"):
        import anndata as ad
        print(ad.read_zarr(path).n_obs)
    else:
        import anndata as ad
        print(ad.read_h5ad(path, backed="r").n_obs)


if __name__ == "__main__":
    cmd, args = sys.argv[1], sys.argv[2:]
    {"rewrite": rewrite, "minus100": minus100, "copy": copy, "vitessce": vitessce, "cx_annotate": cx_annotate,
     "cx_annotations": cx_annotations, "n_obs": n_obs}[cmd](*args)
