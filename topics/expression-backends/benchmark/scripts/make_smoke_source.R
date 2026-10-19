# Write a small synthetic 10x HDF5 matrix for a quick end-to-end check:
#   Rscript make_smoke_source.R out.h5 [cells] [genes]
# then point BENCH_SMOKE_SOURCE at out.h5 (see the benchmark README).
args <- commandArgs(TRUE)
out <- args[1]
n_cells <- if (length(args) > 1) as.integer(args[2]) else 3000L
n_genes <- if (length(args) > 2) as.integer(args[3]) else 2000L
set.seed(1)
m <- Matrix::rsparsematrix(n_genes, n_cells, density = 0.05, rand.x = function(n) rpois(n, 3) + 1)
m <- methods::as(m, "CsparseMatrix")
group <- "mm10"
unlink(out)
rhdf5::h5createFile(out)
rhdf5::h5createGroup(out, group)
w <- function(name, x) rhdf5::h5write(x, out, paste0(group, "/", name))
w("data", as.integer(m@x))
w("indices", as.integer(m@i))
w("indptr", as.integer(m@p))
w("shape", c(n_genes, n_cells))
w("genes", sprintf("ENSMUSG%011d", seq_len(n_genes)))
w("gene_names", sprintf("Gene%d", seq_len(n_genes)))
w("barcodes", sprintf("CELL%06d-1", seq_len(n_cells)))
rhdf5::h5closeAll()
cat("wrote", out, ":", n_genes, "genes x", n_cells, "cells,", length(m@x), "nonzeros\n")
