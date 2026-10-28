## Build one generated Viewer App through the headless Builder route of
## common.R, optionally with login accounts (E) or another expression backend
## (F). The login route follows the Builder server (server/imports.R,
## dispatch_builder_worker_request()): the BuildPlan carries only the account
## summary (builder_auth_summary()), the accounts go to
## builder_auth_create_material() in the coordinator's stage, and the material
## is handed to builder_execute_plan().

bv_accounts <- function(...) {
  pairs <- list(...)
  structure(
    lapply(seq_along(pairs), function(i) {
      list(id = paste0("auth-account-", i), username = names(pairs)[[i]],
           password = pairs[[i]])
    }),
    class = c("builder_auth_accounts", "list")
  )
}

bv_build_app <- function(rt, id, label, input = NULL, object = NULL, work,
                         release, configure = list(), accounts = NULL) {
  unlink(c(work, release), recursive = TRUE)
  dir.create(work, recursive = TRUE, showWarnings = FALSE)
  t0 <- proc.time()[["elapsed"]]
  inspected <- bv_profile(rt, input, object, id)
  settings <- bv_settings(rt, inspected, label, configure, work)
  snapshot <- rt$builder_snapshot_seurat(inspected$object, file.path(work, "snapshot"),
                                         available_bytes = 2^40)
  entry <- list(
    id = id, source_id = id, output_id = id,
    path = input %||% id, filename = basename(input %||% id),
    source_origin = "upload", format = inspected$format,
    profile = inspected$legacy_profile, dataset_profile = inspected$profile,
    snapshot = snapshot, revision = 1L, levels = inspected$levels %||% list(),
    settings = settings
  )
  app_auth <- if (is.null(accounts)) {
    list(enabled = FALSE, account_count = 0L, timeout_minutes = 15L)
  } else {
    rt$builder_auth_summary(TRUE, accounts)
  }
  plan <- rt$builder_freeze_plan(
    list(entry), release, make_app = TRUE,
    app_options = list(launch_browser = FALSE, show_upload_ui = FALSE),
    app_auth = app_auth
  )
  if (!is.null(plan$error)) stop("BuildPlan was not frozen: ", bv_one_line(unlist(plan$error)))
  handle <- rt$builder_coordinator_prepare(plan, paste0(id, "-app"))
  material <- if (is.null(accounts)) NULL else rt$builder_auth_create_material(accounts, handle$stage)
  result <- rt$builder_execute_plan(plan, handle$stage, stats::setNames(list(snapshot), id),
                                    auth_material = material)
  material <- NULL
  if (!identical(result$state, "success")) stop("Build failed: ", bv_one_line(result$error %||% result$state))
  result$build_id <- handle$build_id
  published <- rt$builder_coordinator_publish(handle, result)
  if (!isTRUE(published$published)) stop("Not published: ", bv_one_line(published$error %||% ""))
  list(
    id = id, app_dir = published$app_dir, release = release, work = work,
    crb = published$built[[1L]], settings = settings, plan = plan,
    seconds = proc.time()[["elapsed"]] - t0
  )
}

## Start a generated App as a deployment would (no test mode), in a separate
## R process whose library has every package except CerebroNexus.
bv_start_app <- function(app_dir, label, logs, env = character(), port = NULL) {
  lib <- bv_hermetic_library(dirname(logs))
  port <- port %||% httpuv::randomPort(host = "127.0.0.1")
  dir.create(logs, showWarnings = FALSE, recursive = TRUE)
  stdout <- file.path(logs, paste0(label, ".stdout"))
  stderr <- file.path(logs, paste0(label, ".stderr"))
  proc <- callr::r_bg(
    function(app_dir, port) {
      if (requireNamespace("CerebroNexus", quietly = TRUE)) {
        stop("CerebroNexus is reachable; the library is not hermetic")
      }
      shiny::runApp(app_dir, port = port, host = "127.0.0.1",
                    launch.browser = FALSE, quiet = FALSE)
    },
    args = list(app_dir = app_dir, port = port),
    libpath = lib, stdout = stdout, stderr = stderr, supervise = TRUE,
    env = local({
      e <- Sys.getenv()
      e <- stats::setNames(as.character(e), names(e))
      e <- e[names(e) != "CEREBRO_AUTH_PASSPHRASE"]
      e[names(env)] <- env
      e
    })
  )
  url <- paste0("http://127.0.0.1:", port)
  deadline <- Sys.time() + 120
  status <- NA_integer_
  while (Sys.time() < deadline && proc$is_alive()) {
    status <- tryCatch(httr::status_code(httr::GET(url, httr::timeout(2))),
                       error = function(e) NA_integer_)
    if (!is.na(status)) break
    Sys.sleep(0.5)
  }
  list(proc = proc, url = url, port = port, status = status,
       stdout = stdout, stderr = stderr, alive = proc$is_alive())
}

bv_stop_app <- function(app) {
  if (app$proc$is_alive()) app$proc$kill_tree()
  try(app$proc$wait(timeout = 5000), silent = TRUE)
  invisible(NULL)
}

bv_read_text <- function(path) {
  if (!file.exists(path)) return("")
  paste(readLines(path, warn = FALSE), collapse = "\n")
}
