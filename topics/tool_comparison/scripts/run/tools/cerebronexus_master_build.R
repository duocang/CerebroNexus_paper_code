# Build a CRB with CerebroNexus master (5.3.1), which has no h5ad import: tier .h5ad -> SingleCellExperiment (anndataR) -> Seurat -> exportFromSeurat.
# Usage: cerebronexus_master_build.R <in.h5ad> <outdir> <embedded|h5>
a <- commandArgs(TRUE)
suppressMessages({library(CerebroNexus); library(Seurat); library(Matrix)})
source("scripts/run/tools/common.R")
stopifnot(as.character(packageVersion("CerebroNexus")) == "5.3.1")
t0 <- tick()
sce <- read_h5ad_sce(a[1])
cat(sprintf("TIMING read_input=%.2f\n", tick() - t0))
t1 <- tick()
X <- SummarizedExperiment::assay(sce, "logcounts")
so <- CreateSeuratObject(counts = X, meta.data = as.data.frame(SummarizedExperiment::colData(sce)))
so <- SetAssayData(so, layer = "data", new.data = X)
um <- as.matrix(SingleCellExperiment::reducedDim(sce, "X_umap")); rownames(um) <- colnames(sce); colnames(um) <- c("UMAP_1", "UMAP_2")
so[["umap"]] <- CreateDimReducObject(embeddings = um, key = "UMAP_", assay = "RNA")
rm(sce, X); invisible(gc())
cat(sprintf("TIMING seurat_object=%.2f\n", tick() - t1))
dir.create(a[2], recursive = TRUE, showWarnings = FALSE)
t2 <- tick()
exportFromSeurat(so, assay = "RNA", slot = "data", file = file.path(a[2], "cerebro_e18.crb"), experiment_name = "e18", organism = "mm",
                 groups = "cluster", nUMI = "nUMI", nGene = "nGene",
                 expression_matrix_mode = a[3], h5_compression_level = 0L)
cat(sprintf("TIMING tool_step=%.2f\n", tick() - t2))
cat("FILES:", paste(list.files(a[2], recursive = TRUE), collapse = ", "), "\n")
