# Make the saved selections the captures open, read the plotted values for the
# redrawn panels from the same data the Viewer shows, and record every count the
# figures and the manuscript quote in data/checks.json.
#
#   Rscript scripts/prepare_inputs.R <large-cache> <out-dir>
#
# <large-cache> is the CEREBRO_LARGE_CACHE folder that run-demo.R filled (only
# the Ren data set is read here). <out-dir> receives one .rds per data set.
# CerebroNexus is the INSTALLED package (library()), the revision run.sh
# installed from the locked commit: its readCerebro() reads the data sets and
# the example CRBs are those of the installed package. Nothing is read from a
# source tree.
#
# No count is typed here. The selections are made by the rules below from the
# data as it is; the counts are computed, written to data/checks.json and read
# back by capture_viewer.R (what the page must show) and figures.R (the
# captions and the checks of the captures). The script stops only if the data
# contradict themselves (duplicate cells, a selection outside the data, an
# empty selection, a saved Ren selection that no longer matches the Ren data).

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) {
  stop("Usage: prepare_inputs.R <large-cache> <out-dir>", call. = FALSE)
}
cache <- normalizePath(args[[1]], mustWork = TRUE)
out <- args[[2]]
dir.create(out, recursive = TRUE, showWarnings = FALSE)
topic <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))), ".."))
selections <- file.path(topic, "data", "selections")
dir.create(selections, recursive = TRUE, showWarnings = FALSE)

suppressPackageStartupMessages(library(CerebroNexus))
examples <- system.file("extdata", "examples", package = "CerebroNexus", mustWork = TRUE)

# ---- Selection rules ---------------------------------------------------------
# Each rule is an attribute filter on the data set the Viewer shows, so it picks
# the same biological cells whatever the size of the example. Applied to the
# example CRBs of the revision that first had these figures (12,000 HLA & TCR
# cells, 5,000 Xenium cells) they gave 10, 293 and 500 cells.
#
# HLA & TCR, Figure 5: the cells that carry one exact TRB, the TRB gene segments
# TRBV19 / TRBJ1-5 / TRBC1 with the CDR3 CASSIYSNQPQHF (a TRB found in donor 1
# and donor 2).
RULE_STRICT <- list(trb_genes = "TRBV19.None.TRBJ1-5.TRBC1", trb_cdr3 = "CASSIYSNQPQHF")
# HLA & TCR, Figure 7: the gene-defined clone, all cells with the paired gene
# segments TRAV27 / TRAJ42 and TRBV19 / TRBJ2-7 (CTgene), whatever their CDR3.
RULE_GENE_CLONE <- "TRAV27.TRAJ42.TRAC_TRBV19.None.TRBJ2-7.TRBC2"
# Xenium, Figure 4d,e: the cells in one box of the UMAP, in UMAP units
# (UMAP 1 from xmin to xmax, UMAP 2 from ymin up).
RULE_XENIUM_BOX <- c(xmin = -4.165, xmax = 0.447, ymin = 6.67)

# ---- The Viewer's clone and band rules, as the Viewer states them ------------
# (Clone call = CTgene, TCR chains TRA/TRB/TRG/TRD, scRepertoire's cloneSize
# bins, one clone per cell, clones ordered by size and then by key; the bands
# layout is the Viewer's client-side layout: one band per tier that is present,
# cells in row order along x, a fixed hash of the row for the jitter.)
TCR_CHAINS <- c("TRA", "TRB", "TRG", "TRD")
CLONE_BINS <- c(0, 1, 5, 20, 100, Inf)

clone_per_cell <- function(ir, cells, chains = TCR_CHAINS) {
  rows <- lapply(ir, function(df) {
    if (is.null(df) || !all(c("barcode", "CTgene") %in% names(df))) {
      return(NULL)
    }
    gene <- as.character(df$CTgene)
    ref <- if ("CTstrict" %in% names(df)) as.character(df$CTstrict) else gene
    blank <- is.na(ref) | !nzchar(ref)
    ref[blank] <- gene[blank]
    keep <- Reduce(`|`, lapply(chains, function(ch) grepl(ch, ref, fixed = TRUE)))
    if (!any(keep, na.rm = TRUE)) {
      return(NULL)
    }
    data.frame(barcode = as.character(df$barcode[keep]), clone = gene[keep])
  })
  rows <- do.call(rbind, rows)
  rows <- rows[!is.na(rows$clone) & nzchar(rows$clone), , drop = FALSE]
  rows <- rows[!duplicated(rows$barcode), , drop = FALSE]
  list(clone = rows$clone[match(cells, rows$barcode)])
}

# Clone keys in the order the Linked views stack layout lists them (largest
# first, ties by key in C order); position - 1 is the column of the clone there.
clone_order <- function(clone) {
  sizes <- table(clone)
  keys <- names(sizes)
  keys[order(-as.integer(sizes), keys, method = "radix")]
}

bands <- function(clone) {
  sizes <- table(clone)
  size <- as.numeric(sizes[clone])
  tier <- as.integer(cut(size, CLONE_BINS, right = TRUE, include.lowest = TRUE))
  present <- sort(unique(tier[!is.na(tier)]))
  xy <- matrix(NA_real_, length(size), 2)
  for (b in seq_along(present)) {
    ix <- which(tier == present[[b]])
    xy[ix, 1] <- seq_along(ix) - 1
    xy[ix, 2] <- b - 1 + 0.1 + ((as.double(ix) * 2654435761) %% 4294967296) / 4294967296 * 0.8
  }
  data.frame(band_x = xy[, 1], band_y = xy[, 2], tier = tier, clone = clone)
}

# ---- Saved Linked views files -----------------------------------------------
# The file contract (cerebronexus-linked-view, version 1) is the one the
# Viewer's Share menu writes: the data set is named by its cell count and the
# MD5 of its sorted cell identifiers.
cell_fingerprint <- function(cells) {
  cells <- sort(enc2utf8(cells), method = "radix")
  path <- tempfile("fingerprint-")
  on.exit(unlink(path))
  writeBin(charToRaw(paste0(nchar(cells, type = "bytes"), ":", cells, collapse = "")), path)
  paste0("md5-cell-set-v1:", unname(tools::md5sum(path)))
}
no_fields <- function() structure(list(), names = character(0))
centred <- function(space) list(space = space, viewport = list(cx = 0.5, cy = 0.5, span = 1), rotation = NULL)
view_settings <- function(colour, projections, lenses, display = list(), spatial = NULL, focus = NULL) {
  list(
    colour = list(mode = colour$mode, genes = I(character(0)), gene = NULL, rgb_genes = I(character(0)), clip = colour$clip),
    projections = I(projections),
    spatial_sections = I(if (is.null(spatial)) character(0) else spatial$section),
    active_spatial = if (is.null(spatial)) NULL else spatial$section,
    filters = no_fields(),
    hidden_levels = I(character(0)),
    display = modifyList(list(
      percentage_cells = 100, point_size = 3, point_opacity = 0.8, group_labels = TRUE, cell_borders = FALSE,
      background_images = TRUE, selection_mode = "box", clone_layout = "stack", keep_square = FALSE
    ), display),
    focus_space = focus,
    lenses = lenses,
    spatial_backgrounds = if (is.null(spatial)) I(list()) else list(spatial),
    trekker = list(dissolve_percentage = 0, evidence = FALSE, niche_radius = 250)
  )
}
as_json <- function(x, pretty = FALSE) {
  as.character(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", digits = NA, pretty = pretty))
}
write_selection <- function(name, cells, selected, source, geometry, view) {
  doc <- list(
    schema = "cerebronexus-linked-view", version = 1L,
    dataset = list(cell_count = length(cells), cell_fingerprint = cell_fingerprint(cells)),
    selection = list(cells = I(selected), source = source, geometry = geometry),
    view = view
  )
  file <- file.path(selections, paste0(name, ".json"))
  # An unchanged selection keeps its file (and its timestamp).
  if (file.exists(file)) {
    old <- jsonlite::read_json(file)
    old$created_at <- NULL
    if (identical(as_json(jsonlite::fromJSON(as_json(doc), simplifyVector = FALSE)), as_json(old))) {
      return(invisible(file))
    }
  }
  doc <- c(doc[1:2], list(created_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")), doc[-(1:2)])
  writeLines(as_json(doc, TRUE), file)
  invisible(file)
}
box_geometry <- function(space, x0, x1, y0, y1) {
  list(space = space, mode = "box", polygon = rbind(c(x0, y0), c(x1, y0), c(x1, y1), c(x0, y1)))
}

checks <- list(
  cerebronexus = list(
    version = as.character(utils::packageVersion("CerebroNexus")),
    commit = Sys.getenv("CEREBRO_COMMIT", "")
  ),
  rules = list(
    hla_strict = sprintf("cells whose TRB has the genes %s and the CDR3 %s", RULE_STRICT$trb_genes, RULE_STRICT$trb_cdr3),
    hla_gene = sprintf("cells whose CTgene is %s", RULE_GENE_CLONE),
    xenium = sprintf(
      "cells with UMAP 1 in [%g, %g] and UMAP 2 >= %g",
      RULE_XENIUM_BOX[["xmin"]], RULE_XENIUM_BOX[["xmax"]], RULE_XENIUM_BOX[["ymin"]]
    ),
    ren = "the saved selection data/selections/ren-linked-local.json, kept and checked against the Ren data"
  )
)

# ---- Ren COVID-19 atlas (Figures 1, 3, S1) -----------------------------------
prepared <- function(name) {
  dirs <- Sys.glob(file.path(cache, name, "cerebro-v*"))
  dirs <- dirs[file.exists(file.path(dirs, "demo-version"))]
  if (!length(dirs)) stop("No prepared ", name, " data set in ", cache, ". Run run-demo.R --data=", name, call. = FALSE)
  dirs[which.max(as.integer(sub(".*-v", "", basename(dirs))))]
}
ren_dir <- prepared("ren")
ren_crb <- setdiff(Sys.glob(file.path(ren_dir, "*.crb")), Sys.glob(file.path(ren_dir, "*_compressed.crb")))
stopifnot(length(ren_crb) == 1L)
x <- readCerebro(ren_crb)
md <- x$getMetaData()
cells <- md$cell_barcode
ir <- x$getImmuneRepertoire()
tcr <- clone_per_cell(ir, cells)
saved <- jsonlite::read_json(file.path(selections, "ren-linked-local.json"), simplifyVector = TRUE)
sel <- match(saved$selection$cells, cells)
if (anyNA(sel) || anyDuplicated(cells) || saved$dataset$cell_count != length(cells) ||
  !identical(saved$dataset$cell_fingerprint, cell_fingerprint(cells))) {
  stop("The saved Ren selection does not belong to the Ren data set in ", ren_dir, call. = FALSE)
}
xy <- as.matrix(x$projections$tsne)
ren <- data.frame(
  cell = cells, x = xy[, 1], y = xy[, 2],
  group = as.character(md$major_type),
  selected = seq_along(cells) %in% sel,
  bands(tcr$clone)
)

# TRB clonotype (V;J;CDR3, as the Viewer's Clone sharing tab defines it) of every
# receptor row: the first "_" part of CTgene that names TRB, its first V and J
# gene and the CDR3 of CTaa at the same position.
trb_clonotype <- function(gene, aa, chain = "TRB") {
  if (!length(gene)) {
    return(character(0))
  }
  key <- paste(gene, aa, sep = "\034")
  first <- which(!duplicated(key))
  one <- function(g, a) {
    gp <- strsplit(g, "_", fixed = TRUE)[[1]]
    allele <- sub(";.*$", "", gp)
    slot <- which(grepl(chain, allele, fixed = TRUE) & allele != "NA")[1]
    if (is.na(slot)) {
      return(NA_character_)
    }
    cdr3 <- sub(";.*$", "", strsplit(a, "_", fixed = TRUE)[[1]][slot])
    tokens <- strsplit(allele[slot], ".", fixed = TRUE)[[1]]
    v <- tokens[startsWith(tokens, paste0(chain, "V"))][1]
    j <- tokens[startsWith(tokens, paste0(chain, "J"))][1]
    if (is.na(v) || is.na(j) || is.na(cdr3) || cdr3 == "NA" || !nzchar(cdr3)) {
      return(NA_character_)
    }
    paste(v, j, cdr3, sep = ";")
  }
  id <- vapply(first, function(i) one(gene[[i]], aa[[i]]), "")
  id[match(key, key[first])]
}
rows <- do.call(rbind, Map(function(df, sample) {
  data.frame(
    clone = trb_clonotype(as.character(df$CTgene), as.character(df$CTaa)),
    sample = rep_len(sample, nrow(df)), group = as.character(md$major_type[match(df$barcode, cells)])
  )
}, ir, names(ir)))
rows <- rows[!is.na(rows$clone), ]
# Private: one sample; shared within group: >= 2 samples, one group; shared
# across groups: >= 2 groups (NA samples and groups do not count). The group is
# the major type, the sharing unit the sample.
n_distinct <- function(values) {
  ok <- !is.na(values)
  pairs <- unique(data.frame(clone = rows$clone[ok], value = values[ok]))
  as.integer(table(factor(pairs$clone, levels = unique(rows$clone))))
}
n_samples <- n_distinct(rows$sample)
n_groups <- n_distinct(rows$group)
SHARING <- c("Private", "Public (within-group)", "Public (cross-group)")
class <- ifelse(n_samples <= 1, SHARING[1], ifelse(n_groups >= 2, SHARING[3], SHARING[2]))
sharing <- table(factor(class, levels = SHARING))

annotated <- Map(function(df) {
  df$major_type <- as.character(md$major_type[match(df$barcode, cells)])
  df
}, ir)
abundance <- scRepertoire::clonalAbundance(annotated, cloneCall = "aa", chain = "both", group.by = "major_type", scale = FALSE)

stopifnot(!anyDuplicated(cells), length(sel) > 0L, sum(!is.na(tcr$clone)) > 0L, sum(sharing) > 0L)
saveRDS(list(cells = ren, abundance = abundance$data, sharing = sharing), file.path(out, "ren.rds"))
checks$ren <- list(
  data = basename(ren_dir),
  cells = nrow(ren), tcr_cells = sum(!is.na(tcr$clone)), receptor_records = sum(vapply(ir, nrow, 0L)),
  selected = length(sel), selected_tcr = sum(!is.na(tcr$clone[sel])), selected_no_tcr = length(sel) - sum(!is.na(tcr$clone[sel])),
  trb_sharing = as.list(setNames(as.integer(sharing), names(sharing)))
)
rm(x, md, ir, ren, tcr, xy, rows, annotated, abundance)
invisible(gc())

# ---- HLA & TCR example (Figures 5-7) ------------------------------------------
x <- readCerebro(file.path(examples, "demo_hla_tcr_dextramer.crb"))
md <- x$getMetaData()
cells <- md$cell_barcode
ir <- x$getImmuneRepertoire()
tcr <- clone_per_cell(ir, cells)
xy <- as.matrix(x$projections$umap)
records <- do.call(rbind, lapply(ir, function(d) d[, c("barcode", "CTgene", "CTaa"), drop = FALSE]))
trb_genes <- sub(".*_", "", records$CTgene)
trb_cdr3 <- sub(".*_", "", records$CTaa)
strict <- match(unique(records$barcode[trb_genes == RULE_STRICT$trb_genes & trb_cdr3 == RULE_STRICT$trb_cdr3]), cells)
gene <- match(unique(records$barcode[records$CTgene == RULE_GENE_CLONE]), cells)
cdr3 <- sort(table(sub(".*_", "", records$CTaa[match(cells[gene], records$barcode)])), decreasing = TRUE)
hla <- data.frame(
  cell = cells, x = xy[, 1], y = xy[, 2], donor = as.character(md$sample),
  strict = seq_along(cells) %in% strict, gene = seq_along(cells) %in% gene,
  bands(tcr$clone)
)
stopifnot(!anyDuplicated(cells), !anyNA(c(strict, gene)), length(strict) > 0L, length(gene) > 0L, length(cdr3) > 0L)
saveRDS(list(cells = hla, cdr3 = cdr3), file.path(out, "hla.rds"))

hla_lenses <- list(centred("projection::umap"), centred("clone"))
hla_view <- view_settings(list(mode = "sample", clip = 0), "umap", hla_lenses, focus = "clone")
# Figure 5 opens the exact-TRB cells without a drawn box; Figure 7 draws the box
# around the clone's column in the stack layout (columns are the clones ordered
# by size, x = position - 1, y = the cells stacked from 0).
write_selection("hla-10", cells, cells[strict], "Clonal expansion (TCR)", NULL, hla_view)
column <- match(RULE_GENE_CLONE, clone_order(tcr$clone)) - 1L
write_selection(
  "hla-293", cells, cells[gene], "Clonal expansion (TCR)",
  box_geometry("clone", column - 0.45, column + 0.45, -0.5, length(gene) - 0.5), hla_view
)
checks$hla <- list(
  cells = nrow(hla), strict = length(strict), gene = length(gene),
  strict_by_donor = as.list(table(hla$donor[strict])), gene_by_donor = as.list(table(hla$donor[gene])),
  gene_trb_cdr3 = length(cdr3), largest_cdr3 = max(cdr3), gene_clone_column = column
)
rm(x, md, ir, records, tcr)

# ---- Xenium example (Figure 4d,e) ---------------------------------------------
x <- readCerebro(file.path(examples, "demo_spatial_xenium.crb"))
md <- x$getMetaData()
cells <- md$cell_barcode
xy <- as.matrix(x$projections$umap)
sp <- x$spatial$fov$coordinates
sp <- as.matrix(sp[match(cells, rownames(sp)), 1:2])
sel <- which(xy[, 1] >= RULE_XENIUM_BOX[["xmin"]] & xy[, 1] <= RULE_XENIUM_BOX[["xmax"]] & xy[, 2] >= RULE_XENIUM_BOX[["ymin"]])
xen <- data.frame(
  cell = cells, x = xy[, 1], y = xy[, 2], sx = sp[, 1], sy = sp[, 2],
  cluster = as.character(md$cluster), selected = seq_along(cells) %in% sel
)
stopifnot(!anyDuplicated(cells), length(sel) > 0L, !anyNA(sp))
saveRDS(list(cells = xen), file.path(out, "xenium.rds"))
# The box in the Linked views' normalised UMAP coordinates (0 to 1 over the
# extent of the data; the top edge a little above the data).
norm <- function(v, axis) (v - min(xy[, axis])) / diff(range(xy[, axis]))
background <- list(
  section = "fov", mode = "image", image_id = "external:fov:1:Tissue background", opacity = 0.6,
  alignment = list(
    offset_x = 0, offset_y = -10, scale_x = 1, scale_y = 1, rotation = 0, lock_aspect = TRUE,
    flip_x = FALSE, flip_y = TRUE, show = TRUE
  )
)
write_selection(
  "xenium-linked-selected", cells, cells[sel], "umap (expression)",
  box_geometry(
    "projection::umap", norm(RULE_XENIUM_BOX[["xmin"]], 1), norm(RULE_XENIUM_BOX[["xmax"]], 1),
    norm(RULE_XENIUM_BOX[["ymin"]], 2), 1.02
  ),
  view_settings(list(mode = "cluster", clip = 0.01), "umap", list(centred("projection::umap"), centred("spatial::fov")),
    display = list(point_size = 5, point_opacity = 1, group_labels = FALSE),
    spatial = background
  )
)
checks$xenium <- list(cells = nrow(xen), selected = length(sel), clusters = length(unique(xen$cluster)))

# ---- 10x E18 mouse brain (Supplementary Figure S2) ---------------------------
# Only its size: the capture waits for the Viewer to report this many points.
e18_dir <- prepared("1m")
e18_crb <- setdiff(Sys.glob(file.path(e18_dir, "*.crb")), Sys.glob(file.path(e18_dir, "*_compressed.crb")))
stopifnot(length(e18_crb) == 1L)
x <- readCerebro(e18_crb)
checks$e18 <- list(data = basename(e18_dir), cells = nrow(x$getMetaData()))
rm(x)

jsonlite::write_json(checks, file.path(topic, "data", "checks.json"), auto_unbox = TRUE, pretty = TRUE, digits = NA)
message("Counts written to data/checks.json")
