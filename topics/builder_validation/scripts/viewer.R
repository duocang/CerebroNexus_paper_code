## Start a published Viewer App and check that it serves and loads its dataset.
##
## Mirrors builder_e2e_run_generated_app() and privacy_start_app() in
## tests/testthat/helper-builder-end-to-end.R / helper-app-privacy.R: the App
## runs in a separate R process (callr) with a library that does NOT contain
## CerebroNexus (the generated App must be self-contained); a headless Chrome
## (shinytest2/chromote) opens it, goes to Gene expression, selects a gene and
## waits until the projection canvas has painted points; for spatial data it
## also requires the Spatial page and, if an image was configured, the image
## in the Linked views background picker.

## shinytest2 skips AppDriver outside tests unless NOT_CRAN is set.
Sys.setenv(NOT_CRAN = "true")

bv_hermetic_library <- function(root) {
  ## BV_HERMETIC_LIB: a directory on a file system with symlinks (the data
  ## drive is exFAT).
  lib <- Sys.getenv("BV_HERMETIC_LIB", file.path(root, "hermetic-lib"))
  if (dir.exists(lib)) return(lib)
  dir.create(lib, recursive = TRUE)
  for (source in .libPaths()) {
    for (package in list.dirs(source, recursive = FALSE, full.names = FALSE)) {
      target <- file.path(lib, package)
      if (identical(package, "CerebroNexus") || file.exists(target)) next
      file.symlink(file.path(source, package), target)
    }
  }
  lib
}

bv_viewer_check <- function(app_dir, root, gene, spatial = FALSE,
                            image_label = NULL, label = "viewer",
                            timeout = 120000) {
  t0 <- proc.time()[["elapsed"]]
  out <- list(http_status = NA_integer_, viewer_loaded = FALSE,
              spatial_page = NA, image_listed = NA, viewer_error = "",
              viewer_seconds = NA_real_)
  lib <- bv_hermetic_library(root)
  port <- httpuv::randomPort(host = "127.0.0.1")
  logs <- file.path(root, "viewer-logs")
  dir.create(logs, showWarnings = FALSE, recursive = TRUE)
  proc <- callr::r_bg(
    function(app_dir, port) {
      if (requireNamespace("CerebroNexus", quietly = TRUE)) {
        stop("CerebroNexus is reachable; the library is not hermetic")
      }
      shiny::runApp(app_dir, port = port, host = "127.0.0.1",
                    launch.browser = FALSE, quiet = TRUE, test.mode = TRUE)
    },
    args = list(app_dir = app_dir, port = port),
    libpath = lib,
    stdout = file.path(logs, paste0(label, ".stdout")),
    stderr = file.path(logs, paste0(label, ".stderr")),
    supervise = TRUE
  )
  on.exit(try(proc$kill(), silent = TRUE), add = TRUE)
  url <- paste0("http://127.0.0.1:", port)
  deadline <- Sys.time() + 120
  while (Sys.time() < deadline && proc$is_alive()) {
    status <- tryCatch(httr::status_code(httr::GET(url, httr::timeout(2))),
                       error = function(e) NA_integer_)
    if (!is.na(status)) {
      out$http_status <- status
      break
    }
    Sys.sleep(0.5)
  }
  if (!identical(out$http_status, 200L)) {
    out$viewer_error <- bv_one_line(c("no HTTP 200",
      tryCatch(utils::tail(readLines(file.path(logs, paste0(label, ".stderr"))), 5),
               error = function(e) "")))
    out$viewer_seconds <- proc.time()[["elapsed"]] - t0
    return(out)
  }
  driver <- NULL
  res <- tryCatch({
    driver <- shinytest2::AppDriver$new(url, name = label, load_timeout = timeout)
    driver$wait_for_idle(timeout = timeout)
    driver$wait_for_js(paste0(
      "document.querySelector('a[href=\"#shiny-tab-geneExpression\"]') !== null && ",
      "window.Shiny && Shiny.shinyapp.$socket.readyState === 1"), timeout = timeout)
    driver$click(selector = "a[href='#shiny-tab-geneExpression']")
    driver$wait_for_js(paste0(
      "document.getElementById('expression_genes_input') !== null && ",
      "document.getElementById('expression_feedback') && ",
      "window.cerebroCellViews?.summary('expression_projection').ready"),
      timeout = timeout)
    g <- jsonlite::toJSON(gene, auto_unbox = TRUE)
    driver$run_js(paste0(
      "(function(){var el=document.getElementById('expression_genes_input');",
      "el.selectize.addOption({value:", g, ",label:", g, "});",
      "el.selectize.setValue([", g, "]);})()"))
    driver$wait_for_js(paste0(
      "(function(){var host=document.getElementById('expression_projection_cell_view_host');",
      "var canvas=host&&host.querySelector('canvas:not(.cv-mini)');",
      "var fb=document.getElementById('expression_feedback');",
      "return !!(canvas&&canvas.width>0&&Number(canvas.dataset.pointCount)>0&&fb&&fb.hidden&&",
      "host.innerText.includes(", g, ")&&!fb.classList.contains('is-pending'));})()"),
      timeout = timeout)
    points <- driver$get_js(
      "Number(document.querySelector('#expression_projection_cell_view_host canvas:not(.cv-mini)').dataset.pointCount)")
    has_spatial <- isTRUE(driver$get_js(paste0(
      "(function(){var l=document.querySelector('a[href=\"#shiny-tab-spatial\"]');",
      "return !!(l&&l.offsetParent!==null);})()")))
    image_ok <- NA
    if (!is.null(image_label)) {
      driver$click(selector = "a[href='#shiny-tab-coordinated_views']")
      lab <- jsonlite::toJSON(image_label, auto_unbox = TRUE)
      image_ok <- isTRUE(tryCatch({
        driver$wait_for_js(paste0(
          "(function(){var p=document.getElementById('cv-bg-image-select');",
          "var labels=p?Array.from(p.options).map(function(x){return x.textContent;}):[];",
          "var c=document.querySelector('.cv-pane:not(.cv-hidden) canvas[id^=\"cv-cv-\"]');",
          "return labels.indexOf(", lab, ")>=0&&c&&c.width>0&&c.height>0;})()"),
          timeout = timeout)
        TRUE
      }, error = function(e) FALSE))
    }
    list(points = points, has_spatial = has_spatial, image_ok = image_ok)
  }, error = function(e) e)
  if (!is.null(driver)) try(driver$stop(), silent = TRUE)
  if (inherits(res, "error")) {
    out$viewer_error <- bv_one_line(conditionMessage(res))
  } else {
    out$viewer_loaded <- TRUE
    out$painted_points <- res$points
    out$spatial_page <- res$has_spatial
    out$image_listed <- res$image_ok
  }
  out$viewer_seconds <- proc.time()[["elapsed"]] - t0
  out
}
