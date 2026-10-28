# Supplementary Figures S11 (background-image alignment under spatial transforms) and
# S12 (overview of every validation row, on the last revision it ran on), drawn from
# results/ to the Genome Biology rules of the other figures: 170 mm wide, Arial
# embedded (cairo_pdf), 7 pt text, 8 pt bold panel labels, lines >= 0.25 pt,
# Okabe-Ito colours, no titles or captions in the files. Nothing is rerun.
#
#   Rscript topics/builder_validation/scripts/figures.R          # from the repository root
#   Rscript topics/interface_figures/scripts/check_figures.R topics/builder_validation/figures
#
# Use your own R on macOS: Nix's cairo writes spaces as Type 3 fonts.

suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
})

res <- "topics/builder_validation/results"
out <- "topics/builder_validation/figures"
stopifnot(dir.exists(res))
read <- function(f) utils::read.csv(file.path(res, f), check.names = FALSE)

WIDTH <- 170
FONT <- "Arial"
TEXT_PT <- 7
LINE <- 0.5 / .pt

theme_bv <- function() {
  theme_classic(base_size = TEXT_PT, base_family = FONT) +
    theme(
      text = element_text(size = TEXT_PT, colour = "black"),
      axis.text = element_text(size = TEXT_PT, colour = "black"),
      axis.line = element_line(linewidth = LINE),
      axis.ticks = element_line(linewidth = LINE),
      axis.ticks.length = unit(1, "mm"),
      strip.background = element_blank(),
      strip.text = element_text(size = TEXT_PT),
      legend.text = element_text(size = TEXT_PT),
      legend.title = element_text(size = TEXT_PT),
      legend.key.size = unit(3, "mm"),
      legend.background = element_blank(),
      plot.margin = margin(1, 1, 1, 1, "mm"),
      plot.tag = element_text(size = 8, face = "bold", family = FONT)
    )
}

save_figure <- function(name, plot, height) {
  stopifnot(height <= 225)
  plot <- plot & theme(plot.tag = element_text(size = 8, face = "bold", family = FONT))
  dir.create(file.path(out, "qa"), recursive = TRUE, showWarnings = FALSE)
  f <- file.path(out, name)
  ggsave(paste0(f, ".pdf"), plot, width = WIDTH, height = height, units = "mm", device = cairo_pdf, bg = "white")
  ggsave(paste0(f, ".png"), plot, width = WIDTH, height = height, units = "mm", dpi = 600, device = ragg::agg_png, bg = "white")
  ggsave(file.path(out, "qa", paste0(name, ".svg")), plot, width = WIDTH, height = height, units = "mm", device = svglite::svglite, bg = "white")
  message("Saved ", f, " (", WIDTH, " x ", height, " mm)")
}

# --- S11 a: residual per setting ------------------------------------------------
# All three datasets on 001c4d4dd. A setting with no landmark or corner square in
# view is drawn at the "not in view" row (none on this revision).
NOT_IN_VIEW <- 3e4
residuals <- function(file, dataset, in_view) {
  d <- read(file)
  data.frame(
    dataset = dataset,
    case = d$case,
    page = c(linked = "Linked views", spatial = "Spatial page")[d$page],
    residual = ifelse(d[[in_view]] > 0, d$max_residual_image_px, NOT_IN_VIEW)
  )
}
s11 <- rbind(
  residuals("D_spatial_transforms_001c4d4dd.csv", "Synthetic landmarks", "discs_in_view"),
  residuals("D_arrow_001c4d4dd.csv", "Arrow fixture", "corner_squares_in_view"),
  residuals("D_multisection_001c4d4dd.csv", "Multi-section", "discs_in_view")
)
stopifnot(!anyNA(s11$residual))
# The shipped example preset (rotation 28 against a 0 image) and the fixture shown
# without its flip y are negative controls, not settings; drop them.
s11 <- s11[!s11$case %in% c("arrow_example_preset_rotation_28", "arrow_fixture_as_is_identity"), ]
s11$case[s11$case == "arrow_example_as_configured"] <- "arrow_example"
settings <- c(
  identity = "identity", translate = "translate", "scale_1.5" = "scale 1.5", "scale_0.6" = "scale 0.6",
  flip_x = "flip x", flip_y = "flip y", rotate_90 = "rotate 90", rotate_180 = "rotate 180",
  rotate_270 = "rotate 270", rotate_30 = "rotate 30", rotate_28 = "rotate 28",
  rotate_90_flip_x = "rotate 90 + flip x", combined = "combined",
  origin_rotate_90 = "origin: rotate 90", origin_rotate_30 = "origin: rotate 30",
  origin_rotate_90_flip_x = "origin: rotate 90 + flip x", origin_combined = "origin: combined",
  example = "example preset",
  section_a_1_fov_1 = "a_1: dx, flip y", section_a_2_fov_1 = "a_2: flip x, scale",
  section_b_1_fov_1 = "b_1: rotate 90, dy"
)
s11$setting <- settings[sub("^(synthetic|arrow|multisection)_", "", s11$case)]
stopifnot(!anyNA(s11$setting))
s11$setting <- factor(s11$setting, unique(unname(settings)))
s11$dataset <- factor(s11$dataset, c("Synthetic landmarks", "Arrow fixture", "Multi-section"))

s11a <- ggplot(s11, aes(setting, residual)) +
  geom_hline(yintercept = 3, linetype = "22", linewidth = LINE, colour = "grey50") +
  geom_point(size = 1.3, colour = "#0072B2") +
  facet_grid(page ~ dataset, scales = "free_x", space = "free_x") +
  scale_x_discrete(NULL) +
  scale_y_log10("Max residual (source-image px)", breaks = c(0.1, 0.3, 1, 3, 10),
    labels = c("0.1", "0.3", "1", "3", "10"), limits = c(0.05, 10), expand = c(0, 0)) +
  labs(tag = "a") +
  theme_bv() +
  theme(
    panel.spacing.x = unit(2, "mm"),
    panel.spacing.y = unit(2, "mm"),
    panel.grid.major.y = element_line(colour = "grey90", linewidth = LINE),
    axis.text.x = element_text(angle = 50, hjust = 1, vjust = 1)
  )
stopifnot(max(s11$residual) < 10)

# --- S11 b: the arrow fixture on the Spatial page under four settings -----------
# Display captures of the same four settings on 33150d9d7 (D_ARROW_FILL=1,
# D_POINT_SIZE=18; results/D_captures_figS11_fill/): the cells fill the arrow on a
# 30-px grid, all inside it, and are coloured by region in the Viewer's default
# palette. The residuals in the titles come from the formal point-size-5 run of
# the outline fixture (panel a), since large points cover the corner squares
# that are measured.
# Captures are 1090 x 683 px (device scale 1); the same box, the whole plot
# canvas, is cut from each.
CROP <- list(x = 1:1090, y = 29:652)
capture <- function(case) {
  img <- png::readPNG(file.path(res, "D_captures_figS11_fill", paste0("arrow_", case, "_spatial.png")))
  stopifnot(dim(img)[1] == 683, dim(img)[2] == 1090)
  img[CROP$y, CROP$x, 1:3]
}
arrow <- read("D_arrow_001c4d4dd.csv")
IMG_MM <- 40
image_plot <- function(case, label) {
  img <- capture(case)
  r <- arrow$max_residual_image_px[arrow$case == paste0("arrow_", case) & arrow$page == "spatial"]
  h <- dim(img)[1]
  w <- dim(img)[2]
  ggplot() +
    annotation_raster(img, xmin = 0, xmax = w, ymin = 0, ymax = h, interpolate = FALSE) +
    annotate("rect", xmin = 0, xmax = w, ymin = 0, ymax = h, fill = NA, colour = "grey60", linewidth = LINE) +
    annotate("text", x = 0, y = h + 12, label = sprintf("%s: %.1f px", label, r), hjust = 0, vjust = 0,
      size = TEXT_PT / .pt, family = FONT) +
    coord_fixed(xlim = c(0, w), ylim = c(0, h + 60), expand = FALSE, clip = "off") +
    theme_void(base_family = FONT) +
    theme(plot.margin = margin(1, 1, 1, 1, "mm"))
}
panels <- c(identity = "identity", rotate_90 = "rotate 90", flip_x = "flip x", scale_0.6 = "scale 0.6")
bs <- Map(image_plot, names(panels), panels)
bs[[1]] <- bs[[1]] + labs(tag = "b") +
  theme(plot.tag = element_text(size = 8, face = "bold", family = FONT), plot.tag.position = c(0, 1))
# Region colours as drawn by the Viewer (sampled from the captures).
REGION <- c(tail = "#4C78A8", shaft = "#E07B39", head = "#59A14F")
# Key entries laid out by label length (x in characters of 7-pt text).
key <- data.frame(r = names(REGION), w = nchar(names(REGION)) + 5)
key$x <- 17 + cumsum(c(0, utils::head(key$w, -1)))
region_key <- ggplot(key) +
  geom_point(aes(x, 0), colour = REGION, size = 1.6) +
  geom_text(aes(x + 1, 0, label = r), hjust = 0, size = TEXT_PT / .pt, family = FONT) +
  annotate("text", x = 15.5, y = 0, label = "Cells by region:", hjust = 1, size = TEXT_PT / .pt, family = FONT) +
  coord_cartesian(xlim = c(0, 130), ylim = c(-1, 1), expand = FALSE, clip = "off") +
  theme_void(base_family = FONT)
s11b <- wrap_plots(bs, nrow = 1)
s11 <- wrap_plots(s11a, s11b, region_key, ncol = 1, heights = c(95, 40, 4))
save_figure("figS11-builder-transforms", s11, 150)

# Print size of the captures for check_figures.R (qa/screenshot-qa.csv). The
# arrow fixture's own TOP/RIGHT/BOTTOM labels are image content, not interface
# text; no interface text is inside the crop.
shots <- data.frame(
  figure = "figS11-builder-transforms",
  panel = paste("b", panels),
  ppi = round(length(CROP$x) / (IMG_MM / 25.4)),
  min_text_pt = NA_real_,
  below_6pt = FALSE,
  cut_text = FALSE
)

# --- S12: every validation row, on the last revision it ran on ----------------
REVS <- c("001c4d4dd", "33150d9d7")
STATUS <- c(
  "Pass" = "#009E73",
  "Explicit error (rejected or refused)" = "#56B4E9",
  "Fail" = "#D55E00",
  "Info (no pass criterion)" = "#BBBBBB",
  "Not run" = "white"
)
pretty_id <- function(x) {
  x <- gsub("_", " ", x)
  x <- gsub("\\bna\\b", "NA", x)
  x <- gsub("\\bids\\b", "IDs", x)
  x <- gsub("\\brds\\b", ".rds", x)
  gsub("\\bh5ad\\b", ".h5ad", x)
}

cells <- list()
add <- function(experiment, row, revision, status, part = "", n_parts = 1) {
  cells[[length(cells) + 1]] <<- data.frame(experiment, row, revision, status, part, n_parts)
}

# A: an explicit error stops the build; "silent output" published a CRB equal to
# its source (README, section A).
for (rev in REVS) {
  d <- read(sprintf("A_malformed_inputs_%s.csv", rev))
  stopifnot(nrow(d) == 20, all(d$outcome %in% c("explicit error", "silent output")))
  for (i in seq_len(nrow(d))) {
    add("A", pretty_id(d$case[i]), rev, if (d$outcome[i] == "explicit error") "Explicit error (rejected or refused)" else "Pass")
  }
}

# C and C with HDF5 output: pass when the intended release is in place (v2
# without a fault, v1 after a restore); explicit error when v2 was refused and v1
# kept, or when recovery itself refused with a message (abort of a preserved
# release; "not safely recoverable" while the publishing process is alive).
c_status <- function(d) {
  ok_release <- d$final_release %in% c("v1", "v2") & d$final_crb_readable %in% TRUE
  st <- ifelse(
    d$case == "C00_no_fault" & d$final_release == "v2", "Pass",
    ifelse(
      grepl("^recovered=TRUE", d$recover_result) & ok_release, "Pass",
      ifelse(
        grepl("^not needed", d$recover_result) & d$publish_v2_error != "" &
          (ok_release | grepl("^other", d$final_release)), "Explicit error (rejected or refused)",
        ifelse(grepl("^error: ", d$recover_result), "Explicit error (rejected or refused)", "Fail")
      )
    )
  )
  stopifnot(!any(st == "Fail"))
  st
}
c_files <- list(
  C = c("001c4d4dd" = "C_publish_faults_001c4d4dd.csv", "33150d9d7" = "C_publish_faults_33150d9d7.csv"),
  "C-h5" = c("001c4d4dd" = "F_publish_faults_h5.csv", "33150d9d7" = "F_publish_faults_h5_33150d9d7.csv")
)
for (ex in names(c_files)) {
  for (rev in REVS) {
    d <- read(c_files[[ex]][[rev]])
    d$status <- c_status(d)
    for (case in unique(d$case)) {
      r <- d[d$case == case, ]
      for (j in seq_len(nrow(r))) add(ex, pretty_id(case), rev, r$status[j], r$recovery_action[j], nrow(r))
    }
  }
}

# E: the verdict column of the run; "info (none)" is a run without a criterion.
e_labels <- c(
  E01 = "GET / without login", E02 = "private files by URL, traversal",
  E03 = "no data before login", E04 = "wrong password", E05 = "empty password",
  E06 = "empty username", E07 = "SQL-like username", E07b = "other account's password",
  E08 = "lockout after failed sign-ins", E09 = "right password (control)",
  E10 = "session data URLs, other client", E11 = "login token replayed",
  E12 = "logout ends the session", E13 = "inactivity timeout",
  E14 = "two concurrent sessions", E15 = "other App's account or token",
  E16 = "credentials database at rest", E17 = "database key not in App files",
  E18 = "no plaintext password in files", E19 = "no credentials in logs",
  E20 = "key file mode 0644", E21 = "wrong database key", E22 = "key file removed, no key",
  E23 = "key file is a symlink", E24 = "key file removed, key in env",
  E24b = "credentials database removed", E25 = "App without login"
)
for (rev in REVS) {
  d <- read(if (rev == "001c4d4dd") "E_security.csv" else sprintf("E_security_%s.csv", rev))
  stopifnot(nrow(d) == 40)
  d$id <- sub(" .*", "", d$test)
  d$status <- c(pass = "Pass", fail = "Fail", info = "Info (no pass criterion)", "info (none)" = "Info (no pass criterion)")[d$result]
  stopifnot(!anyNA(d$status), all(d$id %in% names(e_labels)))
  for (id in unique(d$id)) {
    r <- d[d$id == id, ]
    for (j in seq_len(nrow(r))) add("E", paste(id, e_labels[[id]]), rev, r$status[j], r$app[j], nrow(r))
  }
}

# F1: one row per predeclared set, over the App variants it ran on (all agree).
d <- read("F_selection.csv")
f1_labels <- c(
  complete = "complete set (180)", partial = "partial set (60)", zero = "empty set",
  one_section = "one section (30)", partial_reordered = "partial, reverse order",
  lower_case_id_only = "lower-case ID of a pair", upper_case_id_only = "upper-case ID of a pair",
  partial_plus_unknown = "partial + 3 unknown IDs", build = "repertoire IDs not cells (build)"
)
d$status <- ifelse(d$result == "pass", "Pass", ifelse(grepl("^partial", d$result), "Explicit error (rejected or refused)", "Fail"))
for (set in names(f1_labels)) {
  r <- d[d$set == set, ]
  stopifnot(nrow(r) > 0, length(unique(r$status)) == 1)
  add("F1", sprintf("%s, %d App%s", f1_labels[[set]], nrow(r), if (nrow(r) > 1) "s" else ""), "001c4d4dd", r$status[1])
  add("F1", sprintf("%s, %d App%s", f1_labels[[set]], nrow(r), if (nrow(r) > 1) "s" else ""), "33150d9d7", "Not run")
}

# F2: one row per App variant, all set x space rows.
d <- read("F_mapping.csv")
for (v in unique(d$variant)) {
  r <- d[d$variant == v, ]
  lab <- sprintf("%s: %d sets x spaces", pretty_id(v), nrow(r))
  add("F2", lab, "001c4d4dd", if (all(r$mapped_sets_equal)) "Pass" else "Fail")
  add("F2", lab, "33150d9d7", "Not run")
}

# F3: sidecar faults; a fault that should be refused and was is an explicit error.
for (rev in REVS) {
  d <- read(if (rev == "001c4d4dd") "F_hdf5_faults.csv" else sprintf("F_hdf5_faults_%s.csv", rev))
  stopifnot(nrow(d) == 12)
  st <- ifelse(
    grepl("^fail", d$result), "Fail",
    ifelse(d$result == "pass" & grepl("^rejected", d$expected), "Explicit error (rejected or refused)",
      ifelse(d$result == "pass", "Pass", NA)
    )
  )
  stopifnot(!anyNA(st))
  lab <- paste0(c(h5 = ".h5", immune_qs2 = ".immune.qs2")[d$sidecar], ": ", sub("level6", "level-6", pretty_id(d$case)))
  for (i in seq_len(nrow(d))) add("F3", lab[i], rev, st[i])
}

m <- do.call(rbind, cells)
m <- m[m$status != "Not run", ]
# Each row shows its result on the last revision it ran on (33150d9d7 where run).
latest <- ave(match(m$revision, REVS), m$experiment, m$row, FUN = max)
m <- m[match(m$revision, REVS) == latest, ]
m$status <- factor(m$status, setdiff(names(STATUS), "Not run"))
# A cell holding two runs is split: restore | abort for C, Visium | PBMC App for E.
m$k <- ave(seq_len(nrow(m)), m$experiment, m$row, FUN = seq_along)
m$x <- 1 + ifelse(m$n_parts == 2, ifelse(m$k == 1, -0.22, 0.22), 0)
m$w <- ifelse(m$n_parts == 2, 0.42, 0.86)
print(table(m$experiment, m$revision))
print(table(m$experiment, m$status))
print(m[m$status == "Fail", c("experiment", "row", "revision", "part")])

matrix_plot <- function(experiments) {
  d <- m[m$experiment %in% experiments, ]
  d$experiment <- factor(d$experiment, experiments)
  d$row <- factor(d$row, rev(unique(d$row[order(d$experiment)])))
  ggplot(d, aes(x, row, fill = status)) +
    geom_tile(aes(width = w), height = 0.8, colour = "grey70", linewidth = LINE, show.legend = TRUE) +
    facet_grid(experiment ~ ., scales = "free_y", space = "free_y") +
    scale_x_continuous(NULL, breaks = 1, labels = "Result", limits = c(0.5, 1.5), expand = c(0, 0), position = "top") +
    scale_y_discrete(NULL) +
    scale_fill_manual(NULL, values = STATUS, limits = levels(m$status), drop = FALSE) +
    guides(fill = guide_legend(nrow = 1, override.aes = list(colour = "grey70"))) +
    theme_bv() +
    theme(
      axis.line = element_blank(),
      axis.ticks = element_blank(),
      strip.text.y = element_text(angle = 0, hjust = 0, face = "bold"),
      panel.spacing.y = unit(1.5, "mm"),
      legend.position = "bottom"
    )
}
s12 <- wrap_plots(matrix_plot(c("A", "C", "C-h5")), matrix_plot(c("E", "F1", "F2", "F3")), nrow = 1) +
  plot_layout(guides = "collect") &
  theme(legend.position = "bottom", legend.margin = margin(0, 0, 0, 0))
save_figure("figS12-builder-validation-overview", s12, 200)

utils::write.csv(
  rbind(shots, data.frame(figure = "figS12-builder-validation-overview", panel = NA, ppi = NA, min_text_pt = NA, below_6pt = FALSE, cut_text = FALSE)[0, ]),
  file.path(out, "qa", "screenshot-qa.csv"),
  row.names = FALSE
)
