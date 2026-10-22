# Installs the comparison R library into comparison/env/rlib (run with env set by run_r.sh / harness).
# Usage: Rscript --vanilla scripts/setup_r.R
lib <- normalizePath("env/rlib", winslash = "/", mustWork = TRUE)
.libPaths(lib)
cat("libPaths:", .libPaths(), "\n")
options(repos = c(CRAN = "https://cloud.r-project.org"), Ncpus = 8L, install.packages.compile.from.source = "never")
if (!requireNamespace("BiocManager", quietly = TRUE)) install.packages("BiocManager", lib = lib)
if (!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes", lib = lib)
cat("Bioc version:", as.character(BiocManager::version()), "\n")
cran_bioc <- c(
  "iSEE", "anndataR", "SingleCellExperiment", "HDF5Array", "rhdf5", "hdf5r",
  "Seurat", "scRepertoire", "shiny", "shinyhelper", "DT", "ggrepel", "ggdendro",
  "gridExtra", "data.table", "jsonlite", "RColorBrewer", "glue", "readr", "R.utils",
  "reticulate", "Matrix", "ggplot2", "arrow", "qs2", "digest"
)
BiocManager::install(cran_bioc, lib = lib, ask = FALSE, update = FALSE, type = "binary")
cat("---- ShinyCell\n")
remotes::install_local("env/src/ShinyCell-5c61db78.tar.gz", lib = lib, dependencies = TRUE,
  upgrade = "never", type = "binary", INSTALL_opts = "--no-multiarch")
cat("---- CerebroNexus\n")
remotes::install_local("env/src/CerebroNexus-27ac995e.tar.gz", lib = lib, dependencies = TRUE,
  upgrade = "never", type = "binary", INSTALL_opts = "--no-multiarch")
cat("---- done\n")
