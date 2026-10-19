# Viewer performance figures, redrawn from the committed result tables.
# The viewer benchmark harness compares CerebroNexus commits and stays in the
# CerebroNexus repository; only its results and plotting code live here.
library(targets)

topic <- "topics/viewer-performance"
tar_source(file.path(topic, "R", "plot-ren.R"))

list(
  tar_target(ren_backends, file.path(topic, "data", "ren-backends-20261008.tsv"), format = "file"),
  tar_target(
    ren_backends_figure,
    {
      out <- file.path(topic, "figures", "ren-backends-20261008.png")
      dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
      data <- utils::read.delim(ren_backends, check.names = FALSE)
      grDevices::png(out, width = 1800, height = 600, res = 150)
      tryCatch(plotRenBackendBenchmark(data), finally = grDevices::dev.off())
      out
    },
    format = "file"
  )
)
