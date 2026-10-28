## Task 4, T3 (PROTOCOL_task4.md): (a) state saved with the tool's own mechanism and
## checked after a restart; (b) update of the artifact with the changed input,
## and an update whose build is killed halfway (SIGKILL).
## Usage: Rscript scripts/run/task4/t3.R   (after t1_t2.R, which gives the build times)
## Writes results/task4/task4_state.csv and results/task4/task4_update.csv.

source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))), "lib.R"))
root <- file.path(t4_runs, "t3")
unlink(root, recursive = TRUE)
dir.create(root, recursive = TRUE)
builds <- utils::read.csv(file.path(t4_results, "task4_build.csv"))
median_build <- function(tool) stats::median(builds$seconds[builds$tool == tool])

deploy_check <- function(tool, artifact, label) {
  s <- t4_start(tool, t4_app_dir(tool, artifact), file.path(root, paste0(label, ".log")))
  o <- t4_open(tool, s, timeout = 120)
  if (!is.null(o$page)) bv_close(o$page)
  t4_stop(s)
  o
}

## ---- (a) state ---------------------------------------------------------------
state_rows <- list()
state_row <- function(tool, mechanism, grade, steps, saved, restored, note) {
  state_rows[[length(state_rows) + 1L]] <<- data.frame(
    tool = tool, mechanism = mechanism, grade = grade, user_steps = steps,
    state_saved = saved, restored_after_restart = restored, note = note, stringsAsFactors = FALSE)
}

## CerebroNexus: Linked views "Share view" -> "Download JSON", then "Open JSON".
local({
  art <- t4_copy(file.path(t4_runs, "t1_t2", "cerebronexus", "build_1"), file.path(root, "cn_state"))
  app <- t4_app_dir("cerebronexus", art)
  s <- t4_start("cerebronexus", app, file.path(root, "cn_state_1.log"))
  o <- t4_open("cerebronexus", s)
  p <- o$page
  bv_js(p, "document.querySelector('a[href=\"#shiny-tab-coordinated_views\"]').click()")
  ready <- bv_wait_js(p, "!!(window.cerebroLinkedViewsState && cerebroLinkedViewsState.ready())", 120)
  bv_js(p, "(function(){var c=cerebroLinkedViewsState.capture();var idx=[];for(var i=0;i<25;i++)idx.push(i);cerebroLinkedViewsState.apply(c,null,idx);return true;})()")
  bv_idle(2)
  bv_js(p, "document.getElementById('cv-config-open').click()")
  bv_idle(0.5)
  bv_js(p, "document.getElementById('cv-config-download').click()")
  deadline <- Sys.time() + 30
  json <- NULL
  while (is.null(json) && Sys.time() < deadline) {
    bv_idle(0.5)
    f <- bv_frames_text(p, NULL, "in")
    f <- f[grepl("coordviews_config_result", f, fixed = TRUE)]
    if (length(f)) json <- jsonlite::fromJSON(f[[length(f)]], simplifyVector = FALSE)$custom$coordviews_config_result$json
  }
  bv_close(p)
  t4_stop(s)
  view <- file.path(root, "cn_view.json")
  if (!is.null(json)) writeLines(json, view)
  ## restart from the same artifact; open the saved view with the App's code
  s2 <- t4_start("cerebronexus", app, file.path(root, "cn_state_2.log"))
  o2 <- t4_open("cerebronexus", s2)
  if (!is.null(o2$page)) bv_close(o2$page)
  t4_stop(s2)
  restored <- if (file.exists(view)) {
    suppressWarnings(as.integer(utils::tail(system2("Rscript", c(file.path(t4_scripts, "cn_view_state.R"), app, view),
                                                    stdout = TRUE, stderr = FALSE, env = paste0("R_LIBS=", t4_cnlib)), 1)))
  } else NA_integer_
  state_row("cerebronexus", "Linked views: Share view -> Download JSON; Open JSON", "done", "save 2, restore 2 UI actions",
            !is.null(json), identical(restored, 25L),
            sprintf("25-cell selection saved (%s); after restart the App's decoder restores %s cells; the Open JSON file input was not driven",
                    if (is.null(json)) "no JSON" else "JSON", restored))
})

## cellxgene: user annotation saved by the server (--user-generated-data-dir).
local({
  art <- t4_copy(file.path(t4_runs, "t1_t2", "cellxgene", "build_1"), file.path(root, "cx_state"))
  udir <- file.path(root, "cx_state_user_data")
  dir.create(udir)
  s <- t4_start("cellxgene", art, file.path(root, "cx_state_1.log"), state_dir = udir)
  o <- t4_open("cellxgene", s)
  if (!is.null(o$page)) bv_close(o$page)
  put <- system2(t4_py, c(file.path(t4_scripts, "pytools.py"), "cx_annotate", s$url, file.path(art, "data.h5ad"), "task4_label", "100"),
                 stdout = TRUE, stderr = FALSE)
  t4_stop(s)
  s2 <- t4_start("cellxgene", art, file.path(root, "cx_state_2.log"), state_dir = udir)
  o2 <- t4_open("cellxgene", s2)
  cols <- system2(t4_py, c(file.path(t4_scripts, "pytools.py"), "cx_annotations", s2$url), stdout = TRUE, stderr = FALSE)
  if (!is.null(o2$page)) bv_close(o2$page)
  t4_stop(s2)
  files <- list.files(udir, recursive = TRUE, pattern = "cell-labels.*[.]csv$", full.names = TRUE)
  ## The saved file is named by a per-browser id held in a Flask session cookie
  ## whose key is new at every launch; the documented way to load saved labels
  ## into a new server is --annotations-file.
  restored_file <- NA
  if (length(files)) {
    port <- httpuv::randomPort(host = "127.0.0.1")
    p3 <- processx::process$new(t4_cellxgene, c("launch", "--host", "127.0.0.1", "--port", port,
                                                "--annotations-file", files[[1L]], "data.h5ad"),
                                wd = art, env = t4_env(c(HTTPS_PROXY = "http://127.0.0.1:9")),
                                stdout = file.path(root, "cx_state_3.log"), stderr = "2>&1", cleanup_tree = TRUE)
    url3 <- paste0("http://127.0.0.1:", port)
    deadline <- Sys.time() + 60
    while (is.na(t4_http_status(url3)) && Sys.time() < deadline) Sys.sleep(0.5)
    schema <- tryCatch(jsonlite::fromJSON(paste0(url3, "/api/v0.2/schema")), error = function(e) NULL)
    restored_file <- "task4_label" %in% schema$schema$annotations$obs$columns$name
    if (p3$is_alive()) p3$kill_tree()
  }
  state_row("cellxgene", "user annotations, saved by the server to --user-generated-data-dir; loaded again with --annotations-file",
            "manual", "save 3 UI actions (create category, label, assign); restore: restart with --annotations-file <saved csv>",
            any(grepl('"status": 200', put)), isTRUE(restored_file),
            sprintf("annotation written through the annotations/obs request of the UI (%s); saved file %s; same server restarted on the same directory: labels returned %s (a new session id after restart); restarted with --annotations-file: column present %s",
                    bv_one_line(put), paste(basename(files), collapse = ", "), bv_one_line(cols), restored_file))
})

state_row("shinycell", "none in the generated app", "absent", "-", FALSE, FALSE,
          "the generated ui.R/server.R have no save, bookmark or export of the app state")
state_row("isee", "panel settings exported as R code (\"Display panel settings\"), passed back as iSEE(initial = ...)",
          "manual", "save 2 UI actions; restore: edit app.R and restart", NA, NA,
          "restoring needs the user to put the code into app.R; not run")
state_row("vitessce", "the view config is a static config.json; changes in the page are not saved by the tool",
          "manual", "edit config.json", NA, NA, "not run")

## ---- (b) update and killed update ---------------------------------------------
update_rows <- list()
for (tool in t4_tools) {
  a <- file.path(root, paste0(tool, "_update"))
  b1 <- t4_build(tool, t4_input, a, file.path(root, paste0(tool, "_v1.log")))
  c1 <- t4_cells(tool, a)
  b2 <- t4_build(tool, t4_input2, a, file.path(root, paste0(tool, "_v2.log")))
  c2 <- t4_cells(tool, a)
  d2 <- deploy_check(tool, t4_copy(a, paste0(a, "_deploy")), paste0(tool, "_update_serve"))

  k <- file.path(root, paste0(tool, "_killed"))
  t4_build(tool, t4_input, k, file.path(root, paste0(tool, "_k1.log")))
  ck1 <- t4_cells(tool, k)
  after <- max(0.05, median_build(tool) / 2)
  kill <- t4_build_killed(tool, t4_input2, k, file.path(root, paste0(tool, "_k2.log")), after)
  ck2 <- t4_cells(tool, k)
  recovery <- ""
  if (identical(tool, "cerebronexus")) {
    recovery <- utils::tail(system2("Rscript", c(file.path(t4_scripts, "cn_recover.R"), k), stdout = TRUE, stderr = FALSE,
                                    env = paste0("R_LIBS=", t4_cnlib)), 1)
  }
  ck3 <- t4_cells(tool, k)
  dk <- deploy_check(tool, t4_copy(k, paste0(k, "_deploy")), paste0(tool, "_killed_serve"))
  version <- function(n) if (is.na(n)) "unreadable" else if (n == 2638L) "v1" else if (n == 2538L) "v2" else paste(n, "cells")
  update_rows[[length(update_rows) + 1L]] <- data.frame(
    tool = tool, v1_cells = c1, update_exit = b2$status, after_update = version(c2),
    update_deploy_drawn = d2$drawn, kill_after_s = round(after, 2),
    killed_while_running = kill$killed_while_running, after_kill = version(ck2),
    recovery = recovery, after_recovery = version(ck3), killed_deploy_http = dk$http,
    killed_deploy_drawn = dk$drawn, stringsAsFactors = FALSE)
  cat(tool, "update", version(c2), "killed", version(ck2), "->", version(ck3), dk$drawn, "\n")
}

utils::write.csv(do.call(rbind, state_rows), file.path(t4_results, "task4_state.csv"), row.names = FALSE)
utils::write.csv(do.call(rbind, update_rows), file.path(t4_results, "task4_update.csv"), row.names = FALSE)
