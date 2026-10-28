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

`tar_make()` redraws the figures of `expression_backends`, `viewer_performance` and `tool_comparison` from their committed result tables. The figures of `interface_figures` need a CerebroNexus checkout (`topics/interface_figures/run.sh`); the Builder topics have no figures in the pipeline. Figures are written to `topics/<topic>/figures/`. GitHub Actions redraws them on every push and uploads them as the `figures` artifact.

## Layout

Everything for one topic lives in `topics/<topic>/`; only the pipeline and the environment are shared.

```
_targets.R      the pipeline: sources topics/*/functions.R and topics/*/targets.R
default.nix     the one Nix environment (regenerate with generate_env.R)
install.R       installs the R packages without Nix
topics/
  expression_backends/   H5 / BPCells / embedded storage benchmark and its figures
  viewer_performance/    Viewer page, startup, renderer and smoke benchmarks, Ren backend figure
  builder/               Builder builds from a SpatialData zip and a CITE-seq MuData file
  builder_validation/    headless validation of the Builder on real data, experiments A-F (macOS; not in targets)
  interface_figures/     scripted Viewer/Builder captures and Figures 1-7, S1-S2 (run.sh; not in targets)
  tool_comparison/       same-task comparison with ShinyCell, iSEE, cellxgene and Vitessce (measured on Windows and one Mac; only its figures are in targets)
```

A topic folder holds what it needs of:

```
README.md       what the topic measures and how to run it
targets.R       its target list (targets_<topic>), combined in _targets.R
functions.R     helpers for those targets
run.sh          entry point for measurements that run outside targets
scripts/        benchmark harness and plotting scripts
data/           result tables the figures are drawn from
figures/        the figures
tests/          tests of the harness
```

Run all tests from the repository root, inside the Nix environment so that the package versions match the pinned ones:

```bash
nix-shell --run "Rscript -e 'for (d in Sys.glob(\"topics/*/tests\")) testthat::test_dir(d)'"
```

With your own R the `expression_backends` tests that write 10x HDF5 through BPCells (`test-bench-full-source.R`) may fail with a HighFive `Failed to create the dataset` error, depending on the installed BPCells version; the other tests do not depend on it.

## Run the benchmark

The H5 / BPCells / embedded storage benchmark needs Linux, lots of RAM and disk, and downloads about 18 GB of data on first use. It installs CerebroNexus from the commit in `topics/expression_backends/cerebronexus.lock` and runs in the Nix environment (`BENCH_NIX=0` uses your own R after `Rscript install.R benchmark`).

```bash
bash topics/expression_backends/run.sh quick    # small correctness check
bash topics/expression_backends/run.sh scale    # full study
bash topics/expression_backends/run.sh status   # progress and log
```

Results go to `topics/expression_backends/results/` (not tracked); copy a published run to `topics/expression_backends/data/scale/` and point `CURRENT` at it to draw figures from it. Details: [topics/expression_backends/README.md](topics/expression_backends/README.md).

## Viewer benchmarks

Page speed, startup, renderer and smoke checks of the CerebroNexus Viewer, plus the Ren backend figure, are in `topics/viewer_performance/`. They run against a CerebroNexus checkout; see [topics/viewer_performance/README.md](topics/viewer_performance/README.md).

## Builder builds

`topics/builder/` rebuilds the two multi-format Builder examples cited in the manuscript, a Visium SpatialData sample store packed as a `.zip` (6,484 spots, two sections) and the minipbcite CITE-seq MuData file (411 cells, 29 antibody features), with CerebroNexus 6.0.0. It records the input URLs and SHA-256 checksums, the output CRB checksums and counts, and the console log with `sessionInfo()`; see [topics/builder/README.md](topics/builder/README.md).

```bash
Rscript --vanilla topics/builder/build_crbs.R <library with CerebroNexus 6.0.0> <folder with the two inputs> <output folder>
```

## Builder validation

`topics/builder_validation/` tests the CerebroNexus Builder headlessly on real inputs in six experiments (malformed inputs, end to end with the exported Viewer App, publication faults, spatial image transforms, authorization and data leakage, cell selection and sidecars). It runs against a CerebroNexus checkout installed into `env/rlib`; the tables, logs and figures it produced are committed under `results/` and `figures/`. See [topics/builder_validation/README.md](topics/builder_validation/README.md) and `THREAT_MODEL.md`.

## Tool comparison

`topics/tool_comparison/` compares CerebroNexus 6.0.0 with ShinyCell, iSEE, cellxgene and Vitessce on the same tasks (import and capability recognition, selection retrieval, and build and start cost at 10k / 100k / 500k cells), run on one native Windows host under a pre-registered protocol. Results are in [topics/tool_comparison/results/SUMMARY.md](topics/tool_comparison/results/SUMMARY.md); see [topics/tool_comparison/README.md](topics/tool_comparison/README.md).

## Notes

- Figures need Arial; set `ARIAL_DIR` if it is not found.
- Redrawn PDFs differ from the committed ones only by their creation date; commit them when a figure really changed.
- macOS: use your own R for the PDFs; in Nix the font audit fails because Nix's cairo writes spaces as Type 3 fonts.
- To update `default.nix`: `nix-shell -p rPackages.rix R --run "Rscript generate_env.R"` (on macOS run `export R_LIBS_USER=/nonexistent` first).
