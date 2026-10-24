#!/usr/bin/env Rscript
# Server steps: the R work behind the pages, timed one by one without a browser, so that a slower
# page can be traced to the step that got slower. One fresh R process per revision, dataset and round.
#
# usage: server_steps.R --label L --sha S --lib DIR --src DIR --crb FILE --dataset NAME --round N --out FILE
#
# Only the Cerebro object's public methods are called, plus two Viewer helpers sourced from the
# revision's own inst/viewer when they exist there. A step whose method a revision does not have is
# "unavailable", not an error. Every step also records a hash of its result, so a run shows when two
# revisions return different data.
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[[1L]])))
source(file.path(here, "cli.R"))
opt <- parse_cli(commandArgs(trailingOnly = TRUE))
.libPaths(c(opt$lib, .libPaths()))
suppressPackageStartupMessages(library(CerebroNexus, lib.loc = opt$lib))
stopifnot(startsWith(normalizePath(find.package("CerebroNexus")), normalizePath(opt$lib)))

rows <- list()
hash_of <- function(x) {
  f <- tempfile(); on.exit(unlink(f))
  saveRDS(x, f, version = 3L, compress = FALSE)
  unname(tools::md5sum(f))
}
# Time one step. `f` returns the result; `value` turns it into a number worth reporting (a size).
step <- function(name, f, value = function(x) NA_real_, hash = TRUE) {
  gc(full = TRUE)
  t0 <- proc.time()[["elapsed"]]
  out <- tryCatch(list(x = f()), error = function(e) e)
  ms <- (proc.time()[["elapsed"]] - t0) * 1000
  if (inherits(out, "error")) {
    status <- if (inherits(out, "unavailable")) "unavailable" else "error"
    message(sprintf("  %-22s %s: %s", name, status, conditionMessage(out)))
    rows[[length(rows) + 1L]] <<- data.frame(step = name, ms = NA_real_, status = status, value = NA_real_, hash = "", stringsAsFactors = FALSE)
    return(invisible(NULL))
  }
  h <- if (hash) hash_of(out$x) else ""
  v <- value(out$x)
  message(sprintf("  %-22s %8.0f ms", name, ms))
  rows[[length(rows) + 1L]] <<- data.frame(step = name, ms = ms, status = "ok", value = v, hash = h, stringsAsFactors = FALSE)
  invisible(out$x)
}
unavailable <- function(what) stop(structure(class = c("unavailable", "error", "condition"), list(message = paste(what, "is not in this revision"), call = NULL)))
has <- function(obj, method) is.function(tryCatch(obj[[method]], error = function(e) NULL))
call_method <- function(obj, method, ...) if (has(obj, method)) obj[[method]](...) else unavailable(method)

obj <- step("read_crb", function() readCerebro(opt$crb), hash = FALSE)
if (is.null(obj)) quit(save = "no", status = 1L)
cells <- step("cell_names", function() call_method(obj, "getCellNames"))
step("metadata", function() call_method(obj, "getMetaData"))
step("projection", function() call_method(obj, "getProjection", call_method(obj, "availableProjections")[[1L]]))

# Genes picked the same way on every revision: twelve evenly spaced names from the sorted gene list.
genes <- tryCatch(sort(call_method(obj, "getGeneNames")), error = function(e) character())
if (length(genes) >= 12L) {
  pick <- genes[unique(round(seq(1L, length(genes), length.out = 12L)))]
  step("gene_row_first", function() call_method(obj, "getExpressionRow", pick[[1L]]))
  step("gene_row_repeat", function() call_method(obj, "getExpressionRow", pick[[1L]]))
  step("gene_block_12", function() call_method(obj, "getExpressionBlock", pick))
  step("mean_expression_12", function() call_method(obj, "getMeanExpressionForGenes", pick))
  if (length(cells)) {
    set.seed(1L)
    some <- sort(sample(cells, max(1L, length(cells) %/% 10L)))
    step("cells_10pct_genes_12", function() call_method(obj, "getExpressionMatrix", cells = some, genes = pick))
  }
}

# The Linked views bundle: built by the Viewer's own code (inst/viewer/coordinated_views/bundle.R),
# then encoded as JSON the way it is sent to the browser. `value` is the JSON size in MiB.
viewer <- file.path(opt$src, "inst", "viewer")
bundle_file <- file.path(viewer, "coordinated_views", "bundle.R")
env <- new.env(parent = asNamespace("CerebroNexus"))
# The bundle code calls helpers from all over inst/viewer. Load every top-level definition there (functions
# and constants), but nothing that touches a Shiny session, so no file layout has to be known.
shiny_words <- c("input", "output", "session", "observe", "observeEvent", "reactive", "eventReactive", "renderUI")
viewer_definitions <- function(dir) {
  for (f in list.files(dir, "[.]R$", recursive = TRUE, full.names = TRUE)) {
    exprs <- tryCatch(parse(f, keep.source = FALSE), error = function(e) expression())
    for (e in exprs) {
      if (!is.call(e) || !is.name(e[[1L]]) || !as.character(e[[1L]]) %in% c("<-", "=") || !is.name(e[[2L]])) next
      is_function <- is.call(e[[3L]]) && identical(e[[3L]][[1L]], as.name("function"))
      if (is_function || !any(shiny_words %in% all.names(e[[3L]]))) {
        try(eval(e, env), silent = TRUE)
      }
    }
  }
}
ok <- file.exists(bundle_file) && is.null(viewer_definitions(viewer))
if (file.exists(bundle_file) && isTRUE(ok) && is.function(env$cv_build_bundle)) {
  bundle <- step("linked_bundle_build", function() env$cv_build_bundle(obj), hash = FALSE)
  if (!is.null(bundle)) {
    step("linked_bundle_json", function() jsonlite::toJSON(bundle, auto_unbox = TRUE, null = "null", na = "null", digits = NA),
         value = function(x) nchar(x, type = "bytes") / 2^20, hash = FALSE)
  }
} else {
  rows[[length(rows) + 1L]] <- data.frame(step = "linked_bundle_build", ms = NA_real_, status = "unavailable", value = NA_real_, hash = "", stringsAsFactors = FALSE)
}

df <- do.call(rbind, rows)
df <- cbind(data.frame(label = opt$label, sha = opt$sha, dataset = opt$dataset, round = as.integer(opt$round), stringsAsFactors = FALSE), df)
utils::write.table(df, opt$out, sep = "\t", row.names = FALSE, quote = FALSE, col.names = !file.exists(opt$out), append = file.exists(opt$out))
cat(sprintf("%s %s r%s: %d server steps\n", opt$label, opt$dataset, opt$round, nrow(df)))
