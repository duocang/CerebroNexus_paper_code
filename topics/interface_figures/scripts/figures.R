# Draw the interface figures (Figures 1-7, Supplementary Figures S1-S2) to
# the Genome Biology figure rules.
#
#   Rscript scripts/figures.R <inputs-dir> <captures-dir> <out-dir>
#
# Rules applied here (checked again by check_figures.R):
# - 170 mm wide (double column), at most 225 mm high, drawn at final size;
# - vector PDF via cairo_pdf with Arial embedded, text kept as text;
# - panel labels 8 pt bold upright; all other text 7 pt; nothing under 6 pt;
# - lines at least 0.25 pt;
# - colour-blind-safe palettes (Okabe-Ito based) for the drawn panels;
# - legends inside the figure, no figure titles in the file;
# - screenshots are rectangular crops of the native 3x captures, never
#   resampled, and each crop is placed at a scale where its smallest
#   interface text prints at 6 pt or more (recorded in figure-qa.csv).

suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) stop("Usage: figures.R <inputs-dir> <captures-dir> <out-dir>", call. = FALSE)
inputs <- args[[1]]
captures <- args[[2]]
out <- args[[3]]
dir.create(out, recursive = TRUE, showWarnings = FALSE)

WIDTH <- 170 # mm, Genome Biology double column
MAX_HEIGHT <- 225 # mm
FONT <- "Arial"
TEXT_PT <- 7
TAG_PT <- 8
MIN_PT <- 6
LINE <- 0.5 / .pt # 0.5 pt in ggplot linewidth units (mm)
TXT <- TEXT_PT / .pt # geom_text size for 7 pt

SELECTED <- "#D55E00"
OTHER <- "#C5C8CB"
# Okabe-Ito plus four darker/lighter companions for the 12 Ren cell types.
REN_PALETTE <- c(
  "#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00",
  "#CC79A7", "#000000", "#999999", "#8C510A", "#5AAE61", "#762A83"
)
DONORS <- c(donor1 = "#D55E00", donor2 = "#0072B2", donor3 = "#009E73", donor4 = "#CC79A7")

theme_gb <- function() {
  theme_classic(base_size = TEXT_PT, base_family = FONT) +
    theme(
      text = element_text(size = TEXT_PT, colour = "black"),
      axis.text = element_text(size = TEXT_PT, colour = "black"),
      axis.title = element_text(size = TEXT_PT),
      legend.text = element_text(size = TEXT_PT),
      legend.title = element_text(size = TEXT_PT),
      strip.text = element_text(size = TEXT_PT),
      axis.line = element_line(linewidth = LINE),
      axis.ticks = element_line(linewidth = LINE),
      axis.ticks.length = unit(1, "mm"),
      legend.key.size = unit(3, "mm"),
      legend.background = element_blank(),
      plot.margin = margin(1, 1, 1, 1, "mm"),
      plot.tag = element_text(size = TAG_PT, face = "bold", family = FONT),
      plot.tag.position = c(0, 1),
      plot.tag.location = "plot"
    )
}
# Embeddings: axis lines kept, coordinates themselves carry no meaning.
theme_embedding <- function() {
  theme_gb() + theme(axis.text = element_blank(), axis.ticks = element_blank())
}

# --- screenshots ------------------------------------------------------------

QA <- list()
qa_row <- function(...) QA[[length(QA) + 1L]] <<- data.frame(...)

capture_record <- function(name) {
  jsonlite::read_json(file.path(captures, paste0(name, ".json")), simplifyVector = TRUE)
}

# Box of a plot surface (canvas/img/svg) recorded in the capture, CSS px.
surface <- function(name, pick = 1L, filter = function(s) rep(TRUE, nrow(s))) {
  s <- capture_record(name)$surfaces
  s <- s[filter(s), , drop = FALSE]
  s <- s[order(-s$w * s$h), , drop = FALSE]
  unlist(s[pick, c("x", "y", "w", "h")])
}

# A crop of a capture placed `width_mm` wide. rect = c(x, y, w, h) in CSS px.
# Records the smallest interface text fully inside the crop at print size and
# any text the crop cuts through.
shot <- function(figure, panel, name, rect, width_mm) {
  record <- capture_record(name)
  dpr <- record$viewport$dpr
  img <- png::readPNG(file.path(captures, paste0(name, ".png")))
  px <- round(rect * dpr)
  stopifnot(px[1] >= 0, px[2] >= 0, px[1] + px[3] <= ncol(img), px[2] + px[4] <= nrow(img))
  crop <- img[(px[2] + 1):(px[2] + px[4]), (px[1] + 1):(px[1] + px[3]), 1:3]
  scale <- width_mm / rect[3]
  t <- record$text
  inside <- t$x >= rect[1] - 1 & t$y >= rect[2] - 1 &
    t$x + t$w <= rect[1] + rect[3] + 1 & t$y + t$h <= rect[2] + rect[4] + 1
  cut <- !inside & t$x < rect[1] + rect[3] & t$x + t$w > rect[1] & t$y < rect[2] + rect[4] & t$y + t$h > rect[2]
  min_pt <- if (any(inside)) min(t$px[inside]) * scale * .pt else NA_real_
  small <- inside & t$px * scale * .pt < MIN_PT
  qa_row(
    figure = figure, panel = panel, capture = name,
    crop_css = paste(round(rect), collapse = " "), width_mm = round(width_mm, 1),
    height_mm = round(rect[4] * scale, 1), ppi = round(px[3] / (width_mm / 25.4)),
    min_text_pt = round(min_pt, 2),
    below_6pt = paste(unique(t$text[small]), collapse = " | "),
    cut_text = paste(unique(t$text[cut]), collapse = " | ")
  )
  ggplot() +
    annotation_raster(crop, 0, px[3], -px[4], 0, interpolate = FALSE) +
    coord_fixed(xlim = c(0, px[3]), ylim = c(-px[4], 0), expand = FALSE) +
    theme_void(base_family = FONT) +
    theme(
      plot.margin = margin(0, 0, 0, 0),
      plot.tag = element_text(size = TAG_PT, face = "bold", family = FONT),
      plot.tag.position = c(0, 1), plot.tag.location = "plot"
    )
}
shot_height <- function(rect, width_mm) rect[4] * width_mm / rect[3]

# --- drawn panels -----------------------------------------------------------

raster_points <- function(...) ggrastr::rasterise(geom_point(...), dpi = 600)

# One cloud of cells. `colour` is a value per cell (mapped through `palette`
# when given); `sel` marks the cells drawn on top in `sel_colour`, which may
# itself be one value per selected cell.
cells_plot <- function(x, y, colour, sel = NULL, palette = NULL, sel_colour = SELECTED,
                       size = 0.05, sel_size = 0.35, border = FALSE, legend = FALSE) {
  d <- data.frame(x = x, y = y, colour = colour)
  keep <- is.finite(d$x) & is.finite(d$y)
  p <- ggplot(d[keep, ], aes(x, y)) +
    raster_points(aes(colour = colour), size = size, stroke = 0, show.legend = legend)
  p <- p + if (is.null(palette)) scale_colour_identity() else scale_colour_manual(values = palette, name = NULL)
  if (!is.null(sel) && any(sel & keep)) {
    s <- data.frame(x = x, y = y, fill = rep_len(sel_colour, length(x)))
    if (length(sel_colour) == sum(sel)) {
      s$fill <- NA
      s$fill[sel] <- sel_colour
    }
    s <- s[sel & keep, ]
    p <- p + if (border) {
      geom_point(data = s, aes(fill = fill), shape = 21, size = sel_size, stroke = 2 * LINE, colour = "black")
    } else {
      raster_points(data = s, aes(fill = fill), shape = 21, size = sel_size, stroke = 0, colour = "transparent")
    }
    p <- p + scale_fill_identity()
  }
  p
}

embedding <- function(d, colour, sel = NULL, xlab, ylab, xlim = NULL, ylim = NULL, ...) {
  cells_plot(d$x, d$y, colour, sel, ...) +
    coord_cartesian(xlim = xlim, ylim = ylim, expand = TRUE) +
    labs(x = xlab, y = ylab) + theme_embedding()
}

TIERS <- c("Single (1)", "Small (2\u20135)", "Medium (6\u201320)", "Large (21\u2013100)", "Hyper (>100)")
# The Viewer's Expansion bands layout: one band per clone-size tier, band
# width = number of cells. Only cells with a TCR have a position.
bands <- function(d, colour, sel = NULL, ...) {
  has <- !is.na(d$tier)
  cells_plot(d$band_x[has], d$band_y[has], colour[has], if (is.null(sel)) NULL else sel[has], ...) +
    scale_y_continuous(breaks = 0:4 + 0.5, labels = TIERS, limits = c(0, 5), expand = c(0, 0)) +
    scale_x_continuous(expand = c(0.01, 0)) +
    labs(x = "Cells in tier (band width = cell count)", y = NULL) +
    theme_gb() + theme(axis.text.x = element_blank(), axis.ticks.x = element_blank())
}

# A small key drawn as its own plot (legend inside the figure, not the caption).
key_plot <- function(labels, colours, ncol, width_mm = WIDTH, title = NULL, shape = 16) {
  gap <- 2.2 / (width_mm / ncol) # 2.2 mm from symbol to label
  n <- length(labels)
  d <- data.frame(
    label = factor(labels, levels = labels), colour = colours,
    col = (seq_len(n) - 1) %% ncol, row = (seq_len(n) - 1) %/% ncol
  )
  p <- ggplot(d, aes(col, -row)) +
    geom_point(aes(colour = colour), shape = shape, size = 1.6) +
    geom_text(aes(x = col + gap, label = label), hjust = 0, size = TXT, family = FONT) +
    scale_colour_identity() +
    scale_x_continuous(limits = c(-0.05, ncol), expand = c(0, 0)) +
    scale_y_continuous(limits = c(-max(d$row) - 0.5, if (is.null(title)) 0.5 else 1.3), expand = c(0, 0)) +
    theme_void(base_family = FONT) + theme(plot.margin = margin(0, 1, 0, 1, "mm"))
  if (!is.null(title)) p <- p + annotate("text", x = -0.02, y = 0.9, label = title, hjust = 0, size = TXT, family = FONT, fontface = "bold")
  p
}

text_plot <- function(label, hjust = 0) {
  ggplot() +
    annotate("text", x = hjust, y = 0.5, label = label, hjust = hjust, size = TXT, family = FONT, lineheight = 0.95) +
    scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) + scale_y_continuous(limits = c(0, 1), expand = c(0, 0)) +
    theme_void(base_family = FONT) + theme(plot.margin = margin(0, 0, 0, 0))
}

save_figure <- function(name, plot, height) {
  stopifnot(height <= MAX_HEIGHT)
  plot <- plot & theme(plot.tag = element_text(size = TAG_PT, face = "bold", family = FONT))
  ggsave(file.path(out, paste0(name, ".pdf")), plot,
    width = WIDTH, height = height, units = "mm", device = cairo_pdf, bg = "white"
  )
  # SVG copy for check_figures.R: its text and stroke attributes are in pt.
  dir.create(file.path(out, "qa"), showWarnings = FALSE)
  ggsave(file.path(out, "qa", paste0(name, ".svg")), plot,
    width = WIDTH, height = height, units = "mm", device = svglite::svglite, bg = "white"
  )
  ggsave(file.path(out, paste0(name, ".png")), plot,
    width = WIDTH, height = height, units = "mm", dpi = 300, device = ragg::agg_png, bg = "white"
  )
  message("Saved ", name, " (", WIDTH, " x ", round(height, 1), " mm)")
}

# --- crop rectangles from the capture records -------------------------------

# Viewer layout at the 1024 px viewport: the navigation sidebar ends at about
# x = 232; the page content runs from x = 240 to the right edge of the Info
# button.
text_box <- function(name, pattern, which = 1L, min_x = -Inf) {
  t <- capture_record(name)$text
  hit <- t[grepl(pattern, t$text, perl = TRUE) & t$x >= min_x, , drop = FALSE]
  if (!nrow(hit)) stop("No text matches ", pattern, " in ", name, call. = FALSE)
  unlist(hit[which, c("x", "y", "w", "h")])
}
content_area <- function(name, bottom) {
  info <- text_box(name, "^Info$")
  title <- text_box(name, "^(Projection|Spatial|Linked views|HLA & TCR Motifs)$", min_x = 240)
  left <- 252
  right <- info[1] + info[3] + 22
  top <- title[2] - 14
  bottom <- min(bottom, capture_record(name)$viewport$height)
  c(left, top, right - left, bottom - top)
}
largest_surface <- function(name) surface(name, filter = function(s) s$tag == "canvas")
# The Linked views status row: the count, its composition chip and the
# matched-view chip, up to (not including) the Focus/Clear buttons.
status_row <- function(name) {
  t <- capture_record(name)$text
  anchor <- t[grepl("selected$", t$text), , drop = FALSE][1, ]
  row <- t[abs(t$y - anchor$y) < 6 & t$x > 250 & !t$text %in% c("Focus", "Clear"), , drop = FALSE]
  x0 <- min(row$x) - 12
  x1 <- max(row$x + row$w) + 16
  c(x0, anchor$y - 12, x1 - x0, anchor$h + 24)
}

ren <- readRDS(file.path(inputs, "ren.rds"))
hla <- readRDS(file.path(inputs, "hla.rds"))
xen <- readRDS(file.path(inputs, "xenium.rds"))

# --- Figure 1: Viewer workspace and workflow --------------------------------

fig1 <- function() {
  canvas <- largest_surface("ren-projection")
  rect <- content_area("ren-projection", bottom = canvas[2] + canvas[4] + 10)
  a <- shot("Figure 1", "a", "ren-projection", rect, WIDTH)
  ha <- shot_height(rect, WIDTH)
  steps <- data.frame(
    x = c(0, 1, 2),
    head = c("Prepared objects", "Builder", "Viewer"),
    body = c("Seurat, SCE, AnnData, SpatialData", "Configure → review → build", "Select → compare → export")
  )
  b <- ggplot(steps) +
    geom_rect(aes(xmin = x - 0.42, xmax = x + 0.42, ymin = 0, ymax = 1), fill = "#F2F2F2", colour = "#7F7F7F", linewidth = LINE) +
    geom_text(aes(x, 0.68, label = head), fontface = "bold", size = TXT, family = FONT) +
    geom_text(aes(x, 0.3, label = body), size = TXT, family = FONT) +
    annotate("segment", x = c(0.44, 1.44), xend = c(0.56, 1.56), y = 0.5, yend = 0.5,
      linewidth = LINE, arrow = arrow(length = unit(1.2, "mm"), type = "closed")) +
    scale_x_continuous(limits = c(-0.45, 2.45), expand = c(0, 0)) +
    scale_y_continuous(limits = c(-0.05, 1.05), expand = c(0, 0)) +
    theme_void(base_family = FONT)
  modules <- c("Expression", "Linked views", "Spatial", "Immune repertoire", "HLA & TCR motifs")
  c <- ggplot(data.frame(x = seq_along(modules), label = modules)) +
    geom_rect(aes(xmin = x - 0.46, xmax = x + 0.46, ymin = 0, ymax = 1), fill = "white", colour = "#7F7F7F", linewidth = LINE) +
    geom_text(aes(x, 0.5, label = label), size = TXT, family = FONT) +
    scale_x_continuous(limits = c(0.5, length(modules) + 0.5), expand = c(0, 0)) +
    scale_y_continuous(limits = c(-0.05, 1.05), expand = c(0, 0)) +
    theme_void(base_family = FONT)
  plot <- a / b / c + plot_layout(heights = c(ha, 13, 6.5)) + plot_annotation(tag_levels = "a")
  save_figure("fig01-cerebronexus-overview", plot, ha + 13 + 6.5 + 10)
}

# --- Figure 2: Builder Configure and Review ---------------------------------

fig2 <- function() {
  # Builder layout: the dataset rail ends at about x = 265; the stage column
  # runs from there to the card edge.
  span <- function(top, bottom) c(278, top, 990 - 278, bottom - top)
  conf_title <- text_box("builder-configure", "^Complete Viewer demo$", which = 2L)
  conf_end <- text_box("builder-configure", "^Available metadata$")
  rect_a <- span(conf_title[2] - 14, conf_end[2] + conf_end[4] + 12)
  rev_title <- text_box("builder-review", "^Review before building$")
  rev_end <- text_box("builder-review", "^Spatial alignment demo$", which = 2L)
  rect_b <- span(rev_title[2] - 14, rev_end[2] + rev_end[4] + 26)
  a <- shot("Figure 2", "a", "builder-configure", rect_a, WIDTH)
  b <- shot("Figure 2", "b", "builder-review", rect_b, WIDTH)
  h <- c(shot_height(rect_a, WIDTH), shot_height(rect_b, WIDTH))
  plot <- a / b + plot_layout(heights = h) + plot_annotation(tag_levels = "a")
  save_figure("fig02-builder-workflow", plot, sum(h) + 6)
}

# --- Figure 3: Ren selection across expression and receptor views -----------

fig3 <- function() {
  d <- ren$cells
  groups <- sort(unique(d$group))
  pal <- setNames(REN_PALETTE[seq_along(groups)], groups)
  grey <- rep(OTHER, nrow(d))
  key <- key_plot(groups, unname(pal), ncol = 6)
  a <- embedding(d, d$group, palette = pal, xlab = "t-SNE 1", ylab = "t-SNE 2")
  b <- bands(d, d$group, palette = pal)
  c <- embedding(d, grey, sel = d$selected, xlab = "t-SNE 1", ylab = "t-SNE 2", sel_size = 0.3)
  dd <- bands(d, grey, sel = d$selected, sel_size = 0.3)
  rect <- status_row("ren-linked-local")
  strip <- shot("Figure 3", "status", "ren-linked-local", rect, 95)
  sel_key <- key_plot(c("Selected or matched", "Other cells"), c(SELECTED, OTHER), ncol = 2, width_mm = 75)
  hs <- shot_height(rect, 95)
  plot <- (key) /
    (a + b + plot_layout(widths = c(1, 1.15))) /
    (c + dd + plot_layout(widths = c(1, 1.15))) /
    (strip + sel_key + plot_layout(widths = c(95, 75))) +
    plot_layout(heights = c(9, 55, 55, hs)) &
    theme(plot.tag.position = c(0, 1))
  plot <- plot + plot_annotation(tag_levels = list(c("", "a", "b", "c", "d", "", "")))
  save_figure("fig03-linked-views", plot, 9 + 55 + 55 + hs + 8)
}

# --- Figure 4: Xenium spatial views -----------------------------------------

# Box (CSS px) of the dark tissue image inside a plot surface: the bounding box
# of near-black pixels of the capture.
dark_box <- function(name, rect) {
  dpr <- capture_record(name)$viewport$dpr
  img <- png::readPNG(file.path(captures, paste0(name, ".png")))
  px <- round(rect * dpr)
  sub <- img[(px[2] + 1):(px[2] + px[4]), (px[1] + 1):(px[1] + px[3]), 1:3]
  dark <- apply(sub, c(1, 2), max) < 0.06
  rows <- which(rowMeans(dark) > 0.2)
  cols <- which(colMeans(dark) > 0.2)
  c(rect[1] + (min(cols) - 1) / dpr, rect[2] + (min(rows) - 1) / dpr,
    (max(cols) - min(cols) + 1) / dpr, (max(rows) - min(rows) + 1) / dpr)
}

# Colour bar redrawn from the Viewer's own bar: colours are sampled from the
# captured bar, the end labels are its text.
colour_bar <- function(name, gene) {
  rec <- capture_record(name)
  lo <- text_box(name, "^0\\.0$")
  hi <- text_box(name, "^[0-9]+\\.[0-9]$", which = 2L)
  dpr <- rec$viewport$dpr
  img <- png::readPNG(file.path(captures, paste0(name, ".png")))
  y <- round((lo[2] + lo[4] / 2) * dpr)
  xs <- round(seq(lo[1] + lo[3] + 8, hi[1] - 8, length.out = 64) * dpr)
  cols <- rgb(img[y, xs, 1], img[y, xs, 2], img[y, xs, 3])
  hi_value <- as.numeric(rec$text$text[grepl("^[0-9]+\\.[0-9]$", rec$text$text)][2])
  d <- data.frame(x = seq(0, hi_value, length.out = 64), fill = cols)
  ggplot(d, aes(x, 0, fill = fill)) +
    geom_tile(height = 1, width = hi_value / 63) +
    scale_fill_identity() +
    scale_x_continuous(breaks = c(0, hi_value), labels = c("0.0", sprintf("%.1f", hi_value)), expand = c(0, 0)) +
    scale_y_continuous(expand = c(0, 0)) +
    labs(x = paste(gene, "expression"), y = NULL) +
    theme_gb() + theme(axis.text.y = element_blank(), axis.ticks.y = element_blank(), axis.line = element_blank(),
      plot.margin = margin(5, 6, 1, 6, "mm"))
}

fig4 <- function() {
  third <- (WIDTH - 6) / 3
  half <- (WIDTH - 4) / 2
  canvas <- function(name) largest_surface(name)
  ra <- dark_box("xenium-cluster", canvas("xenium-cluster"))
  rb <- dark_box("xenium-feature", canvas("xenium-feature"))
  # The RGB view draws no tissue image; it uses the same plot extent as b.
  cb <- canvas("xenium-feature")
  cc <- canvas("xenium-rgb")
  rc <- c(cc[1] + rb[1] - cb[1], cc[2] + rb[2] - cb[2], rb[3], rb[4])
  a <- shot("Figure 4", "a", "xenium-cluster", ra, third)
  b <- shot("Figure 4", "b", "xenium-feature", rb, third)
  c <- shot("Figure 4", "c", "xenium-rgb", rc, third)
  clusters <- sort(unique(xen$cells$cluster))
  # The Viewer's default categorical palette, in its legend order.
  viewer_pal <- c(
    "#FFC312", "#C4E538", "#12CBC4", "#FDA7DF", "#ED4C67", "#F79F1F", "#A3CB38", "#1289A7",
    "#D980FA", "#B53471", "#EE5A24", "#009432", "#0652DD", "#9980FA", "#833471", "#EA2027",
    "#006266", "#1B1464", "#5758BB", "#6F1E51", "#40407a", "#706fd3", "#f7f1e3", "#34ace0"
  )
  a_key <- key_plot(clusters, viewer_pal[seq_along(clusters)], ncol = 6, width_mm = third)
  b_bar <- colour_bar("xenium-feature", "Slc17a7")
  rgb_key <- key_plot(c("R: Slc17a7", "G: Gad1", "B: Gad2"), c("#E41A1C", "#4DAF4A", "#377EB8"), ncol = 1, width_mm = third, shape = 15)
  x <- xen$cells
  grey <- rep(OTHER, nrow(x))
  d <- embedding(x, grey, sel = x$selected, xlab = "UMAP 1", ylab = "UMAP 2", size = 0.3, sel_size = 0.6)
  e <- cells_plot(x$sx, x$sy, grey, x$selected, size = 0.3, sel_size = 0.6) +
    coord_fixed() + labs(x = "x (\u00b5m)", y = "y (\u00b5m)") + theme_gb()
  sel_key <- key_plot(c("Selected (500)", "Other cells"), c(SELECTED, OTHER), ncol = 2)
  h1 <- shot_height(ra, third)
  plot <- (a + b + c + plot_layout(widths = c(1, 1, 1))) /
    (a_key + b_bar + rgb_key + plot_layout(widths = c(1, 1, 1))) /
    sel_key /
    (d + e + plot_layout(widths = c(1, 1))) +
    plot_layout(heights = c(h1, 16, 4, 62))
  plot <- plot + plot_annotation(tag_levels = list(c("a", "b", "c", "", "", "", "", "d", "e")))
  save_figure("fig04-spatial-images", plot, h1 + 16 + 4 + 62 + 10)
}

# --- Figures 5 and 7: HLA/TCR selections ------------------------------------

donor_key <- function(sel) {
  n <- table(factor(hla$cells$donor[sel], levels = names(DONORS)))
  n <- n[n > 0]
  key_plot(c(sprintf("%s (%d selected)", names(n), as.integer(n)), "Other cells"), c(DONORS[names(n)], OTHER), ncol = length(n) + 1)
}
hla_panels <- function(sel, small) {
  d <- hla$cells
  grey <- rep(OTHER, nrow(d))
  cols <- DONORS[d$donor[sel]]
  size <- if (small) 1.4 else 0.6
  list(
    a = embedding(d, grey, sel = sel, sel_colour = cols, xlab = "UMAP 1", ylab = "UMAP 2", size = 0.15, sel_size = size, border = small),
    b = bands(d, grey, sel = sel, sel_colour = cols[!is.na(d$tier[sel])], size = 0.15, sel_size = size, border = small)
  )
}

fig5 <- function() {
  d <- hla$cells
  sel <- d$strict
  p <- hla_panels(sel, small = TRUE)
  local <- sel & d$x < -6
  stopifnot(sum(local) == 9L)
  pad <- 0.6
  c <- embedding(d, rep(OTHER, nrow(d)), sel = sel, sel_colour = DONORS[d$donor[sel]], xlab = "UMAP 1", ylab = "UMAP 2",
    size = 0.4, sel_size = 2, border = TRUE,
    xlim = range(d$x[local]) + c(-pad, pad), ylim = range(d$y[local]) + c(-pad, pad))
  rect <- status_row("hla-10")
  strip <- shot("Figure 5", "status", "hla-10", rect, 80)
  plot <- donor_key(sel) /
    (p$a + p$b + plot_layout(widths = c(1, 1.15))) /
    (c + (plot_spacer() / strip / plot_spacer() + plot_layout(heights = c(1, shot_height(rect, 80), 1))) + plot_layout(widths = c(1, 1.15))) +
    plot_layout(heights = c(5, 62, 45))
  plot <- plot + plot_annotation(tag_levels = list(c("", "a", "b", "c", "", "", "")))
  save_figure("fig05-hla-tcr-strict", plot, 5 + 62 + 45 + 8)
}

fig7 <- function() {
  d <- hla$cells
  sel <- d$gene
  p <- hla_panels(sel, small = FALSE)
  v <- hla$cdr3
  cd <- data.frame(cdr3 = factor(names(v), levels = rev(names(v))), n = as.integer(v))
  c <- ggplot(cd, aes(n, cdr3)) +
    geom_col(fill = "#0072B2", width = 0.7) +
    geom_text(aes(label = n), hjust = -0.2, size = TXT, family = FONT) +
    scale_x_continuous(expand = expansion(mult = c(0, 0.15))) +
    labs(x = "Cells in the 293-cell selection", y = "TRB CDR3") + theme_gb()
  rect <- status_row("hla-293")
  strip <- shot("Figure 7", "status", "hla-293", rect, 80)
  plot <- donor_key(sel) /
    (p$a + p$b + plot_layout(widths = c(1, 1.15))) /
    (c + (plot_spacer() / strip / plot_spacer() + plot_layout(heights = c(1, shot_height(rect, 80), 1))) + plot_layout(widths = c(1.15, 1))) +
    plot_layout(heights = c(5, 62, 50))
  plot <- plot + plot_annotation(tag_levels = list(c("", "a", "b", "c", "", "", "")))
  save_figure("fig07-hla-tcr-expanded", plot, 5 + 62 + 50 + 8)
}

# --- Figure 6: motif network and donor HLA table ----------------------------

fig6 <- function() {
  net <- largest_surface("hla-motif")
  a <- shot("Figure 6", "a", "hla-motif", net, WIDTH)
  ha <- shot_height(net, WIDTH)
  # Plotly's default qualitative colours, as the Viewer draws motifs.
  motif_key <- key_plot(paste("Motif", 1:5), c("#636EFA", "#EF553B", "#00CC96", "#AB63FA", "#FFA15A"), ncol = 5)
  page <- capture_record("hla-associations")$page_text
  rows <- regmatches(page, gregexpr("donor[0-9]\\tdonor\\t[a-z-]+\\t(true|false)\\t[0-9]+\\t[0-9]+", page))[[1]]
  stopifnot(length(rows) == 4L)
  tab <- do.call(rbind, strsplit(rows, "\t"))
  tab <- data.frame(Donor = tab[, 1], `HLA-A*02:01` = ifelse(tab[, 3] == "carrier", "Carrier", "Non-carrier"),
    `Motif cells` = formatC(as.integer(tab[, 6]), big.mark = ",", format = "d"), `Total cells` = formatC(as.integer(tab[, 5]), big.mark = ",", format = "d"),
    check.names = FALSE)
  long <- data.frame(
    col = rep(seq_along(tab), each = nrow(tab) + 1),
    row = rep(0:nrow(tab), times = ncol(tab)),
    label = unlist(lapply(names(tab), function(n) c(n, tab[[n]]))),
    head = rep(c(TRUE, rep(FALSE, nrow(tab))), times = ncol(tab))
  )
  b <- ggplot(long, aes(col, -row)) +
    geom_text(aes(label = label, fontface = ifelse(head, "bold", "plain")), hjust = 0, size = TXT, family = FONT) +
    annotate("segment", x = 0.95, xend = ncol(tab) + 0.8, y = -0.5, yend = -0.5, linewidth = LINE) +
    scale_x_continuous(limits = c(0.95, ncol(tab) + 0.9), expand = c(0, 0)) +
    scale_y_continuous(limits = c(-nrow(tab) - 0.5, 0.5), expand = c(0, 0)) +
    theme_void(base_family = FONT)
  plot <- a / motif_key / b + plot_layout(heights = c(ha, 4, 26))
  plot <- plot + plot_annotation(tag_levels = list(c("a", "", "b")))
  save_figure("fig06-hla-tcr-context", plot, ha + 4 + 26 + 8)
}

# --- Supplementary Figure S1: repertoire abundance and sharing --------------

figS1 <- function() {
  # As scRepertoire's clonalAbundance(scale = FALSE) draws it: one count line
  # per sample and cell type, coloured by cell type.
  ab <- as.data.frame(table(
    Abundance = ren$abundance$Abundance, sample = ren$abundance$values, type = ren$abundance$major_type
  ))
  ab <- ab[ab$Freq > 0, ]
  ab$Abundance <- as.integer(as.character(ab$Abundance))
  ab <- ab[order(ab$sample, ab$type, ab$Abundance), ]
  types <- sort(unique(as.character(ab$type)))
  pal <- setNames(c("#0072B2", "#009E73", "#D55E00", "#CC79A7", "#E69F00", "#56B4E9")[seq_along(types)], types)
  a <- ggplot(ab, aes(Abundance, Freq, colour = type, group = interaction(sample, type))) +
    geom_line(linewidth = LINE, alpha = 0.7) +
    scale_x_log10() + scale_y_continuous(labels = scales::comma) +
    scale_colour_manual(values = pal, name = "Cell type") +
    labs(x = "Cells per clonotype", y = "Number of clonotypes") +
    theme_gb() + theme(legend.position = "inside", legend.position.inside = c(0.98, 0.98), legend.justification = c(1, 1))
  sh <- data.frame(class = c("Private\n(1 sample)", "Shared within\nmajor type", "Shared across\nmajor types"), n = as.integer(ren$sharing))
  sh$class <- factor(sh$class, levels = sh$class)
  sh$label <- sprintf("%s (%.1f%%)", format(sh$n, big.mark = ","), 100 * sh$n / sum(sh$n))
  b <- ggplot(sh, aes(class, n, fill = class)) +
    geom_col(width = 0.6, show.legend = FALSE) +
    geom_text(aes(label = label), vjust = -0.4, size = TXT, family = FONT) +
    scale_fill_manual(values = c("#7F7F7F", "#0072B2", "#D55E00")) +
    scale_y_continuous(labels = scales::comma, expand = expansion(mult = c(0, 0.12))) +
    labs(x = NULL, y = "TRB clonotypes") + theme_gb()
  plot <- a / b + plot_layout(heights = c(60, 45)) + plot_annotation(tag_levels = "a")
  save_figure("figS01-immune-repertoire", plot, 60 + 45 + 8)
}

# --- Supplementary Figure S2: E18 atlas in the Viewer -----------------------

figS2 <- function() {
  canvas <- largest_surface("e18-projection")
  rect <- content_area("e18-projection", bottom = canvas[2] + canvas[4] + 10)
  a <- shot("Supplementary Figure S2", "", "e18-projection", rect, WIDTH)
  save_figure("figS02-million-cell-view", a, shot_height(rect, WIDTH))
}

for (f in list(fig1, fig2, fig3, fig4, fig5, fig6, fig7, figS1, figS2)) f()
qa <- do.call(rbind, QA)
write.csv(qa, file.path(out, "qa", "screenshot-qa.csv"), row.names = FALSE)
print(qa[, c("figure", "panel", "width_mm", "ppi", "min_text_pt", "below_6pt", "cut_text")])
