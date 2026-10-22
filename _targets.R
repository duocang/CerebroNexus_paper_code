# Redraw the paper figures from the result tables committed under topics/*/data/:
#   Rscript -e 'targets::tar_make()'
# Each topics/<topic>/ has functions.R (helpers) and targets.R (one target list).
# Benchmark harnesses run separately (topics/<topic>/run.sh).
library(targets)

tar_source(c(
  Sys.glob("topics/*/functions.R"),
  Sys.glob("topics/*/targets.R")
))

list(
  targets_expression_backends,
  targets_viewer_performance,
  targets_tool_comparison
)
