# Helpers for scripted browser captures of a running CerebroNexus app.
# Every capture writes <name>.png (lossless, native Chromium screenshot) and
# <name>.json (viewport, page text, plot canvas sizes and every visible text
# box with its font size), so each crop can be checked against the figure rules.

suppressPackageStartupMessages(library(chromote))

capture_session <- function(url, width, height, dpr = 3) {
  b <- ChromoteSession$new(width = width, height = height)
  b$Emulation$setDeviceMetricsOverride(
    width = width, height = height, deviceScaleFactor = dpr, mobile = FALSE
  )
  b$Page$navigate(url)
  b
}

js_quote <- function(x) as.character(jsonlite::toJSON(x, auto_unbox = TRUE))

js <- function(b, code) {
  z <- b$Runtime$evaluate(code, returnByValue = TRUE, awaitPromise = TRUE)
  if (!is.null(z$exceptionDetails)) {
    stop("JavaScript failed: ", z$exceptionDetails$text, "\n", code, call. = FALSE)
  }
  z$result$value
}

# Poll a JavaScript condition until it is true; fail loudly on timeout so a
# capture never silently records a half-loaded page.
wait_for <- function(b, condition, timeout = 300, what = condition) {
  start <- Sys.time()
  repeat {
    if (isTRUE(js(b, sprintf("Boolean(%s)", condition)))) return(invisible(TRUE))
    if (difftime(Sys.time(), start, units = "secs") > timeout) {
      stop("Timed out waiting for: ", what, call. = FALSE)
    }
    Sys.sleep(1)
  }
}

# Wait until Shiny has been idle (no busy class, no visible recalculating
# outputs except those in `ignore`) for `quiet` seconds.
wait_idle <- function(b, quiet = 4, timeout = 300, ignore = character()) {
  start <- Sys.time()
  idle_since <- NULL
  repeat {
    busy <- js(b, paste0(
      "document.documentElement.classList.contains('shiny-busy') || ",
      sprintf(
        "Array.from(document.querySelectorAll('.recalculating')).some(e => e.offsetParent !== null && %s.indexOf(e.id) < 0)",
        js_quote(as.list(ignore))
      )
    ))
    if (isTRUE(busy)) {
      idle_since <- NULL
    } else if (is.null(idle_since)) {
      idle_since <- Sys.time()
    } else if (difftime(Sys.time(), idle_since, units = "secs") >= quiet) {
      return(invisible(TRUE))
    }
    if (difftime(Sys.time(), start, units = "secs") > timeout) {
      stop("Timed out waiting for the app to become idle.", call. = FALSE)
    }
    Sys.sleep(0.5)
  }
}

set_input <- function(b, id, value) {
  js(b, sprintf(
    "(function(){var e=document.getElementById(%s); if(!e) throw new Error('no input '+%s);
      if(e.selectize){e.selectize.setValue(%s);} else {e.value=%s; e.dispatchEvent(new Event('change',{bubbles:true}));}})()",
    js_quote(id), js_quote(id), js_quote(value), js_quote(value)
  ))
  invisible(TRUE)
}

set_checkbox <- function(b, id, value) {
  js(b, sprintf(
    "(function(){var e=document.getElementById(%s); if(!e) throw new Error('no checkbox '+%s);
      if(e.checked!==%s){e.click();}})()",
    js_quote(id), js_quote(id), if (value) "true" else "false"
  ))
  invisible(TRUE)
}

show_tab <- function(b, value) {
  js(b, sprintf("void $(%s).tab('show')", js_quote(sprintf('a[data-value="%s"]', value))))
  invisible(TRUE)
}

click <- function(b, selector) {
  js(b, sprintf(
    "(function(){var e=document.querySelector(%s); if(!e) throw new Error('nothing matches '+%s); e.click();})()",
    js_quote(selector), js_quote(selector)
  ))
  invisible(TRUE)
}

upload_file <- function(b, selector, path) {
  doc <- b$DOM$getDocument()
  node <- b$DOM$querySelector(nodeId = doc$root$nodeId, selector = selector)$nodeId
  if (!node) stop("No file input matches ", selector, call. = FALSE)
  b$DOM$setFileInputFiles(files = list(normalizePath(path, mustWork = TRUE)), nodeId = node)
  invisible(TRUE)
}

# Every visible text node with its box (CSS px) and computed font size, so the
# figure script can find the smallest text inside any crop it uses.
text_boxes <- function(b) {
  js(b, paste0(
    "(function(){var w=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT),n,out=[];",
    "while((n=w.nextNode())){ if(!n.textContent.trim()) continue; var p=n.parentElement;",
    "var s=getComputedStyle(p); if(s.visibility==='hidden'||s.display==='none'||+s.opacity===0) continue;",
    "if(p.checkVisibility&&!p.checkVisibility({checkOpacity:true,checkVisibilityCSS:true})) continue;",
    "var g=document.createRange(); g.selectNodeContents(n); var q=g.getBoundingClientRect();",
    "if(q.width<1||q.height<1||q.bottom<0||q.right<0||q.top>innerHeight||q.left>innerWidth) continue;",
    "out.push({x:q.left,y:q.top,w:q.width,h:q.height,px:parseFloat(s.fontSize),text:n.textContent.trim().slice(0,60)}); }",
    "return out;})()"
  ))
}

# Save the screenshot and its record. Positions are relative to the viewport
# as captured.
# `scroll_to` names an element to scroll into view (bottom-aligned) when it
# does not fit below the page controls; otherwise the page is at the top.
capture <- function(b, name, out_dir, scroll_to = NULL) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  # No focus ring or scroll offset from the scripted steps.
  js(b, "document.activeElement && document.activeElement.blur(); window.scrollTo(0,0)")
  if (!is.null(scroll_to)) {
    js(b, sprintf("document.querySelector(%s).scrollIntoView({block:'end'}); window.scrollBy(0, 12)", js_quote(scroll_to)))
  }
  Sys.sleep(1)
  png <- b$Page$captureScreenshot(format = "png", captureBeyondViewport = FALSE)$data
  file <- file.path(out_dir, paste0(name, ".png"))
  writeBin(jsonlite::base64_dec(png), file)
  viewport <- js(b, "({width:innerWidth,height:innerHeight,dpr:devicePixelRatio})")
  record <- list(
    name = name,
    file = basename(file),
    sha256 = digest::digest(file = file, algo = "sha256"),
    viewport = viewport,
    text = text_boxes(b),
    # Plot surfaces with their CSS-pixel boxes; the figure script crops to them.
    surfaces = js(b, paste0(
      "Array.from(document.querySelectorAll('canvas,img,svg')).map(e=>[e,e.getBoundingClientRect()])",
      ".filter(p=>p[1].width>=80&&p[1].height>=80&&p[1].bottom>0&&p[1].top<innerHeight)",
      ".map(p=>({tag:p[0].tagName.toLowerCase(),id:p[0].id,cls:String(p[0].className.baseVal||p[0].className||'').slice(0,60),",
      "x:p[1].left,y:p[1].top,w:p[1].width,h:p[1].height,pixel_width:p[0].width||null}))"
    )),
    page_text = js(b, "document.body.innerText")
  )
  jsonlite::write_json(record, file.path(out_dir, paste0(name, ".json")),
    auto_unbox = TRUE, pretty = TRUE, null = "null"
  )
  message("Captured ", name)
  invisible(record)
}
