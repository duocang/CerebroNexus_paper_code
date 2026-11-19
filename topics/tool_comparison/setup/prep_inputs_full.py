"""The 1.3 M tier: all cells of the E18 download, log-normalised, written as data/inputs/e18_1300000.h5ad. Not timed.
Run with env/py from topics/tool_comparison:  env/py/Scripts/python.exe setup/prep_inputs_full.py

Same recipe as prep_inputs.py (the 10k / 100k / 500k tiers), with two differences that the size forces:
  * the 2,000 highly variable genes are the ones of the first 500,000 cells (seurat flavour), so the 1.3 M tier
    uses the same genes as the other tiers, and scanpy never sees a matrix with more than 2^31 non-zeros;
  * PCA, neighbours and UMAP are computed on all cells (the other tiers are the first N points of the 500k embedding).
Steps are kept in data/inputs/_work_1300000/ (hvg, PCA, UMAP) and skipped when present, so a stopped run resumes."""
import os, sys, time, json, h5py, numpy as np, pandas as pd, scipy.sparse as sp, anndata as ad, scanpy as sc
from sklearn.cluster import MiniBatchKMeans

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__))); os.chdir(HERE)
RAW = "data/raw/1M_neurons_filtered_gene_bc_matrices_h5.h5"
WORK = "data/inputs/_work_1300000"; OUT = "data/inputs/e18_1300000.h5ad"
N_HVG_CELLS = 500_000
os.makedirs(WORK, exist_ok=True)
T0 = time.time()
def log(*a): print(f"[{time.time()-T0:8.0f}s]", *a, flush=True)

f = h5py.File(RAW, "r"); g = f["mm10"]
indptr = g["indptr"][:].astype(np.int64); N = len(indptr) - 1; nnz = int(indptr[-1]); G = int(g["shape"][0])
log("cells", N, "nnz", nnz, "genes", G)
data = np.empty(nnz, dtype=np.float32); idx = np.empty(nnz, dtype=np.int32)
step = 1 << 27
for s in range(0, nnz, step):
    e = min(s + step, nnz); data[s:e] = g["data"][s:e]; idx[s:e] = g["indices"][s:e]
    if (s // step) % 4 == 0: log("read", e, "/", nnz)
barcodes = [b.decode() for b in g["barcodes"][:]]
gene_names = [b.decode() for b in g["gene_names"][:]]; gene_ids = [b.decode() for b in g["genes"][:]]
f.close()
nGene = np.diff(indptr); assert nGene.min() > 0   # every cell has counts
nUMI = np.empty(N, dtype=np.float64)
# library-size normalisation to 1e4 and log1p, in place, in blocks of cells
for c0 in range(0, N, 100_000):
    c1 = min(c0 + 100_000, N); a, b = indptr[c0], indptr[c1]
    nUMI[c0:c1] = np.add.reduceat(data[a:b].astype(np.float64), indptr[c0:c1] - a)
    data[a:b] *= np.repeat((1e4 / nUMI[c0:c1]).astype(np.float32), nGene[c0:c1]); np.log1p(data[a:b], out=data[a:b])
assert nUMI.min() > 0
log("normalised")

# --- genes: the 2,000 HVGs of the first 500k cells
hvg_f = f"{WORK}/hvg_idx.npy"
if not os.path.exists(hvg_f):
    n5 = int(indptr[N_HVG_CELLS])
    X5 = sp.csr_matrix((data[:n5], idx[:n5], indptr[: N_HVG_CELLS + 1].astype(np.int32)), shape=(N_HVG_CELLS, G), copy=False)
    a5 = ad.AnnData(X=X5, var=pd.DataFrame(index=pd.Index(gene_names))); a5.var_names_make_unique()
    sc.pp.highly_variable_genes(a5, n_top_genes=2000, flavor="seurat")
    np.save(hvg_f, np.flatnonzero(a5.var.highly_variable.values)); del a5, X5
hvg = np.load(hvg_f); log("hvg", len(hvg))

# --- embedding on all cells
pca_f, umap_f = f"{WORK}/X_pca.npy", f"{WORK}/X_umap.npy"
if not (os.path.exists(pca_f) and os.path.exists(umap_f)):
    blocks = []   # the HVG columns, block by block (scipy would widen all of idx to int64 on a matrix this size)
    for c0 in range(0, N, 100_000):
        c1 = min(c0 + 100_000, N); a, b = indptr[c0], indptr[c1]
        blocks.append(sp.csr_matrix((data[a:b], idx[a:b], (indptr[c0:c1 + 1] - a).astype(np.int32)), shape=(c1 - c0, G))[:, hvg])
    h = ad.AnnData(X=sp.vstack(blocks, format="csr"), obs=pd.DataFrame(index=barcodes)); del blocks; log("hvg columns", h.X.shape, h.X.nnz)
    if not os.path.exists(pca_f):
        sc.pp.pca(h, n_comps=50, svd_solver="arpack", random_state=0); np.save(pca_f, h.obsm["X_pca"].astype(np.float32)); log("pca done")
    else:
        h.obsm["X_pca"] = np.load(pca_f)
    h.X = None
    sc.pp.neighbors(h, n_neighbors=15, n_pcs=50, random_state=0); log("neighbors done")
    sc.tl.umap(h, random_state=0); np.save(umap_f, h.obsm["X_umap"].astype(np.float32)); log("umap done")
    del h
X_pca, X_umap = np.load(pca_f), np.load(umap_f)
km = MiniBatchKMeans(n_clusters=20, random_state=0, batch_size=10240, n_init=3).fit(X_pca); log("kmeans done")
obs = pd.DataFrame({"cluster": pd.Categorical(km.labels_.astype(str), categories=[str(i) for i in range(20)]),
                    "nUMI": nUMI.astype(np.float64), "nGene": nGene.astype(np.int64)}, index=barcodes)
obs["cluster"] = obs["cluster"].astype(str).astype("category")
var = pd.DataFrame({"gene_ids": gene_ids}, index=pd.Index(gene_names))
Xf = sp.csr_matrix((N, G), dtype=np.float32); Xf.data, Xf.indices, Xf.indptr = data, idx, indptr   # int32 indices, int64 indptr
t = ad.AnnData(X=Xf, obs=obs, var=var); t.var_names_make_unique()
t.obsm["X_umap"] = X_umap; t.obsm["X_pca"] = X_pca
tmp = OUT + ".part"
t.write_h5ad(tmp); os.replace(tmp, OUT)
json.dump({"n_cells": N, "nnz": nnz, "n_genes": G, "hvg_cells": N_HVG_CELLS, "n_hvg": int(len(hvg)),
           "cluster_sizes": obs["cluster"].value_counts().sort_index().to_dict(), "bytes": os.path.getsize(OUT)},
          open("data/inputs/e18_1300000.json", "w"), indent=1)
log("wrote", OUT, os.path.getsize(OUT))
