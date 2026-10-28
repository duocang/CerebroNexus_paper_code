## Variants of the complete_viewer fixture for F1/F2 (180 cells, UMAP/t-SNE,
## six spatial sections of 20-60 cells, an immune repertoire for every cell).
##
##   base          as shipped
##   reordered     cells in random order, repertoire rows shuffled per sample
##   case_ids      cell 2 renamed to the upper-case ID of cell 1, so two IDs
##                 differ only by letter case
##   immune_part   repertoire rows removed for 60 cells (one modality covers
##                 only part of the cells)
##   immune_extra  five repertoire rows for IDs that are not cells

f_fixture <- function() {
  readRDS(system.file("builder", "fixtures", "complete_viewer", "complete_viewer_data.rds",
                      package = "CerebroNexus", mustWork = TRUE))
}

f_map_repertoire <- function(obj, fun) {
  obj@misc$immune_repertoire <- lapply(obj@misc$immune_repertoire, fun)
  obj
}

f_variants <- function() {
  set.seed(11)
  base <- f_fixture()
  cells <- colnames(base)
  out <- list(base = base)

  out$reordered <- f_map_repertoire(base[, sample(cells)], function(t) t[sample(nrow(t)), , drop = FALSE])

  new <- cells
  new[[2L]] <- toupper(cells[[1L]])
  obj <- SeuratObject::RenameCells(base, new.names = new)
  obj <- f_map_repertoire(obj, function(t) {
    t$barcode[t$barcode == cells[[2L]]] <- new[[2L]]
    t
  })
  ## trajectories are keyed by cell ID as well
  for (m in names(obj@misc$trajectories)) for (tr in names(obj@misc$trajectories[[m]])) {
    rn <- rownames(obj@misc$trajectories[[m]][[tr]]$meta)
    rownames(obj@misc$trajectories[[m]][[tr]]$meta) <- new[match(rn, cells)]
  }
  out$case_ids <- obj

  drop <- sample(cells, 60)
  out$immune_part <- f_map_repertoire(base, function(t) t[!t$barcode %in% drop, , drop = FALSE])

  out$immune_extra <- base
  first <- names(base@misc$immune_repertoire)[[1L]]
  t <- base@misc$immune_repertoire[[first]]
  extra <- t[seq_len(5L), , drop = FALSE]
  extra$barcode <- paste0("not_a_cell_", seq_len(5L))
  out$immune_extra@misc$immune_repertoire[[first]] <- rbind(t, extra)
  out
}

## Truth from the source object, independent of the Builder and the Viewer.
f_truth <- function(obj) {
  cells <- colnames(obj)
  rep <- do.call(rbind, obj@misc$immune_repertoire)
  list(
    cells = cells,
    spatial = lapply(stats::setNames(nm = SeuratObject::Images(obj)), function(s) {
      tc <- SeuratObject::GetTissueCoordinates(obj[[s]])
      if ("cell" %in% names(tc)) tc$cell else rownames(tc)
    }),
    immune = unique(rep$barcode[rep$barcode %in% cells]),
    ## the Linked views clone space shows one receptor class at a time
    tcr = unique(rep$barcode[rep$barcode %in% cells & grepl("(^|[._;])TR[ABGD]", rep$CTgene)]),
    immune_unknown = setdiff(unique(rep$barcode), cells)
  )
}
