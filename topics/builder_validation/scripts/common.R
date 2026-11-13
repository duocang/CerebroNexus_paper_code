## Shared helpers for the builder_validation experiments.
##
## Loads CerebroNexus from the topic library (env/rlib) and sources the Builder
## runtime from the installed package in the order inst/builder/app.R uses,
## leaving out the UI, the Shiny server programs and the worker/session files.
## The headless route is the one the package tests use
## (tests/testthat/test-builder-end-to-end.R):
##   builder_seurat_file_adapter() -> builder_adapter_inspect()      (profile)
##   builder_default_settings() + builder_recommend_metadata()
##   builder_snapshot_seurat() -> builder_freeze_plan()              (plan)
##   builder_coordinator_prepare() -> builder_execute_plan()         (build)
##   builder_coordinator_publish()                                   (publish)

`%||%` <- function(a, b) if (is.null(a)) b else a
Sys.setenv(LANGUAGE = "en")

bv_root <- local({
  args <- commandArgs(trailingOnly = FALSE)
  file <- sub("^--file=", "", args[grepl("^--file=", args)])
  dir <- normalizePath(if (length(file)) dirname(file[[1L]]) else ".", mustWork = TRUE)
  while (!file.exists(file.path(dir, "scripts", "common.R")) && dirname(dir) != dir) {
    dir <- dirname(dir)
  }
  dir
})
## env/ and data/ may be symlinks to an external volume; the Builder refuses
## symbolic links in source and output paths, so use the resolved paths.
bv_lib <- normalizePath(file.path(bv_root, "env", "rlib"), mustWork = TRUE)
dir.create(file.path(bv_root, "data"), showWarnings = FALSE)
bv_data <- normalizePath(file.path(bv_root, "data"), mustWork = TRUE)
.libPaths(c(bv_lib, .libPaths()))
suppressPackageStartupMessages({
  library(CerebroNexus)
  library(Matrix)
})
stopifnot(startsWith(find.package("CerebroNexus"), bv_lib))

## The revision under test is the one in topics/cerebronexus.pin; nothing here
## names a commit or a version. scripts/install_cerebronexus.sh records what it
## installed in env/installed.txt. A run stops only when that is not the pin.
source(file.path(bv_root, "..", "pin.R"), local = TRUE)
bv_pin <- read_pin(file.path(bv_root, "..", "cerebronexus.pin"))
bv_installed <- local({
  path <- file.path(bv_root, "env", "installed.txt")
  if (!file.exists(path)) {
    stop("env/installed.txt is missing: run scripts/install_cerebronexus.sh (it installs the pinned commit)",
         call. = FALSE)
  }
  lines <- trimws(readLines(path, warn = FALSE))
  kv <- strsplit(lines[grepl("=", lines, fixed = TRUE)], "=", fixed = TRUE)
  stats::setNames(
    vapply(kv, function(x) paste(x[-1L], collapse = "="), ""),
    vapply(kv, `[`, "", 1L)
  )
})
bv_commit <- bv_installed[["commit"]]
bv_version <- as.character(utils::packageVersion("CerebroNexus", lib.loc = bv_lib))
## Suffix of every result file of a run on this revision: first 9 characters of the commit.
bv_suffix <- substr(bv_commit, 1L, 9L)
if (!identical(bv_commit, bv_pin$commit)) {
  stop(sprintf("env/rlib holds CerebroNexus %s, the pin (topics/cerebronexus.pin) is %s: run scripts/install_cerebronexus.sh",
               bv_commit, bv_pin$commit), call. = FALSE)
}
if (!identical(bv_version, bv_pin$version)) {
  stop(sprintf("installed CerebroNexus version %s, the pin says %s", bv_version, bv_pin$version), call. = FALSE)
}

bv_builder_dir <- system.file("builder", package = "CerebroNexus", mustWork = TRUE)

## Builder runtime for the headless route, loaded the way inst/builder/app.R
## loads it: the `source()` calls at the top level of app.R name the files and
## their order, so a file that moves or goes away is followed (or skipped) here
## without an edit. Left out are the files of the browser interface and of the
## Shiny session (ui/, server/, worker, session, loading, diagnostics, async,
## spatial_alignment_server). The HLA core is taken from the package namespace,
## as app.R does for an installed package. Files app.R names but the install
## does not have are listed in `attr(rt, "skipped")`; a function a script then
## calls and does not find fails there, by name.
bv_runtime_skip <- "^(ui/|server/|worker\\.R$|session\\.R$|loading\\.R$|diagnostics\\.R$|async\\.R$|spatial_alignment_server\\.R$)"

bv_runtime_files <- function(dir = bv_builder_dir) {
  exprs <- parse(file.path(dir, "app.R"), keep.source = FALSE, encoding = "UTF-8")
  files <- character()
  for (e in exprs) {
    if (!is.call(e) || !identical(e[[1L]], as.name("source"))) next
    target <- tryCatch(eval(e[[2L]], baseenv()), error = function(err) NULL)
    if (is.character(target) && length(target) == 1L) files <- c(files, target)
  }
  files <- gsub("\\\\", "/", files)
  files <- files[!grepl(bv_runtime_skip, files)]
  present <- file.exists(file.path(dir, files))
  structure(files[present], skipped = files[!present])
}

bv_load_runtime <- function() {
  rt <- new.env(parent = globalenv())
  rt$`%||%` <- `%||%`
  old <- setwd(bv_builder_dir)
  on.exit(setwd(old), add = TRUE)
  base::source("prerequisite.R", local = rt, encoding = "UTF-8")
  files <- bv_runtime_files()
  hla <- tryCatch(utils::getFromNamespace(".viewerHLACore", "CerebroNexus"), error = function(e) NULL)
  hla_done <- FALSE
  for (file in files) {
    ## app.R takes the HLA core from the namespace right after the spatial files.
    if (!hla_done && identical(file, "manifest.R")) {
      if (is.function(hla)) list2env(hla(), envir = rt)
      hla_done <- TRUE
    }
    rt$builder_source_utf8(file, envir = rt)
  }
  if (!hla_done && is.function(hla)) list2env(hla(), envir = rt)
  attr(rt, "runtime_files") <- files
  attr(rt, "skipped") <- attr(files, "skipped")
  rt
}

bv_sha256 <- function(path) {
  out <- system2("shasum", c("-a", "256", shQuote(path)), stdout = TRUE)
  unname(strsplit(out, " ")[[1L]][[1L]])
}

## Run `expr`, keeping its value or error and every warning.
bv_capture <- function(expr) {
  warnings <- character()
  value <- withCallingHandlers(
    tryCatch(expr, error = function(e) structure(list(e), class = "bv_error")),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  error <- if (inherits(value, "bv_error")) conditionMessage(value[[1L]]) else NULL
  list(
    value = if (is.null(error)) value else NULL,
    error = error,
    warnings = unique(warnings)
  )
}

bv_one_line <- function(x, max = 300L) {
  x <- paste(x, collapse = " | ")
  x <- gsub("[\r\n\t]+", " ", x)
  x <- gsub("\\s+", " ", x)
  if (nchar(x) > max) paste0(substr(x, 1L, max), "...") else x
}

## Profile stage: open the source with the Builder's registered reader (file)
## or as an in-memory example, and inspect it.
bv_profile <- function(rt, input = NULL, object = NULL, id = "dataset") {
  adapter <- if (!is.null(input)) {
    rt$builder_seurat_file_adapter(input)
  } else {
    rt$builder_example_adapter(id, object)
  }
  rt$builder_adapter_inspect(adapter)
}

## Review of the metadata policy, copied from builder_e2e_review_metadata_policy()
## in tests/testthat/helper-builder-end-to-end.R: every non-blocking column that
## is required, recommended for the CRB or a group is included, the rest
## excluded, as an author confirming Review would leave it.
bv_review_metadata_policy <- function(recommendation, groups) {
  policy <- unserialize(serialize(recommendation, NULL, version = 3L))
  for (id in names(policy$columns)) {
    record <- policy$columns[[id]]
    if (identical(record$disposition, "blocking")) next
    include <- isTRUE(record$retain_in_crb) || isTRUE(record$required) || id %in% groups
    disposition <- if (include) "included" else "excluded"
    record$value <- disposition
    record$disposition <- disposition
    record$effective_included <- identical(disposition, "included")
    record$retain_in_crb <- include
    record$group_enabled <- id %in% groups
    record$forced <- isTRUE(record$forced %||% record$required)
    record$requires_confirmation <- FALSE
    record$group_eligible <- id %in% groups
    record$preview_allowed <- id %in% groups
    policy$columns[[id]] <- record
  }
  dispositions <- vapply(policy$columns, `[[`, character(1), "disposition")
  retained <- vapply(policy$columns, `[[`, logical(1), "retain_in_crb")
  ids <- names(policy$columns)
  policy$retained <- ids[retained]
  policy$groups <- intersect(ids, groups)
  policy$forced <- ids[vapply(policy$columns, `[[`, logical(1), "forced")]
  policy$included <- ids[retained]
  policy$attention <- ids[dispositions == "attention"]
  policy$excluded <- ids[!retained]
  policy$blocking <- ids[dispositions == "blocking"]
  policy$value <- policy$retained
  policy$requires_confirmation <- length(policy$attention) > 0L || length(policy$blocking) > 0L
  policy
}

## Configure defaults and Review, as builder_e2e_entry() in the package tests
## does: recommended groups/projections/organism, embedded backend.
bv_settings <- function(rt, inspected, label, configure = list(), work) {
  lp <- inspected$legacy_profile
  required <- c(lp$nUMI, lp$nGene)
  metadata <- rt$builder_recommend_metadata(
    inspected$profile,
    required = required,
    dependency_ids = if (length(required) == 2L) {
      stats::setNames(list("core.qc.nUMI", "core.qc.nGene"), required)
    } else {
      list()
    }
  )
  groups <- as.character(lp$group_preselect)
  projections <- as.character(lp$reduction_preselect)
  recommendations <- list(
    metadata = metadata,
    groups = list(value = groups[1L], included = groups),
    projections = list(value = projections[1L], included = projections),
    organism = list(value = lp$organism_guess),
    nomenclature = list(value = "name"),
    backend = list(value = "embedded")
  )
  settings <- rt$builder_default_settings(
    lp, label,
    recommendations = recommendations,
    dataset_profile = inspected$profile
  )
  if (length(lp$organism_guess) && !is.na(lp$organism_guess[1L])) {
    settings$organism <- lp$organism_guess
  }
  review_groups <- as.character(lp$group_candidates)
  settings$metadata_policy <- bv_review_metadata_policy(metadata, review_groups)
  settings$groups <- review_groups
  settings$included_groups <- review_groups
  settings$default_group <- lp$group_preselect[1L]
  if (length(inspected$source_images %||% list())) {
    seeded <- rt$builder_source_image_settings(
      inspected$source_images,
      file.path(work, "source-images")
    )
    settings$images <- utils::modifyList(settings$images %||% list(), seeded)
  }
  if (length(configure)) settings <- utils::modifyList(settings, configure)
  ## Groups chosen on Configure (when the Builder offers none of its own).
  if (!is.null(configure$groups)) {
    settings$metadata_policy <- bv_review_metadata_policy(metadata, configure$groups)
    settings$included_groups <- configure$groups
    settings$default_group <- configure$default_group %||% configure$groups[1L]
  }
  settings
}

## Plan stage: snapshot the object and freeze a BuildPlan.
bv_plan <- function(rt, id, inspected, settings, input, work, release,
                    make_app = TRUE, overwrite = FALSE) {
  snapshot <- rt$builder_snapshot_seurat(
    inspected$object,
    file.path(work, "snapshot"),
    available_bytes = 2^40
  )
  entry <- list(
    id = id, source_id = id, output_id = id,
    path = input %||% id, filename = basename(input %||% id),
    source_origin = "upload",
    format = inspected$format,
    profile = inspected$legacy_profile,
    dataset_profile = inspected$profile,
    snapshot = snapshot,
    revision = 1L,
    levels = inspected$levels %||% list(),
    settings = settings
  )
  plan <- rt$builder_freeze_plan(
    list(entry),
    release,
    make_app = make_app,
    overwrite = overwrite,
    app_options = if (make_app) list(launch_browser = FALSE, show_upload_ui = FALSE) else list()
  )
  if (!is.null(plan$error)) {
    err <- plan$error
    stop("BuildPlan was not frozen: ", bv_one_line(
      if (is.list(err)) unlist(err[intersect(c("message", "code"), names(err))]) %||% unlist(err) else err
    ))
  }
  list(plan = plan, snapshot = snapshot, entry = entry)
}

## Build stage: assign a stage through the coordinator and execute the plan.
bv_build <- function(rt, planned, id, build_id) {
  handle <- rt$builder_coordinator_prepare(planned$plan, build_id)
  result <- rt$builder_execute_plan(
    planned$plan,
    handle$stage,
    stats::setNames(list(planned$snapshot), id)
  )
  result$build_id <- handle$build_id
  if (!identical(result$state, "success")) {
    stop("Build failed: ", bv_one_line(result$error %||% result$state))
  }
  list(handle = handle, result = result)
}

## Publish stage.
bv_publish <- function(rt, built, ...) {
  rt$builder_coordinator_publish(built$handle, built$result, ...)
}

## Whole route for one source; returns every intermediate.
bv_route <- function(rt, id, label, input = NULL, object = NULL, work,
                     release, configure = list(), make_app = TRUE,
                     overwrite = FALSE, publish = TRUE, publish_args = list()) {
  dir.create(work, recursive = TRUE, showWarnings = FALSE)
  out <- list(stage = "profile")
  inspected <- bv_profile(rt, input, object, id)
  out$inspected <- inspected
  out$stage <- "plan"
  settings <- bv_settings(rt, inspected, label, configure, work)
  planned <- bv_plan(rt, id, inspected, settings, input, work, release,
                     make_app = make_app, overwrite = overwrite)
  out$planned <- planned
  out$stage <- "build"
  built <- bv_build(rt, planned, id, paste0(id, "-", format(Sys.time(), "%H%M%OS3")))
  out$built <- built
  if (publish) {
    out$stage <- "publish"
    out$published <- do.call(bv_publish, c(list(rt, built), publish_args))
  }
  out$stage <- "done"
  out
}

## Read a CRB written by the Builder.
bv_read_crb <- function(path) readCerebro(path)

## Compare a published CRB with its source Seurat object.
bv_compare <- function(crb_path, object, settings) {
  crb <- bv_read_crb(crb_path)
  assay <- settings$assay
  layer <- settings$layer
  src <- SeuratObject::LayerData(object, assay = assay, layer = layer)
  out <- list()
  cells <- crb$getCellNames()
  out$n_cells_source <- ncol(src)
  out$n_cells_crb <- length(cells)
  out$cell_ids_identical <- identical(cells, colnames(src))
  out$cell_ids_same_set <- setequal(cells, colnames(src))
  genes <- crb$getGeneNames()
  out$n_genes_source <- nrow(src)
  out$n_genes_crb <- length(genes)
  out$gene_ids_identical <- identical(genes, rownames(src))
  out$gene_ids_same_set <- setequal(genes, rownames(src))
  expr <- tryCatch(crb$getExpressionMatrix(), error = function(e) NULL)
  if (is.null(expr) || !length(expr)) {
    out$expr_max_abs_diff <- NA_real_
  } else {
    expr <- methods::as(expr, "CsparseMatrix")
    common_g <- intersect(rownames(src), rownames(expr))
    common_c <- intersect(colnames(src), colnames(expr))
    a <- methods::as(src[common_g, common_c, drop = FALSE], "CsparseMatrix")
    b <- expr[common_g, common_c, drop = FALSE]
    d <- a - b
    out$expr_max_abs_diff <- if (length(d@x)) max(abs(d@x)) else 0
    out$expr_nnz_source <- length(a@x)
    out$expr_nnz_crb <- length(methods::as(b, "CsparseMatrix")@x)
  }
  ## group labels: every group retained in the CRB vs source metadata
  meta <- crb$getMetaData()
  groups <- crb$getGroups()
  mism <- 0L
  checked <- character()
  for (g in groups) {
    if (!g %in% colnames(object@meta.data) || !g %in% colnames(meta)) next
    s <- as.character(object@meta.data[cells, g])
    o <- as.character(meta[[g]])
    mism <- mism + sum(!(s == o | (is.na(s) & is.na(o))), na.rm = TRUE) +
      sum(xor(is.na(s), is.na(o)))
    checked <- c(checked, g)
  }
  out$groups_checked <- paste(checked, collapse = ";")
  out$group_label_mismatches <- mism
  ## spatial coordinates per section
  spatial <- crb$spatial %||% list()
  out$spatial_sections_crb <- length(spatial)
  out$spatial_sections_source <- length(SeuratObject::Images(object))
  coord_diff <- 0
  coord_ids_ok <- TRUE
  for (section in intersect(names(spatial), SeuratObject::Images(object))) {
    sc <- SeuratObject::GetTissueCoordinates(object[[section]])
    rn <- if ("cell" %in% names(sc)) sc$cell else rownames(sc)
    sc <- as.matrix(sc[, c("x", "y")])
    rownames(sc) <- rn
    oc <- as.matrix(spatial[[section]]$coordinates[, c("x", "y")])
    coord_ids_ok <- coord_ids_ok && setequal(rownames(oc), rownames(sc))
    common <- intersect(rownames(oc), rownames(sc))
    coord_diff <- max(coord_diff, abs(oc[common, ] - sc[common, ]))
  }
  out$spatial_coord_max_abs_diff <- if (length(spatial)) coord_diff else NA_real_
  out$spatial_coord_ids_match <- if (length(spatial)) coord_ids_ok else NA
  list(summary = out, crb = crb)
}
