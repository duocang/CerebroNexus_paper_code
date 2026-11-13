# Unit tests of standard/lib.R (no Builder, no worker). Run from the root of this repository:
#   Rscript -e 'testthat::test_dir("topics/builder_performance/tests")'
library(testthat)
topic <- if (dir.exists(file.path(getwd(), "standard"))) {
  getwd()
} else if (dir.exists(file.path(getwd(), "..", "standard"))) {
  normalizePath(file.path(getwd(), ".."))
} else {
  normalizePath(file.path(getwd(), "topics", "builder_performance"))
}
viewer <- file.path(dirname(topic), "viewer_performance", "standard")
source(file.path(viewer, "lib.R"))
source(file.path(topic, "standard", "lib.R"))

test_that("two revisions take turns, each scenario once per revision and round", {
  s <- build_schedule(c("a", "b", "c"), 4L, c("candidate", "baseline"))
  expect_equal(nrow(s), 4L * 3L * 2L)
  expect_equal(s$position, seq_len(nrow(s)))
  expect_true(all(table(s$round, s$scenario, s$revision) == 1L))
  first <- s[!duplicated(paste(s$round, s$scenario)), ]
  # neither revision goes first every time, in any scenario or round
  expect_gt(length(unique(first$revision)), 1L)
  for (sc in c("a", "b", "c")) {
    expect_gt(length(unique(first$revision[first$scenario == sc])), 1L)
  }
  for (r in 1:4) {
    expect_gt(length(unique(first$revision[first$round == r])), 1L)
  }
})

test_that("one revision is scheduled alone", {
  s <- build_schedule(c("a", "b"), 3L)
  expect_true(all(s$revision == "candidate"))
  expect_equal(nrow(s), 6L)
})

test_that("run folders are named by version, time and revision, with a tag for the baseline of a noise check", {
  t <- as.POSIXct("2026-11-13 09:20:27")
  expect_equal(
    run_dir_name("8.0.1", "6a67f6fcda05", t),
    "cerebronexus-8.0.1_20261113-092027_6a67f6f"
  )
  expect_equal(
    run_dir_name("8.0.1", "6a67f6fcda05", t, tag = "base"),
    "cerebronexus-8.0.1_20261113-092027_6a67f6f_base"
  )
  expect_equal(
    run_dir_name("8.0.1", "6a67f6fcda05", t, partial = TRUE),
    "cerebronexus-8.0.1_20261113-092027_6a67f6f_partial"
  )
})

obs <- function(scenario, values, status = "ok", metric = "edit_ms") {
  d <- data.frame(
    round = seq_along(values),
    scenario = scenario,
    status = status,
    stringsAsFactors = FALSE
  )
  for (m in names(time_metrics)) {
    d[[m]] <- NA_real_
  }
  d[[metric]] <- values
  d
}

test_that("scenario_table takes medians over the rounds that finished", {
  raw <- rbind(
    obs("edit", c(100, 110, 120, 9999), status = c("ok", "ok", "ok", "error")),
    obs("import", c(5, 7), metric = "import_s")[0, ]
  )
  t <- scenario_table(raw)
  expect_equal(t$rounds, 4L)
  expect_equal(t$ok_rounds, 3L)
  expect_equal(t$edit_ms, 110)
})

test_that("a clear, consistent difference is called, in the right direction", {
  a <- obs("edit", c(800, 820, 790, 810, 805))
  b <- obs("edit", c(300, 310, 290, 305, 295))
  c1 <- compare_raw(a, b)
  expect_equal(c1$change, "faster")
  expect_lt(c1$p, 0.05)
  expect_equal(c1$n_a, 5L)
  expect_equal(compare_raw(b, a)$change, "slower")
})

test_that("overlapping rounds are not resolved; three against three cannot be", {
  a <- obs("edit", c(100, 130, 90, 120, 110))
  b <- obs("edit", c(105, 95, 125, 115, 100))
  expect_equal(compare_raw(a, b)$change, "not resolved")
  expect_equal(
    compare_raw(
      obs("edit", c(100, 101, 102)),
      obs("edit", c(500, 501, 502))
    )$change,
    "too few rounds"
  )
})

test_that("a difference below the floor is not called even when the rounds do not overlap", {
  a <- obs("edit", c(1000, 1001, 1002, 1003, 1004))
  b <- obs("edit", c(1010, 1011, 1012, 1013, 1014)) # 1 %
  r <- compare_raw(a, b)
  expect_lt(r$p, 0.05)
  expect_equal(r$change, "not resolved")
  expect_gte(r$floor, 30)
})

test_that("the floor of a time in seconds is the timer's resolution", {
  a <- obs(
    "import",
    c(0.001, 0.0011, 0.0012, 0.0013, 0.0014),
    metric = "import_s"
  )
  b <- obs("import", rep(0.01, 5), metric = "import_s")
  r <- compare_raw(a, b, metrics = "import_s")
  expect_equal(r$floor, 0.015)
  expect_equal(r$change, "not resolved")
})

test_that("failed sessions do not count, and a scenario in one run only is still listed", {
  a <- obs("edit", c(800, 810, 805, 800, 790))
  b <- obs(
    "edit",
    c(300, 310, 9999, 305, 295),
    status = c("ok", "ok", "error", "ok", "ok")
  )
  r <- compare_raw(a, b)
  expect_equal(r$n_b, 4L)
  expect_equal(r$change, "faster")
  r2 <- compare_raw(
    a,
    rbind(b, obs("build", c(1, 2, 3, 4, 5), metric = "build_s")),
    metrics = c("edit_ms", "build_s")
  )
  expect_true("build" %in% r2$scenario)
})

test_that("runs made together report the difference within each round", {
  a <- obs("edit", c(800, 820, 790, 810, 805))
  b <- obs("edit", c(300, 310, 290, 305, 295))
  r <- compare_raw(a, b, paired = TRUE)
  expect_equal(r$round_delta_min, -510)
  expect_equal(r$round_delta_max, -500)
  expect_true(is.na(compare_raw(a, b)$round_delta_min))
})

test_that("failed equivalence checks become problems", {
  ok <- data.frame(check = "x", result = "pass", detail = "d")
  bad <- rbind(
    ok,
    data.frame(check = "y", result = "fail", detail = "wrong matrix")
  )
  expect_length(check_summary(ok), 0L)
  expect_match(check_summary(bad), "y")
  expect_match(check_summary(NULL), "no equivalence checks")
})

test_that("every scenario in scenarios.tsv has a fixture and its metrics are known", {
  sc <- read_tsv(file.path(topic, "standard", "scenarios.tsv"))
  fx <- read_tsv(file.path(topic, "standard", "fixtures.tsv"))
  expect_true(all(sc$fixture %in% fx$name))
  expect_true(all(unlist(strsplit(sc$metrics, ",")) %in% all_metrics))
})
