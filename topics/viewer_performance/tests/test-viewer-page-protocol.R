## Contract tests for topics/viewer_performance/scripts/viewer_1m_page_protocol.R, moved from
## CerebroNexus tests/testthat/test-million-cell-viewer.R.
viewer_protocol_file <- file.path("..", "scripts", "viewer_1m_page_protocol.R")

test_that("trajectory benchmark contract follows the selected trajectory", {
  protocol_file <- viewer_protocol_file
  skip_if_not(file.exists(protocol_file), "benchmark tree not present")
  protocol <- new.env(parent = baseenv())
  sys.source(protocol_file, envir = protocol)
  object <- new.env(parent = emptyenv())
  object$getTrajectory <- function(method, name) {
    expect_identical(method, "marker_guided")
    expect_identical(name, "E18_neurogenesis")
    list(
      meta = data.frame(
        DR_1 = 1:5,
        DR_2 = 6:10,
        pseudotime = c(0, 1, NA, 3, 4)
      )
    )
  }
  artifact <- tempfile(fileext = ".crb")
  saveRDS(object, artifact)

  contract <- protocol$benchmark_trajectory_contract(
    artifact,
    "marker_guided",
    "E18_neurogenesis"
  )

  expect_identical(contract$metadata_rows, 5L)
  expect_identical(contract$renderable_rows, 4L)
  expect_identical(contract$excluded_pseudotime_rows, 1L)
  expect_identical(contract$method, "marker_guided")
  expect_identical(contract$name, "E18_neurogenesis")
})

test_that("Spatial benchmark contract follows finite coordinate rows", {
  protocol_file <- viewer_protocol_file
  skip_if_not(file.exists(protocol_file), "benchmark tree not present")
  protocol <- new.env(parent = baseenv())
  sys.source(protocol_file, envir = protocol)
  object <- new.env(parent = emptyenv())
  object$availableSpatial <- function() "synthetic_grid"
  object$getSpatialData <- function(name, hydrate_molecules = TRUE) {
    expect_identical(name, "synthetic_grid")
    expect_false(hydrate_molecules)
    list(coordinates = data.frame(x = 1:5, y = 6:10))
  }
  artifact <- tempfile(fileext = ".crb")
  saveRDS(object, artifact)

  contract <- protocol$benchmark_spatial_contract(artifact)

  expect_identical(contract$name, "synthetic_grid")
  expect_identical(contract$renderable_rows, 5L)
})

test_that("benchmark TSV output escapes controls and validates columns", {
  protocol_file <- viewer_protocol_file
  skip_if_not(file.exists(protocol_file), "benchmark tree not present")
  protocol <- new.env(parent = baseenv())
  sys.source(protocol_file, envir = protocol)
  output <- tempfile(fileext = ".tsv")
  rows <- data.frame(
    status = "error",
    error = "first line\nsecond\tfield\rreturn",
    correctness_detail = "{\n\t\"reason\": \"bad\"\n}",
    stringsAsFactors = FALSE
  )

  expect_silent(protocol$write_validated_tsv(rows, output))

  physical_lines <- readLines(output, warn = FALSE)
  expect_length(physical_lines, 2L)
  expect_true(all(
    vapply(
      physical_lines,
      protocol$tsv_field_count,
      integer(1)
    ) ==
      ncol(rows)
  ))
  expect_match(
    physical_lines[[2L]],
    "first line\\nsecond\\tfield\\rreturn",
    fixed = TRUE
  )

  expect_match(
    physical_lines[[2L]],
    "{\\n\\t\"reason\": \"bad\"\\n}",
    fixed = TRUE
  )
})

test_that("benchmark provenance identifies sidecars and Viewer Packs", {
  protocol_file <- viewer_protocol_file
  skip_if_not(file.exists(protocol_file), "benchmark tree not present")
  protocol <- new.env(parent = baseenv())
  sys.source(protocol_file, envir = protocol)
  root <- tempfile("benchmark-artifacts-")
  dir.create(root)
  sidecar <- file.path(root, "fixture.bpcells")
  pack <- file.path(root, "fixture.viewer")
  dir.create(sidecar)
  dir.create(pack)
  writeLines(c("cell-1", "cell-2"), file.path(sidecar, "col_names"))
  writeBin(as.raw(c(1L, 2L, 3L)), file.path(sidecar, "val_data"))
  writeLines('{"schema_version":1}', file.path(pack, "manifest.json"))
  object <- new.env(parent = emptyenv())
  object$expression_backend <- list(
    type = "bpcells",
    location = basename(sidecar)
  )
  crb <- file.path(root, "fixture.crb")
  saveRDS(object, crb)

  manifest <- protocol$benchmark_artifact_provenance(crb)

  expect_identical(manifest$bpcells_sidecar, normalizePath(sidecar))
  expect_match(manifest$bpcells_sidecar_sha256, "^[0-9a-f]{64}$")
  expect_identical(
    manifest$viewer_pack_manifest,
    normalizePath(file.path(pack, "manifest.json"))
  )
  expect_match(manifest$viewer_pack_manifest_sha256, "^[0-9a-f]{64}$")
})

test_that("the page benchmark schedule and budgets are balanced", {
  protocol_file <- viewer_protocol_file
  skip_if_not(
    file.exists(protocol_file),
    "benchmark tree not present (expected when checking a built package)"
  )
  protocol <- new.env(parent = baseenv())
  sys.source(protocol_file, envir = protocol)

  schedule <- protocol$build_balanced_schedule(
    c("baseline", "candidate"),
    c("overview", "trajectory"),
    5L
  )
  units <- split(
    schedule,
    interaction(schedule$round, schedule$page, schedule$visit, drop = TRUE)
  )
  expect_true(all(vapply(
    units,
    function(unit) setequal(unit$candidate, c("baseline", "candidate")),
    logical(1)
  )))
  page_visits <- split(
    schedule,
    interaction(schedule$page, schedule$visit, drop = TRUE)
  )
  expect_true(all(vapply(
    page_visits,
    function(rows) {
      positions <- table(rows$candidate, rows$candidate_position)
      max(positions) - min(positions) <= 1L
    },
    logical(1)
  )))

  expect_error(
    protocol$validate_page_profile("publication", 4L),
    "at least 5 rounds"
  )
  expect_silent(protocol$validate_page_profile("publication", 5L))
  expect_true(protocol$page_budget_pass(1999, 2000))
  expect_false(protocol$page_budget_pass(2000, 2000))
  expect_true(protocol$requires_ready_event(
    "coordinated_views",
    "first",
    warmed = FALSE
  ))
  expect_true(protocol$requires_ready_event(
    "coordinated_views",
    "repeat",
    warmed = FALSE
  ))
  expect_true(protocol$requires_ready_event(
    "coordinated_views",
    "repeat",
    warmed = TRUE
  ))
  expect_true(protocol$requires_ready_event(
    "trajectory",
    "repeat",
    warmed = TRUE
  ))
  expect_silent(protocol$validate_benchmark_mode("timing"))
  expect_silent(protocol$validate_benchmark_mode("memory"))
  expect_error(protocol$validate_benchmark_mode("mixed"), "timing or memory")
})
