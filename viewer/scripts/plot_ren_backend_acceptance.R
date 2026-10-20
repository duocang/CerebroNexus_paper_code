args <- commandArgs(trailingOnly = TRUE)
script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
here <- dirname(normalizePath(sub("^--file=", "", script_arg[[1L]])))
input <- if (length(args) >= 1L) {
  args[[1L]]
} else {
  file.path(here, "..", "..", "data", "viewer_performance", "ren-backends-20261008.tsv")
}
output <- if (length(args) >= 2L) args[[2L]] else "ren-backends.png"
source(file.path(here, "plot-ren.R"))
data <- utils::read.delim(input, check.names = FALSE)
grDevices::png(output, width = 1800, height = 600, res = 150)
tryCatch(plotRenBackendBenchmark(data), finally = grDevices::dev.off())
