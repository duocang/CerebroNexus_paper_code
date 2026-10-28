## Experiment C: publication fault injection and recovery (Visium build).
##
## Every case starts from a fresh release directory: v1 is built and published
## through the coordinator (builder_coordinator_prepare / builder_execute_plan /
## builder_coordinator_publish), its identity is recorded with
## builder_release_identity(). A v2 (same input, different dataset name, so
## the CRB differs) is then prepared and built into the same output with
## "Replace existing outputs" and published with one fault injected:
##
##  * in process, through the injection points the package tests use
##    (test-builder-publish.R): the coordinator's .verify_app and .publish
##    arguments, and builder_publish_release()'s .move, .after_phase,
##    .after_move and .verify_payload arguments;
##  * by SIGKILL (processx $kill(), i.e. kill -9) of a child R process that
##    builds and publishes v2 and parks itself at a chosen publication phase;
##  * by changing bytes of a staged or published file.
##
## Afterwards: is the release identity still v1 (or v2)? what does
## builder_discover_recovery() report? builder_recover_release() with
## "restore" or "abort" is run when recovery is required (or to show it is a
## no-op), and the final identity, recovery state and residual control files
## next to the release are recorded.
##
## In-process cases go through builder_coordinator_settle(), the function the
## Builder server calls (server/imports.R), so a failed publication is followed
## by the coordinator's own abort of the release handle, as in the app.
##
## Usage: Rscript scripts/C_publish_faults.R [case ...]
## Writes results/C_publish_faults.csv (C_OUT, C_DATA and C_BACKEND override).

source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))), "common.R"))

inputs <- file.path(bv_data, "inputs")
root <- file.path(bv_data, Sys.getenv("C_DATA", "C"))
## C_BACKEND=h5 builds v1 and v2 with the HDF5 expression backend.
c_configure <- if (nzchar(Sys.getenv("C_BACKEND"))) list(expression_backend = Sys.getenv("C_BACKEND")) else list()
dir.create(root, recursive = TRUE, showWarnings = FALSE)
visium_rds <- file.path(inputs, "visium_anterior1.rds")
rt <- bv_load_runtime()

## v1 or v2 of the same release; `name` is the only setting that differs.
prepare_version <- function(rt, case_dir, name, overwrite) {
  work <- file.path(case_dir, paste0("work-", name))
  dir.create(work, recursive = TRUE, showWarnings = FALSE)
  inspected <- bv_profile(rt, visium_rds)
  settings <- bv_settings(rt, inspected, paste("Visium", name), c_configure, work)
  planned <- bv_plan(rt, "visium", inspected, settings, visium_rds, work,
                     file.path(case_dir, "release"), overwrite = overwrite)
  bv_build(rt, planned, "visium", paste0("visium-", name))
}

identity_of <- function(target) {
  id <- rt$builder_release_identity(target)
  if (!isTRUE(id$exists)) return("absent")
  digest_entries(id)
}
digest_entries <- function(id) {
  ## hash of the entry list (paths, types, content digests)
  tf <- tempfile()
  saveRDS(id$entries, tf, version = 3)
  on.exit(unlink(tf))
  unname(tools::md5sum(tf))
}

## Everything next to and inside the release that is not release payload.
residuals <- function(case_dir) {
  all <- list.files(case_dir, all.files = TRUE, recursive = TRUE, include.dirs = FALSE, no.. = TRUE)
  all <- all[!startsWith(all, "work-") & !startsWith(all, "logs/")]
  control <- all[startsWith(all, ".cbr-")]
  list(
    control_files = length(control),
    control_backups = length(unique(sub("^(\\.cbr-[^/]+/[^/]+/[^/]+).*", "\\1",
                                        control[grepl("/(b|backup|\\.b-)", control)]))),
    control_stages = length(unique(sub("^(\\.cbr-[^/]+/stages/[^/]+).*", "\\1",
                                       control[grepl("/stages/", control)]))),
    control_listing = bv_one_line(utils::head(unique(sub("^(\\.cbr-[^/]+/[^/]+(/[^/]+)?).*", "\\1", control)), 12), 400)
  )
}

## Which release the target holds: v1 (identity equal to the published v1),
## v2 (a readable CRB named "Visium v2"), absent, or other.
release_label <- function(target, id_v1) {
  id <- identity_of(target)
  if (identical(id, id_v1)) return("v1")
  if (identical(id, "absent")) return("absent")
  crbs <- list.files(file.path(target, "cerebro_app", "private-data"), pattern = "\\.crb$", full.names = TRUE)
  name <- if (length(crbs)) tryCatch(readCerebro(crbs[[1L]])$getExperiment()$experiment_name,
                                     error = function(e) "unreadable CRB") else "no CRB"
  if (identical(name, "Visium v2")) "v2" else paste0("other (", name, ")")
}

recovery_summary <- function(target, prefix) {
  r <- bv_capture(rt$builder_discover_recovery(target))
  if (!is.null(r$error)) {
    return(stats::setNames(list(paste("error:", bv_one_line(r$error)), NA, NA, NA),
                           paste0(prefix, c("_state", "_phase", "_backup_exists", "_message"))))
  }
  v <- r$value
  stats::setNames(
    list(v$state %||% NA, v$phase %||% NA, isTRUE(v$backup_exists), bv_one_line(v$message %||% "", 200)),
    paste0(prefix, c("_state", "_phase", "_backup_exists", "_message"))
  )
}

## ---- child process publish (for SIGKILL) --------------------------------------------
## The child sources the same runtime, builds v2 and publishes it; at the
## requested point it writes a marker file and sleeps until it is killed.
child_publish <- function(bv_root, case_dir, kill_at) {
  setwd(bv_root)
  source(file.path(bv_root, "scripts", "common.R"))
  rt <- bv_load_runtime()
  marker <- file.path(case_dir, "logs", "parked")
  park <- function(where) {
    writeLines(where, marker)
    ## "exit:" cases throw instead of parking; the child then ends normally
    if (startsWith(kill_at, "exit:")) stop("injected failure at ", where, call. = FALSE)
    Sys.sleep(3600)
  }
  hit <- function(at) identical(kill_at, at) || identical(kill_at, paste0("exit:", at))
  inspected <- bv_profile(rt, file.path(bv_data, "inputs", "visium_anterior1.rds"))
  work <- file.path(case_dir, "work-v2")
  dir.create(work, recursive = TRUE, showWarnings = FALSE)
  c_configure <- if (nzchar(Sys.getenv("C_BACKEND"))) list(expression_backend = Sys.getenv("C_BACKEND")) else list()
  settings <- bv_settings(rt, inspected, "Visium v2", c_configure, work)
  planned <- bv_plan(rt, "visium", inspected, settings,
                     file.path(bv_data, "inputs", "visium_anterior1.rds"),
                     work, file.path(case_dir, "release"), overwrite = TRUE)
  built <- bv_build(rt, planned, "visium", "visium-v2")
  rt$builder_coordinator_publish(
    built$handle, built$result,
    .on_progress = function(phase) if (hit(paste0("progress:", phase))) park(kill_at),
    .publish = function(handle, ...) {
      rt$builder_publish_release(
        handle, ...,
        .after_phase = function(phase) if (hit(phase)) park(phase),
        .after_move = function(move) if (hit(paste0("move:", move))) park(kill_at)
      )
    }
  )
  writeLines("finished", marker)
}

run_killed <- function(case_dir, kill_at) {
  dir.create(file.path(case_dir, "logs"), recursive = TRUE, showWarnings = FALSE)
  marker <- file.path(case_dir, "logs", "parked")
  proc <- callr::r_bg(child_publish, list(bv_root, case_dir, kill_at),
                      stdout = file.path(case_dir, "logs", "child.out"),
                      stderr = file.path(case_dir, "logs", "child.err"),
                      supervise = TRUE)
  deadline <- Sys.time() + 900
  while (proc$is_alive() && !file.exists(marker) && Sys.time() < deadline) Sys.sleep(0.2)
  parked <- if (file.exists(marker)) readLines(marker) else "never"
  pid <- proc$get_pid()
  if (startsWith(kill_at, "exit:")) {
    proc$wait(60000) # the child throws and exits on its own
    return(list(error = paste0("child pid ", pid, " threw at ", parked,
                               " and exited; exit status ", proc$get_exit_status())))
  }
  if (proc$is_alive()) proc$kill() # SIGKILL on Unix
  proc$wait(5000)
  list(error = paste0("child pid ", pid, " killed (SIGKILL) at ", parked,
                      "; exit status ", proc$get_exit_status()))
}

## ---- cases ------------------------------------------------------------------------------
fail_hook <- function(at) function(x) if (identical(x, at)) stop("injected failure at ", at, call. = FALSE)
publish_with <- function(...) {
  extra <- list(...)
  function(handle, ...) do.call(rt$builder_publish_release, c(list(handle, ...), extra))
}
## Fail the payload check at one phase, otherwise defer to the coordinator's own guard.
fail_payload_at <- function(at) function(handle, ..., .verify_payload) {
  rt$builder_publish_release(handle, ...,
    .verify_payload = function(root, phase) !identical(phase, at) && .verify_payload(root, phase))
}
tamper <- function(path) {
  con <- file(path, "ab")
  writeBin(as.raw(0x00), con)
  close(con)
}
staged_crb <- function(built) built$result$built[[1L]]

cases <- list(
  C00_no_fault = list(publish = function(b) list()),
  C01_verify_app_fails = list(where = "coordinator App verification, before the release lock",
    publish = function(b) list(.verify_app = function(...) stop("injected: App verification failed", call. = FALSE))),
  C02_payload_check_fails_before_rename = list(where = "payload verification after the v1 backup was made, before v2 is installed",
    publish = function(b) list(.publish = fail_payload_at("before_rename"))),
  C03_install_move_fails = list(where = "promotion: moving the v2 stage onto the release path",
    publish = function(b) list(.publish = function(handle, ...) rt$builder_publish_release(handle, ...,
      .move = function(from, to) {
        if (identical(rt$.canonicalTargetPath(from), rt$.canonicalTargetPath(handle$stage))) return(FALSE)
        file.rename(from, to)
      }))),
  C04_error_after_backup_move = list(where = "error thrown right after v1 was moved to the backup",
    publish = function(b) list(.publish = publish_with(.after_move = fail_hook("old_to_backup")))),
  C05_error_after_old_moved_phase = list(where = "error thrown after the old_moved journal phase",
    publish = function(b) list(.publish = publish_with(.after_phase = fail_hook("old_moved")))),
  C06_post_install_check_fails = list(where = "payload verification after v2 was installed",
    publish = function(b) list(.publish = fail_payload_at("after_rename"))),
  C07_error_after_new_published = list(where = "error thrown after the new_published journal phase",
    publish = function(b) list(.publish = publish_with(.after_phase = fail_hook("new_published")))),
  C08_restore_also_fails = list(where = "install move fails and the restore move fails too",
    publish = function(b) list(.publish = function(handle, ...) {
      moves <- 0L
      rt$builder_publish_release(handle, ..., .move = function(from, to) {
        moves <<- moves + 1L
        if (moves %in% c(2L, 3L)) return(FALSE)
        file.rename(from, to)
      })
    })),
  K1_kill_before_lock = list(kill = "progress:publish", where = "SIGKILL after verification, before publication starts"),
  K2_kill_old_moving = list(kill = "old_moving", where = "SIGKILL with journal at old_moving, before v1 is moved"),
  K3_kill_after_backup = list(kill = "move:old_to_backup", where = "SIGKILL right after v1 was moved to the backup"),
  K4_kill_old_moved = list(kill = "old_moved", where = "SIGKILL with v1 in backup and v2 not installed"),
  K5_kill_new_published = list(kill = "new_published", where = "SIGKILL after v2 was installed, before completion"),
  X1_error_after_backup_then_exit = list(kill = "exit:move:old_to_backup",
    where = "error thrown right after v1 was moved to the backup, in a child that then exits (as C04, owner gone)"),
  X2_error_after_new_published_then_exit = list(kill = "exit:new_published",
    where = "error thrown after new_published, in a child that then exits (as C07, owner gone)"),
  T1_tamper_stage_before_publish = list(where = "one byte appended to the staged v2 CRB after the build, before publish",
    before_publish = function(b) tamper(staged_crb(b)), publish = function(b) list()),
  T2_tamper_stage_after_record = list(where = "one byte appended to the staged v2 CRB after the ownership record, before the release lock",
    publish = function(b) list(.publish = function(handle, ...) {
      tamper(file.path(handle$stage, "cerebro_app", "private-data", basename(staged_crb(b))))
      rt$builder_publish_release(handle, ...)
    })),
  T3_tamper_stage_mid_publish = list(where = "one byte appended to the staged v2 CRB after v1 was moved to the backup",
    publish = function(b) list(.publish = function(handle, ...) rt$builder_publish_release(handle, ...,
      .after_phase = function(phase) if (identical(phase, "old_moved"))
        tamper(file.path(handle$stage, "cerebro_app", "private-data", basename(staged_crb(b))))))),
  T4_tamper_published_v1 = list(where = "one byte appended to the published v1 CRB after v2 was planned and built",
    before_publish = function(b) tamper(list.files(file.path(dirname(b$handle$stage), "..", "..", "release", "cerebro_app", "private-data"),
                                                   full.names = TRUE, pattern = "\\.crb$")[[1L]]),
    publish = function(b) list()),
  T5_foreign_file_in_release = list(where = "a foreign file written into the published v1 release before v2 is prepared",
    before_prepare = function(case_dir) writeLines("foreign", file.path(case_dir, "release", "notes.txt")),
    publish = function(b) list())
)
## With the HDF5 backend, the same tampering is applied to the .h5 sidecar.
if (identical(Sys.getenv("C_BACKEND"), "h5")) {
  staged_h5 <- function(b) sub("\\.crb$", ".h5", staged_crb(b))
  cases$T6_tamper_stage_h5_before_publish <- list(
    where = "one byte appended to the staged v2 .h5 sidecar after the build, before publish",
    before_publish = function(b) tamper(staged_h5(b)), publish = function(b) list())
  cases$T7_tamper_published_v1_h5 <- list(
    where = "one byte appended to the published v1 .h5 sidecar after v2 was planned and built",
    before_publish = function(b) tamper(list.files(file.path(dirname(b$handle$stage), "..", "..", "release", "cerebro_app", "private-data"),
                                                   full.names = TRUE, pattern = "\\.h5$")[[1L]]),
    publish = function(b) list())
}
## Crash and error cases are run once per recovery action.
expanded <- list()
for (id in names(cases)) {
  if (startsWith(id, "C00") || startsWith(id, "T")) {
    expanded[[id]] <- c(cases[[id]], list(action = "restore"))
  } else {
    for (a in c("restore", "abort")) expanded[[paste0(id, "__", a)]] <- c(cases[[id]], list(action = a))
  }
}
only <- commandArgs(trailingOnly = TRUE)
if (length(only)) expanded <- expanded[vapply(names(expanded), function(n) any(startsWith(n, only)), logical(1))]

rows <- list()
for (id in names(expanded)) {
  case <- expanded[[id]]
  cat("\n==== ", id, " ====\n", sep = "")
  case_dir <- file.path(root, id)
  unlink(case_dir, recursive = TRUE)
  dir.create(case_dir, recursive = TRUE)
  target <- file.path(case_dir, "release")
  t0 <- proc.time()[["elapsed"]]
  v1 <- bv_capture({
    b1 <- prepare_version(rt, case_dir, "v1", overwrite = FALSE)
    bv_publish(rt, b1)
  })
  if (!is.null(v1$error)) stop("v1 publish failed: ", v1$error)
  id_v1 <- identity_of(target)
  row <- list(case = sub("__.*", "", id), recovery_action = case$action, fault = case$where %||% "none",
              v1_published = isTRUE(v1$value$published))
  if (!is.null(case$before_prepare)) case$before_prepare(case_dir)
  if (!is.null(case$kill)) {
    attempt <- run_killed(case_dir, case$kill)
  } else {
    attempt <- bv_capture({
      b2 <- prepare_version(rt, case_dir, "v2", overwrite = TRUE)
      if (!is.null(case$before_publish)) case$before_publish(b2)
      ## As the app does (server/imports.R): builder_coordinator_settle()
      ## publishes and, when publication fails, aborts the release handle and
      ## reports the recovery state.
      injections <- case$publish(b2)
      settled <- rt$builder_coordinator_settle(
        b2$handle, b2$result,
        .publish = function(handle, result) do.call(rt$builder_coordinator_publish,
                                                    c(list(handle, result), injections)))
      if (!isTRUE(settled$ok)) {
        stop(settled$error, if (!is.null(settled$cleanup_error)) paste0(" [cleanup: ", settled$cleanup_error, "]"))
      }
      settled$value
    })
  }
  row$publish_v2_error <- bv_one_line(attempt$error %||% "", 400)
  row$publish_v2_succeeded <- is.null(attempt$error) && isTRUE(attempt$value$published)
  row$after_fault_release <- release_label(target, id_v1)
  row <- c(row, recovery_summary(target, "discover"))
  before <- residuals(case_dir)
  row$control_files_before_recovery <- before$control_files
  row$control_listing_before_recovery <- before$control_listing
  if (identical(row$discover_state, "recovery_required")) {
    rec <- bv_capture(rt$builder_recover_release(target, action = case$action))
    row$recover_result <- if (!is.null(rec$error)) paste("error:", bv_one_line(rec$error)) else
      paste0("recovered=", isTRUE(rec$value$recovered), " state=", rec$value$state %||% "")
  } else {
    rec <- bv_capture(rt$builder_recover_release(target, action = case$action))
    row$recover_result <- if (!is.null(rec$error)) paste("error:", bv_one_line(rec$error)) else
      paste0("not needed: recovered=", isTRUE(rec$value$recovered), " state=", rec$value$state %||% "")
  }
  row$final_release <- release_label(target, id_v1)
  crbs <- list.files(file.path(target, "cerebro_app", "private-data"), pattern = "\\.crb$", full.names = TRUE)
  row$final_crb_readable <- if (length(crbs)) isTRUE(tryCatch({
    x <- readCerebro(crbs[[1L]]); length(x$getCellNames()) == 2696L
  }, error = function(e) FALSE)) else NA
  row$final_crb_experiment <- if (length(crbs)) tryCatch(readCerebro(crbs[[1L]])$getExperiment()$experiment_name,
                                                          error = function(e) NA) else NA
  if (identical(Sys.getenv("C_BACKEND"), "h5")) {
    row$final_h5_sidecars <- length(list.files(file.path(target, "cerebro_app", "private-data"), pattern = "\\.h5$"))
    row$final_expression_readable <- if (length(crbs)) isTRUE(tryCatch({
      m <- readCerebro(crbs[[1L]])$getExpressionMatrix(); ncol(m) == 2696L
    }, error = function(e) FALSE)) else NA
  }
  row <- c(row, recovery_summary(target, "final"))
  row <- c(row, residuals(case_dir))
  row$seconds <- proc.time()[["elapsed"]] - t0
  str(row)
  rows[[id]] <- as.data.frame(lapply(row, function(x) if (is.null(x) || !length(x)) NA else x),
                              stringsAsFactors = FALSE)
}
all_cols <- unique(unlist(lapply(rows, names)))
rows <- lapply(rows, function(r) { r[setdiff(all_cols, names(r))] <- NA; r[all_cols] })
out <- do.call(rbind, rows)
utils::write.csv(out, file.path(bv_root, "results", Sys.getenv("C_OUT", "C_publish_faults.csv")), row.names = FALSE)
print(out[, c("case", "recovery_action", "after_fault_release", "discover_state", "recover_result", "final_release", "final_crb_experiment")])
