# Usage: shinycell_build.R <in.h5ad|in.rds> <outdir> [sce|seurat-rds] [workaround=0|1]
# Default route = ShinyCell documented calls with required args only; workaround=1 adds default genes /
# VariableFeatures where the default route failed (PROTOCOL 5).
a <- commandArgs(TRUE)
suppressMessages({library(ShinyCell); library(Matrix)})
source("scripts/tools/common.R")
t0 <- tick(); route <- if (length(a) >= 3) a[3] else "sce"; work <- length(a) >= 4 && a[4] == "1"
if (route == "seurat-rds") {
  obj <- readRDS(a[1]); gas <- NA
} else {
  obj <- read_h5ad_sce(a[1]); gas <- "logcounts"
}
t_read <- tick() - t0
cat(sprintf("TIMING read_input=%.2f\n", t_read))
if (work && route == "seurat-rds" && length(SeuratObject::VariableFeatures(obj)) == 0)
  SeuratObject::VariableFeatures(obj) <- rownames(obj)[1:min(2000, nrow(obj))]
if (work && route == "sce") obj <- plain_reduced_dims(obj)
scConf <- createConfig(obj)
dg <- if (work) default_genes(obj) else c(NA, NA)
dir.create(a[2], recursive = TRUE, showWarnings = FALSE)
t1 <- tick()
makeShinyApp(obj, scConf, gex.assay = gas, gene.mapping = FALSE, shiny.dir = a[2], shiny.title = "comparison",
             default.gene1 = dg[1], default.gene2 = dg[2], default.multigene = if (work) default_genes(obj) else NA)
cat(sprintf("TIMING tool_step=%.2f\n", tick() - t1))
cat("FILES:", paste(list.files(a[2], recursive = TRUE), collapse = ", "), "\n")
