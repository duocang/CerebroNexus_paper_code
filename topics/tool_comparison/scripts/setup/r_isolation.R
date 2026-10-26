# Prints "ISO <loaded namespaces> <outside env/rlib> BIOC <version>"; run with the study's R environment (PROTOCOL 4).
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
b <- rownames(installed.packages(priority = "base"))
o <- p[!(names(p) %in% b) & !grepl("env/rlib", gsub("\\\\", "/", p))]
cat(
  "ISO",
  length(p),
  length(o),
  "BIOC",
  as.character(BiocManager::version()),
  "\n"
)
