# Shared R-side reading for the ShinyCell and iSEE Task 1 scripts.
# input kinds: orig = file as downloaded/made; rewritten = legacy file rewritten with anndata 0.12 (Deviation D4).
suppressMessages({library(SummarizedExperiment); library(SingleCellExperiment)}); source("scripts/tools/common.R")
r_input <- function(ds, kind) {
  if (ds == "I1") if (kind == "rewritten") "inputs/I1_rewritten.h5ad" else "data/pbmc3k.h5ad"
  else if (ds == "I2") "inputs/I2_seurat.rds"
  else if (ds == "I3") if (kind == "rewritten") "inputs/I3_rewritten.h5ad" else "data/visium_hne_adata.h5ad"
  else if (ds == "I4") "inputs/I4.h5ad"
}
# Seurat object built by hand from the SCE (log-normalised values as counts and data, embeddings as reductions).
seurat_from_sce <- function(sce) {
  suppressMessages(library(Seurat))
  X <- assay(sce, "logcounts"); so <- CreateSeuratObject(counts = X, meta.data = as.data.frame(colData(sce)))
  so <- SetAssayData(so, layer = "data", new.data = X)
  for (n in reducedDimNames(sce)) {
    e <- as.matrix(reducedDim(sce, n)); rownames(e) <- colnames(sce); key <- paste0(gsub("[^A-Za-z]", "", n), "_")
    colnames(e) <- paste0(key, seq_len(ncol(e)))
    so[[gsub("^X_", "", n)]] <- CreateDimReducObject(embeddings = e, key = key, assay = "RNA")
  }
  so
}
r_object <- function(ds, kind, route) {
  if (route == "sce-dup") {   # I4 built in R: the I1 SCE with the last ten cell names replaced by the first ten (same edit as inputs/I4.h5ad)
    sce <- read_h5ad_sce("inputs/I1_rewritten.h5ad"); n <- ncol(sce)
    colnames(sce)[(n - 9):n] <- colnames(sce)[1:10]; return(sce)
  }
  if (ds != "I2" && route == "seurat") return(seurat_from_sce(plain_reduced_dims(read_h5ad_sce(r_input(ds, kind)))))
  f <- r_input(ds, kind)
  if (ds == "I2") {
    suppressMessages(library(Seurat)); s <- readRDS(f)
    return(if (route == "sce") Seurat::as.SingleCellExperiment(s) else s)
  }
  if (route == "seurat") anndataR::read_h5ad(f, as = "Seurat") else read_h5ad_sce(f)
}
sce_facts <- function(sce) list(
  n_cells = ncol(sce), n_genes = nrow(sce), unique_cell_names = !anyDuplicated(colnames(sce)),
  embeddings = reducedDimNames(sce),
  categorical_annotations = names(colData(sce))[vapply(colData(sce), function(z) is.factor(z) || is.character(z), logical(1))],
  ctaa_column_in_metadata = "CTaa" %in% names(colData(sce)))
