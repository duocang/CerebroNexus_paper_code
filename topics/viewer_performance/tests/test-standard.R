# Unit tests of the pure functions in standard/lib.R: the plan, the run folder name, aggregation, the
# summary and the comparison of two runs. Run from the repository root:
#   Rscript -e 'testthat::test_dir("topics/viewer_performance/tests")'
source(file.path("..", "standard", "lib.R"))

tsv <- function(name) read_tsv(file.path("..", "standard", name))

obs <- function(page, visit = "cold", visual = 1000, status = "ok", dataset = "1m", round = 1L, arg = NA_character_, session = NULL, ...) {
  d <- data.frame(dataset = dataset, round = round, session = if (is.null(session)) paste(dataset, page, round) else session,
                  page = page, visit = visit, status = status, arg = arg, visual_complete_ms = visual, stringsAsFactors = FALSE)
  for (m in setdiff(standard_metrics, names(d))) d[[m]] <- 100
  d$run_peak_r_mib <- 2000; d$run_peak_chrome_mib <- 500; d$server_start_s <- 10
  extra <- list(...)
  for (n in names(extra)) d[[n]] <- extra[[n]]
  d
}

test_that("the shipped plan measures every page exactly once, on 1m, ren, cosmx or a demo", {
  cov <- tsv("coverage.tsv"); act <- tsv("actions.tsv"); fx <- tsv("fixtures.tsv")
  expect_false(anyDuplicated(cov$page) > 0)
  expect_setequal(fx$name, c("1m", "ren", "cosmx"))
  expect_false(any(grepl("^(/|[A-Za-z]:)", fx$crb)))   # paths below --large-examples, never absolute
  plan <- build_plan(cov, act, fx$name, c("example", "demo_trekker"))
  expect_equal(nrow(plan), nrow(cov))
  expect_length(attr(plan, "uncovered"), 0L)
  expect_equal(plan$dataset[plan$page == "overview"], "1m")
  expect_equal(plan$dataset[plan$page == "immune_repertoire"], "ren")
  expect_equal(plan$dataset[plan$page == "spatial"], "cosmx")
  expect_true(all(plan$large[plan$dataset %in% fx$name]))
  # large fixtures first, in the order of fixtures.tsv
  expect_equal(unique(plan$dataset)[1:3], c("1m", "ren", "cosmx"))
  expect_equal(plan$actions[plan$page == "overview"], "overview.colour_by,overview.zoom,overview.lasso")
  # every action in actions.tsv is implemented in hook.js
  hook <- paste(readLines(file.path("..", "standard", "hook.js")), collapse = "\n")
  for (a in act$action) expect_true(grepl(sprintf("'%s'", a), hook, fixed = TRUE), info = a)
})

test_that("a page listed twice, or an action of an unknown page, stops the plan", {
  expect_error(build_plan(data.frame(page = c("a", "a"), dataset = "x"), data.frame(action = character(), page = character())), "twice")
  expect_error(build_plan(data.frame(page = "a", dataset = "x"), data.frame(action = "b.go", page = "b")), "does not")
})

test_that("a demo the revision does not ship is not measured but listed", {
  plan <- build_plan(data.frame(page = c("overview", "trekker"), dataset = c("1m", "demo_trekker")),
                     data.frame(action = "trekker.colour_by", page = "trekker"), "1m", "example")
  expect_equal(plan$page, "overview")
  expect_equal(attr(plan, "uncovered"), "trekker")
})

test_that("--pages keeps only those pages and rejects unknown ones", {
  plan <- build_plan(data.frame(page = c("overview", "groups", "about"), dataset = "1m"), data.frame(action = character(), page = character()), "1m")
  expect_equal(subset_plan(plan, c("about", "overview"))$page, c("overview", "about"))
  expect_error(subset_plan(plan, "nope"), "not in the plan")
})

test_that("all fixtures must exist below --large-examples", {
  root <- tempfile(); dir.create(file.path(root, "1m"), recursive = TRUE)
  file.create(file.path(root, "1m", "a.crb"))
  fx <- data.frame(name = c("1m", "ren"), crb = c("1m/a.crb", "ren/b.crb"))
  expect_error(fixture_paths(fx, root), "ren")
  expect_error(fixture_paths(fx, file.path(root, "nope")), "no such directory")
  p <- fixture_paths(fx[1, ], root)
  expect_named(p, "1m")
  expect_true(file.exists(p[["1m"]]))
})

test_that("the run folder names the CerebroNexus version and the date", {
  t <- as.POSIXct("2026-10-29 19:23:05", tz = "UTC")
  expect_equal(run_dir_name("5.4.0", "1a2b3c4d5e6f", t), "cerebronexus-5.4.0_20261029-192305_1a2b3c4")
  expect_equal(run_dir_name("5.4.0", "1a2b3c4d5e6f", t, partial = TRUE), "cerebronexus-5.4.0_20261029-192305_1a2b3c4_partial")
  # the baseline of a noise check measures the same revision at the same time: a tag keeps the folders apart
  expect_equal(run_dir_name("5.4.0", "1a2b3c4d5e6f", t, partial = TRUE, tag = "base"), "cerebronexus-5.4.0_20261029-192305_1a2b3c4_base_partial")
  f <- tempfile(); writeLines(c("Package: CerebroNexus", "Version: 5.4.0"), f)
  expect_equal(description_version(f), "5.4.0")
})

test_that("pages are medians over the rounds that finished, with the range", {
  raw <- rbind(obs("overview", visual = 1000, round = 1L), obs("overview", visual = 3000, round = 2L), obs("overview", visual = 9000, round = 3L, status = "timeout"),
               obs("overview.zoom", "action", visual = 200, arg = "in"))
  p <- page_table(raw)
  expect_equal(p$page, c("overview", "overview.zoom"))
  expect_equal(p$visual_complete_ms[[1L]], 2000)
  expect_equal(c(p$visual_min_ms[[1L]], p$visual_max_ms[[1L]]), c(1000, 3000))
  expect_equal(p$ok_frac[[1L]], 2 / 3)
  expect_equal(p$not_ok[[1L]], "timeout")
  expect_equal(p$arg[[2L]], "in")
})

test_that("memory is the largest session peak per dataset", {
  raw <- rbind(obs("overview", run_peak_r_mib = 3000), obs("groups", run_peak_r_mib = 5000), obs("spatial", dataset = "cosmx", run_peak_r_mib = 1000))
  m <- memory_table(raw)
  expect_equal(m$dataset, c("1m", "cosmx"))
  expect_equal(m$r_peak_mib, c(5000, 1000))
  expect_equal(m$sessions, c(2L, 1L))
})

test_that("server steps report the median and the worst status", {
  s <- data.frame(label = "run", dataset = "1m", round = 1:3, step = "read_crb", ms = c(10, 30, NA), status = c("ok", "ok", "error"), value = NA, hash = c("h", "h", ""))
  t <- server_table(s)
  expect_equal(t$ms, 20)
  expect_equal(t$status, "error")
  expect_equal(t$hash, "h")
})

test_that("the summary lists every page, problems and pages without a dataset", {
  raw <- rbind(obs("loadData", "initial"), obs("overview", status = "error"))
  f <- tempfile(fileext = ".md")
  write_summary(f, list(version = "5.4.0", run_id = "r", ref = "HEAD", sha = "abc", rounds = 1L, sessions = 2L, failed = 0L, datasets = "1m",
                        host = "h", os = "o", cpu = "c", r_version = "R", chrome = "Chrome", renderer = "gpu", uncovered = "trekker"),
                page_table(raw), memory_table(raw), NULL, problems = "something")
  s <- readLines(f)
  expect_true(any(grepl("CerebroNexus 5.4.0", s)))
  expect_true(any(grepl("| loadData | initial | 1m | ok |", s, fixed = TRUE)))
  expect_true(any(grepl("error (0/1 ok)", s, fixed = TRUE)))
  expect_true(any(grepl("trekker", s)))
  expect_true(any(grepl("something", s)))
})

run_of <- function(pages, manifest = c(contract = "blackbox-v7", platform = "windows", host = "h", cpu = "c", memory_measure = "m", plan_md5 = "p", fixtures_md5 = "f", version = "5.4.0"), id = "A") {
  list(id = id, manifest = manifest, pages = page_table(pages), raw = pages)
}
# One page measured in several rounds: `visual` gives the value of each round.
rounds_of <- function(page, visual, visit = "cold", ...) do.call(rbind, lapply(seq_along(visual), function(r) obs(page, visit, visual[[r]], round = r, ...)))

test_that("the exact rank-sum test counts the ways two samples could have been dealt", {
  expect_equal(rank_sum_p(1:5, 6:10), 2 / 252)            # no overlap, 5 against 5: the two extreme deals of 252
  expect_equal(rank_sum_p(6:10, 1:5), 2 / 252)            # two-sided
  expect_equal(rank_sum_p(1:3, 4:6), 0.1)                 # 3 against 3 cannot do better than 2 of 20
  expect_equal(rank_sum_p(c(1, 2, 3, 4), c(5, 6, 7, 8)), 2 / 70)
  expect_equal(rank_sum_p(c(5, 5, 5), c(5, 5, 5)), 1)     # ties share their rank: nothing to tell apart
  expect_equal(rank_sum_p(c(1, 3, 5), c(2, 4, 6)), stats::wilcox.test(c(1, 3, 5), c(2, 4, 6), exact = TRUE)$p.value)
  expect_equal(rank_sum_p(c(1, 2, 7, 9, 11), c(3, 8, 10, 12, 13)), stats::wilcox.test(c(1, 2, 7, 9, 11), c(3, 8, 10, 12, 13), exact = TRUE)$p.value)
  expect_true(is.na(rank_sum_p(numeric(), 1:3)))
  expect_equal(rank_sum_p(c(1, NA, 2), c(3, 4)), rank_sum_p(1:2, 3:4))
  expect_equal(c(rank_sum_min_p(3, 3), rank_sum_min_p(4, 4), rank_sum_min_p(5, 5)), c(0.1, 2 / 70, 2 / 252))
  expect_lte(rank_sum_min_p(default_rounds, default_rounds), compare_alpha)   # the default number of rounds can show a difference
  # many rounds: the normal approximation, close to the exact value
  x <- seq(1, 39, by = 2); y <- seq(20, 58, by = 2)
  expect_equal(rank_sum_p(x, y), stats::wilcox.test(x, y, exact = FALSE)$p.value)
})

test_that("comparing two runs marks slower and faster from the rounds, and pages that stopped finishing", {
  a <- run_of(rbind(rounds_of("overview", c(1000, 1010, 1020, 1030, 1040)), rounds_of("groups", c(1000, 1100, 1200, 1300, 1400)),
                    rounds_of("about", c(300, 300, 300, 300, 300)), rounds_of("trajectory", c(900, 910, 920, 930, 940)),
                    rounds_of("color_management", c(400, 401, 402, 403, 404)), rounds_of("overview.zoom", c(100, 100, 100, 100, 100), "action", arg = "in")))
  b <- run_of(rbind(rounds_of("overview", c(1300, 1310, 1320, 1330, 1340)), rounds_of("groups", c(1050, 1150, 1250, 1350, 1450)),
                    rounds_of("about", c(300, 300, 300, 300, 300), status = "timeout"), rounds_of("trajectory", c(300, 310, 320, 330, 340)),
                    rounds_of("color_management", c(410, 411, 412, 413, 414)), rounds_of("overview.zoom", c(100, 100, 100, 100, 100), "action", arg = "out"),
                    rounds_of("spatial", c(1, 2, 3, 4, 5), dataset = "cosmx")), id = "B")
  cmp <- compare_runs(a, b)
  ch <- stats::setNames(cmp$table$change, cmp$table$page)
  expect_equal(ch[["overview"]], "slower")                # every round of B above every round of A, by more than a frame
  expect_equal(ch[["groups"]], "not resolved")            # the rounds overlap
  expect_equal(ch[["about"]], "stopped finishing")
  expect_equal(ch[["trajectory"]], "faster")
  expect_equal(ch[["color_management"]], "not resolved")  # separated, but by 10 ms: less than a frame (100 ms when not recorded)
  expect_equal(ch[["spatial"]], "only in B")
  expect_match(cmp$table$note[cmp$table$page == "overview.zoom"], "different value")
  expect_equal(cmp$table$delta_pct[cmp$table$page == "overview"], 29.4)
  expect_equal(cmp$table$p[cmp$table$page == "overview"], 2 / 252)
  expect_equal(cmp$table$n_a[cmp$table$page == "overview"], 5L)
  expect_length(cmp$differ, 0L)
  expect_false(cmp$paired); expect_false(cmp$same_revision)
  out <- compare_lines(cmp, a, b)
  expect_true(any(grepl("same contract, platform", out)))
  expect_true(any(grepl("were not made together", out)))
  expect_true(any(grepl("Slower: 1; faster: 1; stopped finishing: 1; not resolved: 3; too few rounds: 0.", out, fixed = TRUE)))
  expect_true(any(grepl("5 rows were tested", out, fixed = TRUE)))
})

test_that("a threefold speed-up of a short action is a difference, and three rounds cannot show one", {
  a <- run_of(rounds_of("groups.group", c(300, 310, 320, 330, 340), "action", frame_ms = 50))
  b <- run_of(rounds_of("groups.group", c(100, 105, 110, 115, 120), "action", frame_ms = 50), id = "B")
  cmp <- compare_runs(a, b)
  expect_equal(cmp$table$change, "faster")
  expect_equal(cmp$table$resolution, 50)                  # the frames of the row itself
  a3 <- run_of(rounds_of("groups.group", c(300, 310, 320), "action")); b3 <- run_of(rounds_of("groups.group", c(100, 105, 110), "action"), id = "B")
  cmp3 <- compare_runs(a3, b3)
  expect_equal(cmp3$table$change, "too few rounds")
  expect_equal(cmp3$table$p, 0.1)
  expect_true(any(grepl("too few rounds: 1", compare_lines(cmp3, a3, b3))))
  # another metric is compared the same way, without the frame floor
  a$raw$r_peak_mib <- c(2000, 2001, 2002, 2003, 2004); b$raw$r_peak_mib <- c(2010, 2011, 2012, 2013, 2014)
  m <- compare_runs(a, b, metric = "r_peak_mib")
  expect_equal(m$table$change, "slower"); expect_equal(m$table$resolution, 0)
  expect_true(any(grepl("A (MiB)", compare_lines(m, a, b), fixed = TRUE)))
  # a run without its observations cannot be tested
  a$raw <- NULL
  expect_equal(compare_runs(a, b)$table$change, "-")
})

test_that("runs made together are compared round by round, and one revision against itself is a noise check", {
  m <- c(contract = "blackbox-v7", platform = "windows", host = "h", cpu = "c", memory_measure = "m", plan_md5 = "p", fixtures_md5 = "f",
         version = "8.0.0", sha = "abc", pair_id = "20261113-100000_abc_abc")
  a <- run_of(rounds_of("overview", c(500, 520, 540, 560, 580)), m)
  b <- run_of(rounds_of("overview", c(510, 525, 530, 570, 600)), m, id = "B")
  cmp <- compare_runs(a, b)
  expect_true(cmp$paired); expect_true(cmp$same_revision)
  expect_equal(cmp$table$change, "not resolved")
  expect_equal(c(cmp$table$round_delta_min, cmp$table$round_delta_max), c(-10, 20))
  out <- compare_lines(cmp, a, b)
  expect_true(any(grepl("Noise check", out)))
  expect_true(any(grepl("made together", out)))
  expect_true(any(grepl("B - A per round", out, fixed = TRUE)))
  expect_true(any(grepl("0 of 1 tested rows marked", out, fixed = TRUE)))
  # different pair ids: not made together
  m2 <- m; m2[["pair_id"]] <- "other"; m2[["sha"]] <- "def"
  cmp2 <- compare_runs(a, run_of(rounds_of("overview", c(510, 525, 530, 570, 600)), m2, id = "B"))
  expect_false(cmp2$paired); expect_false(cmp2$same_revision)
  expect_true(is.na(cmp2$table$round_delta_min))
  # runs made alone carry an empty pair id
  m3 <- m; m3[["pair_id"]] <- ""
  expect_false(compare_runs(run_of(rounds_of("overview", 1:5), m3), run_of(rounds_of("overview", 1:5), m3))$paired)
})

test_that("runs from different machines or plans are labelled, not refused", {
  m <- c(contract = "blackbox-v5", platform = "windows", host = "h", cpu = "c", memory_measure = "m", plan_md5 = "p", fixtures_md5 = "f")
  m2 <- m; m2[["host"]] <- "other"; m2[["plan_md5"]] <- "q"
  cmp <- compare_runs(run_of(obs("overview"), m), run_of(obs("overview"), m2))
  expect_setequal(cmp$differ, c("host", "plan_md5"))
  expect_true(any(grepl("Not like for like", compare_lines(cmp, run_of(obs("overview"), m), run_of(obs("overview"), m2)))))
})

test_that("a run folder round-trips through read_run", {
  d <- tempfile(); dir.create(d)
  utils::write.table(page_table(rbind(obs("overview"), obs("overview.zoom", "action", arg = "in"))), file.path(d, "pages.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
  utils::write.table(data.frame(key = c("version", "host"), value = c("5.4.0", "h")), file.path(d, "manifest.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
  r <- read_run(d)
  expect_equal(r$manifest[["version"]], "5.4.0")
  expect_equal(r$pages$arg, c("", "in"))
  expect_error(read_run(tempdir()), "not a run directory")
})

test_that("server busy time runs to the end of the work, across a short pause", {
  t <- seq(0, 10000, by = 250)
  cpu <- cumsum(c(0, ifelse(t[-1] <= 2000 | (t[-1] > 3000 & t[-1] <= 4000), 0.25, 0)))
  expect_equal(busy_ms(t, cpu, 0, 10000, 0.05), 4000)
})

test_that("quiet needs every tree below its threshold", {
  t <- seq(0, 6000, by = 250)
  r <- cumsum(c(0, rep(0, length(t) - 1L)))
  ch <- cumsum(c(0, ifelse(t[-1] <= 3000, 0.25, 0.01)))
  expect_equal(quiet_from(t, cbind(r, ch), c(0.05, 0.25)), 3000)
})

test_that("visual completion is the first frame that already looks final", {
  v <- visual_from_similarity(c(100, 200, 300, 400), c(0.5, 0.95, 1, 1), t_click = 0)
  expect_equal(v$visual_complete_ms, 300)
  expect_equal(v$visual_90_ms, 200)
})

test_that("plot legends use the version, adding the date and then the time only when needed", {
  expect_equal(run_labels(c("5.4.0", "5.5.0"), c("2026-10-29T20:54:09+0100", "2026-10-29T22:22:17+0100")), c("5.4.0", "5.5.0"))
  expect_equal(run_labels(c("5.5.0", "5.4.0", "5.5.0", "5.5.0"),
                          c("2026-10-29T22:22:17+0100", "2026-10-29T20:54:09+0100", "2026-10-29T23:59:28+0100", "2026-10-30T09:00:00+0100")),
               c("5.5.0 (2026-10-29 22:22)", "5.4.0", "5.5.0 (2026-10-29 23:59)", "5.5.0 (2026-10-30)"))
})

test_that("several runs are drawn in one figure, by version then date", {
  m <- function(v, t) c(version = v, started = t)
  runs <- list(run_of(rbind(obs("overview", visual = 900), obs("overview.zoom", "action", visual = 20)), m("5.5.0", "2026-10-29T22:00:00+0100")),
               run_of(obs("overview", visual = 2000), m("5.4.0", "2026-10-29T23:00:00+0100")))
  expect_equal(vapply(order_runs(runs), function(r) r$manifest[["version"]], ""), c("5.4.0", "5.5.0"))
  f <- tempfile(fileext = ".pdf")
  res <- plot_runs(runs, f, family = "sans")
  expect_true(file.exists(res[["pdf"]]) && file.exists(res[["png"]]))
  expect_equal(round(as.numeric(res[["width_mm"]]), 1), 170)
  # eight runs do not fit 225 mm in one column: two columns, still at most 225 mm
  many <- lapply(1:8, function(i) run_of(rbind(obs("overview", visual = 900 + i), obs("overview.zoom", "action", visual = 20),
                                               obs("groups", visual = 500), obs("groups.group", "action"), obs("about"), obs("trekker")),
                                         m("5.5.0", sprintf("2026-10-%02dT10:00:00+0100", i))))
  big <- plot_runs(many, tempfile(fileext = ".pdf"), family = "sans")
  expect_lte(as.numeric(big[["height_mm"]]), 225)
  expect_error(plot_runs(runs, tempfile(fileext = ".pdf"), metric = "nope", family = "sans"), "no values")
  expect_true(file.exists(plot_runs(runs, tempfile(fileext = ".pdf"), family = "sans", threshold = c(100, 1000))[["pdf"]]))
  expect_true(file.exists(plot_runs(runs, tempfile(fileext = ".pdf"), family = "sans", threshold = NULL)[["pdf"]]))
})

test_that("rows show page and action names, not ids", {
  expect_equal(row_names(c("overview", "overview.colour_by", "geneExpression.genes12", "newPage", "x.new"), c(TRUE, FALSE, FALSE, TRUE, FALSE)),
               c("Projection", "Change colouring", "Show 12 genes", "newPage", "new"))
  expect_true(all(tsv("coverage.tsv")$page %in% names(PAGE_NAMES)))
  expect_true(all(sub("^[^.]*[.]", "", tsv("actions.tsv")$action) %in% names(ACTION_NAMES)))
})

test_that("rows split into columns keep a page with its actions", {
  is_page <- c(TRUE, FALSE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE)
  col <- split_rows(is_page, 2L)
  expect_equal(col[[1L]], 1L); expect_equal(col[[length(col)]], 2L)
  block <- cumsum(is_page)
  expect_true(all(tapply(col, block, function(x) length(unique(x))) == 1L))
  expect_equal(split_rows(is_page, 1L), rep(1L, 8L))
})

test_that("ink is what differs from the element's own background", {
  blank <- array(1, c(40, 40, 3))
  expect_equal(ink_fraction(blank), 0)
  dots <- blank; dots[1:4, 1:10, ] <- 0          # 40 black pixels of 1600: dark
  expect_equal(ink_fraction(dots), 40 / 1600)
  red <- blank; red[1:10, 1:10, 2:3] <- 0        # 100 saturated red pixels
  expect_equal(ink_fraction(red), 100 / 1600)
  pale <- blank; pale[1:10, 1:10, ] <- 0.9       # light grey: close to the background, no ink
  expect_equal(ink_fraction(pale), 0)
  on_black <- array(0, c(40, 40, 3)); on_black[1:10, 1:10, 1] <- 1   # the most frequent colour is the background, whatever it is
  expect_equal(ink_fraction(on_black), 100 / 1600)                   # red on black: coloured
  white_on_black <- array(0, c(40, 40, 3)); white_on_black[1:10, 1:10, ] <- 1
  expect_equal(ink_fraction(white_on_black), 0)                      # white is neither dark nor coloured (as in the tool comparison)
})

test_that("the first plot is the first of two frames in a row that show it", {
  expect_equal(first_accepted_frame(c(FALSE, TRUE, TRUE, TRUE)), 2L)
  expect_equal(first_accepted_frame(c(TRUE, FALSE, FALSE, TRUE, TRUE)), 4L)   # a lone frame does not count
  expect_true(is.na(first_accepted_frame(c(FALSE, TRUE, FALSE, TRUE))))
  expect_true(is.na(first_accepted_frame(TRUE)))
  expect_true(is.na(first_accepted_frame(logical())))
})

test_that("a frame shows the plot when the element is big enough and has enough ink", {
  img <- array(1, c(100, 120, 3)); img[40:60, 50:70, ] <- 0       # 441 of 400 * 300 px element: > 1 %
  expect_true(plot_shown(img, c(10, 10, 300, 400) / 4, scale = 4)$shows == FALSE)   # element 75 x 100 CSS px: too small
  big <- array(1, c(1000, 1000, 3)); big[100:300, 100:300, 3] <- 0                  # yellow square
  r <- plot_shown(big, c(50, 50, 600, 600), scale = 1)
  expect_true(r$shows); expect_equal(r$ink, 201 * 201 / (600 * 600), tolerance = 1e-3)
  expect_false(plot_shown(array(1, c(1000, 1000, 3)), c(50, 50, 600, 600))$shows)  # empty
  expect_false(plot_shown(big, c(2000, 2000, 600, 600))$shows)                      # off screen
  # a quarter-size screenshot (scale 0.25) is cropped by the same CSS rectangle
  small <- array(1, c(250, 250, 3)); small[25:75, 25:75, 3] <- 0
  expect_true(plot_shown(small, c(50, 50, 600, 600), scale = 0.25)$shows)
})

test_that("a page with first_plot also gets two sessions of its own, after its page: nothing kept, then a later start", {
  cov <- data.frame(page = c("a", "b"), dataset = "x", first_plot = c("yes", ""), stringsAsFactors = FALSE)
  plan <- build_plan(cov, data.frame(action = "a.go", page = "a"), "x")
  expect_equal(plan$first_plot, c(TRUE, FALSE))
  s <- build_schedule(plan, 2L)
  expect_equal(s$kind, rep(c("page", "first_start", "first_plot", "page"), 2L))
  expect_equal(s$page, rep(c("a", "a", "a", "b"), 2L))
  expect_equal(s$actions, rep(c("a.go", "", "", ""), 2L))
  expect_equal(s$position, 1:8); expect_equal(s$round, rep(1:2, each = 4L))
  expect_equal(unique(s$revision), "candidate")
  expect_false(any(build_plan(data.frame(page = "a", dataset = "x"), data.frame(action = character(), page = character()), "x")$first_plot))
  expect_true(all(start_visits %in% standard_visits))
})

test_that("two revisions measured in one run take turns, and each goes first equally often", {
  cov <- data.frame(page = c("a", "b"), dataset = "x", first_plot = c("yes", ""), stringsAsFactors = FALSE)
  plan <- build_plan(cov, data.frame(action = character(), page = character()), "x")
  s <- build_schedule(list(candidate = plan, baseline = plan), 2L)
  expect_equal(nrow(s), 2L * nrow(build_schedule(plan, 2L)))
  # the two sessions of one page, kind and round are next to each other
  block <- paste(s$round, s$page, s$kind)
  expect_true(all(block[c(TRUE, FALSE)] == block[c(FALSE, TRUE)]))
  expect_true(all(s$revision[c(TRUE, FALSE)] != s$revision[c(FALSE, TRUE)]))
  first <- s$revision[c(TRUE, FALSE)][!duplicated(paste(s$round, s$page)[c(TRUE, FALSE)])]   # who opens each page of each round
  expect_equal(sum(first == "candidate"), sum(first == "baseline"))
  # each revision has the sessions it would have alone
  alone <- build_schedule(plan, 2L)
  for (rv in c("candidate", "baseline")) expect_equal(paste(s$round, s$page, s$kind)[s$revision == rv], paste(alone$round, alone$page, alone$kind))
  # a page only one revision can measure (its demo CRB is missing in the other) is measured for that one alone
  only <- build_schedule(list(candidate = plan, baseline = plan[plan$page == "a", ]), 1L)
  expect_equal(only$revision[only$page == "b"], "candidate")
})

test_that("the shipped plan times the first plot of the projection, and the hook can open it", {
  plan <- build_plan(tsv("coverage.tsv"), tsv("actions.tsv"), tsv("fixtures.tsv")$name, c("example", "demo_trekker"))
  expect_equal(plan$page[plan$first_plot], "overview")
  expect_equal(standard_contract, "blackbox-v7")
  expect_true("first_plot_ms" %in% standard_metrics)
  hook <- paste(readLines(file.path("..", "standard", "hook.js")), collapse = "
")
  expect_true(grepl("cb.fpStep", hook, fixed = TRUE)); expect_true(grepl(standard_contract, hook, fixed = TRUE))
})

test_that("first_plot rows sit under their page, named by what they time", {
  raw <- rbind(obs("overview", "cold", 600), obs("overview", "first_plot", 3000, first_plot_ms = 2500),
               obs("overview", "first_start", 5000, first_plot_ms = 4200), obs("overview.zoom", "action", 100))
  pages <- page_table(raw)
  expect_equal(pages$visit, c("cold", "first_start", "first_plot", "action"))
  expect_equal(pages$first_plot_ms[pages$visit == "first_plot"], 2500)
  expect_equal(pages$first_plot_ms[pages$visit == "first_start"], 4200)
  expect_equal(row_names(c("overview", "overview", "overview", "overview.zoom"), c(TRUE, FALSE, FALSE, FALSE), c("cold", "first_start", "first_plot", "action")),
               c("Projection", "From page load, nothing kept", "From page load", "Zoom"))
  out <- tempfile(fileext = ".md")
  write_summary(out, list(version = "1", run_id = "r", ref = "HEAD", sha = "s", rounds = 1, sessions = 1, failed = 0, datasets = "1m", host = "h",
                          os = "o", cpu = "c", r_version = "R", chrome = "c", renderer = "g", uncovered = character()), pages)
  s <- readLines(out)
  expect_true(any(grepl("First plot (ms)", s, fixed = TRUE)))
  expect_true(any(grepl("| overview | first_plot | 1m |", s, fixed = TRUE)))
  expect_true(any(grepl("| overview | first_start | 1m |", s, fixed = TRUE)))
})

test_that("a summary says which run it was measured with, and how busy the host was", {
  out <- tempfile(fileext = ".md")
  write_summary(out, list(version = "1", run_id = "r", ref = "HEAD", sha = "s", rounds = 5, sessions = 1, failed = 0, datasets = "1m", host = "h",
                          os = "o", cpu = "c", r_version = "R", chrome = "c", renderer = "g", uncovered = character(),
                          pair = "cerebronexus-1_x_base", pair_role = "this run is the candidate", host_load = "median 4.0 % CPU"),
                page_table(obs("overview")))
  s <- readLines(out)
  expect_true(any(grepl("Measured together with `cerebronexus-1_x_base` (this run is the candidate)", s, fixed = TRUE)))
  expect_true(any(grepl("Host before the sessions: median 4.0 % CPU", s, fixed = TRUE)))
})

test_that("a figure draws the first-plot row under its page, for either metric", {
  m <- c(version = "5.5.0", started = "2026-10-29T22:00:00+0100")
  r <- run_of(rbind(obs("overview", visual = 600), obs("overview", "first_plot", 3000, first_plot_ms = 2500), obs("overview.zoom", "action", visual = 100)), m)
  expect_true(file.exists(plot_runs(list(r), tempfile(fileext = ".pdf"), family = "sans")[["pdf"]]))
  expect_true(file.exists(plot_runs(list(r), tempfile(fileext = ".pdf"), metric = "first_plot_ms", family = "sans")[["pdf"]]))
})
