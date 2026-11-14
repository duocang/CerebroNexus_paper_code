#!/usr/bin/env Rscript
# One measured session: a fresh R server (the installed revision) and a fresh Chrome, one CRB, one page.
#   Data info loads the dataset (recorded as `initial` when the page is loadData), then the page opens
#   (`cold`), then each of its actions runs on it (`action`, hook.js). A fresh R process per page, so the
#   page pays its own first-use costs (expression backend, repertoire), whatever other pages exist.
#   --page none opens Data info only (a warm-up) and records nothing.
#   --first-plot (with --page overview) is the other kind of session: Chrome navigates to a Viewer that has just
#   started, opens the Projection page as soon as the sidebar offers it and the clock (visit `first_plot`) runs
#   from the navigation to the first frame that shows the projection, and to the last frame that changes;
#   start_plot_ms runs from the launch of the R server to the same frame.
#   --tour a,b,c is a third kind: the session opens the Viewer, stays tour_wait_s on the page it opens on, then
#   opens the listed pages one after another (visit `tour`), tour_think_s after the last one finished, without
#   waiting for a quiet server in between.
# Every observation starts with the R server and Chrome quiet and ends when they are quiet again;
# appends one row per observation to --out.
#
# usage: measure_session.R --sha S --lib DIR --crb FILE --port N --round N --out FILE --page P
#        [--actions a,b]   in-page actions to run after the page opened (actions.tsv)
#        [--first-plot [VISIT]]  time the start to the first plot instead of a click (page overview, no actions);
#                          VISIT names the row: first_plot (default) or first_start (the caller emptied --cache-dir)
#        [--cache-dir DIR] the server's user cache directory (R_USER_CACHE_DIR): what the Viewer keeps between
#                          starts goes there and nowhere else. Without it the user's own cache is used.
#        [--crb2 FILE]     a second CRB in the dataset menu, for the loadData.switch actions
#        [--dataset NAME]  [--session ID]  Chrome flags: env PERF_CHROME_ARGS (e.g. --no-sandbox)
#        [--trace FILE]    keep the CPU and memory samples (CSV) of the session
#        [--tour a,b]      the pages of a tour (lib.R, tour_pages()); --page is then "tour"
suppressPackageStartupMessages({
  library(chromote); library(processx); library(jsonlite)
})
for (p in c("png", "base64enc")) if (!requireNamespace(p, quietly = TRUE)) stop("package ", p, " is required")
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[[1L]])))
source(file.path(here, "cli.R"))
source(file.path(here, "lib.R"))
source(file.path(here, "proc.R"))
opt <- parse_cli(commandArgs(trailingOnly = TRUE))
sha <- opt$sha; lib <- opt$lib; crb <- opt$crb
port <- as.integer(opt$port); round <- as.integer(opt$round); out <- opt$out
dataset <- if (!is.null(opt$dataset)) opt$dataset else sub("\\.crb$", "", basename(crb))
page <- if (is.null(opt$page)) stop("--page is required") else opt$page
actions <- if (is.null(opt$actions) || isTRUE(opt$actions) || !nzchar(opt$actions)) character() else strsplit(opt$actions, ",", fixed = TRUE)[[1L]]
session_id <- if (is.null(opt$session)) NA_character_ else opt$session
first_plot_mode <- !is.null(opt$first_plot)
first_plot_visit <- if (isTRUE(opt$first_plot)) "first_plot" else opt$first_plot
if (first_plot_mode && !first_plot_visit %in% start_visits) stop("--first-plot takes ", paste(start_visits, collapse = " or "))
if (first_plot_mode && (!identical(page, "overview") || length(actions))) stop("--first-plot is for --page overview, without actions")
tour <- if (is.null(opt$tour) || isTRUE(opt$tour)) character() else strsplit(opt$tour, ",", fixed = TRUE)[[1L]]
if (length(tour) && (first_plot_mode || length(actions))) stop("--tour goes without --first-plot and --actions")
now_ms <- function() as.numeric(Sys.time()) * 1000

# The cache directory of the server, and how many files it holds before the server starts (0: nothing kept).
cache_dir <- if (is.null(opt$cache_dir) || isTRUE(opt$cache_dir)) NULL else opt$cache_dir
if (!is.null(cache_dir)) dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
cache_files <- if (is.null(cache_dir)) NA_integer_ else length(list.files(cache_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE))

log_file <- tempfile(fileext = ".log")
# The launch of the R server: start_plot_ms of the first-plot visits runs from here.
t_launch <- now_ms()
server <- process$new(
  r_bin("Rscript"), c("--no-save", "--no-restore", file.path(here, "server.R")),
  env = c("current", PERF_LIB = lib, PERF_CRB = crb, PERF_CRB2 = if (is.null(opt$crb2)) "" else opt$crb2, PERF_PORT = port, R_LIBS = lib, R_PROFILE_USER = nullfile(),
          if (!is.null(cache_dir)) c(R_USER_CACHE_DIR = normalizePath(cache_dir, winslash = "/"))),
  stdout = log_file, stderr = "2>&1", cleanup_tree = TRUE
)
stop_file <- tempfile(fileext = ".stop"); mem_csv <- if (is.null(opt$trace)) tempfile(fileext = ".csv") else opt$trace
sampler <- NULL
cleanup <- function() {
  try(file.create(stop_file), silent = TRUE)
  try(if (!is.null(sampler)) sampler$wait(3000), silent = TRUE)
  try(server$kill_tree(), silent = TRUE)
}
on.exit(cleanup(), add = TRUE)

# The server is up when Shiny says it listens (read from its log every 20 ms: a refused connection takes up to
# a second to fail on Windows, which made the start time that coarse), and a connection is accepted.
t_wait <- Sys.time()
repeat {
  listening <- any(grepl("Listening on", readLines(log_file, warn = FALSE), fixed = TRUE)) ||
    as.numeric(difftime(Sys.time(), t_wait, units = "secs")) > 30   # a Shiny that does not say so
  ok <- listening && tryCatch({ con <- socketConnection("127.0.0.1", port, open = "r+", timeout = 1); close(con); TRUE },
                              error = function(e) FALSE, warning = function(w) FALSE)
  if (ok) break
  if (!server$is_alive()) stop("server died:\n", paste(utils::tail(readLines(log_file, warn = FALSE), 25), collapse = "\n"))
  if (as.numeric(difftime(Sys.time(), t_wait, units = "secs")) > 240) stop("server start timeout")
  Sys.sleep(0.02)
}
server_start_s <- (now_ms() - t_launch) / 1000
info <- grep("^PERF_INFO", readLines(log_file, warn = FALSE), value = TRUE)
pkg_version <- if (length(info)) sub(" path=.*", "", sub("^PERF_INFO version=", "", info[[1L]])) else NA_character_

chrome_args <- chromote::default_chrome_args()
# Chrome draws with the machine's GPU (WebGL), never in software. On Linux that is OpenGL through ANGLE (the
# Vulkan path gives WebGPU but its canvas comes out blank in screenshots); without a GPU (WSL) Chrome renders in
# software, which the manifest's `renderer` shows (SwiftShader).
chrome_args <- c(setdiff(chrome_args, "--disable-gpu"), "--enable-unsafe-webgpu", "--ignore-gpu-blocklist")
if (!on_windows) chrome_args <- c(chrome_args, "--use-gl=angle", "--use-angle=gl")
extra <- Sys.getenv("PERF_CHROME_ARGS", "")
if (nzchar(extra)) chrome_args <- c(chrome_args, strsplit(extra, " ", fixed = TRUE)[[1L]])
# A loaded machine can take more than chromote's default 10 s to open the debugging port.
options(chromote.timeout = 60)
br <- Chrome$new(args = chrome_args)
chrome_pid <- br$get_process()$get_pid()
cm <- Chromote$new(browser = br)
b <- ChromoteSession$new(parent = cm)
on.exit({ try(b$close(), silent = TRUE); try(cm$close(), silent = TRUE); try(br$close(), silent = TRUE) }, add = TRUE)
invisible(b$Emulation$setDeviceMetricsOverride(width = 1619, height = 950, deviceScaleFactor = 1, mobile = FALSE))
# The websocket counter must be in the page before Shiny opens its socket. The script only takes effect
# with the Page domain enabled. (Not the Network domain: see ws.js.)
invisible(b$Page$enable())
invisible(b$Page$addScriptToEvaluateOnNewDocument(source = paste(readLines(file.path(here, "ws.js"), warn = FALSE), collapse = "\n")))

sampler <- start_sampler(here, server$get_pid(), chrome_pid, mem_csv, stop_file)

ev <- function(expr) {
  r <- b$Runtime$evaluate(expr, returnByValue = TRUE, awaitPromise = FALSE)
  if (!is.null(r$exceptionDetails)) stop("JS error: ", r$exceptionDetails$text, " ", r$exceptionDetails$exception$description)
  r$result$value
}
hook <- paste(readLines(file.path(here, "hook.js"), warn = FALSE), collapse = "\n")
nz <- function(x) if (is.null(x)) NA_real_ else x

js_peak <- 0
# Frames are compared at quarter scale. With the GPU (Windows) a screenshot Chrome scales down alternates
# between two samplings from one capture to the next (a 1-pixel line moves): capture at full size there
# and take every 4th pixel, which is the same every time.
shot_scale <- if (on_windows) 1 else 0.25
viewport <- list(x = 0, y = 0, width = 1619, height = 950, scale = shot_scale)
quarter <- function(m) if (shot_scale == 1) m[seq(1L, dim(m)[[1L]], 4L), seq(1L, dim(m)[[2L]], 4L), , drop = FALSE] else m
shot <- function() b$Page$captureScreenshot(format = "png", clip = viewport, optimizeForSpeed = TRUE)$data

# Frames are captured back to back while waiting; the page-side hook decides when to stop. `tolerant` is for the
# page load of a first_plot session (Runtime.evaluate and screenshots can fail while Chrome navigates; the
# hook may not be in the page yet); `grace_s` keeps capturing for that long after the page is done.
# Each frame keeps `rect`, where the hook says the projection is (first_plot sessions).
wait_done <- function(timeout_s, capture = TRUE, state_js = "window.__cb.state()", tolerant = FALSE, grace_s = 0) {
  t0 <- Sys.time(); frames <- list(); done_at <- NULL
  repeat {
    t_a <- now_ms()
    st <- if (tolerant) tryCatch(fromJSON(ev(state_js)), error = function(e) list()) else fromJSON(ev(state_js))
    h <- tryCatch(b$Runtime$getHeapUsage()$usedSize, error = function(e) NA_real_)
    if (!is.na(h) && h > js_peak) js_peak <<- h
    if (capture) {
      t_f <- (t_a + now_ms()) / 2
      img <- if (tolerant) tryCatch(shot(), error = function(e) NULL) else shot()
      if (!is.null(img)) frames[[length(frames) + 1L]] <- list(t = t_f, img = img, rect = st$rect)
    }
    if (isTRUE(st$done) && is.null(done_at)) done_at <- Sys.time()
    if (!is.null(done_at) && as.numeric(difftime(Sys.time(), done_at, units = "secs")) >= grace_s) {
      st$status <- if (nzchar(st$error %||% "")) "error" else if (isTRUE(st$stuck)) "stuck_busy" else "ok"
      st$frames <- frames; return(st)
    }
    if (as.numeric(difftime(Sys.time(), t0, units = "secs")) > timeout_s) {
      message("timeout; last page state: ", tryCatch(ev(state_js), error = function(e) conditionMessage(e)))
      st$status <- "timeout"; st$frames <- frames; return(st)
    }
    if (!capture) Sys.sleep(0.04)
  }
}

# Pixel similarity of every frame to the last one (share of identical pixels).
frame_similarity <- function(frames) {
  mats <- lapply(frames, function(f) quarter(png::readPNG(base64enc::base64decode(f$img))))
  fin <- mats[[length(mats)]]
  vapply(mats, function(m) {
    d <- abs(m - fin) > 1e-6
    1 - mean(d[, , 1L] | d[, , 2L] | d[, , 3L])
  }, 0)
}

# Server and Chrome were seen quiet at the end of the last observation and nothing happened since: the
# next one can start without waiting again.
quiet_now <- FALSE

# Prepare an action (find its control, load what it needs) before the clock starts. Returns the
# argument, or NULL when the control is not there.
prepare_action <- function(name, timeout_s = 30) {
  t0 <- Sys.time()
  repeat {
    r <- fromJSON(ev(sprintf("window.__cb.actionPrep(%s)", toJSON(name, auto_unbox = TRUE))))
    if (!isTRUE(r$available)) return(NULL)
    if (isTRUE(r$ready)) return(as.character(r$arg))
    if (as.numeric(difftime(Sys.time(), t0, units = "secs")) > timeout_s) return(NULL)
    Sys.sleep(0.2)
  }
}

rows <- list()
add_row <- function(page, visit, status, arg = NA_character_, error = NA_character_, vis = NULL, st = list(), idle_wait = NA_real_,
                    ft = numeric(), t_start = NA_real_, t_end = NA_real_, t_quiet = NA_real_, trail = NA_real_, ws = list(), fp = list()) {
  rows[[length(rows) + 1L]] <<- data.frame(
    contract = standard_contract, sha = sha, pkg_version = pkg_version, dataset = dataset, round = round, session = session_id,
    seq = length(rows) + 1L, browser = browser, gpu = gpu, page = page, visit = visit, status = status, arg = arg, error = error,
    visual_complete_ms = vis$visual_complete_ms %||% NA_real_, visual_90_ms = vis$visual_90_ms %||% NA_real_,
    first_plot_ms = nz(fp$first_plot_ms), start_plot_ms = nz(fp$start_plot_ms), page_ready_ms = nz(st$page_ready_ms),
    plot_click_ms = nz(fp$click_ms), plot_ink = nz(fp$ink), settled_ms = nz(st$settled_ms),
    loader_visible_ms = nz(st$loader_ms), visible_ms = nz(st$visible_ms), js_peak_mib = if (is.null(vis)) NA_real_ else js_peak / 2^20,
    trail_ms = trail, ws_in_bytes = nz(ws$ws_in_bytes), ws_out_bytes = nz(ws$ws_out_bytes), ws_max_msg_bytes = nz(ws$ws_max_msg_bytes),
    idle_wait_s = idle_wait, frames = length(ft), frame_ms = if (length(ft) > 1L) stats::median(diff(ft)) else NA_real_,
    cache_files = cache_files,
    t_start = t_start, t_end = t_end, t_quiet = t_quiet, stringsAsFactors = FALSE
  )
}

# The renderer: the WebGL renderer and whether WebGPU has an adapter (a software renderer in WSL, the GPU on
# Windows). Needs the Viewer's page; sets `gpu`.
probe_gpu <- function() {
  tryCatch(ev(paste0("(async function(){var c=document.createElement('canvas'),g=c.getContext('webgl2')||c.getContext('webgl'),r='none';",
    "if(g){var x=g.getExtension('WEBGL_debug_renderer_info');r=x?g.getParameter(x.UNMASKED_RENDERER_WEBGL):g.getParameter(g.RENDERER);}",
    "var w='no webgpu';try{if(navigator.gpu){var a=await navigator.gpu.requestAdapter();w=a?'webgpu':'webgpu without adapter';}}catch(e){}",
    "window.__cbgpu=r+'; '+w;})()")), error = function(e) NULL)
  Sys.sleep(0.5)
  gpu <<- tryCatch(as.character(ev("window.__cbgpu || 'unknown'")), error = function(e) "unknown")
}

# The first frame that shows the projection (first_plot sessions): the first of two frames in a row for which
# plot_shown() holds, and its time from the navigation. Frames are decoded in order and the search stops there.
first_plot_from_frames <- function(frames, t_start) {
  shows <- rep(FALSE, length(frames)); ink <- rep(NA_real_, length(frames)); hit <- NA_integer_
  for (i in seq_along(frames)) {
    r <- frames[[i]]$rect
    if (length(r) != 4L) next
    res <- plot_shown(png::readPNG(base64enc::base64decode(frames[[i]]$img)), r, shot_scale)
    shows[[i]] <- res$shows; ink[[i]] <- res$ink
    if (i > 1L && shows[[i]] && shows[[i - 1L]]) { hit <- i - 1L; break }
  }
  if (is.na(hit)) return(list(first_plot_ms = NA_real_, ink = NA_real_))
  list(first_plot_ms = frames[[hit]]$t - t_start, ink = ink[[hit]])
}

# `nav`: the first_plot observation. The clock starts when Chrome is told to navigate to the Viewer (the server
# has just started: no wait for it to be quiet), the hook opens the Projection page as soon as it is offered.
# `tour`: a page of a tour, opened without waiting for a quiet server before or after it.
measure <- function(name, visit, initial = FALSE, timeout_s = 90, record = TRUE, action = FALSE, nav = FALSE, tour = FALSE) {
  js_peak <<- 0
  arg <- NA_character_
  if (action) {
    arg <- prepare_action(name)
    if (is.null(arg)) {
      message(sprintf("  %-28s %-8s unavailable", name, visit))
      return(add_row(name, visit, "unavailable"))
    }
  }
  # Start from a quiet server and Chrome; the wait is not part of the measurement.
  idle_wait <- if (initial || nav || tour) NA_real_ else if (quiet_now) 0 else wait_quiet(mem_csv)$waited_s
  if (!nav) ev("window.__cbws && window.__cbws.reset()")
  t_start <- now_ms()
  if (nav) invisible(b$Page$navigate(sprintf("http://127.0.0.1:%d/", port)))
  else if (action) ev(sprintf("window.__cb.actionBegin(%s, %s)", toJSON(name, auto_unbox = TRUE), toJSON(arg, auto_unbox = TRUE)))
  else ev(sprintf("window.__cb.begin(%s, %s)", toJSON(name, auto_unbox = TRUE), if (initial) "true" else "false"))
  st <- if (nav) wait_done(timeout_s, state_js = "window.__cb && window.__cb.fpStep ? window.__cb.fpStep() : '{}'", tolerant = TRUE, grace_s = 1)
        else wait_done(timeout_s)
  if (nav) try(ev("window.__cb.end()"), silent = TRUE) else ev("window.__cb.end()")
  t_end <- now_ms()
  # The work the page leaves behind (a large message, a backend that loads in the background) belongs to
  # it: wait until both are quiet again, and count the websocket traffic up to then.
  q <- if (tour) list(quiet_from_ms = NA_real_) else wait_quiet(mem_csv)
  quiet_now <<- !tour
  t_quiet <- now_ms()
  if (nav) {
    if (!isTRUE(ev("!!window.__cbws"))) stop("the websocket counter (ws.js) is not in the page")
    probe_gpu()
  }
  trail <- if (is.na(q$quiet_from_ms)) NA_real_ else max(0, q$quiet_from_ms - t_end)
  ws <- tryCatch(fromJSON(ev("window.__cbws ? window.__cbws.read() : '{}'")), error = function(e) list())
  ft <- vapply(st$frames, function(f) f$t, 0)
  sim <- frame_similarity(st$frames)
  vis <- visual_from_similarity(ft, sim, t_start)
  fp <- if (nav) first_plot_from_frames(st$frames, t_start) else list()
  if (nav) {
    fp$click_ms <- st$click_ms; fp$start_plot_ms <- t_start - t_launch + fp$first_plot_ms
    # the page's own event, on the clock of this visit (from the navigation, like its other times)
    if (!is.null(st$page_ready_ms) && !is.null(st$click_ms)) st$page_ready_ms <- st$page_ready_ms + st$click_ms
  }
  # A page that is done but never showed the projection is a result of its own, not a harness error.
  if (nav && identical(st$status, "ok") && is.na(fp$first_plot_ms)) st$status <- "no_plot"
  # PERF_DUMP_FRAMES=DIR keeps every frame of every observation, to see what changes on screen.
  dump <- Sys.getenv("PERF_DUMP_FRAMES", "")
  if (nzchar(dump) && record) {
    d <- file.path(dump, sprintf("%s-%s-%s-%02d", dataset, name, visit, length(rows) + 1L)); dir.create(d, recursive = TRUE, showWarnings = FALSE)
    for (i in seq_along(st$frames)) writeBin(base64enc::base64decode(st$frames[[i]]$img), file.path(d, sprintf("%03d-%06.0f.png", i, ft[[i]] - t_start)))
    utils::write.table(data.frame(t = ft - t_start, sim = sim), file.path(d, "similarity.tsv"), sep = "\t", row.names = FALSE, quote = FALSE)
  }
  if (!record) return(invisible(NULL))
  message(sprintf("  %-28s %-8s %-10s visual=%6.0f v90=%6.0f first_plot=%6.0f loader=%5.0f trail=%6.0f ws_max=%9.0f frames=%d%s", name, visit, st$status,
                  vis$visual_complete_ms, vis$visual_90_ms, nz(fp$first_plot_ms), nz(st$loader_ms), trail, nz(ws$ws_max_msg_bytes), length(ft),
                  if (nzchar(st$error %||% "")) paste0("  error: ", st$error) else ""))
  add_row(name, visit, st$status, arg = arg, error = if (nzchar(st$error %||% "")) gsub("[\t\r\n]+", " ", st$error) else NA_character_,
          vis = vis, st = st, idle_wait = idle_wait, ft = ft, t_start = t_start, t_end = t_end, t_quiet = t_quiet, trail = trail, ws = ws, fp = fp)
}

gpu <- NA_character_
browser <- tryCatch(b$Browser$getVersion()$product, error = function(e) NA_character_)
if (first_plot_mode) {
  # The hook goes into the page at its creation, so that it is there for every frame of the load.
  invisible(b$Page$addScriptToEvaluateOnNewDocument(source = hook))
  measure("overview", first_plot_visit, timeout_s = 120, nav = TRUE)
  message("renderer: ", gpu, "; ", browser)
  page_open <- FALSE
} else if (length(tour)) {
  invisible(b$Page$navigate(sprintf("http://127.0.0.1:%d/", port)))
  t_nav <- Sys.time()
  repeat {
    tryCatch(ev(hook), error = function(e) NULL)
    ready <- tryCatch(isTRUE(ev("!!(window.__cb && window.Shiny && Shiny.shinyapp && Shiny.shinyapp.isConnected && Shiny.shinyapp.isConnected() && window.__cb.activeTab())")), error = function(e) FALSE)
    if (ready) break
    if (as.numeric(difftime(Sys.time(), t_nav, units = "secs")) > 120) stop("page did not connect")
    Sys.sleep(0.1)
  }
  probe_gpu()
  message("renderer: ", gpu, "; ", browser)
  # The page the Viewer opens on, until it is done; then the visitor reads it, and goes on.
  measure(ev("window.__cb.activeTab()"), "initial", initial = TRUE, timeout_s = 120, record = FALSE)
  Sys.sleep(tour_wait_s)
  open_tabs <- fromJSON(ev("window.__cb.tabs()"))
  for (p in tour) {
    if (!p %in% open_tabs) { add_row(p, "tour", "unavailable"); next }
    measure(p, "tour", tour = TRUE)
    Sys.sleep(tour_think_s)
  }
  page_open <- FALSE
} else {
  invisible(b$Page$navigate(sprintf("http://127.0.0.1:%d/", port)))
  t_nav <- Sys.time()
  repeat {
    tryCatch(ev(hook), error = function(e) NULL)
    ready <- tryCatch(isTRUE(ev("!!(window.__cb && window.Shiny && Shiny.shinyapp && Shiny.shinyapp.isConnected && Shiny.shinyapp.isConnected())")), error = function(e) FALSE)
    if (ready) break
    if (as.numeric(difftime(Sys.time(), t_nav, units = "secs")) > 120) stop("page did not connect")
    Sys.sleep(0.1)
  }
  if (!isTRUE(ev("!!window.__cbws"))) stop("the websocket counter (ws.js) is not in the page")
  probe_gpu()
  message("renderer: ", gpu, "; ", browser)

  measure("loadData", "initial", initial = TRUE, timeout_s = 120, record = identical(page, "loadData"))
  page_open <- !identical(page, "none")
  if (!page %in% c("none", "loadData")) {
    page_open <- page %in% fromJSON(ev("window.__cb.tabs()"))
    if (page_open) measure(page, "cold") else { message("page not present in this dataset: ", page); add_row(page, "cold", "unavailable") }
  }
  # Actions run one after another on the page that is open; one whose page is not open is unavailable.
  known <- fromJSON(ev("window.__cb.actionNames()"))
  for (a in actions) {
    if (!a %in% known) { message("  unknown action: ", a); add_row(a, "action", "unavailable"); next }
    if (!page_open || !identical(ev(sprintf("window.__cb.actionPage(%s)", toJSON(a, auto_unbox = TRUE))), page)) {
      add_row(a, "action", "unavailable"); next
    }
    measure(a, "action", action = TRUE)
  }
}
Sys.sleep(1)
file.create(stop_file); sampler$wait(5000)

mem <- read_trace(mem_csv)
if (nrow(mem) < 5) stop("memory sampler produced ", nrow(mem), " samples")
if (!length(rows)) {   # a warm-up
  cat(sprintf("%s r%d: 0 rows, warm-up only\n", dataset, round)); quit(save = "no", status = 0L)
}
df <- do.call(rbind, rows)
peak <- function(col, t0, t1) { if (is.na(t0)) return(NA_real_); w <- mem[[col]][mem$t_ms >= t0 - 250 & mem$t_ms <= t1]; if (length(w)) max(w) / 2^20 else NA_real_ }
# Memory peaks cover the observation and its trail. On Linux the tree's PSS, on Windows its private bytes
# (the sampler writes both into the r_pss / c_pss columns).
df$r_peak_mib <- mapply(peak, "r_pss", df$t_start, df$t_quiet)
df$chrome_peak_mib <- mapply(peak, "c_pss", df$t_start, df$t_quiet)
df$server_busy_ms <- mapply(function(a, z) busy_ms(mem$t_ms, mem$r_cpu, a, z, quiet_thr[["r"]]), df$t_start, df$t_quiet)
df$chrome_busy_ms <- mapply(function(a, z) busy_ms(mem$t_ms, mem$c_cpu, a, z, quiet_thr[["chrome"]]), df$t_start, df$t_quiet)
df$run_peak_r_mib <- max(mem$r_pss) / 2^20
df$run_peak_chrome_mib <- max(mem$c_pss) / 2^20
df$server_start_s <- server_start_s
for (i in seq_len(nrow(df))) if (!is.na(df$t_start[[i]])) {
  message(sprintf("  %-28s %-8s server_busy=%6.0f chrome_busy=%6.0f", df$page[[i]], df$visit[[i]], df$server_busy_ms[[i]], df$chrome_busy_ms[[i]]))
}
utils::write.table(df, out, sep = "\t", row.names = FALSE, quote = FALSE, col.names = !file.exists(out), append = file.exists(out))
cat(sprintf("%s %s r%d: %d rows, R peak %.0f MiB, Chrome peak %.0f MiB\n",
            dataset, page, round, nrow(df), df$run_peak_r_mib[[1L]], df$run_peak_chrome_mib[[1L]]))
