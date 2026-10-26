# Tool comparison figure: capability matrix (Task 1), selection accuracy
# (Task 2) and cost at three sizes (Task 3), drawn from results/ to the
# Genome Biology rules used for the interface figures (170 mm wide, Arial,
# 7 pt text, 8 pt bold panel labels, lines >= 0.25 pt, Okabe-Ito colours).

TC_TOOLS <- c("CerebroNexus", "ShinyCell", "iSEE", "cellxgene", "Vitessce")
TC_CONFIGS <- c(
  cerebronexus_default = "CerebroNexus (embedded)",
  cerebronexus_h5 = "CerebroNexus (HDF5)",
  shinycell = "ShinyCell",
  isee = "iSEE",
  cellxgene = "cellxgene",
  vitessce = "Vitessce"
)
TC_COLOURS <- c(
  "CerebroNexus (embedded)" = "#D55E00",
  "CerebroNexus (HDF5)" = "#0072B2",
  "ShinyCell" = "#E69F00",
  "iSEE" = "#009E73",
  "cellxgene" = "#666666",
  "Vitessce" = "#CC79A7"
)
TC_GRADES <- c(
  auto = "#009E73",
  manual = "#E69F00",
  absent = "#D9D9D9",
  rejected = "#56B4E9",
  silent = "#D55E00"
)
TC_TEXT_PT <- 7
TC_LINE <- 0.5 / ggplot2::.pt

theme_tool_comparison <- function() {
  ggplot2::theme_classic(base_size = TC_TEXT_PT, base_family = "Arial") +
    ggplot2::theme(
      text = ggplot2::element_text(size = TC_TEXT_PT, colour = "black"),
      axis.text = ggplot2::element_text(size = TC_TEXT_PT, colour = "black"),
      axis.line = ggplot2::element_line(linewidth = TC_LINE),
      axis.ticks = ggplot2::element_line(linewidth = TC_LINE),
      axis.ticks.length = ggplot2::unit(1, "mm"),
      strip.background = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(size = TC_TEXT_PT),
      legend.text = ggplot2::element_text(size = TC_TEXT_PT),
      legend.title = ggplot2::element_text(size = TC_TEXT_PT),
      legend.key.size = ggplot2::unit(3, "mm"),
      legend.background = ggplot2::element_blank(),
      plot.margin = ggplot2::margin(1, 1, 1, 1, "mm"),
      plot.tag = ggplot2::element_text(
        size = 8,
        face = "bold",
        family = "Arial"
      )
    )
}

# Task 1: one tile per tool and capability. Embeddings, clustering and import
# are graded over I1-I3 (the import grade is "manual" when the documented
# default route failed on any of them); TCR on I2, spatial on I3, duplicated
# cell names on I4.
tool_capabilities <- function(task1) {
  d <- utils::read.csv(task1, check.names = FALSE)
  worst <- function(x) {
    x <- x[x != "n/a"]
    for (g in c("error", "absent", "manual")) {
      if (g %in% x) return(g)
    }
    "auto"
  }
  rows <- lapply(TC_TOOLS, function(tool) {
    t <- d[d$tool == tool, ]
    i13 <- t[t$dataset %in% c("I1", "I2", "I3"), ]
    stopifnot(all(i13$import_status == "ok"))
    grade <- c(
      "Import" = if (any(i13$default_route_failed == "True")) {
        "manual"
      } else {
        "auto"
      },
      "Embeddings" = worst(i13$grade_embedding),
      "Clusters" = worst(i13$grade_clustering),
      "TCR view" = t$grade_tcr_clonotype_view[t$dataset == "I2"],
      "TCR column" = t$grade_tcr_column[t$dataset == "I2"],
      "Spatial" = t$grade_spatial_coordinates[t$dataset == "I3"],
      "Tissue image" = t$grade_tissue_image[t$dataset == "I3"],
      "Duplicated names" = t$i4_behaviour[t$dataset == "I4"]
    )
    data.frame(tool = tool, capability = names(grade), grade = unname(grade))
  })
  out <- do.call(rbind, rows)
  stopifnot(all(out$grade %in% names(TC_GRADES)))
  out
}

plot_capabilities <- function(cap) {
  cap$tool <- factor(cap$tool, rev(TC_TOOLS))
  cap$capability <- factor(cap$capability, unique(cap$capability))
  cap$grade <- factor(cap$grade, names(TC_GRADES))
  ggplot2::ggplot(cap, ggplot2::aes(capability, tool, fill = grade)) +
    ggplot2::geom_tile(colour = "white", linewidth = 2 * TC_LINE) +
    ggplot2::geom_text(
      ggplot2::aes(label = grade),
      size = 6 / ggplot2::.pt,
      family = "Arial"
    ) +
    ggplot2::scale_fill_manual(
      values = TC_GRADES,
      guide = "none",
      drop = FALSE
    ) +
    ggplot2::scale_x_discrete(position = "top", expand = c(0, 0)) +
    ggplot2::scale_y_discrete(expand = c(0, 0)) +
    ggplot2::labs(x = NULL, y = NULL) +
    theme_tool_comparison() +
    ggplot2::theme(
      axis.line = ggplot2::element_blank(),
      axis.ticks = ggplot2::element_blank(),
      axis.text.x.top = ggplot2::element_text(
        angle = 40,
        hjust = 0,
        vjust = 0,
        lineheight = 0.9
      )
    )
}

# Task 2: median Jaccard index per tool, set and route. A route the tool does
# not offer is drawn as a cross at 0.
tool_selection <- function(task2) {
  d <- utils::read.csv(task2, check.names = FALSE)
  d$route_kind <- ifelse(
    grepl("^attribute", d$route),
    "Attribute",
    ifelse(
      grepl("box brush", d$route),
      "Box brush",
      ifelse(grepl("lasso", d$route), "Lasso", NA)
    )
  )
  # ShinyCell offers neither route: one row per route kind it lacks.
  none <- d[is.na(d$route_kind), ]
  if (nrow(none)) {
    none <- rbind(
      transform(none, route_kind = "Attribute"),
      transform(none, route_kind = "Lasso")
    )
    d <- rbind(d[!is.na(d$route_kind), ], none)
  }
  d$available <- d$result == "ok"
  d$jaccard <- ifelse(d$available, as.numeric(d$jaccard_median), 0)
  d$set <- factor(ifelse(
    d$set == "S1",
    "S1: B cells (342)",
    "S2: top clone (11)"
  ))
  d$tool <- factor(d$tool, rev(TC_TOOLS))
  d$route_kind <- factor(d$route_kind, c("Attribute", "Lasso", "Box brush"))
  d
}

plot_selection <- function(sel) {
  # Routes sit side by side within each tool's row.
  sel$y <- as.integer(sel$tool) +
    c(Attribute = 0.2, Lasso = 0, "Box brush" = -0.2)[as.character(
      sel$route_kind
    )]
  ggplot2::ggplot(sel, ggplot2::aes(jaccard, y, colour = route_kind)) +
    ggplot2::geom_point(data = sel[sel$available, ], size = 1.6) +
    ggplot2::geom_point(
      data = sel[!sel$available, ],
      shape = 4,
      size = 1.6,
      stroke = 2 * TC_LINE,
      show.legend = FALSE
    ) +
    ggplot2::facet_wrap(~set, nrow = 1) +
    ggplot2::scale_x_continuous(
      "Jaccard index with the truth set",
      limits = c(0, 1),
      breaks = c(0, 0.5, 1)
    ) +
    ggplot2::scale_y_continuous(
      NULL,
      breaks = seq_along(levels(sel$tool)),
      labels = levels(sel$tool),
      limits = c(0.6, length(levels(sel$tool)) + 0.4),
      expand = c(0, 0)
    ) +
    ggplot2::scale_colour_manual(
      NULL,
      values = c(
        Attribute = "#0072B2",
        Lasso = "#D55E00",
        "Box brush" = "#999999"
      )
    ) +
    theme_tool_comparison() +
    ggplot2::theme(
      legend.position = "bottom",
      legend.margin = ggplot2::margin(0, 0, 0, 0),
      panel.spacing = ggplot2::unit(3, "mm"),
      panel.grid.major.x = ggplot2::element_line(
        colour = "grey90",
        linewidth = TC_LINE
      )
    )
}

# Task 3: median and min-max over the ok runs of each config and size.
tool_scale <- function(task3) {
  d <- utils::read.csv(task3, check.names = FALSE)
  stopifnot(
    all(d$builds_ok == "3/3" | d$config == "cellxgene"),
    all(d$starts_ok == "9/9")
  )
  metrics <- c(
    build_s = "Build\ntime (s)",
    artifact_gb = "Artifact\nsize (GB)",
    total_s = "Ready +\nfirst plot (s)",
    server_peak_rss_gb = "Server peak\nmemory (GB)",
    browser_peak_rss_gb = "Browser peak\nmemory (GB)"
  )
  rows <- lapply(names(metrics), function(m) {
    data.frame(
      tier = d$tier,
      config = TC_CONFIGS[d$config],
      metric = metrics[[m]],
      median = suppressWarnings(as.numeric(d[[paste0(m, "_median")]])),
      min = suppressWarnings(as.numeric(d[[paste0(m, "_min")]])),
      max = suppressWarnings(as.numeric(d[[paste0(m, "_max")]]))
    )
  })
  out <- do.call(rbind, rows)
  out <- out[!is.na(out$median), ] # cellxgene has no build step
  out$config <- factor(out$config, unname(TC_CONFIGS))
  out$metric <- factor(out$metric, unname(metrics))
  out
}

plot_scale <- function(sc) {
  ggplot2::ggplot(
    sc,
    ggplot2::aes(
      tier,
      median,
      colour = config,
      linetype = config,
      shape = config
    )
  ) +
    ggplot2::geom_errorbar(
      ggplot2::aes(ymin = min, ymax = max),
      width = 0.08,
      linewidth = TC_LINE,
      linetype = "solid"
    ) +
    ggplot2::geom_line(linewidth = TC_LINE) +
    ggplot2::geom_point(size = 1.2) +
    ggplot2::facet_wrap(~metric, nrow = 1, scales = "free_y") +
    ggplot2::scale_x_log10(
      "Cells",
      breaks = c(1e4, 1e5, 5e5),
      labels = c("10k", "100k", "500k")
    ) +
    ggplot2::scale_y_log10(NULL, labels = function(x) {
      format(x, scientific = FALSE, drop0trailing = TRUE, trim = TRUE)
    }) +
    ggplot2::scale_colour_manual(NULL, values = TC_COLOURS) +
    ggplot2::scale_linetype_manual(
      NULL,
      values = c("solid", "22", rep("solid", 4))
    ) +
    ggplot2::scale_shape_manual(NULL, values = c(16, 1, 17, 15, 18, 25)) +
    ggplot2::annotation_logticks(
      sides = "l",
      linewidth = TC_LINE,
      short = ggplot2::unit(0.5, "mm"),
      mid = ggplot2::unit(0.8, "mm"),
      long = ggplot2::unit(1.2, "mm")
    ) +
    theme_tool_comparison() +
    ggplot2::theme(
      legend.position = "bottom",
      legend.margin = ggplot2::margin(0, 0, 0, 0),
      panel.spacing = ggplot2::unit(3, "mm"),
      legend.key.width = ggplot2::unit(6, "mm")
    ) +
    ggplot2::guides(colour = ggplot2::guide_legend(nrow = 1))
}

# Draw the figure to <out_dir>/fig-tool-comparison.{pdf,png} (plus an SVG
# twin in qa/ for check_figures.R when svglite is installed) and return the
# files.
plot_tool_comparison <- function(task1, task2, task3, out_dir) {
  a <- plot_capabilities(tool_capabilities(task1))
  b <- plot_selection(tool_selection(task2))
  c <- plot_scale(tool_scale(task3))
  plot <- patchwork::wrap_plots(
    patchwork::wrap_plots(a, b, widths = c(1.15, 1)),
    c,
    ncol = 1,
    heights = c(1, 1)
  ) +
    patchwork::plot_annotation(tag_levels = "a")
  plot <- plot &
    ggplot2::theme(
      plot.tag = ggplot2::element_text(
        size = 8,
        face = "bold",
        family = "Arial"
      )
    )
  width <- 170
  height <- 120
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  name <- file.path(out_dir, "fig-tool-comparison")
  ggplot2::ggsave(
    paste0(name, ".pdf"),
    plot,
    width = width,
    height = height,
    units = "mm",
    device = grDevices::cairo_pdf,
    bg = "white"
  )
  ggplot2::ggsave(
    paste0(name, ".png"),
    plot,
    width = width,
    height = height,
    units = "mm",
    dpi = 300,
    bg = "white"
  )
  files <- paste0(name, c(".pdf", ".png"))
  if (requireNamespace("svglite", quietly = TRUE)) {
    dir.create(file.path(out_dir, "qa"), showWarnings = FALSE)
    svg <- file.path(out_dir, "qa", "fig-tool-comparison.svg")
    ggplot2::ggsave(
      svg,
      plot,
      width = width,
      height = height,
      units = "mm",
      device = svglite::svglite,
      bg = "white"
    )
    # This figure holds no screenshot; check_figures.R still expects the table.
    utils::write.csv(
      data.frame(
        figure = character(),
        panel = character(),
        ppi = numeric(),
        min_text_pt = numeric(),
        below_6pt = logical(),
        cut_text = logical()
      ),
      file.path(out_dir, "qa", "screenshot-qa.csv"),
      row.names = FALSE
    )
  }
  files
}

# Start to first plot, taken apart: service-ready time and first-plot time
# (median over the 9 starts of each config) per size, and every single start's
# total on log axes, to show the spread between repeated starts.
plot_start_figure <- function(starts_csv, out_dir) {
  d <- utils::read.csv(starts_csv, check.names = FALSE)
  d <- d[d$status == "ok", ]
  d$config <- factor(TC_CONFIGS[d$config], unname(TC_CONFIGS))
  d$tier_label <- factor(
    format(d$tier, big.mark = ",", trim = TRUE),
    format(sort(unique(d$tier)), big.mark = ",", trim = TRUE)
  )
  med <- stats::aggregate(
    cbind(t_ready_s, t_first_plot_s) ~ config + tier_label,
    d,
    stats::median
  )
  long <- rbind(
    data.frame(
      med[c("config", "tier_label")],
      phase = "Service ready",
      seconds = med$t_ready_s
    ),
    data.frame(
      med[c("config", "tier_label")],
      phase = "First plot",
      seconds = med$t_first_plot_s
    )
  )
  long$phase <- factor(long$phase, c("First plot", "Service ready"))
  a <- ggplot2::ggplot(long, ggplot2::aes(seconds, config, fill = phase)) +
    ggplot2::geom_col(width = 0.72, orientation = "y") +
    ggplot2::facet_grid(tier_label ~ ., scales = "free_x") +
    ggplot2::scale_fill_manual(
      NULL,
      values = c("Service ready" = "#56B4E9", "First plot" = "#D55E00"),
      breaks = c("Service ready", "First plot")
    ) +
    ggplot2::scale_x_continuous(
      "Start time (s)",
      expand = ggplot2::expansion(mult = c(0, 0.05))
    ) +
    ggplot2::scale_y_discrete(NULL, limits = rev) +
    theme_tool_comparison() +
    ggplot2::theme(
      legend.position = "inside",
      legend.position.inside = c(0.97, 0.99),
      legend.justification = c(1, 1),
      strip.text.y = ggplot2::element_text(angle = 270),
      panel.spacing = ggplot2::unit(2, "mm")
    )
  d$total <- d$t_ready_s + d$t_first_plot_s
  b <- ggplot2::ggplot(
    d,
    ggplot2::aes(tier, total, colour = config, shape = config)
  ) +
    ggplot2::geom_point(
      size = 1,
      alpha = 0.8,
      position = ggplot2::position_jitter(width = 0.02, height = 0, seed = 1)
    ) +
    ggplot2::scale_x_log10(
      "Cells",
      breaks = c(1e4, 1e5, 5e5),
      labels = c("10k", "100k", "500k")
    ) +
    ggplot2::scale_y_log10(
      "Ready + first plot per start (s)",
      labels = function(x) {
        format(x, scientific = FALSE, drop0trailing = TRUE, trim = TRUE)
      }
    ) +
    ggplot2::scale_colour_manual(NULL, values = TC_COLOURS) +
    ggplot2::scale_shape_manual(NULL, values = c(16, 1, 17, 15, 18, 25)) +
    ggplot2::annotation_logticks(
      sides = "l",
      linewidth = TC_LINE,
      short = ggplot2::unit(0.5, "mm"),
      mid = ggplot2::unit(0.8, "mm"),
      long = ggplot2::unit(1.2, "mm")
    ) +
    theme_tool_comparison() +
    ggplot2::theme(
      legend.position = "right",
      legend.key.height = ggplot2::unit(3.2, "mm")
    )
  plot <- patchwork::wrap_plots(a, b, ncol = 1, heights = c(1.1, 1)) +
    patchwork::plot_annotation(tag_levels = "a")
  plot <- plot &
    ggplot2::theme(
      plot.tag = ggplot2::element_text(
        size = 8,
        face = "bold",
        family = "Arial"
      )
    )
  width <- 170
  height <- 150
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  name <- file.path(out_dir, "fig-tool-comparison-start")
  ggplot2::ggsave(
    paste0(name, ".pdf"),
    plot,
    width = width,
    height = height,
    units = "mm",
    device = grDevices::cairo_pdf,
    bg = "white"
  )
  ggplot2::ggsave(
    paste0(name, ".png"),
    plot,
    width = width,
    height = height,
    units = "mm",
    dpi = 300,
    bg = "white"
  )
  if (requireNamespace("svglite", quietly = TRUE)) {
    dir.create(file.path(out_dir, "qa"), showWarnings = FALSE)
    ggplot2::ggsave(
      file.path(out_dir, "qa", "fig-tool-comparison-start.svg"),
      plot,
      width = width,
      height = height,
      units = "mm",
      device = svglite::svglite,
      bg = "white"
    )
  }
  paste0(name, c(".pdf", ".png"))
}

# Peak memory of the server process tree and of Chrome (psutil, 100 ms
# samples), stacked: the data work of Vitessce happens in the browser, so the
# server alone would make it look much smaller than it is.
plot_memory_figure <- function(task3_csv, out_dir) {
  d <- utils::read.csv(task3_csv, check.names = FALSE)
  d$config <- factor(TC_CONFIGS[d$config], unname(TC_CONFIGS))
  d$tier_label <- factor(
    format(d$tier, big.mark = ",", trim = TRUE),
    format(sort(unique(d$tier)), big.mark = ",", trim = TRUE)
  )
  long <- rbind(
    data.frame(
      d[c("config", "tier_label")],
      part = "Server",
      gb = as.numeric(d$server_peak_rss_gb_median)
    ),
    data.frame(
      d[c("config", "tier_label")],
      part = "Browser",
      gb = as.numeric(d$browser_peak_rss_gb_median)
    )
  )
  long$part <- factor(long$part, c("Browser", "Server"))
  p <- ggplot2::ggplot(long, ggplot2::aes(gb, config, fill = part)) +
    ggplot2::geom_col(width = 0.72, orientation = "y") +
    ggplot2::facet_grid(tier_label ~ ., scales = "free_x") +
    ggplot2::scale_fill_manual(
      NULL,
      values = c(Server = "#0072B2", Browser = "#E69F00"),
      breaks = c("Server", "Browser")
    ) +
    ggplot2::scale_x_continuous(
      "Peak memory (GB)",
      expand = ggplot2::expansion(mult = c(0, 0.05))
    ) +
    ggplot2::scale_y_discrete(NULL, limits = rev) +
    theme_tool_comparison() +
    ggplot2::theme(
      legend.position = "inside",
      legend.position.inside = c(0.97, 0.99),
      legend.justification = c(1, 1),
      strip.text.y = ggplot2::element_text(angle = 270),
      panel.spacing = ggplot2::unit(2, "mm")
    )
  width <- 170
  height <- 95
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  name <- file.path(out_dir, "fig-tool-comparison-memory")
  ggplot2::ggsave(
    paste0(name, ".pdf"),
    p,
    width = width,
    height = height,
    units = "mm",
    device = grDevices::cairo_pdf,
    bg = "white"
  )
  ggplot2::ggsave(
    paste0(name, ".png"),
    p,
    width = width,
    height = height,
    units = "mm",
    dpi = 300,
    bg = "white"
  )
  if (requireNamespace("svglite", quietly = TRUE)) {
    dir.create(file.path(out_dir, "qa"), showWarnings = FALSE)
    ggplot2::ggsave(
      file.path(out_dir, "qa", "fig-tool-comparison-memory.svg"),
      p,
      width = width,
      height = height,
      units = "mm",
      device = svglite::svglite,
      bg = "white"
    )
  }
  paste0(name, c(".pdf", ".png"))
}
