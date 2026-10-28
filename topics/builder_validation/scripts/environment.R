## Record the software environment to results/environment.txt.
source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))), "common.R"))
out <- file.path(bv_root, "results", Sys.getenv("BV_ENV_OUT", "environment.txt"))
sink(out)
cat("Date:", format(Sys.time(), tz = "UTC", usetz = TRUE), "\n")
cat("CerebroNexus under test: duocang/CerebroNexus branch builder/03_builder, commit", bv_commit, "\n")
cat("Installed from: git archive of that commit, R CMD INSTALL --library=env/rlib\n")
cat("CerebroNexus version:", as.character(packageVersion("CerebroNexus")), "from", find.package("CerebroNexus"), "\n")
cat("Rscript:", Sys.which("Rscript"), "\n")
cat("Chrome (chromote):", chromote::chromote_info()$path, "\n\n")
pk <- c("Seurat", "SeuratObject", "SeuratData", "stxBrain.SeuratData", "SingleCellExperiment",
        "rhdf5", "HDF5Array", "qs2", "shiny", "shinytest2", "chromote", "callr", "processx",
        "png", "EBImage", "RBioFormats", "Matrix", "httr")
for (p in pk) cat(sprintf("%-22s %s\n", p, tryCatch(as.character(packageVersion(p)), error = function(e) "not installed")))
cat("\n")
print(sessionInfo())
sink()
cat(readLines(out, 12), sep = "\n")
