# One measurement in a fresh R process: write the gene-major H5 file of a cell-major 10x source with the installed
# CerebroNexus (its streaming writer, .h5adStreamWriteTENx), then read genes from it through HDF5Array as the
# Viewer does. Prints one line, "ROW<TAB>key=value<TAB>...".
# usage: Rscript h5_writer_measure.R LIB SOURCE GROUP OUT_H5 WORKERS (started by h5_writer_run.R)
args <- commandArgs(TRUE)
lib <- args[[1]]; source_file <- args[[2]]; group <- args[[3]]; out <- args[[4]]; workers <- as.integer(args[[5]])
.libPaths(c(lib, .libPaths()))
suppressPackageStartupMessages({ library(CerebroNexus); library(HDF5Array) })
installed <- normalizePath(find.package("CerebroNexus"), winslash = "/")
if (!startsWith(installed, normalizePath(lib, winslash = "/"))) stop("CerebroNexus is not the one in ", lib, call. = FALSE)
ns <- asNamespace("CerebroNexus")
options(cerebro.h5ad_stream_workers = workers)
unlink(out)
gc(full = TRUE)
src <- ns$.h5adStreamFrom10x(source_file, group)
t0 <- proc.time()[["elapsed"]]
ns$.h5adStreamWriteTENx(src, out, group = "expression", dimnames = list(NULL, NULL), level = 1L)
write_s <- proc.time()[["elapsed"]] - t0
## Reads as the Viewer makes them: whole genes (columns of cells x genes), then a few genes for a random subset of
## cells. The file was just written, so the operating system may still hold it: these are warm-cache reads.
m <- TENxMatrix(out, "expression")
set.seed(7); genes <- sample.int(ncol(m), 32)
t0 <- proc.time()[["elapsed"]]; for (g in genes[1:20]) x <- as.vector(m[, g]); read_genes_s <- proc.time()[["elapsed"]] - t0
t0 <- proc.time()[["elapsed"]]; for (g in genes[1:20]) x <- as.vector(m[, g]); read_genes_again_s <- proc.time()[["elapsed"]] - t0
set.seed(11); cells <- sort(sample.int(nrow(m), min(nrow(m), 1e5)))
t0 <- proc.time()[["elapsed"]]; x <- as.matrix(m[cells, genes[21:32]]); read_subset_s <- proc.time()[["elapsed"]] - t0
row <- c(write_s = write_s, file_bytes = format(file.size(out), scientific = FALSE), nnz = format(src$nnz, scientific = FALSE), read_genes_s = read_genes_s,
  read_genes_again_s = read_genes_again_s, read_subset_s = read_subset_s,
  version = as.character(utils::packageVersion("CerebroNexus")))
cat("ROW", paste0(names(row), "=", trimws(row)), sep = "\t")
cat("\n")
