## Prepare the real inputs under data/inputs/.
##
##   visium_anterior1.rds  SeuratData stxBrain anterior1 (10x Visium, mouse
##                         brain), all 2,696 spots and 31,053 genes, with the
##                         lowres H&E kept in its VisiumV2 image. Light
##                         processing as in data-raw/build_spatial_demos.R
##                         (NormalizeData, PCA, UMAP, clusters) but no gene
##                         trimming or spot sampling. No own nUMI/nGene
##                         columns: nCount_Spatial/nFeature_Spatial serve
##                         (Experiment A case A13 covers the duplicate).
##   visium_anterior1_he.png  that lowres H&E raster, native 600 x 599 px, as
##                         an 8-bit PNG (the external background image).
##   xenium_brain.rds      10x Xenium mouse brain CTX+HP (public outs bundle,
##                         data/raw/xenium/brain.zip), every cell with finite
##                         centroids, 248 genes, centroids FOV "fov" in microns;
##                         built as data-raw/build_spatial_demos.R does but
##                         without sampling or gene trimming.
##   xenium_dapi.png,
##   xenium_dapi.json      DAPI morphology MIP (pyramid level with long edge
##                         >= 1400 px, 2-99% stretched) and its extent in
##                         microns (full-resolution size x pixel_size).
##   pbmc_seurat.rds,
##   pbmc_SCE.rds          inst/extdata/examples of the installed package.
##   pbmc3k.h5ad           data/raw (cellxgene example dataset, downloaded
##                         by hand, see README).
##
## Usage: Rscript scripts/00_prepare_inputs.R

source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))), "common.R"))
suppressPackageStartupMessages(library(Seurat))

inputs <- file.path(bv_data, "inputs")
dir.create(inputs, recursive = TRUE, showWarnings = FALSE)
set.seed(42)

visium <- file.path(inputs, "visium_anterior1.rds")
if (!file.exists(visium)) {
  obj <- SeuratData::LoadData("stxBrain", type = "anterior1")
  obj <- UpdateSeuratObject(obj)
  DefaultAssay(obj) <- "Spatial"
  obj <- NormalizeData(obj, verbose = FALSE)
  obj <- FindVariableFeatures(obj, nfeatures = 2000, verbose = FALSE)
  obj <- ScaleData(obj, verbose = FALSE)
  obj <- RunPCA(obj, npcs = 30, verbose = FALSE)
  obj <- RunUMAP(obj, dims = 1:20, verbose = FALSE)
  obj <- FindNeighbors(obj, dims = 1:20, verbose = FALSE)
  obj <- FindClusters(obj, resolution = 0.5, verbose = FALSE)
  obj$cluster <- factor(paste0("C", as.integer(obj$seurat_clusters)))
  saveRDS(obj, visium)
}

he <- file.path(inputs, "visium_anterior1_he.png")
if (!file.exists(he)) {
  obj <- readRDS(visium)
  png::writePNG(obj[["anterior1"]]@image, he)
}

xenium <- file.path(inputs, "xenium_brain.rds")
xdir <- file.path(bv_data, "raw", "xenium", "brain")
if (!file.exists(xenium) && file.exists(file.path(xdir, "cell_feature_matrix.h5"))) {
  ## 10x CSC matrix read with rhdf5 (Read10X_h5 needs hdf5r, not installed);
  ## Gene Expression features only, as Read10X_h5()[["Gene Expression"]].
  h5 <- file.path(xdir, "cell_feature_matrix.h5")
  m <- rhdf5::h5read(h5, "matrix", bit64conversion = "double")
  mat <- Matrix::sparseMatrix(
    i = as.integer(m$indices) + 1L, p = as.integer(m$indptr),
    x = as.numeric(m$data), dims = as.integer(m$shape),
    dimnames = list(as.vector(m$features$name), as.vector(m$barcodes))
  )
  mat <- mat[which(as.vector(m$features$feature_type) == "Gene Expression"), , drop = FALSE]
  cells <- utils::read.csv(gzfile(file.path(xdir, "cells.csv.gz")))
  rownames(cells) <- cells$cell_id
  common <- intersect(colnames(mat), cells$cell_id)
  cells <- cells[common, ]
  fin <- is.finite(cells$x_centroid) & is.finite(cells$y_centroid)
  common <- common[fin]
  obj <- CreateSeuratObject(counts = mat[, common], assay = "Spatial")
  obj <- NormalizeData(obj, verbose = FALSE)
  obj <- FindVariableFeatures(obj, nfeatures = nrow(obj), verbose = FALSE)
  obj <- ScaleData(obj, verbose = FALSE)
  obj <- RunPCA(obj, npcs = 30, verbose = FALSE)
  obj <- RunUMAP(obj, dims = 1:20, verbose = FALSE)
  obj <- FindNeighbors(obj, dims = 1:20, verbose = FALSE)
  obj <- FindClusters(obj, resolution = 0.5, verbose = FALSE)
  obj$cluster <- factor(paste0("C", as.integer(obj$seurat_clusters)))
  xy <- as.matrix(cells[colnames(obj), c("x_centroid", "y_centroid")])
  colnames(xy) <- c("x", "y")
  obj[["fov"]] <- CreateFOV(
    list(centroids = CreateCentroids(xy)),
    type = "centroids",
    assay = "Spatial"
  )
  saveRDS(obj, xenium)
}
dapi <- file.path(inputs, "xenium_dapi.png")
ome <- file.path(xdir, "morphology_mip.ome.tif")
if (!file.exists(dapi) && file.exists(ome)) {
  um_per_px <- jsonlite::fromJSON(file.path(xdir, "experiment.xenium"))$pixel_size %||% 0.2125
  md <- RBioFormats::read.metadata(ome)
  full <- RBioFormats::coreMetadata(md, series = 1)
  level <- 1L
  for (r in seq_along(md)) {
    cm <- RBioFormats::coreMetadata(md, series = r)
    if (max(cm$sizeX, cm$sizeY) >= 1400) level <- r
  }
  arr <- as.array(RBioFormats::read.image(ome, resolution = level, normalize = FALSE))
  ch <- t(if (length(dim(arr)) == 3) arr[, , 1] else arr)
  qs <- stats::quantile(ch, c(0.02, 0.99), na.rm = TRUE)
  ch <- pmin(pmax((ch - qs[[1]]) / (qs[[2]] - qs[[1]] + 1e-9), 0), 1)
  png::writePNG(ch, dapi)
  jsonlite::write_json(
    list(xmin = 0, xmax = full$sizeX * um_per_px, ymin = 0, ymax = full$sizeY * um_per_px,
         um_per_px = um_per_px, full_px = c(full$sizeX, full$sizeY), level = level,
         level_px = rev(dim(ch))),
    file.path(inputs, "xenium_dapi.json"), auto_unbox = TRUE, digits = NA
  )
}

for (f in c("pbmc_seurat.rds", "pbmc_SCE.rds")) {
  src <- system.file("extdata", "examples", f, package = "CerebroNexus", mustWork = TRUE)
  file.copy(src, file.path(inputs, f), overwrite = TRUE)
}
h5ad <- file.path(bv_data, "raw", "pbmc3k.h5ad")
if (file.exists(h5ad)) file.copy(h5ad, file.path(inputs, "pbmc3k.h5ad"), overwrite = TRUE)

files <- list.files(inputs, full.names = TRUE)
info <- data.frame(
  file = basename(files),
  bytes = file.size(files),
  sha256 = vapply(files, bv_sha256, ""),
  row.names = NULL
)
print(info)
utils::write.csv(info, file.path(bv_root, "results", "inputs.csv"), row.names = FALSE)
