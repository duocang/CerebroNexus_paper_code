#!/usr/bin/env Rscript
# GPU tier of the Viewer performance standard (STANDARD.md, section 4): the point renderer
# (inst/viewer/www/cell_points_gpu.js) of two revisions, drawing the same synthetic points in Chrome
# with the machine's GPU. Windows, because WSL has no usable GPU for Chrome. Reported, not judged.
#
#   Rscript run.R --candidate REF --baseline REF [--cerebro-repo DIR] [--rounds 5] [--points 1000000]
#                 [--repeats 15] [--record]
# Exit code: 0 done, 2 invalid (no WebGPU, a lost context, a renderer error) or setup error.
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[[1L]])))
source(file.path(here, "..", "cli.R"))
opt <- parse_cli(commandArgs(trailingOnly = TRUE))
die <- function(...) { message("ERROR: ", ...); quit(save = "no", status = 2L) }
suppressPackageStartupMessages({ library(chromote); library(httpuv); library(jsonlite) })

topic <- normalizePath(file.path(here, "..", ".."))
paper_repo <- normalizePath(file.path(topic, "..", ".."))
repo <- normalizePath(Sys.getenv("CEREBRO_REPO", if (!is.null(opt$cerebro_repo)) opt$cerebro_repo else file.path(paper_repo, "..", "CerebroNexus")), mustWork = FALSE)
git <- function(...) suppressWarnings(system2("git", c("-C", repo, ...), stdout = TRUE, stderr = FALSE))
rounds <- as.integer(if (is.null(opt$rounds)) 5L else opt$rounds)
points <- as.integer(if (is.null(opt$points)) 1000000L else opt$points)
repeats <- as.integer(if (is.null(opt$repeats)) 15L else opt$repeats)
if (is.null(opt$candidate) || is.null(opt$baseline)) die("--candidate and --baseline are required")

# One folder per revision with its renderer; the page is the same for both.
site <- tempfile("gpu-site-"); dir.create(site)
invisible(file.copy(file.path(here, "bench.js"), site))
revs <- list(base = list(ref = opt$baseline), cand = list(ref = opt$candidate))
for (k in names(revs)) {
  sha <- git("rev-parse", "--verify", "--quiet", paste0(revs[[k]]$ref, "^{commit}"))
  if (!length(sha)) die("cannot resolve revision: ", revs[[k]]$ref)
  revs[[k]]$sha <- sha[[1L]]
  js <- git("show", paste0(sha[[1L]], ":inst/viewer/www/cell_points_gpu.js"))
  if (!length(js)) die(revs[[k]]$ref, " has no inst/viewer/www/cell_points_gpu.js")
  dir.create(file.path(site, k))
  writeLines(js, file.path(site, k, "cell_points_gpu.js"))
  writeLines(c("<!doctype html><html><body style='margin:0'>",
               "<canvas id='benchmark-canvas' style='display:block;width:1280px;height:720px'></canvas>",
               sprintf("<script src='/%s/cell_points_gpu.js'></script><script src='/bench.js'></script>", k),
               "</body></html>"), file.path(site, paste0(k, ".html")))
}
port <- httpuv::randomPort()
srv <- httpuv::startServer("127.0.0.1", port, list(staticPaths = list("/" = site)))
on.exit(httpuv::stopServer(srv), add = TRUE)

# A fresh Chrome per measurement, with the GPU enabled (chromote turns it off by default).
chrome_args <- c(setdiff(chromote::default_chrome_args(), "--disable-gpu"), "--enable-unsafe-webgpu", "--ignore-gpu-blocklist")
if (.Platform$OS.type != "windows") chrome_args <- c(chrome_args, "--use-gl=angle", "--use-angle=gl")
measure <- function(k, round) {
  br <- Chrome$new(args = chrome_args)
  cm <- Chromote$new(browser = br)
  b <- ChromoteSession$new(parent = cm, width = 1400, height = 900)
  on.exit({ try(b$close(), silent = TRUE); try(cm$close(), silent = TRUE); try(br$close(), silent = TRUE) })
  if (identical(chrome_version, "unknown")) chrome_version <<- b$Browser$getVersion()$product
  loaded <- b$Page$loadEventFired(wait_ = FALSE)
  b$Page$navigate(sprintf("http://127.0.0.1:%d/%s.html", port, k), wait_ = FALSE)
  b$wait_for(loaded)
  r <- b$Runtime$evaluate(sprintf("runMillionCellBenchmark({count:%d,repeats:%d}).then(r=>JSON.stringify(r))", points, repeats),
                          awaitPromise = TRUE, returnByValue = TRUE, timeout_ = 300)
  if (!is.null(r$exceptionDetails)) {
    return(data.frame(label = k, round = round, status = "error", error = r$exceptionDetails$exception$description %||% r$exceptionDetails$text, stringsAsFactors = FALSE))
  }
  x <- fromJSON(r$result$value)
  x$userAgent <- NULL
  cbind(data.frame(label = k, round = round, status = "ok", error = "", stringsAsFactors = FALSE), as.data.frame(x, stringsAsFactors = FALSE))
}
`%||%` <- function(a, b) if (is.null(a)) b else a
chrome_version <- "unknown"

rows <- list()
for (r in seq_len(rounds)) for (k in if (r %% 2L) c("base", "cand") else c("cand", "base")) {
  message(sprintf("round %d: %s", r, k))
  rows[[length(rows) + 1L]] <- measure(k, r)
}
cols <- unique(unlist(lapply(rows, names)))
raw <- do.call(rbind, lapply(rows, function(d) { d[setdiff(cols, names(d))] <- NA; d[cols] }))

metrics <- c(initializeMs = "renderer start", categoricalBuildMs = "build colours (groups)", uploadMs = "upload to GPU",
             firstFrameMs = "first frame", panZoomMedianMs = "pan/zoom frame, median", panZoomP95Ms = "pan/zoom frame, p95",
             rgbBuildMs = "build colours (RGB)", rgbUploadMs = "upload RGB", rgbMedianMs = "RGB frame, median", rgbP95Ms = "RGB frame, p95")
invalid <- character()
if (any(raw$status != "ok")) invalid <- c(invalid, paste("renderer error:", unique(raw$error[raw$status != "ok"])))
if (!all(raw$backend[raw$status == "ok"] == "webgpu")) invalid <- c(invalid, sprintf("backend was %s, not webgpu (no GPU?)", paste(unique(raw$backend), collapse = ",")))
if (any(as.logical(raw$contextLost), na.rm = TRUE)) invalid <- c(invalid, "GPU context lost")
verdict <- if (length(invalid)) "INVALID" else "REPORT"

ok <- raw[raw$status == "ok", ]
medof <- function(k, m) { v <- as.numeric(ok[[m]][ok$label == k]); if (length(v)) stats::median(v) else NA_real_ }
tab <- data.frame(metric = names(metrics), what = unname(metrics),
                  baseline = vapply(names(metrics), function(m) medof("base", m), 0),
                  candidate = vapply(names(metrics), function(m) medof("cand", m), 0), stringsAsFactors = FALSE)
tab$change_pct <- round((tab$candidate / tab$baseline - 1) * 100, 1)

utc <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
run_id <- sprintf("%s-%s-gpu-windows", utc, substr(revs$cand$sha, 1L, 12L))
out_root <- if (isTRUE(opt$record)) file.path(topic, "runs", "gpu") else file.path(Sys.getenv("PERF_CACHE", file.path(path.expand("~"), ".cache", "cerebronexus-viewer-perf")), "runs", "gpu")
run_dir <- file.path(out_root, run_id); dir.create(run_dir, recursive = TRUE)
utils::write.table(raw, file.path(run_dir, "raw.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
paper_sha <- suppressWarnings(system2("git", c("-C", paper_repo, "rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE))
manifest <- c(run_id = run_id, utc = utc, tier = "gpu", platform = "windows", candidate_ref = revs$cand$ref, candidate_sha = revs$cand$sha,
              baseline_ref = revs$base$ref, baseline_sha = revs$base$sha, rounds = rounds, points = points, repeats = repeats,
              adapter = paste(unique(ok$adapter), collapse = ","), chrome = chrome_version, host = Sys.info()[["nodename"]],
              os = utils::osVersion, r_version = R.version.string, harness_commit = paste(paper_sha, collapse = ""), verdict = verdict)
utils::write.table(data.frame(key = names(manifest), value = unname(manifest)), file.path(run_dir, "manifest.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
f <- function(x) ifelse(is.na(x), "-", formatC(x, format = "f", digits = 1))
writeLines(c(
  sprintf("# GPU renderer run %s", run_id), "",
  sprintf("**%s** (reported, not judged)", verdict), "",
  sprintf("- candidate `%s` (%s), baseline `%s` (%s)", revs$cand$ref, substr(revs$cand$sha, 1L, 12L), revs$base$ref, substr(revs$base$sha, 1L, 12L)),
  sprintf("- %s synthetic points, %d rounds, %d frames per sample; GPU %s; %s", format(points, big.mark = ","), rounds, repeats, manifest[["adapter"]], chrome_version), "",
  if (length(invalid)) c("## Invalid evidence", "", paste0("- ", invalid), "") else character(),
  "| step | baseline ms | candidate ms | change |", "|---|---:|---:|---:|",
  sprintf("| %s | %s | %s | %s |", tab$what, f(tab$baseline), f(tab$candidate), ifelse(is.na(tab$change_pct), "-", sprintf("%+.0f%%", tab$change_pct))), ""
), file.path(run_dir, "summary.md"))
print(tab, row.names = FALSE)
cat(sprintf("\n%s   (run %s)\nSummary: %s\n", verdict, run_id, file.path(run_dir, "summary.md")))
quit(save = "no", status = if (verdict == "INVALID") 2L else 0L)
