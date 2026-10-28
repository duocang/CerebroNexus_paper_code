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
## Arrow part (Builder example data). See the block "arrow fixture" below:
## one CRB + Viewer App per alignment setting, measured on the corner squares
## and the orange arrow outline of arrow_background.png.
##
## Multi-section part. inst/builder/fixtures/complete_viewer (spatial sections
## section_a_1_fov_1, section_a_2_fov_1, section_b_1_fov_1): per section a landmark picture is
## drawn from the section's real cell coordinates under a different T, all
## three are published in one CRB, and each section is measured in Linked
## views after switching to it.
##
## Usage: Rscript scripts/D_spatial_transforms.R [synthetic|arrow|multisection ...]
## (D_OUT=<file.csv> writes to another results file, D_CAPTURES=<dir> and
## D_DATA=<dir> put captures and builds elsewhere; D_TRANSFORMS / D_ARROW
## restrict the synthetic / arrow settings; D_POINT_SIZE sets the Viewer point
## size, 5 by default.)
## Writes results/D_spatial_transforms.csv, captures in results/D_captures/.

source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))), "common.R"))
source(file.path(bv_root, "scripts", "viewer.R"))
suppressPackageStartupMessages({
  library(SeuratObject)
  library(EBImage)
})

root <- file.path(bv_data, Sys.getenv("D_DATA", "D"))
captures <- file.path(bv_root, "results", Sys.getenv("D_CAPTURES", "D_captures"))
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
## centroid of all pixels of a colour (points of one group)
all_px <- function(mask) {
  if (!any(mask)) return(c(x = NA, y = NA, n = 0))
  idx <- which(mask, arr.ind = TRUE)
  c(x = mean(idx[, 2]) - 0.5, y = mean(idx[, 1]) - 0.5, n = nrow(idx))
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
  d <- shinytest2::AppDriver$new(url, name = label, load_timeout = 120000, width = 1400, height = 1000)
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
  d$get_screenshot(file, selector = ".cv-pane.cv-active-spatial")
  file
}
capture_spatial <- function(d, file) {
  unlink(file)
  d$click(selector = "a[href='#shiny-tab-spatial']")
  d$wait_for_js("(function(){var c=document.querySelector('#shiny-tab-spatial canvas.cv-layer-overlay');return !!(c&&c.width>0);})()",
                timeout = 60000)
  Sys.sleep(4)
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
out_csv <- file.path(bv_root, "results", Sys.getenv("D_OUT", "D_spatial_transforms.csv"))
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
if (!length(parts)) parts <- c("synthetic", "arrow", "multisection")

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

## ---- arrow fixture, one build and App per alignment setting -------------------------------
## arrow_background.png is 800 x 500 px (light grid, blue arrow polygon with an
## orange outline, vertices (80,190) (470,190) (470,90) (720,250) (470,410)
## (470,310) (80,310); dashed spine at row 250; 50 x 50 px corner squares
## red/green/blue/yellow centred at (25,25) (775,25) (25,475) (775,475); TOP,
## RIGHT, BOTTOM labels). arrow_spatial.rds holds 159 cells whose coordinates
## ARE pixel positions (x = column, y = row; 119 outline, 38 spine, anchors at
## (0,0) and (800,500)), written by data-raw/build_builder_spatial_fixtures.R.
## Data y points up in Builder and Viewer, image rows point down, so with
## bounds 0..800 x 0..500 the picture is registered by construction only with
## flip_y; the arrow is mirror-symmetric about row 250, so only the corner
## squares and the TOP/BOTTOM labels tell the two apart.
##
## Per setting T the cells are moved to where the Builder preview puts their
## pixel under T (builder_q), the image gets alignment T, the CRB + Viewer App
## is built and published, the App is started and both spatial canvases are
## captured. The data->screen map is fitted to the captured cell points
## (similarity with y flip, iterative closest point); the corner squares and
## the orange outline found in the capture are compared with where they
## should be (builder_q of their pixels). Two more rows: the fixture as is
## with identity alignment, and the Builder example's own preset (rotation 28,
## bounds fitted by builder_alignment_fit_bounds(), as builder_example_configure_entry()).
arrow_vertices <- rbind(c(80, 190), c(470, 190), c(470, 90), c(720, 250),
                        c(470, 410), c(470, 310), c(80, 310), c(80, 190))
arrow_squares <- list(c("#dc2626", 25, 25), c("#16a34a", 775, 25),
                      c("#2563eb", 25, 475), c("#eab308", 775, 475))
arrow_settings <- list(
  identity = list(), translate = list(dx = 120, dy = -80),
  scale_1.5 = list(scale = 1.5), scale_0.6 = list(scale = 0.6),
  flip_x = list(flip_x = TRUE), flip_y = list(flip_y = TRUE),
  rotate_90 = list(rotation = 90), rotate_180 = list(rotation = 180),
  rotate_270 = list(rotation = 270), rotate_28 = list(rotation = 28),
  fixture_as_is_identity = list(as_is = TRUE),
  example_preset_rotation_28 = list(as_is = TRUE, preset = TRUE, rotation = 28),
  ## the Builder example exactly as builder_example_configure_entry() sets it
  ## up (image record and any cell coordinate transform), opacities set to 1
  ## so colours can be measured
  example_as_configured = list(as_is = TRUE, example = TRUE)
)
only_arrow <- Sys.getenv("D_ARROW")
if (nzchar(only_arrow)) arrow_settings <- arrow_settings[strsplit(only_arrow, ",")[[1]]]

fit_screen <- function(cap, legend, data_xy) {
  ## Pixels in a legend (cell) colour; screen = (tx + k x, ty - k y). Start
  ## from the bounding boxes, then minimise the mean distance from each
  ## predicted cell to the nearest cell-coloured pixel.
  pal <- vapply(legend$col, rgb_to_hex, "")
  mask <- Reduce(`|`, lapply(pal, function(h) colour_mask(cap, h, 0.08)))
  idx <- which(mask, arr.ind = TRUE)
  if (!nrow(idx)) return(NULL)
  sx <- range(idx[, 2] - 0.5)
  sy <- range(idx[, 1] - 0.5)
  k <- mean(c(diff(sx) / diff(range(data_xy[, 1])), diff(sy) / diff(range(data_xy[, 2]))))
  par <- c(sx[1] - k * min(data_xy[, 1]), sy[1] + k * max(data_xy[, 2]), k)
  dm <- distmap(!mask)
  cost <- function(p) {
    x <- round(p[1] + p[3] * data_xy[, 1] + 0.5)
    y <- round(p[2] - p[3] * data_xy[, 2] + 0.5)
    ok <- x >= 1 & x <= nrow(dm) & y >= 1 & y <= ncol(dm)
    mean(c(dm[cbind(y[ok], x[ok])], rep(50, sum(!ok))))
  }
  ## distmap is indexed [row, col]; cap rows are y
  dm <- dm
  cost <- function(p) {
    x <- round(p[1] + p[3] * data_xy[, 1] + 0.5)
    y <- round(p[2] - p[3] * data_xy[, 2] + 0.5)
    ok <- y >= 1 & y <= nrow(dm) & x >= 1 & x <= ncol(dm)
    mean(c(dm[cbind(y[ok], x[ok])], rep(50, sum(!ok))))
  }
  opt <- stats::optim(par, cost, control = list(parscale = c(5, 5, par[3] / 50), maxit = 2000))
  list(tx = opt$par[1], ty = opt$par[2], k = opt$par[3], blobs = nrow(data_xy),
       point_fit_rms = opt$value)
}
seg_dist <- function(px, py, poly) {
  d <- rep(Inf, length(px))
  for (i in seq_len(nrow(poly) - 1L)) {
    ax <- poly[i, 1]; ay <- poly[i, 2]; bx <- poly[i + 1, 1]; by <- poly[i + 1, 2]
    t <- ((px - ax) * (bx - ax) + (py - ay) * (by - ay)) / ((bx - ax)^2 + (by - ay)^2)
    t <- pmin(pmax(t, 0), 1)
    d <- pmin(d, sqrt((px - ax - t * (bx - ax))^2 + (py - ay - t * (by - ay))^2))
  }
  d
}

if ("arrow" %in% parts) {
  fx <- system.file("builder", "fixtures", "spatial_alignment", package = "CerebroNexus")
  bg <- file.path(fx, "arrow_background.png")
  fixture <- readRDS(file.path(fx, "arrow_spatial.rds"))
  tc <- GetTissueCoordinates(fixture[["arrow_fov"]])
  pix <- matrix(c(tc$x, tc$y), ncol = 2, dimnames = list(tc$cell, c("u", "v")))
  ## D_ARROW_FILL=1 (display captures for Supplementary Figure S11b only): the
  ## cells fill the arrow on a 30-px grid, labelled tail, shaft or head, and the
  ## Viewer colours them by region; no cell lies outside the arrow. Grid cells
  ## keep 14 px from the outline; one more cell just inside the tip makes the
  ## Viewer's fitted view hold the whole arrow.
  if (nzchar(Sys.getenv("D_ARROW_FILL"))) {
    g <- expand.grid(u = seq(5, 795, by = 30), v = seq(10, 490, by = 30))
    inside <- sp::point.in.polygon(g$u, g$v, arrow_vertices[, 1], arrow_vertices[, 2]) > 0
    edge <- seg_dist(g$u, g$v, arrow_vertices)
    cells_in <- g[inside & edge >= 14, ]
    extent <- data.frame(u = 700, v = 250)
    cells_in <- rbind(cells_in, extent)
    region <- ifelse(cells_in$u >= 470, "head", ifelse(cells_in$u >= 275, "shaft", "tail"))
    uv <- as.matrix(cells_in)
    n <- nrow(uv)
    ids <- sprintf("ArrowFill%03d", seq_len(n))
    counts <- GetAssayData(fixture, assay = "Spatial", layer = "counts")[, sample(ncol(fixture), n, replace = TRUE)]
    colnames(counts) <- ids
    fill <- SeuratObject::CreateSeuratObject(counts, assay = "Spatial")
    fill$region <- factor(region, c("tail", "shaft", "head"))
    fill$seurat_clusters <- fill$region
    fill$cell_type_final <- fill$region
    fill$sample <- "arrow_sample"
    emb <- uv; dimnames(emb) <- list(ids, c("umap_1", "umap_2"))
    fill[["umap"]] <- SeuratObject::CreateDimReducObject(emb, key = "umap_", assay = "Spatial")
    fill[["arrow_fov"]] <- CreateFOV(coords = data.frame(x = uv[, 1], y = uv[, 2], cell = ids),
                                     type = "centroids", assay = "Spatial", key = "arrow_")
    fixture <- fill
    pix <- matrix(uv, ncol = 2, dimnames = list(ids, c("u", "v")))
  }
  B <- list(xmin = 0, xmax = 800, ymin = 0, ymax = 500)
  for (id in names(arrow_settings)) {
    cat("\n==== arrow ", id, " ====\n", sep = "")
    tr <- arrow_settings[[id]]
    dir <- file.path(root, paste0("arrow_", id))
    unlink(dir, recursive = TRUE)
    dir.create(dir, recursive = TRUE)
    o <- fixture
    o$sample <- "arrow"
    if (isTRUE(tr$as_is)) {
      data_xy <- pix
    } else {
      data_xy <- builder_q(pix[, 1], pix[, 2], tr, B, 800, 500)
      rownames(data_xy) <- rownames(pix)
      o@images <- list()
      o[["arrow_fov"]] <- CreateFOV(coords = data.frame(x = data_xy[, 1], y = data_xy[, 2], cell = rownames(pix)),
                                    type = "centroids", assay = "Spatial", key = "arrow_")
    }
    colnames(data_xy) <- c("x", "y")
    input <- file.path(dir, "arrow.rds")
    saveRDS(o, input)
    extra_configure <- list()
    if (isTRUE(tr$example)) {
      catalog <- rt$builder_example_catalog()$spatial_alignment
      configured <- rt$builder_example_configure_entry(
        list(id = "spatial_alignment", settings = list()), catalog, fixture)
      rec <- configured$settings$images$arrow_fov[[1L]]
      rec[c("image_opacity", "point_opacity", "point_size")] <- list(1, 1, point_size)
      extra_configure$spatial_coordinate_transforms <- configured$settings$spatial_coordinate_transforms
      expected_tr <- rec[c("dx", "dy", "scale", "rotation", "flip_x", "flip_y")]
      eb <- rec$base_bounds
    } else if (isTRUE(tr$preset)) {
      ins <- rt$builder_read_image(bg)
      rec <- rt$builder_alignment_record(
        source = list(name = basename(bg), type = ins$mime, size = ins$bytes),
        base_bounds = rt$builder_alignment_fit_bounds(
          list(xmin = min(data_xy[, 1]), xmax = max(data_xy[, 1]), ymin = min(data_xy[, 2]), ymax = max(data_xy[, 2])),
          ins$source_dimensions),
        parameters = utils::modifyList(rt$builder_alignment_defaults(),
          list(rotation = 28, image_opacity = 1, point_opacity = 1, point_size = point_size)),
        section = list(id = "arrow_fov", kind = "spatial"), source_path = ins$source_path)
      rec$source_content_md5 <- ins$source_content_md5
      expected_tr <- list(rotation = 28)
      eb <- rec$base_bounds
    } else {
      rec <- image_record(bg, "arrow_fov", B, tr)
      expected_tr <- tr
      eb <- B
    }
    ## where the Builder preview shows the image features in data space
    sq_exp <- builder_q(vapply(arrow_squares, function(x) as.numeric(x[[2]]), 1),
                        vapply(arrow_squares, function(x) as.numeric(x[[3]]), 1), expected_tr, eb, 800, 500)
    poly_exp <- builder_q(arrow_vertices[, 1], arrow_vertices[, 2], expected_tr, eb, 800, 500)
    sq_pred_viewer <- viewer_q(vapply(arrow_squares, function(x) as.numeric(x[[2]]), 1),
                               vapply(arrow_squares, function(x) as.numeric(x[[3]]), 1), expected_tr, eb, 800, 500)
    data_per_px <- (eb$xmax - eb$xmin) / 800 * (expected_tr$scale %||% 1)
    ## as-is rows: truth is the fixture's own registration (cells = pixels)
    if (isTRUE(tr$as_is)) {
      sq_true <- cbind(vapply(arrow_squares, function(x) as.numeric(x[[2]]), 1),
                       vapply(arrow_squares, function(x) as.numeric(x[[3]]), 1))
      poly_true <- arrow_vertices
    } else {
      sq_true <- sq_exp
      poly_true <- poly_exp
    }
    app <- publish_case(paste0("arrow_", id), input,
                        c(list(images = list(arrow_fov = rec), organism = "mm"),
                          if (nzchar(Sys.getenv("D_ARROW_FILL"))) list(groups = "region"),
                          Filter(Negate(is.null), extra_configure)))
    v <- viewer_open(app, paste0("arrow_", id))
    legend <- tryCatch({
      v$d$click(selector = "a[href='#shiny-tab-coordinated_views']")
      Sys.sleep(3)
      legend_colours(v$d)
    }, error = function(e) NULL)
    for (page in c("linked", "spatial")) {
      file <- file.path(captures, paste0("arrow_", id, "_", page, ".png"))
      got <- bv_capture(if (page == "linked") capture_linked(v$d, file) else capture_spatial(v$d, file))
      row <- list(case = paste0("arrow_", id), page = page,
                  transform = bv_one_line(jsonlite::toJSON(tr, auto_unbox = TRUE)))
      if (!is.null(got$error) || is.null(legend)) {
        row$error <- bv_one_line(got$error %||% "legend not found")
      } else {
        cap <- read_capture(file)
        f <- fit_screen(cap, legend, data_xy)
        to_s <- function(xy) cbind(f$tx + f$k * xy[, 1], f$ty - f$k * xy[, 2])
        sq <- t(vapply(arrow_squares, function(x) blob(colour_mask(cap, x[[1]], 0.12)), numeric(3)))
        sq_ok <- sq[, "n"] > 30
        e <- to_s(sq_true)
        r_sq <- sqrt((sq[, "x"] - e[, 1])^2 + (sq[, "y"] - e[, 2])^2) / f$k / data_per_px
        r_sq[!sq_ok] <- NA
        om <- colour_mask(cap, "#ea580c", 0.10)
        idx <- which(om, arr.ind = TRUE)
        ps <- to_s(poly_true)
        r_out <- if (nrow(idx)) seg_dist(idx[, 2] - 0.5, idx[, 1] - 0.5, ps) / f$k / data_per_px else NA
        pv <- sqrt(rowSums((sq_pred_viewer - sq_exp)^2)) / data_per_px
        row <- c(row, list(
          cells = f$blobs, cell_fit_mean_dist_capture_px = round(f$point_fit_rms, 2),
          capture_px_per_image_px = round(f$k * data_per_px, 3),
          corner_squares_in_view = sum(sq_ok),
          max_residual_image_px = if (any(sq_ok)) round(max(r_sq, na.rm = TRUE), 2) else NA,
          corner_residuals_image_px = paste(round(r_sq, 1), collapse = ";"),
          outline_pixels_found = nrow(idx),
          outline_residual_p95_image_px = if (nrow(idx)) round(stats::quantile(r_out, 0.95), 2) else NA,
          outline_residual_max_image_px = if (nrow(idx)) round(max(r_out), 2) else NA,
          predicted_viewer_residual_image_px = round(max(pv), 1)))
      }
      rows[[length(rows) + 1L]] <- as.data.frame(row, stringsAsFactors = FALSE)
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
