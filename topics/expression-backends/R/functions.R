# Paths of the given files inside the run that a CURRENT pointer names.
current_run_files <- function(current, files) {
  run_id <- trimws(readLines(current, warn = FALSE)[1])
  paths <- file.path(dirname(current), run_id, files)
  missing <- paths[!file.exists(paths)]
  if (length(missing)) stop("Missing input: ", paste(missing, collapse = ", "), call. = FALSE)
  paths
}

# Draw the publication figures with render-figures.sh (Arial embedded, PDF
# audit) and return the files it wrote.
render_figures <- function(figure_code, scale_inputs, out_dir) {
  script <- figure_code[basename(figure_code) == "render-figures.sh"]
  scale_dir <- unique(dirname(scale_inputs))
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  status <- system2("bash", c(
    shQuote(script),
    shQuote(paste0("--scale=", scale_dir)),
    shQuote(paste0("--out=", out_dir))
  ))
  if (!identical(status, 0L)) stop("render-figures.sh failed with status ", status, call. = FALSE)
  list.files(out_dir, pattern = "^fig-.*-expression-backends\\.(pdf|png)$", full.names = TRUE)
}
