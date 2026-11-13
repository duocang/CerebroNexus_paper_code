# Writes the synthetic Seurat objects the scenarios read (standard/fixtures.tsv) into one folder, once per
# machine. The data are random on purpose: what is measured is a count of cells, columns and non-zero values,
# not a biology, and a fixture needs no download. A fixed seed makes it the same file every time; the MD5 of
# every file is written to MD5SUMS beside it and recorded in the manifest of a run.
#   Rscript topics/builder_performance/standard/fixtures.R --out ../data/builder-perf [--scale 0.01] [--only meta60,...]
# `--scale` shrinks every fixture (cells and, for cells100k, genes) for a smoke test: use it only to see the
# harness run, never for a measurement. Needs Seurat and Matrix; cells100k is about 5 GB on disk and 6 GB in memory.
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
if (is.null(opt$out)) {
  stop("--out DIR is required", call. = FALSE)
}
scale <- if (is.null(opt$scale)) 1 else as.numeric(opt$scale)
only <- if (is.null(opt$only)) {
  NULL
} else {
  strsplit(opt$only, ",", fixed = TRUE)[[1L]]
}
fx <- utils::read.delim(
  file.path(here, "fixtures.tsv"),
  stringsAsFactors = FALSE
)
if (!is.null(only)) {
  fx <- fx[fx$name %in% only, , drop = FALSE]
}
dir.create(opt$out, recursive = TRUE, showWarnings = FALSE)
suppressPackageStartupMessages({
  library(Matrix)
  library(Seurat)
})

# A dgCMatrix of genes x cells with exactly `k` non-zero values in every cell (column), built column by column
# so that 198 M values need no intermediate triplet form.
sparse_counts <- function(genes, cells, k) {
  k <- min(k, genes)
  i <- integer(cells * k)
  for (j in seq_len(cells)) {
    i[((j - 1L) * k + 1L):(j * k)] <- sort.int(sample.int(genes, k)) - 1L
  }
  new(
    "dgCMatrix",
    i = i,
    p = as.integer(seq(0L, by = k, length.out = cells + 1L)),
    x = as.numeric(rpois(cells * k, 2) + 1),
    Dim = c(genes, cells),
    Dimnames = list(
      paste0("Gene", seq_len(genes)),
      sprintf("CELL%07d-1", seq_len(cells))
    )
  )
}

# 63 metadata columns, as a real object has: Seurat's own three (orig.ident, nCount, nFeature), 20 numeric, 20
# integer, 15 factors of 30 levels and 5 more factors, a clone id with many distinct values and a copy of the
# barcodes (a column of all-distinct text).
add_metadata <- function(seurat, n, clones) {
  for (k in 1:20) {
    seurat[[paste0("num", k)]] <- stats::rnorm(n)
  }
  for (k in 1:20) {
    seurat[[paste0("int", k)]] <- sample.int(5000L, n, replace = TRUE)
  }
  for (k in 1:15) {
    seurat[[paste0("group", k)]] <- factor(sample(
      paste0("L", 1:30),
      n,
      replace = TRUE
    ))
  }
  for (k in 1:3) {
    seurat[[paste0("batch", k)]] <- factor(sample(
      paste0("B", 1:6),
      n,
      replace = TRUE
    ))
  }
  seurat$clone_id <- paste0("clone", sample.int(clones, n, replace = TRUE))
  seurat$barcode_copy <- colnames(seurat)
  seurat
}

make <- function(name, cells, genes, k, meta_cols) {
  set.seed(1)
  message(sprintf(
    "%s: %d cells, %d genes, %d values per cell",
    name,
    cells,
    genes,
    k
  ))
  counts <- sparse_counts(genes, cells, k)
  seurat <- CreateSeuratObject(counts, project = name)
  rm(counts)
  seurat <- NormalizeData(seurat, verbose = FALSE)
  if (meta_cols > 10L) {
    seurat <- add_metadata(seurat, cells, max(2L, as.integer(cells * 0.4)))
  } else {
    seurat$sample <- factor(sample(paste0("S", 1:8), cells, replace = TRUE))
    seurat$cluster <- factor(sample(0:24, cells, replace = TRUE))
    seurat$cell_type <- factor(sample(
      paste0("type", 1:12),
      cells,
      replace = TRUE
    ))
  }
  emb <- matrix(
    stats::rnorm(cells * 2L),
    ncol = 2L,
    dimnames = list(colnames(seurat), c("umap_1", "umap_2"))
  )
  seurat[["umap"]] <- CreateDimReducObject(emb, key = "umap_", assay = "RNA")
  seurat
}

for (i in seq_len(nrow(fx))) {
  f <- fx[i, ]
  path <- file.path(opt$out, f$file)
  seurat <- make(
    f$name,
    max(50L, as.integer(f$cells * scale)),
    max(20L, as.integer(f$genes * min(1, scale * 10))),
    max(5L, as.integer(f$nnz_per_cell * min(1, scale * 10))),
    f$meta_cols
  )
  message(sprintf("  %s: %d metadata columns", f$file, ncol(seurat@meta.data)))
  saveRDS(seurat, path, compress = FALSE)
  rm(seurat)
  invisible(gc())
}
files <- file.path(opt$out, fx$file)
sums <- tools::md5sum(files)
sums_path <- file.path(opt$out, "MD5SUMS")
old <- if (file.exists(sums_path)) readLines(sums_path) else character()
old <- old[!sub("^[0-9a-f]+  ", "", old) %in% basename(files)]
writeLines(sort(c(old, sprintf("%s  %s", sums, basename(files)))), sums_path)
writeLines(sprintf("scale %s", format(scale)), file.path(opt$out, "SCALE"))
message("done: ", opt$out)
