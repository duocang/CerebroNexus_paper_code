# Writes the two CRBs of the `fixture` scenarios (standard/scenarios.tsv) from the builder_performance fixture
# cells100k.rds (100 000 cells, 198 M non-zero values), each with its Viewer Pack beside it:
#   embedded_100k   the expression matrix inside the CRB: the case where createShinyApp()'s preflight used to read the
#                   CRB a second time to check the Viewer Pack
#   h5_100k         a thin CRB with an H5 sidecar, at a size between `example` and `1m`
# Usage: Rscript topics/app_export/standard/fixtures.R --from ../data/builder-perf --out ../data/app-export [--lib DIR]
# The installed CerebroNexus writes them (`--lib` selects another library); its version is recorded in VERSION.
# A CRB is read by every revision, so the writer matters little; the MD5 of each CRB is in the run's manifest.
here <- normalizePath(
  dirname(sub(
    "^--file=",
    "",
    grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]
  )),
  winslash = "/"
)
source(file.path(
  dirname(dirname(here)),
  "viewer_performance",
  "standard",
  "cli.R"
))
opt <- parse_cli(commandArgs(TRUE))
if (is.null(opt$from) || is.null(opt$out)) {
  stop(
    "--from DIR (builder_performance fixtures) and --out DIR are required",
    call. = FALSE
  )
}
rds <- file.path(opt$from, "cells100k.rds")
if (!file.exists(rds)) {
  stop(
    "no cells100k.rds in ",
    opt$from,
    " (topics/builder_performance/standard/fixtures.R writes it)",
    call. = FALSE
  )
}
suppressPackageStartupMessages({
  library(CerebroNexus, lib.loc = if (is.null(opt$lib)) NULL else opt$lib)
  library(Seurat)
})
seurat <- readRDS(rds)
for (mode in c("embedded", "h5")) {
  dir <- file.path(opt$out, paste0(mode, "_100k"))
  unlink(dir, recursive = TRUE)
  dir.create(dir, recursive = TRUE)
  file <- file.path(dir, sprintf("cerebro_%s_100k.crb", mode))
  message(mode, ": ", file)
  exportFromSeurat(
    seurat,
    assay = "RNA",
    slot = "data",
    file = file,
    experiment_name = paste0("app_export_", mode),
    organism = "mm",
    groups = c("sample", "cluster", "cell_type"),
    nUMI = "nCount_RNA",
    nGene = "nFeature_RNA",
    expression_matrix_mode = mode,
    h5_compression_level = 0L,
    codec = "qs2",
    viewer_binary = "always",
    verbose = FALSE
  )
  stopifnot(file.exists(file), dir.exists(sub("[.]crb$", ".viewer", file)))
}
writeLines(
  as.character(utils::packageVersion("CerebroNexus")),
  file.path(opt$out, "VERSION")
)
message("done: ", opt$out)
