# CerebroNexus paper code

Code, result tables and figures for the CerebroNexus manuscript. The package itself lives in [CerebroNexus](https://github.com/mihem/CerebroNexus).

## Quick start

```bash
bash run.sh install    # install the R packages into your own library
bash run.sh            # redraw all figures with your R
bash run.sh --nix      # or redraw them in the pinned Nix environment
```

One topic only: `bash run.sh expression_backends`. All options: `bash run.sh --help`.

## Layout

```
topics/
  expression-backends/   H5 / BPCells / embedded storage: benchmark + figures
  viewer-performance/    million-cell viewer: figures only (benchmark scripts live in CerebroNexus)
nix/                     pinned environments (figures, benchmark)
```

Each topic holds `_targets.R` (figure pipeline), `R/`, `data/` (tables the figures use), `figures/`, and optionally `benchmark/` and `tests/`.

## Run the benchmark

Only `expression-backends` has a benchmark here (`bash run.sh benchmark` lists them).

CerebroNexus is installed from the commit in `topics/expression-backends/cerebronexus.lock` (GitHub `duocang/CerebroNexus`); no local copy is needed.

```bash
bash run.sh install benchmark                      # once; includes BPCells
bash run.sh benchmark expression-backends quick    # small correctness check (first run downloads ~18 GB of data)
bash run.sh benchmark expression-backends scale    # full study: Linux, lots of RAM and disk
bash run.sh benchmark expression-backends status   # running? where is the log?
```

To check the whole pipeline in about a minute, run `quick` on a small synthetic matrix instead of the published datasets:

```bash
Rscript topics/expression-backends/benchmark/scripts/make_smoke_source.R /tmp/smoke.h5
BENCH_SMOKE_SOURCE=/tmp/smoke.h5 bash run.sh benchmark expression-backends quick
```

Results go to `topics/expression-backends/results/` (not tracked). To test a local CerebroNexus checkout instead: `CEREBRONEXUS_SRC=/path/to/CerebroNexus bash run.sh benchmark expression-backends quick`. This repository must have at least one commit and no uncommitted changes (the run records its commit and the CerebroNexus commit). Add `--nix` (`bash run.sh --nix benchmark expression-backends quick`) to use the pinned Nix environment. Details: [benchmark README](topics/expression-backends/benchmark/README.md).

## Add a topic

Create `topics/<name>/_targets.R` and add `<name>` to `_targets.yaml`.

## Notes

- Figures need Arial; set `ARIAL_DIR` if it is not found. GitHub Actions redraws all figures on every push.
- macOS: use `bash run.sh` (your R) for the PDFs; with `--nix` the font audit fails because Nix's cairo writes spaces as Type 3 fonts.
- To rebuild the Nix files, run `nix-shell -p rPackages.rix R --run "Rscript nix/<env>/create_env.R"`; on macOS run `export R_LIBS_USER=/nonexistent` first.
