"""Task 3 inputs (PROTOCOL section 7.1): first 500k cells of E18, log-normalised; PCA/UMAP/k-means once on the 500k
object; tiers 10k / 100k / 500k written as data/inputs/e18_<N>.h5ad. Not timed. Run with env/py."""
import os, sys, time, json, h5py, numpy as np, pandas as pd, scipy.sparse as sp, anndata as ad, scanpy as sc
from sklearn.cluster import MiniBatchKMeans
HERE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))); os.chdir(HERE)
T0 = time.time()
def log(*a): print(f"[{time.time()-T0:8.0f}s]", *a, flush=True)
N = 500_000
f = h5py.File("data/raw/1M_neurons_filtered_gene_bc_matrices_h5.h5", "r"); g = f["mm10"]
indptr = g["indptr"][: N + 1]; nnz = int(indptr[-1]); log("nnz in first 500k cells:", nnz)
data = np.empty(nnz, dtype=np.float32); idx = np.empty(nnz, dtype=np.int32)
step = 1 << 27
for s in range(0, nnz, step):
    e = min(s + step, nnz); data[s:e] = g["data"][s:e]; idx[s:e] = g["indices"][s:e]
    log("read", e, "/", nnz)
n_genes_total = int(g["shape"][0])
barcodes = [b.decode() for b in g["barcodes"][:N]]
gene_names = [b.decode() for b in g["gene_names"][:]]; gene_ids = [b.decode() for b in g["genes"][:]]
f.close()
X = sp.csr_matrix((data, idx, indptr.astype(np.int64) if nnz >= 2**31 else indptr.astype(np.int32)), shape=(N, n_genes_total))
log("csr built", X.shape)
nUMI = np.asarray(X.sum(axis=1)).ravel(); nGene = np.diff(X.indptr)
assert nUMI.min() > 0
# library-size normalisation to 1e4 and log1p, in place
scale = (1e4 / nUMI).astype(np.float32)
X.data *= np.repeat(scale, nGene); np.log1p(X.data, out=X.data)
log("normalised")
a = ad.AnnData(X=X, obs=pd.DataFrame({"nUMI": nUMI.astype(np.float64), "nGene": nGene.astype(np.int64)}, index=barcodes),
               var=pd.DataFrame({"gene_ids": gene_ids}, index=pd.Index(gene_names)))
a.var_names_make_unique()
sc.pp.highly_variable_genes(a, n_top_genes=2000, flavor="seurat"); log("hvg", int(a.var.highly_variable.sum()))
top2 = a.var.loc[a.var.highly_variable].sort_values("dispersions_norm", ascending=False).index[:2].tolist()
open("data/inputs/default_genes.txt", "w").write("\n".join(top2) + "\n"); log("default genes", top2)
sc.pp.pca(a, n_comps=50, mask_var="highly_variable", svd_solver="arpack", random_state=0); log("pca done")
sc.pp.neighbors(a, n_neighbors=15, n_pcs=50, random_state=0); log("neighbors done")
sc.tl.umap(a, random_state=0); log("umap done")
km = MiniBatchKMeans(n_clusters=20, random_state=0, batch_size=10240, n_init=3).fit(a.obsm["X_pca"])
a.obs["cluster"] = pd.Categorical(km.labels_.astype(str), categories=[str(i) for i in range(20)]); log("kmeans done")
def tier(n):
    t = ad.AnnData(X=a.X[:n].copy() if n < N else a.X, obs=a.obs.iloc[:n][["cluster", "nUMI", "nGene"]].copy(),
                   var=a.var[["gene_ids"]].copy())
    t.obs["cluster"] = t.obs["cluster"].astype(str).astype("category")
    t.obsm["X_umap"] = np.asarray(a.obsm["X_umap"][:n], dtype=np.float32)
    t.obsm["X_pca"] = np.asarray(a.obsm["X_pca"][:n], dtype=np.float32)
    return t
for n in (10_000, 100_000, 500_000):
    t = tier(n); t.write_h5ad(f"data/inputs/e18_{n}.h5ad"); log("wrote tier", n, os.path.getsize(f"data/inputs/e18_{n}.h5ad"))
json.dump({"n_cells": N, "nnz_500k": nnz, "default_genes": top2, "cluster_sizes_500k": a.obs["cluster"].value_counts().sort_index().to_dict(),
           "umap_range": [float(a.obsm["X_umap"].min()), float(a.obsm["X_umap"].max())]},
          open("results/task3_inputs_manifest.json", "w"), indent=1)
log("all done")
