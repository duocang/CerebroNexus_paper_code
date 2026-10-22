# Viewer benchmarks

Measure page speed or check that a CRB opens and responds correctly. These scripts moved here from CerebroNexus (`tests/bench/`, later `tests/benchmarks/viewer/`).

They measure a CerebroNexus checkout. Run them from the root of that checkout in Linux or WSL, with this repository cloned beside it, or set `CEREBRO_REPO` to the checkout. You need the CerebroNexus R environment, Chrome/Chromium and the renderer required by the data (WebGPU by default for the million-cell page benchmark). The commands below assume:

```bash
cd CerebroNexus
nix-shell default.nix -A shell
```

The data preparation used by the demo (`prepare_viewer_1m_data.R`, `prepare_viewer_ren_data.R`, `prepare_viewer_pack.R`) stays in CerebroNexus under `tests/demo/`.

## Choose a command

```bash
# Quick page comparison: pre-PR0, fixed PR5 and committed HEAD.
bash ../CerebroNexus_paper_code/topics/viewer_performance/run.sh pages --artifact /data/brain-pages.crb

# Five rounds for a more complete comparison.
bash ../CerebroNexus_paper_code/topics/viewer_performance/run.sh pages --artifact /data/brain-pages.crb --profile publication

# Compare PR5 and HEAD, each using its own Viewer Pack.
bash ../CerebroNexus_paper_code/topics/viewer_performance/run.sh release --artifact /data/brain-pages.crb --rounds 3

# Check loading, rendering, selection, zoom and gene switching.
bash ../CerebroNexus_paper_code/topics/viewer_performance/run.sh smoke /data/brain.crb
```

Page comparisons use the million-cell fixture and compare committed revisions in separate clean worktrees. Uncommitted changes are not measured. Use `--baseline`, `--reference` and `--candidate` to select other revisions. For example:

The default pre-PR0 and PR5 revisions are fixed historical reference points, not the current `master`. Select revisions explicitly when comparing a new release.

```bash
bash ../CerebroNexus_paper_code/topics/viewer_performance/run.sh pages --artifact /data/brain-pages.crb --candidate master --pages overview,trajectory
bash ../CerebroNexus_paper_code/topics/viewer_performance/run.sh pages --help
```

## Prepare the page fixture

The official mouse-brain CRB lacks repertoire, HLA and trajectory data. Create a test fixture beside it so both files can use the same expression sidecar:

```bash
Rscript ../CerebroNexus_paper_code/topics/viewer_performance/scripts/prepare_viewer_1m_pages.R . /data/brain.crb /data/brain-pages.crb
```

The added data are only for testing page behavior, not biological analysis. Use [smoke checks](scripts/smoke/README.md) for other CRB files.

## Existing artifact diagnostics

The general H5 / BPCells / embedded comparison is in [`topics/expression_backends/`](../expression_backends/README.md). Two older diagnostics remain useful for specific questions: `scripts/benchmark_ren_expression_backends.R` compares reads from two already prepared Ren CRBs, without rebuilding them; `scripts/benchmark_bpcells_storage_order.R` compares column and row storage on the matching million-cell fixture. For example, from the same Nix shell:

```bash
Rscript ../CerebroNexus_paper_code/topics/viewer_performance/scripts/benchmark_ren_expression_backends.R /data/ren-bpcells.crb /data/ren-h5.crb /tmp/ren-backends 3
Rscript ../CerebroNexus_paper_code/topics/viewer_performance/scripts/benchmark_bpcells_storage_order.R /data/brain-col.crb /data/brain-row.crb /tmp/storage-order.tsv 3
```

## Narrow diagnostics

These scripts answer one question each. They are run by hand when that part of the Viewer changes; none of them runs in CI.

- **Server hot paths and Linked bundle, two revisions.** `scripts/run_viewer_1m_benchmark.sh BEFORE AFTER [OUTPUT_DIR]` checks out both revisions in temporary worktrees, prepares the million-cell CRB with CerebroNexus's `tests/demo/prepare_viewer_1m_data.R`, and runs `viewer_1m_hot_paths.R` (filtering, cell indexing and expression reads, with equality checks) and `viewer_1m_bundle.R` (Linked bundle build, JSON encoding and size). It produced `topics/viewer_performance/data/million_cell_backend_hot_paths.tsv` and `million_cell_backend_bundle.tsv`. `REPEATS` sets the repetitions; `CEREBRO_LARGE_CACHE` reuses prepared data.
- **Startup.** `scripts/benchmark_million_cell_startup.R LABEL=CRB [LABEL=CRB ...]` starts the app for each CRB, opens it in headless Chrome and times three steps: the server is ready, the page has loaded, and Data info reports all one million cells. `CEREBRO_STARTUP_REPEATS` sets the repetitions (default 3). It produced the `million_cell_startup_*.csv` files in [`topics/viewer_performance/data/`](data).
- **Renderer.** `scripts/benchmark_million_cell_renderer.R [points] [repeats] [output.csv]` draws synthetic points (one million by default) in the small app in `scripts/million_cell_renderer_app/` with headless Chrome and times renderer setup, building the colour buffers and drawing, on the real renderer code in `inst/`. Set `CEREBRO_RENDERER_BACKEND=webgl2` to force the WebGL2 fallback instead of WebGPU.

```bash
REPEATS=3 bash ../CerebroNexus_paper_code/topics/viewer_performance/scripts/run_viewer_1m_benchmark.sh 27303f21 HEAD
Rscript ../CerebroNexus_paper_code/topics/viewer_performance/scripts/benchmark_million_cell_startup.R before=/data/old.crb after=/data/new.crb
Rscript ../CerebroNexus_paper_code/topics/viewer_performance/scripts/benchmark_million_cell_renderer.R 1000000 15 /tmp/renderer.csv
```

## Results

Page comparisons write to `CerebroNexus-benchmarks/` beside the CerebroNexus checkout. Start with `page-summary.md`; `raw.tsv` contains individual observations and `run-config.tsv` records the revisions. Failed runs keep their measurements and return a nonzero exit code.

Page timing starts after the dataset has loaded and ends when the correct primary result is drawn. First visits must be under 2 seconds, or 3 seconds for HLA and Trajectory; repeat visits must be under 500 ms. `settled_ms` is an additional diagnostic, not the page-speed score. Run `--mode memory` separately: memory sampling changes timing, so those times are excluded from performance comparisons.

[Saved Viewer results](data) are historical. Check each report's revision and timing definition before comparing numbers. The detailed event checks are implemented in `scripts/viewer_1m_page_protocol.R`; the other scripts are listed above.

The older three-launch, 11-page figure is drawn by the `viewer_performance` targets (`topics/viewer_performance/targets.R`). Historical reports and backend recommendations remain evidence from their recorded revisions, not conclusions from the current benchmark.

## Load mode

The browser benchmarks (`benchmark_viewer_1m_pages.R`, `benchmark_million_cell_viewer.R`, `benchmark_ren_linked_transport.R`) share `scripts/lib/viewer_launch.R`. By default (`VIEWER_BENCH_LOAD=installed`) each candidate is installed into a temporary library with `R CMD INSTALL` and launched with `library(CerebroNexus)`, as deployments run it. `VIEWER_BENCH_LOAD=load_all` uses `devtools::load_all()` instead, which also attaches every DESCRIPTION Imports package; the much larger R heap makes each full garbage collection take seconds and shifts pauses onto whichever page step allocates next, so use it only to profile an uninstalled source tree. The page benchmark manifest records the mode as `viewer_load_mode`.

## Ren backend figure

`scripts/plot_ren_backend_acceptance.R [input.tsv] [output.png]` redraws the 2026-10-08 Ren v2 BPCells / HDF5 figure shown in the CerebroNexus "Large-dataset benchmarks" article from `topics/viewer_performance/data/ren-backends-20261008.tsv`. It reads only that table:

```bash
Rscript topics/viewer_performance/scripts/plot_ren_backend_acceptance.R
```

## Tests

`tests/test-viewer-*.R` and `tests/test-ren-backend-benchmark.R` cover these scripts. The Ren worker test loads a CerebroNexus checkout (sibling `../CerebroNexus` or `CEREBRO_REPO`); browser tests need `NOT_CRAN=true` and Chrome:

```bash
cd tests && NOT_CRAN=true Rscript -e 'testthat::test_dir(".", filter = "viewer|ren-backend")'
```
