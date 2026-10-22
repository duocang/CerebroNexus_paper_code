# Expression-backend benchmark figures, redrawn from the Scale run that
# topics/expression_backends/data/scale/CURRENT names.
targets_expression_backends <- list(
  tar_target(
    scale_current,
    "topics/expression_backends/data/scale/CURRENT",
    format = "file"
  ),
  tar_target(
    scale_inputs,
    current_run_files(scale_current, c("10_export.csv", "20_access.csv", "run_manifest.csv")),
    format = "file"
  ),
  tar_target(
    figure_code,
    file.path("topics/expression_backends/scripts", c("rebuild-figures.R", "render-figures.sh")),
    format = "file"
  ),
  tar_target(
    expression_backend_figures,
    render_figures(figure_code, scale_inputs, out_dir = "topics/expression_backends/figures"),
    format = "file"
  )
)
