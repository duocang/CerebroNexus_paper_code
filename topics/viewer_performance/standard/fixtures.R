#!/usr/bin/env Rscript
# Builds the one large Viewer fixture, `mb` (a mouse brain h5ad as a CRB with an H5 sidecar), once per machine.
#
#   Rscript topics/viewer_performance/standard/fixtures.R --h5ad FILE --out DIR [--lib DIR]
#
#   --h5ad FILE  the cells: an h5ad with a `cluster` column and `nUMI`, `nGene` (the 10x E18 mouse brain, any size)
#   --out DIR    where `mb/cerebro_mb.crb` (+ .h5, .viewer) is written; give the same DIR as --large-examples to run.R
#   --lib DIR    library holding the CerebroNexus that converts (default: the user's own). Use the OLDEST revision
#                you measure: every newer revision reads its CRB, the other way round it does not.
a <- commandArgs(TRUE)
opt <- function(k, d = NULL) { i <- match(paste0("--", k), a); if (is.na(i)) d else a[[i + 1L]] }
h5ad <- opt("h5ad"); out <- opt("out"); lib <- opt("lib")
if (is.null(h5ad) || is.null(out)) stop("usage: fixtures.R --h5ad FILE --out DIR [--lib DIR]")
if (!is.null(lib)) .libPaths(c(normalizePath(lib), .libPaths()))
suppressMessages(library(CerebroNexus))
dest <- file.path(out, "mb"); dir.create(dest, recursive = TRUE, showWarnings = FALSE)
HDF5Array::setHDF5DumpCompressionLevel(0L)
# the CRB and its sidecars are named after the h5ad (a CRB records its own H5 file name, so never rename them)
link <- file.path(tempdir(), "mb.h5ad"); file.symlink(normalizePath(h5ad), link)
res <- convertH5adToCerebro(h5ad_file = link, result_dir = dest, groups = "cluster", nUMI = "nUMI", nGene = "nGene",
                            expression_matrix_mode = "h5")
cat("CerebroNexus", as.character(packageVersion("CerebroNexus")), "->", list.files(dest), "\n")
