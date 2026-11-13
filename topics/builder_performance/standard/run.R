# Measures what the Builder's own functions cost, for one CerebroNexus revision, or for a candidate and a
# baseline in turns. Usage (from the root of this repository):
#   Rscript topics/builder_performance/standard/run.R --fixtures ../data/builder-perf [--candidate REF]
#     [--baseline REF] [--cerebro-repo DIR] [--rounds N] [--scenarios a,b] [--no-checks]
# The rules are in ../STANDARD.md.
t_start <- Sys.time()
here <- normalizePath(
  dirname(sub(
    "^--file=",
    "",
    grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]
  )),
  winslash = "/"
)
topic <- dirname(here)
paper_repo <- dirname(dirname(topic))
viewer <- file.path(dirname(topic), "viewer_performance", "standard")
for (f in c("cli.R", "lib.R", "proc.R")) {
  source(file.path(viewer, f))
} # statistics, idle gate, canary, machine facts
source(file.path(here, "lib.R"))

die <- function(...) {
  message("error: ", ...)
  quit(save = "no", status = 2L)
}
opt <- parse_cli(commandArgs(TRUE))
if (is.null(opt$fixtures)) {
  die("--fixtures DIR is required (made once by standard/fixtures.R)")
}
fixtures_dir <- normalizePath(opt$fixtures, winslash = "/", mustWork = FALSE)
rounds <- if (is.null(opt$rounds)) default_rounds else as.integer(opt$rounds)
idle_max_s <- as.numeric(Sys.getenv(
  "PERF_IDLE_MAX_S",
  as.character(host_idle_max_s)
))
platform <- platform_name()
if (is.na(platform)) {
  die("unsupported platform")
}
repo <- normalizePath(
  if (is.null(opt$cerebro_repo)) {
    file.path(dirname(paper_repo), "CerebroNexus")
  } else {
    opt$cerebro_repo
  },
  winslash = "/"
)
sh <- function(cmd, args, ...) {
  suppressWarnings(system2(cmd, args, stdout = TRUE, stderr = FALSE, ...))
}
git <- function(...) sh("git", c("-C", repo, ...))
cache_root <- file.path(
  if (on_windows) {
    Sys.getenv("LOCALAPPDATA")
  } else {
    Sys.getenv("XDG_CACHE_HOME", file.path(Sys.getenv("HOME"), ".cache"))
  },
  "cerebronexus-builder-perf"
)

# ---- the revisions: installed from `git archive`, so that only committed code is measured -----------------
prepare_revision <- function(ref) {
  sha <- tryCatch(
    git("rev-parse", "--verify", "--quiet", paste0(ref, "^{commit}"))[[1L]],
    error = function(e) NA_character_
  )
  if (is.na(sha)) {
    die("cannot resolve revision: ", ref)
  }
  s12 <- substr(sha, 1L, 12L)
  src <- file.path(cache_root, "src", s12)
  lib <- file.path(cache_root, "lib", s12)
  if (!dir.exists(file.path(src, "inst"))) {
    dir.create(src, recursive = TRUE, showWarnings = FALSE)
    tarball <- tempfile(fileext = ".tar")
    if (
      system2(
        "git",
        c("-C", repo, "archive", "--format=tar", "-o", tarball, sha)
      ) !=
        0L
    ) {
      die("git archive failed for ", ref)
    }
    utils::untar(tarball, exdir = src, tar = "internal")
    unlink(tarball)
  }
  if (!dir.exists(file.path(lib, "CerebroNexus"))) {
    dir.create(lib, recursive = TRUE, showWarnings = FALSE)
    log <- file.path(cache_root, paste0("install-", s12, ".log"))
    rc <- system2(
      r_bin("R"),
      c(
        "CMD",
        "INSTALL",
        "--no-docs",
        "--no-multiarch",
        paste0("--library=", lib),
        src
      ),
      stdout = log,
      stderr = log
    )
    if (rc != 0L) {
      unlink(file.path(lib, "CerebroNexus"), recursive = TRUE)
      die("R CMD INSTALL failed for ", ref, "; see ", log)
    }
  }
  list(
    ref = ref,
    sha = sha,
    s12 = s12,
    src = src,
    lib = lib,
    version = description_version(file.path(src, "DESCRIPTION"))
  )
}
source(file.path(dirname(topic), "pin.R"))
pin <- read_pin() # the revision of every topic (topics/cerebronexus.pin) unless --candidate says otherwise
revs <- list(
  candidate = prepare_revision(
    if (is.null(opt$candidate)) pin$commit else opt$candidate
  )
)
if (!is.null(opt$baseline)) {
  revs$baseline <- prepare_revision(opt$baseline)
}
paired <- length(revs) == 2L
pair_id <- if (paired) {
  sprintf(
    "%s_%s_%s",
    format(t_start, "%Y%m%d-%H%M%S"),
    substr(revs$candidate$sha, 1L, 7L),
    substr(revs$baseline$sha, 1L, 7L)
  )
} else {
  ""
}

# ---- scenarios and fixtures ---------------------------------------------------------------------------------
sc <- read_tsv(file.path(here, "scenarios.tsv"))
fx <- read_tsv(file.path(here, "fixtures.tsv"))
if (!is.null(opt$scenarios)) {
  sc <- sc[
    sc$scenario %in% strsplit(opt$scenarios, ",", fixed = TRUE)[[1L]],
    ,
    drop = FALSE
  ]
}
if (!nrow(sc)) {
  die("no scenario selected")
}
sc$path <- file.path(fixtures_dir, fx$file[match(sc$fixture, fx$name)])
absent <- sc$scenario[!file.exists(sc$path)]
if (length(absent)) {
  die(
    "no fixture for: ",
    paste(absent, collapse = ", "),
    " (standard/fixtures.R writes them)"
  )
}
partial <- !is.null(opt$scenarios)
scale_note <- if (file.exists(file.path(fixtures_dir, "SCALE"))) {
  sub("^scale ", "", readLines(file.path(fixtures_dir, "SCALE"))[[1L]])
} else {
  "1"
}
if (!identical(scale_note, "1")) {
  message(
    "WARNING: the fixtures were made with --scale ",
    scale_note,
    ": a smoke test, not a measurement"
  )
}
used <- unique(sc$path)
fixture_md5 <- stats::setNames(unname(tools::md5sum(used)), basename(used))

for (rv in names(revs)) {
  r <- revs[[rv]]
  tag <- if (
    paired &&
      rv == "baseline" &&
      identical(revs$baseline$sha, revs$candidate$sha)
  ) {
    "base"
  } else {
    ""
  }
  r$run_id <- run_dir_name(r$version, r$sha, t_start, partial, tag)
  r$run_dir <- file.path(topic, "runs", r$run_id)
  dir.create(file.path(r$run_dir, "logs"), recursive = TRUE)
  r$work <- file.path(r$run_dir, "work")
  r$raw <- list()
  revs[[rv]] <- r
}
sched <- build_schedule(sc$scenario, rounds, names(revs))
sched$host_cpu_pct <- NA_real_
sched$host_wait_s <- NA_real_
sched$host_idle <- NA
for (rv in names(revs)) {
  utils::write.table(
    sched,
    file.path(revs[[rv]]$run_dir, "schedule.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
  )
}

# ---- one session: a fresh Rscript process, run alone ---------------------------------------------------------
metric_cols <- all_metrics
session <- function(row) {
  r <- revs[[row$revision]]
  s <- sc[sc$scenario == row$scenario, ]
  work <- file.path(
    r$work,
    sprintf("%03d-%s-r%d", row$position, row$scenario, row$round)
  )
  res <- paste0(work, ".json")
  log <- file.path(
    r$run_dir,
    "logs",
    sprintf("%03d-%s-r%d.log", row$position, row$scenario, row$round)
  )
  t0 <- Sys.time()
  rc <- system2(
    r_bin("Rscript"),
    c(
      "--vanilla",
      file.path(here, "worker.R"),
      r$lib,
      r$src,
      row$scenario,
      s$path,
      work,
      res
    ),
    stdout = log,
    stderr = log
  )
  wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  v <- if (file.exists(res)) {
    jsonlite::fromJSON(res)
  } else {
    list(error = sprintf("worker died (exit %s)", rc))
  }
  unlink(work, recursive = TRUE)
  failed <- !is.null(v$error) && !is.na(v$error)
  d <- data.frame(
    round = row$round,
    scenario = row$scenario,
    revision = row$revision,
    position = row$position,
    wall_s = wall,
    status = if (failed) "error" else "ok",
    error = if (failed) v$error else "",
    stringsAsFactors = FALSE
  )
  for (m in metric_cols) {
    d[[m]] <- if (is.null(v[[m]])) NA_real_ else as.numeric(v[[m]])
  }
  d$rebuild_h5_same_md5 <- if (is.null(v$rebuild_h5_same_md5)) {
    NA
  } else {
    v$rebuild_h5_same_md5
  }
  d
}

# ---- the run ---------------------------------------------------------------------------------------------------
message(sprintf(
  "%s; %d scenario(s), %d round(s), %d session(s)",
  paste(
    vapply(
      revs,
      function(r) sprintf("%s %s (%s)", r$version, r$s12, r$ref),
      ""
    ),
    collapse = " vs "
  ),
  nrow(sc),
  rounds,
  nrow(sched)
))
canaries <- canary_ms()
for (i in seq_len(nrow(sched))) {
  row <- sched[i, ]
  gate <- wait_host_idle(max_s = idle_max_s)
  sched$host_cpu_pct[[i]] <- round(gate$cpu_pct, 1)
  sched$host_wait_s[[i]] <- round(gate$waited_s, 1)
  sched$host_idle[[i]] <- gate$idle
  d <- session(row)
  d$host_cpu_pct <- sched$host_cpu_pct[[i]]
  d$host_idle <- sched$host_idle[[i]]
  revs[[row$revision]]$raw[[length(revs[[row$revision]]$raw) + 1L]] <- d
  shown <- unlist(d[1L, intersect(names(time_metrics), names(d))])
  shown <- shown[!is.na(shown)]
  message(sprintf(
    "[%d/%d] round %d %s%s: %s  %s%s",
    i,
    nrow(sched),
    row$round,
    if (paired) paste0(row$revision, " ") else "",
    row$scenario,
    d$status,
    if (d$status == "ok") {
      paste(sprintf("%s %.1f", names(shown), shown), collapse = "  ")
    } else {
      d$error
    },
    if (isFALSE(gate$idle)) {
      sprintf(
        "  [host busy: %.0f %% after %.0f s]",
        gate$cpu_pct,
        gate$waited_s
      )
    } else {
      ""
    }
  ))
  if (i %% (nrow(sched) / rounds) == 0L) {
    canaries <- c(canaries, canary_ms())
  } # one reading per round
  for (rv in names(revs)) {
    utils::write.table(
      sched,
      file.path(revs[[rv]]$run_dir, "schedule.tsv"),
      sep = "\t",
      quote = FALSE,
      row.names = FALSE
    )
  }
}

# ---- equivalence checks: once per revision (checks.R) -------------------------------------------------------
checks <- list()
if (is.null(opt$no_checks)) {
  for (rv in names(revs)) {
    message("equivalence checks: ", rv)
    out <- file.path(revs[[rv]]$run_dir, "checks.tsv")
    log <- file.path(revs[[rv]]$run_dir, "logs", "checks.log")
    system2(
      r_bin("Rscript"),
      c(
        "--vanilla",
        file.path(here, "checks.R"),
        revs[[rv]]$lib,
        revs[[rv]]$src,
        file.path(revs[[rv]]$work, "checks"),
        out
      ),
      stdout = log,
      stderr = log
    )
    checks[[rv]] <- if (file.exists(out)) {
      read_tsv(out)
    } else {
      data.frame(
        check = "checks.R",
        result = "fail",
        detail = "did not write a result; see logs/checks.log",
        stringsAsFactors = FALSE
      )
    }
  }
}

# ---- record: one run folder per revision ---------------------------------------------------------------------
machine <- machine_facts()
paper_sha <- sh("git", c("-C", paper_repo, "rev-parse", "HEAD"))
paper_sha <- if (length(paper_sha)) {
  paste0(
    paper_sha[[1L]],
    if (
      length(sh(
        "git",
        c("-C", paper_repo, "status", "--porcelain", "--", topic)
      ))
    ) {
      "-dirty"
    } else {
      ""
    }
  )
} else {
  NA_character_
}
canary_ratio <- max(canaries) / min(canaries)
any_failed <- FALSE
for (rv in names(revs)) {
  r <- revs[[rv]]
  raw <- do.call(rbind, r$raw)
  utils::write.table(
    raw,
    file.path(r$run_dir, "raw.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
  )
  scen <- scenario_table(raw)
  utils::write.table(
    scen,
    file.path(r$run_dir, "scenarios.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
  )
  mine <- sched[sched$revision == rv, ]
  failed <- sum(raw$status != "ok")
  busy <- sum(mine$host_idle %in% FALSE)
  any_failed <- any_failed ||
    failed > 0L ||
    (rv %in% names(checks) && any(checks[[rv]]$result != "pass"))
  problems <- c(
    if (failed) {
      sprintf(
        "%d session(s) failed: their scenarios have fewer rounds (logs/)",
        failed
      )
    },
    if (canary_ratio > canary_limit) {
      sprintf(
        "the CPU canary moved by a factor %.2f during the run (%s ms)",
        canary_ratio,
        paste(round(canaries), collapse = ", ")
      )
    },
    if (busy) {
      sprintf(
        "%d of %d sessions started on a busy machine (above %d %% CPU after waiting %d s)",
        busy,
        nrow(mine),
        host_idle_pct,
        round(idle_max_s)
      )
    },
    if (anyNA(mine$host_idle)) {
      "the machine's CPU could not be read before the sessions (package ps): no idle check was made"
    },
    if (!identical(scale_note, "1")) {
      sprintf(
        "fixtures made with --scale %s: a smoke test, not a measurement",
        scale_note
      )
    },
    if (rv %in% names(checks)) check_summary(checks[[rv]])
  )
  manifest <- c(
    run_id = r$run_id,
    contract = standard_contract,
    version = r$version,
    ref = r$ref,
    sha = r$sha,
    platform = platform,
    rounds = rounds,
    partial = partial,
    scenarios = paste(sc$scenario, collapse = ","),
    sessions = nrow(mine),
    failed_sessions = failed,
    pair_id = pair_id,
    pair_role = if (paired) rv else "",
    pair_with = if (paired) revs[[setdiff(names(revs), rv)]]$run_id else "",
    host = Sys.info()[["nodename"]],
    os = machine$os,
    cpu = machine$cpu,
    cores = parallel::detectCores(),
    mem_total_mib = machine$mem_total_mib,
    r_version = R.version.string,
    harness_commit = paper_sha,
    cerebro_repo = repo,
    fixtures = fixtures_dir,
    fixtures_scale = scale_note,
    fixtures_md5 = paste(
      sprintf("%s=%s", names(fixture_md5), fixture_md5),
      collapse = ","
    ),
    scenarios_md5 = unname(tools::md5sum(file.path(here, "scenarios.tsv"))),
    canary_ms = paste(round(canaries, 1), collapse = ","),
    canary_ratio = round(canary_ratio, 3),
    host_idle_pct = host_idle_pct,
    host_idle_max_s = idle_max_s,
    host_busy_sessions = busy,
    host_cpu_pct_median = if (all(is.na(mine$host_cpu_pct))) {
      NA
    } else {
      round(stats::median(mine$host_cpu_pct, na.rm = TRUE), 1)
    },
    checks_failed = if (rv %in% names(checks)) {
      sum(checks[[rv]]$result != "pass")
    } else {
      NA
    },
    started = format(t_start, "%Y-%m-%dT%H:%M:%S%z"),
    ended = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  )
  utils::write.table(
    data.frame(key = names(manifest), value = unname(manifest)),
    file.path(r$run_dir, "manifest.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
  )
  write_summary(
    file.path(r$run_dir, "summary.md"),
    list(
      version = r$version,
      run_id = r$run_id,
      ref = r$ref,
      sha = r$s12,
      rounds = rounds,
      sessions = nrow(mine),
      failed = failed,
      fixtures = paste(basename(used), collapse = ", "),
      host = manifest[["host"]],
      os = manifest[["os"]],
      cpu = manifest[["cpu"]],
      pair = if (paired) revs[[setdiff(names(revs), rv)]]$run_id,
      pair_role = if (paired) sprintf("this run is the %s", rv)
    ),
    scen,
    if (rv %in% names(checks)) checks[[rv]],
    problems
  )
  unlink(r$work, recursive = TRUE)
  cat(sprintf("\nRun (%s): %s\n", rv, r$run_dir))
  if (length(problems)) {
    cat("Problems:\n", paste0("  - ", problems, "\n"), sep = "")
  }
}
if (paired) {
  cat(sprintf(
    "\nCompare: Rscript %s %s %s\n",
    file.path("topics", "builder_performance", "standard", "compare.R"),
    revs$baseline$run_id,
    revs$candidate$run_id
  ))
}
quit(save = "no", status = if (any_failed) 2L else 0L)
