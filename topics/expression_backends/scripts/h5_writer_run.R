# H5 writer benchmark: the streaming writer of two CerebroNexus revisions on one cell-major 10x source, in turns.
# Usage (from the root of this repository):
#   Rscript topics/expression_backends/scripts/h5_writer_run.R --cerebro-repo DIR --candidate REF --baseline REF
#           --source FILE [--group mm10] [--rounds 5] [--workers 4] [--work DIR]
# Each revision is installed from `git archive` of its commit (committed code only). Every measurement is a fresh R
# process (h5_writer_measure.R) that writes the gene-major H5 file at gzip level 1 and reads genes from it. Which revision
# goes first alternates with the round. Before each measurement the machine must be idle (total CPU under 15 % for
# 3 s, waiting at most 120 s; the wait and the result are recorded). The files of round 1 are compared value by
# value (equivalence); every file is deleted after its measurement. Writes
# data/h5_writer/<stamp>_<candidate>_vs_<baseline>/ with manifest.tsv, raw.tsv, checks.tsv and summary.md, and
# names a finished run of at least 5 rounds in data/h5_writer/CURRENT. Decision rule (topics/STANDARDS.md): exact two-sided
# rank-sum test over the rounds, p <= 0.05, and a difference of medians above 3 % and 15 ms.
here <- normalizePath(
  dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])),
  winslash = "/"
)
topic <- dirname(here)
args <- commandArgs(TRUE)
opt <- list(group = "mm10", rounds = "5", workers = "4")
for (i in seq(1, length(args), by = 2)) {
  opt[[gsub("-", "_", sub("^--", "", args[[i]]))]] <- args[[i + 1L]]
}
for (k in c("cerebro_repo", "candidate", "baseline", "source")) {
  if (is.null(opt[[k]])) stop("--", gsub("_", "-", k), " is required", call. = FALSE)
}
rounds <- as.integer(opt$rounds)
workers <- as.integer(opt$workers)
if (rounds < 5L) warning("fewer than 5 rounds: no outcome can be resolved (STANDARDS.md)", call. = FALSE)
repo <- normalizePath(opt$cerebro_repo, winslash = "/")
source_file <- normalizePath(opt$source, winslash = "/")
on_windows <- .Platform$OS.type == "windows"
rscript <- file.path(R.home("bin"), if (on_windows) "Rscript.exe" else "Rscript")
cache <- file.path(
  if (on_windows) Sys.getenv("LOCALAPPDATA") else file.path(Sys.getenv("HOME"), ".cache"),
  "cerebronexus-h5writer-bench"
)
work <- if (is.null(opt$work)) file.path(cache, "work") else opt$work
dir.create(work, recursive = TRUE, showWarnings = FALSE)
git <- function(...) system2("git", c("-C", repo, ...), stdout = TRUE)

install_rev <- function(ref) {
  sha <- git("rev-parse", "--verify", paste0(ref, "^{commit}"))[[1L]]
  s12 <- substr(sha, 1, 12)
  lib <- file.path(cache, "lib", s12)
  if (!dir.exists(file.path(lib, "CerebroNexus"))) {
    src <- file.path(cache, "src", s12)
    dir.create(src, recursive = TRUE, showWarnings = FALSE)
    tarball <- file.path(cache, paste0(s12, ".tar"))
    if (system2("git", c("-C", repo, "archive", "--format=tar", "-o", tarball, sha)) != 0) {
      stop("git archive failed for ", ref, call. = FALSE)
    }
    utils::untar(tarball, exdir = src)
    unlink(tarball)
    dir.create(lib, recursive = TRUE, showWarnings = FALSE)
    log <- file.path(cache, paste0("install-", s12, ".log"))
    status <- system2(
      file.path(R.home("bin"), "R"),
      c("CMD", "INSTALL", "--no-docs", "--no-multiarch", "--no-test-load", paste0("--library=", lib), src),
      stdout = log, stderr = log
    )
    if (status != 0) stop("install failed, see ", log, call. = FALSE)
  }
  version <- read.dcf(file.path(lib, "CerebroNexus", "DESCRIPTION"), "Version")[[1L]]
  list(ref = ref, sha = sha, s12 = s12, lib = lib, version = version)
}
revs <- list(candidate = install_rev(opt$candidate), baseline = install_rev(opt$baseline))

## The highest total CPU over 3 one-second samples (Windows), NA elsewhere.
cpu_now <- function() {
  if (!on_windows) return(NA_real_)
  command <- paste(
    "(Get-Counter '\\Processor(_Total)\\% Processor Time' -SampleInterval 1 -MaxSamples 3).CounterSamples.CookedValue",
    "| Measure-Object -Maximum | ForEach-Object Maximum"
  )
  out <- suppressWarnings(system2("powershell.exe", c("-NoProfile", "-Command", shQuote(command, type = "cmd")), stdout = TRUE))
  suppressWarnings(as.numeric(utils::tail(out, 1)))
}
wait_idle <- function() {
  t0 <- Sys.time()
  repeat {
    cpu <- cpu_now()
    waited <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    if (is.na(cpu) || cpu < 15) return(list(waited = waited, idle = !is.na(cpu), cpu = cpu))
    if (waited > 120) return(list(waited = waited, idle = FALSE, cpu = cpu))
  }
}

stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
runs_root <- file.path(topic, "data", "h5_writer")
run_dir <- file.path(runs_root, sprintf("%s_%s_vs_%s", stamp, revs$candidate$s12, revs$baseline$s12))
dir.create(run_dir, recursive = TRUE)
cat("run:", run_dir, "\n")
rows <- list()
kept <- list()
for (r in seq_len(rounds)) {
  order <- if (r %% 2L == 1L) c("candidate", "baseline") else c("baseline", "candidate")
  for (rv in order) {
    idle <- wait_idle()
    out <- file.path(work, sprintf("%s-r%02d.h5", rv, r))
    t0 <- Sys.time()
    res <- system2(
      rscript,
      c("--no-save", "--no-restore", file.path(here, "h5_writer_measure.R"), revs[[rv]]$lib, source_file, opt$group, out, workers),
      stdout = TRUE,
      stderr = file.path(run_dir, sprintf("r%02d-%s.log", r, rv))
    )
    line <- grep("^ROW\t", res, value = TRUE)
    status <- if (length(line)) "ok" else "error"
    kv <- character()
    if (length(line)) {
      pairs <- strsplit(strsplit(line, "\t", fixed = TRUE)[[1]][-1], "=", fixed = TRUE)
      kv <- stats::setNames(vapply(pairs, `[`, "", 2), vapply(pairs, `[`, "", 1))
    }
    rows[[length(rows) + 1L]] <- c(
      round = r, revision = rv, sha = revs[[rv]]$sha, status = status,
      started = format(t0, "%Y-%m-%d %H:%M:%S"), idle_wait_s = round(idle$waited, 1),
      idle = idle$idle, cpu_before = idle$cpu, kv
    )
    cat(sprintf("[round %d] %-9s %s write=%s s read_genes=%s s\n", r, rv, status, kv["write_s"], kv["read_genes_s"]))
    if (r == 1L && status == "ok") kept[[rv]] <- out else unlink(out)
  }
}
columns <- unique(unlist(lapply(rows, names)))
raw <- as.data.frame(do.call(rbind, lapply(rows, function(x) x[columns])), stringsAsFactors = FALSE)
names(raw) <- columns
utils::write.table(raw, file.path(run_dir, "raw.tsv"), sep = "\t", row.names = FALSE, quote = FALSE)

## Equivalence: the two files of round 1 hold the same values.
checks <- data.frame(check = "same values (round 1 files)", result = "not run")
if (length(kept) == 2L) {
  g <- "expression"
  same <- TRUE
  for (d in c("shape", "indptr", "barcodes", "genes")) {
    read <- function(f) tryCatch(as.vector(rhdf5::h5read(f, paste0(g, "/", d), bit64conversion = "double")), error = function(e) NULL)
    same <- same && identical(read(kept$candidate), read(kept$baseline))
  }
  n <- as.numeric(raw$nnz[raw$status == "ok"][1])
  step <- 2^27
  for (d in c("indices", "data")) {
    for (s in seq(1, n, by = step)) {
      k <- min(step, n - s + 1)
      same <- same && identical(
        as.vector(rhdf5::h5read(kept$candidate, paste0(g, "/", d), start = s, count = k)),
        as.vector(rhdf5::h5read(kept$baseline, paste0(g, "/", d), start = s, count = k))
      )
      if (!same) break
    }
  }
  checks$result <- if (same) "pass" else "FAIL"
}
unlink(unlist(kept))
utils::write.table(checks, file.path(run_dir, "checks.tsv"), sep = "\t", row.names = FALSE, quote = FALSE)

harness <- tryCatch(system2("git", c("-C", here, "rev-parse", "HEAD"), stdout = TRUE)[[1L]], error = function(e) NA)
dirty <- length(tryCatch(system2("git", c("-C", here, "status", "--porcelain", "--", "."), stdout = TRUE), error = function(e) character())) > 0
manifest <- data.frame(
  key = c("benchmark", "candidate_ref", "candidate_sha", "candidate_version", "baseline_ref", "baseline_sha",
    "baseline_version", "source", "source_bytes", "source_md5", "group", "rounds", "workers", "gzip_level",
    "platform", "cpu", "logical_cores", "r_version", "rhdf5", "HDF5Array", "harness_commit", "started"),
  value = c("h5_writer-v1", revs$candidate$ref, revs$candidate$sha, revs$candidate$version, revs$baseline$ref,
    revs$baseline$sha, revs$baseline$version, source_file, file.size(source_file), unname(tools::md5sum(source_file)),
    opt$group, rounds, workers, 1, R.version$platform, Sys.getenv("PROCESSOR_IDENTIFIER", NA),
    parallel::detectCores(), R.version.string, as.character(utils::packageVersion("rhdf5")),
    as.character(utils::packageVersion("HDF5Array")), paste0(harness, if (dirty) "-dirty" else ""), stamp)
)
utils::write.table(manifest, file.path(run_dir, "manifest.tsv"), sep = "\t", row.names = FALSE, quote = FALSE)

## Summary: per metric, the medians, the difference, the exact rank-sum p and the outcome.
metrics <- c("write_s", "read_genes_s", "read_genes_again_s", "read_subset_s", "file_bytes")
ok <- raw[raw$status == "ok", ]
lines <- c(
  sprintf("# H5 writer: %s (candidate) vs %s (baseline)", revs$candidate$s12, revs$baseline$s12),
  "",
  sprintf("Source: `%s` (%s non-zero values); %d rounds in turns; %d worker processes; gzip level 1.",
    basename(source_file), ok$nnz[1], rounds, workers),
  sprintf("Equivalence of the round-1 files: **%s**.", checks$result),
  "",
  "| Metric | Baseline (median) | Candidate (median) | Difference | p (exact rank-sum) | Outcome |",
  "|---|---|---|---|---|---|"
)
for (k in metrics) {
  a <- as.numeric(ok[[k]][ok$revision == "baseline"])
  b <- as.numeric(ok[[k]][ok$revision == "candidate"])
  if (!length(a) || !length(b)) next
  ma <- stats::median(a)
  mb <- stats::median(b)
  p <- if (length(unique(c(a, b))) > 1) suppressWarnings(stats::wilcox.test(b, a, exact = TRUE)$p.value) else 1
  above_floor <- abs(mb - ma) > max(0.03 * abs(ma), if (k == "file_bytes") 0 else 0.015)
  outcome <- if (min(length(a), length(b)) < 5) {
    "too few rounds"
  } else if (p <= 0.05 && above_floor) {
    if (mb < ma) "faster / smaller" else "slower / larger"
  } else {
    "not resolved"
  }
  lines <- c(lines, sprintf("| %s | %s | %s | %+.1f %% | %.3f | %s |", k,
    format(signif(ma, 4), big.mark = ","), format(signif(mb, 4), big.mark = ","), 100 * (mb - ma) / ma, p, outcome))
}
lines <- c(lines, "", sprintf("Sessions that started on a busy machine: %d of %d.", sum(raw$idle != "TRUE"), nrow(raw)))
writeLines(lines, file.path(run_dir, "summary.md"))
## A complete run (enough rounds, every measurement ok, the files equal) becomes the current one.
if (rounds >= 5L && all(raw$status == "ok") && identical(checks$result, "pass")) {
  writeLines(basename(run_dir), file.path(runs_root, "CURRENT"))
}
cat(lines, sep = "\n")
