## Record the software environment to results/environment_<9 chars of the commit>.txt
## (BV_ENV_OUT overrides the file name). The revision is the one in
## topics/cerebronexus.pin, as installed by scripts/install_cerebronexus.sh;
## common.R stops when the installed commit is not the pinned one.
source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))), "common.R"))
out <- file.path(bv_root, "results", Sys.getenv("BV_ENV_OUT", paste0("environment_", bv_suffix, ".txt")))
rt <- bv_load_runtime()
sink(out)
cat("Date:", format(Sys.time(), tz = "UTC", usetz = TRUE), "\n")
cat("CerebroNexus pin (topics/cerebronexus.pin): ref", bv_pin$ref, "commit", bv_pin$commit, "version", bv_pin$version, "\n")
cat("CerebroNexus installed: commit", bv_commit, "version", bv_version, "\n")
cat("Installed from: git archive of that commit (", bv_installed[["source"]], "), R CMD INSTALL --library=env/rlib, at",
    bv_installed[["installed"]], "\n", sep = " ")
cat("CerebroNexus library:", find.package("CerebroNexus"), "\n")
cat("Builder runtime files sourced (from inst/builder/app.R):", length(attr(rt, "runtime_files")), "\n")
cat("  ", paste(attr(rt, "runtime_files"), collapse = " "), "\n")
cat("Builder runtime files app.R names that the install lacks:", paste(attr(rt, "skipped"), collapse = " "), "\n")
cat("Rscript:", Sys.which("Rscript"), "\n")
cat("Chrome (chromote):", tryCatch(chromote::chromote_info()$path, error = function(e) "not found"), "\n\n")
pk <- c("Seurat", "SeuratObject", "SeuratData", "stxBrain.SeuratData", "SingleCellExperiment",
        "rhdf5", "HDF5Array", "qs2", "shiny", "shinytest2", "chromote", "callr", "processx",
        "png", "EBImage", "RBioFormats", "Matrix", "httr")
for (p in pk) cat(sprintf("%-22s %s\n", p, tryCatch(as.character(packageVersion(p)), error = function(e) "not installed")))
cat("\n")
print(sessionInfo())
sink()
cat(readLines(out, 12), sep = "\n")
