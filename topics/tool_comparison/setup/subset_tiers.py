"""Smaller tiers: the first N cells of data/inputs/e18_500000.h5ad (same log-normalised matrix, PCA, UMAP and clusters, as the
10,000 and 100,000 tiers made by prep_inputs.py). Usage: env/py/Scripts/python.exe setup/subset_tiers.py 5000 20000 50000"""
import os, sys, anndata as ad
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = os.path.join(HERE, "data", "inputs", "e18_500000.h5ad")
a = ad.read_h5ad(src, backed="r")
for n in map(int, sys.argv[1:]):
    out = os.path.join(HERE, "data", "inputs", f"e18_{n}.h5ad")
    if os.path.exists(out):
        print("exists", out); continue
    t = a[:n].to_memory()
    t.obs["cluster"] = t.obs["cluster"].astype(str).astype("category")
    t.write_h5ad(out)
    print("wrote", out, t.shape, os.path.getsize(out))
