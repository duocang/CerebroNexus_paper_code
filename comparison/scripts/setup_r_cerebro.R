# CerebroNexus 6.0.0 (27ac995e) into env/rlib via R CMD INSTALL.
# remotes::install_local fails on the DESCRIPTION Remotes entry (GitHub BPCells, HTTP 401), so the
# hard dependencies (Depends/Imports) are installed first and the package is then installed directly.
lib <- normalizePath("env/rlib", winslash = "/", mustWork = TRUE)
.libPaths(lib)
options(repos = c(CRAN = "https://cloud.r-project.org"), Ncpus = 8L)
tmp <- tempfile(); dir.create(tmp)
untar("env/src/CerebroNexus-27ac995e.tar.gz", exdir = tmp)
d <- read.dcf(file.path(tmp, "DESCRIPTION"), fields = c("Depends", "Imports"))
pk <- unlist(strsplit(gsub("[(][^)]*[)]", "", paste(d, collapse = ",")), "[,\n ]+"))
pk <- setdiff(pk[nzchar(pk) & !is.na(pk)], c("NA", "R", rownames(installed.packages(priority = "base"))))
cat("hard deps:", pk, "\n")
BiocManager::install(setdiff(pk, rownames(installed.packages(lib.loc = lib))), lib = lib, ask = FALSE, update = FALSE, type = "binary")
install.packages(file.path(tmp), lib = lib, repos = NULL, type = "source", INSTALL_opts = "--no-multiarch")
cat("---- done\n")
