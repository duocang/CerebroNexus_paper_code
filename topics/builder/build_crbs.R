## Build one CRB per public input through the CerebroNexus Builder's own
## import -> inspect -> freeze BuildPlan -> execute BuildPlan path, without the
## browser UI. Mirrors the Builder's import handler (inst/builder/server/imports.R):
## default settings, recommended metadata policy, pictures the source brings,
## then a CRB-only plan executed into a stage directory.
##
## Usage (from any directory):
##   Rscript --vanilla build_crbs.R <r_library> <inputs_dir> <out_dir>
## <r_library> holds the CerebroNexus revision of topics/cerebronexus.pin, installed with
## install_pin.R (which stamps the commit on the installation). The script reads the pin and the installed
## package, records both versions and fails only when the installed commit is not the pinned one.
## Everything else (Builder runtime, HLA core) is taken from the installed package.

args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 3L)
lib <- normalizePath(args[[1L]], mustWork = TRUE)
inputs_dir <- normalizePath(args[[2L]], mustWork = TRUE)
out_dir <- args[[3L]]
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out_dir <- normalizePath(out_dir, mustWork = TRUE)

## topics/cerebronexus.pin, found upwards from this script.
script_dir <- local({
  file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])
  dirname(normalizePath(file, mustWork = TRUE))
})
pin <- local({
  d <- script_dir
  while (!file.exists(file.path(d, "cerebronexus.pin"))) {
    if (identical(dirname(d), d)) stop("cerebronexus.pin not found above ", script_dir)
    d <- dirname(d)
  }
  lines <- trimws(readLines(file.path(d, "cerebronexus.pin"), warn = FALSE))
  lines <- lines[nzchar(lines) & !startsWith(lines, "#")]
  kv <- regmatches(lines, regexpr("=", lines), invert = TRUE)
  stats::setNames(vapply(kv, `[`, "", 2L), vapply(kv, `[`, "", 1L))
})

.libPaths(c(lib, .libPaths()))
suppressPackageStartupMessages(library(CerebroNexus))
pkg_dir <- find.package("CerebroNexus")
installed_version <- as.character(packageVersion("CerebroNexus"))
## The commit of the installation: the stamp install_pin.R leaves, or, for a library from the viewer_performance
## cache (<cache>/lib/<first 12 characters of the commit>), the library's folder name.
installed_commit <- if (file.exists(file.path(pkg_dir, "PIN_COMMIT"))) {
  trimws(readLines(file.path(pkg_dir, "PIN_COMMIT"), warn = FALSE)[[1L]])
} else {
  basename(lib)
}
cat("date:", format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), "\n")
cat("CerebroNexus", installed_version, "from", pkg_dir, "\n")
cat("installed commit:", installed_commit, " version:", installed_version, "\n")
cat("pinned commit:   ", pin[["commit"]], " version:", pin[["version"]], " ref:", pin[["ref"]], "\n")
if (nchar(installed_commit) < 12L || !startsWith(pin[["commit"]], installed_commit)) {
  stop("The installed CerebroNexus (", installed_commit, ") is not the pinned revision (", pin[["commit"]],
       "); install it with install_pin.R", call. = FALSE)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

## Builder runtime: the files inst/builder/app.R sources, read from that installed app.R in its order (UI,
## server and session files left out), so a file added, renamed or moved in the package is followed. The
## HLA core is taken from the package namespace, the way app.R does when it is not run from a checkout.
builder_dir <- system.file("builder", package = "CerebroNexus", mustWork = TRUE)
builder_files <- local({
  exprs <- parse(file.path(builder_dir, "app.R"), keep.source = FALSE)
  files <- character()
  for (e in exprs) {
    if (is.call(e) && (identical(e[[1L]], as.name("source")) ||
                       identical(e[[1L]], quote(base::source)))) {
      f <- eval(e[[2L]], baseenv())
      if (is.character(f) && length(f) == 1L) files <- c(files, f)
    }
  }
  skip <- c("loading.R", "diagnostics.R", "async.R", "worker.R", "session.R", "spatial_alignment_server.R")
  files <- files[!(startsWith(files, "ui") | startsWith(files, "server") | files %in% skip)]
  setdiff(files, "prerequisite.R")
})
rt <- new.env(parent = globalenv())
rt$`%||%` <- `%||%`
old_wd <- setwd(builder_dir)
base::source("prerequisite.R", local = rt, encoding = "UTF-8")
invisible(list2env(utils::getFromNamespace(".viewerHLACore", "CerebroNexus")(), envir = rt))
for (file in builder_files) {
  rt$builder_source_utf8(file, envir = rt)
}
setwd(old_wd)
cat("Builder runtime files (", length(builder_files), "): ", paste(builder_files, collapse = " "), "\n", sep = "")

sha256 <- function(path) unname(tools::sha256sum(path))

show_settings <- function(settings, when) {
  keys <- c("organism", "assay", "layer", "groups", "default_group", "reductions", "default_reduction")
  for (k in keys) {
    cat(sprintf("  %-18s %s\n", paste0(when, " ", k, ":"), paste(settings[[k]] %||% "<none>", collapse = ", ")))
  }
}

## `configure` holds what an author would pick on the Configure page when the
## Builder has no default for it (named settings fields).
build_one <- function(id, label, input, configure = list(), make_app = FALSE) {
  cat("\n==== ", id, " (", basename(input), ") ====\n", sep = "")
  work <- file.path(out_dir, "work", id)
  unlink(work, recursive = TRUE)
  dir.create(work, recursive = TRUE)

  adapter <- rt$builder_seurat_file_adapter(input)
  inspected <- rt$builder_adapter_inspect(adapter)
  object <- inspected$object
  cat("Builder reader:", inspected$format, "\n")
  cat("Seurat object:", ncol(object), "cells x", nrow(object), "features; assays",
      paste(SeuratObject::Assays(object), collapse = ","), "; images",
      paste(SeuratObject::Images(object), collapse = ","), "\n")

  settings <- rt$builder_default_settings(
    inspected$legacy_profile,
    label,
    dataset_profile = inspected$profile
  )
  metadata <- rt$builder_recommend_metadata(inspected$profile)
  settings$recommendations <- list(metadata = metadata)
  settings$metadata_policy <- metadata
  settings$expression_backend <- "embedded"
  cat("Group candidates:", paste(inspected$legacy_profile$group_candidates, collapse = ", "), "\n")
  cat("Reductions:", paste(inspected$legacy_profile$reductions %||% names(object@reductions), collapse = ", "), "\n")
  show_settings(settings, "default")
  if (length(configure)) {
    settings <- utils::modifyList(settings, configure)
    show_settings(settings, "configured")
  }
  if (length(inspected$source_images %||% list())) {
    seeded <- rt$builder_source_image_settings(
      inspected$source_images,
      file.path(work, "source-images")
    )
    settings$images <- utils::modifyList(settings$images %||% list(), seeded)
    cat("Source pictures placed for sections:", paste(names(seeded), collapse = ", "), "\n")
  }

  snapshot <- rt$builder_snapshot_seurat(
    object,
    file.path(work, "snapshot"),
    available_bytes = 2^40
  )
  entry <- list(
    id = id, source_id = id, output_id = id,
    path = input, filename = basename(input), source_origin = "upload",
    format = inspected$format,
    profile = inspected$legacy_profile,
    dataset_profile = inspected$profile,
    snapshot = snapshot,
    revision = 1L,
    levels = inspected$levels %||% list(),
    settings = settings
  )
  ## Tissue pictures are stored next to the CRB, which the Builder only allows
  ## for the "CRB files + Viewer App" output; the CRB itself is the same file.
  plan <- rt$builder_freeze_plan(
    list(entry),
    file.path(work, "release"),
    make_app = make_app,
    app_options = if (make_app) list(launch_browser = FALSE) else list()
  )
  if (!is.null(plan$error)) {
    stop("BuildPlan was not frozen: ", format(plan$error))
  }
  stage <- file.path(work, "stage")
  dir.create(stage)
  result <- rt$builder_execute_plan(plan, stage, stats::setNames(list(snapshot), id))
  cat("Output:", if (make_app) "CRB files + Viewer App" else "CRB only", "\n")
  cat("Build state:", result$state, "; publishable:", isTRUE(result$publishable), "\n")
  if (!identical(result$state, "success")) {
    stop("Build failed: ", result$error %||% "unknown")
  }
  crb <- file.path(out_dir, paste0(id, ".crb"))
  stopifnot(file.copy(result$built[[1L]], crb, overwrite = TRUE))
  invisible(crb)
}

## Counts read back from the written CRB, not from the source object.
describe_crb <- function(crb) {
  x <- readCerebro(crb)
  cells <- x$getCellNames()
  features <- x$getGeneNames()
  sections <- names(x$spatial %||% list())
  list(
    file = basename(crb),
    bytes = file.size(crb),
    sha256 = sha256(crb),
    cells = length(cells),
    features = length(features),
    prot_features = sum(startsWith(features, "prot:")),
    spatial_sections = length(sections),
    section_names = paste(sections, collapse = ";"),
    projections = paste(names(x$projections %||% list()), collapse = ";")
  )
}

jobs <- list(
  list(id = "visium_spatialdata", label = "Visium SpatialData sample",
       input = file.path(inputs_dir, "visium_spatialdata_0.7.1.zip"),
       make_app = TRUE),
  list(id = "minipbcite", label = "minipbcite CITE-seq",
       input = file.path(inputs_dir, "minipbcite.h5mu"),
       ## human PBMCs; the file does not name its organism
       configure = list(organism = "hg"))
)
only <- Sys.getenv("BUILD_ONLY")
if (nzchar(only)) jobs <- Filter(function(j) j$id %in% strsplit(only, ",")[[1L]], jobs)

rows <- list()
for (job in jobs) {
  crb <- build_one(job$id, job$label, job$input, job$configure %||% list(),
                   isTRUE(job$make_app))
  d <- describe_crb(crb)
  d <- c(list(input = basename(job$input), input_sha256 = sha256(job$input)), d,
         list(cerebronexus_commit = installed_commit, cerebronexus_version = installed_version,
              pin_commit = pin[["commit"]], pin_version = pin[["version"]]))
  str(d)
  rows[[job$id]] <- as.data.frame(d)
}
summary <- do.call(rbind, rows)
utils::write.csv(summary, file.path(out_dir, "build-summary.csv"), row.names = FALSE)
print(summary)
unlink(file.path(out_dir, "work"), recursive = TRUE)
cat("\n")
print(sessionInfo())
