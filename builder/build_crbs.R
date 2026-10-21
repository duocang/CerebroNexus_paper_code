## Build one CRB per public input through the CerebroNexus Builder's own
## import -> inspect -> freeze BuildPlan -> execute BuildPlan path, without the
## browser UI. Mirrors the Builder's import handler (inst/builder/server/imports.R):
## default settings, recommended metadata policy, pictures the source brings,
## then a CRB-only plan executed into a stage directory.
##
## Usage (from any directory):
##   Rscript --vanilla build_crbs.R <r_library> <inputs_dir> <out_dir>
## <r_library> holds CerebroNexus 6.0.0 installed from the
## feat/multi-format-on-builder branch.

args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 3L)
lib <- normalizePath(args[[1L]], mustWork = TRUE)
inputs_dir <- normalizePath(args[[2L]], mustWork = TRUE)
out_dir <- args[[3L]]
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out_dir <- normalizePath(out_dir, mustWork = TRUE)

.libPaths(c(lib, .libPaths()))
suppressPackageStartupMessages(library(CerebroNexus))
cat("CerebroNexus", as.character(packageVersion("CerebroNexus")), "from",
    find.package("CerebroNexus"), "\n")
stopifnot(identical(as.character(packageVersion("CerebroNexus")), "6.0.0"))

`%||%` <- function(a, b) if (is.null(a)) b else a

## Builder runtime, sourced from the installed package in the order app.R uses
## (UI and server files left out).
builder_dir <- system.file("builder", package = "CerebroNexus", mustWork = TRUE)
rt <- new.env(parent = globalenv())
rt$`%||%` <- `%||%`
old_wd <- setwd(builder_dir)
base::source("prerequisite.R", local = rt, encoding = "UTF-8")
runtime_files <- c(
  file.path("core", "bundle_path_contract.R"),
  "publish.R", "app_bundle.R", "report.R", "coordinator.R", "notify.R",
  "io.R", "project.R",
  file.path("..", "viewer", "core", "viewer_content_contract.R"),
  file.path("..", "viewer", "core", "spatial_coordinate_contract.R"),
  file.path("..", "viewer", "core", "spatial_coordinate_transform.R"),
  "spatial.R",
  file.path("..", "viewer", "hla_tcr_motifs", "core", "hla_typing.R"),
  file.path("..", "viewer", "hla_tcr_motifs", "core", "hla_motif_core.R"),
  file.path("..", "viewer", "hla_tcr_motifs", "core", "hla_association_core.R"),
  "manifest.R", "content_tables.R", "content_immune.R", "content_spatial.R",
  "content.R", "profile.R", "inspect.R", "recommend.R", "adapters.R",
  "preview.R", "stats.R", "extras.R", "analysis.R", "marker_import.R",
  "build.R", "state.R", "review.R", "workflow.R", "plan.R"
)
for (file in runtime_files) {
  rt$builder_source_utf8(file, envir = rt)
}
setwd(old_wd)

sha256 <- function(path) {
  unname(strsplit(system2("shasum", c("-a", "256", shQuote(path)), stdout = TRUE), " ")[[1L]][[1L]])
}

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
  d <- c(list(input = basename(job$input), input_sha256 = sha256(job$input)), d)
  str(d)
  rows[[job$id]] <- as.data.frame(d)
}
summary <- do.call(rbind, rows)
utils::write.csv(summary, file.path(out_dir, "build-summary.csv"), row.names = FALSE)
print(summary)
unlink(file.path(out_dir, "work"), recursive = TRUE)
cat("\n")
print(sessionInfo())
