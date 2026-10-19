# Regenerate nix/figures/default.nix, the small environment that redraws the
# figures (locally and in GitHub Actions). Run from the repository root:
#   nix-shell -p rPackages.rix R --run "Rscript nix/figures/create_env.R"
# No browser, BPCells or CerebroNexus here, so it also builds on aarch64-darwin.

library(rix)

source("nix/latest_date.R")
latest_date <- osmzhlab_latest_date()

rix(
  date = latest_date,
  r_pkgs = c(
    "ggplot2",
    "patchwork",
    "scales",
    "systemfonts",
    "targets",
    "yaml"
  ),
  system_pkgs = c(
    "fontconfig",
    "poppler-utils" # pdffonts/pdfinfo for the publication-figure audit
  ),
  ide = "none",
  project_path = "nix/figures",
  overwrite = TRUE
)
