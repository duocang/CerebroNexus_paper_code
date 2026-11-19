"""Usage: vitessce_build.py <in.h5ad> <outdir> <cluster_col> [<embedding key, default X_umap>]
Build: .h5ad -> Zarr (vitessce optimize_adata, X kept sparse as CSC) + Vitessce config (PROTOCOL 7.2).
The package's data_utils/__init__ imports spatialdata/ome-zarr extras that are not part of the pinned install,
so optimize_adata is loaded from its own module file (same code)."""
import sys, os, json, time, importlib.util, warnings
warnings.filterwarnings("ignore")
import anndata as ad
import vitessce
from vitessce import VitessceConfig, ViewType as vt, CoordinationType as ct, AnnDataWrapper

src, out, cluster = sys.argv[1], sys.argv[2], sys.argv[3]
emb = sys.argv[4] if len(sys.argv) > 4 else "X_umap"
os.makedirs(out, exist_ok=True)
spec = importlib.util.spec_from_file_location("vitessce_adata_utils", os.path.join(os.path.dirname(vitessce.__file__), "data_utils", "anndata.py"))
du = importlib.util.module_from_spec(spec); spec.loader.exec_module(du)

t0 = time.perf_counter()
a = ad.read_h5ad(src)
t_read = time.perf_counter() - t0
print(f"TIMING read_input={t_read:.2f}", flush=True)
t1 = time.perf_counter()
a2 = du.optimize_adata(a, obs_cols=[cluster], obsm_keys=[emb], optimize_X=False)
zpath = os.path.join(out, "data.zarr")
a2.write_zarr(zpath)
print(f"TIMING tool_step={time.perf_counter() - t1:.2f}", flush=True)

vc = VitessceConfig(schema_version="1.0.17", name="comparison")
ds = vc.add_dataset(name="d").add_object(AnnDataWrapper(
    adata_url="__ORIGIN__/data.zarr", obs_embedding_paths=[f"obsm/{emb}"], obs_embedding_names=[emb.replace("X_", "").upper()],
    obs_set_paths=[f"obs/{cluster}"], obs_set_names=[cluster], obs_feature_matrix_path="X"))
sc = vc.add_view(vt.SCATTERPLOT, dataset=ds, mapping=emb.replace("X_", "").upper())
sets = vc.add_view(vt.OBS_SETS, dataset=ds)
feat = vc.add_view(vt.FEATURE_LIST, dataset=ds)
vc.layout((sc | (sets / feat)))
cfg = vc.to_dict()
json.dump(cfg, open(os.path.join(out, "config.json"), "w"))
print("FILES:", sorted(os.listdir(out)))
