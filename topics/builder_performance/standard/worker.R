# One Builder measurement: a fresh R process runs one scenario on one fixture with one installed revision and
# writes what it timed to a JSON file. Started by run.R.
# usage: Rscript --vanilla worker.R LIB SRC SCENARIO FIXTURE WORKDIR RESULT_JSON
# LIB is the library the revision was installed into, SRC its `git archive` (the Builder's own test helpers,
# which source the Builder runtime the same way the app does, are read from there). Every scenario times the
# same calls the Builder makes in its worker or its Shiny process; none of them needs a browser.
a <- commandArgs(TRUE)
lib <- a[[1L]]
src <- a[[2L]]
scenario <- a[[3L]]
fixture <- a[[4L]]
work <- a[[5L]]
res <- a[[6L]]
.libPaths(c(lib, .libPaths()))
suppressPackageStartupMessages({
  library(CerebroNexus, lib.loc = lib)
  library(testthat)
  library(Seurat)
})
setwd(src)
`%||%` <- function(a, b) if (is.null(a)) b else a
dir.create(work, recursive = TRUE, showWarnings = FALSE)
work <- normalizePath(work, winslash = "/")

# The Builder runtime, sourced as the Builder's own end-to-end tests do.
for (helper in list.files(
  "tests/testthat",
  pattern = "^helper.*[.]R$",
  full.names = TRUE
)) {
  try(sys.source(helper, envir = globalenv()), silent = TRUE)
}
builder_e2e_source_runtime(globalenv())
# The Builder runs its runtime from the installed package, byte-compiled. Sourced here, each function would be
# compiled by the JIT the first time it runs, inside the time of the first edit or Build (most of `freeze_s`
# was that): compile them now, as the installation does.
for (name in ls(globalenv(), all.names = TRUE)) {
  f <- get(name, envir = globalenv())
  if (is.function(f) && !is.primitive(f)) {
    compiled <- tryCatch(compiler::cmpfun(f), error = function(e) NULL)
    if (!is.null(compiled)) assign(name, compiled, envir = globalenv())
  }
}

# Wall time. Sys.time() reads Windows' precise clock (below 1 ms); proc.time()'s elapsed time there moves in
# steps of 10 to 16 ms, too coarse for an edit of 50 ms.
now <- function() as.numeric(Sys.time())
timed <- function(expr) {
  t0 <- now()
  value <- expr
  list(s = now() - t0, value = value)
}
out <- list()

# ---- import, as the Builder's worker does it -------------------------------------------------------------
new_workspace <- function() {
  assign(".builder_objects", new.env(parent = emptyenv()), envir = globalenv())
  assign(
    ".builder_snapshots",
    new.env(parent = emptyenv()),
    envir = globalenv()
  )
  assign(
    ".builder_snapshot_root",
    file.path(work, "snapshots"),
    envir = globalenv()
  )
  unlink(.builder_snapshot_root, recursive = TRUE)
  dir.create(.builder_snapshot_root)
}
import_fixture <- function() {
  new_workspace()
  timed(.builder_register_adapter(
    builder_seurat_file_adapter(fixture),
    "ds",
    progress = function(...) NULL
  ))
}

# The entry the import handler would put in the Builder's state, with the default settings.
make_entry <- function(registered, backend) {
  settings <- builder_default_settings(
    registered$profile,
    "Perf",
    dataset_profile = registered$dataset_profile
  )
  metadata <- builder_recommend_metadata(registered$dataset_profile)
  settings$recommendations <- list(metadata = metadata)
  settings$metadata_policy <- metadata
  settings$expression_backend <- backend
  if (!length(settings$organism) || !nzchar(settings$organism)) {
    settings$organism <- "mm"
  }
  if (!length(settings$reductions)) {
    settings$reductions <- "umap"
  }
  if (!length(settings$layer)) {
    settings$layer <- "data"
  }
  list(
    id = "ds",
    source_id = "ds",
    output_id = "ds",
    path = fixture,
    filename = basename(fixture),
    source_origin = "local",
    format = registered$format,
    profile = registered$profile,
    dataset_profile = registered$dataset_profile,
    snapshot = registered$snapshot,
    revision = 1L,
    levels = registered$levels %||% list(),
    settings = settings
  )
}

# One edit of the entry, as the group handler does it: a group ticked or unticked.
edit_entry <- function(entry, pick) {
  included <- entry$settings$included_groups %||% entry$settings$groups
  included <- if (pick %in% included && length(included) > 1L) {
    setdiff(included, pick)
  } else {
    union(included, pick)
  }
  entry$settings$included_groups <- included
  entry$settings$groups <- included
  if (!entry$settings$default_group %in% included) {
    entry$settings$default_group <- included[[1L]]
  }
  policy <- entry$settings$metadata_policy
  if (is.list(policy)) {
    entry$settings$metadata_policy <- builder_metadata_policy_set_groups(
      policy,
      included
    )
  }
  entry$revision <- entry$revision + 1L
  entry
}

# Freeze the plan and run it into a new stage folder: the build the Builder's worker runs. Returns seconds and
# the files the stage holds.
build_once <- function(entry, registered, tag) {
  object <- get("ds", envir = .builder_objects)
  frozen <- timed(builder_freeze_plan(
    list(entry),
    file.path(work, paste0("release-", tag))
  ))
  if (!is.null(frozen$value$error)) {
    stop("plan blocked: ", paste(unlist(frozen$value$error), collapse = " "))
  }
  stage <- file.path(work, paste0("stage-", tag))
  dir.create(stage)
  built <- timed(builder_execute_plan(
    frozen$value,
    stage,
    list(ds = registered$snapshot),
    objects = list(ds = object),
    on_progress = function(...) NULL
  ))
  if (!identical(built$value$state, "success")) {
    stop(
      "build did not succeed: ",
      built$value$state,
      " ",
      paste(unlist(built$value$error), collapse = " ")
    )
  }
  files <- list.files(stage, recursive = TRUE, full.names = TRUE)
  list(
    freeze_s = frozen$s,
    build_s = built$s,
    stage = stage,
    files = files,
    bytes = sum(file.size(files))
  )
}

run <- function() {
  if (scenario == "edit") {
    imp <- import_fixture()
    registered <- imp$value
    entry <- make_entry(registered, "embedded")
    state <- builder_state(list(entry))
    candidates <- names(registered$levels %||% list())
    if (!length(candidates)) {
      candidates <- entry$settings$groups
    }
    cache <- new.env(parent = emptyenv())
    shares_state <- "state_cache" %in% names(formals(builder_reduce_state))
    k <- 0L
    next_action <- function() {
      k <<- k + 1L
      entry <<- edit_entry(entry, candidates[[(k %% length(candidates)) + 1L]])
      list(type = "replace", id = "ds", entry = entry)
    }
    # What one edit costs: the reducer's replace and then the state the rail derives from it.
    one_edit <- function() {
      action <- next_action()
      state <<- if (shares_state) {
        builder_reduce_state(state, action, trusted = TRUE, state_cache = cache)
      } else {
        builder_reduce_state(state, action, trusted = TRUE)
      }
      if (exists("builder_cached_dataset_state")) {
        builder_cached_dataset_state(state$datasets[[1L]], cache)
      } else {
        builder_dataset_state(entry)
      }
    }
    one_reduce <- function() {
      state <<- builder_reduce_state(state, next_action(), trusted = TRUE)
    }
    warm <- 3L
    reps <- 15L
    for (i in seq_len(warm)) {
      one_edit()
    }
    edit_ms <- vapply(seq_len(reps), function(i) timed(one_edit())$s * 1000, 0)
    for (i in seq_len(warm)) {
      one_reduce()
    }
    reduce_ms <- vapply(
      seq_len(reps),
      function(i) timed(one_reduce())$s * 1000,
      0
    )
    out$edit_ms <<- stats::median(edit_ms)
    out$reduce_ms <<- stats::median(reduce_ms)
    out$edit_ms_max <<- max(edit_ms)
    out$metadata_cols <<- length(
      builder_recommend_metadata(registered$dataset_profile)$columns
    )
  } else if (scenario == "import") {
    imp <- import_fixture()
    out$import_s <<- imp$s
  } else if (scenario %in% c("build_embedded", "build_h5")) {
    h5 <- identical(scenario, "build_h5")
    # What the Builder's session does at its start; a revision that does not know the option ignores it.
    options(cerebro.expression_sidecars = list())
    imp <- import_fixture()
    registered <- imp$value
    out$import_s <<- imp$s
    entry <- make_entry(registered, if (h5) "h5" else "embedded")
    first <- build_once(entry, registered, "1")
    out$freeze_s <<- first$freeze_s
    out$build_s <<- first$build_s
    out$out_mib <<- first$bytes / 2^20
    if (h5) {
      # A second build after a change of the configuration only, offered the sidecar of the first.
      side <- first$files[grepl("[.]h5$", first$files)]
      if (!length(side)) {
        stop("the build wrote no H5 sidecar")
      }
      offered <- list(list(
        path = side[[1L]],
        md5 = unname(tools::md5sum(side[[1L]]))
      ))
      options(cerebro.expression_sidecars = offered)
      groups <- entry$settings$groups
      if (length(groups) < 2L) {
        stop(
          "the fixture has fewer than two groups: no configuration change to make"
        )
      }
      second <- build_once(
        edit_entry(entry, groups[[length(groups)]]),
        registered,
        "2"
      )
      out$rebuild_s <<- second$build_s
      out$rebuild_freeze_s <<- second$freeze_s
      side2 <- second$files[grepl("[.]h5$", second$files)]
      # The sidecar of the second build must hold the same matrix as the first; the equivalence check in
      # checks.R judges that. Here only whether the file is byte for byte the same is recorded.
      out$rebuild_h5_same_md5 <<- length(side2) == 1L &&
        identical(unname(tools::md5sum(side2)), offered[[1L]]$md5)
    }
  } else if (scenario == "export_h5") {
    seurat <- readRDS(fixture)
    file <- file.path(work, "perf.crb")
    stage_marks <- list()
    on_progress <- function(part) {
      stage_marks[[length(stage_marks) + 1L]] <<- list(part = part, at = now())
    }
    # An older revision lacks some arguments (6.0.0 has no `.on_progress`): pass only those it has.
    args <- list(
      seurat,
      assay = "RNA",
      slot = "data",
      file = file,
      experiment_name = "perf",
      organism = "mm",
      groups = c("sample", "cluster", "cell_type"),
      nUMI = "nCount_RNA",
      nGene = "nFeature_RNA",
      expression_matrix_mode = "h5",
      h5_compression_level = 0L,
      codec = "qs2",
      verbose = FALSE,
      .on_progress = on_progress
    )
    known <- names(formals(exportFromSeurat))
    args <- args[names(args) == "" | names(args) %in% known]
    ex <- timed(do.call(exportFromSeurat, args))
    out$export_s <<- ex$s
    files <- list.files(work, recursive = TRUE, full.names = TRUE)
    out$out_mib <<- sum(file.size(files)) / 2^20
  } else {
    stop("unknown scenario: ", scenario)
  }
}

err <- tryCatch(
  {
    run()
    NA_character_
  },
  error = function(e) conditionMessage(e)
)
cpu <- proc.time()
peak_mib <- if (.Platform$OS.type == "windows") {
  ps::ps_memory_info(ps::ps_handle())[["peak_wset"]] / 2^20
} else {
  as.numeric(gsub(
    "[^0-9]",
    "",
    grep("^VmHWM:", readLines("/proc/self/status"), value = TRUE)
  )) /
    1024
}
out$cpu_s <- cpu[["user.self"]] + cpu[["sys.self"]]
out$peak_mib <- peak_mib
out$error <- err
writeLines(
  jsonlite::toJSON(out, auto_unbox = TRUE, na = "null", digits = NA),
  res
)
