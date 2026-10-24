#!/usr/bin/env Rscript
# Viewer performance standard: measure a candidate against a baseline and record the run.
# Rules: ../STANDARD.md. Linux, WSL or Windows.
#
#   Rscript run.R --tier l0|l1|l2 --candidate REF [--baseline REF|auto] [--cerebro-repo DIR]
#                 [--record] [--track] [--fetch] [--rounds N] [--out DIR] [--allow-same]
#                 [--mouse1m CRB] [--ren CRB] [--cosmx CRB]   large datasets (coverage.tsv); demo CRBs otherwise
#   Rscript run.R --tier l0|l1|l2 --candidate REF --solo [--rounds N] [--record] ...
#                 measure only REF and record its times: no baseline, no verdict
#   Rscript run.R ... --pages a,b      only these pages and actions; for checks, never recorded
# Exit code: 0 pass (or recorded with --solo), 1 regression (FAIL), 2 invalid evidence or setup error.
args_all <- commandArgs(trailingOnly = FALSE)
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", args_all, value = TRUE)[[1L]])))
source(file.path(here, "cli.R"))
source(file.path(here, "lib.R"))
source(file.path(here, "proc.R"))
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
solo <- isTRUE(opt$solo)
if (solo && (!is.null(opt$baseline) || isTRUE(opt$track))) die("--solo measures one revision: no --baseline and no --track")
# A solo run judges nothing, so it needs no calibrated thresholds to be recorded.
if (isTRUE(opt$record) && !solo && identical(pol$calibrated_by, "-")) {
  die("tier ", tier, " has no A/A calibration (calibrated_by in policy.tsv); run an A/A with --allow-same, check it with calibrate.R, then record the run id")
}
if (!is.null(opt$rounds)) pol$rounds <- as.integer(opt$rounds)

# Large datasets are given on the command line, one option per name in coverage.tsv (--mouse1m FILE, ...).
coverage <- read_coverage(file.path(here, "coverage.tsv"))
large_names <- setdiff(unique(coverage$fixture), "-")
known <- c("tier", "candidate", "baseline", "cerebro_repo", "record", "track", "fetch", "rounds", "out", "allow_same", "solo", "pages", large_names)
if (length(unknown <- setdiff(names(opt), known))) die("unknown option: --", paste(gsub("_", "-", unknown), collapse = ", --"))
large_paths <- unlist(lapply(stats::setNames(large_names, large_names), function(n) opt[[n]]))
if (is.null(large_paths)) large_paths <- character()
for (n in names(large_paths)) if (!file.exists(large_paths[[n]])) die("--", n, ": no such file: ", large_paths[[n]])
large_paths <- vapply(large_paths, normalizePath, "")

cache <- Sys.getenv("PERF_CACHE", default_cache())
dir.create(cache, recursive = TRUE, showWarnings = FALSE)
repo <- normalizePath(Sys.getenv("CEREBRO_REPO", if (!is.null(opt$cerebro_repo)) opt$cerebro_repo else file.path(paper_repo, "..", "CerebroNexus")), mustWork = FALSE)
if (!dir.exists(file.path(repo, ".git")) && !file.exists(file.path(repo, ".git"))) die("not a CerebroNexus checkout: ", repo, " (use --cerebro-repo)")
git <- function(...) sh("git", c("-C", repo, ...))
index_path <- file.path(topic, "runs", "INDEX.tsv")

# ---- platform and lock -------------------------------------------------------------------------
platform <- platform_name()
if (is.na(platform)) die("Linux, WSL or Windows is required (see STANDARD.md, Platform)")
lock <- file.path(cache, "run.lock")
if (!dir.create(lock, showWarnings = FALSE)) {
  other <- tryCatch(readLines(file.path(lock, "pid"), warn = FALSE)[[1L]], error = function(e) "")
  if (nzchar(other) && pid_alive(other)) die("another performance run is active (pid ", other, "); only one at a time")
  unlink(lock, recursive = TRUE); dir.create(lock)
}
writeLines(as.character(Sys.getpid()), file.path(lock, "pid"))
# on.exit does not run at the top level of a script; a finalizer at exit does, also after quit().
reg.finalizer(globalenv(), function(e) unlink(lock, recursive = TRUE), onexit = TRUE)
stray <- stray_processes()
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
baseline_ref <- if (solo) "-" else if (is.null(opt$baseline)) "auto" else opt$baseline
if (solo) {
  baseline_sha <- "-"
} else if (identical(baseline_ref, "auto")) {
  baseline_sha <- last_recorded_sha(index_path, tier)
  if (is.na(baseline_sha)) die("no earlier ", tier, " run is recorded; give --baseline REF")
  baseline_ref <- substr(baseline_sha, 1L, 12L)
} else baseline_sha <- resolve(baseline_ref)
if (isTRUE(opt$track) && identical(candidate_sha, last_recorded_sha(index_path, tier))) {
  cat("up to date: ", candidate_ref, " (", substr(candidate_sha, 1L, 12L), ") is already the newest recorded ", tier, " run\n", sep = ""); quit(save = "no", status = 0L)
}
if (identical(candidate_sha, baseline_sha) && !isTRUE(opt$allow_same)) die("candidate and baseline are the same commit (--allow-same for a noise check)")
cands <- list(base = list(ref = baseline_ref, sha = baseline_sha), cand = list(ref = candidate_ref, sha = candidate_sha))
if (solo) cands$base <- NULL
# The labels measured in round r on dataset i: base and candidate alternate, the order flipping each time.
labels_at <- function(r, i) if (solo) "cand" else if ((r + i) %% 2L == 1L) c("base", "cand") else c("cand", "base")

# ---- candidates: sources and installed libraries ------------------------------------------------
for (k in names(cands)) {
  s12 <- substr(cands[[k]]$sha, 1L, 12L)
  src <- file.path(cache, "src", s12); lib <- file.path(cache, "lib", s12)
  if (!dir.exists(file.path(src, "inst"))) {
    dir.create(src, recursive = TRUE, showWarnings = FALSE)
    tarball <- tempfile(fileext = ".tar")
    rc <- system2("git", c("-C", repo, "archive", "--format=tar", "-o", tarball, cands[[k]]$sha))
    if (rc != 0L) die("git archive failed for ", cands[[k]]$sha)
    utils::untar(tarball, exdir = src, tar = "internal"); unlink(tarball)
  }
  if (!dir.exists(file.path(lib, "CerebroNexus"))) {
    dir.create(lib, recursive = TRUE, showWarnings = FALSE)
    message("installing ", s12, " ...")
    install_log <- file.path(cache, paste0("install-", s12, ".log"))
    rc <- system2(r_bin("R"), c("CMD", "INSTALL", "--no-docs", "--no-multiarch", paste0("--library=", lib), src), stdout = install_log, stderr = install_log)
    if (rc != 0L) { unlink(file.path(lib, "CerebroNexus"), recursive = TRUE); die("R CMD INSTALL failed for ", s12, "; see ", install_log) }
  }
  cands[[k]]$src <- src; cands[[k]]$lib <- lib
}
demos_available <- Reduce(intersect, lapply(cands, function(x) sub("\\.crb$", "", list.files(file.path(x$src, "inst", "extdata", "examples"), "\\.crb$"))))
# ---- what is measured where ----------------------------------------------------------------------
# Each page is measured once, on the dataset coverage.tsv assigns to it. A large dataset is one prepared CRB
# that both revisions open, so both must read its format: compare revisions of the same CRB format era.
# A page whose large dataset was not given runs on its demo CRB instead.
plan <- build_plan(coverage, names(large_paths), demos_available)
plan <- add_actions(plan, read_actions(file.path(here, "actions.tsv")))
# --pages a,b: measure only these pages and actions (a check while working on one page). Such a run is not
# the plan, so it cannot be recorded.
if (!is.null(opt$pages)) {
  if (isTRUE(opt$record)) die("--pages measures part of the plan; it cannot be recorded")
  keep <- strsplit(opt$pages, ",", fixed = TRUE)[[1L]]
  plan <- structure(plan[plan$page %in% keep, , drop = FALSE], uncovered = attr(plan, "uncovered"))
  pol$min_pages <- min(pol$min_pages, nrow(plan))
}
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
canary_before <- canary(); load_before <- load1()

# ---- schedule: base and candidate alternate; the order flips each round, dataset and cold page -------
# Per round and dataset: one journey session per revision (all its pages in sidebar order, then the
# actions), and one cold session per revision and page (that page only, in a fresh server and Chrome).
sched <- do.call(rbind, lapply(seq_len(pol$rounds), function(r) do.call(rbind, lapply(seq_along(datasets), function(i) {
  pages <- plan$page[plan$dataset == datasets[[i]]]
  cold <- pages[!grepl(".", pages, fixed = TRUE) & pages != "loadData"]
  rbind(
    data.frame(round = r, dataset = datasets[[i]], mode = "journey", label = labels_at(r, i), pages = paste(pages, collapse = ","), stringsAsFactors = FALSE),
    do.call(rbind, lapply(seq_along(cold), function(k) {
      data.frame(round = r, dataset = datasets[[i]], mode = "cold", label = labels_at(r, i + k), pages = cold[[k]], stringsAsFactors = FALSE)
    }))
  )
}))))
sched$position <- seq_len(nrow(sched))
utils::write.table(sched, file.path(run_dir, "schedule.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
utils::write.table(plan, file.path(run_dir, "plan.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)

session <- function(row, attempt, out = raw_path, pages = row$pages, tag = sprintf("%03d", row$position)) {
  x <- cands[[row$label]]
  what <- if (identical(row$mode, "cold")) paste0("cold-", pages) else "journey"
  name <- sprintf("%s-%s-%s-%s-r%d-a%d", tag, row$label, row$dataset, what, row$round, attempt)
  log <- file.path(run_dir, "logs", paste0(name, ".log"))
  port <- 20000L + (if (identical(tag, "warm")) 900L else row$position * 3L) + attempt
  # Switching datasets needs a second one in the menu: the revision's small example CRB (another demo
  # when the session's own dataset is that example).
  crb2 <- if (grepl("loadData.switch", pages, fixed = TRUE)) {
    c("--crb2", crb_path(row$label, if (identical(row$dataset, "example")) "demo_trekker" else "example"))
  }
  rc <- system2(r_bin("Rscript"), c("--no-save", "--no-restore", file.path(here, "measure_session.R"), "--label", row$label, "--sha", x$sha,
                              "--lib", x$lib, "--crb", crb_path(row$label, row$dataset), crb2,
                              "--port", port, "--round", row$round, "--out", out, "--dataset", row$dataset, "--pages", pages,
                              "--mode", if (is.null(row$mode)) "journey" else row$mode, "--trace", file.path(run_dir, "logs", paste0(name, "-trace.csv"))),
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
  message(sprintf("[%d/%d] %s %s %s round %d (%s)", i, nrow(sched), row$label, row$dataset, row$mode, row$round, row$pages))
  ok <- session(row, 1L) || { Sys.sleep(5); session(row, 2L) }
  if (!ok) { failed <- failed + 1L; message("  session failed twice; see logs/") }
}
# Server steps (server_steps.R): the same alternation, one fresh R process per revision, dataset and round.
server_path <- file.path(run_dir, "server.tsv")
for (r in seq_len(pol$rounds)) for (i in seq_along(datasets)) {
  for (k in labels_at(r, i)) {
    message(sprintf("server steps: %s %s round %d", k, datasets[[i]], r))
    log <- file.path(run_dir, "logs", sprintf("server-%s-%s-r%d.log", k, datasets[[i]], r))
    system2(r_bin("Rscript"), c("--no-save", "--no-restore", file.path(here, "server_steps.R"), "--label", k, "--sha", cands[[k]]$sha,
                         "--lib", cands[[k]]$lib, "--src", cands[[k]]$src, "--crb", crb_path(k, datasets[[i]]),
                         "--dataset", datasets[[i]], "--round", r, "--out", server_path),
            stdout = log, stderr = log, timeout = 3600)
  }
}
canary_after <- canary(); load_after <- load1()

# ---- judge and record ----------------------------------------------------------------------------
raw <- if (file.exists(raw_path)) utils::read.delim(raw_path, stringsAsFactors = FALSE) else NULL
canary_ratio <- max(canary_before, canary_after) / min(canary_before, canary_after)
server <- if (file.exists(server_path)) utils::read.delim(server_path, stringsAsFactors = FALSE, colClasses = c(hash = "character")) else NULL
result <- if (is.null(raw)) list(verdict = "INVALID", invalid = "no observations were recorded", table = NULL, pages = NULL, memory = NULL) else
  if (solo) record_only(raw, pol, "cand", canary_ratio, server = server) else
  judge(raw, pol, "base", "cand", canary_ratio, plan = plan, server = server)
if (failed > 0L && result$verdict != "INVALID") {
  result$verdict <- "INVALID"; result$invalid <- c(result$invalid, sprintf("%d session(s) failed twice", failed))
}
if (!is.null(result$table)) utils::write.table(result$table, file.path(run_dir, "verdict.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)

cmd1 <- function(x) { r <- suppressWarnings(tryCatch(system2(x[[1L]], x[-1L], stdout = TRUE, stderr = FALSE), error = function(e) "")); if (length(r)) r[[1L]] else "" }
machine <- machine_facts()
# The browser and what drew the pages, as the sessions saw them.
seen <- function(col) if (!is.null(raw) && !is.null(raw[[col]])) paste(sort(unique(stats::na.omit(raw[[col]]))), collapse = " | ") else "unknown"
paper_sha <- paste0(sh("git", c("-C", paper_repo, "rev-parse", "HEAD")), if (length(sh("git", c("-C", paper_repo, "status", "--porcelain", "--", topic)))) "-dirty" else "")
ds_hash <- unlist(lapply(names(cands), function(k) vapply(datasets, function(d) unname(tools::md5sum(crb_path(k, d))), "")))
names(ds_hash) <- unlist(lapply(names(cands), function(k) paste0("md5.", k, ".", datasets)))
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
  rounds = pol$rounds, datasets = paste(datasets, collapse = ","), sessions = nrow(sched), failed_sessions = failed,
  host = Sys.info()[["nodename"]], os = machine$os, cpu = machine$cpu, cores = parallel::detectCores(), mem_total_mib = machine$mem_total_mib,
  gpu = machine$gpu, renderer = seen("gpu"), memory_measure = if (on_windows) "private bytes (Windows has no PSS)" else "PSS",
  r_version = R.version.string, chrome = seen("browser"),
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
             datasets = paste(datasets, collapse = ", "), host = manifest[["host"]], os = manifest[["os"]], r_version = R.version.string, chrome = paste0(manifest[["chrome"]], ", drawn by ", manifest[["renderer"]]),
             plan = plan, uncovered = uncovered)
(if (solo) write_solo_summary else write_summary)(file.path(run_dir, "summary.md"), info, result)

if (isTRUE(opt$record) && result$verdict != "INVALID" && !is.null(raw)) {
  hc <- headline(raw, "cand")
  hb <- if (solo) list(initial_visual_ms = NA, cold_visual_ms = NA, repeat_visual_ms = NA) else headline(raw, "base")
  append_index(index_path, list(
    run_id = run_id, utc = utc, tier = tier, platform = platform, candidate_ref = candidate_ref, candidate_sha = candidate_sha,
    baseline_ref = baseline_ref, baseline_sha = baseline_sha, verdict = result$verdict, rounds = pol$rounds, datasets = length(datasets),
    cand_initial_visual_ms = round(hc$initial_visual_ms), cand_cold_visual_ms = round(hc$cold_visual_ms), cand_repeat_visual_ms = round(hc$repeat_visual_ms),
    base_initial_visual_ms = round(hb$initial_visual_ms), base_cold_visual_ms = round(hb$cold_visual_ms), base_repeat_visual_ms = round(hb$repeat_visual_ms),
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
