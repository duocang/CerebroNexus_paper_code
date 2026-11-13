# Measures how long createShinyApp() takes, what it writes and how much memory it needs, for one CerebroNexus
# revision. Usage (from the root of this repository):
#   Rscript topics/app_export/standard/run.R --large-examples ../data/large-examples [--candidate REF]
#     [--fixtures DIR] [--cerebro-repo DIR] [--rounds N] [--scenarios a,b]
# --fixtures is where standard/fixtures.R wrote the CRBs of the `fixture` scenarios; without it they are left out.
here <- normalizePath(
  dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])),
  winslash = "/"
)
topic <- dirname(here)
source(file.path(dirname(topic), "viewer_performance", "standard", "cli.R"))
die <- function(...) {
  message("error: ", ...)
  quit(status = 2L)
}
opt <- parse_cli(commandArgs(TRUE))
if (is.null(opt$large_examples)) die("--large-examples DIR is required")
rounds <- if (is.null(opt$rounds)) 3L else as.integer(opt$rounds)
on_windows <- .Platform$OS.type == "windows"
repo <- normalizePath(
  if (is.null(opt$cerebro_repo)) file.path(dirname(dirname(dirname(topic))), "CerebroNexus") else opt$cerebro_repo,
  winslash = "/"
)
git <- function(...) system2("git", c("-C", repo, ...), stdout = TRUE, stderr = FALSE)
r_bin <- function(name) file.path(R.home("bin"), if (on_windows) paste0(name, ".exe") else name)
cache <- file.path(
  if (on_windows) Sys.getenv("LOCALAPPDATA") else file.path(Sys.getenv("HOME"), ".cache"),
  "cerebronexus-app-export"
)

# ---- the revision: installed from git archive, as in viewer_performance ---------------------------
source(file.path(dirname(topic), "pin.R"))
ref <- if (is.null(opt$candidate)) read_pin()$commit else opt$candidate   # topics/cerebronexus.pin
sha <- tryCatch(
  git("rev-parse", "--verify", "--quiet", paste0(ref, "^{commit}"))[[1L]],
  error = function(e) NA_character_
)
if (is.na(sha)) die("cannot resolve revision: ", ref)
s12 <- substr(sha, 1L, 12L)
src <- file.path(cache, "src", s12)
lib <- file.path(cache, "lib", s12)
if (!dir.exists(file.path(src, "inst"))) {
  dir.create(src, recursive = TRUE, showWarnings = FALSE)
  tarball <- tempfile(fileext = ".tar")
  if (system2("git", c("-C", repo, "archive", "--format=tar", "-o", tarball, sha)) != 0L) {
    die("git archive failed")
  }
  utils::untar(tarball, exdir = src, tar = "internal")
  unlink(tarball)
}
if (!dir.exists(file.path(lib, "CerebroNexus"))) {
  dir.create(lib, recursive = TRUE, showWarnings = FALSE)
  log <- file.path(cache, paste0("install-", s12, ".log"))
  rc <- system2(
    r_bin("R"),
    c("CMD", "INSTALL", "--no-docs", "--no-multiarch", paste0("--library=", lib), src),
    stdout = log,
    stderr = log
  )
  if (rc != 0L) {
    unlink(file.path(lib, "CerebroNexus"), recursive = TRUE)
    die("R CMD INSTALL failed; see ", log)
  }
}
version <- read.dcf(file.path(src, "DESCRIPTION"), "Version")[[1L]]

# ---- scenarios ------------------------------------------------------------------------------------
sc <- utils::read.delim(file.path(here, "scenarios.tsv"), stringsAsFactors = FALSE, comment.char = "#")
if (!is.null(opt$scenarios)) {
  sc <- sc[sc$scenario %in% strsplit(opt$scenarios, ",", fixed = TRUE)[[1L]], , drop = FALSE]
}
if (is.null(opt$fixtures)) {
  if (any(sc$source == "fixture")) message("no --fixtures: leaving out ", paste(sc$scenario[sc$source == "fixture"], collapse = ", "))
  sc <- sc[sc$source != "fixture", , drop = FALSE]
}
sc$path <- ifelse(
  sc$source == "demo",
  file.path(src, "inst", "extdata", "examples", paste0(sc$crb, ".crb")),
  ifelse(sc$source == "fixture", file.path(if (is.null(opt$fixtures)) "" else opt$fixtures, sc$crb), file.path(opt$large_examples, sc$crb))
)
absent <- sc$scenario[!file.exists(sc$path)]
if (length(absent)) die("no CRB for: ", paste(absent, collapse = ", "))
partial <- !is.null(opt$scenarios)

run_id <- sprintf(
  "cerebronexus-%s_%s_%s%s",
  version,
  format(Sys.time(), "%Y%m%d-%H%M%S"),
  substr(sha, 1L, 7L),
  if (partial) "_partial" else ""
)
run_dir <- file.path(topic, "runs", run_id)
dir.create(run_dir, recursive = TRUE)
work <- file.path(run_dir, "work")
dir.create(work)

# ---- one session: the worker reports its own CPU time and peak memory ---------------------------------
session <- function(s, round) {
  out <- file.path(work, sprintf("%s-r%d", s$scenario, round))
  res <- paste0(out, ".json")
  p <- processx::process$new(
    r_bin("Rscript"),
    c("--vanilla", file.path(here, "worker.R"), lib, s$path, out, res, s$scenario),
    stdout = file.path(work, "worker.log"),
    stderr = "2>&1"
  )
  t0 <- Sys.time()
  p$wait()
  wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  r <- if (file.exists(res)) {
    jsonlite::fromJSON(res)
  } else {
    list(first_error = "worker died", first_s = NA, repeat_s = NA, out_files = NA, out_bytes = NA, cpu_s = NA, peak_mib = NA)
  }
  unlink(out, recursive = TRUE)
  failed <- !is.null(r$first_error) && !is.na(r$first_error)
  data.frame(
    scenario = s$scenario,
    round = round,
    first_s = r$first_s,
    repeat_s = r$repeat_s,
    wall_s = wall,
    cpu_s = r$cpu_s,
    peak_mib = r$peak_mib,
    out_files = r$out_files,
    out_mib = r$out_bytes / 2^20,
    status = if (failed) "error" else "ok",
    error = if (failed) r$first_error else ""
  )
}
message("CerebroNexus ", version, " (", s12, "): ", paste(sc$scenario, collapse = ", "), "; ", rounds, " rounds")
rows <- list()
for (round in seq_len(rounds)) {
  for (i in seq_len(nrow(sc))) {
    r <- session(sc[i, ], round)
    rows[[length(rows) + 1L]] <- r
    message(sprintf(
      "  %-15s r%d  first %.1f s  repeat %.1f s  peak %.0f MiB  %s",
      r$scenario, round, r$first_s, r$repeat_s, r$peak_mib, r$status
    ))
  }
}
raw <- do.call(rbind, rows)
utils::write.table(raw, file.path(run_dir, "raw.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
ok <- raw[raw$status == "ok", ]
med <- function(x) stats::median(x, na.rm = TRUE)
scenarios <- do.call(rbind, lapply(split(ok, ok$scenario), function(d) {
  data.frame(
    scenario = d$scenario[[1L]],
    rounds_ok = nrow(d),
    first_s = med(d$first_s),
    repeat_s = med(d$repeat_s),
    cpu_s = med(d$cpu_s),
    peak_mib = med(d$peak_mib),
    out_files = med(d$out_files),
    out_mib = med(d$out_mib)
  )
}))
utils::write.table(scenarios, file.path(run_dir, "scenarios.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
writeLines(
  c(
    "key\tvalue",
    "contract\tapp-export-v1",
    paste0("version\t", version),
    paste0("sha\t", sha),
    paste0("ref\t", ref),
    paste0("platform\t", R.version$platform),
    paste0("host\t", Sys.info()[["nodename"]]),
    paste0("r\t", R.version.string),
    paste0("rounds\t", rounds),
    paste0("scenarios\t", paste(sc$scenario, collapse = ",")),
    paste0(
      "fixture_md5\t",
      paste(sprintf("%s=%s", sc$scenario[sc$source == "fixture"], unname(tools::md5sum(sc$path[sc$source == "fixture"]))), collapse = ",")
    ),
    paste0("started\t", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
  ),
  file.path(run_dir, "manifest.tsv")
)
unlink(work, recursive = TRUE)
fmt <- function(x) ifelse(is.na(x), "-", formatC(x, format = "f", digits = 1))
bad <- raw$status != "ok"
lines <- c(
  paste0("# createShinyApp() on CerebroNexus ", version, " (", substr(sha, 1L, 7L), ")"),
  "",
  "| Scenario | first export (s) | repeat export (s) | CPU (s) | peak memory (MiB) | files | output (MiB) | rounds ok |",
  "|---|---|---|---|---|---|---|---|",
  sprintf(
    "| %s | %s | %s | %s | %s | %s | %s | %d/%d |",
    scenarios$scenario, fmt(scenarios$first_s), fmt(scenarios$repeat_s), fmt(scenarios$cpu_s),
    fmt(scenarios$peak_mib), fmt(scenarios$out_files), fmt(scenarios$out_mib), scenarios$rounds_ok, rounds
  )
)
if (any(bad)) {
  lines <- c(lines, "", "## Problems", "", sprintf("- %s round %d: %s", raw$scenario[bad], raw$round[bad], raw$error[bad]))
}
writeLines(lines, file.path(run_dir, "summary.md"))
message("written ", run_dir)
