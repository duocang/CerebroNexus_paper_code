## Tests of topics/viewer_performance/standard/lib.R (policy, aggregation, verdict, records).

source(file.path("..", "standard", "lib.R"))
policy <- read_policy(file.path("..", "standard", "policy.tsv"))
## The synthetic runs below have three pages, so lower the page requirement; it is tested on its own.
policy <- lapply(policy, function(p) { p$min_pages <- 2L; p })

fake_raw <- function(labels = c("base", "cand"), datasets = paste0("d", 1:8), rounds = 3L,
                     pages = c("overview", "groups", "about"), ready = 800, status = "ok") {
  g <- expand.grid(label = labels, dataset = datasets, round = seq_len(rounds), page = pages,
                   visit = c("cold", "repeat"), stringsAsFactors = FALSE)
  g$status <- status
  g$visual_complete_ms <- ifelse(g$visit == "cold", ready, 100)
  g$visual_90_ms <- g$visual_complete_ms / 2
  g$settled_ms <- g$visual_complete_ms + 50
  g$loader_visible_ms <- 0
  g$visible_ms <- g$visual_complete_ms
  g$run_peak_r_pss_mib <- 1500
  g$run_peak_chrome_pss_mib <- 1000
  g$server_start_s <- 12
  g
}

test_that("identical measurements pass", {
  res <- judge(fake_raw(), policy$l1, "base", "cand")
  expect_identical(res$verdict, "PASS")
  expect_identical(verdict_exit_code(res$verdict), 0L)
  expect_false(any(res$table$verdict == "FAIL"))
})

test_that("a page that gets slower than the tolerance fails, a smaller change does not", {
  raw <- fake_raw()
  slow <- raw$label == "cand" & raw$page == "overview" & raw$visit == "cold"
  raw$visual_complete_ms[slow] <- 800 + 600
  res <- judge(raw, policy$l1, "base", "cand")
  expect_identical(res$verdict, "FAIL")
  failed <- res$table[res$table$verdict == "FAIL", ]
  expect_identical(failed$metric, "visual_complete_ms")
  expect_identical(failed$scope, "overview")

  raw <- fake_raw()
  raw$visual_complete_ms[raw$label == "cand" & raw$page == "overview" & raw$visit == "cold"] <- 800 + 90  # within 10% + 100 ms
  expect_identical(judge(raw, policy$l1, "base", "cand")$verdict, "PASS")
})

test_that("tolerance is wider at L0 than at L2", {
  raw <- fake_raw(rounds = 5L)
  raw$visual_complete_ms[raw$label == "cand" & raw$page == "groups" & raw$visit == "cold"] <- 800 + 500
  expect_identical(judge(raw, policy$l2, "base", "cand")$verdict, "FAIL")
  expect_identical(judge(raw[raw$round == 1, ], policy$l0, "base", "cand")$verdict, "PASS")
})

test_that("a page that finishes on the baseline but not on the candidate fails", {
  raw <- fake_raw()
  raw$status[raw$label == "cand" & raw$dataset == "d3" & raw$page == "groups" & raw$visit == "cold"] <- "stuck_busy"
  res <- judge(raw, policy$l1, "base", "cand")
  expect_identical(res$verdict, "FAIL")
  expect_true("completion" %in% res$table$metric[res$table$verdict == "FAIL"])
})

test_that("a page the baseline cannot finish is skipped, not blamed on the candidate", {
  raw <- fake_raw()
  both <- raw$dataset == "d2" & raw$page == "about"
  raw$status[both & raw$label == "base"] <- "timeout"
  raw$status[both & raw$label == "cand"] <- "timeout"
  res <- judge(raw, policy$l1, "base", "cand")
  expect_identical(res$verdict, "PASS")
  expect_true(any(res$table$verdict == "SKIP" & res$table$metric == "completion"))
})

test_that("a loading card on one page is only reported, on several pages it fails", {
  raw <- fake_raw()
  raw$loader_visible_ms[raw$label == "cand" & raw$page == "about" & raw$visit == "cold"] <- 400
  one <- judge(raw, policy$l1, "base", "cand")
  expect_identical(one$verdict, "PASS")
  expect_true(any(one$table$verdict == "REPORT" & one$table$metric == "loader_visible_ms"))
  raw$loader_visible_ms[raw$label == "cand" & raw$page == "groups" & raw$visit == "cold"] <- 400
  res <- judge(raw, policy$l1, "base", "cand")
  expect_identical(res$verdict, "FAIL")
  expect_identical(unique(res$table$metric[res$table$verdict == "FAIL"]), "loader_visible_ms")
})

test_that("crossing a page budget fails", {
  raw <- fake_raw(ready = 1950)
  raw$visual_complete_ms[raw$label == "cand" & raw$visit == "cold"] <- 2400  # +23%: inside the L0 latency tolerance, over the 2 s budget
  res <- judge(raw, policy$l0, "base", "cand")
  expect_true("budget" %in% res$table$metric[res$table$verdict == "FAIL"])
  expect_false("visual_complete_ms" %in% res$table$metric[res$table$verdict == "FAIL"])
  # right at the budget is noise, not a crossing
  raw$visual_complete_ms[raw$label == "cand" & raw$visit == "cold"] <- 2050
  expect_identical(judge(raw, policy$l0, "base", "cand")$verdict, "PASS")
})

test_that("missing rounds, datasets or a noisy machine make the evidence invalid", {
  expect_identical(judge(fake_raw(rounds = 2L), policy$l1, "base", "cand")$verdict, "INVALID")
  few <- policy$l1; few$min_pages <- 4L
  expect_identical(judge(fake_raw(), few, "base", "cand")$verdict, "INVALID")   # only three pages measured
  noisy <- judge(fake_raw(), policy$l1, "base", "cand", canary_ratio = 1.8)
  expect_identical(noisy$verdict, "INVALID")
  expect_match(noisy$invalid, "machine noise")
  expect_identical(verdict_exit_code("INVALID"), 2L)
})

test_that("memory is reported at L1 and gated at L2", {
  raw <- fake_raw(rounds = 5L)
  raw$run_peak_r_pss_mib[raw$label == "cand"] <- 2200
  expect_identical(judge(raw, policy$l1, "base", "cand")$verdict, "PASS")
  expect_identical(judge(raw, policy$l2, "base", "cand")$verdict, "FAIL")
})

test_that("every page is measured on exactly one dataset, on its large fixture when there is one", {
  coverage <- read_coverage(file.path("..", "standard", "coverage.tsv"))
  demos <- c("example", "demo_full_tcr_bcr", "demo_spatial_visium", "demo_trekker", "demo_hla_tcr_dextramer")
  expect_false(anyDuplicated(coverage$page) > 0)
  demo_plan <- build_plan(coverage, character(), demos)
  expect_false(anyDuplicated(demo_plan$page) > 0)
  expect_true(all(!demo_plan$large))
  expect_identical(demo_plan$dataset[demo_plan$page == "spatial"], "demo_spatial_visium")
  auto <- build_plan(coverage, c("mouse1m", "ren"), demos)
  expect_identical(auto$dataset[auto$page == "overview"], "mouse1m")                # the main large fixture
  expect_identical(auto$dataset[auto$page == "trajectory"], "mouse1m")
  expect_identical(auto$dataset[auto$page == "immune_repertoire"], "ren")           # only what the mouse brain lacks
  expect_identical(auto$dataset[auto$page == "spatial"], "demo_spatial_visium")     # cosmx absent: falls back
  expect_identical(auto$dataset[auto$page == "hla_tcr_motifs"], "demo_hla_tcr_dextramer")
  expect_true(all(auto$large[auto$dataset %in% c("mouse1m", "ren")]))
  expect_true(all(head(auto$large, sum(auto$large))))                               # large fixtures are scheduled first
  expect_false(anyDuplicated(auto$page) > 0)
  none <- build_plan(coverage, "ren", demos)                                # mouse brain not built yet
  expect_identical(none$dataset[none$page == "overview"], "example")                # a page does not move to another large fixture
  gone <- build_plan(coverage, character(), c("example"))
  expect_true("spatial" %in% attr(gone, "uncovered"))                               # a page with no dataset is reported
  expect_false("spatial" %in% gone$page)
})

test_that("budgets", {
  expect_equal(page_budget_ms("trajectory", "cold"), 3000)
  expect_equal(page_budget_ms("overview", "journey"), 2000)
  expect_equal(page_budget_ms("overview", "repeat"), 500)
  expect_equal(page_budget_ms("overview", "revisit_after_tour"), 500)
  expect_true(is.na(page_budget_ms("loadData", "initial")))
  expect_equal(budget_time_ms(c(800, 800, 800), c(2600, 300, NA)), c(2600, 800, 800))
})

## A CPU trace sampled every 150 ms: cumulative CPU seconds that grow at `rate` cores in each [from, to) ms.
cpu_trace <- function(spans, until = 20000, step = 150) {
  t <- seq(0, until, by = step)
  rate <- vapply(t, function(x) sum(vapply(spans, function(s) if (x >= s[[1L]] && x < s[[2L]]) s[[3L]] else 0, 0)), 0)
  list(t = t, cpu = cumsum(c(0, head(rate, -1L) * step / 1000)))
}

test_that("server busy time runs to the end of the work, across a short pause", {
  # Overview on the mouse brain: R draws for 4 s, pauses 1.2 s while Chrome draws, then sends a large
  # message for 6 s. The pause is part of the work; the quiet stretch after 11.2 s ends it.
  x <- cpu_trace(list(c(1000, 5000, 1), c(6200, 11200, 1)))
  b <- busy_ms(x$t, x$cpu, t_click = 1000, t_stop = 18000, thr = 0.05)
  expect_gt(b, 9800); expect_lt(b, 10400)
  # nothing to do on the server: quiet from the click
  idle <- cpu_trace(list())
  expect_equal(busy_ms(idle$t, idle$cpu, 1000, 8000, 0.05), 0)
  # a single tick of a timer is not work
  blip <- cpu_trace(list(c(1000, 2000, 1), c(4500, 4650, 0.07)))
  expect_lt(busy_ms(blip$t, blip$cpu, 1000, 9000, 0.05), 1300)
  # still busy when the harness stopped looking: unknown, not short
  long <- cpu_trace(list(c(1000, 20000, 1)))
  expect_true(is.na(busy_ms(long$t, long$cpu, 1000, 15000, 0.05)))
})

test_that("quiet needs every tree below its threshold", {
  r <- cpu_trace(list(c(0, 2000, 1)))
  chrome <- cpu_trace(list(c(0, 5000, 2), c(5000, 20000, 0.15)))   # idle Chrome still uses a little
  q <- quiet_from(r$t, cbind(r$cpu, chrome$cpu), c(0.05, 0.25))
  expect_gt(q, 4500); expect_lt(q, 5200)                            # Chrome was the last to finish
  expect_true(is.na(quiet_from(r$t[r$t < 900], cbind(r$cpu, chrome$cpu)[r$t < 900, ], c(0.05, 0.25))))  # no full window yet
})

test_that("a page whose server keeps working past the budget is over it, though it looks done", {
  raw <- fake_raw(ready = 800)
  raw$server_busy_ms <- 900
  raw$server_busy_ms[raw$label == "cand" & raw$page == "overview" & raw$visit == "cold"] <- 6000
  res <- judge(raw, policy$l1, "base", "cand")
  expect_identical(res$verdict, "FAIL")
  f <- res$table[res$table$verdict == "FAIL", ]
  expect_identical(f$metric, "budget")
  expect_match(f$note, "server_busy_ms")
  expect_true(any(res$table$metric == "over_budget" & res$table$scope == "overview"))
  expect_equal(res$pages$cand_busy_ms[res$pages$page == "overview" & res$pages$visit == "cold"], 6000)
  # the same server time on both revisions is reported, not a regression
  raw$server_busy_ms[raw$label == "base" & raw$page == "overview" & raw$visit == "cold"] <- 6000
  res <- judge(raw, policy$l1, "base", "cand")
  expect_identical(res$verdict, "PASS")
  expect_match(res$table$note[res$table$metric == "over_budget"][[1L]], "server_busy_ms")
})

test_that("the journey order is reported, and the summary shows busy, trail and the largest message", {
  raw <- fake_raw(datasets = "mouse1m", rounds = 3L)
  raw$server_busy_ms <- 900; raw$trail_ms <- 100; raw$ws_max_msg_bytes <- 29e6
  j <- raw[raw$visit == "cold", ]; j$visit <- "journey"
  j$seq <- match(j$page, c("overview", "groups", "about")) + 1L
  raw$seq <- NA_integer_
  raw <- rbind(raw, j)
  res <- judge(raw, policy$l1, "base", "cand")
  expect_identical(res$journey$order, "overview -> groups -> about")
  path <- tempfile(fileext = ".md")
  info <- list(run_id = "r", tier = "l1", candidate_ref = "a", candidate_sha = "a", baseline_ref = "b", baseline_sha = "b",
               rounds = 3, datasets = "mouse1m", host = "h", os = "o", r_version = "4.6.1", chrome = "c")
  write_summary(path, info, res)
  text <- paste(readLines(path), collapse = "\n")
  expect_match(text, "Journey order")
  expect_match(text, "mouse1m: overview -> groups -> about", fixed = TRUE)
  expect_match(text, "busy cand")
  expect_match(text, "| 29.0 |", fixed = TRUE)
  solo <- record_only(raw[raw$label == "cand", ], policy$l1, "cand")
  out <- tempfile(fileext = ".md")
  write_solo_summary(out, c(info, list(candidate_ref = "master")), solo)
  stext <- paste(readLines(out), collapse = "\n")
  expect_match(stext, "Journey order")
  expect_match(stext, "| busy | trail | ws max MB |", fixed = TRUE)
})

test_that("a planned page that the baseline measured and the candidate did not is a failure", {
  raw <- fake_raw()
  raw <- raw[!(raw$label == "cand" & raw$page == "about"), ]
  plan <- data.frame(page = c("overview", "groups", "about"), dataset = "d1", stringsAsFactors = FALSE)
  res <- judge(raw, policy$l1, "base", "cand", plan = plan)
  expect_identical(res$verdict, "FAIL")
  expect_true(any(res$table$note == "page is missing on the candidate"))
})

test_that("INDEX rows are appended in a fixed column order and newest SHA is found", {
  index <- tempfile(fileext = ".tsv")
  row <- as.list(setNames(rep("x", length(index_columns)), index_columns))
  row$tier <- "l1"; row$verdict <- "PASS"; row$candidate_sha <- "aaa111"
  append_index(index, rev(row))  # order must not matter
  row$candidate_sha <- "bbb222"
  append_index(index, row)
  row$verdict <- "INVALID"; row$candidate_sha <- "ccc333"
  append_index(index, row)
  expect_identical(colnames(read.delim(index)), index_columns)
  expect_identical(last_recorded_sha(index, "l1"), "bbb222")   # INVALID runs do not count
  expect_true(is.na(last_recorded_sha(index, "l2")))
  expect_error(append_index(index, row[-1]))
})

test_that("summary names failures and the evidence problems", {
  raw <- fake_raw()
  raw$visual_complete_ms[raw$label == "cand" & raw$page == "overview" & raw$visit == "cold"] <- 2000
  res <- judge(raw, policy$l1, "base", "cand", canary_ratio = 1.5)
  path <- tempfile(fileext = ".md")
  info <- list(run_id = "r", tier = "l1", candidate_ref = "pr", candidate_sha = "aaa", baseline_ref = "master", baseline_sha = "bbb",
               rounds = 3, datasets = "d1", host = "h", os = "o", r_version = "4.6.1", chrome = "c")
  write_summary(path, info, res)
  text <- paste(readLines(path), collapse = "\n")
  expect_match(text, "Verdict: INVALID")
  expect_match(text, "Invalid evidence")
  expect_match(text, "overview")
})

test_that("visual completion is the first frame that already looks final", {
  t <- c(50, 100, 150, 200, 250, 300, 350)
  sim <- c(0.20, 0.55, 0.92, 0.9999, 1, 1, 1)     # 0.9999 is within the 0.05% tolerance
  v <- visual_from_similarity(t, sim, t_click = 0)
  expect_equal(v$visual_complete_ms, 200)           # frame 4 is the first that matches the end
  expect_equal(v$visual_90_ms, 150)                 # frame 3 is the first at least 90% alike
  # a late repaint after a quiet spell moves the completion time
  sim2 <- c(0.2, 1, 1, 1, 0.97, 1, 1)
  expect_equal(visual_from_similarity(t, sim2, 0)$visual_complete_ms, 300)
  # nothing changed after the click: complete at the first frame
  expect_equal(visual_from_similarity(t, rep(1, 7), t_click = 20)$visual_complete_ms, 30)
  expect_true(is.na(visual_from_similarity(numeric(), numeric(), 0)$visual_complete_ms))
})

test_that("the large fixture is a dataset group of its own and over-budget pages are reported", {
  raw <- fake_raw(datasets = "ren", rounds = 5L, ready = 6000)
  res <- judge(raw, policy$l1, "base", "cand")
  expect_identical(res$verdict, "PASS")
  over <- res$table[res$table$metric == "over_budget", ]
  expect_true(nrow(over) > 0)
  expect_true(all(over$verdict == "REPORT"))
  path <- tempfile(fileext = ".md")
  info <- list(run_id = "r", tier = "l1", candidate_ref = "a", candidate_sha = "a", baseline_ref = "b", baseline_sha = "b",
               rounds = 5, datasets = "ren", host = "h", os = "o", r_version = "4.6.1", chrome = "c")
  write_summary(path, info, res)
  expect_match(paste(readLines(path), collapse = "
"), "Pages over their budget")
})

test_that("actions join the plan on the dataset of their page", {
  coverage <- read_coverage(file.path("..", "standard", "coverage.tsv"))
  actions <- read_actions(file.path("..", "standard", "actions.tsv"))
  demos <- c("example", "demo_full_tcr_bcr", "demo_spatial_visium", "demo_trekker", "demo_hla_tcr_dextramer")
  plan <- add_actions(build_plan(coverage, "mouse1m", demos), actions)
  expect_identical(plan$dataset[plan$page == "overview.colour_by"], "mouse1m")
  expect_identical(plan$dataset[plan$page == "geneExpression.gene"], "mouse1m")
  expect_false(anyDuplicated(plan$page) > 0)
  expect_true(all(startsWith(actions$action, paste0(actions$page, "."))))
  no_overview <- add_actions(data.frame(page = "about", dataset = "example", large = FALSE), actions)
  expect_identical(no_overview$page, "about")                                       # an action without its page is not planned
  expect_true(is.na(page_budget_ms("overview.zoom", "action")))
})

fake_actions <- function(arg_cand = "Gad1", status_cand = "ok") {
  raw <- fake_raw()
  a <- unique(raw[raw$page == "overview" & raw$visit == "cold", ])
  a$page <- "geneExpression.gene"; a$visit <- "action"; a$arg <- "Gad1"; a$visual_complete_ms <- 400
  a$arg[a$label == "cand"] <- arg_cand; a$status[a$label == "cand"] <- status_cand
  raw$arg <- NA_character_
  rbind(raw, a)
}

test_that("a slower action fails, unless the two revisions did different work", {
  raw <- fake_actions()
  expect_identical(judge(raw, policy$l1, "base", "cand")$verdict, "PASS")
  raw$visual_complete_ms[raw$label == "cand" & raw$visit == "action"] <- 1400
  res <- judge(raw, policy$l1, "base", "cand")
  expect_identical(res$verdict, "FAIL")
  expect_identical(res$table$scope[res$table$verdict == "FAIL"], "geneExpression.gene")
  raw <- fake_actions(arg_cand = "Snap25")
  raw$visual_complete_ms[raw$label == "cand" & raw$visit == "action"] <- 1400
  res <- judge(raw, policy$l1, "base", "cand")
  expect_identical(res$verdict, "PASS")
  expect_match(res$table$note[res$table$scope == "geneExpression.gene" & res$table$metric == "visual_complete_ms"], "different argument")
})

test_that("an error on screen or a missing control is not a finished page", {
  for (s in c("error", "unavailable")) {
    res <- judge(fake_actions(status_cand = s), policy$l1, "base", "cand")
    expect_identical(res$verdict, "FAIL")
    expect_match(res$table$note[res$table$metric == "completion"][[1L]], s)
  }
})

test_that("server steps are reported with their change and a note when results differ", {
  server <- expand.grid(label = c("base", "cand"), dataset = "example", round = 1:3, step = c("read_crb", "gene_block_12", "linked_bundle_build"),
                        stringsAsFactors = FALSE)
  server$ms <- ifelse(server$label == "cand", 300, 100); server$status <- "ok"; server$value <- NA_real_; server$hash <- "h"
  server$hash[server$step == "gene_block_12" & server$label == "cand"] <- "other"
  server$status[server$step == "linked_bundle_build" & server$label == "base"] <- "unavailable"
  res <- judge(fake_raw(), policy$l1, "base", "cand", server = server)
  expect_identical(res$verdict, "PASS")                                             # reported, never judged
  s <- res$table[res$table$metric == "server_ms", ]
  expect_equal(s$delta_pct[s$scope == "example/read_crb"], 200)
  expect_identical(s$note[s$scope == "example/gene_block_12"], "results differ between the revisions")
  expect_match(s$note[s$scope == "example/linked_bundle_build"], "unavailable")
  path <- tempfile(fileext = ".md")
  info <- list(run_id = "r", tier = "l1", candidate_ref = "a", candidate_sha = "a", baseline_ref = "b", baseline_sha = "b",
               rounds = 3, datasets = "example", host = "h", os = "o", r_version = "4.6.1", chrome = "c")
  write_summary(path, info, res)
  expect_match(paste(readLines(path), collapse = "\n"), "Server steps")
})

test_that("a solo run records one revision's times without a verdict", {
  raw <- fake_raw(labels = "cand", datasets = "d1", rounds = 5L, ready = 2500)
  res <- record_only(raw, policy$l2, "cand")
  expect_identical(res$invalid, character())
  expect_identical(verdict_exit_code("RECORDED"), 0L)
  expect_identical(res$verdict, "RECORDED")
  first <- res$pages[res$pages$visit == "cold", ]
  expect_identical(nrow(first), 3L)
  expect_equal(first$visual_ms, rep(2500, 3))
  expect_equal(first$budget_ms, rep(2000, 3))
  expect_equal(res$memory$r_peak_mib, 1500)
  out <- tempfile(fileext = ".md")
  write_solo_summary(out, list(run_id = "x", tier = "l2", candidate_ref = "master", candidate_sha = "abc", rounds = 5,
                               datasets = "d1", host = "h", os = "o", r_version = "r", chrome = "c"), res)
  expect_true(any(grepl("**over**", readLines(out), fixed = TRUE)))
})

test_that("a solo run with too few rounds is invalid", {
  res <- record_only(fake_raw(labels = "cand", rounds = 2L), policy$l2, "cand")
  expect_identical(res$verdict, "INVALID")
})
