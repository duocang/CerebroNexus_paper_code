# Redraw the paper figures from the result tables committed under data/:
#   Rscript -e 'targets::tar_make()'
# functions/ holds the helpers; each scripts/<topic>.R defines one target list.
# The expression-backend benchmark itself runs separately (benchmark/run.sh).
library(targets)

tar_source("functions")
tar_source(list.files("scripts", pattern = "\\.R$", full.names = TRUE))

list(
  targets_expression_backends,
  targets_viewer_performance
)
