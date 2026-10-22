# Usage: cerebronexus_build.R <in.h5ad> <outdir> <embedded|h5> <groups> [nUMI] [nGene]
a <- commandArgs(TRUE)
suppressMessages(library(CerebroNexus))
dir.create(a[2], recursive = TRUE, showWarnings = FALSE)
mode <- a[3]
args <- list(h5ad_file = a[1], result_dir = a[2], groups = a[4])
if (length(a) >= 6) { args$nUMI <- a[5]; args$nGene <- a[6] }
if (mode == "h5") {
  HDF5Array::setHDF5DumpCompressionLevel(0L)
  args$expression_matrix_mode <- "h5"
}
res <- do.call(convertH5adToCerebro, args)
cat("RESULT:", paste(utils::capture.output(print(res)), collapse = " | "), "\n")
cat("FILES:", paste(list.files(a[2], recursive = TRUE), collapse = ", "), "\n")
