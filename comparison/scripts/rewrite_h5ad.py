"""Rewrite a legacy .h5ad with the current anndata (workaround for anndataR, which refuses files made with anndata<0.8).
Usage: rewrite_h5ad.py <in> <out>. Content unchanged."""
import sys, warnings, anndata as ad
warnings.filterwarnings("ignore")
a = ad.read_h5ad(sys.argv[1]); a.write_h5ad(sys.argv[2]); print("rewrote", sys.argv[1], "->", sys.argv[2], a.shape)
