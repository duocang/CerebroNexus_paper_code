# Read the plotted values for the redrawn panels from the same data the Viewer
# shows, and check every count the figures and captions quote.
#
#   Rscript scripts/prepare_inputs.R <cerebronexus-src> <large-cache> <out-dir>
#
# <cerebronexus-src> is the CerebroNexus checkout the Viewer runs from (its
# inst/viewer helpers and example data sets are used), <large-cache> the
# CEREBRO_LARGE_CACHE folder that run-demo.R filled. Writes one .rds per data
# set and checks.json; the script stops if any count differs.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) {
  stop("Usage: prepare_inputs.R <cerebronexus-src> <large-cache> <out-dir>", call. = FALSE)
}
src <- normalizePath(args[[1]], mustWork = TRUE)
cache <- normalizePath(args[[2]], mustWork = TRUE)
out <- args[[3]]
dir.create(out, recursive = TRUE, showWarnings = FALSE)
topic <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))), ".."))
selections <- file.path(topic, "data", "selections")

suppressPackageStartupMessages(pkgload::load_all(src, export_all = FALSE, quiet = TRUE, helpers = FALSE))
viewer <- file.path(src, "inst", "viewer")
for (f in c("utility_functions.R", "clone_contract.R", "coordinated_views/bundle.R")) {
  source(file.path(viewer, f))
}
# Only the pure repertoire helpers, without the Shiny observers of data.R.
needed <- c(
  "ir_annotate_metadata", "ir_parse_segments", "ir_sharing_classify",
  "IR_SHARING_LEVELS_3", "IR_SHARING_LEVELS_2"
)
for (e in parse(file.path(viewer, "immune_repertoire", "data.R"))) {
  if (is.call(e) && identical(e[[1]], as.name("<-")) && as.character(e[[2]]) %in% needed) eval(e)
}

selection <- function(name) {
  jsonlite::read_json(file.path(selections, paste0(name, ".json")), simplifyVector = TRUE)$selection$cells
}

# R translation of the Viewer's "Expansion bands" clone layout: one band per
# expansion tier, cells in original row order along x, deterministic jitter
# (Knuth multiplicative hash, as in the JavaScript) within the band.
bands <- function(clone) {
  sizes <- table(clone)
  size <- as.numeric(sizes[clone])
  tier <- as.integer(cerebro_clone_expansion(size))
  xy <- matrix(NA_real_, length(size), 2)
  for (k in sort(unique(tier[!is.na(tier)]))) {
    ix <- which(tier == k)
    xy[ix, 1] <- seq_along(ix) - 1
    xy[ix, 2] <- k - 1 + 0.1 + ((as.double(ix) * 2654435761) %% 4294967296) / 4294967296 * 0.8
  }
  data.frame(band_x = xy[, 1], band_y = xy[, 2], tier = tier, clone = clone)
}

checks <- list(cerebronexus_src = src)

# Ren COVID-19 atlas (Figures 1, 3, S1).
crb <- file.path(cache, "ren", "cerebro-v2", "cerebro_ren_covid_1.46m.crb")
x <- read_cerebro_file(crb)
cells <- qs2::qs_read(sub("\\.crb$", ".viewer/common/cell_order.qs2", crb))
md <- x$getMetaData()
ir <- qs2::qs_read(sub("\\.crb$", ".immune.qs2", crb))
tcr <- cv_clone_per_cell(ir, cells, "TCR")
sel <- match(selection("ren-linked-local"), cells)
xy <- as.matrix(x$projections$tsne)
ren <- data.frame(
  cell = cells, x = xy[, 1], y = xy[, 2],
  group = as.character(md$major_type),
  selected = seq_along(cells) %in% sel,
  bands(tcr$clone)
)
stopifnot(
  nrow(ren) == 1462702L, !anyDuplicated(cells), !anyNA(sel),
  length(sel) == 13556L, sum(!is.na(tcr$clone)) == 220968L,
  sum(!is.na(tcr$clone[sel])) == 6569L
)
ir <- ir_annotate_metadata(ir, transform(md, cell_barcode = cells), "major_type")
abundance <- scRepertoire::clonalAbundance(ir, cloneCall = "aa", chain = "both", group.by = "major_type", scale = FALSE)
sharing <- table(ir_sharing_classify(ir_parse_segments(ir, "TRB", columns = c("sample", "major_type")), "sample", "major_type")$sharing)
saveRDS(list(cells = ren, abundance = abundance$data, sharing = sharing), file.path(out, "ren.rds"))
checks$ren <- list(
  cells = nrow(ren), tcr_cells = sum(!is.na(tcr$clone)), receptor_records = sum(vapply(ir, nrow, 0L)),
  selected = length(sel), selected_tcr = sum(!is.na(tcr$clone[sel])), selected_no_tcr = length(sel) - sum(!is.na(tcr$clone[sel])),
  trb_sharing = as.list(setNames(as.integer(sharing), names(sharing)))
)
rm(x, md, ir, ren, tcr, xy)
invisible(gc())

# HLA & TCR example (Figures 5-7).
x <- read_cerebro_file(file.path(src, "inst", "extdata", "examples", "demo_hla_tcr_dextramer.crb"))
md <- x$getMetaData()
ir <- x$immune_repertoire
tcr <- cv_clone_per_cell(ir, md$cell_barcode, "TCR")
xy <- as.matrix(x$projections$umap)
strict <- match(selection("hla-10"), md$cell_barcode)
gene <- match(selection("hla-293"), md$cell_barcode)
records <- do.call(rbind, lapply(ir, function(d) d[, c("barcode", "CTaa"), drop = FALSE]))
cdr3 <- sort(table(sub(".*_", "", records$CTaa[match(selection("hla-293"), records$barcode)])), decreasing = TRUE)
hla <- data.frame(
  cell = md$cell_barcode, x = xy[, 1], y = xy[, 2], donor = as.character(md$sample),
  strict = seq_len(nrow(md)) %in% strict, gene = seq_len(nrow(md)) %in% gene,
  bands(tcr$clone)
)
stopifnot(
  nrow(hla) == 12000L, !anyDuplicated(hla$cell), !anyNA(c(strict, gene)),
  length(strict) == 10L, length(gene) == 293L,
  length(cdr3) == 10L, max(cdr3) == 227L
)
saveRDS(list(cells = hla, cdr3 = cdr3), file.path(out, "hla.rds"))
checks$hla <- list(
  cells = nrow(hla), strict = length(strict), gene = length(gene),
  strict_by_donor = as.list(table(hla$donor[strict])), gene_by_donor = as.list(table(hla$donor[gene])),
  gene_trb_cdr3 = length(cdr3), largest_cdr3 = max(cdr3)
)

# Xenium example (Figure 4d,e).
x <- read_cerebro_file(file.path(src, "inst", "extdata", "examples", "demo_spatial_xenium.crb"))
md <- x$getMetaData()
xy <- as.matrix(x$projections$umap)
sp <- x$spatial$fov$coordinates
sp <- as.matrix(sp[match(md$cell_barcode, rownames(sp)), 1:2])
sel <- match(selection("xenium-linked-selected"), md$cell_barcode)
xen <- data.frame(
  cell = md$cell_barcode, x = xy[, 1], y = xy[, 2], sx = sp[, 1], sy = sp[, 2],
  cluster = as.character(md$cluster), selected = seq_len(nrow(md)) %in% sel
)
stopifnot(nrow(xen) == 5000L, length(sel) == 500L, !anyNA(sel), !anyNA(sp), !anyDuplicated(xen$cell))
saveRDS(list(cells = xen), file.path(out, "xenium.rds"))
checks$xenium <- list(cells = nrow(xen), selected = length(sel), clusters = length(unique(xen$cluster)))

jsonlite::write_json(checks, file.path(out, "checks.json"), auto_unbox = TRUE, pretty = TRUE)
message("All counts match.")
