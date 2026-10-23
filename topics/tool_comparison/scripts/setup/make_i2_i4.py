"""Write data/inputs/I2.h5ad (from the R export) and data/inputs/I4.h5ad (I1 with duplicated cell names)."""
import os, numpy as np, pandas as pd, scipy.io, scipy.sparse as sp, anndata as ad
HERE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.chdir(HERE)
d = "data/inputs/I2_export/"
X = sp.csr_matrix(scipy.io.mmread(d + "counts.mtx").T.astype(np.float32))
genes = [l.strip() for l in open(d + "genes.txt")]; cells = [l.strip() for l in open(d + "cells.txt")]
meta = pd.read_csv(d + "meta.csv", index_col=0).loc[cells]
um = pd.read_csv(d + "umap.csv", index_col=0).loc[cells]
a = ad.AnnData(X=X, obs=meta, var=pd.DataFrame(index=genes))
for c in ["orig.ident", "sample", "seurat_clusters", "RNA_snn_res.0.8", "cloneSize"]:
    a.obs[c] = a.obs[c].astype(str).astype("category")
for c in ["CTgene", "CTnt", "CTaa", "CTstrict"]:   # NA stays NA
    a.obs[c] = a.obs[c].astype("object").where(a.obs[c].notna(), None).astype("category")
a.obsm["X_umap"] = um.to_numpy(dtype=np.float32)
a.write_h5ad("data/inputs/I2.h5ad")
print("I2", a.shape, "CTaa non-NA", a.obs["CTaa"].notna().sum(), "obs", list(a.obs.columns))
i1 = ad.read_h5ad("data/raw/pbmc3k.h5ad")
names = np.array(i1.obs_names, dtype=object)
names[-10:] = names[:10]
i1.obs_names = pd.Index(names)
assert (~i1.obs_names.is_unique) and i1.obs_names.nunique() == i1.n_obs - 10
i1.write_h5ad("data/inputs/I4.h5ad")
print("I4", i1.shape, "unique names", i1.obs_names.nunique())
