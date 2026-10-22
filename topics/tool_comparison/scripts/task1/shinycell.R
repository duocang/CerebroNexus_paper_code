# Usage: task1/shinycell.R <dataset> <route sce|seurat> <input orig|rewritten> <workaround 0|1> <out.json>
a <- commandArgs(TRUE); ds <- a[1]; route <- a[2]; kind <- a[3]; wk <- a[4] == "1"; out <- a[5]
suppressMessages({library(ShinyCell); library(Matrix)}); source("scripts/task1/common.R"); source("scripts/task1/rside.R")
dir <- file.path("artifacts/t1", paste0("sc_", ds, "_", route, "_", kind, "_w", as.integer(wk))); unlink(dir, recursive = TRUE); dir.create(dir, recursive = TRUE)
row <- list(tool = "ShinyCell", dataset = ds, route = route, input = kind, workaround = wk)
stage <- "read"
r <- t1_run(function() {
  obj <- r_object(ds, kind, route)
  stage <<- "makeShinyApp"
  if (wk) {
    if (route %in% c("sce", "sce-dup")) obj <- plain_reduced_dims(obj)
    if (route == "seurat" && length(SeuratObject::VariableFeatures(obj)) == 0) SeuratObject::VariableFeatures(obj) <- rownames(obj)[1:min(2000, nrow(obj))]
  }
  facts <- if (route %in% c("sce", "sce-dup")) sce_facts(obj) else list(n_cells = ncol(obj), n_genes = nrow(obj), embeddings = names(obj@reductions),
    unique_cell_names = !anyDuplicated(colnames(obj)), categorical_annotations = names(obj@meta.data)[vapply(obj@meta.data, function(z) is.factor(z) || is.character(z), logical(1))],
    ctaa_column_in_metadata = "CTaa" %in% names(obj@meta.data))
  scConf <- createConfig(obj)
  dg <- if (wk) { g <- rownames(obj); g[1:2] } else c(NA, NA)
  makeShinyApp(obj, scConf, gex.assay = if (route %in% c("sce", "sce-dup")) "logcounts" else NA, gene.mapping = FALSE, shiny.dir = dir,
               shiny.title = "t1", default.gene1 = dg[1], default.gene2 = dg[2], default.multigene = if (wk) dg else NA)
  facts
})
row$status <- if (r$ok) "ok" else "error"; row$error_message <- r$error; row$failed_stage <- if (r$ok) NA else stage; row$warnings <- r$warnings
row$required_args <- "makeShinyApp(obj, scConf); createConfig(obj)" 
if (r$ok) {
  row <- c(row, r$value)
  conf <- readRDS(file.path(dir, "sc1conf.rds")); meta <- readRDS(file.path(dir, "sc1meta.rds"))
  ids <- if ("sampleID" %in% names(meta)) as.character(meta$sampleID) else rownames(meta)
  row$in_app_cells <- nrow(meta); row$in_app_unique_cell_names <- !anyDuplicated(ids)
  row$in_app_dimension_columns <- conf$ID[grepl("[0-9]$", conf$ID) & !conf$grp]
  row$in_app_grouping_variables <- conf$ID[conf$grp]
  row$in_app_metadata_columns <- conf$ID
  row$in_app_genes <- length(readRDS(file.path(dir, "sc1gene.rds")))
  row$artifact_bytes <- sum(file.size(list.files(dir, recursive = TRUE, full.names = TRUE)))
}
t1_write(row, out); cat("WROTE", out, row$status, "\n")
