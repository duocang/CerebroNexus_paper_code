## Experiment F1/F2: cell selection and cross-view mapping.
##
## Each variant of the complete_viewer fixture (scripts/F_variants.R) is built
## into an App through the headless Builder route. The checks then run the
## Viewer server code copied into that App (viewer/coordinated_views/config.R,
## bundle.R and viewer/clone_contract.R, sourced from the App directory) on the
## App's own CRB:
##
##  F1  a Linked views View JSON (schema "cerebronexus-linked-view") is made
##      with the App's own cv_config_prepare() for a predeclared barcode set,
##      then opened with cv_config_decode() as the server does for "Open JSON"
##      (coordinated_views/server.R); the restored set, the selection indices
##      sent to the browser and the server's "Table of selected cells"
##      (cv_selected_metadata()) are compared with the predeclared set.
##  F2  for each set, the cells every Linked views space places are taken from
##      the same functions the bundle uses (cv_spatial_section_rows() per
##      section, cv_clone_per_cell() for the clone space, the CRB projections)
##      and compared with the truth read from the source object; this is the
##      count the page reports as "n of N selected cells mapped".
##
## The App was also started and loaded in headless Chrome (viewer.R) once per
## variant. The page's file input and coverage readout were not driven.
##
## Usage: Rscript scripts/F_selection.R
## Writes results/F_selection.csv and results/F_mapping.csv.

source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))), "common.R"))
source(file.path(bv_root, "scripts", "viewer.R"))
source(file.path(bv_root, "scripts", "apps.R"))
source(file.path(bv_root, "scripts", "F_variants.R"))

root <- file.path(bv_data, "F", "selection")
dir.create(root, recursive = TRUE, showWarnings = FALSE)
rt <- bv_load_runtime()
variants <- f_variants()

viewer_env <- function(app_dir) {
  env <- new.env(parent = globalenv())
  env$`%||%` <- `%||%`
  for (f in c("clone_contract.R", file.path("coordinated_views", "config.R"),
              file.path("coordinated_views", "bundle.R"))) {
    sys.source(file.path(app_dir, "viewer", f), envir = env)
  }
  env
}

same_set <- function(a, b) setequal(as.character(a), as.character(b)) && length(unique(a)) == length(unique(b))

sel_rows <- list()
map_rows <- list()
for (vid in names(variants)) {
  cat("\n==== ", vid, " ====\n", sep = "")
  obj <- variants[[vid]]
  truth <- f_truth(obj)
  built <- bv_capture(bv_build_app(rt, "cv", paste("complete viewer", vid), object = obj,
                                   work = file.path(root, vid, "work"),
                                   release = file.path(root, vid, "release")))
  if (!is.null(built$error)) {
    extra <- identical(vid, "immune_extra")
    sel_rows[[length(sel_rows) + 1L]] <- data.frame(variant = vid, set = "build",
      expected = if (extra) "repertoire IDs that are not cells reported (named) before or at build" else "App built",
      observed = bv_one_line(built$error),
      result = if (extra && grepl("attention", built$error)) "partial (held at Review, IDs not named)" else "fail")
    next
  }
  a <- built$value
  viewer <- bv_viewer_check(a$app_dir, file.path(root, vid), rownames(obj)[[1L]],
                            label = paste0("F_", vid))
  crb <- readCerebro(a$crb)
  cells <- crb$getCellNames()
  md <- crb$getMetaData()
  env <- viewer_env(a$app_dir)
  fingerprint <- env$cv_config_cell_fingerprint(cells)
  ir <- crb$getImmuneRepertoire()
  ir_barcodes <- unique(unlist(lapply(ir, function(t) as.character(t$barcode))))
  clone <- env$cv_clone_per_cell(ir, cells)
  spatial_names <- crb$availableSpatial()
  placed <- c(
    stats::setNames(lapply(crb$availableProjections(), function(p) {
      xy <- crb$getProjection(p); cells[stats::complete.cases(xy[cells, , drop = FALSE])]
    }), paste0("projection::", crb$availableProjections())),
    stats::setNames(lapply(spatial_names, function(nm) {
      co <- crb$getSpatialData(nm, hydrate_molecules = FALSE)$coordinates
      rows <- env$cv_spatial_section_rows(nm, co, cells)
      cells[rows[!is.na(rows)]]
    }), paste0("spatial::", spatial_names)),
    list(clone = if (is.null(clone)) character() else cells[!is.na(clone$clone)])
  )
  truth_placed <- c(
    stats::setNames(rep(list(truth$cells), length(crb$availableProjections())),
                    paste0("projection::", crb$availableProjections())),
    stats::setNames(truth$spatial[spatial_names], paste0("spatial::", spatial_names)),
    list(clone = if (identical(clone$receptor, "TCR")) truth$tcr else truth$immune)
  )

  base_row <- data.frame(
    variant = vid, app_built = TRUE, viewer_http = viewer$http_status,
    viewer_loaded = viewer$viewer_loaded,
    crb_cells = length(cells), crb_cells_equal_source_set = same_set(cells, truth$cells),
    crb_cell_order_equal_source = identical(cells, truth$cells),
    crb_repertoire_ids_not_cells = length(setdiff(ir_barcodes, cells)),
    clone_space_receptor = clone$receptor %||% NA_character_,
    source_repertoire_ids_not_cells = length(truth$immune_unknown),
    stringsAsFactors = FALSE)

  set.seed(3)
  section <- truth$spatial[["section_a_1_fov_1"]]
  sets <- list(
    complete = truth$cells,
    partial = sample(truth$cells, 60),
    zero = character(),
    one_section = section,
    partial_reordered = rev(sample(truth$cells, 60)),
    partial_plus_unknown = c(sample(truth$cells, 40), "not_a_cell_1", "not_a_cell_2", "not_a_cell_3")
  )
  if (identical(vid, "case_ids")) {
    sets$upper_case_id_only <- toupper(colnames(variants$base)[[1L]])
    sets$lower_case_id_only <- colnames(variants$base)[[1L]]
  }
  for (sid in names(sets)) {
    s <- sets[[sid]]
    known <- intersect(s, cells)
    unknown <- setdiff(s, cells)
    ## The download route: the App prepares a document from selection indices
    ## of the known cells (the browser can only select cells it has).
    prepared <- bv_capture(env$cv_config_prepare(
      list(schema = env$CV_CONFIG_SCHEMA, version = env$CV_CONFIG_VERSION,
           dataset = list(cell_count = length(cells), cell_fingerprint = fingerprint),
           selection = list(cells = I(as.list(s)), source = NULL, geometry = NULL),
           view = list(projections = I(list("umap")), spatial_sections = I(as.list(spatial_names)),
                       active_spatial = spatial_names[[1L]],
                       colour = list(mode = "cell_type", genes = I(list()), gene = NULL, rgb_genes = I(list()), clip = 0.01),
                       filters = setNames(list(), character()), hidden_levels = I(list()),
                       display = list(point_size = 5, point_opacity = 1, percentage_cells = 100,
                                      group_labels = FALSE, cell_borders = FALSE, background_images = TRUE,
                                      selection_mode = "lasso", clone_layout = "stack", keep_square = FALSE),
                       focus_space = NULL,
                       lenses = I(lapply(c("projection::umap", paste0("spatial::", spatial_names)), function(sp)
                         list(space = sp, viewport = list(cx = 0.5, cy = 0.5, span = 1), rotation = NULL))),
                       spatial_backgrounds = I(list()),
                       trekker = list(dissolve_percentage = 0, evidence = FALSE, niche_radius = 250))),
      cells = cells, fingerprint = fingerprint))
    opened <- if (is.null(prepared$error)) bv_capture(env$cv_config_decode(
      prepared$value$json, cells = cells, fingerprint = fingerprint)) else NULL
    restored <- if (!is.null(opened) && is.null(opened$error)) opened$value$selection$cells else NULL
    indices <- if (!is.null(restored)) match(restored, cells) - 1L else NULL
    table_ids <- if (length(restored)) as.character(env$cv_selected_metadata(md, restored)$cell_barcode) else character()
    err <- prepared$error %||% opened$error %||% ""
    ok_known <- !length(unknown)
    row <- cbind(base_row, data.frame(
      set = sid, set_size = length(s), known = length(known), unknown = length(unknown),
      prepare_error = bv_one_line(prepared$error %||% ""),
      open_error = bv_one_line(opened$error %||% ""),
      restored = length(restored),
      restored_equal_set = !is.null(restored) && same_set(restored, s),
      indices_point_to_set = !is.null(indices) && same_set(cells[indices + 1L], s),
      table_equal_set = same_set(table_ids, restored %||% character()),
      unknown_ids_named_in_error = length(unknown) > 0 && all(vapply(unknown, grepl, NA, err, fixed = TRUE)),
      stringsAsFactors = FALSE))
    row$expected <- if (ok_known) "restored set, indices and table equal the predeclared set" else
      "rejected or reduced, with the unknown IDs reported apart from the known ones"
    row$result <- if (ok_known) {
      if (isTRUE(row$restored_equal_set) && isTRUE(row$indices_point_to_set) && isTRUE(row$table_equal_set)) "pass" else "fail"
    } else {
      if (nzchar(err) && isTRUE(row$unknown_ids_named_in_error)) "pass" else
        if (nzchar(err)) "partial (rejected, unknown IDs not listed)" else "fail"
    }
    sel_rows[[length(sel_rows) + 1L]] <- row

    if (!ok_known) next
    for (space in names(placed)) {
      map_rows[[length(map_rows) + 1L]] <- data.frame(
        variant = vid, set = sid, space = space, selected = length(s),
        mapped_viewer = length(intersect(s, placed[[space]])),
        mapped_truth = length(intersect(s, truth_placed[[space]])),
        mapped_sets_equal = same_set(intersect(s, placed[[space]]), intersect(s, truth_placed[[space]])),
        coverage = if (!length(s)) "empty selection" else {
          n <- length(intersect(s, placed[[space]]))
          if (n == length(s)) "all" else if (n == 0) "none" else "part"
        },
        stringsAsFactors = FALSE)
    }
  }
}
all_cols <- unique(unlist(lapply(sel_rows, names)))
sel_rows <- lapply(sel_rows, function(r) { r[setdiff(all_cols, names(r))] <- NA; r[all_cols] })
sel <- do.call(rbind, sel_rows)
map <- do.call(rbind, map_rows)
utils::write.csv(sel, file.path(bv_root, "results", "F_selection.csv"), row.names = FALSE)
utils::write.csv(map, file.path(bv_root, "results", "F_mapping.csv"), row.names = FALSE)
print(sel[, c("variant", "set", "restored", "restored_equal_set", "open_error", "result")])
print(table(map$variant, map$mapped_sets_equal))
