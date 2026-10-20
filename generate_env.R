# Regenerate default.nix, the one Nix environment for this repository: the
# figure pipeline (targets, ggplot2, patchwork, poppler) and the
# expression-backend benchmark (CerebroNexus' Imports, the storage backends
# including BPCells, and the harness tests). CerebroNexus itself is not in it:
# the benchmark installs the commit in benchmark/cerebronexus.lock into a
# scratch library. Run from the repository root:
#   nix-shell -p rPackages.rix R --run "Rscript generate_env.R"
# On macOS run `export R_LIBS_USER=/nonexistent` first.

library(rix)

# Latest nixpkgs date published by the osmzhlab Attic cache, so the environment
# uses a snapshot with binary substitutes, and the BPCells revision that cache
# built for that date.
osmzhlab_reports <- "https://raw.githubusercontent.com/mihem/attic/main/reports"

readme <- readLines(file.path(osmzhlab_reports, "README.md"), warn = FALSE)
dates <- sort(unique(unlist(regmatches(readme, gregexpr("[0-9]{4}-[0-9]{2}-[0-9]{2}", readme)))))
latest_date <- tail(dates, 1)
if (length(latest_date) == 0 || is.na(latest_date)) stop("Could not determine latest osmzhlab cache date")
cat("Using latest_date:", latest_date, "\n")

pins <- readLines(sprintf("%s/%s/pins.json", osmzhlab_reports, latest_date), warn = FALSE)
pin_value <- function(name) {
  line <- grep(sprintf('"%s"', name), pins, value = TRUE)
  sub(sprintf('.*"%s"[[:space:]]*:[[:space:]]*"([^"]+)".*', name), "\\1", line)
}
if (!identical(pin_value("r_nixpkgs_date"), latest_date)) {
  stop("pins.json date does not match selected osmzhlab cache date")
}
bpcells_sha <- pin_value("bp_cells_rev")
if (length(bpcells_sha) != 1 || !grepl("^[0-9a-f]{40}$", bpcells_sha)) {
  stop("Could not determine BPCells revision from osmzhlab Attic pins.json")
}
cat("Using BPCells revision:", bpcells_sha, "\n")

rix(
  date = latest_date,
  r_pkgs = c(
    # figure pipeline
    "ggplot2",
    "patchwork",
    "scales",
    "systemfonts",
    "targets",
    # CerebroNexus Imports (keep in sync with its DESCRIPTION)
    "base64enc",
    "biomaRt",
    "colourpicker",
    "dplyr",
    "DT",
    "fs",
    "future.apply",
    "glue",
    "GSVA",
    "htmltools",
    "htmlwidgets",
    "httr",
    "igraph",
    "jsonlite",
    "later",
    "Matrix",
    "mirai",
    "msigdbr",
    "pbapply",
    "plotly",
    "qvalue",
    "qs2",
    "R6",
    "rlang",
    "scRepertoire",
    "shiny",
    "shinycssloaders",
    "shinydashboard",
    "shinyjs",
    "shinyWidgets",
    "stringdist",
    "stringr",
    "tibble",
    "tidyr",
    "tidyselect",
    "visNetwork",
    # storage backends and readers under test
    "DelayedArray",
    "HDF5Array",
    "rhdf5",
    "Seurat",
    "SeuratObject",
    # benchmark harness tests
    "callr",
    "testthat",
    "withr"
  ),
  system_pkgs = c(
    "fontconfig",
    "git",
    "poppler-utils" # pdffonts/pdfinfo for the publication-figure audit
  ),
  git_pkgs = list(
    # BPCells is not on CRAN, install from GitHub
    list(
      package_name = "BPCells",
      repo_url = "https://github.com/bnprks/BPCells/r",
      commit = bpcells_sha
    )
  ),
  ide = "none",
  project_path = ".",
  overwrite = TRUE
)

nix_file <- "default.nix"
nix_lines <- readLines(nix_file)

# --- BPCells block fix: the R package lives in the r/ subdirectory ---
bp_start <- grep("BPCells = \\(pkgs.rPackages.buildRPackage \\{", nix_lines)
bp_end <- grep("^\\s*\\}\\);", nix_lines)
bp_end <- bp_end[bp_end > bp_start][1]
if (length(bp_start) != 1 || is.na(bp_end)) stop("Unexpected rix output; BPCells block not found")
block <- nix_lines[bp_start:bp_end]
field <- function(name) sub(sprintf(".*%s = \"(.*)\";.*", name), "\\1", grep(sprintf("%s = ", name), block, value = TRUE, fixed = TRUE))
propagated <- grep("propagatedBuildInputs = ", nix_lines[bp_start:bp_end], fixed = TRUE) + bp_start - 1
nix_lines <- c(
  nix_lines[1:(bp_start - 1)],
  "    BPCells-src = pkgs.fetchgit {",
  sprintf("      url = \"%s\";", sub("/r$", "", field("url"))),
  sprintf("      rev = \"%s\";", field("rev")),
  sprintf("      sha256 = \"%s\";", field("sha256")),
  "    };",
  "",
  "    BPCells = (pkgs.rPackages.buildRPackage {",
  "      pname = \"BPCells\";",
  "      name = \"BPCells\";",
  "      src = \"${BPCells-src}/r\";",
  "      postPatch = \"patchShebangs configure\";",
  "      nativeBuildInputs = [ pkgs.pkg-config ];",
  "      buildInputs = [ pkgs.hdf5 ];",
  nix_lines[propagated:bp_end],
  nix_lines[(bp_end + 1):length(nix_lines)]
)

# --- HDF5 with ROS3 on Linux, for the benchmark's remote-reader measurements ---
marker <- grep("^let$", nix_lines)
inputs <- grep("buildInputs = \\[ BPCells rpkgs system_packages \\];", nix_lines)
if (length(marker) != 1L || length(inputs) != 1L) {
  stop("Unexpected rix output; cannot apply the HDF5 ROS3 settings")
}
nix_lines[inputs] <- paste(
  "    buildInputs = [ BPCells hdf5Ros3 ] ++ rpkgs ++ system_packages;",
  "    shellHook = pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''",
  "      export LD_LIBRARY_PATH=\"${hdf5Ros3}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}\"",
  "    '';", sep = "\n"
)
nix_lines <- append(nix_lines, c(
  "  hdf5Ros3 = if pkgs.stdenv.hostPlatform.isLinux then",
  "    pkgs.hdf5.overrideAttrs (old: {",
  "      buildInputs = (old.buildInputs or []) ++ [ pkgs.curl.dev ];",
  "      cmakeFlags = (old.cmakeFlags or []) ++ [ \"-DHDF5_ENABLE_ROS3_VFD=ON\" ];",
  "    }) else pkgs.hdf5;"
), after = marker + 1L)
writeLines(nix_lines, nix_file)
cat("Updated", nix_file, "\n")
