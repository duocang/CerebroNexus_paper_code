# Extracted from test-bench-cli-contract.R:152

# prequel ----------------------------------------------------------------------
bench_root <- normalizePath(file.path("..", "benchmark", "scripts"), mustWork = FALSE)
skip_unless_bench_cli <- function() {
  testthat::skip_if_not(
    file.exists(file.path(bench_root, "benchmark_cli.R")),
    "benchmark tree not present (expected when checking a built package)"
  )
}
run_bench_command <- function(command, args = character(), env = character()) {
  out <- tempfile("bench-cli-stdout-")
  err <- tempfile("bench-cli-stderr-")
  on.exit(unlink(c(out, err)), add = TRUE)
  status <- bench_test_system2(
    file.path(R.home("bin"), "Rscript"),
    c(file.path(bench_root, "benchmark_cli.R"), command, args),
    stdout = out,
    stderr = err,
    env = c(paste0("BENCH_ROOT=", bench_root), env)
  )
  list(
    status = status,
    stdout = readLines(out, warn = FALSE),
    stderr = readLines(err, warn = FALSE)
  )
}

# test -------------------------------------------------------------------------
skip_unless_bench_cli()
result <- tempfile(fileext = ".csv")
on.exit(unlink(result), add = TRUE)
run <- run_bench_command(
    "environment",
    result,
    env = c(
      "BENCH_PROFILE=quick",
      "BENCH_STUDY_ID=test-study",
      "BENCH_RUN_ID=test-run",
      "BENCH_THREADS=3"
    )
  )
expect_equal(run$status, 0L, info = paste(run$stderr, collapse = "\n"))
manifest <- utils::read.csv(result, stringsAsFactors = FALSE)
values <- stats::setNames(manifest$value, manifest$key)
expect_equal(values[["study_id"]], "test-study")
expect_equal(values[["run_id"]], "test-run")
expect_equal(values[["benchmark_threads"]], "3")
expect_match(values[["git_sha"]], "^[0-9a-f]{40}$")
