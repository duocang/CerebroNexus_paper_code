# Viewer performance figures, redrawn from the committed result tables. The
# viewer benchmark harness compares CerebroNexus commits and stays in the
# CerebroNexus repository; only its results and plotting code live here.
targets_viewer_performance <- list(
  tar_target(
    ren_backends,
    "data/viewer_performance/ren-backends-20261008.tsv",
    format = "file"
  ),
  tar_target(
    ren_backends_figure,
    plot_ren_backends(ren_backends, "figures/viewer_performance/ren-backends-20261008.png"),
    format = "file"
  )
)
