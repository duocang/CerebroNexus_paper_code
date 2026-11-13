#!/usr/bin/env Rscript
# Compare two recorded runs, page by page: A is the reference, B the one to judge.
#
#   Rscript topics/viewer_performance/standard/compare.R A B [--metric NAME] [--out FILE.md]
#
# A and B are folder names under topics/viewer_performance/runs/ or paths to run folders.
# Prints a Markdown table: the median of the metric (default visual_complete_ms, any metric of raw.tsv) for
# every page and action in A and B, the difference, the rounds behind each, the p-value of an exact rank-sum
# test over those rounds, server busy time and R memory. A row is `slower` or `faster` when p <= 0.05 and the
# medians differ by more than one frame; with 3 rounds against 3 no row can be (STANDARD.md, section 6).
# It also says when the runs were not made under the same conditions (machine, plan, large datasets), whether
# they were made together (run.R --baseline), and, for two runs of one revision, how large the noise is.
args_all <- commandArgs(trailingOnly = FALSE)
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", args_all, value = TRUE)[[1L]])))
source(file.path(here, "lib.R"))
args <- commandArgs(trailingOnly = TRUE)
take <- function(flag, default) {
  i <- which(args == flag)
  if (!length(i)) return(default)
  v <- args[[i + 1L]]; args <<- args[-c(i, i + 1L)]; v
}
out <- take("--out", NULL)
metric <- take("--metric", "visual_complete_ms")
if (length(args) != 2L) {
  message("usage: Rscript topics/viewer_performance/standard/compare.R RUN_A RUN_B [--metric NAME] [--out FILE.md]  (a folder name in runs/ or a path)")
  quit(save = "no", status = 2L)
}
runs_root <- file.path(dirname(here), "runs")
a <- read_run(args[[1L]], runs_root); b <- read_run(args[[2L]], runs_root)
for (r in list(a, b)) if (!is.null(r$raw) && !metric %in% names(r$raw)) stop("no metric ", metric, " in raw.tsv of ", r$id, call. = FALSE)
lines <- compare_lines(compare_runs(a, b, metric), a, b)
if (is.null(out)) writeLines(lines) else { writeLines(lines, out); cat("written:", out, "\n") }
