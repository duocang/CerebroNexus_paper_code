#!/usr/bin/env Rscript
# Viewer performance standard: measure a candidate against a baseline and record the run.
# Rules: ../STANDARD.md. Linux or WSL only.
#
#   Rscript run.R --tier l0|l1|l2 --candidate REF [--baseline REF|auto] [--cerebro-repo DIR]
#                 [--record] [--track] [--fetch] [--rounds N] [--fixtures demo|auto]
#                 [--out DIR] [--allow-same] [--keep-going]
# Exit code: 0 pass, 1 regression (FAIL), 2 invalid evidence or setup error.
args_all <- commandArgs(trailingOnly = FALSE)
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", args_all, value = TRUE)[[1L]])))
source(file.path(here, "cli.R"))
source(file.path(here, "lib.R"))
# An R error must not look like a regression: exit code 1 is FAIL, 2 is "no valid result".
options(error = function() { traceback(2); quit(save = "no", status = 2L) })
opt <- parse_cli(commandArgs(trailingOnly = TRUE))

die <- function(...) { message("ERROR: ", ...); quit(save = "no", status = 2L) }
sh <- function(cmd, args, ...) system2(cmd, args, stdout = TRUE, stderr = FALSE, ...)
topic <- dirname(here)
paper_repo <- normalizePath(file.path(topic, "..", ".."))

tier <- if (is.null(opt$tier)) die("--tier is required (l0, l1 or l2)") else opt$tier
policy <- read_policy(file.path(here, "policy.tsv"))
pol <- policy[[tier]]
if (is.null(pol)) die("unknown tier: ", tier)
if (isTRUE(opt$record) && identical(pol$calibrated_by, "-")) {
  die("tier ", tier, " has no A/A calibration (calibrated_by in policy.tsv); run an A/A with --allow-same, check it with calibrate.R, then record the run id")
}
if (!is.null(opt$rounds)) pol$rounds <- as.integer(opt$rounds)
if (!is.null(opt$fixtures)) pol$fixtures <- opt$fixtures

cache <- Sys.getenv("PERF_CACHE", file.path(Sys.getenv("XDG_CACHE_HOME", file.path(Sys.getenv("HOME"), ".cache")), "cerebronexus-viewer-perf"))
dir.create(cache, recursive = TRUE, showWarnings = FALSE)
repo <- normalizePath(Sys.getenv("CEREBRO_REPO", if (!is.null(opt$cerebro_repo)) opt$cerebro_repo else file.path(paper_repo, "..", "CerebroNexus")), mustWork = FALSE)
if (!dir.exists(file.path(repo, ".git")) && !file.exists(file.path(repo, ".git"))) die("not a CerebroNexus checkout: ", repo, " (use --cerebro-repo)")
git <- function(...) sh("git", c("-C", repo, ...))
index_path <- file.path(topic, "runs", "INDEX.tsv")

# ---- platform and lock -------------------------------------------------------------------------
if (!file.exists("/proc/version")) die("Linux or WSL is required (see STANDARD.md, Platform)")
platform <- if (grepl("microsoft", paste(readLines("/proc/version", warn = FALSE), collapse = " "), ignore.case = TRUE)) "linux-wsl" else "linux"
lock <- file.path(cache, "run.lock")
if (!dir.create(lock, showWarnings = FALSE)) {
  other <- tryCatch(readLines(file.path(lock, "pid"), warn = FALSE)[[1L]], error = function(e) "")
  if (nzchar(other) && dir.exists(file.path("/proc", other))) die("another performance run is active (pid ", other, "); only one at a time")
  unlink(lock, recursive = TRUE); dir.create(lock)
}
writeLines(as.character(Sys.getpid()), file.path(lock, "pid"))
on.exit(unlink(lock, recursive = TRUE), add = TRUE)
stray <- Filter(function(p) {
  cl <- tryCatch(readBin(file.path("/proc", p, "cmdline"), "raw", 65536L), error = function(e) raw())
  grepl("measure_session[.]R|remote-debugging-port", rawToChar(replace(cl, cl == as.raw(0L), as.raw(32L))))
}, setdiff(list.files("/proc", "^[0-9]+$"), as.character(Sys.getpid())))
if (length(stray)) die("benchmark or browser automation processes already running: ", paste(stray, collapse = ", "))

# ---- revisions ---------------------------------------------------------------------------------
if (isTRUE(opt$fetch) || isTRUE(opt$track)) invisible(git("fetch", "--quiet", "origin"))
resolve <- function(ref) {
  sha <- tryCatch(git("rev-parse", "--verify", "--quiet", paste0(ref, "^{commit}")), warning = function(w) character(), error = function(e) character())
  if (!length(sha)) die("cannot resolve revision: ", ref)
  sha[[1L]]
}
candidate_ref <- if (!is.null(opt$candidate)) opt$candidate else if (isTRUE(opt$track)) "origin/master" else die("--candidate is required")
candidate_sha <- resolve(candidate_ref)
baseline_ref <- if (is.null(opt$baseline)) "auto" else opt$baseline
if (identical(baseline_ref, "auto")) {
  baseline_sha <- last_recorded_sha(index_path, tier)
  if (is.na(baseline_sha)) die("no earlier ", tier, " run is recorded; give --baseline REF")
  baseline_ref <- substr(baseline_sha, 1L, 12L)
} else baseline_sha <- resolve(baseline_ref)
if (isTRUE(opt$track) && identical(candidate_sha, last_recorded_sha(index_path, tier))) {
  cat("up to date: ", candidate_ref, " (", substr(candidate_sha, 1L, 12L), ") is already the newest recorded ", tier, " run\n", sep = ""); quit(save = "no", status = 0L)
}
if (identical(candidate_sha, baseline_sha) && !isTRUE(opt$allow_same)) die("candidate and baseline are the same commit (--allow-same for a noise check)")
cands <- list(base = list(ref = baseline_ref, sha = baseline_sha), cand = list(ref = candidate_ref, sha = candidate_sha))

# ---- candidates: sources and installed libraries ------------------------------------------------
for (k in names(cands)) {
  s12 <- substr(cands[[k]]$sha, 1L, 12L)
  src <- file.path(cache, "src", s12); lib <- file.path(cache, "lib", s12)
  if (!dir.exists(file.path(src, "inst"))) {
    dir.create(src, recursive = TRUE, showWarnings = FALSE)
    rc <- system(sprintf("git -C %s archive %s | tar -x -C %s", shQuote(repo), cands[[k]]$sha, shQuote(src)))
    if (rc != 0L) die("git archive failed for ", cands[[k]]$sha)
  }
  if (!dir.exists(file.path(lib, "CerebroNexus"))) {
    dir.create(lib, recursive = TRUE, showWarnings = FALSE)
    message("installing ", s12, " ...")
    install_log <- file.path(cache, paste0("install-", s12, ".log"))
    rc <- system2("R", c("CMD", "INSTALL", "--no-docs", "--no-multiarch", paste0("--library=", lib), src), stdout = install_log, stderr = install_log)
    if (rc != 0L) { unlink(file.path(lib, "CerebroNexus"), recursive = TRUE); die("R CMD INSTALL failed for ", s12, "; see ", install_log) }
  }
  cands[[k]]$src <- src; cands[[k]]$lib <- lib
}
demos_available <- Reduce(intersect, lapply(cands, function(x) sub("\\.crb$", "", list.files(file.path(x$src, "inst", "extdata", "examples"), "\\.crb$"))))
# ---- what is measured where ----------------------------------------------------------------------
# Each page is measured once, on the dataset coverage.tsv assigns to it. Large fixtures (fixtures.tsv) are
# one prepared CRB that both revisions open, so both must read its format: compare revisions of the same
# CRB format era. A page whose large fixture is absent runs on its demo CRB instead.
fixtures <- read_fixtures(file.path(here, "fixtures.tsv"))
large_paths <- if (identical(pol$fixtures, "auto")) fixture_paths(fixtures) else character()
plan <- build_plan(read_coverage(file.path(here, "coverage.tsv")), pol$fixtures, names(large_paths), demos_available)
plan <- add_actions(plan, read_actions(file.path(here, "actions.tsv")))
uncovered <- attr(plan, "uncovered")
if (!nrow(plan)) die("no page can be measured: no dataset exists in both revisions")
datasets <- unique(plan$dataset)
crb_path <- function(label, dataset) if (dataset %in% names(large_paths)) large_paths[[dataset]] else file.path(cands[[label]]$src, "inst", "extdata", "examples", paste0(dataset, ".crb"))
message("plan: ", paste(sprintf("%s=%s", plan$page, plan$dataset), collapse = ", "))
if (length(uncovered)) message("no dataset for: ", paste(uncovered, collapse = ", "))

# ---- run directory and noise canary -------------------------------------------------------------
utc <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
run_id <- sprintf("%s-%s-%s-%s", utc, substr(candidate_sha, 1L, 12L), tier, platform)
out_root <- if (!is.null(opt$out)) opt$out else if (isTRUE(opt$record)) file.path(topic, "runs") else file.path(cache, "runs")
run_dir <- file.path(out_root, run_id)
dir.create(file.path(run_dir, "logs"), recursive = TRUE)
raw_path <- file.path(run_dir, "raw.tsv")

canary <- function() {
  t <- vapply(1:7, function(i) system.time({ x <- 0; for (j in 1:3e6) x <- x + sqrt(j) })[["elapsed"]], 0)
  stats::median(t) * 1000
}
canary_before <- canary(); load_before <- as.numeric(strsplit(readLines("/proc/loadavg", warn = FALSE), " ")[[1L]][[1L]])

# ---- schedule: base and candidate alternate; the order flips each round and dataset ----------------
sched <- do.call(rbind, lapply(seq_len(pol$rounds), function(r) do.call(rbind, lapply(seq_along(datasets), function(i) {
  ord <- if ((r + i) %% 2L == 1L) c("base", "cand") else c("cand", "base")
  data.frame(round = r, dataset = datasets[[i]], label = ord, pages = paste(plan$page[plan$dataset == datasets[[i]]], collapse = ","), stringsAsFactors = FALSE)
}))))
sched$position <- seq_len(nrow(sched))
utils::write.table(sched, file.path(run_dir, "schedule.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
utils::write.table(plan, file.path(run_dir, "plan.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)

session <- function(row, attempt, out = raw_path, pages = row$pages, tag = sprintf("%03d", row$position)) {
  x <- cands[[row$label]]
  log <- file.path(run_dir, "logs", sprintf("%s-%s-%s-r%d-a%d.log", tag, row$label, row$dataset, row$round, attempt))
  port <- 20000L + (if (identical(tag, "warm")) 900L else row$position * 3L) + attempt
  rc <- system2("Rscript", c("--no-save", "--no-restore", file.path(here, "measure_session.R"), "--label", row$label, "--sha", x$sha,
                              "--lib", x$lib, "--crb", crb_path(row$label, row$dataset),
                              "--port", port, "--round", row$round, "--out", out, "--dataset", row$dataset, "--pages", pages),
                stdout = log, stderr = log, timeout = 3600)
  rc == 0L && any(grepl("rows,", readLines(log, warn = FALSE), fixed = TRUE))
}
t_start <- Sys.time()
failed <- 0L
# Warm-up: the first read of a large fixture's H5 comes from disk, the rest from the page cache. One
# discarded session per large fixture, so that no measured session pays for it.
for (d in intersect(datasets, names(large_paths))) {
  message("warm-up: ", d)
  invisible(session(data.frame(label = "cand", dataset = d, round = 0L, position = 0L, stringsAsFactors = FALSE), 1L,
                    out = tempfile(fileext = ".tsv"), pages = "none", tag = "warm"))
}
for (i in seq_len(nrow(sched))) {
  row <- sched[i, ]
  message(sprintf("[%d/%d] %s %s round %d (%s)", i, nrow(sched), row$label, row$dataset, row$round, row$pages))
  ok <- session(row, 1L) || { Sys.sleep(5); session(row, 2L) }
  if (!ok) { failed <- failed + 1L; message("  session failed twice; see logs/") }
}
# Server steps (server_steps.R): the same alternation, one fresh R process per revision, dataset and round.
server_path <- file.path(run_dir, "server.tsv")
for (r in seq_len(pol$rounds)) for (i in seq_along(datasets)) {
  for (k in if ((r + i) %% 2L == 1L) c("base", "cand") else c("cand", "base")) {
    message(sprintf("server steps: %s %s round %d", k, datasets[[i]], r))
    log <- file.path(run_dir, "logs", sprintf("server-%s-%s-r%d.log", k, datasets[[i]], r))
    system2("Rscript", c("--no-save", "--no-restore", file.path(here, "server_steps.R"), "--label", k, "--sha", cands[[k]]$sha,
                         "--lib", cands[[k]]$lib, "--src", cands[[k]]$src, "--crb", crb_path(k, datasets[[i]]),
                         "--dataset", datasets[[i]], "--round", r, "--out", server_path),
            stdout = log, stderr = log, timeout = 3600)
  }
}
canary_after <- canary(); load_after <- as.numeric(strsplit(readLines("/proc/loadavg", warn = FALSE), " ")[[1L]][[1L]])

# ---- judge and record ----------------------------------------------------------------------------
raw <- if (file.exists(raw_path)) utils::read.delim(raw_path, stringsAsFactors = FALSE) else NULL
canary_ratio <- max(canary_before, canary_after) / min(canary_before, canary_after)
result <- if (is.null(raw)) list(verdict = "INVALID", invalid = "no observations were recorded", table = NULL, pages = NULL, memory = NULL) else
  judge(raw, pol, "base", "cand", canary_ratio, plan = plan,
        server = if (file.exists(server_path)) utils::read.delim(server_path, stringsAsFactors = FALSE, colClasses = c(hash = "character")) else NULL)
if (failed > 0L && result$verdict != "INVALID") {
  result$verdict <- "INVALID"; result$invalid <- c(result$invalid, sprintf("%d session(s) failed twice", failed))
}
if (!is.null(result$table)) utils::write.table(result$table, file.path(run_dir, "verdict.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)

cmd1 <- function(x) { r <- suppressWarnings(tryCatch(system2(x[[1L]], x[-1L], stdout = TRUE, stderr = FALSE), error = function(e) "")); if (length(r)) r[[1L]] else "" }
chrome_bin <- Sys.which(c("google-chrome", "chromium", "chromium-browser"))
chrome_bin <- chrome_bin[nzchar(chrome_bin)][1L]
paper_sha <- paste0(sh("git", c("-C", paper_repo, "rev-parse", "HEAD")), if (length(sh("git", c("-C", paper_repo, "status", "--porcelain", "--", topic)))) "-dirty" else "")
file_hash <- function(p) strsplit(cmd1(c("sha256sum", p)), " ")[[1L]][[1L]]
ds_hash <- unlist(lapply(names(cands), function(k) vapply(datasets, function(d) file_hash(crb_path(k, d)), "")))
names(ds_hash) <- unlist(lapply(names(cands), function(k) paste0("sha256.", k, ".", datasets)))
for (d in intersect(datasets, names(large_paths))) {   # the big files are identified by size and version stamp, not hashed
  stamp <- file.path(dirname(large_paths[[d]]), "demo-version")
  ds_hash <- c(ds_hash, stats::setNames(c(large_paths[[d]], file.size(sub("[.]crb$", ".h5", large_paths[[d]])),
                                         if (file.exists(stamp)) readLines(stamp, warn = FALSE)[[1L]] else NA),
                                       paste0("fixture.", d, c(".crb", ".h5_bytes", ".version_stamp"))))
}
ds_hash <- c(ds_hash, plan_md5 = unname(tools::md5sum(file.path(run_dir, "plan.tsv"))), uncovered_pages = paste(uncovered, collapse = ","))
pkg_versions <- if (!is.null(raw)) tapply(raw$pkg_version, raw$label, function(x) x[[1L]]) else c(base = NA, cand = NA)
manifest <- c(
  run_id = run_id, utc = utc, tier = tier, contract = standard_contract, platform = platform,
  candidate_ref = candidate_ref, candidate_sha = candidate_sha, candidate_version = unname(pkg_versions["cand"]),
  baseline_ref = baseline_ref, baseline_sha = baseline_sha, baseline_version = unname(pkg_versions["base"]),
  rounds = pol$rounds, datasets = paste(datasets, collapse = ","), fixtures_mode = pol$fixtures, sessions = nrow(sched), failed_sessions = failed,
  host = Sys.info()[["nodename"]], os = cmd1(c("uname", "-sr")), cpu = sub("^.*: ", "", cmd1(c("sh", "-c", shQuote("grep -m1 'model name' /proc/cpuinfo")))),
  cores = parallel::detectCores(), mem_total_mib = round(as.numeric(sub("[^0-9]*([0-9]+).*", "\\1", cmd1(c("sh", "-c", shQuote("grep -m1 MemTotal /proc/meminfo"))))) / 1024),
  r_version = R.version.string, chrome = if (is.na(chrome_bin)) "unknown" else cmd1(c(chrome_bin, "--version")),
  chromote = as.character(utils::packageVersion("chromote")), harness_commit = paper_sha, cerebro_repo = repo,
  canary_before_ms = round(canary_before, 1), canary_after_ms = round(canary_after, 1), canary_ratio = round(canary_ratio, 3),
  load1_before = load_before, load1_after = load_after,
  started = format(t_start, "%Y-%m-%dT%H:%M:%S%z"), ended = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), verdict = result$verdict,
  unlist(lapply(names(pol), function(n) stats::setNames(as.character(pol[[n]]), paste0("policy.", n)))), ds_hash
)
manifest <- manifest[!duplicated(names(manifest))]
utils::write.table(data.frame(key = names(manifest), value = unname(manifest)), file.path(run_dir, "manifest.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)

info <- list(run_id = run_id, tier = tier, candidate_ref = candidate_ref, candidate_sha = substr(candidate_sha, 1L, 12L),
             baseline_ref = baseline_ref, baseline_sha = substr(baseline_sha, 1L, 12L), rounds = pol$rounds,
             datasets = paste(datasets, collapse = ", "), host = manifest[["host"]], os = manifest[["os"]], r_version = R.version.string, chrome = manifest[["chrome"]],
             plan = plan, uncovered = uncovered)
write_summary(file.path(run_dir, "summary.md"), info, result)

if (isTRUE(opt$record) && result$verdict != "INVALID" && !is.null(raw)) {
  hc <- headline(raw, "cand"); hb <- headline(raw, "base")
  append_index(index_path, list(
    run_id = run_id, utc = utc, tier = tier, platform = platform, candidate_ref = candidate_ref, candidate_sha = candidate_sha,
    baseline_ref = baseline_ref, baseline_sha = baseline_sha, verdict = result$verdict, rounds = pol$rounds, datasets = length(datasets),
    cand_initial_visual_ms = round(hc$initial_visual_ms), cand_first_visual_ms = round(hc$first_visual_ms), cand_repeat_visual_ms = round(hc$repeat_visual_ms),
    base_initial_visual_ms = round(hb$initial_visual_ms), base_first_visual_ms = round(hb$first_visual_ms), base_repeat_visual_ms = round(hb$repeat_visual_ms),
    cand_r_peak_mib = round(hc$r_peak_mib), cand_chrome_peak_mib = round(hc$chrome_peak_mib), unfinished_cells_cand = hc$unfinished_cells,
    path = file.path("runs", run_id)))
  writeLines(run_id, file.path(out_root, paste0("CURRENT_", tier)))
}

cat(sprintf("\nVerdict: %s   (run %s)\n", result$verdict, run_id))
if (length(result$invalid)) cat("Invalid evidence:\n", paste0("  - ", result$invalid, "\n"), sep = "")
fails <- if (!is.null(result$table)) result$table[result$table$verdict == "FAIL", ] else NULL
if (!is.null(fails) && nrow(fails)) print(fails[c("metric", "scope", "visit", "baseline", "candidate", "delta_pct", "rule")], row.names = FALSE)
cat("Summary:", file.path(run_dir, "summary.md"), "\n")
quit(save = "no", status = verdict_exit_code(result$verdict))
