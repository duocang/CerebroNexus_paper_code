## iSEE: the documented use is iSEE(sce) inside an R session; a shareable App
## needs the SingleCellExperiment saved and an app.R written by the user.
## Usage: build_isee.R <in.h5ad> <outdir>
a <- commandArgs(TRUE)
suppressMessages(library(SingleCellExperiment))
sce <- anndataR::read_h5ad(a[1], as = "SingleCellExperiment")
assayNames(sce)[assayNames(sce) == "X"] <- "logcounts"
for (n in reducedDimNames(sce)) reducedDim(sce, n) <- as.matrix(reducedDim(sce, n))
dir.create(a[2], recursive = TRUE, showWarnings = FALSE)
saveRDS(sce, file.path(a[2], "sce.rds"))
writeLines(c("library(iSEE)", "iSEE(readRDS(\"sce.rds\"))"), file.path(a[2], "app.R"))
cat("DONE\n")
