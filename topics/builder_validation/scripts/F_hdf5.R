## Experiment F3: HDF5 and immune-repertoire sidecars.
##
##  1. Storage of the H5 written by the Builder (B with B_BACKEND=h5, its
##     default gzip level 0) and of an H5 written with gzip level 6 through the
##     package route exportFromSeurat(h5_compression_level = 6) - the Builder
##     has no compression setting. All expression values of the level-6 CRB are
##     compared with the source.
##  2. Faults on copies of the Builder's Visium HDF5 App: the .h5 sidecar is
##     deleted, renamed, truncated, replaced by another dataset's valid H5,
##     replaced by a valid H5 with the same cells and genes but changed values,
##     and replaced by the level-6 H5 of the same data. Each copy is read with
##     readCerebro() and started as an App (viewer.R, headless Chrome, one gene).
##  3. The Builder never writes a .immune.qs2 for these data (the package
##     threshold is 100,000 repertoire rows), so the immune sidecar is made with
##     the package route saveCerebro(immune_sidecar = "always") from the
##     complete_viewer CRB, put into an App with createShinyApp(), and the same
##     faults are applied to it.
##
## Usage: Rscript scripts/F_hdf5.R   (after B_BACKEND=h5 B_OUT=F_hdf5_end_to_end.csv)
## Writes results/F_hdf5_storage.csv and results/F_hdf5_faults.csv.

source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))), "common.R"))
source(file.path(bv_root, "scripts", "viewer.R"))
suppressPackageStartupMessages(library(SeuratObject))

root <- file.path(bv_data, "F", "hdf5")
unlink(root, recursive = TRUE)
dir.create(root, recursive = TRUE, showWarnings = FALSE)
b_h5 <- file.path(bv_data, "B_h5")
visium_app <- file.path(b_h5, "visium", "release", "cerebro_app")
pbmc_app <- file.path(b_h5, "pbmc_seurat", "release", "cerebro_app")
stopifnot(dir.exists(visium_app), dir.exists(pbmc_app))
private_of <- function(app, pattern) list.files(file.path(app, "private-data"), pattern = pattern, full.names = TRUE)

h5_filters <- function(path) {
  fid <- rhdf5::H5Fopen(path, flags = "H5F_ACC_RDONLY")
  on.exit(rhdf5::H5Fclose(fid), add = TRUE)
  did <- rhdf5::H5Dopen(fid, "expression/data")
  on.exit(rhdf5::H5Dclose(did), add = TRUE)
  pid <- rhdf5::H5Dget_create_plist(did)
  on.exit(rhdf5::H5Pclose(pid), add = TRUE)
  n <- rhdf5::H5Pget_nfilters(pid)
  if (!n) return("none")
  paste(vapply(seq_len(n), function(i) {
    f <- rhdf5::H5Pget_filter(pid, i)
    paste0(f[[2]], if (length(f) >= 3 && length(f[[3]])) paste0("(", paste(f[[3]], collapse = ","), ")"))
  }, ""), collapse = "+")
}
expr_of <- function(crb_path) methods::as(readCerebro(crb_path)$getExpressionMatrix(), "CsparseMatrix")
max_diff <- function(a, b) {
  a <- methods::as(a, "CsparseMatrix"); b <- methods::as(b, "CsparseMatrix")
  if (!identical(dim(a), dim(b)) || !identical(dimnames(a), dimnames(b))) return(NA_real_)
  d <- a - b
  if (length(d@x)) max(abs(d@x)) else 0
}

## ---- 1. storage ---------------------------------------------------------------
visium <- readRDS(file.path(bv_data, "inputs", "visium_anterior1.rds"))
src <- LayerData(visium, assay = "Spatial", layer = "data")
storage <- list()
for (id in c("visium", "xenium", "pbmc_seurat", "pbmc_sce", "pbmc_sce_own_qc", "pbmc3k_h5ad")) {
  h5 <- private_of(file.path(b_h5, id, "release", "cerebro_app"), "\\.h5$")
  if (!length(h5)) next
  storage[[id]] <- data.frame(build = paste("Builder, B_BACKEND=h5:", id), file = basename(h5),
                              bytes = file.size(h5), filters = h5_filters(h5), stringsAsFactors = FALSE)
}
level6_dir <- file.path(root, "level6")
dir.create(level6_dir)
level6_crb <- file.path(level6_dir, "visium_level6.crb")
exportFromSeurat(visium, assay = "Spatial", slot = "data", file = level6_crb,
                 experiment_name = "Visium level 6", organism = "mm", groups = "cluster",
                 nUMI = "nCount_Spatial", nGene = "nFeature_Spatial",
                 expression_matrix_mode = "h5", h5_compression_level = 6L, verbose = FALSE)
level6_h5 <- list.files(level6_dir, pattern = "\\.h5$", full.names = TRUE)
level6_diff <- max_diff(src, expr_of(level6_crb))
storage$level6 <- data.frame(build = "exportFromSeurat(h5_compression_level = 6): visium",
                             file = basename(level6_h5), bytes = file.size(level6_h5),
                             filters = h5_filters(level6_h5), stringsAsFactors = FALSE)
storage <- do.call(rbind, storage)
storage$expr_max_abs_diff_vs_source <- NA_real_
storage$expr_max_abs_diff_vs_source[storage$build == storage$build[nrow(storage)]] <- level6_diff
utils::write.csv(storage, file.path(bv_root, "results", "F_hdf5_storage.csv"), row.names = FALSE)
print(storage)

## ---- 2./3. faults -----------------------------------------------------------
rows <- list()
fault_case <- function(kind, base_app, sidecar_pattern, case, mutate, gene, expect_ok = FALSE,
                       read_check) {
  dir <- file.path(root, kind, case)
  dir.create(dir, recursive = TRUE)
  file.copy(base_app, dir, recursive = TRUE, copy.mode = TRUE)
  app <- file.path(dir, basename(base_app))
  sidecar <- private_of(app, sidecar_pattern)[[1L]]
  mutate(sidecar, app)
  crb <- private_of(app, "\\.crb$")[[1L]]
  read <- bv_capture(read_check(crb))
  v <- bv_viewer_check(app, dir, gene, label = paste(kind, case, sep = "_"), timeout = 60000)
  stderr <- tryCatch(readLines(file.path(dir, "viewer-logs", paste0(kind, "_", case, ".stderr"))),
                     error = function(e) character())
  errs <- grep("rror|arning:|nvalid|not match|missing|cannot", stderr, value = TRUE)
  read_value <- if (is.null(read$error)) read$value else NA
  explicit <- !is.null(read$error) || length(errs) > 0 || !isTRUE(v$viewer_loaded)
  silent_wrong <- is.null(read$error) && isTRUE(v$viewer_loaded) && !isTRUE(read_value == 0)
  row <- data.frame(
    sidecar = kind, case = case,
    expected = if (expect_ok) "accepted, values identical" else "rejected with an explicit error",
    read_error = bv_one_line(read$error %||% "", 300),
    read_value_max_abs_diff = if (is.numeric(read_value)) read_value else NA_real_,
    app_http = v$http_status, viewer_loaded = v$viewer_loaded,
    viewer_error = bv_one_line(v$viewer_error, 300),
    app_stderr_errors = bv_one_line(utils::head(errs, 3), 300),
    stringsAsFactors = FALSE)
  row$result <- if (expect_ok) {
    if (isTRUE(v$viewer_loaded) && isTRUE(read_value == 0)) "pass" else "fail"
  } else if (silent_wrong) "fail (wrong data shown without error)" else if (explicit) "pass" else "fail"
  cat(sprintf("[%s] %s %s\n", row$result, kind, case))
  rows[[length(rows) + 1L]] <<- row
}

## H5 sidecar of the Builder's Visium HDF5 App
visium_crb <- private_of(visium_app, "\\.crb$")[[1L]]
truth_expr <- expr_of(visium_crb)
h5_read <- function(crb) max_diff(truth_expr, expr_of(crb))
h5_cases <- list(
  control = list(function(s, a) NULL, TRUE),
  delete = list(function(s, a) unlink(s), FALSE),
  rename = list(function(s, a) file.rename(s, paste0(s, ".bak")), FALSE),
  truncate = list(function(s, a) {
    x <- readBin(s, "raw", file.size(s)); writeBin(x[seq_len(length(x) %/% 2)], s)
  }, FALSE),
  replace_other_dataset = list(function(s, a) file.copy(private_of(pbmc_app, "\\.h5$")[[1L]], s, overwrite = TRUE), FALSE),
  replace_same_ids_changed_values = list(function(s, a) {
    m <- truth_expr
    m@x <- m@x * 2
    unlink(s)
    HDF5Array::writeTENxMatrix(methods::as(Matrix::t(m), "CsparseMatrix"), s, group = "expression", level = 0L)
  }, FALSE),
  ## same values, other bytes: accepted without a checksum, refused with one
  replace_level6_same_content = list(function(s, a) file.copy(level6_h5, s, overwrite = TRUE),
                                     !nzchar(Sys.getenv("F_H5_CHECKSUM")))
)
for (case in if (nzchar(Sys.getenv("F_SKIP_H5"))) character() else names(h5_cases)) {
  fault_case("h5", visium_app, "\\.h5$", case, h5_cases[[case]][[1L]], "Ttr",
             expect_ok = h5_cases[[case]][[2L]], read_check = h5_read)
}

## Immune sidecar: complete_viewer CRB re-saved with immune_sidecar = "always".
cv_crb <- list.files(file.path(bv_data, "F", "selection", "base", "release", "cerebro_app", "private-data"),
                     pattern = "\\.crb$", full.names = TRUE)[[1L]]
cv_part_crb <- list.files(file.path(bv_data, "F", "selection", "immune_part", "release", "cerebro_app", "private-data"),
                          pattern = "\\.crb$", full.names = TRUE)[[1L]]
imm_dir <- file.path(root, "immune_source")
dir.create(imm_dir)
saveCerebro(readCerebro(cv_crb), file.path(imm_dir, "cv.crb"), immune_sidecar = "always")
saveCerebro(readCerebro(cv_part_crb), file.path(imm_dir, "cv_part.crb"), immune_sidecar = "always")
print(list.files(imm_dir))
imm_app_root <- file.path(root, "immune_app")
createShinyApp(c(cv = file.path(imm_dir, "cv.crb")), result_dir = imm_app_root, launch_browser = FALSE, verbose = FALSE)
imm_app <- imm_app_root
print(list.files(imm_app, recursive = TRUE, pattern = "crb|qs2"))
imm_truth <- readCerebro(cv_crb)$getImmuneRepertoire()
imm_read <- function(crb) {
  r <- readCerebro(crb)$getImmuneRepertoire()
  if (identical(lapply(r, as.data.frame), lapply(imm_truth, as.data.frame))) 0 else 1
}
imm_cases <- list(
  control = list(function(s, a) NULL, TRUE),
  delete = list(function(s, a) unlink(s), FALSE),
  rename = list(function(s, a) file.rename(s, paste0(s, ".bak")), FALSE),
  truncate = list(function(s, a) {
    x <- readBin(s, "raw", file.size(s)); writeBin(x[seq_len(length(x) %/% 2)], s)
  }, FALSE),
  replace_other_valid = list(function(s, a) file.copy(file.path(imm_dir, "cv_part.immune.qs2"), s, overwrite = TRUE), FALSE)
)
gene <- readCerebro(cv_crb)$getGeneNames()[[1L]]
for (case in names(imm_cases)) {
  fault_case("immune_qs2", imm_app, "\\.immune\\.qs2$", case, imm_cases[[case]][[1L]], gene,
             expect_ok = imm_cases[[case]][[2L]], read_check = imm_read)
}

out <- do.call(rbind, rows)
utils::write.csv(out, file.path(bv_root, "results", "F_hdf5_faults.csv"), row.names = FALSE)
print(out[, c("sidecar", "case", "read_error", "viewer_loaded", "result")])
