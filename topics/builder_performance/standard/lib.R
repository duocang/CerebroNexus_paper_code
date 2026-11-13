# Pure functions of the Builder performance measurement: the schedule, the aggregation, the comparison of two
# runs. No Builder and no R worker here, so they are unit tested (../tests/test-standard.R). The rules are in
# ../STANDARD.md. The statistics (rank_sum_p, rank_sum_min_p, med) and the machine checks are those of
# topics/viewer_performance/standard (lib.R, proc.R), sourced by run.R and compare.R, not copied.

standard_contract <- "builder-perf-v1"

# Every number a worker can report, and whether it is a time (the comparison floor is a time resolution).
# `edit_ms`, `reduce_ms`: milliseconds; the others seconds.
time_metrics <- c(
  edit_ms = "ms",
  reduce_ms = "ms",
  import_s = "s",
  freeze_s = "s",
  build_s = "s",
  rebuild_s = "s",
  export_s = "s"
)
other_metrics <- c("cpu_s", "peak_mib", "out_mib")
all_metrics <- c(names(time_metrics), other_metrics)

compare_alpha <- 0.05
default_rounds <- 5L
# A difference of medians smaller than this share of the first run's median, or than the timer's resolution
# (15 ms: the Windows clock ticks at 15.6 ms), is not worth a name even when the rounds do not overlap.
floor_share <- 0.03
timer_floor_ms <- 15

read_tsv <- function(path) {
  utils::read.delim(path, stringsAsFactors = FALSE, comment.char = "#")
}

# ---- schedule -----------------------------------------------------------------------------------------------
# Every round measures every scenario once per revision, each in its own fresh R process. Two revisions take
# turns: which one goes first alternates with the round and the scenario, so that neither always meets the
# machine first (or after the other's disk traffic).
build_schedule <- function(scenarios, rounds, revisions = "candidate") {
  rows <- list()
  for (r in seq_len(rounds)) {
    for (i in seq_along(scenarios)) {
      order <- if (length(revisions) == 2L && (r + i) %% 2L == 0L) {
        rev(revisions)
      } else {
        revisions
      }
      for (rv in order) {
        rows[[length(rows) + 1L]] <- data.frame(
          round = r,
          scenario = scenarios[[i]],
          revision = rv,
          stringsAsFactors = FALSE
        )
      }
    }
  }
  out <- do.call(rbind, rows)
  out$position <- seq_len(nrow(out))
  out[, c("position", "round", "scenario", "revision")]
}

# ---- the run directory ---------------------------------------------------------------------------------------
# runs/cerebronexus-<version>_<YYYYMMDD-HHMMSS>_<sha7>[_<tag>][_partial]; `tag` tells two runs of one revision
# made together apart (the baseline of a noise check: "base").
run_dir_name <- function(
  version,
  sha,
  time = Sys.time(),
  partial = FALSE,
  tag = ""
) {
  sprintf(
    "cerebronexus-%s_%s_%s%s%s",
    version,
    format(time, "%Y%m%d-%H%M%S"),
    substr(sha, 1L, 7L),
    if (nzchar(tag)) paste0("_", tag) else "",
    if (partial) "_partial" else ""
  )
}

# ---- aggregation ---------------------------------------------------------------------------------------------
# One row per scenario: medians over the rounds that finished (status ok) for every metric the worker reported,
# and how many rounds finished.
scenario_table <- function(raw) {
  out <- lapply(split(raw, raw$scenario), function(d) {
    ok <- d[d$status == "ok", , drop = FALSE]
    row <- data.frame(
      scenario = d$scenario[[1L]],
      rounds = nrow(d),
      ok_rounds = nrow(ok),
      stringsAsFactors = FALSE
    )
    for (m in intersect(all_metrics, names(raw))) {
      row[[m]] <- if (nrow(ok)) med(ok[[m]]) else NA_real_
    }
    row
  })
  out <- do.call(rbind, out)
  rownames(out) <- NULL
  out
}

# ---- comparison ----------------------------------------------------------------------------------------------
# Compare two runs scenario by scenario and metric, from the observations of the rounds that finished.
#   slower / faster   the exact rank-sum test over the rounds gives p <= alpha and the medians differ by more
#                     than the floor (3 % of A's median, at least the timer's resolution)
#   not resolved      neither: the rounds overlap, or the difference is below the floor
#   too few rounds    with these numbers of rounds no outcome could give p <= alpha (3 against 3 cannot)
# Memory and CPU are reported (delta) but not judged. Runs made together (same pair_id) also get the range of
# B - A within each round.
compare_raw <- function(
  a,
  b,
  paired = FALSE,
  alpha = compare_alpha,
  metrics = names(time_metrics)
) {
  rows <- list()
  scenarios <- union(unique(a$scenario), unique(b$scenario))
  for (s in scenarios) {
    for (m in metrics) {
      da <- a[
        a$scenario == s & a$status == "ok" & !is.na(a[[m]]),
        ,
        drop = FALSE
      ]
      db <- b[
        b$scenario == s & b$status == "ok" & !is.na(b[[m]]),
        ,
        drop = FALSE
      ]
      if (!nrow(da) && !nrow(db)) {
        next
      }
      ma <- med(da[[m]])
      mb <- med(db[[m]])
      unit <- time_metrics[[m]]
      floor <- max(
        floor_share * abs(ma),
        if (identical(unit, "ms")) timer_floor_ms else timer_floor_ms / 1000,
        na.rm = TRUE
      )
      p <- rank_sum_p(da[[m]], db[[m]])
      min_p <- rank_sum_min_p(nrow(da), nrow(db))
      change <- if (is.na(p)) {
        "-"
      } else if (min_p > alpha) {
        "too few rounds"
      } else if (p <= alpha && abs(mb - ma) > floor) {
        (if (mb > ma) "slower" else "faster")
      } else {
        "not resolved"
      }
      both <- intersect(da$round, db$round)
      rd <- if (paired && length(both)) {
        vapply(
          both,
          function(r) db[[m]][match(r, db$round)] - da[[m]][match(r, da$round)],
          0
        )
      } else {
        numeric()
      }
      rows[[length(rows) + 1L]] <- data.frame(
        scenario = s,
        metric = m,
        a = ma,
        b = mb,
        delta = mb - ma,
        delta_pct = if (is.na(ma) || ma == 0) {
          NA_real_
        } else {
          round((mb / ma - 1) * 100, 1)
        },
        n_a = nrow(da),
        n_b = nrow(db),
        p = p,
        floor = floor,
        round_delta_min = if (length(rd)) min(rd) else NA_real_,
        round_delta_max = if (length(rd)) max(rd) else NA_real_,
        change = change,
        stringsAsFactors = FALSE
      )
    }
  }
  out <- do.call(rbind, rows)
  if (is.null(out)) {
    return(data.frame())
  }
  rownames(out) <- NULL
  out
}

# ---- the equivalence checks ------------------------------------------------------------------------------------
# A fast path that reuses something must also give the same bytes as the slow one, and must not reuse what no
# longer fits. checks.R writes one row per check; a run is only as good as its failed checks say.
check_summary <- function(checks) {
  if (is.null(checks) || !nrow(checks)) {
    return("no equivalence checks were run")
  }
  bad <- checks[checks$result != "pass", , drop = FALSE]
  if (!nrow(bad)) {
    return(character())
  }
  sprintf("equivalence check failed: %s (%s)", bad$check, bad$detail)
}

# ---- the summary -----------------------------------------------------------------------------------------------
fmt_num <- function(x, digits = 1L) {
  ifelse(
    is.na(x),
    "-",
    format(round(x, digits), big.mark = ",", trim = TRUE, nsmall = 0)
  )
}
md_table <- function(df) {
  c(
    paste0("| ", paste(names(df), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
    apply(df, 1L, function(r) paste0("| ", paste(r, collapse = " | "), " |"))
  )
}

write_summary <- function(
  path,
  info,
  scenarios,
  checks = NULL,
  problems = character()
) {
  show <- scenarios
  for (m in intersect(all_metrics, names(show))) {
    show[[m]] <- fmt_num(
      show[[m]],
      if (m %in% c("edit_ms", "reduce_ms")) 0L else 1L
    )
  }
  lines <- c(
    sprintf("# Builder performance: CerebroNexus %s", info$version),
    "",
    sprintf(
      "Run `%s`: revision `%s` (%s), %d round(s), %d session(s), %d failed.",
      info$run_id,
      info$ref,
      info$sha,
      info$rounds,
      info$sessions,
      info$failed
    ),
    sprintf(
      "Contract `%s`. Fixtures: %s. Machine: %s, %s, %s.",
      standard_contract,
      info$fixtures,
      info$host,
      info$os,
      info$cpu
    ),
    if (!is.null(info$pair)) {
      sprintf("Made together with `%s`; %s.", info$pair, info$pair_role)
    },
    "",
    "Medians over the rounds that finished. Times in milliseconds (`edit_ms`, `reduce_ms`) or seconds (the rest); `peak_mib` is the peak memory of the worker, `out_mib` the size of what it wrote.",
    "",
    md_table(show),
    ""
  )
  if (!is.null(checks) && nrow(checks)) {
    lines <- c(
      lines,
      "## Equivalence checks",
      "",
      md_table(checks[, c("check", "result", "detail")]),
      ""
    )
  }
  if (length(problems)) {
    lines <- c(lines, "## Problems", "", paste0("- ", problems), "")
  }
  writeLines(lines, path)
}

compare_lines <- function(
  cmp,
  a_id,
  b_id,
  differ = character(),
  paired = FALSE,
  same_revision = FALSE
) {
  lines <- c(sprintf("# %s -> %s", a_id, b_id), "")
  if (same_revision) {
    lines <- c(
      lines,
      "Both runs are of the same revision: every difference below is noise.",
      ""
    )
  }
  lines <- c(
    lines,
    if (paired) {
      "Made together: the rounds of A and B met the same machine."
    } else {
      "Not made together: a busier machine in one run looks like a change in the code."
    },
    ""
  )
  if (length(differ)) {
    lines <- c(
      lines,
      sprintf("The runs differ in: %s.", paste(differ, collapse = ", ")),
      ""
    )
  }
  if (!nrow(cmp)) {
    return(c(lines, "Nothing to compare."))
  }
  show <- data.frame(
    scenario = cmp$scenario,
    metric = cmp$metric,
    A = fmt_num(cmp$a, 1L),
    B = fmt_num(cmp$b, 1L),
    delta = fmt_num(cmp$delta, 1L),
    `%` = ifelse(is.na(cmp$delta_pct), "-", sprintf("%+.1f", cmp$delta_pct)),
    rounds = sprintf("%d/%d", cmp$n_a, cmp$n_b),
    p = ifelse(is.na(cmp$p), "-", sprintf("%.3f", cmp$p)),
    `B-A per round` = ifelse(
      is.na(cmp$round_delta_min),
      "-",
      sprintf(
        "%s to %s",
        fmt_num(cmp$round_delta_min, 1L),
        fmt_num(cmp$round_delta_max, 1L)
      )
    ),
    change = cmp$change,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  c(lines, md_table(show), "")
}
