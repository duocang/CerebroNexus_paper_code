# Viewer performance figures, redrawn from the committed result tables: the Ren
# backend figure and, once a run is recorded, the L1 trend.
targets_viewer_performance <- list(
  tar_target(
    ren_backends,
    "topics/viewer_performance/data/ren-backends-20261008.tsv",
    format = "file"
  ),
  tar_target(
    ren_backends_figure,
    plot_ren_backends(ren_backends, "topics/viewer_performance/figures/ren-backends-20261008.png"),
    format = "file"
  )
)

# The trend exists once a run has been recorded (topics/viewer_performance/runs/INDEX.tsv).
if (file.exists("topics/viewer_performance/runs/INDEX.tsv")) {
  targets_viewer_performance <- c(targets_viewer_performance, list(
    tar_target(viewer_trend_index, "topics/viewer_performance/runs/INDEX.tsv", format = "file"),
    tar_target(
      viewer_trend_figure,
      plot_viewer_trend(viewer_trend_index, "topics/viewer_performance/figures/viewer-trend-l1.png"),
      format = "file"
    )
  ))
}
