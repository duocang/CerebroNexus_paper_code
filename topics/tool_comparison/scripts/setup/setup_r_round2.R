# Round 2 R library (PROTOCOL 4): dependency closure of all R-side tools as Windows binaries, then CerebroNexus (pinned commit) and ShinyCell from source.
# Usage (from the tool_comparison folder): scripts/run/run_r.sh scripts/setup/setup_r_round2.R
lib <- normalizePath("env/rlib", winslash = "/", mustWork = TRUE)
.libPaths(lib)
options(
  repos = c(CRAN = "https://cloud.r-project.org"),
  Ncpus = 8L,
  install.packages.compile.from.source = "never"
)
if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager", lib = lib)
}
repos <- BiocManager::repositories()
db <- available.packages(repos = repos, type = "binary")
tmp <- tempfile()
dir.create(tmp)
untar("env/src/CerebroNexus-tmp-emergency-opt-c9bc0a0d.tar.gz", exdir = tmp)
untar("env/src/ShinyCell-5c61db78.tar.gz", exdir = tmp)
hard <- function(path) {
  d <- read.dcf(path, fields = c("Depends", "Imports"))
  pk <- unlist(strsplit(
    gsub("[(][^)]*[)]", "", paste(d, collapse = ",")),
    "[,\n ]+"
  ))
  pk[nzchar(pk) & !is.na(pk) & pk != "NA"]
}
dirs <- list.dirs(tmp, recursive = FALSE)
cn <- hard(file.path(tmp, "CerebroNexus", "DESCRIPTION"))
sc <- hard(file.path(dirs[basename(dirs) != "CerebroNexus"][1], "DESCRIPTION"))
top <- c(
  "iSEE",
  "anndataR",
  "SingleCellExperiment",
  "HDF5Array",
  "rhdf5",
  "hdf5r",
  "Seurat",
  "scRepertoire",
  "shiny",
  "shinyhelper",
  "DT",
  "ggrepel",
  "ggdendro",
  "gridExtra",
  "data.table",
  "jsonlite",
  "RColorBrewer",
  "glue",
  "readr",
  "R.utils",
  "reticulate",
  "Matrix",
  "ggplot2",
  "arrow",
  "qs2",
  "digest",
  "BiocManager",
  "remotes",
  cn,
  sc
)
base <- rownames(installed.packages(priority = "base"))
top <- intersect(setdiff(unique(top), base), rownames(db))
all <- setdiff(
  unique(c(
    top,
    unlist(tools::package_dependencies(
      top,
      db = db,
      which = c("Depends", "Imports", "LinkingTo"),
      recursive = TRUE
    ))
  )),
  base
)
todo <- setdiff(all, rownames(installed.packages(lib.loc = lib)))
cat("closure:", length(all), " to install:", length(todo), "\n")
if (length(todo)) {
  install.packages(
    todo,
    lib = lib,
    repos = repos,
    type = "binary",
    dependencies = FALSE
  )
}
cat(
  "still missing:",
  setdiff(all, rownames(installed.packages(lib.loc = lib))),
  "\n"
)
install.packages(
  file.path(tmp, "CerebroNexus"),
  lib = lib,
  repos = NULL,
  type = "source",
  INSTALL_opts = "--no-multiarch"
)
install.packages(
  "env/src/ShinyCell-5c61db78.tar.gz",
  lib = lib,
  repos = NULL,
  type = "source",
  INSTALL_opts = "--no-multiarch"
)
cat("---- isolation check\n")
suppressMessages({
  library(CerebroNexus)
  library(ShinyCell)
  library(iSEE)
  library(Seurat)
  library(anndataR)
  library(SingleCellExperiment)
})
ns <- setdiff(loadedNamespaces(), "base")
p <- vapply(ns, function(n) dirname(getNamespaceInfo(n, "path")), "")
outside <- p[!(names(p) %in% base) & !grepl("env/rlib", gsub("\\\\", "/", p))]
cat(
  "loaded namespaces:",
  length(p),
  " outside env/rlib:",
  length(outside),
  "\n"
)
print(outside)
cat("R", R.version.string, "| Bioc", as.character(BiocManager::version()), "\n")
for (n in c(
  "CerebroNexus",
  "ShinyCell",
  "iSEE",
  "Seurat",
  "anndataR",
  "SingleCellExperiment"
)) {
  cat(n, as.character(packageVersion(n)), "\n")
}
