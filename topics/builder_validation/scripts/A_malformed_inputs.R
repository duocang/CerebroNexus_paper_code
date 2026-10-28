## Experiment A: malformed and perturbed inputs.
##
## Each case changes one thing in a real input (the Visium anterior1 Seurat
## object unless noted) and runs the headless route profile -> plan -> build
## -> publish with the same Review defaults as Experiment B. For each case we
## record the stage where the route stopped, whether it stopped with an
## explicit error, finished with warnings, or finished silently, the message,
## and, if a CRB was published, whether its content equals the (perturbed)
## source: cell and gene IDs, every expression value, every coordinate (by
## barcode), every group label.
##
## Usage: Rscript scripts/A_malformed_inputs.R [case ...]
## Writes results/A_malformed_inputs.csv.

source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))), "common.R"))
suppressPackageStartupMessages(library(SeuratObject))

inputs <- file.path(bv_data, "inputs")
root <- file.path(bv_data, "A")
dir.create(root, recursive = TRUE, showWarnings = FALSE)
rt <- bv_load_runtime()

visium_rds <- file.path(inputs, "visium_anterior1.rds")
visium_png <- file.path(inputs, "visium_anterior1_he.png")
h5ad <- file.path(inputs, "pbmc3k.h5ad")
base <- readRDS(visium_rds)
copy <- function(o) unserialize(serialize(o, NULL))

write_obj <- function(o, name) {
  path <- file.path(root, "inputs", name)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  saveRDS(o, path)
  path
}
write_bytes <- function(bytes, name) {
  path <- file.path(root, "inputs", name)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeBin(bytes, path)
  path
}
truncate_file <- function(src, fraction, name) {
  n <- file.size(src)
  con <- file(src, "rb")
  on.exit(close(con))
  write_bytes(readBin(con, "raw", n = floor(n * fraction)), name)
}
image_record <- function(path, section = "anterior1") {
  ins <- rt$builder_read_image(path)
  if (!is.null(ins$error)) stop("image: ", ins$error)
  d <- dim(png::readPNG(path))
  rec <- rt$builder_alignment_record(
    source = list(name = basename(path), type = ins$mime, size = ins$bytes),
    base_bounds = list(xmin = 0, xmax = d[2] / 0.05163511, ymin = 0, ymax = d[1] / 0.05163511),
    section = list(id = section, kind = "spatial"),
    source_path = ins$source_path
  )
  rec$source_content_md5 <- ins$source_content_md5
  rec
}

## Visium image (VisiumV2) coordinate slot helpers.
centroids <- function(o, s = "anterior1") o[[s]]@boundaries$centroids
set_centroids <- function(o, cents, s = "anterior1") {
  img <- o[[s]]
  img@boundaries$centroids <- cents
  o@images[[s]] <- img
  o
}

## ---- cases --------------------------------------------------------------------
## Each case returns list(input = path, configure = list(), before_build = fn,
## object = the perturbed object to compare against, or NULL).
cases <- list(
  A01_truncated_rds = function() list(input = truncate_file(visium_rds, 0.5, "truncated.rds")),
  A02_not_rds_bytes = function() list(input = write_bytes(readBin(visium_png, "raw", file.size(visium_png)), "png_named.rds")),
  A03_spatial_removed = function() {
    o <- copy(base)
    o@images <- list()
    list(input = write_obj(o, "no_spatial.rds"), object = o)
  },
  A04a_image_file_missing = function() {
    tmp <- file.path(root, "inputs", "he_deleted.png")
    dir.create(dirname(tmp), recursive = TRUE, showWarnings = FALSE)
    file.copy(visium_png, tmp, overwrite = TRUE)
    rec <- image_record(tmp)
    list(input = visium_rds, configure = list(images = list(anterior1 = rec)),
         before_plan = function() unlink(tmp), object = base)
  },
  A04b_image_replaced_after_review = function() {
    tmp <- file.path(root, "inputs", "he_replaced.png")
    file.copy(visium_png, tmp, overwrite = TRUE)
    rec <- image_record(tmp)
    list(input = visium_rds, configure = list(images = list(anterior1 = rec)),
         before_build = function() {
           a <- png::readPNG(visium_png)
           png::writePNG(1 - a, tmp)
         },
         object = base, image = tmp)
  },
  A04c_image_not_an_image = function() {
    tmp <- file.path(root, "inputs", "not_image.png")
    writeBin(charToRaw(strrep("not a png ", 100)), tmp)
    list(input = visium_rds, configure_fn = function() list(images = list(anterior1 = image_record(tmp))),
         object = base)
  },
  A05a_assay_absent = function() list(input = visium_rds, configure = list(assay = "RNA"), object = base),
  A05b_layer_absent = function() {
    o <- copy(base)
    o[["Spatial"]]$data <- NULL
    list(input = write_obj(o, "no_data_layer.rds"), configure = list(layer = "data"), object = o)
  },
  A06_duplicated_barcodes = function() {
    ## Seurat refuses duplicated cell names, a SingleCellExperiment keeps them.
    m <- LayerData(base, assay = "Spatial", layer = "counts")
    colnames(m)[2:11] <- colnames(m)[1]
    sce <- SingleCellExperiment::SingleCellExperiment(
      assays = list(counts = m, logcounts = log1p(m)),
      colData = S4Vectors::DataFrame(cluster = base$cluster, row.names = colnames(m))
    )
    list(input = write_obj(sce, "duplicated_barcodes_sce.rds"))
  },
  A07a_coords_subset = function() {
    o <- copy(base)
    keep <- sample(Cells(o), floor(ncol(o) / 2))
    o@images$anterior1 <- subset(o[["anterior1"]], cells = keep)
    list(input = write_obj(o, "coords_subset.rds"), object = o)
  },
  A07b_coords_barcodes_unmatched = function() {
    o <- copy(base)
    ce <- centroids(o)
    ce@cells <- paste0(ce@cells, "-unmatched")
    o <- set_centroids(o, ce)
    list(input = write_obj(o, "coords_unmatched.rds"), object = o)
  },
  A07c_coords_row_order_shuffled = function() {
    o <- copy(base)
    ce <- centroids(o)
    perm <- sample(length(ce@cells))
    ce@coords <- ce@coords[perm, , drop = FALSE]
    ce@cells <- ce@cells[perm]
    o <- set_centroids(o, ce)
    list(input = write_obj(o, "coords_shuffled.rds"), object = o)
  },
  A08_empty_group_column = function() {
    o <- copy(base)
    o$empty_group <- factor(rep("", ncol(o)))
    list(input = write_obj(o, "empty_group.rds"), object = o)
  },
  A09_all_na_column = function() {
    o <- copy(base)
    o$all_na <- factor(rep(NA_character_, ncol(o)))
    list(input = write_obj(o, "all_na.rds"), object = o)
  },
  A10a_zero_cells = function() {
    m <- LayerData(base, assay = "Spatial", layer = "counts")[, 0]
    sce <- SingleCellExperiment::SingleCellExperiment(assays = list(counts = m))
    list(input = write_obj(sce, "zero_cells_sce.rds"))
  },
  A10b_zero_genes = function() {
    m <- LayerData(base, assay = "Spatial", layer = "counts")[0, ]
    sce <- SingleCellExperiment::SingleCellExperiment(assays = list(counts = m))
    list(input = write_obj(sce, "zero_genes_sce.rds"))
  },
  A11_na_expression_values = function() {
    o <- copy(base)
    d <- LayerData(o, assay = "Spatial", layer = "data")
    d@x[1:100] <- NA
    LayerData(o, assay = "Spatial", layer = "data") <- d
    list(input = write_obj(o, "na_expression.rds"), object = o)
  },
  A12_duplicate_nUMI_column = function() {
    o <- copy(base)
    o$nUMI <- o$nCount_Spatial
    o$nGene <- o$nFeature_Spatial
    list(input = write_obj(o, "dup_numi.rds"), object = o)
  },
  A13a_h5ad_truncated = function() list(input = truncate_file(h5ad, 0.5, "truncated.h5ad")),
  A13b_h5ad_header_only = function() list(input = truncate_file(h5ad, 4096 / file.size(h5ad), "header_only.h5ad"))
)
only <- commandArgs(trailingOnly = TRUE)
if (length(only)) cases <- cases[intersect(names(cases), only)]

## ---- content check --------------------------------------------------------------
check_content <- function(crb_path, o, settings) {
  crb <- readCerebro(crb_path)
  m <- LayerData(o, assay = settings$assay, layer = settings$layer)
  cells <- crb$getCellNames()
  r <- list(cells_equal = identical(cells, colnames(m)),
            genes_equal = identical(crb$getGeneNames(), rownames(m)))
  e <- methods::as(crb$getExpressionMatrix(), "CsparseMatrix")
  if (identical(dim(e), dim(m))) {
    a <- methods::as(m, "CsparseMatrix")
    na_src <- sum(is.na(a@x))
    na_out <- sum(is.na(e@x))
    d <- a - e
    r$expr_max_abs_diff <- suppressWarnings(max(abs(d@x), na.rm = TRUE))
    r$expr_na_source <- na_src
    r$expr_na_crb <- na_out
  }
  meta <- crb$getMetaData()
  mism <- 0L
  for (g in crb$getGroups()) {
    if (!g %in% names(o@meta.data)) next
    s <- as.character(o@meta.data[cells, g])
    x <- as.character(meta[[g]])
    mism <- mism + sum(xor(is.na(s), is.na(x)) | (!is.na(s) & !is.na(x) & s != x))
  }
  r$group_mismatches <- mism
  r$groups_in_crb <- paste(crb$getGroups(), collapse = ";")
  r$meta_cols_in_crb <- paste(colnames(meta), collapse = ";")
  sp <- crb$spatial %||% list()
  r$spatial_sections <- paste(names(sp), collapse = ";")
  if ("anterior1" %in% Images(o)) {
    tc <- GetTissueCoordinates(o[["anterior1"]])
    rn <- if ("cell" %in% names(tc)) tc$cell else rownames(tc)
    src <- matrix(c(tc$x, tc$y), ncol = 2, dimnames = list(rn, c("x", "y")))
    if (!is.null(sp$anterior1)) {
      out <- as.matrix(sp$anterior1$coordinates[, c("x", "y")])
      common <- intersect(rownames(out), rownames(src))
      r$coords_in_crb <- nrow(out)
      r$coords_in_source <- nrow(src)
      r$coords_barcodes_matched <- length(common)
      r$coords_max_abs_diff_by_barcode <- if (length(common)) {
        max(abs(out[common, ] - src[common, ]))
      } else NA_real_
      r$coords_barcodes_not_cells <- sum(!rownames(out) %in% cells)
    } else {
      r$coords_in_crb <- 0L
      r$coords_in_source <- nrow(src)
    }
  }
  r
}

## ---- run -----------------------------------------------------------------------------
set.seed(7)
rows <- list()
for (id in names(cases)) {
  cat("\n==== ", id, " ====\n", sep = "")
  work <- file.path(root, "runs", id)
  unlink(work, recursive = TRUE)
  dir.create(work, recursive = TRUE)
  prepared <- bv_capture(cases[[id]]())
  if (!is.null(prepared$error)) {
    rows[[id]] <- data.frame(case = id, stopped_at = "prepare", outcome = "explicit error",
                             message = bv_one_line(prepared$error), stringsAsFactors = FALSE)
    next
  }
  case <- prepared$value
  t0 <- proc.time()[["elapsed"]]
  stage <- "profile"
  warnings <- character()
  run <- function(expr) {
    r <- bv_capture(expr)
    warnings <<- c(warnings, r$warnings)
    if (!is.null(r$error)) stop(structure(class = c("bv_stage_error", "error", "condition"),
                                          list(message = r$error, call = NULL)))
    r$value
  }
  result <- tryCatch({
    inspected <- run(bv_profile(rt, case$input, id = id))
    stage <- "plan"
    configure <- case[["configure", exact = TRUE]] %||% list()
    if (!is.null(case$configure_fn)) configure <- utils::modifyList(configure, run(case$configure_fn()))
    if (!is.null(case$before_plan)) case$before_plan()
    settings <- run(bv_settings(rt, inspected, id, configure, work))
    planned <- run(bv_plan(rt, id, inspected, settings, case$input, work, file.path(work, "release")))
    stage <- "build"
    if (!is.null(case$before_build)) case$before_build()
    built <- run(bv_build(rt, planned, id, paste0(id, "-A")))
    stage <- "publish"
    published <- run(bv_publish(rt, built))
    stage <- "done"
    list(settings = settings, published = published, inspected = inspected)
  }, bv_stage_error = function(e) e)
  row <- list(case = id, input = basename(case$input))
  if (inherits(result, "error")) {
    row$stopped_at <- stage
    row$outcome <- "explicit error"
    row$message <- bv_one_line(conditionMessage(result))
  } else {
    row$stopped_at <- "none (published)"
    row$outcome <- if (length(warnings)) "warning + output" else "silent output"
    row$message <- ""
  }
  row$warnings <- bv_one_line(unique(warnings))
  row$seconds <- proc.time()[["elapsed"]] - t0
  if (!inherits(result, "error")) {
    lp <- result$inspected$legacy_profile
    row$group_candidates <- paste(lp$group_candidates, collapse = ";")
    row$group_struck <- paste(names(lp$group_struck %||% list()), collapse = ";")
    crb_path <- result$published$built[[1L]]
    row$crb_written <- file.exists(crb_path)
    o <- case$object %||% result$inspected$object
    content <- bv_capture(check_content(crb_path, o, result$settings))
    if (!is.null(content$error)) {
      row$content_check_error <- bv_one_line(content$error)
    } else {
      row <- c(row, content$value)
    }
    if (!is.null(case$image)) {
      pub <- list.files(file.path(work, "release", "cerebro_app", "spatial-assets"), full.names = TRUE)
      row$published_image_equals_reviewed <- identical(
        png::readPNG(pub[[1L]]), png::readPNG(visium_png))
      row$published_image_equals_replaced <- identical(
        png::readPNG(pub[[1L]]), png::readPNG(case$image))
    }
  }
  str(row)
  rows[[id]] <- as.data.frame(lapply(row, function(x) if (is.null(x) || !length(x)) NA else x),
                              stringsAsFactors = FALSE)
}
all_cols <- unique(unlist(lapply(rows, names)))
rows <- lapply(rows, function(r) { r[setdiff(all_cols, names(r))] <- NA; r[all_cols] })
out <- do.call(rbind, rows)
utils::write.csv(out, file.path(bv_root, "results", Sys.getenv("A_OUT", "A_malformed_inputs.csv")), row.names = FALSE)
print(out[, c("case", "stopped_at", "outcome", "message")])
