# I2: scRepertoire example Seurat object + TCR (CTaa etc.) -> data/inputs/I2_seurat.rds and a plain-text export for the h5ad writer.
suppressMessages({library(Seurat); library(scRepertoire); library(Matrix)})
data("scRep_example"); data("contig_list")
seu <- scRep_example
smp <- c("P17B", "P17L", "P18B", "P18L", "P19B", "P19L", "P20B", "P20L")
cl <- combineTCR(contig_list, samples = smp, removeNA = FALSE, removeMulti = FALSE, filterMulti = FALSE)
seu <- combineExpression(cl, seu, cloneCall = "strict", proportion = FALSE,
  cloneSize = c(Single = 1, Small = 5, Medium = 20, Large = 100, Hyperexpanded = 500))
seu$sample <- seu$orig.ident
saveRDS(seu, "data/inputs/I2_seurat.rds")
dir.create("data/inputs/I2_export", showWarnings = FALSE)
m <- GetAssayData(seu, assay = "RNA", layer = "counts")
Matrix::writeMM(m, "data/inputs/I2_export/counts.mtx")
writeLines(rownames(m), "data/inputs/I2_export/genes.txt")
writeLines(colnames(m), "data/inputs/I2_export/cells.txt")
write.csv(seu@meta.data, "data/inputs/I2_export/meta.csv", row.names = TRUE)
write.csv(Embeddings(seu, "umap"), "data/inputs/I2_export/umap.csv", row.names = TRUE)
cat("cells", ncol(seu), "genes", nrow(seu), "with CTaa", sum(!is.na(seu$CTaa)), "\n")
tt <- sort(table(seu$CTaa), decreasing = TRUE)
cat("top CTaa:", names(tt)[1], tt[[1]], "\n")
cat("VariableFeatures:", length(VariableFeatures(seu)), "\n")
