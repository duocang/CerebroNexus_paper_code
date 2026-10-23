# Pure functions of the Viewer performance standard: policy, aggregation, the verdict and the
# records it writes. No browser and no R app here, so they are unit tested
# (topics/viewer_performance/tests/test-standard.R). The rules are in ../STANDARD.md.

standard_contract <- "blackbox-v3"
standard_metrics <- c("visual_complete_ms", "visual_90_ms", "settled_ms", "loader_visible_ms", "visible_ms", "js_peak_mib")
standard_visits <- c("initial", "first", "repeat", "action")
slow_pages <- c("hla_tcr_motifs", "trajectory")

# Visual metrics from screenshots taken back to back after a click. `sim` is the share of pixels of
# each frame that equals the last frame; `t` the frame times (ms) and `t_click` the click time.
#   visual_complete_ms  when the page first looked the way it ends up (no later frame differs by
#                       more than `tol` of the pixels). The KPI: it needs no cooperation from the
#                       Viewer code, so it is comparable across versions.
#   visual_90_ms        when the page first looked at least `progress` like its final state.
visual_from_similarity <- function(t, sim, t_click, tol = 0.0005, progress = 0.90) {
  n <- length(t)
  if (!n) return(list(visual_complete_ms = NA_real_, visual_90_ms = NA_real_))
  differs <- which(sim < 1 - tol)
  complete_t <- if (!length(differs)) t[[1L]] else t[[min(max(differs) + 1L, n)]]
  first90 <- which(sim >= progress)
  list(visual_complete_ms = max(0, complete_t - t_click),
       visual_90_ms = if (length(first90)) max(0, t[[first90[[1L]]]] - t_click) else NA_real_)
}

med <- function(x) if (all(is.na(x))) NA_real_ else stats::median(x, na.rm = TRUE)

read_policy <- function(path) {
  p <- utils::read.delim(path, stringsAsFactors = FALSE, colClasses = c(fixtures = "character", calibrated_by = "character"))
  stats::setNames(lapply(seq_len(nrow(p)), function(i) as.list(p[i, ])), p$tier)
}

# ---- what is measured where ------------------------------------------------------------------------
# coverage.tsv says, per page, which large fixture it is measured on and which demo CRB stands in when
# that fixture is not available. Every page is measured on exactly one dataset per run: a page that
# does not depend on the data (About, Gene ID conversion) is not repeated on every dataset.
read_coverage <- function(path) utils::read.delim(path, stringsAsFactors = FALSE)

read_fixtures <- function(path) utils::read.delim(path, stringsAsFactors = FALSE, na.strings = character(), colClasses = "character")

# Path of every large fixture that exists: the environment variable if set, else the default under HOME.
fixture_paths <- function(fixtures, home = Sys.getenv("HOME")) {
  paths <- vapply(seq_len(nrow(fixtures)), function(i) {
    p <- Sys.getenv(fixtures$env[[i]], "")
    if (!nzchar(p) && nzchar(fixtures$default_path[[i]])) p <- file.path(home, fixtures$default_path[[i]])
    if (nzchar(p) && file.exists(p)) p else ""
  }, "")
  stats::setNames(paths, fixtures$name)[nzchar(paths)]
}

# mode "demo": only the demo CRBs (L0). mode "auto": a page uses its large fixture when that
# exists and falls back to the demo CRB otherwise. Pages with no dataset are returned in attr "uncovered".
build_plan <- function(coverage, mode = c("auto", "demo"), large_available = character(), demos_available = character()) {
  mode <- match.arg(mode)
  rows <- lapply(seq_len(nrow(coverage)), function(i) {
    cv <- coverage[i, ]
    ds <- if (mode == "auto" && cv$fixture != "-" && cv$fixture %in% large_available) cv$fixture
          else if (cv$fallback %in% demos_available) cv$fallback else NA_character_
    data.frame(page = cv$page, dataset = ds, large = !is.na(ds) && ds %in% large_available, stringsAsFactors = FALSE)
  })
  plan <- do.call(rbind, rows)
  out <- plan[!is.na(plan$dataset), ]
  # large fixtures first: they take the longest and are the ones that need a warm-up
  out <- out[order(!out$large, match(out$dataset, unique(out$dataset)), match(out$page, coverage$page)), ]
  rownames(out) <- NULL
  attr(out, "uncovered") <- plan$page[is.na(plan$dataset)]
  out
}

# actions.tsv lists the in-page actions (changing the colour, zooming, switching the gene). An action
# runs on the dataset of its page and enters the plan as one more row, named "<page>.<action>".
read_actions <- function(path) utils::read.delim(path, stringsAsFactors = FALSE)

add_actions <- function(plan, actions) {
  rows <- actions[actions$page %in% plan$page, ]
  if (!nrow(rows)) return(plan)
  at <- match(rows$page, plan$page)
  extra <- data.frame(page = rows$action, dataset = plan$dataset[at], large = plan$large[at], stringsAsFactors = FALSE)
  out <- rbind(plan, extra)
  out <- out[order(match(out$dataset, unique(plan$dataset))), ]
  rownames(out) <- NULL
  attr(out, "uncovered") <- attr(plan, "uncovered")
  out
}

# Page budgets (STANDARD.md): first visit 2 s (3 s for Trajectory and HLA), repeat visit 500 ms.
# Actions have no budget yet.
page_budget_ms <- function(page, visit) {
  if (identical(visit, "action")) NA_real_ else if (identical(visit, "repeat")) 500 else if (page %in% slow_pages) 3000 else 2000
}

# One row per label x dataset x page x visit: medians over rounds and the share of rounds that
# finished ("ok").
cell_table <- function(raw) {
  key <- paste(raw$label, raw$dataset, raw$page, raw$visit, sep = "\r")
  rows <- lapply(split(raw, key), function(d) {
    out <- data.frame(
      label = d$label[[1L]], dataset = d$dataset[[1L]], page = d$page[[1L]], visit = d$visit[[1L]],
      n = nrow(d), ok_frac = mean(d$status == "ok"),
      not_ok = paste(sort(unique(d$status[d$status != "ok"])), collapse = ","),
      arg = if (is.null(d$arg)) "" else paste(sort(unique(stats::na.omit(d$arg))), collapse = ","),
      stringsAsFactors = FALSE
    )
    for (m in standard_metrics) out[[m]] <- if (is.null(d[[m]])) NA_real_ else med(d[[m]])
    out
  })
  do.call(rbind, unname(rows))
}

# Run-level memory: peak of each session, median over rounds, then median over datasets.
memory_table <- function(raw) {
  s <- unique(raw[c("label", "dataset", "round", "run_peak_r_pss_mib", "run_peak_chrome_pss_mib", "server_start_s")])
  per_ds <- do.call(rbind, lapply(split(s, paste(s$label, s$dataset)), function(d) {
    data.frame(label = d$label[[1L]], dataset = d$dataset[[1L]], r = med(d$run_peak_r_pss_mib),
               chrome = med(d$run_peak_chrome_pss_mib), start = med(d$server_start_s), stringsAsFactors = FALSE)
  }))
  do.call(rbind, lapply(split(per_ds, per_ds$label), function(d) {
    data.frame(label = d$label[[1L]], r_peak_mib = med(d$r), chrome_peak_mib = med(d$chrome),
               server_start_s = med(d$start), stringsAsFactors = FALSE)
  }))
}

verdict_row <- function(metric, scope, visit, base, cand, rule, verdict, note = "") {
  data.frame(metric = metric, scope = scope, visit = visit, baseline = base, candidate = cand,
             delta_pct = if (is.na(base) || base == 0) NA_real_ else round((cand / base - 1) * 100, 1),
             rule = rule, verdict = verdict, note = note, stringsAsFactors = FALSE)
}

latency_verdict <- function(base, cand, rel, floor) {
  if (is.na(base) || is.na(cand)) return("SKIP")
  if (cand > base * (1 + rel) + floor) "FAIL" else if (cand < base * (1 - rel) - floor) "IMPROVED" else "PASS"
}

# Compare candidate with baseline, measured in the same run. `pol` is one row of policy.tsv.
# Returns list(verdict = PASS|FAIL|INVALID, invalid = reasons, table = rows, pages = per page).
judge <- function(raw, pol, baseline, candidate, canary_ratio = NA_real_, plan = NULL, server = NULL) {
  rows <- list()
  add <- function(...) rows[[length(rows) + 1L]] <<- verdict_row(...)
  invalid <- character()

  rounds <- tapply(raw$round, raw$label, function(x) length(unique(x)))
  if (!all(c(baseline, candidate) %in% names(rounds))) invalid <- c(invalid, "baseline or candidate has no observations")
  else if (any(rounds[c(baseline, candidate)] < pol$rounds)) {
    invalid <- c(invalid, sprintf("fewer than %d rounds (have %s)", pol$rounds, paste(rounds[c(baseline, candidate)], collapse = "/")))
  }
  cells <- cell_table(raw)
  base_cells <- cells[cells$label == baseline, ]
  cand_cells <- cells[cells$label == candidate, ]
  if (length(unique(cand_cells$page)) < pol$min_pages) {
    invalid <- c(invalid, sprintf("fewer than %d pages measured on the candidate", pol$min_pages))
  }
  if (!is.na(canary_ratio) && canary_ratio > pol$canary_max_ratio) {
    invalid <- c(invalid, sprintf("machine noise: canary drifted x%.2f (limit x%.2f)", canary_ratio, pol$canary_max_ratio))
  }

  m <- merge(base_cells, cand_cells, by = c("dataset", "page", "visit"), suffixes = c(".b", ".c"))
  # 1. Completion: a page that finished on the baseline must finish on the candidate.
  for (i in which(m$ok_frac.b == 1 & m$ok_frac.c < 1)) {
    add("completion", paste(m$dataset[i], m$page[i], sep = "/"), m$visit[i], 1, m$ok_frac.c[i], "ok on baseline", "FAIL",
        sprintf("did not finish on the candidate (%s)", m$not_ok.c[i]))
  }
  for (i in which(m$ok_frac.b < 1)) {
    add("completion", paste(m$dataset[i], m$page[i], sep = "/"), m$visit[i], m$ok_frac.b[i], m$ok_frac.c[i], "baseline did not finish",
        "SKIP", "excluded: the baseline itself does not finish here")
  }
  ok <- m[m$ok_frac.b == 1 & m$ok_frac.c == 1, ]
  # A planned page that the baseline measured but the candidate did not has disappeared.
  if (!is.null(plan)) {
    have <- function(cells) paste(cells$dataset, cells$page)
    for (i in seq_len(nrow(plan))) {
      key <- paste(plan$dataset[i], plan$page[i])
      if (key %in% have(base_cells) && !key %in% have(cand_cells)) {
        add("completion", paste(plan$dataset[i], plan$page[i], sep = "/"), "-", NA, NA, "page measured on the baseline", "FAIL", "page is missing on the candidate")
      }
    }
  }

  # 2. Latency per page and visit: median over datasets of the per-dataset medians.
  pages <- NULL
  for (v in standard_visits) {
    for (p in unique(ok$page[ok$visit == v])) {
      d <- ok[ok$visit == v & ok$page == p, ]
      bb <- med(d$visual_complete_ms.b); cc <- med(d$visual_complete_ms.c)
      rule <- sprintf("visual_complete_ms > base x %.2f + %d ms", 1 + pol$latency_rel, pol$latency_floor_ms)
      lv <- latency_verdict(bb, cc, pol$latency_rel, pol$latency_floor_ms)
      note <- sprintf("%d datasets", nrow(d))
      # An action that picked a different value on the two revisions (another gene, another colour
      # column) did not do the same work, so it is reported, not judged.
      if (any(d$arg.b != d$arg.c)) {
        if (lv == "FAIL") lv <- "REPORT"
        note <- sprintf("different argument: %s vs %s", paste(d$arg.b, collapse = ","), paste(d$arg.c, collapse = ","))
      }
      add("visual_complete_ms", p, v, bb, cc, rule, lv, note)
      add("visual_90_ms", p, v, med(d$visual_90_ms.b), med(d$visual_90_ms.c), "reported", "REPORT")
      add("settled_ms", p, v, med(d$settled_ms.b), med(d$settled_ms.c), "diagnostic", "REPORT")
      lb <- med(d$loader_visible_ms.b); lc <- med(d$loader_visible_ms.c)
      add("loader_visible_ms", p, v, lb, lc, sprintf("loader > base + %d ms", pol$loader_floor_ms),
          if (is.na(lb) || is.na(lc)) "SKIP" else if (lc > lb + pol$loader_floor_ms) "FAIL" else "PASS")
      # 3. Budgets: pass on the baseline, fail on the candidate is a regression.
      budget <- page_budget_ms(p, v)
      # Only a clear crossing counts: a page that sits right at the budget moves across it with noise.
      if (!is.na(budget) && v != "initial" && !is.na(bb) && !is.na(cc) && bb < budget && cc >= budget + pol$latency_floor_ms) {
        add("budget", p, v, bb, cc, sprintf("< %d ms (+ %d ms tolerance)", budget, pol$latency_floor_ms), "FAIL", "crosses the page budget")
      }
      # Where the page stands against its budget is always reported (it is the 3-second target).
      if (!is.na(budget) && v != "initial" && !is.na(cc) && cc >= budget) {
        add("over_budget", p, v, bb, cc, sprintf("< %d ms", budget), "REPORT", "candidate is over the page budget")
      }
      pages <- rbind(pages, data.frame(page = p, visit = v, datasets = nrow(d), base_visual_ms = bb, cand_visual_ms = cc,
                                       base_visual_90_ms = med(d$visual_90_ms.b), cand_visual_90_ms = med(d$visual_90_ms.c),
                                       base_loader_ms = lb, cand_loader_ms = lc,
                                       base_js_mib = med(d$js_peak_mib.b), cand_js_mib = med(d$js_peak_mib.c), stringsAsFactors = FALSE))
    }
  }

  # 4. Memory: reported at L0/L1, gated at L2.
  mem <- memory_table(raw)
  mb <- mem[mem$label == baseline, ]; mc <- mem[mem$label == candidate, ]
  if (nrow(mb) && nrow(mc)) {
    for (k in c("r_peak_mib", "chrome_peak_mib")) {
      verdict <- latency_verdict(mb[[k]], mc[[k]], pol$mem_rel, pol$mem_floor_mib)
      if (verdict == "FAIL" && !isTRUE(pol$mem_gate == 1)) verdict <- "REPORT"
      add(k, "session", "-", mb[[k]], mc[[k]], if (isTRUE(pol$mem_gate == 1)) sprintf("> base x %.2f + %d MiB", 1 + pol$mem_rel, pol$mem_floor_mib) else "reported",
          verdict)
    }
  }
  # 5. Server steps (server_steps.R): reported, with a note when the two revisions return different results.
  srv <- if (!is.null(server) && nrow(server)) server_table(server) else NULL
  if (!is.null(srv)) {
    sm <- merge(srv[srv$label == baseline, ], srv[srv$label == candidate, ], by = c("dataset", "step"), suffixes = c(".b", ".c"))
    for (i in seq_len(nrow(sm))) {
      note <- if (sm$status.b[i] != "ok" || sm$status.c[i] != "ok") sprintf("status %s / %s", sm$status.b[i], sm$status.c[i])
              else if (sm$hash.b[i] != sm$hash.c[i]) "results differ between the revisions" else ""
      add("server_ms", paste(sm$dataset[i], sm$step[i], sep = "/"), "-", sm$ms.b[i], sm$ms.c[i], "reported", "REPORT", note)
    }
  }
  tab <- if (length(rows)) do.call(rbind, rows) else verdict_row("none", "-", "-", NA, NA, "-", "SKIP")
  # A loading card is a shared mechanism: a real regression shows on several pages at once, noise on one
  # (the card appears only if the page is not ready after 180 ms, so a page near that line flips between 0 and 150 ms).
  lf <- tab$metric == "loader_visible_ms" & tab$verdict == "FAIL"
  if (sum(lf) < pol$loader_min_pages) {
    tab$verdict[lf] <- "REPORT"; tab$note[lf] <- "not corroborated by another page"
  }
  overall <- if (length(invalid)) "INVALID" else if (any(tab$verdict == "FAIL")) "FAIL" else "PASS"
  list(verdict = overall, invalid = invalid, table = tab, pages = pages, memory = mem, server = srv)
}

# Server steps per label, dataset and step: median time over rounds, the worst status, and the result
# hash (one value when every round returned the same result).
server_table <- function(server) {
  key <- paste(server$label, server$dataset, server$step, sep = "")
  do.call(rbind, unname(lapply(split(server, key), function(d) {
    ok <- d$status == "ok"
    data.frame(label = d$label[[1L]], dataset = d$dataset[[1L]], step = d$step[[1L]],
               ms = if (any(ok)) med(d$ms[ok]) else NA_real_, value = if (any(ok)) med(d$value[ok]) else NA_real_,
               status = if (all(ok)) "ok" else paste(sort(unique(d$status[!ok])), collapse = ","),
               hash = paste(sort(unique(d$hash[ok])), collapse = ","), stringsAsFactors = FALSE)
  })))
}

verdict_exit_code <- function(verdict) c(PASS = 0L, FAIL = 1L, INVALID = 2L)[[verdict]]

# Numbers that go into runs/INDEX.tsv so a trend can be drawn without opening each run.
headline <- function(raw, label, pages = NULL) {
  cells <- cell_table(raw[raw$label == label, ])
  ok <- cells[cells$ok_frac == 1, ]
  g <- function(v) med(vapply(split(ok[ok$visit == v, ], ok$page[ok$visit == v]), function(d) med(d$visual_complete_ms), numeric(1)))
  mem <- memory_table(raw[raw$label == label, ])
  list(initial_visual_ms = g("initial"), first_visual_ms = g("first"), repeat_visual_ms = g("repeat"),
       unfinished_cells = sum(cells$ok_frac < 1), r_peak_mib = mem$r_peak_mib, chrome_peak_mib = mem$chrome_peak_mib)
}

fmt_num <- function(x) ifelse(is.na(x), "-", format(round(x), big.mark = ","))

write_summary <- function(path, info, result) {
  t <- result$table
  lines <- c(
    sprintf("# Viewer performance run %s", info$run_id), "",
    sprintf("**Verdict: %s** (tier %s, contract %s)", result$verdict, info$tier, standard_contract), "",
    sprintf("- candidate `%s` (%s), baseline `%s` (%s)", info$candidate_ref, info$candidate_sha, info$baseline_ref, info$baseline_sha),
    sprintf("- %s rounds, datasets: %s", info$rounds, info$datasets),
    sprintf("- host %s, %s, R %s, %s", info$host, info$os, info$r_version, info$chrome), ""
  )
  if (length(result$invalid)) lines <- c(lines, "## Invalid evidence", "", paste0("- ", result$invalid), "")
  if (!is.null(info$plan)) {
    lines <- c(lines, "## Coverage", "", "Every page is measured once, on one dataset (coverage.tsv).", "",
               "| page | dataset |", "|---|---|", sprintf("| %s | %s |", info$plan$page, info$plan$dataset), "")
    if (length(info$uncovered)) lines <- c(lines, sprintf("Not measured, no dataset available: %s", paste(info$uncovered, collapse = ", ")), "")
  }
  over <- t[t$metric == "over_budget", ]
  fails <- t[t$verdict == "FAIL", ]
  if (nrow(fails)) {
    lines <- c(lines, "## Failures", "", "| metric | scope | visit | baseline | candidate | change | rule |", "|---|---|---|---:|---:|---:|---|",
               sprintf("| %s | %s | %s | %s | %s | %s%% | %s |", fails$metric, fails$scope, fails$visit, fmt_num(fails$baseline), fmt_num(fails$candidate),
                       ifelse(is.na(fails$delta_pct), "-", sprintf("%+.0f", fails$delta_pct)), fails$rule), "")
  }
  if (nrow(over)) {
    lines <- c(lines, "## Pages over their budget (first visit 2 s, 3 s for Trajectory and HLA; repeat visit 500 ms)", "",
               "| page | visit | baseline | candidate |", "|---|---|---:|---:|",
               sprintf("| %s | %s | %s | %s |", over$scope, over$visit, fmt_num(over$baseline), fmt_num(over$candidate)), "")
  }
  p <- result$pages
  if (!is.null(p)) {
    p <- p[order(match(p$visit, standard_visits), p$page), ]
    lines <- c(lines, "## Pages and actions (visual_complete_ms, ms)", "",
               "| page | visit | baseline | candidate | change | loader base | loader cand | JS heap base MiB | JS heap cand MiB |",
               "|---|---|---:|---:|---:|---:|---:|---:|---:|",
               sprintf("| %s | %s | %s | %s | %+.0f%% | %s | %s | %s | %s |", p$page, p$visit, fmt_num(p$base_visual_ms), fmt_num(p$cand_visual_ms),
                       (p$cand_visual_ms / p$base_visual_ms - 1) * 100, fmt_num(p$base_loader_ms), fmt_num(p$cand_loader_ms),
                       fmt_num(p$base_js_mib), fmt_num(p$cand_js_mib)), "")
  }
  srv <- t[t$metric == "server_ms", ]
  if (nrow(srv)) {
    lines <- c(lines, "## Server steps (ms, median over rounds; reported, not judged)", "",
               "| dataset/step | baseline | candidate | change | note |", "|---|---:|---:|---:|---|",
               sprintf("| %s | %s | %s | %s | %s |", srv$scope, fmt_num(srv$baseline), fmt_num(srv$candidate),
                       ifelse(is.na(srv$delta_pct), "-", sprintf("%+.0f%%", srv$delta_pct)), srv$note), "")
  }
  m <- result$memory
  if (!is.null(m) && nrow(m)) {
    lines <- c(lines, "## Memory (session peak, PSS, median over datasets)", "", "| label | R tree MiB | Chrome tree MiB | R start s |", "|---|---:|---:|---:|",
               sprintf("| %s | %s | %s | %.1f |", m$label, fmt_num(m$r_peak_mib), fmt_num(m$chrome_peak_mib), m$server_start_s), "")
  }
  writeLines(lines, path)
}

index_columns <- c("run_id", "utc", "tier", "platform", "candidate_ref", "candidate_sha", "baseline_ref", "baseline_sha", "verdict",
                   "rounds", "datasets", "cand_initial_visual_ms", "cand_first_visual_ms", "cand_repeat_visual_ms",
                   "base_initial_visual_ms", "base_first_visual_ms", "base_repeat_visual_ms", "cand_r_peak_mib", "cand_chrome_peak_mib",
                   "unfinished_cells_cand", "path")

append_index <- function(index_path, row) {
  stopifnot(setequal(names(row), index_columns))
  row <- row[index_columns]
  new <- !file.exists(index_path)
  utils::write.table(as.data.frame(row, stringsAsFactors = FALSE), index_path, sep = "\t", quote = FALSE, row.names = FALSE,
                     col.names = new, append = !new)
}

# SHA of the candidate of the newest recorded run of a tier (for --track and --baseline auto).
last_recorded_sha <- function(index_path, tier) {
  if (!file.exists(index_path)) return(NA_character_)
  idx <- utils::read.delim(index_path, stringsAsFactors = FALSE, colClasses = "character")
  idx <- idx[idx$tier == tier & idx$verdict != "INVALID", ]
  if (!nrow(idx)) NA_character_ else idx$candidate_sha[[nrow(idx)]]
}
