# Usage: task1/cerebronexus.R <dataset I1|I2|I3|I4> <route h5ad|seurat|h5ad-nogroups> <out.json>
a <- commandArgs(TRUE); ds <- a[1]; route <- a[2]; out <- a[3]
suppressMessages(library(CerebroNexus)); source("scripts/run/task1/common.R")
src <- list(I1 = "data/raw/pbmc3k.h5ad", I2 = "data/inputs/I2.h5ad", I3 = "data/raw/visium_hne_adata.h5ad", I4 = "data/inputs/I4.h5ad")
grp <- list(I1 = "louvain", I2 = "seurat_clusters", I3 = "cluster", I4 = "louvain")
dir <- file.path("data/builds/t1", paste0("cn_", ds, "_", route)); unlink(dir, recursive = TRUE); dir.create(dir, recursive = TRUE)
row <- list(tool = "CerebroNexus", dataset = ds, route = route)
if (route == "seurat") {
  r <- t1_run(function() {
    suppressMessages(library(Seurat))
    s <- readRDS("data/inputs/I2_seurat.rds")
    s <- addImmuneRepertoire(s, from_metadata = TRUE)
    f <- file.path(dir, "I2_seurat.crb")
    exportFromSeurat(s, assay = "RNA", file = f, experiment_name = "I2", organism = "hg", groups = "seurat_clusters",
                     nUMI = "nCount_RNA", nGene = "nFeature_RNA")
    f
  })
  row$required_args <- "addImmuneRepertoire(from_metadata = TRUE); exportFromSeurat(file, experiment_name, organism, groups, nUMI, nGene)"
} else {
  g <- if (route == "h5ad-nogroups") NULL else grp[[ds]]
  r <- t1_run(function() {
    res <- convertH5adToCerebro(src[[ds]], result_dir = dir, groups = g, verbose = FALSE)
    res
  })
  row$required_args <- if (route == "h5ad-nogroups") "none given (groups omitted on purpose)" else paste0("h5ad_file, result_dir, groups = '", grp[[ds]], "'")
}
row$status <- if (r$ok) "ok" else "error"; row$error_message <- r$error; row$warnings <- r$warnings
if (r$ok) {
  f <- if (route == "seurat") r$value else list.files(dir, pattern = "[.]crb$", full.names = TRUE)[1]
  x <- readCerebro(f)
  row$n_cells <- length(x$getCellNames()); row$n_genes <- length(x$getGeneNames())
  row$embeddings <- x$availableProjections()
  row$categorical_annotations <- x$getGroups()
  row$unique_cell_names <- !anyDuplicated(x$getCellNames())
  sp <- x$availableSpatial()
  row$spatial_present <- length(sp) > 0
  row$tissue_image_present <- length(sp) > 0 && length(x$getSpatialData(sp[1])$histology_images) > 0
  ir <- tryCatch(x$getImmuneRepertoire(), error = function(e) NULL)
  row$immune_repertoire_present <- !is.null(ir) && length(ir) > 0 && any(vapply(ir, function(z) is.data.frame(z) && nrow(z) > 0, logical(1)))
  if (row$immune_repertoire_present) row$immune_repertoire_rows <- sum(vapply(ir, function(z) if (is.data.frame(z)) nrow(z) else 0L, numeric(1)))
  row$ctaa_column_in_metadata <- "CTaa" %in% colnames(x$getMetaData())
  row$artifact_bytes <- file.size(f)
}
t1_write(row, out)
cat("WROTE", out, "status", row$status, "\n")
