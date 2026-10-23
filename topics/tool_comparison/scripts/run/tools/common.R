# Shared helpers for the R-side tools (PROTOCOL 5, 7.2): .h5ad -> SingleCellExperiment with anndataR.
suppressMessages({library(SummarizedExperiment); library(SingleCellExperiment)})
tick <- function() proc.time()[["elapsed"]]
read_h5ad_sce <- function(path) {
  sce <- anndataR::read_h5ad(path, as = "SingleCellExperiment")
  # anndataR names the main matrix "X"; Bioconductor tools expect "logcounts" for log-normalised values.
  if ("X" %in% assayNames(sce)) assayNames(sce)[assayNames(sce) == "X"] <- "logcounts"
  sce
}
default_genes <- function(sce, file = "data/inputs/default_genes.txt") {
  g <- if (file.exists(file)) readLines(file) else character(0)
  g <- g[g %in% rownames(sce)]
  if (length(g) < 2) g <- rownames(sce)[1:2]
  g[1:2]
}
# Workaround used only when the default route failed: anndataR returns reducedDims with loadings as
# LinearEmbeddingMatrix, which ShinyCell cannot coerce; plain matrices of the same embeddings are used instead.
plain_reduced_dims <- function(sce) {
  for (n in reducedDimNames(sce)) reducedDim(sce, n) <- as.matrix(reducedDim(sce, n))
  sce
}
