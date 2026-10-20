# Install the R packages this repository needs into your own library, without
# Nix. Only missing packages are installed.
#   Rscript install.R figures     redraw the figures
#   Rscript install.R benchmark   also run the expression-backend benchmark
# The benchmark set reads CerebroNexus' Imports from the commit in
# benchmark/cerebronexus.lock, or from $CEREBRONEXUS_SRC.
what <- commandArgs(TRUE)
what <- if (length(what)) what[1] else "figures"
if (!what %in% c("figures", "benchmark")) {
  stop("Usage: Rscript install.R [figures|benchmark]", call. = FALSE)
}

cran <- getOption("repos")[["CRAN"]]
if (is.null(cran) || cran == "@CRAN@") cran <- "https://cloud.r-project.org"
options(repos = c(CRAN = cran))

missing_pkgs <- function(pkgs) {
  pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
}
install <- function(pkgs, installer) {
  todo <- missing_pkgs(unique(pkgs))
  if (!length(todo)) return(invisible())
  message("Installing: ", paste(todo, collapse = ", "))
  installer(todo)
}

figures <- c("ggplot2", "patchwork", "scales", "systemfonts", "targets")
install(figures, function(p) install.packages(p))

if (what == "benchmark") {
  src <- Sys.getenv("CEREBRONEXUS_SRC")
  if (nzchar(src)) {
    desc <- file.path(src, "DESCRIPTION")
  } else {
    lock <- readLines("benchmark/cerebronexus.lock")
    lock_value <- function(key) sub(paste0("^", key, "="), "", grep(paste0("^", key, "="), lock, value = TRUE))
    repo <- sub("\\.git$", "", sub("^https://github.com/", "", lock_value("repo")))
    desc <- tempfile(fileext = ".dcf")
    utils::download.file(
      sprintf("https://raw.githubusercontent.com/%s/%s/DESCRIPTION", repo, lock_value("commit")),
      desc, quiet = TRUE
    )
  }
  if (!file.exists(desc)) {
    stop("CerebroNexus DESCRIPTION not found at ", desc, call. = FALSE)
  }
  imports <- read.dcf(desc, fields = "Imports")[1, 1]
  imports <- trimws(sub("\\(.*", "", strsplit(imports, ",")[[1]]))
  base <- rownames(installed.packages(priority = "base"))
  imports <- setdiff(imports[nzchar(imports)], base)
  harness <- c(
    "DelayedArray", "HDF5Array", "rhdf5", "Seurat", "SeuratObject",
    "callr", "testthat", "withr"
  )
  install("BiocManager", function(p) install.packages(p))
  install(c(imports, harness), function(p) {
    BiocManager::install(p, update = FALSE, ask = FALSE)
  })
  # BPCells is not on CRAN or Bioconductor.
  install("BPCells", function(p) {
    install.packages(p, repos = c("https://bnprks.r-universe.dev", cran))
  })
}

still <- missing_pkgs(c(figures, if (what == "benchmark") c(imports, harness, "BPCells")))
if (length(still)) stop("Still missing: ", paste(still, collapse = ", "), call. = FALSE)
message("All ", what, " packages are installed.")
