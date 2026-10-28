## Experiment B: end to end on real inputs.
##
## For each input: profile -> plan -> build -> publish ("CRB files + Viewer
## App"), start the published Viewer in a separate R process without
## CerebroNexus on its library path and load the dataset in headless Chrome,
## then compare the published CRB with the source read independently of the
## Builder (readRDS for Seurat/SCE, rhdf5 for the h5ad): cell IDs and order,
## gene IDs and order, every expression value, every projection and spatial
## coordinate, every group label, and the decoded image pixels.
##
## Usage: Rscript scripts/B_end_to_end.R [id ...]
## Writes results/B_end_to_end.csv and results/logs/B_end_to_end.log (via tee).

source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))), "common.R"))
source(file.path(bv_root, "scripts", "viewer.R"))
suppressPackageStartupMessages(library(SeuratObject))

inputs <- file.path(bv_data, "inputs")
## B_BACKEND=h5 builds every case with the HDF5 expression backend (F3).
b_backend <- Sys.getenv("B_BACKEND")
work_root <- file.path(bv_data, if (nzchar(b_backend)) paste0("B_", b_backend) else "B")
dir.create(work_root, recursive = TRUE, showWarnings = FALSE)
rt <- bv_load_runtime()

## External image record, as the Spatial page stores it after an author adds
## a picture (helper-builder-end-to-end.R builds the same record).
image_record <- function(path, section, bounds) {
  ins <- rt$builder_read_image(path)
  rec <- rt$builder_alignment_record(
    source = list(name = basename(path), type = ins$mime, size = ins$bytes),
    base_bounds = bounds,
    section = list(id = section, kind = "spatial"),
    source_path = ins$source_path
  )
  rec$source_content_md5 <- ins$source_content_md5
  rec
}

## ---- source truth, read without the Builder --------------------------------

truth_seurat <- function(path, settings) {
  o <- readRDS(path)
  m <- LayerData(o, assay = settings$assay, layer = settings$layer)
  coords <- list()
  for (s in Images(o)) {
    tc <- GetTissueCoordinates(o[[s]])
    rn <- if ("cell" %in% names(tc)) tc$cell else rownames(tc)
    coords[[s]] <- matrix(c(tc$x, tc$y), ncol = 2, dimnames = list(rn, c("x", "y")))
  }
  list(
    cells = colnames(m), genes = rownames(m), matrix = m,
    meta = o@meta.data,
    projections = lapply(o@reductions, function(r) Embeddings(r)[, 1:2]),
    coords = coords
  )
}

truth_sce <- function(path, settings) {
  o <- readRDS(path)
  assay <- if (identical(settings$layer, "counts")) "counts" else "logcounts"
  m <- SummarizedExperiment::assay(o, assay)
  list(
    cells = colnames(o), genes = rownames(o), matrix = m, matrix_source = assay,
    meta = as.data.frame(SummarizedExperiment::colData(o)),
    projections = lapply(as.list(SingleCellExperiment::reducedDims(o)), function(r) {
      r <- as.matrix(r)[, 1:2]
      rownames(r) <- colnames(o)
      r
    }),
    coords = list()
  )
}

truth_h5ad <- function(path, settings) {
  obs <- suppressWarnings(rhdf5::h5read(path, "obs"))
  var <- suppressWarnings(rhdf5::h5read(path, "var"))
  cells <- as.vector(obs$index)
  genes <- as.vector(var$index)
  x <- rhdf5::h5read(path, "X")
  dimnames(x) <- list(genes, cells)
  obsm <- rhdf5::h5read(path, "obsm", compoundAsDataFrame = FALSE)
  meta <- data.frame(row.names = cells)
  for (col in setdiff(names(obs), "index")) meta[[col]] <- as.vector(obs[[col]])
  cats <- as.vector(rhdf5::h5read(path, "uns/louvain_categories"))
  meta$louvain <- cats[meta$louvain + 1L]
  list(
    cells = cells, genes = genes, matrix = x, matrix_source = "X",
    meta = meta,
    projections = lapply(obsm, function(a) {
      a <- t(a)[, 1:2]
      rownames(a) <- cells
      a
    }),
    coords = list()
  )
}

## ---- comparison -------------------------------------------------------------

norm_name <- function(x) tolower(sub("^X_", "", x))

compare <- function(crb, truth) {
  r <- list()
  cells <- crb$getCellNames()
  genes <- crb$getGeneNames()
  r$n_cells <- length(cells)
  r$n_genes <- length(genes)
  r$cells_identical_order <- identical(cells, truth$cells)
  r$genes_identical_order <- identical(genes, truth$genes)
  e <- methods::as(crb$getExpressionMatrix(), "CsparseMatrix")
  t <- truth$matrix
  if (!identical(dim(e), dim(t))) {
    r$expr_max_abs_diff <- NA_real_
  } else {
    t <- t[rownames(e), colnames(e), drop = FALSE]
    if (methods::is(t, "sparseMatrix")) {
      d <- methods::as(t, "CsparseMatrix") - e
      r$expr_max_abs_diff <- if (length(d@x)) max(abs(d@x)) else 0
    } else {
      r$expr_max_abs_diff <- max(abs(as.matrix(e) - t))
    }
  }
  r$expr_values_compared <- prod(dim(e))
  ## projections: match names case-insensitively, without the AnnData X_
  pr <- crb$projections
  diffs <- c()
  matched <- c()
  for (p in names(pr)) {
    k <- match(norm_name(p), norm_name(names(truth$projections)))
    if (is.na(k)) next
    src <- truth$projections[[k]][cells, , drop = FALSE]
    out <- as.matrix(pr[[p]])
    diffs <- c(diffs, max(abs(out - src)))
    matched <- c(matched, p)
  }
  r$projections <- paste(names(pr), collapse = ";")
  r$projections_compared <- paste(matched, collapse = ";")
  r$projection_max_abs_diff <- if (length(diffs)) max(diffs) else NA_real_
  ## group labels
  meta <- crb$getMetaData()
  groups <- crb$getGroups()
  mism <- 0L
  compared <- c()
  for (g in groups) {
    if (!g %in% names(truth$meta)) next
    s <- as.character(truth$meta[cells, g])
    o <- as.character(meta[[g]])
    mism <- mism + sum(xor(is.na(s), is.na(o)) | (!is.na(s) & !is.na(o) & s != o))
    compared <- c(compared, g)
  }
  r$groups <- paste(groups, collapse = ";")
  r$groups_compared <- paste(compared, collapse = ";")
  r$group_label_mismatches <- mism
  r$meta_rows_aligned <- identical(as.character(meta$cell_barcode), cells)
  ## spatial coordinates
  sp <- crb$spatial %||% list()
  r$spatial_sections <- paste(names(sp), collapse = ";")
  if (length(truth$coords)) {
    cd <- 0
    ids <- TRUE
    for (s in names(truth$coords)) {
      if (is.null(sp[[s]])) {
        ids <- FALSE
        next
      }
      out <- as.matrix(sp[[s]]$coordinates[, c("x", "y")])
      ids <- ids && identical(sort(rownames(out)), sort(rownames(truth$coords[[s]])))
      cd <- max(cd, abs(out - truth$coords[[s]][rownames(out), , drop = FALSE]))
    }
    r$coords_compared <- sum(vapply(truth$coords, nrow, 1L))
    r$coord_max_abs_diff <- cd
    r$coord_ids_match <- ids
  } else {
    r$coords_compared <- 0L
    r$coord_max_abs_diff <- NA_real_
    r$coord_ids_match <- NA
  }
  r
}

## Published image vs the source PNG, decoded.
compare_image <- function(release, source_png) {
  if (is.null(source_png)) {
    return(list(image_published = NA, image_dims_equal = NA, image_max_abs_diff_8bit = NA_real_))
  }
  files <- list.files(file.path(release, "cerebro_app", "spatial-assets"),
                      full.names = TRUE, recursive = TRUE)
  files <- files[grepl("\\.(png|jpe?g)$", files, ignore.case = TRUE)]
  if (!length(files)) {
    return(list(image_published = FALSE, image_dims_equal = NA, image_max_abs_diff_8bit = NA_real_))
  }
  a <- png::readPNG(source_png)
  b <- png::readPNG(files[[1L]])
  same <- identical(dim(a), dim(b))
  list(
    image_published = TRUE,
    image_file = basename(files[[1L]]),
    image_dims = paste(dim(b), collapse = "x"),
    image_dims_equal = same,
    image_max_abs_diff_8bit = if (same) max(abs(round(a * 255) - round(b * 255))) else NA_real_,
    image_bytes_identical = identical(bv_sha256(source_png), bv_sha256(files[[1L]]))
  )
}

## ---- cases -------------------------------------------------------------------

visium_png <- file.path(inputs, "visium_anterior1_he.png")
xenium_png <- file.path(inputs, "xenium_dapi.png")
cases <- list(
  visium = list(
    label = "Visium anterior1", input = "visium_anterior1.rds", truth = truth_seurat,
    gene = "Ttr", image = visium_png, section = "anterior1",
    bounds = function() {
      d <- dim(png::readPNG(visium_png))
      lowres <- 0.05163511 # ScaleFactors(obj[["anterior1"]])$lowres
      list(xmin = 0, xmax = d[2] / lowres, ymin = 0, ymax = d[1] / lowres)
    }
  ),
  xenium = list(
    label = "Xenium brain", input = "xenium_brain.rds", truth = truth_seurat,
    gene = "Gfap", image = xenium_png, section = "fov",
    bounds = function() {
      j <- jsonlite::fromJSON(file.path(inputs, "xenium_dapi.json"))
      j[c("xmin", "xmax", "ymin", "ymax")]
    }
  ),
  pbmc_seurat = list(label = "PBMC Seurat", input = "pbmc_seurat.rds",
                     truth = truth_seurat, gene = "CD3E"),
  pbmc_sce = list(label = "PBMC SCE", input = "pbmc_SCE.rds",
                  truth = truth_sce, gene = "CD3E"),
  ## The same file with the source's own nUMI/nGene columns chosen as the QC
  ## columns on the Configure page (the default, nCount_RNA/nFeature_RNA from
  ## the SCE conversion, fails; see README).
  pbmc_sce_own_qc = list(label = "PBMC SCE own QC", input = "pbmc_SCE.rds",
                         truth = truth_sce, gene = "CD3E",
                         configure = list(nUMI = "nUMI", nGene = "nGene")),
  pbmc3k_h5ad = list(label = "pbmc3k h5ad", input = "pbmc3k.h5ad",
                     truth = truth_h5ad, gene = "NKG7")
)
only <- commandArgs(trailingOnly = TRUE)
if (length(only)) cases <- cases[intersect(names(cases), only)]

rows <- list()
for (id in names(cases)) {
  case <- cases[[id]]
  cat("\n==== ", id, " ====\n", sep = "")
  input <- file.path(inputs, case$input)
  work <- file.path(work_root, id)
  unlink(work, recursive = TRUE)
  dir.create(file.path(work, "work"), recursive = TRUE)
  configure <- case[["configure", exact = TRUE]] %||% list()
  if (nzchar(b_backend)) configure$expression_backend <- b_backend
  if (!is.null(case$image)) {
    configure$images <- stats::setNames(
      list(image_record(case$image, case$section, case$bounds())),
      case$section
    )
  }
  t0 <- proc.time()[["elapsed"]]
  stage_times <- list()
  run <- bv_capture({
    inspected <- bv_profile(rt, input, id = id)
    stage_times$profile <- proc.time()[["elapsed"]] - t0
    settings <- bv_settings(rt, inspected, case$label, configure, file.path(work, "work"))
    planned <- bv_plan(rt, id, inspected, settings, input, file.path(work, "work"),
                       file.path(work, "release"))
    stage_times$plan <- proc.time()[["elapsed"]] - t0
    built <- bv_build(rt, planned, id, paste0(id, "-B"))
    stage_times$build <- proc.time()[["elapsed"]] - t0
    published <- bv_publish(rt, built)
    stage_times$publish <- proc.time()[["elapsed"]] - t0
    list(settings = settings, published = published)
  })
  row <- list(id = id, input = case$input, input_sha256 = bv_sha256(input),
              route_error = run$error %||% "",
              route_warnings = bv_one_line(run$warnings))
  row$seconds_profile <- stage_times$profile %||% NA
  row$seconds_to_plan <- stage_times$plan %||% NA
  row$seconds_to_build <- stage_times$build %||% NA
  row$seconds_to_publish <- stage_times$publish %||% NA
  if (is.null(run$error)) {
    pub <- run$value$published
    crb_path <- pub$built[[1L]]
    row$published <- isTRUE(pub$published)
    row$crb <- basename(crb_path)
    row$crb_bytes <- file.size(crb_path)
    row$layer <- run$value$settings$layer
    v <- bv_viewer_check(pub$app_dir, work_root, case$gene,
                         image_label = if (!is.null(case$image)) basename(case$image),
                         label = id)
    row <- c(row, v)
    crb <- readCerebro(crb_path)
    truth <- case$truth(input, run$value$settings)
    row$truth_matrix <- truth$matrix_source %||% paste0(run$value$settings$assay, "/", run$value$settings$layer)
    row <- c(row, compare(crb, truth))
    row <- c(row, compare_image(file.path(work, "release"), case$image))
  }
  row$seconds_total <- proc.time()[["elapsed"]] - t0
  str(row)
  rows[[id]] <- as.data.frame(lapply(row, function(x) if (is.null(x)) NA else x),
                              stringsAsFactors = FALSE)
}
all_cols <- unique(unlist(lapply(rows, names)))
rows <- lapply(rows, function(r) { r[setdiff(all_cols, names(r))] <- NA; r[all_cols] })
out <- do.call(rbind, rows)
utils::write.csv(out, file.path(bv_root, "results", Sys.getenv("B_OUT", "B_end_to_end.csv")), row.names = FALSE)
print(t(out))
