#!/usr/bin/env Rscript
# One measured session: a fresh R server (installed candidate) and a fresh Chrome, one CRB.
# Opens Data info, visits every sidebar page once (first visit), then once more after returning
# to Data info (repeat visit), then performs the in-page actions (hook.js, cb.actions), and appends
# one row per observation to --out.
#
# usage: measure_session.R --label L --sha S --lib DIR --crb FILE --port N --round N --out FILE
#        [--dataset NAME]   Chrome flags: env PERF_CHROME_ARGS (e.g. --no-sandbox)
suppressPackageStartupMessages({
  library(chromote); library(processx); library(jsonlite)
})
for (p in c("png", "base64enc")) if (!requireNamespace(p, quietly = TRUE)) stop("package ", p, " is required")
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[[1L]])))
source(file.path(here, "cli.R"))
source(file.path(here, "lib.R"))
source(file.path(here, "proc.R"))
opt <- parse_cli(commandArgs(trailingOnly = TRUE))
label <- opt$label; sha <- opt$sha; lib <- opt$lib; crb <- opt$crb
port <- as.integer(opt$port); round <- as.integer(opt$round); out <- opt$out
dataset <- if (!is.null(opt$dataset)) opt$dataset else sub("\\.crb$", "", basename(crb))
now_ms <- function() as.numeric(Sys.time()) * 1000
contract <- standard_contract
## --pages a,b,c  visit only these pages and actions (default: all pages, no actions); "none" opens
## Data info only (a warm-up). loadData in the list means the Data info load is recorded as well.
pages_wanted <- if (is.null(opt$pages)) NULL else strsplit(opt$pages, ",", fixed = TRUE)[[1L]]
record_initial <- is.null(pages_wanted) || "loadData" %in% pages_wanted

log_file <- tempfile(fileext = ".log")
server <- process$new(
  Sys.which("Rscript"), c("--no-save", "--no-restore", file.path(here, "server.R")),
  env = c("current", PERF_LIB = lib, PERF_CRB = crb, PERF_PORT = port, R_LIBS = lib, R_PROFILE_USER = "/dev/null"),
  stdout = log_file, stderr = "2>&1", cleanup_tree = TRUE
)
stop_file <- tempfile(fileext = ".stop"); mem_csv <- tempfile(fileext = ".csv")
sampler <- NULL
cleanup <- function() {
  try(file.create(stop_file), silent = TRUE)
  try(if (!is.null(sampler)) sampler$wait(3000), silent = TRUE)
  try(server$kill_tree(), silent = TRUE)
}
on.exit(cleanup(), add = TRUE)

t_wait <- Sys.time()
repeat {
  ok <- tryCatch({ con <- socketConnection("127.0.0.1", port, open = "r+", timeout = 1); close(con); TRUE },
                 error = function(e) FALSE, warning = function(w) FALSE)
  if (ok) break
  if (!server$is_alive()) stop("server died:\n", paste(utils::tail(readLines(log_file, warn = FALSE), 25), collapse = "\n"))
  if (as.numeric(difftime(Sys.time(), t_wait, units = "secs")) > 240) stop("server start timeout")
  Sys.sleep(0.2)
}
server_start_s <- as.numeric(difftime(Sys.time(), t_wait, units = "secs"))
info <- grep("^PERF_INFO", readLines(log_file, warn = FALSE), value = TRUE)
pkg_version <- if (length(info)) sub(" path=.*", "", sub("^PERF_INFO version=", "", info[[1L]])) else NA_character_

chrome_args <- chromote::default_chrome_args()
extra <- Sys.getenv("PERF_CHROME_ARGS", "")
if (nzchar(extra)) chrome_args <- c(chrome_args, strsplit(extra, " ", fixed = TRUE)[[1L]])
br <- Chrome$new(args = chrome_args)
chrome_pid <- br$get_process()$get_pid()
cm <- Chromote$new(browser = br)
b <- ChromoteSession$new(parent = cm)
on.exit({ try(b$close(), silent = TRUE); try(cm$close(), silent = TRUE); try(br$close(), silent = TRUE) }, add = TRUE)
invisible(b$Emulation$setDeviceMetricsOverride(width = 1619, height = 950, deviceScaleFactor = 1, mobile = FALSE))

sampler <- process$new(Sys.which("Rscript"), c("--no-save", "--no-restore", file.path(here, "sampler.R"),
                                               server$get_pid(), chrome_pid, mem_csv, stop_file), cleanup_tree = TRUE)

ev <- function(expr) {
  r <- b$Runtime$evaluate(expr, returnByValue = TRUE, awaitPromise = FALSE)
  if (!is.null(r$exceptionDetails)) stop("JS error: ", r$exceptionDetails$text, " ", r$exceptionDetails$exception$description)
  r$result$value
}
hook <- paste(readLines(file.path(here, "hook.js"), warn = FALSE), collapse = "\n")
nz <- function(x) if (is.null(x)) NA_real_ else x

js_peak <- 0
viewport <- list(x = 0, y = 0, width = 1619, height = 950, scale = 0.25)
shot <- function() b$Page$captureScreenshot(format = "png", clip = viewport, optimizeForSpeed = TRUE)$data

# Frames are captured back to back while waiting; the page-side hook decides when to stop.
wait_done <- function(timeout_s, capture = TRUE) {
  t0 <- Sys.time(); frames <- list()
  repeat {
    t_a <- now_ms()
    st <- fromJSON(ev("window.__cb.state()"))
    h <- tryCatch(b$Runtime$getHeapUsage()$usedSize, error = function(e) NA_real_)
    if (!is.na(h) && h > js_peak) js_peak <<- h
    if (capture) frames[[length(frames) + 1L]] <- list(t = (t_a + now_ms()) / 2, img = shot())
    if (isTRUE(st$done)) {
      st$status <- if (nzchar(st$error %||% "")) "error" else if (isTRUE(st$stuck)) "stuck_busy" else "ok"
      st$frames <- frames; return(st)
    }
    if (as.numeric(difftime(Sys.time(), t0, units = "secs")) > timeout_s) { st$status <- "timeout"; st$frames <- frames; return(st) }
    if (!capture) Sys.sleep(0.04)
  }
}

# Pixel similarity of every frame to the last one (share of identical pixels).
frame_similarity <- function(frames) {
  mats <- lapply(frames, function(f) png::readPNG(base64enc::base64decode(f$img)))
  fin <- mats[[length(mats)]]
  vapply(mats, function(m) {
    d <- abs(m - fin) > 1e-6
    1 - mean(d[, , 1L] | d[, , 2L] | d[, , 3L])
  }, 0)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

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
                    ft = numeric(), t_start = NA_real_, t_end = NA_real_) {
  rows[[length(rows) + 1L]] <<- data.frame(
    contract = contract, label = label, sha = sha, pkg_version = pkg_version, dataset = dataset, round = round,
    page = page, visit = visit, status = status, arg = arg, error = error,
    visual_complete_ms = vis$visual_complete_ms %||% NA_real_, visual_90_ms = vis$visual_90_ms %||% NA_real_, settled_ms = nz(st$settled_ms),
    loader_visible_ms = nz(st$loader_ms), visible_ms = nz(st$visible_ms), js_peak_mib = if (is.null(vis)) NA_real_ else js_peak / 2^20,
    idle_wait_s = idle_wait, frames = length(ft), frame_ms = if (length(ft) > 1L) stats::median(diff(ft)) else NA_real_,
    t_start = t_start, t_end = t_end, stringsAsFactors = FALSE
  )
}

measure <- function(page, visit, initial = FALSE, timeout_s = 90, record = TRUE, action = FALSE) {
  js_peak <<- 0
  arg <- NA_character_
  if (action) {
    arg <- prepare_action(page)
    if (is.null(arg)) {
      message(sprintf("  %-20s %-8s unavailable", page, visit))
      return(add_row(page, visit, "unavailable"))
    }
  }
  # Start from a quiet server; the wait is not part of the measurement.
  idle_wait <- if (initial) NA_real_ else wait_tree_idle(server$get_pid())
  t_start <- now_ms()
  if (action) ev(sprintf("window.__cb.actionBegin(%s, %s)", toJSON(page, auto_unbox = TRUE), toJSON(arg, auto_unbox = TRUE)))
  else ev(sprintf("window.__cb.begin(%s, %s)", toJSON(page, auto_unbox = TRUE), if (initial) "true" else "false"))
  st <- wait_done(timeout_s)
  ev("window.__cb.end()")
  t_end <- now_ms()
  ft <- vapply(st$frames, function(f) f$t, 0)
  vis <- visual_from_similarity(ft, frame_similarity(st$frames), t_start)
  if (!record) return(invisible(NULL))
  message(sprintf("  %-20s %-8s %-10s visual=%6.0f v90=%6.0f loader=%5.0f settled=%6.0f frames=%d%s", page, visit, st$status,
                  vis$visual_complete_ms, vis$visual_90_ms, nz(st$loader_ms), nz(st$settled_ms), length(ft),
                  if (nzchar(st$error %||% "")) paste0("  error: ", st$error) else ""))
  add_row(page, visit, st$status, arg = arg, error = if (nzchar(st$error %||% "")) gsub("[	
]+", " ", st$error) else NA_character_,
          vis = vis, st = st, idle_wait = idle_wait, ft = ft, t_start = t_start, t_end = t_end)
}

invisible(b$Page$navigate(sprintf("http://127.0.0.1:%d/", port)))
t_nav <- Sys.time()
repeat {
  tryCatch(ev(hook), error = function(e) NULL)
  ready <- tryCatch(isTRUE(ev("!!(window.__cb && window.Shiny && Shiny.shinyapp && Shiny.shinyapp.isConnected && Shiny.shinyapp.isConnected())")), error = function(e) FALSE)
  if (ready) break
  if (as.numeric(difftime(Sys.time(), t_nav, units = "secs")) > 120) stop("page did not connect")
  Sys.sleep(0.1)
}
measure("loadData", "initial", initial = TRUE, timeout_s = 120, record = record_initial)
tabs <- setdiff(fromJSON(ev("window.__cb.tabs()")), "loadData")
action_names <- fromJSON(ev("window.__cb.actionNames()"))
actions <- if (is.null(pages_wanted)) character() else intersect(pages_wanted, action_names)
if (!is.null(pages_wanted)) tabs <- intersect(tabs, pages_wanted)
missing_pages <- setdiff(setdiff(pages_wanted, c("none", "loadData", action_names)), tabs)
if (length(missing_pages)) message("pages not present in this dataset: ", paste(missing_pages, collapse = ", "))
for (visit in c("first", "repeat")) {
  for (tb in tabs) {
    if (visit == "repeat") {
      ev("window.__cb.begin('loadData', false)"); wait_done(60, capture = FALSE); ev("window.__cb.end()")
    }
    measure(tb, visit)
  }
}
# Actions run on their own page, which is opened first (not measured).
for (a in actions) {
  pg <- ev(sprintf("window.__cb.actionPage(%s)", toJSON(a, auto_unbox = TRUE)))
  if (!pg %in% tabs) { add_row(a, "action", "unavailable"); next }
  ev(sprintf("window.__cb.begin(%s, false)", toJSON(pg, auto_unbox = TRUE))); wait_done(60, capture = FALSE); ev("window.__cb.end()")
  measure(a, "action", action = TRUE)
}
Sys.sleep(1)
file.create(stop_file); sampler$wait(5000)

mem <- utils::read.csv(mem_csv)
if (nrow(mem) < 5) stop("memory sampler produced ", nrow(mem), " samples")
if (!length(rows)) {   # a warm-up or a dataset without any of the requested pages
  cat(sprintf("%s %s r%d: 0 rows, warm-up only
", label, dataset, round)); quit(save = "no", status = 0L)
}
df <- do.call(rbind, rows)
peak <- function(col, t0, t1) { if (is.na(t0)) return(NA_real_); w <- mem[[col]][mem$t_ms >= t0 - 250 & mem$t_ms <= t1]; if (length(w)) max(w) / 2^20 else NA_real_ }
df$r_peak_pss_mib <- mapply(peak, "r_pss", df$t_start, df$t_end)
df$chrome_peak_pss_mib <- mapply(peak, "c_pss", df$t_start, df$t_end)
df$r_peak_rss_mib <- mapply(peak, "r_rss", df$t_start, df$t_end)
df$chrome_peak_rss_mib <- mapply(peak, "c_rss", df$t_start, df$t_end)
df$run_peak_r_pss_mib <- max(mem$r_pss) / 2^20
df$run_peak_chrome_pss_mib <- max(mem$c_pss) / 2^20
df$run_peak_r_rss_mib <- max(mem$r_rss) / 2^20
df$run_peak_chrome_rss_mib <- max(mem$c_rss) / 2^20
df$server_start_s <- server_start_s
utils::write.table(df, out, sep = "\t", row.names = FALSE, quote = FALSE, col.names = !file.exists(out), append = file.exists(out))
cat(sprintf("%s %s r%d: %d rows, initial visual %.0f ms, R peak %.0f MiB (PSS), Chrome peak %.0f MiB (PSS)\n",
            label, dataset, round, nrow(df), df$visual_complete_ms[[1L]], df$run_peak_r_pss_mib[[1L]], df$run_peak_chrome_pss_mib[[1L]]))
