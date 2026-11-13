# Every topic measures the one revision named in topics/cerebronexus.pin. Run from the root of this repository:
#   Rscript -e 'testthat::test_file("topics/tests/test-pin.R")'
library(testthat)
topics <- if (file.exists(file.path(getwd(), "cerebronexus.pin"))) {
  getwd()
} else if (file.exists(file.path(getwd(), "..", "cerebronexus.pin"))) {
  normalizePath(file.path(getwd(), ".."))
} else {
  normalizePath(file.path(getwd(), "topics"))
}
source(file.path(topics, "pin.R"))
pin <- read_pin(file.path(topics, "cerebronexus.pin"))
lock <- function(path) {
  x <- trimws(readLines(file.path(topics, path), warn = FALSE))
  x <- x[nzchar(x) & !startsWith(x, "#")]
  kv <- strsplit(x, "=", fixed = TRUE)
  stats::setNames(
    vapply(kv, function(v) paste(v[-1L], collapse = "="), ""),
    vapply(kv, `[`, "", 1L)
  )
}

test_that("the pin is a full commit hash with a version", {
  expect_match(pin$commit, "^[0-9a-f]{40}$")
  expect_match(pin$version, "^[0-9]+[.][0-9]+[.][0-9]+$")
})

test_that("the lock file that keeps its own copy names the pinned commit (expression_backends is retired and keeps its old one)", {
  il <- lock("interface_figures/cerebronexus.lock")
  expect_identical(il[["viewer_commit"]], pin$commit)
  expect_identical(il[["builder_commit"]], pin$commit)
})

test_that("the run scripts take the pin as their default revision, not HEAD", {
  for (f in c(
    "viewer_performance/standard/run.R",
    "app_export/standard/run.R",
    "builder_performance/standard/run.R"
  )) {
    src <- paste(readLines(file.path(topics, f), warn = FALSE), collapse = "\n")
    expect_true(grepl("read_pin()", src, fixed = TRUE), info = f)
    expect_false(
      grepl('is.null(opt$candidate)) "HEAD"', src, fixed = TRUE),
      info = f
    )
  }
})
