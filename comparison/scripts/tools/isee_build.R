# Usage: isee_build.R <in.h5ad|in.rds> <outdir> [sce|seurat-rds]
a <- commandArgs(TRUE)
source("scripts/tools/common.R")
t0 <- tick(); route <- if (length(a) >= 3) a[3] else "sce"
if (route == "seurat-rds") {
  sce <- Seurat::as.SingleCellExperiment(readRDS(a[1]))
} else sce <- read_h5ad_sce(a[1])
cat(sprintf("TIMING read_input=%.2f\n", tick() - t0))
dir.create(a[2], recursive = TRUE, showWarnings = FALSE)
t1 <- tick(); saveRDS(sce, file.path(a[2], "sce.rds"), compress = FALSE)
cat(sprintf("TIMING tool_step=%.2f\n", tick() - t1))
cat("FILES:", paste(list.files(a[2], recursive = TRUE), collapse = ", "), "\n")
