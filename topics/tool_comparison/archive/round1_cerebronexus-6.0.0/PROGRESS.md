# Progress

Newest entry last. Dates are local time.

## 2026-10-22

- Earlier attempt abandoned at the owner's request (the `comparison/` folder it expected did not exist); its only product, a clone in WSL, was removed.
- Host chosen: native Windows 11 (i9-12900K, 24 threads, 127.7 GB RAM), R 4.5.0, Chrome 155, Python 3.11 available through uv. No WSL.
- `PROTOCOL.md` written; its SHA-256 is in `results/PROTOCOL.sha256`.
- Status: **waiting for the owner to approve the protocol.** Nothing has been downloaded, installed or run.

### Environment and data (2026-10-22 afternoon)

- `env/py`: Python 3.11.15 (uv), cellxgene 1.3.0, vitessce 3.8.4, anndata 0.12.19, scanpy 1.11.5, playwright 1.64.0, zarr 2.18.7. `env/rlib`: R 4.5.0, Bioconductor 3.22, CerebroNexus 6.0.0 (27ac995e), ShinyCell 2.1.0 (5c61db78cdd6...), iSEE 2.22.0, anndataR 1.0.2, Seurat 5.6.0, scRepertoire 2.6.2. `env/js`: vitessce 3.9.9 bundle. All versions in `results/environment.json`; setup logs in `logs/setup/`.
- Data in `data/` with sizes and SHA-256 in `results/inputs.csv`. E18 is 4,216,018,749 bytes as expected (SHA-256 `255a36ee92de25cb3568faa2c27d31fe6d0db30f285c5c977be8d6245de14044`).
- Inputs in `inputs/`: I2 (500 cells, 365 with CTaa, top clone 11 cells), I4 (2,638 rows, 2,628 unique names), rewritten I1/I3 for anndataR, Task 3 tiers `e18_10000/100000/500000.h5ad` (500k tier 8.3 GB; PCA/UMAP/k-means done once, 12 min; default genes S100a8, Ccl4; manifest in `results/task3_inputs_manifest.json`).
- Protocol body hash verified unchanged after adding Deviations D1-D7 (`results/PROTOCOL_body.sha256`).

### Pilot (discarded from statistics; `logs/pilot/`)

One build and one start per tool on I1 and on the 10,000-cell tier, first-plot timeout shortened to 60 s for the pilot. All six configurations draw the cells (screenshots checked by eye, `logs/pilot/<tool>_<dataset>.png`). The harness measures first plot for cellxgene and Vitessce too. Vitessce's ink fraction is below the 2% rule (see D2).

| Dataset | Config | Build s | Artifact bytes | Ready s | First plot s | Ink | Server peak RSS | Chrome peak RSS |
|---|---|---|---|---|---|---|---|---|
| I1 | cerebronexus_default | 10.4 | 21,551,716 | 5.2 | 2.78 | 0.045 | 471 MB | 866 MB |
| I1 | cerebronexus_h5 | 15.4 | 58,761,909 | 9.3 | 2.92 | 0.045 | 912 MB | 818 MB |
| I1 | shinycell | 11.7 | 17,373,151 | 2.5 | 3.30 | 0.020 | 477 MB | 700 MB |
| I1 | isee | 8.4 | 42,362,171 | 7.6 | 6.83 | 0.058 | 1,233 MB | 774 MB |
| I1 | cellxgene | n/a | 24,653,425 | 9.1 | 1.03 | 0.045 | 298 MB | 674 MB |
| I1 | vitessce | 5.0 | 17,599,272 | 0.6 | not reached at 1% | 0.005 | 30 MB | 821 MB |
| 10k | cerebronexus_default | 12.6 | 44,218,858 | 4.9 | 2.38 | 0.117 | 676 MB | 864 MB |
| 10k | cerebronexus_h5 | 15.3 | 250,888,915 | 7.6 | 2.75 | 0.117 | 960 MB | 819 MB |
| 10k | shinycell | 26.5 | 95,481,723 | 2.3 | 3.59 | 0.081 | 481 MB | 697 MB |
| 10k | isee | 11.6 | 251,084,315 | 8.7 | 8.96 | 0.126 | 1,635 MB | 758 MB |
| 10k | cellxgene | n/a | 168,376,200 | 8.6 | 0.88 | 0.088 | 433 MB | 676 MB |
| 10k | vitessce | 6.0 | 87,169,737 | 0.6 | 2.00 | 0.017 | 31 MB | 843 MB |

Observations to keep in mind: Vitessce's server is a static file server, so its server RSS is tiny and the data work happens in Chrome (hence the extra Chrome column). cellxgene, CerebroNexus and iSEE load their data in the server before answering.

### Still to do (needs the owner's go-ahead for the measured part)

1. Task 1 scripts and runs (I1-I4, all tools), 2. Task 2 export-route discovery and runs, 3. Task 3 orchestrator and the measured runs (about 6 configs x 3 tiers x 3 builds x 3 starts), 4. summary tables.

## 2026-10-22 evening: Task 1, Task 2 done; Task 3 started

- Owner approved the protocol and D1-D7. Task 1 (`results/task1_*.csv|json`, raw rows in `results/task1_raw/`) and Task 2 (`results/task2_*.csv`, `results/task2_summary.csv`, raw in `results/task2_raw/`) were run on this host; D8-D10 added to the protocol (body hash unchanged).
- Task 1 highlights: duplicated names in I4 are rejected by CerebroNexus and cellxgene, kept silently by ShinyCell, iSEE and Vitessce. anndataR refuses the two legacy `.h5ad` files; ShinyCell's default route fails on the anndataR `SingleCellExperiment` (LinearEmbeddingMatrix) and, for a Seurat object without VariableFeatures, with "argument is of length zero".
- Task 2 highlights: region selection reaches J = 0.97-0.98 (S1) with the margin-expanded hull in CerebroNexus, cellxgene, Vitessce and iSEE (lasso); attribute selection reaches J = 1.0 in cellxgene and Vitessce; ShinyCell has no export route; iSEE's table filter is ignored by its export; CerebroNexus has no attribute selection.
- Task 3 started with tier 10,000 (`scripts/task3.py run 10000`, log `logs/task3/run_10000.log`); no other heavy job runs while it measures.

## 2026-10-22 night: Task 3 finished, results written

- Task 3 measured runs finished: 6 configs x 3 tiers x 3 builds x 3 starts = 54 builds (the 9 cellxgene builds are `n/a`) and 162 starts, every build and every start `ok` (no timeout, error or out-of-memory). Raw rows `results/task3_builds.csv`, `results/task3_starts.csv`; tables `results/summary_task3.csv|md`; one page for all three tasks `results/SUMMARY.md`.
- The run needed three restarts (Deviations D11-D13): ink rule (saturation 0.1), cellxgene upgrade check (GitHub rate limit), and one invalid unit caused by my cleanup. Every superseded row is kept in `results/superseded_*` and `logs/superseded_v1/`; none is in a table.
- Largest values at 500,000 cells: build CerebroNexus h5 1,048 s and ShinyCell 1,016 s, iSEE first plot 47 s, iSEE server peak RSS 14.6 GB, CerebroNexus default 12.1 GB, cellxgene 8.0 GB; Vitessce server 0.03 GB (its data work happens in Chrome, 1.4 GB).
- Not committed. Untracked deliverables: `PROTOCOL.md`, `PROGRESS.md`, `scripts/`, `results/`, `logs/` (about 64 MB, 1,200 files, of which 36 MB screenshots in `logs/screens` and 14 MB superseded runs).

## 2026-10-23: CerebroNexus attribute route of Task 2

- The first Task 2 run said CerebroNexus has no attribute route; that was wrong, only the legend had been tried. The Group filters (Projection > Settings) make filtered cells unselectable, so filter plus lasso selects by attribute (Deviation D14).
- Run with `scripts/task2/t2_cerebronexus.py <set> 3 attribute`: S1 selects exactly the 342 B cells, Jaccard 1.0 (three runs). S2: the Group filters of the I2 CRB list only `seurat_clusters`, so the route is `route not found` for `CTaa`; the CRB was not rebuilt.
- `results/task2_cerebronexus.csv`, `results/task2_summary.csv` and `results/SUMMARY.md` regenerated; the previous summaries are in `results/superseded_task2_attribute/`. The region rows did not change.

## 2026-10-23: folders reorganised

- Folder layout simplified (path map in Deviation D15 of `PROTOCOL.md`; its body hash is unchanged): `results/` now holds the summaries plus `task1/`, `task2/`, `task3/` (per-run files and per-tool tables), `superseded/` and `figures/` (the figure, `qa/`, `captures/`); the downloads, derived inputs and tool builds are `data/raw/`, `data/inputs/` and `data/builds/` (was `artifacts/`); `scripts/` is split into `run/`, `setup/`, `report/`.
- Checked after the move: every Python script compiles, the dataset paths used by the harness and the R/Python drivers exist, `capture_figures.py --list`, `task3/run.py status` and the four report scripts run from the new places, and re-running them wrote byte-identical tables (only the header text of `results/SUMMARY.md` changed). The measurement drivers (harness, task1 and task2 scripts, tool builders) were not run again.
- `logs/` renamed `results/evidence/`. The relative `logs/...` paths inside the result tables (469 occurrences in 54 files) were rewritten to `results/evidence/...` with a one-off script that also checked every rewritten path exists and that undoing the replacement gives the original text; absolute Windows paths and the archived `results/superseded/` were left as recorded. Re-running the report scripts afterwards wrote byte-identical tables. `logs/superseded_v1/` is now `results/superseded/v1/logs/`; the stray probe log is `results/evidence/task2/cn_attribute_probe.log`.
- Deleted: `TASK2_RERUN.md` (finished, see D14) and the unreferenced `probe_page.py`, `probe_page2.py`, `killport.sh`.
