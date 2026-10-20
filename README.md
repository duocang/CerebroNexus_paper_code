# CerebroNexus paper code

Code, result tables and figures for the CerebroNexus manuscript. The package itself lives in [CerebroNexus](https://github.com/mihem/CerebroNexus).

## Redraw the figures

With Nix (the pinned environment in `default.nix`):

```bash
nix-shell --run "Rscript -e 'targets::tar_make()'"
```

With your own R:

```bash
Rscript install.R
Rscript -e 'targets::tar_make()'
```

Figures are written to `figures/<topic>/`. GitHub Actions redraws them on every push and uploads them as the `figures` artifact.

## Layout

```
_targets.R      the pipeline: sources functions/ and combines the target lists in scripts/
functions/      helper functions, one file per topic
scripts/        one target list per topic (expression_backends.R, viewer_performance.R)
data/           result tables the figures are drawn from
figures/        the figures
benchmark/      the expression-backend benchmark (runs outside targets)
viewer/         Viewer page, startup, renderer and smoke benchmarks (run outside targets)
tests/          tests of the benchmark harnesses
generate_env.R  regenerates default.nix with rix
install.R       installs the R packages without Nix
```

## Run the benchmark

The H5 / BPCells / embedded storage benchmark needs Linux, lots of RAM and disk, and downloads about 18 GB of data on first use. It installs CerebroNexus from the commit in `benchmark/cerebronexus.lock` and runs in the Nix environment (`BENCH_NIX=0` uses your own R after `Rscript install.R benchmark`).

```bash
bash benchmark/run.sh quick    # small correctness check
bash benchmark/run.sh scale    # full study
bash benchmark/run.sh status   # progress and log
```

Results go to `benchmark/results/` (not tracked); copy a published run to `data/expression_backends/scale/` and point `CURRENT` at it to draw figures from it. Details: [benchmark/README.md](benchmark/README.md). Tests: `cd tests && Rscript -e 'testthat::test_dir(".")'`.

## Viewer benchmarks

Page speed, startup, renderer and smoke checks of the CerebroNexus Viewer, plus the Ren backend figure, are in `viewer/`. They run against a CerebroNexus checkout; see [viewer/README.md](viewer/README.md).

## Notes

- Figures need Arial; set `ARIAL_DIR` if it is not found.
- Redrawn PDFs differ from the committed ones only by their creation date; commit them when a figure really changed.
- macOS: use your own R for the PDFs; in Nix the font audit fails because Nix's cairo writes spaces as Type 3 fonts.
- To update `default.nix`: `nix-shell -p rPackages.rix R --run "Rscript generate_env.R"` (on macOS run `export R_LIBS_USER=/nonexistent` first).
