## Shared helpers of the Task 4 driver: paths, timed tool processes, servers
## and the "main view drawn" check in headless Chrome.

`%||%` <- function(a, b) if (is.null(a)) b else a
t4_here <- local({
  file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  normalizePath(if (length(file)) file.path(dirname(file[[1L]]), "..", "..", "..") else ".")
})
t4_scripts <- file.path(t4_here, "scripts", "run", "task4")
t4_results <- file.path(t4_here, "results", "task4")
t4_bv <- normalizePath(file.path(t4_here, "..", "builder_validation"))
## T4_G: tool installs and run directories (recorded runs: /Volumes/bv_cache/g).
G <- Sys.getenv("T4_G", file.path(t4_here, "env", "g"))
t4_py <- file.path(G, "py", "bin", "python")
t4_cellxgene <- file.path(G, "py", "bin", "cellxgene")
t4_glib <- file.path(G, "rlib")
t4_cnlib <- normalizePath(file.path(t4_bv, "env", "rlib"))
## the Viewer library without CerebroNexus, as in builder_validation/scripts/viewer.R
t4_viewer_lib <- Sys.getenv("BV_HERMETIC_LIB", file.path(t4_bv, "env", "hermetic-lib"))
t4_js <- file.path(G, "vjs", "out")
t4_input <- file.path(G, "inputs", "pbmc3k.h5ad")
t4_input2 <- file.path(G, "inputs", "pbmc3k_minus100.h5ad")
t4_runs <- file.path(G, "runs")
bv_one_line <- function(x, max = 300L) {
  x <- gsub("\\s+", " ", paste(x, collapse = " | "))
  if (nchar(x) > max) paste0(substr(x, 1, max), "...") else x
}
source(file.path(t4_bv, "scripts", "browser.R"))
t4_tools <- c("cerebronexus", "shinycell", "isee", "cellxgene", "vitessce")

t4_env <- function(extra = character()) {
  e <- Sys.getenv()
  e <- stats::setNames(as.character(e), names(e))
  e[names(extra)] <- extra
  e
}

## The documented build route of each tool as one process.
t4_build_command <- function(tool, src, out) {
  switch(tool,
    cerebronexus = list("Rscript", c(file.path(t4_scripts, "build_cerebronexus.R"), src, out,
                                     paste0(out, "_work_", format(Sys.time(), "%H%M%OS3"))),
                        c(R_LIBS = t4_cnlib)),
    shinycell = list("Rscript", c(file.path(t4_scripts, "build_shinycell.R"), src, out), c(R_LIBS = t4_glib)),
    isee = list("Rscript", c(file.path(t4_scripts, "build_isee.R"), src, out), c(R_LIBS = t4_glib)),
    cellxgene = list(t4_py, c(file.path(t4_scripts, "pytools.py"), "copy", src, out), character()),
    vitessce = list(t4_py, c(file.path(t4_scripts, "pytools.py"), "vitessce", src, out), character()))
}

## Run a build to the end; seconds and exit status.
t4_build <- function(tool, src, out, log) {
  cmd <- t4_build_command(tool, src, out)
  t0 <- proc.time()[["elapsed"]]
  p <- processx::process$new(cmd[[1]], cmd[[2]], env = t4_env(cmd[[3]]),
                             stdout = log, stderr = "2>&1")
  p$wait()
  list(seconds = proc.time()[["elapsed"]] - t0, status = p$get_exit_status())
}

## Start a build and SIGKILL it after `after` seconds.
t4_build_killed <- function(tool, src, out, log, after) {
  cmd <- t4_build_command(tool, src, out)
  p <- processx::process$new(cmd[[1]], cmd[[2]], env = t4_env(cmd[[3]]),
                             stdout = log, stderr = "2>&1", cleanup_tree = TRUE)
  Sys.sleep(after)
  alive <- p$is_alive()
  ## the process may end between the check and the signal
  if (alive) alive <- !inherits(tryCatch(p$kill_tree(), error = function(e) e), "error")
  p$wait()
  list(killed_while_running = alive, status = p$get_exit_status())
}

## Server for an artifact directory, started from that directory only.
t4_server_command <- function(tool, dir, port, state_dir = NULL) {
  ## The CerebroNexus App runs on a library without CerebroNexus (it must be
  ## self-contained); the others on the tools' library before the user's.
  shiny_cmd <- function(lib, only = FALSE) list("Rscript", c("-e", sprintf(
    "shiny::runApp('.', port = %d, host = '127.0.0.1', launch.browser = FALSE)", port)),
    if (only) c(R_LIBS = lib, R_LIBS_USER = lib) else c(R_LIBS = lib))
  switch(tool,
    cerebronexus = shiny_cmd(t4_viewer_lib, only = TRUE),
    shinycell = shiny_cmd(t4_glib),
    isee = shiny_cmd(t4_glib),
    cellxgene = list(t4_cellxgene, c("launch", "--host", "127.0.0.1", "--port", port,
                                     "--user-generated-data-dir", state_dir %||% file.path(dir, "user-data"),
                                     "data.h5ad"),
                     c(HTTPS_PROXY = "http://127.0.0.1:9", HTTP_PROXY = "http://127.0.0.1:9")),
    vitessce = list(t4_py, c(file.path(t4_scripts, "serve_vitessce.py"), dir, port, t4_js), character()))
}

t4_start <- function(tool, dir, log, state_dir = NULL) {
  port <- httpuv::randomPort(host = "127.0.0.1")
  cmd <- t4_server_command(tool, dir, port, state_dir)
  t0 <- proc.time()[["elapsed"]]
  p <- processx::process$new(cmd[[1]], cmd[[2]], wd = dir, env = t4_env(cmd[[3]]),
                             stdout = log, stderr = "2>&1", cleanup_tree = TRUE)
  list(proc = p, port = port, url = paste0("http://127.0.0.1:", port), t0 = t0, log = log)
}

t4_stop <- function(server) {
  if (server$proc$is_alive()) server$proc$kill_tree()
  try(server$proc$wait(5000), silent = TRUE)
  invisible(NULL)
}

t4_http_status <- function(url) {
  tryCatch(httr::status_code(httr::GET(url, httr::timeout(5))), error = function(e) NA_integer_)
}

## The main embedding view of each tool (targets of Tasks 1-3), drawn.
t4_view_js <- c(
  shinycell = "(function(){var i=document.querySelector('#sc1a1oup1 img');return !!(i&&i.complete&&i.naturalWidth>100);})()",
  isee = "(function(){var i=document.querySelector('#ReducedDimensionPlot1 img');return !!(i&&i.complete&&i.naturalWidth>100);})()",
  cellxgene = "(function(){var c=document.querySelector('canvas.graph-canvas');return !!(c&&c.width>100&&c.height>100);})()",
  vitessce = "(function(){var c=document.querySelector('canvas#deckgl-overlay, canvas[id^=deckgl-overlay]');return !!(c&&c.width>100);})()"
)

## Wait for HTTP, open the page and wait for the main view; seconds from the
## server process start. CerebroNexus: the Gene expression projection with one
## gene (as builder_validation/scripts/viewer.R), after login when `login`.
t4_open <- function(tool, server, login = NULL, timeout = 180) {
  deadline <- Sys.time() + timeout
  status <- NA_integer_
  while (Sys.time() < deadline && server$proc$is_alive()) {
    status <- t4_http_status(server$url)
    if (!is.na(status)) break
    Sys.sleep(0.25)
  }
  out <- list(http = status, drawn = FALSE, seconds = NA_real_, page = NULL)
  if (is.na(status)) return(out)
  page <- bv_browser(tool)
  out$page <- page
  bv_goto(page, server$url)
  if (!is.null(login)) {
    out$login <- bv_login(page, login[[1]], login[[2]])
  }
  out$drawn <- if (identical(tool, "cerebronexus")) {
    bv_show_gene(page, "NKG7", timeout = timeout)
  } else {
    bv_wait_js(page, t4_view_js[[tool]], timeout = timeout)
  }
  out$seconds <- proc.time()[["elapsed"]] - server$t0
  out
}

## Cells in an artifact, read from its files (NA when it cannot be read).
t4_cells <- function(tool, dir) {
  r <- function(lib, expr) {
    out <- tryCatch(system2("Rscript", c("-e", shQuote(expr)), stdout = TRUE, stderr = FALSE,
                            env = paste0("R_LIBS=", lib)), error = function(e) character())
    suppressWarnings(as.integer(utils::tail(out, 1)))
  }
  value <- switch(tool,
    cerebronexus = r(t4_cnlib, sprintf(
      "x <- CerebroNexus::readCerebro(list.files('%s', pattern='[.]crb$', full.names=TRUE)[1]); cat(length(x$getCellNames()))",
      file.path(dir, "cerebro_app", "private-data"))),
    shinycell = r(t4_glib, sprintf("cat(nrow(readRDS('%s')))", file.path(dir, "sc1meta.rds"))),
    isee = r(t4_glib, sprintf("suppressMessages(library(SingleCellExperiment)); cat(ncol(readRDS('%s')))", file.path(dir, "sce.rds"))),
    cellxgene = suppressWarnings(as.integer(utils::tail(system2(t4_py, c(file.path(t4_scripts, "pytools.py"), "n_obs",
                                                                        file.path(dir, "data.h5ad")), stdout = TRUE, stderr = FALSE), 1))),
    vitessce = suppressWarnings(as.integer(utils::tail(system2(t4_py, c(file.path(t4_scripts, "pytools.py"), "n_obs",
                                                                       file.path(dir, "data.zarr")), stdout = TRUE, stderr = FALSE), 1))))
  if (length(value) == 1L) value else NA_integer_
}

## Copy an artifact to a new empty directory (the deployment).
t4_copy <- function(src, dest) {
  unlink(dest, recursive = TRUE)
  dir.create(dest, recursive = TRUE)
  file.copy(list.files(src, all.files = TRUE, no.. = TRUE, full.names = TRUE), dest,
            recursive = TRUE, copy.mode = TRUE)
  dest
}

## The served directory of an artifact.
t4_app_dir <- function(tool, artifact) {
  if (identical(tool, "cerebronexus")) file.path(artifact, "cerebro_app") else artifact
}
