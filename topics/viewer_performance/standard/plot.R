#!/usr/bin/env Rscript
# Draw several recorded runs in one figure: every page and action, one colour per run.
#
#   Rscript topics/viewer_performance/standard/plot.R RUN [RUN ...] [--out FILE.pdf] [--metric NAME] [--threshold MS[,MS]] [--allow-font-substitute]
#
# RUN is a folder name under topics/viewer_performance/runs/ (e.g. cerebronexus-5.4.0_20261029-205409_c7697e0)
# or a path to a run folder.
# The legend names each run by its CerebroNexus version, adding the date when two runs share a version
# (and the start time when they share the date too). Runs are drawn by version, then date. --metric is a column of
# pages.tsv (default visual_complete_ms; e.g. server_busy_ms, r_peak_mib). Writes a PDF and a PNG
# (default topics/viewer_performance/figures/viewer-performance.pdf / .png), 170 mm wide, Arial 7 pt, as the
# Genome Biology rules in topics/expression_backends/scripts/rebuild-figures.R. --allow-font-substitute
# draws a draft with another sans font when Arial and Helvetica are not installed. --threshold draws dashed
# response-time limits in ms (default 1000, i.e. 1 s; e.g. 100,1000 for 0.1 s and 1 s; none to leave them out).
args_all <- commandArgs(trailingOnly = FALSE)
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", args_all, value = TRUE)[[1L]])))
source(file.path(here, "lib.R"))
args <- commandArgs(trailingOnly = TRUE)
take <- function(flag, default) {
  i <- which(args == flag)
  if (!length(i)) return(default)
  v <- args[[i + 1L]]; args <<- args[-c(i, i + 1L)]; v
}
substitute <- "--allow-font-substitute" %in% args
args <- setdiff(args, "--allow-font-substitute")
out <- take("--out", file.path(dirname(here), "figures", "viewer-performance.pdf"))
metric <- take("--metric", "visual_complete_ms")
threshold <- take("--threshold", "1000")
threshold <- if (identical(threshold, "none")) NULL else as.numeric(strsplit(threshold, ",", fixed = TRUE)[[1L]])
if (anyNA(threshold)) stop("--threshold takes milliseconds, e.g. 1000 or 100,1000, or none", call. = FALSE)
if (!length(args)) {
  message("usage: Rscript topics/viewer_performance/standard/plot.R RUN [RUN ...] [--out FILE.pdf] [--metric NAME] [--threshold MS[,MS]] [--allow-font-substitute]  (RUN: a folder name in runs/ or a path)")
  quit(save = "no", status = 2L)
}
runs <- lapply(args, read_run, runs_root = file.path(dirname(here), "runs"))
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
res <- plot_runs(runs, out, metric, family = figure_font(substitute), threshold = threshold)
cat(sprintf("written: %s and %s (%.1f x %.1f mm)\n", res[["pdf"]], res[["png"]], as.numeric(res[["width_mm"]]), as.numeric(res[["height_mm"]])))
