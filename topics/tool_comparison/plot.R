#!/usr/bin/env Rscript
# Two figures of the tool comparison, Genome Biology artwork rules (170 mm wide, at most 225 mm tall, Arial 7 pt text,
# panel labels 8 pt bold, lines >= 0.25 pt, Okabe-Ito colours, no title, vector PDF with embedded fonts, PNG preview):
#
#   figures/fig-tool-timing.pdf      what a run of bench.py measured: where each viewer stands (a), how start, colouring
#                                    by a gene, memory and build time grow with the number of cells (b-g)
#   figures/fig-tool-capability.pdf  what each viewer does with the data it is given and how well its selections can be
#                                    taken out of it (features/*.csv, measured once, not by bench.py)
#
#   Rscript plot.R [RUN_DIR] [--out DIR] [--only capability|timing]      without RUN_DIR the newest run in runs/ is drawn
options(warn = 1)
suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
  library(ggrepel)
  library(ggbeeswarm)
})
args <- commandArgs(trailingOnly = TRUE)
here <- dirname(normalizePath(
  sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[[1L]]),
  winslash = "/"
))
only_i <- match("--only", args)
only <- if (is.na(only_i)) "" else args[[only_i + 1L]]
out_i <- match("--out", args)
out_dir <- if (is.na(out_i)) file.path(here, "figures") else args[[out_i + 1L]]
pos <- setdiff(
  args,
  c(
    "--out",
    "--only",
    if (!is.na(out_i)) args[[out_i + 1L]],
    if (!is.na(only_i)) args[[only_i + 1L]]
  )
)
run <- if (length(pos)) {
  pos[[1L]]
} else {
  runs <- list.dirs(file.path(here, "runs"), recursive = FALSE)
  runs <- runs[file.exists(file.path(runs, "starts.tsv")) & !grepl("/_", runs)]
  if (!length(runs)) {
    stop("no run in runs/")
  }
  sort(runs)[[length(runs)]]
}
message("run: ", run)
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
family <- if ("Arial" %in% systemfonts::system_fonts()$family) {
  "Arial"
} else {
  stop("Arial is not installed")
}
qa_dir <- Sys.getenv("NATURE_FIGURE_DIR", "") # the nature-figure skill folder: if set, the alignment gate runs on every figure

# ---------------------------------------------------------------------------------------------- shared look
tools <- c(
  cerebronexus_h5 = "CerebroNexus (HDF5)",
  cerebronexus_embedded = "CerebroNexus (embedded)",
  shinycell = "ShinyCell",
  isee = "iSEE",
  cellxgene = "cellxgene",
  vitessce = "Vitessce"
)
cols <- c(
  "CerebroNexus (HDF5)" = "#D55E00",
  "CerebroNexus (embedded)" = "#E69F00",
  "ShinyCell" = "#009E73",
  "iSEE" = "#56B4E9",
  "cellxgene" = "#7F7F7F",
  "Vitessce" = "#CC79A7"
)
shapes <- c(
  "CerebroNexus (HDF5)" = 16,
  "CerebroNexus (embedded)" = 1,
  "ShinyCell" = 17,
  "iSEE" = 15,
  "cellxgene" = 18,
  "Vitessce" = 6
)
sh <- function(x) x # one name for a tool everywhere in the figure
lab <- function(x) factor(tools[x], levels = tools)
is_cnx <- function(x) grepl("^CerebroNexus", x)
SZ <- 7 / ggplot2::.pt # a 7 pt text in geom_text units
fmt_cells <- function(x) {
  ifelse(
    x >= 1e6,
    paste0(round(x / 1e6, 1), "M"),
    ifelse(x >= 1e3, paste0(x / 1e3, "k"), x)
  )
}
fmt_num <- function(x) format(x, scientific = FALSE, drop0trailing = TRUE)

theme_gb <- theme_classic(base_size = 7, base_family = family) +
  theme(
    text = element_text(size = 7, family = family),
    axis.text = element_text(size = 7, colour = "black"),
    axis.title = element_text(size = 7),
    axis.line = element_line(linewidth = 0.25),
    axis.ticks = element_line(linewidth = 0.25),
    axis.ticks.length = unit(1.5, "pt"),
    legend.position = "none",
    plot.margin = margin(1, 3, 1, 1),
    panel.grid = element_blank(),
    plot.tag = element_text(size = 8, face = "bold", family = family),
    plot.tag.position = c(0, 1),
    strip.background = element_blank(),
    strip.text = element_text(size = 7),
    plot.background = element_rect(fill = "white", colour = NA),
    panel.background = element_rect(fill = "white", colour = NA),
    legend.background = element_blank(),
    legend.key = element_blank()
  )
theme_tile <- theme_gb +
  theme(axis.line = element_blank(), axis.ticks = element_blank())

export_fig <- function(fig, name, w_mm, h_mm, align = NULL, align_h_mm = h_mm) {
  stopifnot(w_mm <= 170.5, h_mm <= 225)
  pdf <- file.path(out_dir, paste0(name, ".pdf"))
  w <- w_mm / 25.4
  h <- h_mm / 25.4
  a <- if (is.null(align)) fig else align
  if (nzchar(qa_dir) && inherits(a, "patchwork")) {
    # panel alignment gate of the nature-figure skill, on the aligned panels
    source(file.path(qa_dir, "scripts", "panel_alignment.R"))
    grDevices::pdfFonts(Arial = grDevices::pdfFonts()$Helvetica) # the skill measures on a plain pdf() device: Helvetica has Arial's metrics
    tryCatch(
      require_patchwork_panel_alignment(
        a,
        manifest_path = file.path(
          out_dir,
          paste0(name, ".alignment-layout.json")
        ),
        report_path = file.path(out_dir, paste0(name, ".alignment.json")),
        width_in = w,
        height_in = align_h_mm / 25.4,
        audit_script = file.path(qa_dir, "scripts", "audit_panel_alignment.py"),
        strict = TRUE
      ),
      error = function(e) {
        message("alignment gate not auditable here: ", conditionMessage(e))
      }
    )
  }
  ggsave(
    pdf,
    fig,
    width = w,
    height = h,
    device = grDevices::cairo_pdf,
    family = family
  )
  ggsave(sub("[.]pdf$", ".png", pdf), fig, width = w, height = h, dpi = 300)
  message("wrote ", pdf, " (", round(w_mm), " x ", round(h_mm), " mm)")
}

# =============================================================================================== capability figure
# a and b are two blocks (a thin rule between them, no background) in one coordinate system, so that they share their rows; one unit is one column of a.
feat_dir <- file.path(here, "features")
if (
  !identical(only, "timing") &&
    file.exists(file.path(feat_dir, "capability.csv"))
) {
  cap <- read.csv(
    file.path(feat_dir, "capability.csv"),
    stringsAsFactors = FALSE
  )
  sel <- read.csv(
    file.path(feat_dir, "selection.csv"),
    stringsAsFactors = FALSE
  )
  ord <- c("CerebroNexus", "ShinyCell", "iSEE", "cellxgene", "Vitessce")
  feat <- unique(cap$feature)
  nr <- length(ord)
  nf <- length(feat)
  wrap <- c(
    Embeddings = "Embed-\ndings",
    `TCR view` = "TCR\nview",
    `TCR column` = "TCR\ncolumn",
    `Tissue image` = "Tissue\nimage",
    `Duplicate names` = "Duplicate\nnames"
  )
  pitch <- 1.34
  fx <- c(pitch * 1:7, pitch * 7 + 1.3) # column positions of a; the last (duplicate names) is another kind of thing: a gap before it
  cap$c <- fx[match(cap$feature, feat)]
  cap$y <- nr + 1 - match(cap$tool, ord)
  disc <- function(cx, cy, r, from = 0, to = 2 * pi, n = 40) {
    t <- seq(from, to, length.out = n)
    data.frame(x = c(cx, cx + r * cos(t)), y = c(cy, cy + r * sin(t)))
  }
  R0 <- 0.34
  polys <- function(d, from, to, tag) {
    do.call(
      rbind,
      lapply(seq_len(nrow(d)), function(i) {
        cbind(disc(d$c[i], d$y[i], R0, from, to), id = paste(tag, i))
      })
    )
  }
  full <- polys(cap[cap$grade == "auto", ], 0, 2 * pi, "f")
  half <- polys(cap[cap$grade == "manual", ], -pi / 2, pi / 2, "h")
  ring <- do.call(
    rbind,
    lapply(which(cap$grade %in% c("manual", "absent")), function(i) {
      cbind(
        disc(cap$c[i], cap$y[i], R0)[-1, ],
        id = paste("r", i),
        kind = cap$grade[i]
      )
    })
  )
  dup <- cap[cap$grade %in% c("rejected", "silent"), ]
  score <- data.frame(
    y = nr:1,
    n = vapply(
      ord,
      function(t) {
        sum(
          cap$grade[cap$tool == t & cap$feature != "Duplicate names"] == "auto"
        )
      },
      0
    )
  )
  xs <- pitch * 7 + 2.2
  bar <- 0.2 # the score bars start at xs, 0.2 columns per feature
  a0 <- 0.35
  a1 <- xs + 2.6 # the grey block of a
  b0 <- a1 + 0.6
  x0 <- b0 + 0.6
  tw <- 0.98 # the block of b; its tiles are tw apart
  sx <- x0 + tw * c(0, 1, 2, 3.45, 4.45, 5.45) # S1: attribute, lasso, box; a gap; S2 the same
  b1 <- sx[6] + 0.6
  sel$col <- sx[
    (sel$set == "S2") * 3 + match(sel$route, c("Attribute", "Lasso", "Box"))
  ]
  sel$y <- nr + 1 - match(sel$tool, ord)
  sel$txt <- ifelse(is.na(sel$jaccard), "", sprintf("%.2f", sel$jaccard))
  sel$dark <- !is.na(sel$jaccard) & sel$jaccard < 0.45
  yb <- -0.8
  yt <- nr + 1.3 # the grey blocks span the column labels below and the headers above
  blocks <- data.frame(x0 = c(a0, b0), x1 = c(a1, b1))
  bands <- data.frame(x0 = c(a0, b0) + 0.1, x1 = c(a1, b1) - 0.1)
  # the key under the blocks, drawn with the same symbols
  ky <- -1.7
  keyx <- c(0.6, 3.6, 7.3, 12.9, 15.7)
  kf <- cbind(disc(keyx[1], ky, R0), id = "k1")
  kh <- cbind(disc(keyx[2], ky, R0, -pi / 2, pi / 2), id = "k2")
  kr <- rbind(
    cbind(disc(keyx[2], ky, R0)[-1, ], id = "k2", kind = "manual"),
    cbind(disc(keyx[3], ky, R0)[-1, ], id = "k3", kind = "absent")
  )
  kd <- data.frame(x = keyx[4:5], y = ky)
  kt <- data.frame(
    x = c(keyx + 0.5, 10.1),
    y = ky,
    lab = c(
      "default call",
      "extra step or code",
      "not offered",
      "refused",
      "kept, no warning",
      "Duplicate names:"
    )
  )
  hdr <- data.frame(
    x = fx,
    y = 0.35,
    lab = unname(ifelse(feat %in% names(wrap), wrap[feat], feat))
  )
  sh_hdr <- data.frame(
    x = sx,
    y = 0.35,
    lab = rep(c("Attr.", "Lasso", "Box"), 2)
  )
  g1 <- ggplot() +
    annotate(
      "segment",
      x = (a1 + b0) / 2,
      xend = (a1 + b0) / 2,
      y = yb,
      yend = yt,
      linewidth = 0.25,
      colour = "grey55"
    ) +
    geom_polygon(
      data = full,
      aes(x, y, group = id),
      fill = "#009E73",
      colour = NA
    ) +
    geom_polygon(
      data = half,
      aes(x, y, group = id),
      fill = "#E69F00",
      colour = NA
    ) +
    geom_polygon(
      data = ring,
      aes(x, y, group = id, colour = kind),
      fill = NA,
      linewidth = 0.3
    ) +
    geom_point(
      data = dup[dup$grade == "rejected", ],
      aes(c, y),
      shape = 23,
      fill = "#0072B2",
      colour = "white",
      size = 2.0,
      stroke = 0.25
    ) +
    geom_point(
      data = dup[dup$grade == "silent", ],
      aes(c, y),
      shape = 25,
      fill = "#D55E00",
      colour = "white",
      size = 2.0,
      stroke = 0.25
    ) +
    geom_segment(
      data = score,
      aes(x = xs, xend = xs + n * bar, y = y, yend = y),
      linewidth = 2.4,
      colour = "#009E73",
      lineend = "butt"
    ) +
    geom_text(
      data = score,
      aes(x = xs + n * bar + 0.1, y = y, label = n),
      size = SZ,
      family = family,
      hjust = 0
    ) +
    geom_tile(
      data = sel,
      aes(col, y, fill = jaccard),
      width = tw - 0.06,
      height = 0.94,
      colour = NA
    ) +
    geom_text(
      data = sel[!is.na(sel$jaccard), ],
      aes(col, y, label = txt, colour = dark),
      size = SZ,
      family = family
    ) +
    geom_text(
      data = sel[is.na(sel$jaccard), ],
      aes(col, y),
      label = "–",
      colour = "#8C8C8C",
      size = SZ,
      family = family
    ) +
    geom_polygon(
      data = kf,
      aes(x, y, group = id),
      fill = "#009E73",
      colour = NA
    ) +
    geom_polygon(
      data = kh,
      aes(x, y, group = id),
      fill = "#E69F00",
      colour = NA
    ) +
    geom_polygon(
      data = kr,
      aes(x, y, group = id, colour = kind),
      fill = NA,
      linewidth = 0.3
    ) +
    geom_point(
      data = kd[1, ],
      aes(x, y),
      shape = 23,
      fill = "#0072B2",
      colour = "white",
      size = 2.0,
      stroke = 0.25
    ) +
    geom_point(
      data = kd[2, ],
      aes(x, y),
      shape = 25,
      fill = "#D55E00",
      colour = "white",
      size = 2.0,
      stroke = 0.25
    ) +
    geom_text(
      data = kt,
      aes(x, y, label = lab),
      size = SZ,
      family = family,
      hjust = 0
    ) +
    geom_text(
      data = hdr,
      aes(x, y, label = lab),
      size = SZ,
      family = family,
      hjust = 0.5,
      vjust = 1,
      lineheight = 0.9
    ) +
    geom_text(
      data = sh_hdr,
      aes(x, y, label = lab),
      size = SZ,
      family = family,
      hjust = 0.5,
      vjust = 1
    ) +
    annotate(
      "text",
      x = xs,
      y = nr + 0.6,
      label = "Features offered\nby the default call",
      size = SZ,
      family = family,
      hjust = 0,
      vjust = 0,
      lineheight = 0.9
    ) +
    annotate(
      "text",
      x = sx[c(2, 5)],
      y = nr + 0.6,
      label = c("S1: B cells (342)", "S2: top clone (11)"),
      size = SZ,
      family = family,
      fontface = "bold",
      vjust = 0
    ) +
    annotate(
      "text",
      x = c(a0, b0),
      y = yt + 0.25,
      label = c("a", "b"),
      size = 8 / ggplot2::.pt,
      family = family,
      fontface = "bold",
      hjust = 0,
      vjust = 0
    ) +
    scale_colour_manual(
      values = c(
        manual = "#E69F00",
        absent = "#B0B0B0",
        `TRUE` = "black",
        `FALSE` = "white"
      ),
      guide = "none"
    ) +
    scale_fill_gradientn(
      colours = c("#F6E8C3", "#DFC27D", "#80CDC1", "#35978F", "#01665E"),
      limits = c(0, 1),
      na.value = "#EFEFEF",
      breaks = c(0, 0.5, 1),
      name = "Jaccard index of the cells exported by a selection with the truth set"
    ) +
    scale_y_continuous(breaks = nr:1, labels = ord, expand = c(0, 0)) +
    scale_x_continuous(expand = c(0, 0)) +
    coord_fixed(xlim = c(a0, b1), ylim = c(-2.2, yt + 0.9), clip = "off") +
    theme_tile +
    theme(
      axis.text.x = element_blank(),
      axis.text.y = element_text(face = c("bold", rep("plain", nr - 1))),
      axis.title = element_blank(),
      plot.margin = margin(1, 3, 1, 1, "mm"),
      legend.position = "bottom",
      legend.key.height = unit(2, "mm"),
      legend.key.width = unit(14, "mm"),
      legend.title.position = "top",
      legend.title = element_text(size = 7),
      legend.text = element_text(size = 7),
      legend.margin = margin(0, 0, 0, 0),
      legend.justification = "right"
    )
  export_fig(g1, "fig-tool-capability", 170, 100)
}
# =============================================================================================== timing figure
if (identical(only, "capability")) {
  quit(save = "no")
}
rd <- function(f) utils::read.delim(file.path(run, f), stringsAsFactors = FALSE)
starts <- rd("starts.tsv")
genes <- rd("genes.tsv")
builds <- rd("builds.tsv")
ok <- starts[starts$status == "ok", ]
ok$mem <- ok$server_peak_gb + ok$browser_peak_gb
g_ok <- genes[genes$status == "ok" & !is.na(genes$t_s), ]
bd <- builds[builds$status %in% c("ok", "n/a") & !is.na(builds$artifact_gb), ]
tiers <- sort(unique(ok$tier))
full <- max(tiers)
common <- max(tiers[vapply(
  tiers,
  function(t) length(unique(ok$tool[ok$tier == t])) == length(tools),
  TRUE
)]) # largest tier all tools reach

agg <- function(d, v, q = c(0, 1)) {
  d$v <- d[[v]]
  d <- d[!is.na(d$v), ]
  do.call(
    rbind,
    lapply(split(d, list(d$tool, d$tier), drop = TRUE), function(x) {
      data.frame(
        tool = lab(x$tool[[1L]]),
        tier = x$tier[[1L]],
        y = median(x$v),
        lo = unname(quantile(x$v, q[1])),
        hi = unname(quantile(x$v, q[2]))
      )
    })
  )
}

# ---- a: scorecard, the common tier and the full data set
metric_names <- c(
  "Start",
  "Again",
  "Gene 1",
  "Genes 2+",
  "Memory",
  "Build",
  "Size"
)
unit_names <- c("(s)", "(s)", "(s)", "(s)", "(GiB)", "(s)", "(GiB)")
val_at <- function(t) {
  m <- function(d, v, f = NULL) {
    d <- d[d$tier == t, ]
    if (!is.null(f)) {
      d <- d[eval(f, d), ]
    }
    tapply(d[[v]], d$tool, median, na.rm = TRUE)
  }
  list(
    m(ok[ok$kind == "first", ], "t_total_s"),
    m(ok[ok$kind == "again", ], "t_total_s"),
    m(g_ok[g_ok$gene_idx == 1, ], "t_s"),
    m(g_ok[g_ok$gene_idx > 1, ], "t_s"),
    m(ok[ok$kind == "first", ], "mem"),
    m(bd[!is.na(bd$build_s), ], "build_s"),
    m(bd, "artifact_gb")
  )
}
card <- do.call(
  rbind,
  lapply(c(common, full), function(t) {
    vals <- val_at(t)
    do.call(
      rbind,
      lapply(seq_along(metric_names), function(i) {
        v <- as.numeric(vals[[i]][names(tools)])
        present <- names(tools) %in% unique(ok$tool[ok$tier == t])
        v[!present] <- NA
        data.frame(
          tier = t,
          metric = metric_names[i],
          tool = unname(tools),
          v = v,
          rank = rank(v, na.last = "keep", ties.method = "min"),
          present = present
        )
      })
    )
  })
)
card <- card[card$present, ]
card$block <- factor(
  ifelse(
    card$tier == common,
    paste0(format(common, big.mark = ","), " cells"),
    "1,306,127 cells"
  ),
  levels = c(
    paste0(format(common, big.mark = ","), " cells"),
    "1,306,127 cells"
  )
)
card$tool <- factor(card$tool, levels = rev(tools))
card$metric <- factor(card$metric, levels = metric_names)
card$txt <- ifelse(
  is.na(card$v),
  "n/a",
  ifelse(
    card$v >= 100,
    sprintf("%.0f", card$v),
    ifelse(card$v >= 10, sprintf("%.1f", card$v), sprintf("%.2f", card$v))
  )
)
card$light <- card$rank <= 2 |
  card$rank >= 5 |
  (!is.na(card$rank) &
    card$rank == max(card$rank, na.rm = TRUE) &
    card$tier == full)
ga2 <- ggplot(card, aes(metric, tool, fill = rank)) +
  geom_tile(colour = "white", linewidth = 0.8) +
  geom_text(aes(label = txt, colour = light), size = SZ, family = family) +
  facet_grid(block ~ ., scales = "free_y", space = "free_y", switch = "y") +
  scale_fill_gradientn(
    colours = c("#01665E", "#5AB4AC", "#F5F5F5", "#E6C79A", "#B8741A"),
    limits = c(1, 6),
    na.value = "#EDEDED",
    breaks = c(1, 6),
    labels = c("best", "worst"),
    name = "Rank among the tools shown"
  ) +
  scale_colour_manual(
    values = c(`TRUE` = "white", `FALSE` = "black"),
    guide = "none"
  ) +
  scale_x_discrete(position = "top", expand = c(0, 0), labels = function(x) {
    paste0(x, "\n", unit_names[match(x, metric_names)])
  }) +
  scale_y_discrete(expand = c(0, 0)) +
  labs(tag = "a") +
  theme_tile +
  theme(
    axis.title = element_blank(),
    strip.placement = "outside",
    strip.text.y.left = element_text(
      angle = 0,
      hjust = 1,
      face = "bold",
      size = 7
    ),
    legend.position = "bottom",
    legend.key.height = unit(2, "mm"),
    legend.key.width = unit(14, "mm"),
    legend.title.position = "top",
    legend.title = element_text(size = 7),
    legend.text = element_text(size = 7),
    legend.margin = margin(0, 0, 0, 0),
    panel.spacing.y = unit(2, "mm")
  )

# ---- b, e, f, g: lines over the number of cells; CerebroNexus drawn heavier; the label of each line at its right end
panel_lines <- function(d, ylab, tag, labels = FALSE) {
  d$cnx <- is_cnx(d$tool)
  d$x <- match(d$tier, tiers) # the numbers of cells are equally spaced: a category axis, not a scale
  g <- ggplot(d, aes(x, y, colour = tool, group = tool)) +
    geom_linerange(
      aes(ymin = lo, ymax = hi),
      linewidth = 0.25,
      show.legend = FALSE
    ) +
    geom_line(aes(linewidth = cnx)) +
    geom_point(aes(shape = tool, size = cnx), stroke = 0.4, fill = "white") +
    scale_linewidth_manual(values = c(`TRUE` = 0.75, `FALSE` = 0.4)) +
    scale_size_manual(values = c(`TRUE` = 1.8, `FALSE` = 1.3)) +
    scale_colour_manual(values = cols, limits = names(cols)) +
    scale_shape_manual(values = shapes, limits = names(shapes)) +
    scale_x_continuous(
      breaks = seq_along(tiers),
      labels = fmt_cells(tiers),
      expand = expansion(add = c(0.35, 0.35))
    ) +
    scale_y_log10(labels = fmt_num) +
    labs(x = "Cells", y = ylab, tag = tag) +
    theme_gb
  if (labels) {
    g <- g +
      geom_text_repel(
        data = do.call(
          rbind,
          lapply(split(d, d$tool), function(x) x[which.min(x$tier), ])
        ),
        aes(label = sh(as.character(tool))),
        size = SZ,
        family = family,
        hjust = 1,
        direction = "y",
        nudge_x = -0.15,
        segment.size = 0.2,
        segment.color = "grey60",
        box.padding = 0.1,
        min.segment.length = 0.1,
        xlim = c(-Inf, NA),
        seed = 1
      )
  }
  g
}
gb2 <- panel_lines(
  agg(ok[ok$kind == "first", ], "t_total_s"),
  "Launch to first plot,\nfirst start (s)",
  "b"
)

# ---- c: the full data set, when the server answered (open) and when the plot was on screen (filled)
ob <- ok[ok$tier == full, ]
ob <- do.call(
  rbind,
  lapply(split(ob, list(ob$tool, ob$kind), drop = TRUE), function(x) {
    data.frame(
      tool = lab(x$tool[[1L]]),
      kind = x$kind[[1L]],
      ready = median(x$t_ready_s),
      total = median(x$t_total_s)
    )
  })
)
ob$tool <- factor(ob$tool, levels = rev(levels(droplevels(ob$tool))))
ob$yy <- as.numeric(ob$tool) + ifelse(ob$kind == "first", 0.2, -0.2)
gc <- ggplot(ob, aes(colour = tool)) +
  geom_segment(
    aes(x = ready, xend = total, y = yy, yend = yy, linetype = kind),
    linewidth = 0.6,
    alpha = 0.8
  ) +
  geom_point(
    aes(x = ready, y = yy),
    shape = 21,
    fill = "white",
    size = 1.6,
    stroke = 0.5
  ) +
  geom_point(aes(x = total, y = yy), size = 1.8) +
  scale_colour_manual(values = cols) +
  scale_linetype_manual(values = c(first = "solid", again = "22")) +
  scale_x_log10(labels = fmt_num, expand = expansion(mult = c(0.05, 0.1))) +
  scale_y_continuous(
    breaks = seq_along(levels(ob$tool)),
    labels = sh(levels(ob$tool)),
    expand = expansion(add = c(0.5, 3.0))
  ) +
  annotate(
    "text",
    x = 40,
    y = length(levels(ob$tool)) + 2.95,
    hjust = 1,
    vjust = 1,
    size = SZ,
    family = family,
    lineheight = 0.95,
    label = "open: server answered
filled: plot shown
solid: first start
dashed: started again"
  ) +
  labs(
    x = paste0("Time at ", fmt_cells(full), " cells (s)"),
    y = NULL,
    tag = "c"
  ) +
  theme_gb

# ---- d: every colouring by a gene at the full data set, the first gene marked
gz <- g_ok[g_ok$tier == full, ]
gz$tool <- factor(
  tools[gz$tool],
  levels = rev(levels(droplevels(lab(unique(g_ok$tool[g_ok$tier == full])))))
)
gz$first <- gz$gene_idx == 1
gd <- ggplot(gz, aes(t_s, tool, colour = tool)) +
  geom_quasirandom(
    data = gz[!gz$first, ],
    orientation = "y",
    width = 0.28,
    size = 0.9,
    alpha = 0.75,
    stroke = 0
  ) +
  stat_summary(
    data = gz[!gz$first, ],
    fun = median,
    fun.min = median,
    fun.max = median,
    geom = "errorbar",
    orientation = "y",
    width = 0.4,
    linewidth = 0.5,
    colour = "black"
  ) +
  geom_point(
    data = gz[gz$first, ],
    shape = 23,
    size = 2.3,
    fill = "white",
    stroke = 0.7
  ) +
  scale_colour_manual(values = cols) +
  scale_y_discrete(labels = sh, expand = expansion(add = c(0.6, 1.0))) +
  scale_x_log10(labels = fmt_num) +
  annotate(
    "text",
    x = Inf,
    y = Inf,
    hjust = 1.05,
    vjust = 1.1,
    size = SZ,
    family = family,
    lineheight = 0.95,
    label = "diamond: first gene
dots: genes 2-20, bar: median"
  ) +
  labs(
    x = paste0("Colour by a gene at ", fmt_cells(full), " cells (s)"),
    y = NULL,
    tag = "d"
  ) +
  theme_gb

ge <- panel_lines(
  agg(g_ok[g_ok$gene_idx > 1, ], "t_s", c(0.1, 0.9)),
  "Later genes (s;\nmedian, 10-90 %)",
  "e"
)
gf <- panel_lines(
  agg(ok[ok$kind == "first", ], "mem"),
  "Peak memory, server +\nbrowser (GiB)",
  "f"
)
gg <- panel_lines(
  agg(bd[!is.na(bd$build_s), ], "build_s"),
  "Build time\n(s)",
  "g"
)

design <- c(
  "BBBBBBCCCCCC",
  "BBBBBBCCCCCC",
  "BBBBBBCCCCCC",
  "DDDDDDEEEEEE",
  "DDDDDDEEEEEE",
  "DDDDDDEEEEEE",
  "FFFFFFGGGGGG",
  "FFFFFFGGGGGG",
  "FFFFFFGGGGGG"
)
bottom <- (gb2 + gc + gd + ge + gf + gg) +
  plot_layout(design = paste(design, collapse = "\n"))
leg_plot <- gb2 +
  scale_colour_manual(
    name = NULL,
    values = cols,
    limits = names(cols),
    labels = sh
  ) +
  scale_shape_manual(
    name = NULL,
    values = shapes,
    limits = names(shapes),
    labels = sh
  ) +
  guides(
    colour = guide_legend(nrow = 2, byrow = TRUE),
    shape = guide_legend(nrow = 2, byrow = TRUE),
    linewidth = "none",
    size = "none"
  ) +
  theme(
    legend.position = "bottom",
    legend.text = element_text(size = 7),
    legend.key.width = unit(7, "mm"),
    legend.key.spacing.x = unit(4, "mm"),
    legend.key.spacing.y = unit(0, "mm"),
    legend.margin = margin(0, 0, 0, 0)
  )
leg <- cowplot::get_plot_component(
  leg_plot,
  "guide-box-bottom",
  return_all = FALSE
)
fig2 <- wrap_elements(full = ga2) /
  bottom /
  wrap_elements(full = leg) +
  plot_layout(heights = c(3.2, 9, 0.7))
export_fig(
  fig2,
  "fig-tool-timing",
  170,
  205,
  align = bottom,
  align_h_mm = 205 * 9 / 12.2
)
