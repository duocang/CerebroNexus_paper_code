## Experiment D: spatial image transform correctness, Builder -> Viewer.
##
## Synthetic part. A 600 x 400 px background with five saturated landmark
## discs at known pixels, and a Seurat object whose cells sit where the
## Builder's alignment preview (inst/builder/www/builder-spatial-canvas.js,
## drawImage()) puts those landmarks under a given transform T:
##
##   data(u, v) = C + R(rotation) . ( fx * (u/W - 1/2) * w * scale,
##                                   -fy * (v/H - 1/2) * h * scale )
##   C = centre of the base bounds + (dx, dy);  w, h = base-bound extents;
##   fx, fy = -1 when flipped; R counter-clockwise in data space (y up);
##   flips act in the image frame before the rotation.
##
## So an author who aligned the picture in the Builder with T saw every disc
## under its cells. The object is published with the alignment record T
## (builder_alignment_record(), as the Spatial page saves it), the generated
## Viewer is opened in headless Chrome and the spatial canvas is captured on
## two pages (Linked views and Spatial). On the capture, disc centroids
## (pixels near each pure disc colour, largest component, holes filled) are
## compared with the centroid of that landmark's points (pixels near the
## group colour from the Viewer legend). The residual is reported in source
## image pixels. Four frame cells at the transformed image corners keep the
## whole picture in view and give the screen scale.
##
## Visium crop part (the Builder's Spatial alignment example). See the block "Visium crop"
## below: one CRB + Viewer App per alignment setting, measured on five discs painted on a copy of
## visium_breast_cancer_he.jpg. (The arrow fixture of the
## runs up to 33150d9d7 is no longer shipped by the package.)
##
## Multi-section part. inst/builder/fixtures/complete_viewer (spatial sections
## section_a_1_fov_1, section_a_2_fov_1, section_b_1_fov_1): per section a landmark picture is
## drawn from the section's real cell coordinates under a different T, all
## three are published in one CRB, and each section is measured in Linked
## views after switching to it.
##
## Usage: Rscript scripts/D_spatial_transforms.R [synthetic|crop|multisection ...]
## (D_OUT=<file.csv> writes to another results file, D_CAPTURES=<dir> and
## D_DATA=<dir> put captures and builds elsewhere; D_TRANSFORMS / D_CROP
## restrict the synthetic / crop settings; D_POINT_SIZE sets the Viewer point
## size, 5 by default.)
## Defaults carry the suffix of the installed commit: results/D_spatial_transforms_<9 chars>.csv,
## captures in results/D_captures_<9 chars>/.

source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))), "common.R"))
source(file.path(bv_root, "scripts", "viewer.R"))
suppressPackageStartupMessages({
  library(SeuratObject)
  library(EBImage)
})

root <- file.path(bv_data, Sys.getenv("D_DATA", paste0("D_", bv_suffix)))
captures <- file.path(bv_root, "results", Sys.getenv("D_CAPTURES", paste0("D_captures_", bv_suffix)))
dir.create(root, recursive = TRUE, showWarnings = FALSE)
dir.create(captures, recursive = TRUE, showWarnings = FALSE)
rt <- bv_load_runtime()
set.seed(11)
point_size <- as.numeric(Sys.getenv("D_POINT_SIZE", "5"))

disc_cols <- c("#ff0000", "#00c000", "#0000ff", "#ff00ff", "#00e0e0")

builder_q <- function(u, v, tr, b, W, H) {
  w <- b$xmax - b$xmin
  h <- b$ymax - b$ymin
  fx <- if (isTRUE(tr$flip_x)) -1 else 1
  fy <- if (isTRUE(tr$flip_y)) -1 else 1
  s <- tr$scale %||% 1
  lx <- fx * (u / W - 0.5) * w * s
  ly <- -fy * (v / H - 0.5) * h * s
  a <- (tr$rotation %||% 0) * pi / 180
  cbind(
    x = (b$xmin + b$xmax) / 2 + round(tr$dx %||% 0) + cos(a) * lx - sin(a) * ly,
    y = (b$ymin + b$ymax) / 2 + round(tr$dy %||% 0) + sin(a) * lx + cos(a) * ly
  )
}

## Where the Viewer puts image pixel (u, v), transcribed from drawImage() in
## inst/viewer/www/cell_views.js: the image's bounds are rotated about the DATA
## ORIGIN, the offset is added to the rotated centre, scale and flips act in
## screen axes after the rotation.
viewer_q <- function(u, v, tr, b, W, H) {
  a <- (tr$rotation %||% 0) * pi / 180
  rot <- function(x, y) cbind(cos(a) * x - sin(a) * y, sin(a) * x + cos(a) * y)
  p <- rot(b$xmin + u / W * (b$xmax - b$xmin), b$ymax - v / H * (b$ymax - b$ymin))
  cr <- rot((b$xmin + b$xmax) / 2, (b$ymin + b$ymax) / 2)
  s <- tr$scale %||% 1
  d <- c(s * if (isTRUE(tr$flip_x)) -1 else 1, s * if (isTRUE(tr$flip_y)) -1 else 1)
  cbind(
    x = cr[1] + round(tr$dx %||% 0) + d[1] * (p[, 1] - cr[1]),
    y = cr[2] + round(tr$dy %||% 0) + d[2] * (p[, 2] - cr[2])
  )
}

draw_discs <- function(path, W, H, u, v, r = 16, bg = 0.92) {
  img <- array(bg, c(H, W, 3))
  yy <- matrix(rep(seq_len(H) - 0.5, W), H)
  xx <- matrix(rep(seq_len(W) - 0.5, each = H), H)
  for (k in seq_along(u)) {
    m <- (xx - u[k])^2 + (yy - v[k])^2 <= r^2
    rgb <- grDevices::col2rgb(disc_cols[k]) / 255
    for (ch in 1:3) {
      a <- img[, , ch]
      a[m] <- rgb[ch]
      img[, , ch] <- a
    }
  }
  png::writePNG(img, path)
  path
}

image_record <- function(path, section, bounds, tr) {
  ins <- rt$builder_read_image(path)
  rec <- rt$builder_alignment_record(
    source = list(name = basename(path), type = ins$mime, size = ins$bytes),
    base_bounds = bounds,
    parameters = c(tr[intersect(names(tr), c("dx", "dy", "scale", "rotation", "flip_x", "flip_y"))],
                   list(image_opacity = 1, point_opacity = 1, point_size = point_size)),
    section = list(id = section, kind = "spatial"),
    source_path = ins$source_path
  )
  rec$source_content_md5 <- ins$source_content_md5
  rec
}

## ---- image analysis -----------------------------------------------------------------
read_capture <- function(path) {
  a <- png::readPNG(path)
  if (dim(a)[3] == 4) a <- a[, , 1:3]
  a
}
colour_mask <- function(a, hex, tol) {
  rgb <- grDevices::col2rgb(hex)[, 1] / 255
  d <- sqrt((a[, , 1] - rgb[1])^2 + (a[, , 2] - rgb[2])^2 + (a[, , 3] - rgb[3])^2)
  d < tol
}
## centroid (x right, y down, in capture px) of the largest component
blob <- function(mask, fill = TRUE) {
  if (!any(mask)) return(c(x = NA, y = NA, n = 0))
  lab <- bwlabel(mask)
  if (fill) lab <- fillHull(lab)
  sizes <- table(lab[lab > 0])
  k <- as.integer(names(sizes)[which.max(sizes)])
  idx <- which(lab == k, arr.ind = TRUE)
  c(x = mean(idx[, 2]) - 0.5, y = mean(idx[, 1]) - 0.5, n = nrow(idx))
}
## centroid of the largest connected group of pixels of a colour (the points of one group). Stray
## pixels of that colour elsewhere in the capture (the pane title is drawn with colour fringes in
## recent Chrome builds) must not pull the centroid, so the largest component is taken, not every pixel.
all_px <- function(mask) {
  if (!any(mask)) return(c(x = NA, y = NA, n = 0))
  blob(mask, fill = FALSE)
}

## The pane's tool bar (zoom, selection, download buttons) and its mini map are drawn over the plot in
## recent Viewers; their icons have colours of the default palette, so they are hidden before a capture.
## Only controls are hidden; the plotted points and the image are untouched.
hide_pane_controls <- function(d) {
  d$run_js(paste0("document.querySelectorAll('.cv-panebar, .cv-mini, .cv-focus-btn, .cv-moran-badge')",
                  ".forEach(function(e){e.style.visibility='hidden';});"))
  Sys.sleep(0.5)
}

## ---- Viewer session ----------------------------------------------------------------------
viewer_open <- function(app_dir, label) {
  lib <- bv_hermetic_library(file.path(bv_data, "B"))
  port <- httpuv::randomPort(host = "127.0.0.1")
  proc <- callr::r_bg(
    function(a, p) shiny::runApp(a, port = p, host = "127.0.0.1", launch.browser = FALSE,
                                 quiet = TRUE, test.mode = TRUE),
    list(app_dir, port), libpath = lib, supervise = TRUE,
    stderr = file.path(root, paste0(label, ".viewer.err"))
  )
  url <- paste0("http://127.0.0.1:", port)
  for (i in 1:240) {
    if (!is.na(tryCatch(httr::status_code(httr::GET(url)), error = function(e) NA))) break
    Sys.sleep(0.5)
  }
  ## Chrome sometimes misses its 10 s start-up window on a busy machine: retry the start, not the measurement.
  d <- NULL
  for (attempt in 1:3) {
    d <- tryCatch(shinytest2::AppDriver$new(url, name = label, load_timeout = 120000, width = 1400, height = 1000),
                  error = function(e) if (attempt == 3) stop(e) else NULL)
    if (!is.null(d)) break
  }
  d$wait_for_idle(timeout = 60000)
  list(d = d, proc = proc)
}
viewer_close <- function(v) {
  try(v$d$stop(), silent = TRUE)
  try(v$proc$kill(), silent = TRUE)
}
legend_colours <- function(d) {
  jsonlite::fromJSON(d$get_js(paste0(
    "JSON.stringify(Array.from(document.querySelectorAll('#cv-legend .cv-lg')).map(function(e){",
    "return {name:e.childNodes[1].textContent.trim(), col:e.querySelector('.cv-dot').style.background};}))")))
}
rgb_to_hex <- function(x) {
  if (grepl("^#", x)) return(x)
  n <- as.integer(strsplit(gsub("[^0-9,]", "", x), ",")[[1]])
  grDevices::rgb(n[1], n[2], n[3], maxColorValue = 255)
}
capture_linked <- function(d, file, section = NULL) {
  unlink(file)
  d$click(selector = "a[href='#shiny-tab-coordinated_views']")
  if (!is.null(section)) {
    d$run_js(sprintf(paste0(
      "(function(){var s=document.getElementById('cv-pick-spatial');var want=%s;",
      "Array.from(s.options).forEach(function(o){o.selected=(o.value===want);});",
      "s.dispatchEvent(new Event('change',{bubbles:true}));})()"),
      jsonlite::toJSON(section, auto_unbox = TRUE)))
  }
  d$wait_for_js(paste0(
    "(function(){var p=document.querySelector('.cv-pane.cv-active-spatial');",
    "var c=p&&p.querySelector('canvas.cv-layer-overlay');",
    "var t=p&&p.querySelector('.cv-ptitle');",
    "return !!(c&&c.width>0&&(", if (is.null(section)) "true" else
      paste0("t&&t.textContent.indexOf(", jsonlite::toJSON(section, auto_unbox = TRUE), ")===0"), "));})()"),
    timeout = 60000)
  Sys.sleep(4)
  hide_pane_controls(d)
  d$get_screenshot(file, selector = ".cv-pane.cv-active-spatial")
  file
}
capture_spatial <- function(d, file) {
  unlink(file)
  d$click(selector = "a[href='#shiny-tab-spatial']")
  d$wait_for_js("(function(){var c=document.querySelector('#shiny-tab-spatial canvas.cv-layer-overlay');return !!(c&&c.width>0);})()",
                timeout = 60000)
  Sys.sleep(4)
  hide_pane_controls(d)
  d$get_screenshot(file, selector = "#shiny-tab-spatial .cv-pane")
  file
}

## Residuals of discs vs. points on one capture. `expected` gives, per
## landmark, the group name whose points should sit on disc k.
measure <- function(file, legend, groups, frame_group = "frame", disc_tol = 0.25, point_tol = 0.12) {
  a <- read_capture(file)
  pal <- stats::setNames(vapply(legend$col, rgb_to_hex, ""), legend$name)
  out <- lapply(seq_along(groups), function(k) {
    disc <- blob(colour_mask(a, disc_cols[k], disc_tol))
    pt <- all_px(colour_mask(a, pal[[groups[k]]], point_tol))
    c(disc, pt)
  })
  m <- do.call(rbind, out)
  colnames(m) <- c("disc_x", "disc_y", "disc_n", "pt_x", "pt_y", "pt_n")
  m
}

## ---- synthetic transforms --------------------------------------------------------------
W <- 600
H <- 400
lm <- data.frame(u = c(150, 450, 300, 140, 470), v = c(110, 95, 200, 300, 290))
base_bounds <- list(xmin = 1000, xmax = 1600, ymin = 2000, ymax = 2400) # 1 data unit per px
transforms <- list(
  identity = list(),
  translate = list(dx = 120, dy = -80),
  scale_1.5 = list(scale = 1.5),
  scale_0.6 = list(scale = 0.6),
  flip_x = list(flip_x = TRUE),
  flip_y = list(flip_y = TRUE),
  rotate_90 = list(rotation = 90),
  rotate_180 = list(rotation = 180),
  rotate_270 = list(rotation = 270),
  rotate_30 = list(rotation = 30),
  rotate_90_flip_x = list(rotation = 90, flip_x = TRUE),
  combined = list(dx = 60, dy = 40, scale = 1.25, rotation = 45, flip_y = TRUE),
  ## controls: image bounds centred on the data origin, where rotating about
  ## the origin and about the image centre coincide
  origin_rotate_90 = list(rotation = 90, origin = TRUE),
  origin_rotate_30 = list(rotation = 30, origin = TRUE),
  origin_rotate_90_flip_x = list(rotation = 90, flip_x = TRUE, origin = TRUE),
  origin_combined = list(dx = 60, dy = 40, scale = 1.25, rotation = 45, flip_y = TRUE, origin = TRUE)
)
origin_bounds <- list(xmin = -300, xmax = 300, ymin = -200, ymax = 200)
bounds_for <- function(tr) if (isTRUE(tr$origin)) origin_bounds else base_bounds

synthetic_object <- function(tr, dir) {
  xy <- builder_q(lm$u, lm$v, tr, bounds_for(tr), W, H)
  corners <- builder_q(c(0, W, 0, W), c(0, 0, H, H), tr, bounds_for(tr), W, H)
  rep_k <- rep(seq_len(nrow(lm)), each = 3)
  pts <- rbind(xy[rep_k, ], corners)
  grp <- c(paste0("L", rep_k), rep("frame", 4))
  cells <- c(paste0("L", rep_k, "_", rep(1:3, nrow(lm))), paste0("frame_", 1:4))
  rownames(pts) <- cells
  counts <- Matrix::Matrix(matrix(stats::rpois(10 * length(cells), 5), 10,
                                  dimnames = list(paste0("G", 1:10), cells)), sparse = TRUE)
  o <- CreateSeuratObject(counts, assay = "Spatial")
  o <- Seurat::NormalizeData(o, verbose = FALSE)
  o$landmark <- factor(grp, levels = c(paste0("L", seq_len(nrow(lm))), "frame"))
  o$sample <- "synthetic"
  emb <- pts / 100
  colnames(emb) <- c("UMAP_1", "UMAP_2")
  o[["umap"]] <- CreateDimReducObject(emb, key = "UMAP_", assay = "Spatial")
  o[["lm"]] <- CreateFOV(coords = data.frame(x = pts[, 1], y = pts[, 2], cell = cells),
                         type = "centroids", assay = "Spatial", key = "lm_")
  path <- file.path(dir, "lm.rds")
  saveRDS(o, path)
  list(path = path, corners = corners, xy = xy)
}

publish_case <- function(id, input, configure) {
  dir <- file.path(root, id)
  r <- bv_route(rt, id, id, input = input, work = file.path(dir, "work"),
                release = file.path(dir, "release"), configure = configure)
  r$published$app_dir
}

## Scale from data to capture pixels: use the frame cells (the four transformed
## image corners), whose capture positions follow from the landmark points by a
## least-squares similarity fit (data -> screen, y flipped).
screen_scale <- function(m, xy) {
  ok <- stats::complete.cases(m[, c("pt_x", "pt_y")])
  fit <- stats::lm(m[ok, "pt_x"] ~ xy[ok, "x"])
  unname(abs(stats::coef(fit)[2]))
}

rows <- list()
out_csv <- file.path(bv_root, "results", Sys.getenv("D_OUT", paste0("D_spatial_transforms_", bv_suffix, ".csv")))
write_rows <- function() {
  if (!length(rows)) return(invisible())
  all_cols <- unique(unlist(lapply(rows, names)))
  rr <- lapply(rows, function(r) { r[setdiff(all_cols, names(r))] <- NA; r[all_cols] })
  utils::write.csv(do.call(rbind, rr), out_csv, row.names = FALSE)
}
add_rows <- function(case, page, m, px_per_data, data_per_image_px, extra = list()) {
  res_screen <- sqrt((m[, "disc_x"] - m[, "pt_x"])^2 + (m[, "disc_y"] - m[, "pt_y"])^2)
  res_img <- res_screen / px_per_data / data_per_image_px
  rows[[length(rows) + 1L]] <<- data.frame(
    c(list(case = case, page = page,
           landmarks_found = sum(m[, "disc_n"] > 0 & m[, "pt_n"] > 0),
           max_residual_image_px = if (all(is.na(res_img))) NA else round(max(res_img, na.rm = TRUE), 2),
           mean_residual_image_px = if (all(is.na(res_img))) NA else round(mean(res_img, na.rm = TRUE), 2),
           discs_in_view = sum(m[, "disc_n"] > 50),
           residuals_image_px = paste(round(res_img, 1), collapse = ";"),
           capture_px_per_image_px = round(px_per_data * data_per_image_px, 3)),
      extra),
    stringsAsFactors = FALSE)
}

parts <- commandArgs(trailingOnly = TRUE)
if (!length(parts)) parts <- c("synthetic", "crop", "multisection")
if ("arrow" %in% parts) {
  stop("The arrow fixture is no longer shipped by the package; use \"crop\" (the Visium crop of the Builder example).",
       call. = FALSE)
}

only_tr <- Sys.getenv("D_TRANSFORMS")
if (nzchar(only_tr)) transforms <- transforms[strsplit(only_tr, ",")[[1]]]
if ("synthetic" %in% parts) {
  for (id in names(transforms)) {
    cat("\n==== synthetic ", id, " ====\n", sep = "")
    tr <- transforms[[id]]
    dir <- file.path(root, id)
    unlink(dir, recursive = TRUE)
    dir.create(dir, recursive = TRUE)
    png_path <- draw_discs(file.path(dir, "landmarks.png"), W, H, lm$u, lm$v)
    obj <- synthetic_object(tr, dir)
    rec <- image_record(png_path, "lm", bounds_for(tr), tr)
    predicted <- sqrt(rowSums((viewer_q(lm$u, lm$v, tr, bounds_for(tr), W, H) -
                               builder_q(lm$u, lm$v, tr, bounds_for(tr), W, H))^2))
    stored <- rt$builder_alignment_payload(rec)
    app <- publish_case(id, obj$path, list(images = list(lm = rec), organism = "mm",
                                           groups = "landmark"))
    v <- viewer_open(app, id)
    legend <- tryCatch({
      v$d$click(selector = "a[href='#shiny-tab-coordinated_views']")
      Sys.sleep(3)
      legend_colours(v$d)
    }, error = function(e) NULL)
    for (page in c("linked", "spatial")) {
      file <- file.path(captures, paste0("synthetic_", id, "_", page, ".png"))
      got <- bv_capture(if (page == "linked") capture_linked(v$d, file) else capture_spatial(v$d, file))
      if (!is.null(got$error) || is.null(legend)) {
        rows[[length(rows) + 1L]] <- data.frame(case = paste0("synthetic_", id), page = page,
          error = bv_one_line(got$error %||% "legend not found"), stringsAsFactors = FALSE)
        next
      }
      m <- measure(file, legend, paste0("L", seq_len(nrow(lm))))
      add_rows(paste0("synthetic_", id), page, m, screen_scale(m, obj$xy), tr$scale %||% 1,
               list(transform = bv_one_line(jsonlite::toJSON(tr, auto_unbox = TRUE)),
                    image_bounds = paste(unlist(bounds_for(tr)), collapse = ";"),
                    predicted_viewer_residual_image_px = round(max(predicted), 1),
                    stored_alignment = bv_one_line(jsonlite::toJSON(
                      stored[c("dx", "dy", "scale", "rotation", "flip_x", "flip_y")], auto_unbox = TRUE))))
    }
    viewer_close(v)
    write_rows()
    print(utils::tail(rows, 2))
  }
}

## ---- Visium crop (the Builder example), one build and App per alignment setting ------------
## The Builder's "Spatial alignment" example ships a crop of a real 10x Visium
## breast cancer section: inst/builder/fixtures/spatial_alignment/
## visium_breast_cancer.rds (405 spots, 300 genes, FOV "visium_breast") and
## visium_breast_cancer_he.jpg (560 x 440 px). The spot coordinates ARE pixel
## positions of that image (x = column, y = row), so the picture is registered
## by construction only with flip_y (data y points up in Builder and Viewer,
## image rows point down), with bounds 0..560 x 440 and no rotation, offset
## or scale. This replaces the synthetic arrow fixture (arrow_background.png,
## arrow_spatial.rds), which the package no longer ships.
##
## The H&E has no landmarks that can be located exactly, so the measured
## picture is a copy of the shipped H&E with five saturated discs painted on it
## (lossless PNG, same 560 x 440 px), centred on the pixel positions of five
## real spots: the extremes of x + y and x - y and the spot nearest the centre.
## Those five spots form groups L1..L5 (all other spots "other"). As in the
## synthetic part, the residual is the distance between a disc and the points
## of its group in the same capture, in source-image pixels; nothing is fitted.
## For the example case the Builder's own builder_example_configure_entry()
## builds the alignment record from a catalog record whose image is the painted
## copy (same pixel grid), so the preset (flip_y, bounds, opacities, point
## appearance) is the one the package ships.
##
## Per setting T the cells are moved to where the Builder preview puts their
## pixel under T (builder_q) and the image gets alignment T. Rows with `as_is`:
## the spots as they ship (cells = pixels) with identity alignment (not
## registered: the picture is upside down against the cells) and with the
## Builder example's preset (registered).
crop_settings <- list(
  identity = list(), translate = list(dx = 120, dy = -80),
  scale_1.5 = list(scale = 1.5), scale_0.6 = list(scale = 0.6),
  flip_x = list(flip_x = TRUE), flip_y = list(flip_y = TRUE),
  rotate_90 = list(rotation = 90), rotate_180 = list(rotation = 180),
  rotate_270 = list(rotation = 270), rotate_28 = list(rotation = 28),
  fixture_as_is_identity = list(as_is = TRUE),
  ## the Builder example exactly as builder_example_configure_entry() sets it
  ## up (image record, point appearance), opacities set to 1 so colours can be
  ## measured
  example_as_configured = list(as_is = TRUE, example = TRUE)
)
only_crop <- Sys.getenv("D_CROP")
if (nzchar(only_crop)) crop_settings <- crop_settings[strsplit(only_crop, ",")[[1]]]

## The shipped H&E with discs painted at pixel positions (u = column, v = row, continuous).
paint_discs <- function(he_path, u, v, out, r = 12) {
  a <- aperm(as.array(EBImage::readImage(he_path))[, , 1:3, drop = FALSE], c(2, 1, 3)) # rows = y, columns = x
  Hc <- dim(a)[1]
  Wc <- dim(a)[2]
  yy <- matrix(rep(seq_len(Hc) - 0.5, Wc), Hc)
  xx <- matrix(rep(seq_len(Wc) - 0.5, each = Hc), Hc)
  for (k in seq_along(u)) {
    m <- (xx - u[k])^2 + (yy - v[k])^2 <= r^2
    rgb <- grDevices::col2rgb(disc_cols[k]) / 255
    for (ch in 1:3) {
      p <- a[, , ch]
      p[m] <- rgb[ch]
      a[, , ch] <- p
    }
  }
  png::writePNG(a, out)
  out
}

if ("crop" %in% parts) {
  fx <- system.file("builder", "fixtures", "spatial_alignment", package = "CerebroNexus")
  he <- file.path(fx, "visium_breast_cancer_he.jpg")
  fixture <- readRDS(file.path(fx, "visium_breast_cancer.rds"))
  section <- SeuratObject::Images(fixture)[1L]
  tc <- GetTissueCoordinates(fixture[[section]])
  pix <- matrix(c(tc$x, tc$y), ncol = 2, dimnames = list(tc$cell, c("u", "v")))
  dims <- dim(EBImage::readImage(he))
  Wc <- dims[1L]
  Hc <- dims[2L]
  pick <- rownames(pix)[unique(c(which.min(pix[, 1] + pix[, 2]), which.max(pix[, 1] + pix[, 2]),
                                 which.min(pix[, 1] - pix[, 2]), which.max(pix[, 1] - pix[, 2]),
                                 which.min((pix[, 1] - mean(range(pix[, 1])))^2 + (pix[, 2] - mean(range(pix[, 2])))^2)))]
  stopifnot(length(pick) == 5L)
  fixture$landmark <- factor(ifelse(colnames(fixture) %in% pick, paste0("L", match(colnames(fixture), pick)), "other"),
                             c(paste0("L", 1:5), "other"))
  crop_dir <- file.path(root, "crop_fixture")
  dir.create(crop_dir, recursive = TRUE, showWarnings = FALSE)
  bg <- paint_discs(he, pix[pick, 1], pix[pick, 2], file.path(crop_dir, "visium_crop_painted.png"))
  B <- list(xmin = 0, xmax = Wc, ymin = 0, ymax = Hc)
  ## the same pixel grid, so the Builder's own example record can be built on the painted copy
  catalog <- rt$builder_example_catalog()$spatial_alignment
  painted <- catalog
  painted$serialized_path <- file.path(crop_dir, basename(catalog$serialized_path))
  painted$histology_images$visium_breast_cancer_he$path <- basename(bg)
  crop_point_size <- as.numeric(Sys.getenv("D_POINT_SIZE", "12"))
  for (id in names(crop_settings)) {
    cat("\n==== visium crop ", id, " ====\n", sep = "")
    tr <- crop_settings[[id]]
    dir <- file.path(root, paste0("visium_crop_", id))
    unlink(dir, recursive = TRUE)
    dir.create(dir, recursive = TRUE)
    o <- fixture
    if (isTRUE(tr$as_is)) {
      data_xy <- pix
    } else {
      data_xy <- builder_q(pix[, 1], pix[, 2], tr, B, Wc, Hc)
      rownames(data_xy) <- rownames(pix)
      o@images <- list()
      o[[section]] <- CreateFOV(coords = data.frame(x = data_xy[, 1], y = data_xy[, 2], cell = rownames(pix)),
                                type = "centroids", assay = "Spatial", key = "vb_")
    }
    input <- file.path(dir, "visium_crop.rds")
    saveRDS(o, input)
    if (isTRUE(tr$example)) {
      configured <- rt$builder_example_configure_entry(
        list(id = "spatial_alignment", settings = list()), painted, fixture)
      images <- configured$settings$images
      rec <- images[[section]][[1L]]
      rec[c("image_opacity", "point_opacity", "point_size")] <- list(1, 1, crop_point_size)
      images[[section]][[1L]] <- rec
      extra_configure <- list(images = images)
      if (!is.null(configured$settings$spatial_point_appearance)) {
        extra_configure$spatial_point_appearance <- stats::setNames(
          list(list(point_opacity = 1, point_size = crop_point_size)), section)
      }
      extra_configure$spatial_coordinate_transforms <- configured$settings$spatial_coordinate_transforms
      expected_tr <- rec[c("dx", "dy", "scale", "rotation", "flip_x", "flip_y")]
      eb <- rec$base_bounds
      preset <- bv_one_line(jsonlite::toJSON(expected_tr, auto_unbox = TRUE))
    } else {
      old_point_size <- point_size
      point_size <- crop_point_size # image_record() reads the global
      rec <- image_record(bg, section, B, tr)
      point_size <- old_point_size
      extra_configure <- list(images = stats::setNames(list(rec), section))
      expected_tr <- tr
      eb <- B
      preset <- NA_character_
    }
    ## where the Builder preview shows the five landmark pixels in data space; for the as-is rows the
    ## points stay at the pixel positions, so the discs (drawn by the alignment) are what moves
    lm_xy <- data_xy[pick, , drop = FALSE]
    colnames(lm_xy) <- c("x", "y")
    predicted <- sqrt(rowSums((viewer_q(pix[pick, 1], pix[pick, 2], expected_tr, eb, Wc, Hc) -
                               builder_q(pix[pick, 1], pix[pick, 2], expected_tr, eb, Wc, Hc))^2))
    app <- publish_case(paste0("visium_crop_", id), input,
                        c(list(organism = "hg", groups = "landmark"), Filter(Negate(is.null), extra_configure)))
    v <- viewer_open(app, paste0("visium_crop_", id))
    legend <- tryCatch({
      v$d$click(selector = "a[href='#shiny-tab-coordinated_views']")
      Sys.sleep(3)
      legend_colours(v$d)
    }, error = function(e) NULL)
    for (page in c("linked", "spatial")) {
      file <- file.path(captures, paste0("visium_crop_", id, "_", page, ".png"))
      got <- bv_capture(if (page == "linked") capture_linked(v$d, file) else capture_spatial(v$d, file))
      if (!is.null(got$error) || is.null(legend)) {
        rows[[length(rows) + 1L]] <- data.frame(case = paste0("visium_crop_", id), page = page,
          error = bv_one_line(got$error %||% "legend not found"), stringsAsFactors = FALSE)
        next
      }
      ## flat dots in exactly the legend colour; the H&E under them has purple tissue that a looser match takes
      m <- measure(file, legend, paste0("L", 1:5), point_tol = 0.03)
      ## data units per source-image pixel: base-bound width over image width, times scale
      add_rows(paste0("visium_crop_", id), page, m, screen_scale(m, lm_xy), (eb$xmax - eb$xmin) / Wc * (expected_tr$scale %||% 1),
               list(transform = bv_one_line(jsonlite::toJSON(tr, auto_unbox = TRUE)),
                    example_alignment = preset,
                    predicted_viewer_residual_image_px = round(max(predicted), 1)))
    }
    viewer_close(v)
    write_rows()
    print(utils::tail(rows, 2))
  }
}

## ---- multi-section fixture -------------------------------------------------------------------
run_multisection <- function() {
  cat("\n==== complete_viewer multi-section ====\n")
  fx <- system.file("builder", "fixtures", "complete_viewer", package = "CerebroNexus")
  dir <- file.path(root, "multisection")
  unlink(dir, recursive = TRUE)
  dir.create(dir, recursive = TRUE)
  o <- readRDS(file.path(fx, "complete_viewer_data.rds"))
  sections <- c("section_a_1_fov_1", "section_a_2_fov_1", "section_b_1_fov_1")
  stopifnot(all(sections %in% Images(o)))
  ## one transform per section: translation+flip, scale+flip, and a rotation
  section_tr <- list(section_a_1_fov_1 = list(dx = 15, flip_y = TRUE),
                     section_a_2_fov_1 = list(flip_x = TRUE, scale = 1.2),
                     section_b_1_fov_1 = list(rotation = 90, dy = -10))
  o$landmark <- "other"
  images <- list()
  truth <- list()
  for (s in sections) {
    tc <- GetTissueCoordinates(o[[s]])
    rn <- if ("cell" %in% names(tc)) tc$cell else rownames(tc)
    xy <- matrix(c(tc$x, tc$y), ncol = 2, dimnames = list(rn, c("x", "y")))
    b <- list(xmin = min(xy[, 1]), xmax = max(xy[, 1]), ymin = min(xy[, 2]), ymax = max(xy[, 2]))
    pad <- 0.15 * max(b$xmax - b$xmin, b$ymax - b$ymin)
    b <- list(xmin = b$xmin - pad, xmax = b$xmax + pad, ymin = b$ymin - pad, ymax = b$ymax + pad)
    Ws <- 600
    Hs <- round(600 * (b$ymax - b$ymin) / (b$xmax - b$xmin))
    ## five cells spread over the section become landmarks; the disc for each
    ## is drawn where the Builder preview would show that data point under T
    pick <- rn[unique(c(which.min(xy[, 1] + xy[, 2]), which.max(xy[, 1] + xy[, 2]),
                        which.min(xy[, 1] - xy[, 2]), which.max(xy[, 1] - xy[, 2]),
                        which.min((xy[, 1] - mean(xy[, 1]))^2 + (xy[, 2] - mean(xy[, 2]))^2)))]
    tr <- section_tr[[s]]
    grid <- expand.grid(u = seq(0, Ws, length.out = 241), v = seq(0, Hs, length.out = 241))
    q <- builder_q(grid$u, grid$v, tr, b, Ws, Hs)
    uv <- t(vapply(pick, function(cell) {
      j <- which.min((q[, 1] - xy[cell, 1])^2 + (q[, 2] - xy[cell, 2])^2)
      c(grid$u[j], grid$v[j])
    }, numeric(2)))
    ## refine the inverse map by Newton steps on the analytic forward map
    for (k in seq_len(nrow(uv))) {
      for (it in 1:20) {
        fq <- function(u, v) as.numeric(builder_q(u, v, tr, b, Ws, Hs))
        f <- fq(uv[k, 1], uv[k, 2]) - xy[pick[k], ]
        J <- cbind((fq(uv[k, 1] + 1e-3, uv[k, 2]) - fq(uv[k, 1], uv[k, 2])) / 1e-3,
                   (fq(uv[k, 1], uv[k, 2] + 1e-3) - fq(uv[k, 1], uv[k, 2])) / 1e-3)
        uv[k, ] <- uv[k, ] - solve(J, as.numeric(f))
      }
    }
    png_path <- draw_discs(file.path(dir, paste0(s, "_landmarks.png")), Ws, Hs, uv[, 1], uv[, 2], r = 9)
    images[[s]] <- image_record(png_path, s, b, tr)
    ## shared levels L1..L5 (+ other) keep every group colour distinct
    o$landmark[pick] <- paste0("L", seq_along(pick))
    truth[[s]] <- list(pick = pick, tr = tr, uv = uv, b = b, W = Ws, H = Hs,
                       data_per_image_px = (b$xmax - b$xmin) / Ws * (tr$scale %||% 1))
  }
  o$landmark <- factor(o$landmark)
  input <- file.path(dir, "complete_viewer_landmarks.rds")
  saveRDS(o, input)
  app <- publish_case("multisection", input, list(images = images, groups = "landmark"))
  v <- viewer_open(app, "multisection")
  v$d$click(selector = "a[href='#shiny-tab-coordinated_views']")
  Sys.sleep(3)
  legend <- legend_colours(v$d)
  ## Linked views keeps every section in one multi-select; the Spatial page
  ## shows one section per sample, so each section is measured there.
  v$d$click(selector = "a[href='#shiny-tab-spatial']")
  Sys.sleep(3)
  for (s in sections) {
    sample <- unique(as.character(o$sample_id[Cells(o[[s]])]))[1L]
    v$d$set_inputs(spatial_projection_sample = sample, wait_ = FALSE)
    v$d$wait_for_js(sprintf(
      "document.getElementById('spatial_projection_to_display').value===%s",
      jsonlite::toJSON(s, auto_unbox = TRUE)), timeout = 60000)
    Sys.sleep(5)
    file <- file.path(captures, paste0("multisection_", s, "_spatial.png"))
    unlink(file)
    hide_pane_controls(v$d)
    v$d$get_screenshot(file, selector = "#shiny-tab-spatial .cv-pane")
    pk <- truth[[s]]
    m <- measure(file, legend, paste0("L", seq_along(pk$pick)))
    xy <- GetTissueCoordinates(o[[s]])
    rn <- if ("cell" %in% names(xy)) xy$cell else rownames(xy)
    sel <- matrix(c(xy$x, xy$y), ncol = 2, dimnames = list(rn, c("x", "y")))[pk$pick, , drop = FALSE]
    pred <- sqrt(rowSums((viewer_q(pk$uv[, 1], pk$uv[, 2], pk$tr, pk$b, pk$W, pk$H) - sel)^2)) / pk$data_per_image_px
    add_rows(paste0("multisection_", s), "spatial", m, screen_scale(m, sel), pk$data_per_image_px,
             list(transform = bv_one_line(jsonlite::toJSON(pk$tr, auto_unbox = TRUE)),
                  sample = sample,
                  predicted_viewer_residual_image_px = round(max(pred), 1)))
    write_rows()
    print(utils::tail(rows, 1))
  }
  viewer_close(v)
}

if ("multisection" %in% parts) {
  ms <- bv_capture(run_multisection())
  if (!is.null(ms$error)) {
    rows[[length(rows) + 1L]] <- data.frame(case = "multisection", page = "linked",
      error = bv_one_line(ms$error), stringsAsFactors = FALSE)
  }
}
write_rows()
out <- read.csv(out_csv)
print(out[, intersect(c("case", "page", "max_residual_image_px", "error"), names(out))])
