# Ren v2 BPCells/H5 comparison: one bar panel per timing metric.
plotRenBackendBenchmark <- function(data) {
  stopifnot(
    all(data$correctness == "OK"),
    setequal(data$backend, c("bpcells", "h5"))
  )
  metrics <- c(
    startup_seconds = "Load source + CRB",
    first_gene_seconds = "First gene",
    hot_gene_p50_seconds = "Repeated gene",
    twelve_gene_seconds = "12-gene block"
  )
  old <- graphics::par(
    mfrow = c(1, 4),
    mar = c(4, 4, 3, 1),
    oma = c(0, 0, 3, 0)
  )
  on.exit(graphics::par(old))
  for (metric in names(metrics)) {
    medians <- vapply(
      c("bpcells", "h5"),
      function(backend) {
        stats::median(data[data$backend == backend, metric])
      },
      numeric(1)
    )
    mid <- graphics::barplot(
      medians,
      names.arg = c("BPCells", "HDF5"),
      col = c("#D9A03C", "#3F7F93"),
      border = NA,
      ylim = c(0, max(medians) * 1.27),
      main = metrics[[metric]],
      ylab = "Seconds"
    )
    graphics::text(mid, medians, sprintf("%.3f", medians), pos = 3, cex = .9)
  }
  graphics::mtext(
    paste0(
      "Ren v2: median of ",
      length(unique(data$round)),
      " fresh-process rounds (historical measurements)"
    ),
    outer = TRUE,
    side = 3,
    line = 1,
    cex = 1.1
  )
  invisible(NULL)
}

# Draw the Ren backend comparison from its result table to a PNG and return
# the file.
plot_ren_backends <- function(table, out) {
  dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
  data <- utils::read.delim(table, check.names = FALSE)
  grDevices::png(out, width = 1800, height = 600, res = 150)
  tryCatch(plotRenBackendBenchmark(data), finally = grDevices::dev.off())
  out
}

# Trend of the recorded L1 runs (runs/INDEX.tsv): median visual completion of Data info and of the
# pages, first and repeat visit, and the session memory peaks, one point per run in the order they were made.
plot_viewer_trend <- function(index_tsv, out_png, tier = "l1") {
  idx <- utils::read.delim(index_tsv, stringsAsFactors = FALSE)
  idx <- idx[idx$tier == tier & idx$verdict != "INVALID", ]
  stopifnot(nrow(idx) > 0L)
  idx <- idx[order(idx$utc), ]
  x <- seq_len(nrow(idx))
  lab <- paste0(substr(idx$candidate_sha, 1L, 7L), "\n", substr(idx$utc, 1L, 8L))
  panels <- list(
    list("Data info, initial load (ms)", idx$cand_initial_visual_ms, idx$base_initial_visual_ms),
    list("Pages, cold first visit (ms)", idx$cand_cold_visual_ms, idx$base_cold_visual_ms),
    list("Pages, repeat visit (ms)", idx$cand_repeat_visual_ms, idx$base_repeat_visual_ms),
    list("R process tree peak (MiB)", idx$cand_r_peak_mib, NULL),
    list("Chrome process tree peak (MiB)", idx$cand_chrome_peak_mib, NULL)
  )
  grDevices::png(out_png, width = 2400, height = 1200, res = 200)
  old <- graphics::par(mfrow = c(2, 3), mar = c(5, 4, 3, 1), oma = c(0, 0, 3, 0))
  on.exit({ graphics::par(old); grDevices::dev.off() })
  for (p in panels) {
    y <- c(p[[2]], p[[3]])
    graphics::plot(x, p[[2]], type = "b", pch = 19, col = "#3F7F93", xaxt = "n", xlab = "", ylab = "",
                   main = p[[1]], ylim = range(c(0, y), na.rm = TRUE), xlim = c(0.7, max(x) + 0.3))
    if (!is.null(p[[3]])) graphics::points(x, p[[3]], pch = 1, col = "#999999")
    graphics::axis(1, at = x, labels = lab, cex.axis = 0.6, padj = 0.5)
  }
  graphics::plot.new()
  graphics::legend("center", c("candidate (the revision of the run)", "baseline measured in the same run"),
                   pch = c(19, 1), col = c("#3F7F93", "#999999"), bty = "n")
  graphics::mtext(sprintf("Viewer performance standard, %s runs on %s", toupper(tier), unique(idx$platform)[[1L]]), outer = TRUE, cex = 1.1)
  out_png
}
