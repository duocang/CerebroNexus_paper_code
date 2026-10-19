# Regenerate nix/benchmark/default.nix, the environment the expression-backend
# benchmark runs in. Run from the repository root:
#   nix-shell -p rPackages.rix R --run "Rscript nix/benchmark/create_env.R"
#
# The benchmark compares H5, BPCells and embedded storage, so BPCells is always
# part of this environment. CerebroNexus itself is not: the runner installs the
# checkout under test (CEREBRONEXUS_SRC) into a scratch library, so the R
# packages below cover CerebroNexus' Imports plus what the harness needs.

library(rix)

source("nix/latest_date.R")
latest_date <- osmzhlab_latest_date()
bpcells_sha <- osmzhlab_bpcells_rev(latest_date)

rix(
  date = latest_date,
  r_pkgs = c(
    # CerebroNexus Imports (keep in sync with its DESCRIPTION)
    "base64enc",
    "biomaRt",
    "colourpicker",
    "dplyr",
    "DT",
    "fs",
    "future.apply",
    "ggplot2",
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
    "scales",
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
    # harness tests
    "callr",
    "testthat",
    "withr"
  ),
  system_pkgs = c("git"),
  git_pkgs = list(
    # BPCells is not on CRAN, install from GitHub
    list(
      package_name = "BPCells",
      repo_url = "https://github.com/bnprks/BPCells/r",
      commit = bpcells_sha
    )
  ),
  ide = "none",
  project_path = "nix/benchmark",
  overwrite = TRUE
)

nix_file <- "nix/benchmark/default.nix"
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

# --- HDF5 with ROS3 on Linux, for the remote-reader measurements ---
marker <- grep("^let$", nix_lines)
inputs <- grep("buildInputs = \\[ BPCells rpkgs system_packages \\];", nix_lines)
if (length(marker) != 1L || length(inputs) != 1L) {
  stop("Unexpected rix output; cannot apply benchmark environment settings")
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
