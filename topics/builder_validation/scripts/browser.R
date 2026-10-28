## Headless Chrome through chromote (CDP) for the E and F experiments: every
## page records the websocket frames it sends and receives and the URLs it
## requests, so tests can check what reached the browser and when.

bv_browser <- function(label = "page") {
  b <- chromote::ChromoteSession$new(width = 1400, height = 1000)
  log <- new.env(parent = emptyenv())
  log$frames <- list()
  log$requests <- character()
  log$documents <- character()
  log$phase <- "start"
  b$Network$enable()
  b$Page$enable()
  b$Network$webSocketFrameReceived(callback_ = function(m) {
    log$frames[[length(log$frames) + 1L]] <- list(
      dir = "in", phase = log$phase, time = Sys.time(),
      data = m$response$payloadData %||% "")
  })
  b$Network$webSocketFrameSent(callback_ = function(m) {
    log$frames[[length(log$frames) + 1L]] <- list(
      dir = "out", phase = log$phase, time = Sys.time(),
      data = m$response$payloadData %||% "")
  })
  b$Network$requestWillBeSent(callback_ = function(m) {
    log$requests <- c(log$requests, m$request$url)
    if (identical(m$type, "Document")) log$documents <- c(log$documents, m$request$url)
  })
  list(b = b, log = log, label = label)
}

bv_js <- function(page, expr) {
  r <- page$b$Runtime$evaluate(expr, returnByValue = TRUE, awaitPromise = TRUE)
  if (!is.null(r$exceptionDetails)) {
    stop("JS error: ", bv_one_line(r$exceptionDetails$exception$description %||% r$exceptionDetails$text))
  }
  r$result$value
}

bv_wait_js <- function(page, expr, timeout = 60, interval = 0.25) {
  deadline <- Sys.time() + timeout
  repeat {
    ok <- tryCatch(isTRUE(bv_js(page, expr)), error = function(e) FALSE)
    if (ok) return(TRUE)
    if (Sys.time() > deadline) return(FALSE)
    later::run_now(interval)
    Sys.sleep(interval)
  }
}

## Keep the event loop running (frames and requests keep arriving).
bv_idle <- function(seconds) {
  deadline <- Sys.time() + seconds
  while (Sys.time() < deadline) {
    later::run_now(0.2)
    Sys.sleep(0.2)
  }
}

bv_goto <- function(page, url, ready = "document.readyState === 'complete'", timeout = 60) {
  page$b$Page$navigate(url, wait_ = FALSE)
  Sys.sleep(0.5)
  bv_wait_js(page, ready, timeout = timeout)
}

bv_socket_open <- "!!(window.Shiny && Shiny.shinyapp && Shiny.shinyapp.$socket && Shiny.shinyapp.$socket.readyState === 1)"
bv_login_form <- "!!document.getElementById('auth-user_id') && !!document.getElementById('auth-go_auth')"
bv_viewer_ui <- "document.querySelector('a[href=\"#shiny-tab-geneExpression\"]') !== null"

## Fill the provider's login form and press Sign in. Returns "app" (the
## Viewer UI appeared), "error" (the provider's error message) or "timeout".
bv_login <- function(page, user, password, timeout = 60) {
  if (!bv_wait_js(page, paste(bv_login_form, "&&", bv_socket_open), timeout)) return("no_form")
  before <- bv_js(page, "(document.getElementById('auth-msg_auth')||{}).innerText || ''")
  bv_js(page, sprintf(paste0(
    "(function(){var u=document.getElementById('auth-user_id'),p=document.getElementById('auth-user_pwd');",
    "$(u).val(%s).trigger('change');$(p).val(%s).trigger('change');",
    "window.__bv_err=document.getElementById('auth-msg_auth');",
    "setTimeout(function(){document.getElementById('auth-go_auth').click();},150);return true;})()"),
    jsonlite::toJSON(user, auto_unbox = TRUE), jsonlite::toJSON(password, auto_unbox = TRUE)))
  deadline <- Sys.time() + timeout
  repeat {
    state <- tryCatch(bv_js(page, paste0(
      "(function(){if(document.querySelector('a[href=\"#shiny-tab-geneExpression\"]'))return 'app';",
      "var e=document.getElementById('auth-msg_auth');",
      "if(e && e!==window.__bv_err && e.innerText.trim().length)return 'error';return '';})()")),
      error = function(e) "")
    if (nzchar(state)) return(state)
    if (Sys.time() > deadline) return("timeout")
    later::run_now(0.2)
    Sys.sleep(0.2)
  }
}

## Viewer ready, then show one gene on the Gene expression page (as viewer.R).
bv_show_gene <- function(page, gene, timeout = 120) {
  ok <- bv_wait_js(page, paste(bv_viewer_ui, "&&", bv_socket_open), timeout)
  if (!ok) return(FALSE)
  bv_js(page, "document.querySelector('a[href=\"#shiny-tab-geneExpression\"]').click()")
  ok <- bv_wait_js(page, paste0(
    "document.getElementById('expression_genes_input') !== null && ",
    "!!document.getElementById('expression_genes_input').selectize && ",
    "!!(window.cerebroCellViews && window.cerebroCellViews.summary('expression_projection').ready)"), timeout)
  if (!ok) return(FALSE)
  g <- jsonlite::toJSON(gene, auto_unbox = TRUE)
  bv_js(page, paste0(
    "(function(){var el=document.getElementById('expression_genes_input');",
    "el.selectize.addOption({value:", g, ",label:", g, "});",
    "el.selectize.setValue([", g, "]);return true;})()"))
  bv_wait_js(page, paste0(
    "(function(){var host=document.getElementById('expression_projection_cell_view_host');",
    "var canvas=host&&host.querySelector('canvas:not(.cv-mini)');",
    "var fb=document.getElementById('expression_feedback');",
    "return !!(canvas&&canvas.width>0&&Number(canvas.dataset.pointCount)>0&&fb&&fb.hidden&&",
    "host.innerText.includes(", g, ")&&!fb.classList.contains('is-pending'));})()"), timeout)
}

bv_frames_text <- function(page, phase = NULL, dir = "in") {
  f <- page$log$frames
  if (!is.null(phase)) f <- Filter(function(x) x$phase %in% phase, f)
  if (!is.null(dir)) f <- Filter(function(x) x$dir %in% dir, f)
  vapply(f, `[[`, "", "data")
}

## Which of `terms` occur in `text` (fixed-string search).
bv_hits <- function(text, terms) {
  text <- paste(text, collapse = "\n")
  terms[vapply(terms, function(t) grepl(t, text, fixed = TRUE), logical(1))]
}

bv_close <- function(page) try(page$b$close(), silent = TRUE)
