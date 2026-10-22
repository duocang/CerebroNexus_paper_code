# Check the drawn figures against the Genome Biology rules.
#
#   Rscript scripts/check_figures.R <figures-dir>
#
# Reads the PDFs (page size, embedded fonts, file size), their SVG twins in
# qa/ (every font size and stroke width, in pt) and qa/screenshot-qa.csv (the
# smallest interface text inside each screenshot crop at print size). Writes
# qa/figure-check.csv and stops if a rule fails.

args <- commandArgs(trailingOnly = TRUE)
dir <- args[[1]]
pdfs <- sort(Sys.glob(file.path(dir, "*.pdf")))
rows <- lapply(pdfs, function(pdf) {
  name <- sub("\\.pdf$", "", basename(pdf))
  info <- system2("pdfinfo", shQuote(pdf), stdout = TRUE)
  size <- as.numeric(regmatches(info, regexpr("[0-9.]+ x [0-9.]+", info))[[1]] |> strsplit(" x ") |> unlist())
  size_mm <- size / 72 * 25.4
  fonts <- system2("pdffonts", shQuote(pdf), stdout = TRUE)[-(1:2)]
  fields <- strsplit(trimws(fonts), "\\s+")
  embedded <- vapply(fields, function(f) f[length(f) - 4], "")
  svg <- paste(readLines(file.path(dir, "qa", paste0(name, ".svg")), warn = FALSE), collapse = "\n")
  font_pt <- as.numeric(sub("font-size: *([0-9.]+)px.*", "\\1", regmatches(svg, gregexpr("font-size: *[0-9.]+px", svg))[[1]]))
  stroke_pt <- as.numeric(sub("stroke-width: *([0-9.]+).*", "\\1", regmatches(svg, gregexpr("stroke-width: *[0-9.]+", svg))[[1]]))
  stroke_pt <- stroke_pt[stroke_pt > 0]
  data.frame(
    figure = name,
    width_mm = round(size_mm[1], 1), height_mm = round(size_mm[2], 1),
    file_mb = round(file.size(pdf) / 1e6, 2),
    fonts = paste(unique(vapply(fields, `[`, "", 1)), collapse = " "),
    # A figure that is only a screenshot has no fonts at all.
    all_fonts_embedded = all(embedded == "yes"),
    text_sizes_pt = paste(sort(unique(round(font_pt, 2))), collapse = " "),
    min_text_pt = if (length(font_pt)) min(font_pt) else NA_real_,
    min_stroke_pt = if (length(stroke_pt)) round(min(stroke_pt), 3) else NA_real_
  )
})
check <- do.call(rbind, rows)
write.csv(check, file.path(dir, "qa", "figure-check.csv"), row.names = FALSE)
print(check)
shots <- read.csv(file.path(dir, "qa", "screenshot-qa.csv"))
print(shots[, c("figure", "panel", "ppi", "min_text_pt", "below_6pt", "cut_text")])
problems <- c(
  # cairo_pdf rounds the page to whole points: 170 mm = 481.9 pt -> 481 pt.
  check$figure[abs(check$width_mm - 170) > 0.5],
  check$figure[check$height_mm > 225],
  check$figure[check$file_mb > 10],
  check$figure[!check$all_fonts_embedded],
  check$figure[!is.na(check$min_text_pt) & check$min_text_pt < 6],
  check$figure[!is.na(check$min_stroke_pt) & check$min_stroke_pt < 0.25],
  paste(shots$figure, shots$panel)[shots$ppi < 300 | (!is.na(shots$min_text_pt) & shots$min_text_pt < 6)]
)
if (length(problems)) stop("Rule check failed: ", paste(unique(problems), collapse = ", "), call. = FALSE)
message("All figures pass.")
