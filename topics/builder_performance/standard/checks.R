# Equivalence checks for the paths the Builder optimisations take. A faster path that reuses a file, or writes it
# another way, must give the same data as the slow one, and must not reuse what no longer fits. Runs on a tiny
# synthetic object (seconds), in a fresh R process, with the revision's installed package; run.R starts it once
# per revision. A revision that has no such path (the baseline) passes by doing the slow thing.
# usage: Rscript --vanilla checks.R LIB SRC WORKDIR OUT_TSV
a <- commandArgs(TRUE)
lib <- a[[1L]]
work <- a[[3L]]
out_tsv <- a[[4L]]
.libPaths(c(lib, .libPaths()))
suppressPackageStartupMessages({
  library(CerebroNexus, lib.loc = lib)
  library(Seurat)
  library(Matrix)
})
dir.create(work, recursive = TRUE, showWarnings = FALSE)
work <- normalizePath(work, winslash = "/")

# ---- a tiny object and its export -------------------------------------------------------------------------
make_object <- function(seed = 1L, bump = FALSE) {
  set.seed(seed)
  genes <- 200L
  cells <- 300L
  i <- unlist(lapply(seq_len(cells), function(j) {
    sort.int(sample.int(genes, 30L)) - 1L
  }))
  x <- as.numeric(rpois(length(i), 2) + 1)
  counts <- new(
    "dgCMatrix",
    i = as.integer(i),
    p = as.integer(seq(0L, by = 30L, length.out = cells + 1L)),
    x = x,
    Dim = c(genes, cells),
    Dimnames = list(
      paste0("Gene", seq_len(genes)),
      sprintf("CELL%04d-1", seq_len(cells))
    )
  )
  if (bump) {
    counts@x[[1L]] <- counts@x[[1L]] + 5
  } # one value of the matrix differs
  s <- CreateSeuratObject(counts, project = "chk")
  s <- NormalizeData(s, verbose = FALSE)
  s$sample <- factor(sample(c("S1", "S2", "S3"), cells, TRUE))
  s$cluster <- factor(sample(0:4, cells, TRUE))
  s$cell_type <- factor(sample(paste0("t", 1:3), cells, TRUE))
  emb <- matrix(
    rnorm(cells * 2L),
    ncol = 2L,
    dimnames = list(colnames(s), c("umap_1", "umap_2"))
  )
  s[["umap"]] <- CreateDimReducObject(emb, key = "umap_", assay = "RNA")
  s
}
export_h5 <- function(
  object,
  tag,
  groups = c("sample", "cluster", "cell_type"),
  offer = NULL
) {
  dir <- file.path(work, tag)
  dir.create(dir, recursive = TRUE)
  options(cerebro.expression_sidecars = offer %||% list()) # what the Builder sets; an older revision ignores it
  exportFromSeurat(
    object,
    assay = "RNA",
    slot = "data",
    file = file.path(dir, "chk.crb"),
    experiment_name = "chk",
    organism = "mm",
    groups = groups,
    nUMI = "nCount_RNA",
    nGene = "nFeature_RNA",
    expression_matrix_mode = "h5",
    h5_compression_level = 0L,
    codec = "qs2",
    verbose = FALSE
  )
  h5 <- list.files(dir, "[.]h5$", recursive = TRUE, full.names = TRUE)
  if (length(h5) != 1L) {
    stop("expected one H5 sidecar in ", dir, ", found ", length(h5))
  }
  h5
}
`%||%` <- function(a, b) if (is.null(a)) b else a

# The data an H5 file holds: every dataset's path, dimensions, type and a hash of its values, so that two files
# are equal when they hold the same matrix whatever else (a digest attribute, a timestamp) differs.
h5_content <- function(path) {
  ls <- rhdf5::h5ls(path, recursive = TRUE)
  ds <- ls[ls$otype == "H5I_DATASET", , drop = FALSE]
  vapply(
    seq_len(nrow(ds)),
    function(k) {
      p <- paste(sub("/$", "", ds$group[[k]]), ds$name[[k]], sep = "/")
      p <- sub("^//", "/", p)
      v <- rhdf5::h5read(path, p)
      f <- tempfile()
      on.exit(unlink(f))
      saveRDS(v, f, compress = FALSE)
      sprintf(
        "%s|%s|%s|%s",
        p,
        ds$dim[[k]],
        ds$dclass[[k]],
        unname(tools::md5sum(f))
      )
    },
    ""
  )
}
same_content <- function(x, y) identical(h5_content(x), h5_content(y))
md5 <- function(f) unname(tools::md5sum(f))

rows <- list()
add <- function(check, ok, detail) {
  rows[[length(rows) + 1L]] <<- data.frame(
    check = check,
    result = if (isTRUE(ok)) "pass" else "fail",
    detail = detail,
    stringsAsFactors = FALSE
  )
}
guard <- function(check, expr) {
  tryCatch(expr, error = function(e) {
    add(check, FALSE, paste("error:", conditionMessage(e)))
  })
}

obj <- make_object()
base_h5 <- export_h5(obj, "a-first") # what the Builder's first export leaves

# 1. Only the configuration changed (another set of groups): offered the earlier sidecar, the export holds
#    the same matrix as one that was offered nothing.
guard("sidecar_config_change_same_matrix", {
  offered <- file.path(work, "offered-1.h5")
  file.copy(base_h5, offered)
  reused <- export_h5(
    obj,
    "b-offered",
    groups = c("sample", "cluster"),
    offer = list(list(path = offered, md5 = md5(offered)))
  )
  fresh <- export_h5(obj, "b-fresh", groups = c("sample", "cluster"))
  add(
    "sidecar_config_change_same_matrix",
    same_content(reused, fresh),
    "matrix after a configuration change, offered the earlier sidecar vs offered nothing"
  )
})

# 2. The matrix changed: the earlier sidecar no longer fits and must not be copied.
guard("sidecar_changed_matrix_rewritten", {
  offered <- file.path(work, "offered-2.h5")
  file.copy(base_h5, offered)
  changed <- make_object(bump = TRUE)
  reused <- export_h5(
    changed,
    "c-offered",
    offer = list(list(path = offered, md5 = md5(offered)))
  )
  fresh <- export_h5(changed, "c-fresh")
  add(
    "sidecar_changed_matrix_rewritten",
    same_content(reused, fresh) && !same_content(reused, base_h5),
    "a changed matrix, offered the sidecar of the old one: the result holds the new matrix, not the old"
  )
})

# 3. The offered sidecar is not what its recorded MD5 says: it must not be copied.
guard("sidecar_wrong_md5_rewritten", {
  offered <- file.path(work, "offered-3.h5")
  file.copy(base_h5, offered)
  reused <- export_h5(
    obj,
    "d-offered",
    offer = list(list(path = offered, md5 = strrep("0", 32L)))
  )
  fresh <- export_h5(obj, "d-fresh")
  add(
    "sidecar_wrong_md5_rewritten",
    same_content(reused, fresh),
    "an offered sidecar whose MD5 does not match: the matrix is written again"
  )
})

# 4. A sidecar that is gone is not an error.
guard("sidecar_missing_rewritten", {
  reused <- export_h5(
    obj,
    "e-offered",
    offer = list(list(
      path = file.path(work, "no-such.h5"),
      md5 = strrep("0", 32L)
    ))
  )
  fresh <- export_h5(obj, "e-fresh")
  add(
    "sidecar_missing_rewritten",
    same_content(reused, fresh),
    "an offered sidecar that does not exist: the matrix is written again"
  )
})

# 5. What the H5 holds, for the two runs of a pair to compare: the faster writer must leave the same data.
guard("h5_content_digest", {
  fresh <- export_h5(obj, "f-fresh")
  d <- h5_content(fresh)
  f <- tempfile()
  on.exit(unlink(f))
  writeLines(d, f)
  add(
    "h5_content_digest",
    TRUE,
    paste0("digest ", md5(f), " over ", length(d), " datasets")
  )
})

res <- do.call(rbind, rows)
utils::write.table(res, out_tsv, sep = "\t", quote = FALSE, row.names = FALSE)
