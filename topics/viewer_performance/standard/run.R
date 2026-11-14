#!/usr/bin/env Rscript
# Viewer performance: measure one CerebroNexus revision, or two in turn, and record the times under runs/.
# Rules: ../STANDARD.md. Run from the root of the paper-code repository, on Windows (also works on Linux).
#
#   Rscript topics/viewer_performance/standard/run.R --large-examples DIR
#           [--candidate REF] [--baseline REF] [--cerebro-repo DIR] [--rounds N] [--pages a,b]
#
#   --large-examples DIR  required: the folder with mb/cerebro_mb.crb (standard/fixtures.R makes it); relative to the
#                         current directory or absolute
#   --candidate REF       the revision to measure (default HEAD of the CerebroNexus checkout)
#   --baseline REF        a second revision, measured in the same run: the sessions of the two take turns, each
#                         revision gets a run folder of its own, and compare.R knows the two belong together.
#                         The same revision as --candidate gives a noise check.
#   --cerebro-repo DIR    the CerebroNexus checkout (default ../CerebroNexus beside this repository)
#   --rounds N            how often every page is measured (default 5)
#   --pages a,b           only these pages and their actions; the run folder ends in _partial
# Environment: PERF_CACHE (where sources, libraries and the servers' cache directories go), PERF_IDLE_MAX_S
# (how long a session waits for an idle machine, default 600).
# Exit code: 0 every session finished, 2 a session failed twice or setup error.
args_all <- commandArgs(trailingOnly = FALSE)
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", args_all, value = TRUE)[[1L]])))
source(file.path(here, "cli.R"))
source(file.path(here, "lib.R"))
source(file.path(here, "proc.R"))
options(error = function() { traceback(2); quit(save = "no", status = 2L) })
opt <- parse_cli(commandArgs(trailingOnly = TRUE))

die <- function(...) { message("ERROR: ", ...); quit(save = "no", status = 2L) }
sh <- function(cmd, args, ...) suppressWarnings(system2(cmd, args, stdout = TRUE, stderr = FALSE, ...))
topic <- dirname(here)
paper_repo <- normalizePath(file.path(topic, "..", ".."), winslash = "/")

known <- c("large_examples", "candidate", "baseline", "cerebro_repo", "rounds", "pages")
if (length(unknown <- setdiff(names(opt), known))) die("unknown option: --", paste(gsub("_", "-", unknown), collapse = ", --"))
if (is.null(opt$large_examples) || isTRUE(opt$large_examples)) die("--large-examples DIR is required (the folder with mb/cerebro_mb.crb; standard/fixtures.R makes it)")
rounds <- if (is.null(opt$rounds)) default_rounds else as.integer(opt$rounds)
if (is.na(rounds) || rounds < 1L) die("--rounds must be a positive whole number")
if (isTRUE(opt$baseline) || isTRUE(opt$candidate)) die("--candidate and --baseline take a revision")
idle_max_s <- as.numeric(Sys.getenv("PERF_IDLE_MAX_S", host_idle_max_s))
if (is.na(idle_max_s) || idle_max_s < 0) die("PERF_IDLE_MAX_S must be a number of seconds")

fixtures <- read_tsv(file.path(here, "fixtures.tsv"))
large_root <- normalizePath(opt$large_examples, winslash = "/", mustWork = FALSE)
large_paths <- tryCatch(fixture_paths(fixtures, large_root), error = function(e) die(conditionMessage(e)))

cache <- Sys.getenv("PERF_CACHE", default_cache())
dir.create(cache, recursive = TRUE, showWarnings = FALSE)
repo <- normalizePath(if (!is.null(opt$cerebro_repo)) opt$cerebro_repo else file.path(paper_repo, "..", "CerebroNexus"), winslash = "/", mustWork = FALSE)
if (!dir.exists(file.path(repo, ".git")) && !file.exists(file.path(repo, ".git"))) die("not a CerebroNexus checkout: ", repo, " (use --cerebro-repo)")
git <- function(...) sh("git", c("-C", repo, ...))

# ---- platform and lock -------------------------------------------------------------------------
platform <- platform_name()
if (is.na(platform)) die("Windows or Linux is required (see STANDARD.md)")
lock <- file.path(cache, "run.lock")
if (!dir.create(lock, showWarnings = FALSE)) {
  other <- tryCatch(readLines(file.path(lock, "pid"), warn = FALSE)[[1L]], error = function(e) "")
  if (nzchar(other) && pid_alive(other)) die("another performance run is active (pid ", other, "); only one at a time")
  unlink(lock, recursive = TRUE); dir.create(lock)
}
writeLines(as.character(Sys.getpid()), file.path(lock, "pid"))
# The servers' cache directories of this run (below) go when the run ends, however it ends.
# on.exit does not run at the top level of a script; a finalizer at exit does, also after quit().
run_caches <- character()
invisible(reg.finalizer(globalenv(), function(e) { unlink(run_caches, recursive = TRUE); unlink(lock, recursive = TRUE) }, onexit = TRUE))
stray <- stray_processes()
if (length(stray)) die("benchmark or browser automation processes already running: ", paste(stray, collapse = ", "))

# ---- the revisions: source and installed library --------------------------------------------------
prepare_revision <- function(ref) {
  sha <- tryCatch(git("rev-parse", "--verify", "--quiet", paste0(ref, "^{commit}")), error = function(e) character())
  if (!length(sha)) die("cannot resolve revision: ", ref)
  sha <- sha[[1L]]; s12 <- substr(sha, 1L, 12L)
  if (identical(ref, "HEAD") && length(git("status", "--porcelain", "--untracked-files=no"))) {
    message("note: the CerebroNexus checkout has uncommitted changes; they are not measured (only the commit ", s12, ")")
  }
  src <- file.path(cache, "src", s12); lib <- file.path(cache, "lib", s12)
  if (!dir.exists(file.path(src, "inst"))) {
    dir.create(src, recursive = TRUE, showWarnings = FALSE)
    tarball <- tempfile(fileext = ".tar")
    rc <- system2("git", c("-C", repo, "archive", "--format=tar", "-o", tarball, sha))
    if (rc != 0L) die("git archive failed for ", sha)
    utils::untar(tarball, exdir = src, tar = "internal"); unlink(tarball)
  }
  if (!dir.exists(file.path(lib, "CerebroNexus"))) {
    dir.create(lib, recursive = TRUE, showWarnings = FALSE)
    message("installing ", s12, " ...")
    install_log <- file.path(cache, paste0("install-", s12, ".log"))
    rc <- system2(r_bin("R"), c("CMD", "INSTALL", "--no-docs", "--no-multiarch", paste0("--library=", lib), src), stdout = install_log, stderr = install_log)
    if (rc != 0L) { unlink(file.path(lib, "CerebroNexus"), recursive = TRUE); die("R CMD INSTALL failed for ", s12, "; see ", install_log) }
  }
  list(ref = ref, sha = sha, s12 = s12, src = src, lib = lib, version = description_version(file.path(src, "DESCRIPTION")),
       demos = sub("\\.crb$", "", list.files(file.path(src, "inst", "extdata", "examples"), "\\.crb$")))
}
source(file.path(dirname(topic), "pin.R"))
pin <- read_pin()   # the revision of every topic (topics/cerebronexus.pin) unless --candidate says otherwise
revs <- list(candidate = prepare_revision(if (is.null(opt$candidate)) pin$commit else opt$candidate))
if (!is.null(opt$baseline)) revs$baseline <- prepare_revision(opt$baseline)
paired <- length(revs) == 2L

# ---- what is measured where ----------------------------------------------------------------------
# Each page once, on the dataset coverage.tsv gives it: a large fixture, or a demo CRB of the revision.
coverage <- read_tsv(file.path(here, "coverage.tsv")); actions <- read_tsv(file.path(here, "actions.tsv"))
partial <- !is.null(opt$pages)
for (rv in names(revs)) {
  plan <- build_plan(coverage, actions, fixtures$name, revs[[rv]]$demos)
  if (partial) plan <- tryCatch(subset_plan(plan, strsplit(opt$pages, ",", fixed = TRUE)[[1L]]), error = function(e) die(conditionMessage(e)))
  if (!nrow(plan)) die("no page can be measured for ", rv)
  revs[[rv]]$plan <- plan
  revs[[rv]]$uncovered <- attr(plan, "uncovered")
  # The datasets a session of this revision opens: those of its pages, and the small example CRB that the
  # dataset-switching actions put second in the menu.
  revs[[rv]]$datasets <- unique(plan$dataset)
  revs[[rv]]$opened <- unique(c(plan$dataset, if (any(grepl("loadData.switch", plan$actions, fixed = TRUE))) "example"))
  message(rv, ": CerebroNexus ", revs[[rv]]$version, " (", revs[[rv]]$s12, "); plan: ", paste(sprintf("%s=%s", plan$page, plan$dataset), collapse = ", "))
  if (length(revs[[rv]]$uncovered)) message("  no dataset for: ", paste(revs[[rv]]$uncovered, collapse = ", "))
}
crb_path <- function(rv, dataset) if (dataset %in% names(large_paths)) large_paths[[dataset]] else file.path(revs[[rv]]$src, "inst", "extdata", "examples", paste0(dataset, ".crb"))

# ---- run directories and cache directories ----------------------------------------------------------
# One run folder per revision. What a server keeps between starts goes to a cache directory of this run and
# this revision, never to the user's own: `kept` is filled by the warm-up and stays for the run (a later
# start), `empty` is emptied before every first_start session (nothing kept).
t_start <- Sys.time()
for (rv in names(revs)) {
  tag <- if (rv == "baseline" && identical(revs$baseline$sha, revs$candidate$sha)) "base" else ""
  revs[[rv]]$run_id <- run_dir_name(revs[[rv]]$version, revs[[rv]]$sha, t_start, partial, tag)
  revs[[rv]]$run_dir <- file.path(topic, "runs", revs[[rv]]$run_id)
  if (dir.exists(revs[[rv]]$run_dir)) die("run folder exists already: ", revs[[rv]]$run_dir)
  dir.create(file.path(revs[[rv]]$run_dir, "logs"), recursive = TRUE)
  revs[[rv]]$raw_path <- file.path(revs[[rv]]$run_dir, "raw.tsv")
  revs[[rv]]$server_path <- file.path(revs[[rv]]$run_dir, "server.tsv")
  utils::write.table(revs[[rv]]$plan, file.path(revs[[rv]]$run_dir, "plan.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
  revs[[rv]]$cache <- file.path(cache, "rcache", revs[[rv]]$run_id)
  unlink(revs[[rv]]$cache, recursive = TRUE)
  run_caches <- c(run_caches, revs[[rv]]$cache)
}
pair_id <- if (paired) sprintf("%s_%s_%s", format(t_start, "%Y%m%d-%H%M%S"), substr(revs$candidate$sha, 1L, 7L), substr(revs$baseline$sha, 1L, 7L)) else ""

canaries <- canary_ms()

# ---- schedule: every round measures every page once, each page in its own fresh session; a page with a first
# plot also gets two sessions of its own for it; two revisions take turns (build_schedule) -------------------
sched <- build_schedule(lapply(revs, function(r) r$plan), rounds)
sched$host_cpu_pct <- NA_real_; sched$host_wait_s <- NA_real_; sched$host_idle <- NA; sched$ok <- NA
write_schedule <- function() for (rv in names(revs)) utils::write.table(sched, file.path(revs[[rv]]$run_dir, "schedule.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
write_schedule()

session <- function(row, attempt, out = revs[[row$revision]]$raw_path, tag = sprintf("%03d", row$position), port_base = 20000L + row$position * 3L) {
  r <- revs[[row$revision]]
  start <- row$kind %in% start_visits
  cache_dir <- file.path(r$cache, if (identical(row$kind, "first_start")) "empty" else "kept")
  if (identical(row$kind, "first_start")) unlink(cache_dir, recursive = TRUE)
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  name <- sprintf("%s-%s-%s%s-r%d-a%d", tag, row$dataset, row$page, if (start) paste0("-", row$kind) else "", row$round, attempt)
  log <- file.path(r$run_dir, "logs", paste0(name, ".log"))
  # Switching datasets needs a second one in the menu: the revision's small example CRB.
  crb2 <- if (grepl("loadData.switch", row$actions, fixed = TRUE)) c("--crb2", crb_path(row$revision, "example"))
  rc <- system2(r_bin("Rscript"), c("--no-save", "--no-restore", file.path(here, "measure_session.R"), "--sha", r$sha,
                              "--lib", r$lib, "--crb", crb_path(row$revision, row$dataset), crb2, "--port", port_base + attempt, "--round", row$round,
                              "--out", out, "--dataset", row$dataset, "--page", row$page, "--session", name, "--cache-dir", cache_dir,
                              if (nzchar(row$actions)) c("--actions", row$actions), if (start) c("--first-plot", row$kind),
                              "--trace", file.path(r$run_dir, "logs", paste0(name, "-trace.csv"))),
                stdout = log, stderr = log, timeout = 3600)
  rc == 0L && any(grepl("rows,", readLines(log, warn = FALSE), fixed = TRUE))
}
# Warm-up: one discarded session per revision and dataset it opens. The first read of a large fixture's H5
# comes from disk, the rest from the file cache; and the session leaves in `kept` what the Viewer keeps for a
# data set, so that every measured session on it is a later start, in round 1 as in round 5. On the dataset
# of a page whose first plot is timed, the warm-up opens that page too (what is kept for its first view).
warm <- 0L
for (rv in names(revs)) for (d in revs[[rv]]$opened) {
  if (!file.exists(crb_path(rv, d))) next
  message("warm-up: ", rv, " ", d)
  warm <- warm + 1L
  warm_page <- c(revs[[rv]]$plan$page[revs[[rv]]$plan$dataset == d & revs[[rv]]$plan$first_plot], "none")[[1L]]
  invisible(session(data.frame(revision = rv, dataset = d, page = warm_page, actions = "", kind = "page", round = 0L, position = 0L, stringsAsFactors = FALSE), 1L,
                    out = tempfile(fileext = ".tsv"), tag = paste0("warm-", rv), port_base = 19000L + warm * 3L))
}
for (r in seq_len(rounds)) {
  for (i in which(sched$round == r)) {
    row <- sched[i, ]
    # The machine as a whole has to be idle, not only the two process trees the session will start.
    gate <- wait_host_idle(max_s = idle_max_s)
    sched$host_cpu_pct[[i]] <- round(gate$cpu_pct, 1); sched$host_wait_s[[i]] <- round(gate$waited_s, 1); sched$host_idle[[i]] <- gate$idle
    message(sprintf("[%d/%d] round %d: %s%s on %s%s%s%s", i, nrow(sched), row$round, if (paired) paste0(row$revision, " ") else "", row$page, row$dataset,
                    switch(row$kind, first_start = " (start to first plot, nothing kept)", first_plot = " (start to first plot)", ""),
                    if (nzchar(row$actions)) paste0(" + ", row$actions) else "",
                    if (isFALSE(gate$idle)) sprintf("  [host busy: %.0f %% after %.0f s]", gate$cpu_pct, gate$waited_s) else ""))
    sched$ok[[i]] <- session(row, 1L) || { Sys.sleep(5); session(row, 2L) }
    if (!sched$ok[[i]]) message("  session failed twice; see logs/")
  }
  # Server steps (server_steps.R): the R work behind the pages, one fresh R process per revision, dataset and round.
  for (rv in if (r %% 2L) names(revs) else rev(names(revs))) for (d in revs[[rv]]$datasets) {
    message(sprintf("server steps: %s%s round %d", if (paired) paste0(rv, " ") else "", d, r))
    log <- file.path(revs[[rv]]$run_dir, "logs", sprintf("server-%s-r%d.log", d, r))
    system2(r_bin("Rscript"), c("--no-save", "--no-restore", file.path(here, "server_steps.R"), "--label", "run", "--sha", revs[[rv]]$sha,
                         "--lib", revs[[rv]]$lib, "--src", revs[[rv]]$src, "--crb", crb_path(rv, d), "--dataset", d, "--round", r,
                         "--out", revs[[rv]]$server_path, "--cache-dir", file.path(revs[[rv]]$cache, "kept")),
            stdout = log, stderr = log, timeout = 3600)
  }
  canaries <- c(canaries, canary_ms())
  write_schedule()
}

# ---- record: one run folder per revision -------------------------------------------------------------
machine <- machine_facts()
paper_sha <- sh("git", c("-C", paper_repo, "rev-parse", "HEAD"))
paper_sha <- if (length(paper_sha)) paste0(paper_sha[[1L]], if (length(sh("git", c("-C", paper_repo, "status", "--porcelain", "--", topic)))) "-dirty" else "") else NA_character_
canary_ratio <- max(canaries) / min(canaries)
t_end <- Sys.time()
any_failed <- FALSE
for (rv in names(revs)) {
  r <- revs[[rv]]
  mine <- sched[sched$revision == rv, , drop = FALSE]
  failed <- sum(mine$ok %in% FALSE)
  any_failed <- any_failed || failed > 0L
  raw <- if (file.exists(r$raw_path)) utils::read.delim(r$raw_path, stringsAsFactors = FALSE, colClasses = c(arg = "character")) else NULL
  if (is.null(raw)) { message("no observations were recorded for ", rv, "; see ", file.path(r$run_dir, "logs")); any_failed <- TRUE; next }
  pages <- page_table(raw)
  utils::write.table(pages, file.path(r$run_dir, "pages.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
  server <- if (file.exists(r$server_path)) server_table(utils::read.delim(r$server_path, stringsAsFactors = FALSE, colClasses = c(hash = "character"))) else NULL
  busy <- sum(mine$host_idle %in% FALSE)
  not_empty <- if (is.null(raw$cache_files)) 0L else sum(raw$visit == "first_start" & !is.na(raw$cache_files) & raw$cache_files > 0)
  unfinished <- pages$ok_frac < 1
  problems <- c(
    if (failed) sprintf("%d session(s) failed twice: their pages have fewer rounds (logs/)", failed),
    if (canary_ratio > canary_limit) sprintf("the CPU canary moved by a factor %.2f during the run (%s ms): the machine was busy with something else or changed its speed",
                                             canary_ratio, paste(round(canaries), collapse = ", ")),
    if (busy) sprintf("%d of %d sessions started on a busy machine (above %d %% CPU after waiting %d s): schedule.tsv, host_idle", busy, nrow(mine), host_idle_pct, round(idle_max_s)),
    if (anyNA(mine$host_idle)) "the machine's CPU could not be read before the sessions (package ps): no idle check was made",
    if (not_empty) sprintf("%d first_start observation(s) found files in the cache directory that should have been empty", not_empty),
    if (any(unfinished)) sprintf("not finished in every round: %s", paste(unique(ifelse(pages$visit[unfinished] %in% start_visits, sprintf("%s (%s)", pages$page[unfinished], pages$visit[unfinished]), pages$page[unfinished])), collapse = ", "))
  )
  seen <- function(col) if (!is.null(raw[[col]])) paste(sort(unique(stats::na.omit(raw[[col]]))), collapse = " | ") else "unknown"
  fx <- intersect(r$datasets, names(large_paths))
  fixture_facts <- unlist(lapply(fx, function(d) {
    stamp <- file.path(dirname(large_paths[[d]]), "demo-version")
    stats::setNames(c(fixtures$crb[fixtures$name == d], unname(tools::md5sum(large_paths[[d]])), file.size(sub("[.]crb$", ".h5", large_paths[[d]])),
                      if (file.exists(stamp)) readLines(stamp, warn = FALSE)[[1L]] else NA),
                    paste0("fixture.", d, c(".crb", ".md5", ".h5_bytes", ".version_stamp")))
  }))
  other <- if (paired) revs[[setdiff(names(revs), rv)]] else NULL
  host_load <- if (all(is.na(mine$host_cpu_pct))) NA_character_ else
    sprintf("median %.1f %% CPU, at most %.1f %%; waited %.0f s in all", stats::median(mine$host_cpu_pct, na.rm = TRUE), max(mine$host_cpu_pct, na.rm = TRUE), sum(mine$host_wait_s, na.rm = TRUE))
  manifest <- c(
    run_id = r$run_id, contract = standard_contract, version = r$version, ref = r$ref, sha = r$sha, platform = platform,
    rounds = rounds, partial = partial, datasets = paste(r$datasets, collapse = ","), sessions = nrow(mine), failed_sessions = failed,
    pair_id = pair_id, pair_role = if (paired) rv else "", pair_with = if (paired) other$run_id else "",
    host = Sys.info()[["nodename"]], os = machine$os, cpu = machine$cpu, cores = parallel::detectCores(), mem_total_mib = machine$mem_total_mib,
    gpu = machine$gpu, renderer = seen("gpu"), memory_measure = if (on_windows) "private bytes (Windows has no PSS)" else "PSS",
    r_version = R.version.string, chrome = seen("browser"), chromote = tryCatch(as.character(utils::packageVersion("chromote")), error = function(e) NA_character_),
    harness_commit = paper_sha, cerebro_repo = repo, large_examples = large_root,
    plan_md5 = unname(tools::md5sum(file.path(r$run_dir, "plan.tsv"))),
    fixtures_md5 = paste(vapply(fx, function(d) fixture_facts[[paste0("fixture.", d, ".md5")]], ""), collapse = ","),
    uncovered_pages = paste(r$uncovered, collapse = ","),
    cache = "a directory of this run and revision (R_USER_CACHE_DIR): filled by the warm-up and kept; emptied before every first_start session",
    canary_ms = paste(round(canaries, 1), collapse = ","), canary_ratio = round(canary_ratio, 3),
    host_idle_pct = host_idle_pct, host_idle_max_s = idle_max_s, host_busy_sessions = busy,
    host_cpu_pct_median = if (all(is.na(mine$host_cpu_pct))) NA else round(stats::median(mine$host_cpu_pct, na.rm = TRUE), 1),
    started = format(t_start, "%Y-%m-%dT%H:%M:%S%z"), ended = format(t_end, "%Y-%m-%dT%H:%M:%S%z"),
    fixture_facts
  )
  utils::write.table(data.frame(key = names(manifest), value = unname(manifest)), file.path(r$run_dir, "manifest.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
  write_summary(file.path(r$run_dir, "summary.md"),
                list(version = r$version, run_id = r$run_id, ref = r$ref, sha = r$s12, rounds = rounds, sessions = nrow(mine), failed = failed,
                     datasets = paste(r$datasets, collapse = ", "), host = manifest[["host"]], os = manifest[["os"]], cpu = manifest[["cpu"]],
                     r_version = R.version.string, chrome = manifest[["chrome"]], renderer = manifest[["renderer"]], uncovered = r$uncovered,
                     pair = if (paired) other$run_id, pair_role = if (paired) sprintf("this run is the %s", rv),
                     host_load = if (!is.na(host_load)) host_load),
                pages, memory_table(raw), server, problems)
  cat(sprintf("\nRun (%s): %s\n", rv, r$run_dir))
  if (length(problems)) cat("Problems:\n", paste0("  - ", problems, "\n"), sep = "")
  cat("Summary:", file.path(r$run_dir, "summary.md"), "\n")
}
if (paired) cat(sprintf("\nCompare: Rscript %s %s %s\n", file.path("topics", "viewer_performance", "standard", "compare.R"), revs$baseline$run_id, revs$candidate$run_id))
quit(save = "no", status = if (any_failed) 2L else 0L)
