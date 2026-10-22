# Capture the Viewer states the interface figures use.
#
#   Rscript scripts/capture_viewer.R <viewer-url> <out-dir> [step ...]
#
# Without step names all steps run: ren, xenium, hla10, hla293, motif, e18.
# The Viewer must already be running with the Ren and E18 demo data sets (see
# run.sh). Every state is reached from a fresh page load by the steps below,
# and every screenshot is taken at a 1024 x 720 CSS viewport and
# devicePixelRatio 3 (3072 x 2160 pixels; the Xenium Spatial page uses a
# 960 px tall viewport). Figures crop these captures; figures.R records the
# printed size of the smallest interface text in every crop.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) stop("Usage: capture_viewer.R <viewer-url> <out-dir> [step ...]", call. = FALSE)
url <- args[[1]]
out <- args[[2]]
steps <- if (length(args) > 2L) args[-(1:2)] else c("ren", "xenium", "hla10", "hla293", "motif", "e18")
topic <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))), ".."))
source(file.path(topic, "scripts", "capture_lib.R"))
selections <- file.path(topic, "data", "selections")

WIDTH <- 1024
HEIGHT <- 720
# The Spatial page stacks its legend above the plot; a taller page keeps the
# whole plot on screen.
HEIGHT_SPATIAL <- 960

REN <- "Ren et al. COVID-19 atlas (1.46M + TCR/BCR)"
E18 <- "10x E18 mouse brain (1.3M)"
XENIUM <- "Mouse brain (Xenium)"
HLA <- "HLA & TCR"

# A fresh page with one data set loaded.
open_dataset <- function(dataset, height = HEIGHT) {
  b <- capture_session(url, WIDTH, height)
  wait_for(b, "document.getElementById('crb_file_selector')", what = "the data set menu")
  wait_idle(b)
  set_input(b, "crb_file_selector", dataset)
  wait_idle(b, timeout = 900)
  b
}

page_has <- function(b, pattern, timeout = 600) {
  wait_for(b, sprintf("%s.test(document.body.innerText)", pattern), timeout, what = pattern)
}

# Open a saved Linked views configuration (selection plus view settings), the
# same way a reader would with Share > Open.
open_linked_view <- function(b, file) {
  show_tab(b, "coordinated_views")
  wait_idle(b, 5)
  # Linked views loads per-cell codes only for the active colouring, and a file
  # whose colouring has no codes yet is refused, so colour by it first.
  mode <- jsonlite::read_json(file.path(selections, file))$view$colour$mode
  if (!identical(js(b, "document.getElementById('cv-pick-color').value"), mode)) {
    set_input(b, "cv-pick-color", mode)
    wait_idle(b, 5, 600)
  }
  click(b, "#cv-config-open")
  # The download button is enabled once the linked plots have their data, so
  # the file is only opened against a fully loaded view.
  wait_for(b, "document.getElementById('cv-config-download') && !document.getElementById('cv-config-download').disabled",
    timeout = 600, what = "the linked views to finish loading"
  )
  upload_file(b, "#coordviews_config_upload", file.path(selections, file))
  wait_for(b, "document.getElementById('cv-config-status').classList.contains('is-success')",
    timeout = 300, what = paste("opening", file)
  )
  click(b, "#cv-config-close")
  wait_idle(b, 6, 600)
}


STEPS <- list()

# Ren projection (Figure 1a): Projection page, t-SNE, coloured by major_type.
# Then the saved 13,556-cell selection in Linked views (Figure 3 status strip).
STEPS$ren <- function() {
  b <- open_dataset(REN)
  show_tab(b, "overview")
  page_has(b, "/view with 1462702 points/")
  set_input(b, "overview_projection_to_display", "tsne")
  set_input(b, "overview_projection_point_color", "major_type")
  wait_idle(b, 6, 600)
  capture(b, "ren-projection", out)
  open_linked_view(b, "ren-linked-local.json")
  page_has(b, "/13,?556/")
  capture(b, "ren-linked-local", out)
  b$close()
}

# Xenium Spatial page (Figure 4a-c), then the saved 500-cell selection in
# Linked views (identity check for Figure 4d,e).
STEPS$xenium <- function() {
  b <- open_dataset(XENIUM, HEIGHT_SPATIAL)
  show_tab(b, "spatial")
  wait_idle(b, 6)
  set_input(b, "spatial_projection_to_display", "fov")
  set_input(b, "spatial_projection_plot_type", "ImageDimPlot")
  wait_idle(b, 4)
  set_input(b, "spatial_projection_point_color", "cluster")
  wait_idle(b, 6)
  capture(b, "xenium-cluster", out)
  set_input(b, "spatial_projection_plot_type", "ImageFeaturePlot")
  wait_idle(b, 4)
  set_input(b, "spatial_projection_feature_to_display", "Slc17a7")
  wait_idle(b, 6)
  capture(b, "xenium-feature", out)
  set_input(b, "spatial_projection_plot_type", "Co-expression (RGB)")
  wait_idle(b, 4)
  set_input(b, "spatial_projection_coexpr_r", "Slc17a7")
  set_input(b, "spatial_projection_coexpr_g", "Gad1")
  set_input(b, "spatial_projection_coexpr_b", "Gad2")
  wait_idle(b, 6)
  # The three gene menus push the plot below the fold; scroll it into view.
  capture(b, "xenium-rgb", out, scroll_to = "#cv-cv-a")
  open_linked_view(b, "xenium-linked-selected.json")
  page_has(b, "/\\b500\\b/")
  capture(b, "xenium-linked-selected", out)
  b$close()
}

# HLA & TCR: the exact 10-cell receptor selection (Figure 5).
STEPS$hla10 <- function() {
  b <- open_dataset(HLA)
  open_linked_view(b, "hla-10.json")
  page_has(b, "/\\b10 (cells )?selected/")
  capture(b, "hla-10", out)
  b$close()
}

# HLA & TCR: the 293-cell gene-defined selection (Figure 7).
STEPS$hla293 <- function() {
  b <- open_dataset(HLA)
  open_linked_view(b, "hla-293.json")
  page_has(b, "/\\b293 (cells )?selected/")
  capture(b, "hla-293", out)
  b$close()
}

# HLA & TCR Motifs: TRB network of all cells, coloured by motif (Figure 6a),
# then the donor HLA table (Figure 6b).
STEPS$motif <- function() {
  b <- open_dataset(HLA)
  show_tab(b, "hla_tcr_motifs")
  wait_idle(b, 6)
  set_input(b, "hla_chain", "TRB")
  set_input(b, "hla_scope", "all")
  set_input(b, "hla_color_by", "cluster")
  wait_idle(b, 8)
  page_has(b, "/view with 94 points/")
  capture(b, "hla-motif", out)
  # The HLA Associations tab opens on HLA-A*02:01 and the motif component
  # TRBV19::M13_15; its per-donor table is Figure 6b.
  show_tab(b, "HLA Associations")
  wait_idle(b, 8)
  page_has(b, "/TRBV19::M13_15 \\(30 CDR3\\)/")
  page_has(b, "/donor1\\s+donor\\s+carrier\\s+true\\s+3000\\s+306/")
  capture(b, "hla-associations", out)
  b$close()
}

# E18 projection (Supplementary Figure S2): UMAP coloured by seurat_clusters.
STEPS$e18 <- function() {
  b <- open_dataset(E18)
  show_tab(b, "overview")
  page_has(b, "/view with 1306127 points/")
  set_input(b, "overview_projection_to_display", "umap")
  set_input(b, "overview_projection_point_color", "seurat_clusters")
  wait_idle(b, 6, 600)
  capture(b, "e18-projection", out)
  b$close()
}

unknown <- setdiff(steps, names(STEPS))
if (length(unknown)) stop("Unknown steps: ", paste(unknown, collapse = ", "), call. = FALSE)
for (step in steps) STEPS[[step]]()
