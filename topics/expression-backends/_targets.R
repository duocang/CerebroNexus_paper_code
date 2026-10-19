# Expression-backend benchmark figures. The heavy benchmark itself
# (benchmark/run.sh) runs by hand on a large Linux machine; this pipeline only
# redraws the figures from the summary tables committed under data/.
library(targets)

topic <- "topics/expression-backends"
tar_source(file.path(topic, "R", "functions.R"))

list(
  tar_target(scale_current, file.path(topic, "data", "scale", "CURRENT"), format = "file"),
  tar_target(
    scale_inputs,
    current_run_files(scale_current, c("10_export.csv", "20_access.csv", "run_manifest.csv")),
    format = "file"
  ),
  tar_target(
    figure_code,
    file.path(topic, "R", c("rebuild-figures.R", "render-figures.sh")),
    format = "file"
  ),
  tar_target(
    figures,
    render_figures(figure_code, scale_inputs, out_dir = file.path(topic, "figures")),
    format = "file"
  )
)
