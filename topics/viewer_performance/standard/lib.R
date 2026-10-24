# Pure functions of the Viewer performance standard: policy, aggregation, the verdict and the
# records it writes. No browser and no R app here, so they are unit tested
# (topics/viewer_performance/tests/test-standard.R). The rules are in ../STANDARD.md.

standard_contract <- "blackbox-v4"
standard_metrics <- c("visual_complete_ms", "visual_90_ms", "settled_ms", "loader_visible_ms", "visible_ms", "js_peak_mib",
                      "server_busy_ms", "chrome_busy_ms", "trail_ms", "ws_in_bytes", "ws_out_bytes", "ws_max_msg_bytes")
# initial      Data info loading the dataset (journey session)
# cold         a page opened in a fresh server and Chrome, after Data info only: pays its own first-use cost
# journey      a page opened in sidebar order in one session: what it costs depends on the pages before it
# repeat       the same page again, right after going back to Data info (cold session)
# revisit_after_tour  the page again after the whole journey (journey session)
# action       one thing done on an open page (actions.tsv, journey session)
standard_visits <- c("initial", "cold", "journey", "repeat", "revisit_after_tour", "action")
first_visits <- c("cold", "journey")
slow_pages <- c("hla_tcr_motifs", "trajectory")

# Quiet: below this many CPU seconds per second, over 1 s, for each tree (R server, Chrome), for
# quiet_need_s seconds in a row. Headless Chrome uses 0.1-0.2 of a core while idle (software rendering).
quiet_thr <- c(r = 0.05, chrome = 0.25)
quiet_need_s <- 3

# Start (ms) of the quiet stretch that lasts to the last sample. `t` are sample times (ms), `cpu` the
# cumulative CPU seconds, one column per tree, `thr` the threshold per column. A 1 s window ending at a
# sample is noisy when any tree used `thr` or more of a core in it. Only windows ending at or after `from`
# count. NA when the last window is noisy or no window is complete yet.
quiet_from <- function(t, cpu, thr, window_ms = 1000, from = t[[1L]]) {
  cpu <- as.matrix(cpu)
  ends <- which(t - t[[1L]] >= window_ms & t >= from)
  if (!length(ends)) return(NA_real_)
  noisy <- rep(FALSE, length(ends))
  for (j in seq_len(ncol(cpu))) {
    before <- stats::approx(t, cpu[, j], t[ends] - window_ms, rule = 2, ties = max)$y
    noisy <- noisy | (cpu[ends, j] - before) / (window_ms / 1000) >= thr[[j]]
  }
  if (noisy[[length(noisy)]]) return(NA_real_)
  if (!any(noisy)) return(max(from, t[[ends[[1L]]]] - window_ms))
  max(from, t[[ends[[max(which(noisy)) + 1L]]]] - window_ms)
}

# How long a tree kept working after a click: from `t_click` to the start of its quiet stretch that
# reaches `t_stop` (when the harness had seen both trees quiet for quiet_need_s). A pause shorter than that
# (R waiting while Chrome draws, then sending a large message) is part of the work. NA when the tree was
# still busy at `t_stop`.
busy_ms <- function(t, cpu, t_click, t_stop, thr, window_ms = 1000) {
  if (is.na(t_click) || is.na(t_stop)) return(NA_real_)
  keep <- t >= t_click - window_ms & t <= t_stop
  if (sum(keep) < 2L) return(NA_real_)
  q <- quiet_from(t[keep], cpu[keep], thr, window_ms, from = t_click)
  if (is.na(q)) NA_real_ else q - t_click
}

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
  p <- utils::read.delim(path, stringsAsFactors = FALSE, colClasses = c(calibrated_by = "character"))
  stats::setNames(lapply(seq_len(nrow(p)), function(i) as.list(p[i, ])), p$tier)
}

# ---- what is measured where ------------------------------------------------------------------------
# coverage.tsv says, per page, which large dataset it is measured on and which demo CRB stands in when
# that dataset is not given. Every page is measured on exactly one dataset per run: a page that
# does not depend on the data (About, Gene ID conversion) is not repeated on every dataset.
read_coverage <- function(path) utils::read.delim(path, stringsAsFactors = FALSE)

# A page uses its large dataset when that was given on the command line and its demo CRB otherwise.
# Pages with no dataset are returned in attr "uncovered".
build_plan <- function(coverage, large_available = character(), demos_available = character()) {
  rows <- lapply(seq_len(nrow(coverage)), function(i) {
    cv <- coverage[i, ]
    ds <- if (cv$fixture != "-" && cv$fixture %in% large_available) cv$fixture
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

# Page budgets (STANDARD.md): first visit (cold, journey) 2 s (3 s for Trajectory and HLA), repeat visit
# (repeat, revisit_after_tour) 500 ms. Data info's initial load and actions have no budget yet.
page_budget_ms <- function(page, visit) {
  if (visit %in% first_visits) { if (page %in% slow_pages) 3000 else 2000 }
  else if (visit %in% c("repeat", "revisit_after_tour")) 500 else NA_real_
}

# What a page is held against its budget: the later of the screen looking final and the server going
# quiet, because a user who clicks on waits for both.
budget_time_ms <- function(visual, busy) ifelse(is.na(busy), visual, pmax(visual, busy, na.rm = TRUE))

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
      sb <- med(d$server_busy_ms.b); sc <- med(d$server_busy_ms.c)
      add("server_busy_ms", p, v, sb, sc, "reported; counts towards the budget", "REPORT")
      add("trail_ms", p, v, med(d$trail_ms.b), med(d$trail_ms.c), "reported", "REPORT")
      add("ws_max_msg_bytes", p, v, med(d$ws_max_msg_bytes.b), med(d$ws_max_msg_bytes.c), "reported", "REPORT")
      lb <- med(d$loader_visible_ms.b); lc <- med(d$loader_visible_ms.c)
      add("loader_visible_ms", p, v, lb, lc, sprintf("loader > base + %d ms", pol$loader_floor_ms),
          if (is.na(lb) || is.na(lc)) "SKIP" else if (lc > lb + pol$loader_floor_ms) "FAIL" else "PASS")
      # 3. Budgets, on the later of visual completion and the server going quiet: pass on the baseline,
      # fail on the candidate is a regression.
      budget <- page_budget_ms(p, v)
      tb <- budget_time_ms(bb, sb); tc <- budget_time_ms(cc, sc)
      by <- if (!is.na(sc) && !is.na(cc) && sc > cc) "server_busy_ms" else "visual_complete_ms"
      # Only a clear crossing counts: a page that sits right at the budget moves across it with noise.
      if (!is.na(budget) && !is.na(tb) && !is.na(tc) && tb < budget && tc >= budget + pol$latency_floor_ms) {
        add("budget", p, v, tb, tc, sprintf("< %d ms (+ %d ms tolerance)", budget, pol$latency_floor_ms), "FAIL",
            sprintf("crosses the page budget (%s)", by))
      }
      # Where the page stands against its budget is always reported (it is the 3-second target).
      if (!is.na(budget) && !is.na(tc) && tc >= budget) {
        add("over_budget", p, v, tb, tc, sprintf("< %d ms", budget), "REPORT", sprintf("candidate is over the page budget (%s)", by))
      }
      pages <- rbind(pages, data.frame(page = p, visit = v, datasets = nrow(d), base_visual_ms = bb, cand_visual_ms = cc,
                                       base_visual_90_ms = med(d$visual_90_ms.b), cand_visual_90_ms = med(d$visual_90_ms.c),
                                       base_busy_ms = sb, cand_busy_ms = sc,
                                       base_trail_ms = med(d$trail_ms.b), cand_trail_ms = med(d$trail_ms.c),
                                       base_ws_max = med(d$ws_max_msg_bytes.b), cand_ws_max = med(d$ws_max_msg_bytes.c),
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
  list(verdict = overall, invalid = invalid, table = tab, pages = pages, memory = mem, server = srv,
       journey = journey_order(raw, candidate))
}

# The order in which a label's journey session opened the pages, per dataset (its first round): a journey
# visit pays for what the pages before it did not load yet, so its number belongs to this order.
journey_order <- function(raw, label) {
  j <- raw[raw$label == label & raw$visit == "journey", ]
  if (!nrow(j) || is.null(j$seq)) return(NULL)
  j <- j[j$round == min(j$round), ]
  do.call(rbind, unname(lapply(split(j, j$dataset), function(d) {
    data.frame(dataset = d$dataset[[1L]], order = paste(d$page[order(d$seq)], collapse = " -> "), stringsAsFactors = FALSE)
  })))
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

# One revision only (--solo): its times per page and visit, nothing judged. The evidence checks of
# judge() still apply (rounds, pages, machine noise), so an INVALID run is not recorded.
# Returns list(verdict = RECORDED|INVALID, invalid, pages, memory, server).
record_only <- function(raw, pol, label, canary_ratio = NA_real_, server = NULL) {
  invalid <- character()
  raw <- raw[raw$label == label, ]
  n_rounds <- length(unique(raw$round))
  if (n_rounds < pol$rounds) invalid <- c(invalid, sprintf("fewer than %d rounds (have %d)", pol$rounds, n_rounds))
  cells <- if (nrow(raw)) cell_table(raw) else NULL
  if (is.null(cells) || length(unique(cells$page)) < pol$min_pages) invalid <- c(invalid, sprintf("fewer than %d pages measured", pol$min_pages))
  if (!is.na(canary_ratio) && canary_ratio > pol$canary_max_ratio) {
    invalid <- c(invalid, sprintf("machine noise: canary drifted x%.2f (limit x%.2f)", canary_ratio, pol$canary_max_ratio))
  }
  pages <- NULL
  if (!is.null(cells)) {
    pages <- data.frame(page = cells$page, visit = cells$visit, dataset = cells$dataset, rounds_ok = round(cells$ok_frac * cells$n),
                        rounds = cells$n, not_ok = cells$not_ok, visual_ms = cells$visual_complete_ms, visual_90_ms = cells$visual_90_ms,
                        busy_ms = cells$server_busy_ms, trail_ms = cells$trail_ms, ws_max = cells$ws_max_msg_bytes,
                        loader_ms = cells$loader_visible_ms, js_mib = cells$js_peak_mib, stringsAsFactors = FALSE)
    pages$budget_ms <- mapply(page_budget_ms, pages$page, pages$visit)
    pages <- pages[order(match(pages$visit, standard_visits), pages$page), ]
    rownames(pages) <- NULL
  }
  srv <- if (!is.null(server) && nrow(server)) server_table(server[server$label == label, ]) else NULL
  list(verdict = if (length(invalid)) "INVALID" else "RECORDED", invalid = invalid, table = NULL, pages = pages,
       memory = if (nrow(raw)) memory_table(raw) else NULL, server = srv, journey = journey_order(raw, label))
}

verdict_exit_code <- function(verdict) c(PASS = 0L, RECORDED = 0L, FAIL = 1L, INVALID = 2L)[[verdict]]

# Numbers that go into runs/INDEX.tsv so a trend can be drawn without opening each run.
headline <- function(raw, label, pages = NULL) {
  cells <- cell_table(raw[raw$label == label, ])
  ok <- cells[cells$ok_frac == 1, ]
  g <- function(v) med(vapply(split(ok[ok$visit == v, ], ok$page[ok$visit == v]), function(d) med(d$visual_complete_ms), numeric(1)))
  mem <- memory_table(raw[raw$label == label, ])
  list(initial_visual_ms = g("initial"), cold_visual_ms = g("cold"), repeat_visual_ms = g("repeat"),
       unfinished_cells = sum(cells$ok_frac < 1), r_peak_mib = mem$r_peak_mib, chrome_peak_mib = mem$chrome_peak_mib)
}

fmt_num <- function(x) ifelse(is.na(x), "-", format(round(x), big.mark = ","))
fmt_mb <- function(x) ifelse(is.na(x), "-", ifelse(x < 1e5, "<0.1", sprintf("%.1f", x / 1e6)))

budget_line <- "Budget: first visit (cold, journey) 2 s, 3 s for Trajectory and HLA; repeat visit (repeat, revisit_after_tour) 500 ms. A page is held against it with the later of visual_complete_ms and server_busy_ms."

journey_lines <- function(j) {
  if (is.null(j) || !nrow(j)) return(character())
  c("## Journey order", "", "The journey visits opened the pages in this order, one session per dataset; each pays for what the pages before it did not load.", "",
    sprintf("- %s: %s", j$dataset, j$order), "")
}

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
    lines <- c(lines, "## Coverage", "", "Every page is measured on one dataset (coverage.tsv): cold in a session of its own, and in the journey.", "",
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
    lines <- c(lines, "## Pages over their budget", "", budget_line, "",
               "| page | visit | baseline | candidate | held by |", "|---|---|---:|---:|---|",
               sprintf("| %s | %s | %s | %s | %s |", over$scope, over$visit, fmt_num(over$baseline), fmt_num(over$candidate),
                       sub("^.*\\((.*)\\)$", "\\1", over$note)), "")
  }
  lines <- c(lines, journey_lines(result$journey))
  p <- result$pages
  if (!is.null(p)) {
    p <- p[order(match(p$visit, standard_visits), p$page), ]
    lines <- c(lines, "## Pages and actions (ms, median over rounds)", "",
               "visual: the screen looks final. busy: the R server is quiet again. trail: R or Chrome kept working after the page was finished. ws max: the largest single websocket message (MB).", "",
               "| page | visit | visual base | visual cand | change | busy base | busy cand | trail base | trail cand | ws max base | ws max cand | loader base | loader cand | JS heap base MiB | JS heap cand MiB |",
               "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
               sprintf("| %s | %s | %s | %s | %+.0f%% | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |", p$page, p$visit,
                       fmt_num(p$base_visual_ms), fmt_num(p$cand_visual_ms), (p$cand_visual_ms / p$base_visual_ms - 1) * 100,
                       fmt_num(p$base_busy_ms), fmt_num(p$cand_busy_ms), fmt_num(p$base_trail_ms), fmt_num(p$cand_trail_ms),
                       fmt_mb(p$base_ws_max), fmt_mb(p$cand_ws_max), fmt_num(p$base_loader_ms), fmt_num(p$cand_loader_ms),
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

# Summary of a --solo run: the revision's own times, no comparison.
write_solo_summary <- function(path, info, result) {
  lines <- c(
    sprintf("# Viewer performance run %s", info$run_id), "",
    sprintf("**%s** (tier %s, contract %s, one revision only: times are recorded, nothing is judged)", result$verdict, info$tier, standard_contract), "",
    sprintf("- revision `%s` (%s)", info$candidate_ref, info$candidate_sha),
    sprintf("- %s rounds, datasets: %s", info$rounds, info$datasets),
    sprintf("- host %s, %s, R %s, %s", info$host, info$os, info$r_version, info$chrome), ""
  )
  if (length(result$invalid)) lines <- c(lines, "## Invalid evidence", "", paste0("- ", result$invalid), "")
  if (length(info$uncovered)) lines <- c(lines, sprintf("Not measured, no dataset available: %s", paste(info$uncovered, collapse = ", ")), "")
  lines <- c(lines, journey_lines(result$journey))
  p <- result$pages
  if (!is.null(p) && nrow(p)) {
    held <- budget_time_ms(p$visual_ms, p$busy_ms)
    over <- !is.na(p$budget_ms) & !is.na(held) & held >= p$budget_ms
    lines <- c(lines, "## Pages and actions (median over rounds, ms)", "",
               paste(budget_line, "Over budget is marked **over**."), "",
               "visual: the screen looks final. busy: the R server is quiet again. trail: R or Chrome kept working after the page was finished. ws max: the largest single websocket message (MB).", "",
               "| page | visit | dataset | finished | visual | visual_90 | busy | trail | ws max MB | loader | JS heap MiB | budget |",
               "|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|",
               sprintf("| %s | %s | %s | %d/%d%s | %s | %s | %s | %s | %s | %s | %s | %s |", p$page, p$visit, p$dataset, p$rounds_ok, p$rounds,
                       ifelse(nzchar(p$not_ok), paste0(" (", p$not_ok, ")"), ""), fmt_num(p$visual_ms), fmt_num(p$visual_90_ms),
                       fmt_num(p$busy_ms), fmt_num(p$trail_ms), fmt_mb(p$ws_max),
                       fmt_num(p$loader_ms), fmt_num(p$js_mib), ifelse(is.na(p$budget_ms), "-", ifelse(over, "**over**", "ok"))), "")
  }
  s <- result$server
  if (!is.null(s) && nrow(s)) {
    lines <- c(lines, "## Server steps (ms, median over rounds)", "", "| dataset/step | ms | status |", "|---|---:|---|",
               sprintf("| %s/%s | %s | %s |", s$dataset, s$step, fmt_num(s$ms), s$status), "")
  }
  m <- result$memory
  if (!is.null(m) && nrow(m)) {
    lines <- c(lines, "## Memory (session peak, PSS, median over datasets)", "", "| R tree MiB | Chrome tree MiB | R start s |", "|---:|---:|---:|",
               sprintf("| %s | %s | %.1f |", fmt_num(m$r_peak_mib), fmt_num(m$chrome_peak_mib), m$server_start_s), "")
  }
  writeLines(lines, path)
}

index_columns <- c("run_id", "utc", "tier", "platform", "candidate_ref", "candidate_sha", "baseline_ref", "baseline_sha", "verdict",
                   "rounds", "datasets", "cand_initial_visual_ms", "cand_cold_visual_ms", "cand_repeat_visual_ms",
                   "base_initial_visual_ms", "base_cold_visual_ms", "base_repeat_visual_ms", "cand_r_peak_mib", "cand_chrome_peak_mib",
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
