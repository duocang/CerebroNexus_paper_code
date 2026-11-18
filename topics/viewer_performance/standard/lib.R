# Pure functions of the Viewer performance measurement: the plan, aggregation, the records a run
# writes and the comparison of two runs. No browser and no R app here, so they are unit tested
# (topics/viewer_performance/tests/test-standard.R). The rules are in ../STANDARD.md.

standard_contract <- "blackbox-v10"
standard_metrics <- c("visual_complete_ms", "visual_90_ms", "first_plot_ms", "start_plot_ms", "page_ready_ms", "painted_ms", "settled_ms", "loader_visible_ms", "visible_ms", "js_peak_mib",
                      "server_busy_ms", "chrome_busy_ms", "trail_ms", "ws_in_bytes", "ws_out_bytes", "ws_max_msg_bytes",
                      "r_peak_mib", "chrome_peak_mib")
# initial  Data info loading the dataset (the session of the loadData page)
# cold     a page opened in a fresh server and Chrome, after Data info only: pays its own first-use cost
# first_start  a page opened from the start, with nothing kept from an earlier start: the user cache directory
#          of the server is emptied before the session (a new installation)
# first_plot  the same from a later start: the cache directory holds what earlier sessions of the run left. The
#          clock starts when Chrome navigates to the Viewer (not at a click) and runs to the first plot; the same
#          event the tool comparison times (coverage.tsv, column first_plot)
# tour     a page opened in a session that is already running, as a visitor goes on: the session opened the
#          Viewer, stayed tour_wait_s on the page it opened on, then opened the tour's pages one after another,
#          tour_think_s after the last one finished, without waiting for a quiet server (what the Viewer prepares
#          while a page is read is part of what is measured)
# action   one thing done on the open page (actions.tsv), right after its cold visit
standard_visits <- c("initial", "cold", "first_start", "first_plot", "tour", "action")
start_visits <- c("first_start", "first_plot")
tour_wait_s <- 15
tour_think_s <- 1.5

# Quiet: below this many CPU seconds per second, over 1 s, for each tree (R server, Chrome), for
# quiet_need_s seconds in a row. Headless Chrome uses 0.1-0.2 of a core while idle (software rendering).
quiet_thr <- c(r = 0.05, chrome = 0.25)
quiet_need_s <- 3

# The machine as a whole: a session starts only when all its CPUs together were below host_idle_pct percent
# for quiet_need_s one-second windows in a row; after host_idle_max_s seconds of waiting it starts anyway and
# is counted as started on a busy host. A run whose CPU canary (proc.R) moved by more than canary_limit
# between any two of its readings says so.
host_idle_pct <- 15
host_idle_max_s <- 600
canary_limit <- 1.2

# What compare.R calls a difference: an exact two-sided rank-sum test over the rounds at compare_alpha, and
# a difference of the medians above one frame. Rounds per page a run makes by default.
# The rows of a comparison are tested together: a row is marked when its Holm-adjusted p-value (over every
# row that was tested) is at or below compare_alpha. 7 rounds against 7 can mark a row among up to 85;
# 5 against 5 among 6 at most.
compare_alpha <- 0.05
default_rounds <- 7L

`%||%` <- function(a, b) if (is.null(a)) b else a

# Start (ms) of the quiet stretch that lasts to the last sample. `t` are sample times (ms), `cpu` the
# cumulative CPU seconds, one column per tree, `thr` the threshold per column. A 1 s window ending at a
# sample is noisy when any tree used `thr` or more of a core in it. Only windows ending at or after `from`
# count. NA when the last window is noisy or no window is complete yet.
quiet_from <- function(t, cpu, thr, window_ms = 1000, from = t[[1L]]) {
  cpu <- as.matrix(cpu)
  ends <- which(t - t[[1L]] >= window_ms & t >= from)
  if (!length(ends)) return(NA_real_)
  noisy <- rep(FALSE, length(ends))
  for (j in seq_len(ncol(cpu))) {
    before <- stats::approx(t, cpu[, j], t[ends] - window_ms, rule = 2, ties = max)$y
    noisy <- noisy | (cpu[ends, j] - before) / (window_ms / 1000) >= thr[[j]]
  }
  if (noisy[[length(noisy)]]) return(NA_real_)
  if (!any(noisy)) return(max(from, t[[ends[[1L]]]] - window_ms))
  max(from, t[[ends[[max(which(noisy)) + 1L]]]] - window_ms)
}

# How long a tree kept working after a click: from `t_click` to the start of its quiet stretch that
# reaches `t_stop` (when the harness had seen both trees quiet for quiet_need_s). A pause shorter than that
# (R waiting while Chrome draws, then sending a large message) is part of the work. NA when the tree was
# still busy at `t_stop`.
busy_ms <- function(t, cpu, t_click, t_stop, thr, window_ms = 1000) {
  if (is.na(t_click) || is.na(t_stop)) return(NA_real_)
  keep <- t >= t_click - window_ms & t <= t_stop
  if (sum(keep) < 2L) return(NA_real_)
  q <- quiet_from(t[keep], cpu[keep], thr, window_ms, from = t_click)
  if (is.na(q)) NA_real_ else q - t_click
}

# How frames are captured (env PERF_CAPTURE), recorded in raw.tsv and the manifest (`capture`):
#   screenshot  Page.captureScreenshot back to back (the default): a frame every 75 to 140 ms, whether the
#               screen changed or not
#   screencast  Page.startScreencast: a frame each time Chrome's compositor draws a new one, stamped by Chrome.
#               No frame means no change: a frame stays on screen until the next one
# Runs made with different modes are not comparable (compare.R lists `capture` among the differences).
capture_modes <- c("screenshot", "screencast")
capture_mode <- function(x = Sys.getenv("PERF_CAPTURE", "")) {
  if (!nzchar(x)) return(capture_modes[[1L]])
  if (!x %in% capture_modes) stop("PERF_CAPTURE must be one of: ", paste(capture_modes, collapse = ", "), call. = FALSE)
  x
}

# The frames of one observation (screencast): the frame on screen at the click (the last one at or before
# `t_click`, which a screencast sends when it starts) and every later one. Indices into `t`.
frames_in_window <- function(t, t_click) {
  if (!length(t)) return(integer())
  before <- which(t <= t_click)
  seq.int(if (length(before)) max(before) else 1L, length(t))
}

# The median time between two frames after the click (`frame_ms`). A screencast frame from before the click
# (the screen at the click) does not count.
frame_interval_ms <- function(t, t_click) {
  t <- t[t >= t_click]
  if (length(t) > 1L) stats::median(diff(t)) else NA_real_
}

# Share of identical pixels of two frames (arrays as png::readPNG returns, colour in the first three
# layers); 0 when their sizes differ.
pixel_similarity <- function(a, b) {
  if (!identical(dim(a), dim(b))) return(0)
  d <- abs(a - b) > 1e-6
  1 - mean(d[, , 1L] | d[, , 2L] | d[, , 3L])
}

# Visual metrics from the frames of an observation. `sim` is the share of pixels of each frame that
# equals the last frame; `t` the frame times (ms, increasing) and `t_click` the click time. A frame stands
# for the screen from its time until the next frame's, so frames need not be evenly spaced (screencast:
# only changes arrive; a frame from before the click is the screen at the click and counts as 0).
#   visual_complete_ms  when the page first looked the way it ends up (no later frame differs by
#                       more than `tol` of the pixels). The KPI: it needs no cooperation from the
#                       Viewer code, so it is comparable across versions.
#   visual_90_ms        when the page first looked at least `progress` like its final state.
visual_from_similarity <- function(t, sim, t_click, tol = 0.0005, progress = 0.90) {
  n <- length(t)
  if (!n) return(list(visual_complete_ms = NA_real_, visual_90_ms = NA_real_))
  differs <- which(sim < 1 - tol)
  complete_t <- if (!length(differs)) t[[1L]] else t[[min(max(differs) + 1L, n)]]
  first90 <- which(sim >= progress)
  list(visual_complete_ms = max(0, complete_t - t_click),
       visual_90_ms = if (length(first90)) max(0, t[[first90[[1L]]]] - t_click) else NA_real_)
}

# First plot, as the tool comparison defines it (topics/tool_comparison/scripts/run/harness.py): a frame
# shows the plot when the plot element is at least `min_px` wide and tall and at least `min_ink` of its
# pixels are "ink". A pixel is ink when its colour is further than `dist` (0-255 RGB distance) from the most
# frequent colour of the element and it is dark (V < 0.5) or coloured (saturation above `sat`). The first
# plot is the first frame of a run of at least two frames that show it.
ink_params <- c(dist = 60, sat = 0.1, min_ink = 0.01, min_px = 200)

# Share of ink pixels of an image array (height x width x 3, values 0-1, as png::readPNG returns).
ink_fraction <- function(img, dist = ink_params[["dist"]], sat = ink_params[["sat"]]) {
  d <- dim(img)
  if (length(d) != 3L || d[[3L]] < 3L || prod(d[1:2]) == 0L) return(0)
  r <- round(img[, , 1L] * 255); g <- round(img[, , 2L] * 255); b <- round(img[, , 3L] * 255)
  flat <- r * 65536 + g * 256 + b
  u <- unique(as.vector(flat))
  bg <- u[[which.max(tabulate(match(as.vector(flat), u)))]]
  br <- bg %/% 65536; bgc <- (bg %/% 256) %% 256; bb <- bg %% 256
  far <- sqrt((r - br)^2 + (g - bgc)^2 + (b - bb)^2) > dist
  mx <- pmax(r, g, b); mn <- pmin(r, g, b)
  s <- ifelse(mx > 0, (mx - mn) / pmax(mx, 1), 0)
  mean(far & (mx / 255 < 0.5 | s > sat))
}

# The part of a screenshot that is the plot element. `rect` = c(x, y, width, height) in CSS pixels as the page
# reports it, `scale` = pixels of the screenshot per CSS pixel. NULL when nothing of the element is on screen.
crop_to_rect <- function(img, rect, scale = 1) {
  h <- dim(img)[[1L]]; w <- dim(img)[[2L]]
  x0 <- max(0, round(rect[[1L]] * scale)); y0 <- max(0, round(rect[[2L]] * scale))
  x1 <- min(w, round((rect[[1L]] + rect[[3L]]) * scale)); y1 <- min(h, round((rect[[2L]] + rect[[4L]]) * scale))
  if (x1 <= x0 || y1 <= y0) return(NULL)
  img[(y0 + 1L):y1, (x0 + 1L):x1, , drop = FALSE]
}

# Does this frame show the plot? The element must be at least min_px wide and tall on screen and have at least
# min_ink ink. Returns the verdict and the ink share (NA when the element is too small to ask).
plot_shown <- function(img, rect, scale = 1, min_px = ink_params[["min_px"]], min_ink = ink_params[["min_ink"]]) {
  crop <- crop_to_rect(img, rect, scale)
  if (is.null(crop) || dim(crop)[[2L]] / scale < min_px || dim(crop)[[1L]] / scale < min_px) return(list(shows = FALSE, ink = NA_real_))
  ink <- ink_fraction(crop)
  list(shows = ink >= min_ink, ink = ink)
}

# Does frame k count as the first plot? It shows the plot and so does the next frame. With `hold_ms`
# (screencast, where an unchanged screen sends no frame) it also counts when it stayed on screen that long:
# until the next frame's time `t`, or for the last frame until `t_end`, when the capture stopped.
first_plot_hold_ms <- 100   # about one screenshot interval: a flash the screenshots would see once does not count
frame_accepted <- function(shows, k, t = NULL, t_end = NA_real_, hold_ms = NA_real_) {
  shows[is.na(shows)] <- FALSE
  n <- length(shows)
  if (k < 1L || k > n || !shows[[k]]) return(FALSE)
  if (k < n && shows[[k + 1L]]) return(TRUE)
  if (is.na(hold_ms) || is.null(t)) return(FALSE)
  until <- if (k < n) t[[k + 1L]] else t_end
  !is.na(until) && until - t[[k]] >= hold_ms
}

# Index of the first accepted frame (frame_accepted()); NA when there is none. Without `hold_ms`: the first
# of two frames in a row that show the plot.
first_accepted_frame <- function(shows, t = NULL, t_end = NA_real_, hold_ms = NA_real_) {
  for (k in seq_along(shows)) if (frame_accepted(shows, k, t, t_end, hold_ms)) return(k)
  NA_integer_
}

med <- function(x) if (all(is.na(x))) NA_real_ else stats::median(x, na.rm = TRUE)

# ---- what is measured where ------------------------------------------------------------------------
# fixtures.tsv names the large datasets and where each CRB lies below --large-examples.
# coverage.tsv gives every page exactly one dataset: a large fixture, or a demo CRB that ships with
# CerebroNexus (inst/extdata/examples) for the pages no large dataset has. A page is never measured twice.
read_tsv <- function(path) utils::read.delim(path, stringsAsFactors = FALSE, comment.char = "#")

# The CRB of every fixture below `root`. Stops when one is missing: a run always measures the whole plan.
fixture_paths <- function(fixtures, root) {
  if (!dir.exists(root)) stop("--large-examples: no such directory: ", root, call. = FALSE)
  paths <- stats::setNames(file.path(root, fixtures$crb), fixtures$name)
  missing <- paths[!file.exists(paths)]
  if (length(missing)) stop("missing in --large-examples: ", paste(sprintf("%s (%s)", names(missing), missing), collapse = ", "), call. = FALSE)
  vapply(paths, normalizePath, "", winslash = "/")
}

# One row per page: its dataset, whether that is a large fixture, whether its first plot from the start of
# the page is timed (coverage.tsv column first_plot, "yes"), and its actions (comma separated, in
# actions.tsv order). Pages whose demo CRB the revision does not ship are returned in attr "uncovered".
build_plan <- function(coverage, actions, fixtures = character(), demos_available = character()) {
  if (anyDuplicated(coverage$page)) stop("coverage.tsv lists a page twice: ", paste(unique(coverage$page[duplicated(coverage$page)]), collapse = ", "))
  if (length(stray <- setdiff(actions$page, coverage$page))) stop("actions.tsv names pages that coverage.tsv does not: ", paste(stray, collapse = ", "))
  large <- coverage$dataset %in% fixtures
  ok <- large | coverage$dataset %in% demos_available
  fp <- if (is.null(coverage$first_plot)) rep(FALSE, nrow(coverage)) else coverage$first_plot %in% "yes"
  plan <- data.frame(page = coverage$page, dataset = coverage$dataset, large = large, first_plot = fp, stringsAsFactors = FALSE)
  plan$actions <- vapply(plan$page, function(p) paste(actions$action[actions$page == p], collapse = ","), "", USE.NAMES = FALSE)
  out <- plan[ok, , drop = FALSE]
  # large fixtures first, in the order of fixtures.tsv: they take the longest and need the warm-up
  out <- out[order(!out$large, match(out$dataset, unique(c(fixtures, out$dataset))), match(out$page, coverage$page)), , drop = FALSE]
  rownames(out) <- NULL
  attr(out, "uncovered") <- plan$page[!ok]
  out
}

# The sessions of a run: every round, every page once (with its actions), and for a page with first_plot two
# sessions of their own right after it, in which Chrome navigates to a Viewer that has only just started and
# the page is the first thing opened: once with an emptied cache directory (first_start), once with the kept
# one (first_plot). kind is "page", "first_start" or "first_plot".
# `plans` is one plan, or a named list of plans, one per revision measured in the same run (candidate,
# baseline). The revisions then take turns session by session, so that both meet the same state of the
# machine, and which one goes first changes with every page and every round.
# `tours`: per revision, list(dataset, pages) of its tour (tour_pages()), or NULL: one tour session per round
# and revision, after the round's pages.
build_schedule <- function(plans, rounds, tours = NULL) {
  if (is.data.frame(plans)) plans <- list(candidate = plans)
  pages <- unique(unlist(lapply(plans, function(p) p$page)))
  rows <- list()
  for (r in seq_len(rounds)) {
    for (k in seq_along(pages)) {
      revs <- names(plans)
      if ((r + k) %% 2L == 1L) revs <- rev(revs)
      for (kind in c("page", start_visits)) for (rv in revs) {
        p <- plans[[rv]][plans[[rv]]$page == pages[[k]], , drop = FALSE]
        if (!nrow(p) || (kind != "page" && !isTRUE(p$first_plot))) next
        rows[[length(rows) + 1L]] <- data.frame(round = r, revision = rv, page = p$page, dataset = p$dataset,
                                                actions = if (kind == "page") p$actions else "", kind = kind, tour = "",
                                                stringsAsFactors = FALSE)
      }
    }
    revs <- names(plans)
    if (r %% 2L == 0L) revs <- rev(revs)
    for (rv in intersect(revs, names(tours))) {
      t <- tours[[rv]]
      if (is.null(t) || !length(t$pages)) next
      rows[[length(rows) + 1L]] <- data.frame(round = r, revision = rv, page = "tour", dataset = t$dataset, actions = "",
                                              kind = "tour", tour = paste(t$pages, collapse = ","), stringsAsFactors = FALSE)
    }
  }
  sched <- do.call(rbind, rows)
  sched$position <- seq_len(nrow(sched))
  rownames(sched) <- NULL
  sched
}

# The tour of a plan: the pages of `dataset` in the plan's order, without Data info and the page the Viewer
# opens on (overview), which the session is on already. NULL when the plan has none of them.
tour_pages <- function(plan, dataset = "1m") {
  pages <- plan$page[plan$dataset == dataset & !plan$page %in% c("loadData", "overview")]
  if (length(pages)) list(dataset = dataset, pages = pages) else NULL
}

# --pages a,b: only these pages (and their actions).
subset_plan <- function(plan, pages) {
  unknown <- setdiff(pages, plan$page)
  if (length(unknown)) stop("--pages: not in the plan: ", paste(unknown, collapse = ", "), call. = FALSE)
  out <- plan[plan$page %in% pages, , drop = FALSE]
  rownames(out) <- NULL
  structure(out, uncovered = attr(plan, "uncovered"))
}

# ---- the run directory ---------------------------------------------------------------------------------
# runs/cerebronexus-<version>_<YYYYMMDD-HHMMSS>_<sha7>[_<tag>][_partial]: sorted by version, then by date.
# `tag` tells two runs of one revision made together apart (the baseline of a noise check: "base").
run_dir_name <- function(version, sha, time = Sys.time(), partial = FALSE, tag = "") {
  sprintf("cerebronexus-%s_%s_%s%s%s", version, format(time, "%Y%m%d-%H%M%S"), substr(sha, 1L, 7L),
          if (nzchar(tag)) paste0("_", tag) else "", if (partial) "_partial" else "")
}

# Version field of a package's DESCRIPTION file.
description_version <- function(path) {
  v <- read.dcf(path, fields = "Version")[1L, "Version"]
  if (is.na(v)) stop("no Version in ", path)
  unname(v)
}

# ---- aggregation ----------------------------------------------------------------------------------------
# One row per page x visit: medians over the rounds that finished, the range of the KPI, and the share of
# rounds that finished ("ok").
page_table <- function(raw) {
  key <- paste(raw$page, raw$visit, sep = "\r")
  rows <- lapply(split(raw, key), function(d) {
    ok <- d$status == "ok"
    vc <- d$visual_complete_ms[ok]
    out <- data.frame(
      page = d$page[[1L]], visit = d$visit[[1L]], dataset = d$dataset[[1L]],
      n = nrow(d), ok_frac = mean(ok),
      not_ok = paste(sort(unique(d$status[!ok])), collapse = ","),
      arg = if (is.null(d$arg)) "" else paste(sort(unique(stats::na.omit(d$arg))), collapse = ","),
      visual_min_ms = if (length(vc)) min(vc) else NA_real_, visual_max_ms = if (length(vc)) max(vc) else NA_real_,
      stringsAsFactors = FALSE
    )
    for (m in standard_metrics) out[[m]] <- if (is.null(d[[m]])) NA_real_ else med(d[[m]][ok])
    out
  })
  out <- do.call(rbind, unname(rows))
  out <- out[order(match(out$page, unique(raw$page)), match(out$visit, standard_visits)), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# Session peaks per dataset: the largest peak of any session on it, and the median server start.
memory_table <- function(raw) {
  s <- unique(raw[c("dataset", "session", "run_peak_r_mib", "run_peak_chrome_mib", "server_start_s")])
  out <- do.call(rbind, unname(lapply(split(s, s$dataset), function(d) {
    data.frame(dataset = d$dataset[[1L]], sessions = nrow(d), r_peak_mib = max(d$run_peak_r_mib, na.rm = TRUE),
               chrome_peak_mib = max(d$run_peak_chrome_mib, na.rm = TRUE), server_start_s = med(d$server_start_s), stringsAsFactors = FALSE)
  })))
  out[order(match(out$dataset, unique(raw$dataset))), , drop = FALSE]
}

# Server steps per dataset and step: median time over rounds, the worst status, and the result hash (one
# value when every round returned the same result).
server_table <- function(server) {
  key <- paste(server$dataset, server$step, sep = "\r")
  out <- do.call(rbind, unname(lapply(split(server, key), function(d) {
    ok <- d$status == "ok"
    data.frame(dataset = d$dataset[[1L]], step = d$step[[1L]],
               ms = if (any(ok)) med(d$ms[ok]) else NA_real_, value = if (any(ok)) med(d$value[ok]) else NA_real_,
               status = if (all(ok)) "ok" else paste(sort(unique(d$status[!ok])), collapse = ","),
               hash = paste(sort(unique(d$hash[ok])), collapse = ","), stringsAsFactors = FALSE)
  })))
  out <- out[order(match(out$dataset, unique(server$dataset)), match(out$step, unique(server$step))), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# ---- summary --------------------------------------------------------------------------------------------
fmt_num <- function(x) ifelse(is.na(x), "-", format(round(x), big.mark = ",", trim = TRUE))
fmt_mb <- function(x) ifelse(is.na(x), "-", ifelse(x < 1e5, "<0.1", sprintf("%.1f", x / 1e6)))
md_table <- function(df) {
  df[] <- lapply(df, as.character)
  c(paste0("| ", paste(names(df), collapse = " | "), " |"), paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
    if (nrow(df)) apply(df, 1L, function(r) paste0("| ", paste(r, collapse = " | "), " |")))
}

write_summary <- function(path, info, pages, memory = NULL, server = NULL, problems = character()) {
  status <- ifelse(pages$ok_frac == 1, "ok", sprintf("%s (%d/%d ok)", pages$not_ok, round(pages$ok_frac * pages$n), pages$n))
  tab <- data.frame(Page = pages$page, Visit = pages$visit, Dataset = pages$dataset, Status = status,
                    `Visual (ms)` = fmt_num(pages$visual_complete_ms),
                    `First plot (ms)` = fmt_num(pages$first_plot_ms),
                    `Range (ms)` = ifelse(is.na(pages$visual_min_ms), "-", paste0(fmt_num(pages$visual_min_ms), "-", fmt_num(pages$visual_max_ms))),
                    `Server busy (ms)` = fmt_num(pages$server_busy_ms), `Trail (ms)` = fmt_num(pages$trail_ms),
                    `Largest msg (MB)` = fmt_mb(pages$ws_max_msg_bytes), `Loader (ms)` = fmt_num(pages$loader_visible_ms),
                    `R peak (MiB)` = fmt_num(pages$r_peak_mib), `Chrome peak (MiB)` = fmt_num(pages$chrome_peak_mib),
                    Value = pages$arg, check.names = FALSE, stringsAsFactors = FALSE)
  lines <- c(
    sprintf("# Viewer performance: CerebroNexus %s", info$version), "",
    sprintf("- Run: `%s`", info$run_id),
    sprintf("- Revision: %s (`%s`)", info$ref, info$sha),
    sprintf("- Rounds: %d; sessions: %d, failed twice: %d", info$rounds, info$sessions, info$failed),
    sprintf("- Datasets: %s", info$datasets),
    sprintf("- Machine: %s; %s; %s", info$host, info$os, info$cpu),
    sprintf("- %s; %s, drawn by %s", info$r_version, info$chrome, info$renderer),
    if (!is.null(info$capture)) sprintf("- Frames: %s (`PERF_CAPTURE`; runs with different modes are not comparable)", info$capture) else character(),
    if (!is.null(info$pair)) sprintf("- Measured together with `%s` (%s), session by session in turn", info$pair, info$pair_role) else character(),
    if (!is.null(info$host_load)) sprintf("- Host before the sessions: %s", info$host_load) else character(), "",
    if (length(problems)) c("## Problems", "", paste0("- ", problems), "") else character(),
    if (length(info$uncovered)) c(sprintf("Not measured (this revision ships no dataset for them): %s", paste(info$uncovered, collapse = ", ")), "") else character(),
    "## Pages and actions", "",
    "Medians over the rounds that finished. Visual = click to the last frame that changes (the KPI); range = fastest and slowest round.",
    "On the `first_start` and `first_plot` rows both times run from Chrome's navigation to the Viewer instead of from a click: First plot = to the first frame that shows the projection, Visual = to the last frame that changes. `first_start`: the server's cache directory was emptied before the session; `first_plot`: it held what earlier sessions left.", "",
    md_table(tab), ""
  )
  if (!is.null(memory) && nrow(memory)) {
    lines <- c(lines, "## Memory per dataset", "", "Largest peak of any session on the dataset (R server tree, Chrome tree) and the median server start.", "",
               md_table(data.frame(Dataset = memory$dataset, Sessions = memory$sessions, `R peak (MiB)` = fmt_num(memory$r_peak_mib),
                                   `Chrome peak (MiB)` = fmt_num(memory$chrome_peak_mib), `Server start (s)` = sprintf("%.1f", memory$server_start_s),
                                   check.names = FALSE)), "")
  }
  if (!is.null(server) && nrow(server)) {
    lines <- c(lines, "## Server steps", "", "The R work behind the pages, without a browser (one fresh R process per dataset and round).", "",
               md_table(data.frame(Dataset = server$dataset, Step = server$step, `Time (ms)` = fmt_num(server$ms), Status = server$status, check.names = FALSE)), "")
  }
  writeLines(lines, path)
}

# ---- comparing two runs (compare.R) -----------------------------------------------------------------------
# Manifest facts that should agree for two runs to compare like for like. A difference is reported, not
# refused: comparing across machines can still be useful when it is labelled.
comparable_keys <- c("contract", "platform", "host", "cpu", "memory_measure", "capture", "plan_md5", "fixtures_md5")
# A manifest without the key was made before it existed, with this value.
manifest_defaults <- c(capture = "screenshot")

# A run folder as given, or else the folder of that name under `runs_root` (topics/viewer_performance/runs).
resolve_run <- function(dir, runs_root) {
  if (dir.exists(dir) || is.null(runs_root)) return(dir)
  inside <- file.path(runs_root, basename(dir))
  if (dir.exists(inside)) inside else dir
}

# A run directory as compare_runs() needs it: its id, manifest (named character), pages.tsv and, when it is
# there, raw.tsv (one row per observation: what the test of compare_runs() is made on).
read_run <- function(dir, runs_root = NULL) {
  dir <- resolve_run(dir, runs_root)
  if (!file.exists(file.path(dir, "pages.tsv"))) stop("not a run directory (no pages.tsv): ", dir, call. = FALSE)
  m <- utils::read.delim(file.path(dir, "manifest.tsv"), stringsAsFactors = FALSE, colClasses = "character")
  raw <- file.path(dir, "raw.tsv")
  list(id = basename(normalizePath(dir)), manifest = stats::setNames(m$value, m$key),
       pages = utils::read.delim(file.path(dir, "pages.tsv"), stringsAsFactors = FALSE, colClasses = c(arg = "character")),
       raw = if (file.exists(raw)) utils::read.delim(raw, stringsAsFactors = FALSE, colClasses = c(arg = "character")) else NULL)
}

# Exact two-sided p-value of the rank-sum (Mann-Whitney) test of two small samples: the share of all ways to
# deal the observed values into two groups of these sizes whose rank sum lies at least as far from its
# expectation as the observed one. Equal values share their rank, so ties are exact too. Above `max_perm`
# ways the normal approximation is used. NA when a sample is empty.
rank_sum_p <- function(x, y, max_perm = 50000) {
  x <- x[!is.na(x)]; y <- y[!is.na(y)]
  nx <- length(x); n <- nx + length(y)
  if (!nx || n == nx) return(NA_real_)
  if (choose(n, nx) > max_perm) return(suppressWarnings(stats::wilcox.test(x, y, exact = FALSE)$p.value))
  r <- rank(c(x, y)); centre <- nx * (n + 1) / 2
  w <- utils::combn(n, nx, function(i) sum(r[i]))
  mean(abs(w - centre) >= abs(sum(r[seq_len(nx)]) - centre) - 1e-9)
}

# The smallest p-value rank_sum_p() can return for samples of these sizes (no ties): the two samples do not
# overlap. 3 and 3 rounds give 0.10, 4 and 4 give 0.029, 5 and 5 give 0.008.
rank_sum_min_p <- function(nx, ny) if (!nx || !ny) NA_real_ else 2 / choose(nx + ny, nx)

# Metrics that are read off frames: a difference below the time between two frames cannot be seen.
frame_metrics <- c("visual_complete_ms", "visual_90_ms", "first_plot_ms", "start_plot_ms")

# The Hodges-Lehmann shift of y against x (the median of all differences y_j - x_i) and its 95 % confidence
# interval from the rank-sum test (exact without ties). NA when a sample has fewer than two values.
shift_ci <- function(x, y, level = 0.95) {
  x <- x[!is.na(x)]; y <- y[!is.na(y)]
  if (length(x) < 2L || length(y) < 2L) return(c(shift = NA_real_, lo = NA_real_, hi = NA_real_))
  t <- tryCatch(suppressWarnings(stats::wilcox.test(y, x, conf.int = TRUE, conf.level = level, correct = FALSE)),
                error = function(e) NULL)
  if (is.null(t) || is.null(t$conf.int)) return(c(shift = stats::median(outer(y, x, "-")), lo = NA_real_, hi = NA_real_))
  c(shift = unname(t$estimate), lo = t$conf.int[[1L]], hi = t$conf.int[[2L]])
}

# Compare two runs row by row (page x visit) on `metric`, from the observations of the rounds that finished.
#   slower / faster   the exact rank-sum test over the rounds gives a Holm-adjusted p <= alpha (adjusted over
#                     every row tested), and the medians differ by more than the resolution (frame metrics: the
#                     median time between two frames of that row, in either run; 100 ms when it was not
#                     recorded; other metrics: no floor)
#   suggestive        p <= alpha and more than the resolution, but not after the adjustment: one of the rows
#                     that chance alone would mark among many
#   not resolved      neither: the rounds overlap, or the difference is below one frame
#   too few rounds    with these numbers of rounds no outcome could survive the adjustment over the rows tested
#                     (the smallest possible p times their number is above alpha; 3 against 3 never can)
# and, as before, pages that stopped finishing, finish now, or are in one run only. Runs made together
# (same pair_id in their manifests) also get the range of B - A within each round.
compare_runs <- function(a, b, metric = "visual_complete_ms", alpha = compare_alpha) {
  key <- function(p) paste(p$page, p$visit, sep = "\r")
  ka <- key(a$pages); kb <- key(b$pages)
  all_keys <- c(ka, setdiff(kb, ka))
  pick <- function(p, col) if (is.null(p[[col]])) rep(NA, length(all_keys)) else p[[col]][match(all_keys, key(p))]
  oka <- pick(a$pages, "ok_frac"); okb <- pick(b$pages, "ok_frac")
  arga <- pick(a$pages, "arg"); argb <- pick(b$pages, "arg")
  arga[is.na(arga)] <- ""; argb[is.na(argb)] <- ""
  # the observations of one row: value and round of the rounds that finished, and the time between frames
  obs <- function(run, k) {
    r <- run$raw
    if (is.null(r) || is.null(r[[metric]])) return(list(x = numeric(), round = integer(), frame = NA_real_))
    d <- r[key(r) == k & r$status == "ok" & !is.na(r[[metric]]), , drop = FALSE]
    list(x = d[[metric]], round = d$round, frame = if (is.null(d$frame_ms)) NA_real_ else med(d$frame_ms))
  }
  pair_id <- function(r) if ("pair_id" %in% names(r$manifest) && !is.na(r$manifest[["pair_id"]])) r$manifest[["pair_id"]] else ""
  paired <- nzchar(pair_id(a)) && identical(pair_id(a), pair_id(b))
  rows <- lapply(all_keys, function(k) {
    oa <- obs(a, k); ob <- obs(b, k)
    ma <- med(oa$x); mb <- med(ob$x)
    res <- if (metric %in% frame_metrics) { f <- suppressWarnings(max(oa$frame, ob$frame, na.rm = TRUE)); if (is.finite(f)) f else 100 } else 0
    p <- rank_sum_p(oa$x, ob$x); min_p <- rank_sum_min_p(length(oa$x), length(ob$x))
    both <- intersect(oa$round, ob$round)
    rd <- if (paired && length(both)) vapply(both, function(r) ob$x[match(r, ob$round)] - oa$x[match(r, oa$round)], 0) else numeric()
    ci <- shift_ci(oa$x, ob$x)
    data.frame(a = ma, b = mb, n_a = length(oa$x), n_b = length(ob$x), p = p, min_p = min_p, resolution = res,
               shift = ci[["shift"]], shift_lo = ci[["lo"]], shift_hi = ci[["hi"]],
               round_delta_min = if (length(rd)) min(rd) else NA_real_, round_delta_max = if (length(rd)) max(rd) else NA_real_,
               stringsAsFactors = FALSE)
  })
  st <- do.call(rbind, rows)
  # Every row with observations in both runs is tested; their p-values are adjusted together (Holm).
  tested <- !is.na(st$p)
  st$p_holm <- NA_real_
  st$p_holm[tested] <- stats::p.adjust(st$p[tested], method = "holm")
  m <- sum(tested)
  big <- abs(st$b - st$a) > st$resolution
  change <- ifelse(!tested, "-",
            ifelse(st$min_p * m > alpha, "too few rounds",
            ifelse(st$p_holm <= alpha & big, ifelse(st$b > st$a, "slower", "faster"),
            ifelse(st$p <= alpha & big, "suggestive", "not resolved"))))
  change[!is.na(oka) & !is.na(okb) & oka == 1 & okb < 1] <- "stopped finishing"
  change[!is.na(oka) & !is.na(okb) & oka < 1 & okb == 1] <- "finishes now"
  change[is.na(oka)] <- "only in B"; change[is.na(okb)] <- "only in A"
  ds <- pick(a$pages, "dataset"); ds[is.na(ds)] <- pick(b$pages, "dataset")[is.na(ds)]
  out <- data.frame(
    page = sub("\r.*", "", all_keys), visit = sub(".*\r", "", all_keys), dataset = ds,
    a = st$a, b = st$b, delta = st$b - st$a,
    delta_pct = ifelse(is.na(st$a) | is.na(st$b) | st$a == 0, NA_real_, round((st$b / st$a - 1) * 100, 1)),
    n_a = st$n_a, n_b = st$n_b, p = st$p, p_holm = st$p_holm, resolution = st$resolution,
    shift = st$shift, shift_lo = st$shift_lo, shift_hi = st$shift_hi,
    round_delta_min = st$round_delta_min, round_delta_max = st$round_delta_max,
    a_server_busy_ms = pick(a$pages, "server_busy_ms"), b_server_busy_ms = pick(b$pages, "server_busy_ms"),
    a_r_peak_mib = pick(a$pages, "r_peak_mib"), b_r_peak_mib = pick(b$pages, "r_peak_mib"),
    change = change,
    note = ifelse(!is.na(oka) & !is.na(okb) & arga != argb, sprintf("different value: %s vs %s", arga, argb), ""),
    stringsAsFactors = FALSE
  )
  fact <- function(m) vapply(comparable_keys, function(k) if (k %in% names(m)) m[[k]] else if (k %in% names(manifest_defaults)) manifest_defaults[[k]] else NA_character_, "")
  facts <- data.frame(key = comparable_keys, A = fact(a$manifest), B = fact(b$manifest), stringsAsFactors = FALSE, row.names = NULL)
  sha <- function(r) if ("sha" %in% names(r$manifest)) r$manifest[["sha"]] else NA_character_
  list(table = out, differ = facts$key[!mapply(identical, facts$A, facts$B)], facts = facts, metric = metric, alpha = alpha,
       paired = paired, same_revision = !is.na(sha(a)) && identical(sha(a), sha(b)), tested = m)
}

compare_lines <- function(cmp, a, b) {
  t <- cmp$table
  unit <- if (grepl("_ms$", cmp$metric)) "ms" else if (grepl("_mib$", cmp$metric)) "MiB" else if (grepl("_bytes$", cmp$metric)) "bytes" else ""
  u <- function(s) if (nzchar(unit)) sprintf("%s (%s)", s, unit) else s
  tab <- data.frame(Page = t$page, Visit = t$visit, Dataset = t$dataset, A = fmt_num(t$a), B = fmt_num(t$b), Delta = fmt_num(t$delta),
                    `Delta (%)` = ifelse(is.na(t$delta_pct), "-", sprintf("%+.1f", t$delta_pct)),
                    Shift = ifelse(is.na(t$shift), "-", ifelse(is.na(t$shift_lo), fmt_num(t$shift),
                                   sprintf("%s [%s, %s]", fmt_num(t$shift), fmt_num(t$shift_lo), fmt_num(t$shift_hi)))),
                    `Rounds A / B` = paste0(t$n_a, " / ", t$n_b), p = ifelse(is.na(t$p), "-", sprintf("%.3f", t$p)),
                    `p (Holm)` = ifelse(is.na(t$p_holm), "-", sprintf("%.3f", t$p_holm)),
                    check.names = FALSE, stringsAsFactors = FALSE)
  names(tab)[match(c("A", "B", "Delta", "Shift"), names(tab))] <- c(u("A"), u("B"), u("Delta"), u("Shift [95 % CI]"))
  if (cmp$paired) tab[[u("B - A per round")]] <- ifelse(is.na(t$round_delta_min), "-", paste0(fmt_num(t$round_delta_min), " to ", fmt_num(t$round_delta_max)))
  tab[["Busy A / B (ms)"]] <- paste0(fmt_num(t$a_server_busy_ms), " / ", fmt_num(t$b_server_busy_ms))
  tab[["R peak A / B (MiB)"]] <- paste0(fmt_num(t$a_r_peak_mib), " / ", fmt_num(t$b_r_peak_mib))
  tab$Change <- t$change; tab$Note <- t$note
  version <- function(r) if ("version" %in% names(r$manifest)) r$manifest[["version"]] else "?"
  tested <- t$change %in% c("slower", "faster", "suggestive", "not resolved")
  flagged <- t$change %in% c("slower", "faster")
  few <- sum(t$change == "too few rounds")
  c(sprintf("# Viewer performance: CerebroNexus %s (A) vs %s (B)", version(a), version(b)), "",
    sprintf("- A: `%s`", a$id), sprintf("- B: `%s`", b$id), sprintf("- Metric: `%s`, median over the rounds that finished", cmp$metric), "",
    if (cmp$same_revision) c("**Noise check:** both runs measured the same revision, so every difference below is noise of the measurement. No row should be marked slower or faster.", "") else character(),
    if (length(cmp$differ)) c(sprintf("**Not like for like:** the runs differ in %s, so part of any difference comes from the setup, not the code.", paste(cmp$differ, collapse = ", ")), "",
                              md_table(cmp$facts[cmp$facts$key %in% cmp$differ, , drop = FALSE]), "")
    else c("Both runs have the same contract, platform, host, CPU, frame capture, plan and large datasets.", ""),
    if (cmp$paired) c("The two runs were made together, their sessions taking turns, so both met the same state of the machine.", "")
    else c("The two runs were not made together: a machine that was busier during one of them shows as a difference. Measure both in one run (`run.R --baseline`) to rule that out.", ""),
    sprintf("Change: `slower` or `faster` when the exact two-sided rank-sum test over the rounds gives p <= %s after the Holm adjustment over the %d rows tested, and the medians differ by more than one frame; `suggestive` when only the unadjusted p does; `not resolved` otherwise; `too few rounds` when the numbers of rounds cannot survive the adjustment at all. Shift: the Hodges-Lehmann estimate of B - A with its 95 %% confidence interval.",
            format(cmp$alpha), cmp$tested %||% 0L), "",
    md_table(tab), "",
    sprintf("Slower: %d; faster: %d; suggestive: %d; stopped finishing: %d; not resolved: %d; too few rounds: %d.", sum(t$change == "slower"), sum(t$change == "faster"),
            sum(t$change == "suggestive"), sum(t$change == "stopped finishing"), sum(t$change == "not resolved"), few),
    if (any(tested)) sprintf("%d rows were tested together: the chance that any of them is marked slower or faster when nothing changed is at most %s (Holm); without the adjustment up to %.1f would be marked by chance alone (the `suggestive` rows).",
                             sum(tested), format(cmp$alpha), sum(tested) * cmp$alpha) else character(),
    if (cmp$same_revision && any(!is.na(t$delta))) sprintf("Noise: the medians of the two runs differ by %s %s in the median row, by %s at the 90th percentile and by %s at most; %d of %d tested rows marked.",
                                    fmt_num(stats::median(abs(t$delta), na.rm = TRUE)), unit, fmt_num(stats::quantile(abs(t$delta), 0.9, na.rm = TRUE, names = FALSE)),
                                    fmt_num(max(abs(t$delta), na.rm = TRUE)), sum(flagged), sum(tested)) else character())
}

# ---- plotting several runs (plot.R) ------------------------------------------------------------------------
# Legend labels: the CerebroNexus version; when two runs share a version, the date is added, and when they
# also share the date, the start time.
run_labels <- function(version, started) {
  t <- as.POSIXct(substr(started, 1L, 19L), format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
  day <- format(t, "%Y-%m-%d"); hm <- format(t, "%Y-%m-%d %H:%M")
  lab <- version
  dup <- version %in% version[duplicated(version)]
  lab[dup] <- sprintf("%s (%s)", version[dup], day[dup])
  dup2 <- lab %in% lab[duplicated(lab)]
  lab[dup2] <- sprintf("%s (%s)", version[dup2], hm[dup2])
  lab
}

# Runs by version, then by when they were made, whatever order the folders were given in.
order_runs <- function(runs) {
  v <- vapply(runs, function(r) r$manifest[["version"]] %||% "0", "")
  v <- tryCatch(numeric_version(v), error = function(e) NULL)
  started <- vapply(runs, function(r) r$manifest[["started"]] %||% "", "")
  runs[if (is.null(v)) order(started) else order(v, started)]
}

# Font for figures: Arial or Helvetica as Genome Biology asks (Windows ships Arial). Without systemfonts the
# name is used as is. No silent substitution: `substitute = TRUE` allows the closest sans font for a draft.
figure_font <- function(substitute = FALSE) {
  wanted <- c("Arial", "Helvetica", if (substitute) c("Liberation Sans", "Nimbus Sans", "DejaVu Sans"))
  if (!requireNamespace("systemfonts", quietly = TRUE)) return("Arial")
  have <- unique(systemfonts::system_fonts()$family)
  hit <- wanted[wanted %in% have]
  if (!length(hit)) stop("Arial or Helvetica is not installed; use --allow-font-substitute for a draft", call. = FALSE)
  hit[[1L]]
}

# Rows split into columns: consecutive pages with their actions, never a page apart from its actions, in
# about equal halves. Returns the column of each row.
split_rows <- function(is_page, ncol) {
  if (ncol <= 1L) return(rep(1L, length(is_page)))
  block <- cumsum(is_page)
  sizes <- tabulate(block)
  cut_at <- findInterval(cumsum(sizes) - sizes / 2, seq(0, length(is_page), length.out = ncol + 1L)[-c(1L, ncol + 1L)]) + 1L
  cut_at[block]
}

# Readable names for the figure: the sidebar name of each page, a short verb for each action and the dataset
# a page was measured on. An id without an entry is shown as it is.
PAGE_NAMES <- c(loadData = "Load data", overview = "Projection", coordinated_views = "Linked views", groups = "Groups",
                geneExpression = "Gene expression", trajectory = "Trajectory", color_management = "Colour management",
                geneIdConversion = "Gene ID conversion", about = "About", immune_repertoire = "Immune repertoire",
                hla_tcr_motifs = "HLA & TCR motifs", extra_material = "Extra material", spatial = "Spatial",
                markerGenes = "Marker genes", mostExpressedGenes = "Most expressed genes", enrichedPathways = "Enriched pathways",
                trekker = "Trekker")
ACTION_NAMES <- c(switch = "Switch dataset", switch_back = "Switch back", colour_by = "Change colouring", zoom = "Zoom",
                  lasso = "Lasso select", group = "Change grouping", plot_type = "Change plot type", percent = "Show as percent",
                  gene = "Show 1 gene", genes12 = "Show 12 genes", tab = "Switch tab", content = "Switch content",
                  section = "Switch section", table = "Switch table")
DATASET_NAMES <- c(`1m` = "mouse brain, 1.3 M", ren = "COVID-19, 1.46 M", cosmx = "CosMx NSCLC, 800 k",
                   example = "example", demo_trekker = "Trekker demo")
display_name <- function(id, table) ifelse(id %in% names(table), table[id], id)
row_names <- function(page, is_page, visit = rep("cold", length(page))) {
  ifelse(visit == "first_start", "From page load, nothing kept", ifelse(visit == "first_plot", "From page load",
         ifelse(visit == "tour", "On the way, one session",
         ifelse(is_page, display_name(page, PAGE_NAMES), display_name(sub("^[^.]*[.]", "", page), ACTION_NAMES)))))
}

# The figure's rows ("page\rvisit" keys, in the order the runs list them) with each row under its page: a
# visit or action that only a later run has (a tour, the first plot) would otherwise come after the last page of
# the earlier runs. The page's own row stays first.
order_rows <- function(keys) {
  kp <- sub("\r.*", "", keys); kv <- sub(".*\r", "", keys); grp <- sub("[.].*", "", kp)
  head_row <- kp == grp & !kv %in% c("action", "tour", start_visits)
  keys[order(match(grp, unique(grp)), !head_row, seq_along(keys))]
}

# One dot per run and page or action (the median of `metric`), with a line over the fastest and slowest
# round for the KPI. Runs are ordered by version, then date. Rows are every page and action with a value in
# any run, in plan order, on a log time axis (actions take milliseconds, the largest pages seconds). Pages are
# bold with their dataset in grey where it changes, actions are indented under them. `threshold` draws dashed vertical lines
# (ms; default 1 s, NULL for none) for a response-time limit.
# Genome Biology artwork rules, as in topics/expression_backends: 170 mm wide, at most 225 mm tall (two
# columns when one would be taller), vector PDF with Arial, 7 pt text, lines >= 0.25 pt, Okabe-Ito colours,
# legend in the figure, no title. Writes <stem>.pdf and <stem>.png; `out` may end in .pdf or .png.
plot_runs <- function(runs, out, metric = "visual_complete_ms", family = figure_font(), threshold = 1000) {
  if (!any(vapply(runs, function(r) metric %in% names(r$pages), TRUE))) stop("no values of ", metric, " in these runs", call. = FALSE)
  runs <- order_runs(runs)
  labs <- run_labels(vapply(runs, function(r) r$manifest[["version"]] %||% "?", ""), vapply(runs, function(r) r$manifest[["started"]] %||% "", ""))
  key <- function(p) paste(p$page, p$visit, sep = "\r")
  keys <- order_rows(unique(unlist(lapply(runs, function(r) key(r$pages)))))
  col_of <- function(col) matrix(sapply(runs, function(r) {
    m <- match(keys, key(r$pages)); v <- if (is.null(r$pages[[col]])) rep(NA_real_, length(keys)) else r$pages[[col]][m]
    ifelse(!is.na(r$pages$ok_frac[m]) & r$pages$ok_frac[m] > 0, v, NA_real_)
  }), nrow = length(keys))
  val <- col_of(metric)
  ranged <- identical(metric, "visual_complete_ms")
  lo <- if (ranged) col_of("visual_min_ms") else val; hi <- if (ranged) col_of("visual_max_ms") else val
  page_of <- sub("\r.*", "", keys); visit_of <- sub(".*\r", "", keys); is_page <- !visit_of %in% c("action", "tour", start_visits)
  keep <- is_page | rowSums(!is.na(val)) > 0   # an action no run could do (e.g. one table only) has no row
  val <- val[keep, , drop = FALSE]; lo <- lo[keep, , drop = FALSE]; hi <- hi[keep, , drop = FALSE]
  keys <- keys[keep]; page_of <- page_of[keep]; is_page <- is_page[keep]; visit_of <- visit_of[keep]
  row_lab <- row_names(page_of, is_page, visit_of)
  dataset_of <- function(r) r$pages$dataset[match(keys, key(r$pages))]
  ds <- Reduce(function(a, b) ifelse(is.na(a), b, a), lapply(runs, dataset_of))
  ds_lab <- ifelse(is_page & !is.na(ds), display_name(ds, DATASET_NAMES), "")
  pos <- c(val, lo, hi); pos <- pos[!is.na(pos) & pos > 0]
  if (!length(pos)) stop("no values of ", metric, " in these runs", call. = FALSE)
  xlim <- range(pos) * c(0.8, 1.25)
  threshold <- threshold[!is.na(threshold) & threshold > 0]
  if (!ranged) threshold <- NULL   # a time limit means nothing on another metric
  n <- length(keys); k <- length(runs)
  pal <- rep(c("#0072B2", "#E69F00", "#009E73", "#CC79A7", "#56B4E9", "#D55E00", "#F0E442", "#000000"), length.out = k)
  grey <- "#595959"
  # Sizes in points: 482 pt = 170 mm wide, at most 637.8 pt = 225 mm tall.
  width_pt <- 482; max_pt <- 637.8
  row_pt <- max(9, 2 + 2.4 * k)
  n_leg <- k + length(threshold)
  leg_cols <- min(n_leg, 4L); top_pt <- 19 + 11 * ceiling(n_leg / leg_cols)
  chrome_pt <- top_pt + 34   # legend on top (four entries per line), axis and its title below
  ncol <- if (n * row_pt + chrome_pt <= max_pt) 1L else 2L
  col <- split_rows(is_page, ncol)
  rows_per_col <- max(tabulate(col, ncol))
  if (rows_per_col * row_pt + chrome_pt > max_pt) row_pt <- (max_pt - chrome_pt) / rows_per_col
  height_pt <- rows_per_col * row_pt + chrome_pt
  stem <- sub("[.](pdf|png)$", "", out, ignore.case = TRUE)
  fmt_ms <- function(t) ifelse(t >= 1000, paste0(t / 1000, " s"), paste0(t, " ms"))
  draw <- function() {
    graphics::par(family = family, ps = 7, cex = 1, mgp = c(1.4, 0.3, 0), tcl = -0.2, lwd = 0.5,
                  omi = c(0, 0, top_pt / 72, 0), mfrow = c(1L, ncol), xpd = FALSE)
    off <- if (k > 1L) seq(0.3, -0.3, length.out = k) else 0
    ticks <- c(1, 3, 10, 30, 100, 300, 1000, 3000, 10000, 30000, 1e5)
    ticks <- ticks[ticks >= xlim[[1L]] & ticks <= xlim[[2L]]]
    sw <- function(s, font = 1) graphics::strwidth(s, units = "inches", font = font, family = family)
    indent_in <- 0.1; gap_in <- 0.08
    name_in <- max(sw(row_lab[is_page], 2), indent_in + sw(row_lab[!is_page]), 0.3)
    ds_in <- max(sw(ds_lab), 0)
    label_in <- name_in + (if (ds_in > 0) gap_in + ds_in else 0) + 0.1
    for (cc in seq_len(ncol)) {
      rows <- which(col == cc); m <- length(rows)
      graphics::par(mai = c(34 / 72, label_in, 0.02, 0.05))
      y <- rev(seq_len(m)) + (rows_per_col - m)
      graphics::plot(NA, xlim = xlim, ylim = c(0.5, rows_per_col + 0.5), log = "x", yaxs = "i", axes = FALSE, xlab = "", ylab = "")
      graphics::abline(v = ticks, col = "#E6E6E6", lwd = 0.5)
      graphics::abline(h = y[is_page[rows]] + 0.5, col = "#D0D0D0", lwd = 0.5, lty = 3)
      if (length(threshold)) graphics::abline(v = threshold, col = grey, lwd = 0.8, lty = "22")
      graphics::axis(1, at = ticks, labels = fmt_ms(ticks), lwd = 0.5, lwd.ticks = 0.5)
      graphics::mtext(if (ranged) "Click (or page load) to final frame (log scale)" else paste(metric, "(log scale)"), side = 1, line = 1.3, cex = 1)
      # labels left-aligned in the margin: page name bold, its actions indented; dataset in grey before the axis
      left_in <- graphics::grconvertX(10^graphics::par("usr")[[1L]], "user", "inches") - label_in + 0.02
      at_in <- function(dx) graphics::grconvertX(left_in + dx, "inches", "user")
      x0 <- at_in(0); x_act <- at_in(indent_in); x_ds <- at_in(name_in + gap_in)
      graphics::par(xpd = NA)
      p <- is_page[rows]
      graphics::text(ifelse(p, x0, x_act), y, row_lab[rows], adj = c(0, 0.5), font = ifelse(p, 2, 1), col = ifelse(p, "black", "#333333"))
      # the dataset only where it changes (and at the top of a column)
      d <- ds_lab[rows]; first <- p & c(TRUE, d[-1L] != Reduce(function(a, b) if (nzchar(b)) b else a, d, accumulate = TRUE)[-m])
      if (ds_in > 0) graphics::text(x_ds, y[first], d[first], adj = c(0, 0.5), col = grey)
      graphics::par(xpd = FALSE)
      for (j in seq_len(k)) {
        if (ranged) graphics::segments(lo[rows, j], y + off[[j]], hi[rows, j], y + off[[j]], col = grDevices::adjustcolor(pal[[j]], 0.55), lwd = 0.8)
        graphics::points(val[rows, j], y + off[[j]], pch = 19, cex = 0.45, col = pal[[j]])
      }
    }
    graphics::par(xpd = NA)
    th <- length(threshold)
    graphics::legend(graphics::grconvertX(0.5, "ndc", "user"), graphics::grconvertY(1, "ndc", "user"),
                     legend = c(labs, if (th) paste(fmt_ms(threshold), "threshold")),
                     col = c(pal, rep(grey, th)), pch = c(rep(19, k), rep(NA, th)), lty = c(rep(NA, k), rep("22", th)),
                     lwd = c(rep(NA, k), rep(0.8, th)), seg.len = 1.6, y.intersp = 0.8, title.adj = 0.5,
                     pt.cex = 0.6, ncol = leg_cols, bty = "n", xjust = 0.5, yjust = 1, title = if (ranged) "CerebroNexus (dot = median over rounds; line = fastest to slowest round)" else "CerebroNexus (median over rounds)")
  }
  grDevices::cairo_pdf(paste0(stem, ".pdf"), width = width_pt / 72, height = height_pt / 72, family = family, bg = "white")
  tryCatch(draw(), finally = grDevices::dev.off())
  grDevices::png(paste0(stem, ".png"), width = width_pt / 72, height = height_pt / 72, units = "in", res = 300, type = if (capabilities("cairo")) "cairo" else "windows", family = family, bg = "white")
  tryCatch(draw(), finally = grDevices::dev.off())
  invisible(c(pdf = paste0(stem, ".pdf"), png = paste0(stem, ".png"), width_mm = width_pt / 72 * 25.4, height_mm = height_pt / 72 * 25.4))
}
