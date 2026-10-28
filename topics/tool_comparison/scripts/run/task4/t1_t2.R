## Task 4, T1 build and T2 deploy (PROTOCOL_task4.md), three runs each per tool.
## Usage: Rscript scripts/run/task4/t1_t2.R
## Writes results/task4/task4_build.csv and results/task4/task4_deploy.csv.

source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))), "lib.R"))
root <- file.path(t4_runs, "t1_t2")
unlink(root, recursive = TRUE)
dir.create(root, recursive = TRUE)
runs <- as.integer(Sys.getenv("T4_RUNS", "3"))

## The artifact's data files, requested by URL from the running server
## (relative to the served directory).
data_paths <- list(
  cerebronexus = function(app) file.path("private-data", basename(list.files(file.path(app, "private-data"), pattern = "[.]crb$"))),
  shinycell = function(app) c("sc1gexpr.h5", "sc1meta.rds"),
  isee = function(app) "sce.rds",
  cellxgene = function(app) c("data.h5ad", "api/v0.2/schema", "api/v0.2/annotations/obs"),
  vitessce = function(app) c("data.zarr/.zgroup", "data.zarr/obs/.zattrs", "config.json")
)

build_rows <- list()
deploy_rows <- list()
for (tool in t4_tools) {
  for (run in seq_len(runs)) {
    out <- file.path(root, tool, paste0("build_", run))
    b <- t4_build(tool, t4_input, out, file.path(root, paste0(tool, "_build_", run, ".log")))
    cells <- t4_cells(tool, out)
    build_rows[[length(build_rows) + 1L]] <- data.frame(
      tool = tool, run = run, exit_status = b$status, seconds = round(b$seconds, 2),
      artifact_bytes = sum(file.size(list.files(out, recursive = TRUE, full.names = TRUE, all.files = TRUE))),
      cells = cells, stringsAsFactors = FALSE)
    cat(tool, "build", run, b$status, round(b$seconds, 1), "s", cells, "cells\n")

    dep <- t4_copy(out, file.path(root, tool, paste0("deploy_", run)))
    app <- t4_app_dir(tool, dep)
    s <- t4_start(tool, app, file.path(root, paste0(tool, "_serve_", run, ".log")))
    o <- t4_open(tool, s)
    reach <- vapply(data_paths[[tool]](app), function(p) t4_http_status(paste0(s$url, "/", p)), 1L)
    if (!is.null(o$page)) bv_close(o$page)
    t4_stop(s)
    deploy_rows[[length(deploy_rows) + 1L]] <- data.frame(
      tool = tool, run = run, login = FALSE, http = o$http, view_drawn = o$drawn,
      seconds_to_view = round(o$seconds, 2),
      data_file_requests = paste(names(reach), reach, sep = " -> ", collapse = "; "),
      data_reachable = any(reach == 200L, na.rm = TRUE), stringsAsFactors = FALSE)
    cat(tool, "deploy", run, o$http, o$drawn, round(o$seconds, 1), "s\n")
  }
}

## CerebroNexus is the only one of the five that documents a login for its
## exported App (Builder "Login" accounts); the other four document none.
login <- c("alice", "task4-alice-5r7t9")   # generated test account of this local App
Sys.setenv(TASK4_PASSWORD = login[[2]])
for (run in seq_len(runs)) {
  out <- file.path(root, "cerebronexus_login", paste0("build_", run))
  cmd <- t4_build_command("cerebronexus", t4_input, out)
  t0 <- proc.time()[["elapsed"]]
  p <- processx::process$new(cmd[[1]], c(cmd[[2]], "login"), env = t4_env(cmd[[3]]),
                             stdout = file.path(root, paste0("cerebronexus_login_build_", run, ".log")), stderr = "2>&1")
  p$wait()
  build_rows[[length(build_rows) + 1L]] <- data.frame(
    tool = "cerebronexus (login)", run = run, exit_status = p$get_exit_status(),
    seconds = round(proc.time()[["elapsed"]] - t0, 2),
    artifact_bytes = sum(file.size(list.files(out, recursive = TRUE, full.names = TRUE, all.files = TRUE))),
    cells = t4_cells("cerebronexus", out), stringsAsFactors = FALSE)
  dep <- t4_copy(out, file.path(root, "cerebronexus_login", paste0("deploy_", run)))
  app <- t4_app_dir("cerebronexus", dep)
  s <- t4_start("cerebronexus", app, file.path(root, paste0("cerebronexus_login_serve_", run, ".log")))
  o <- t4_open("cerebronexus", s, login = login)
  reach <- vapply(data_paths$cerebronexus(app), function(p) t4_http_status(paste0(s$url, "/", p)), 1L)
  if (!is.null(o$page)) bv_close(o$page)
  t4_stop(s)
  deploy_rows[[length(deploy_rows) + 1L]] <- data.frame(
    tool = "cerebronexus", run = run, login = TRUE, http = o$http,
    view_drawn = o$drawn && identical(o$login, "app"), seconds_to_view = round(o$seconds, 2),
    data_file_requests = paste(names(reach), reach, sep = " -> ", collapse = "; "),
    data_reachable = any(reach == 200L, na.rm = TRUE), stringsAsFactors = FALSE)
}

utils::write.csv(do.call(rbind, build_rows), file.path(t4_results, "task4_build.csv"), row.names = FALSE)
utils::write.csv(do.call(rbind, deploy_rows), file.path(t4_results, "task4_deploy.csv"), row.names = FALSE)
