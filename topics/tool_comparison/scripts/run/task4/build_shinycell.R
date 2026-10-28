## ShinyCell documented route: .h5ad -> SingleCellExperiment (anndataR) ->
## createConfig() -> makeShinyApp() into <outdir>.
## Usage: build_shinycell.R <in.h5ad> <outdir>
a <- commandArgs(TRUE)
suppressMessages({library(ShinyCell); library(SingleCellExperiment)})
sce <- anndataR::read_h5ad(a[1], as = "SingleCellExperiment")
assayNames(sce)[assayNames(sce) == "X"] <- "logcounts"
for (n in reducedDimNames(sce)) reducedDim(sce, n) <- as.matrix(reducedDim(sce, n))
conf <- createConfig(sce)
dir.create(a[2], recursive = TRUE, showWarnings = FALSE)
makeShinyApp(sce, conf, gex.assay = "logcounts", gene.mapping = FALSE, shiny.dir = a[2],
             shiny.title = "task4", default.gene1 = rownames(sce)[1], default.gene2 = rownames(sce)[2],
             default.multigene = rownames(sce)[1:2])
cat("DONE\n")
