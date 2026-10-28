# Tool comparison

Same-task comparison of five single-cell viewers on one native Windows 11 host (i9-12900K, 127.7 GB RAM, RTX 4060, Chrome 155 with a hardware WebGL renderer): CerebroNexus (default and H5 backend), ShinyCell, iSEE, cellxgene 1.3.0 and Vitessce 3.8.4 / 3.9.9. The current run is round 2; the tools are pinned in [PROTOCOL.md](PROTOCOL.md), the diary is [PROGRESS.md](PROGRESS.md).

- CerebroNexus: commit `2786ff6d09a53f54e25bb1affbc6ed58aac70b43` of the branch `tmp/应急` (version 6.0.0, the Builder merged into `perf/viewer-page-open`). R 4.6.1 with Bioconductor 3.23 (iSEE 2.24.0).
- Task 1: import and capability recognition on I1-I4 (pbmc3k, scRepertoire example with TCR, Visium H&E, pbmc3k with duplicated cell names).
- Task 2: selection retrieval for S1 and S2 by region and attribute routes, Jaccard against the truth sets, three runs per route.
- Task 3: E18 first 10k / 100k / 500k cells, 3 builds x 3 starts per tool and size; build time, artifact size, service-ready time, first plot, peak RSS.
- Task 4 (separate, one Mac): building a shareable artifact, deploying it, saving and restoring a view, and a killed update; see [Task 4](#task-4-building-deployment-and-saverestore) below.

Results: [results/SUMMARY.md](results/SUMMARY.md) and [results/summary_task3.md](results/summary_task3.md); one file or row per run, with per-tool tables, in `results/task1/`, `results/task2/` and `results/task3/`; logs and screenshots behind them in `results/evidence/`.

Figures (R, ggplot2, Genome Biology rules; `functions.R` and `targets.R`): `figures/fig-tool-comparison.pdf` (a: capability matrix, b: Jaccard per route, c: build time, artifact size, ready + first plot and server and browser memory at 10k / 100k / 500k cells) and `figures/fig-tool-comparison-start.pdf` (service-ready and first-plot time, every single start). Checked with `topics/interface_figures/scripts/check_figures.R`. The screenshot panels of [FIGURES.md](FIGURES.md) are not redone yet.

## Layout

```
PROTOCOL.md     protocol of round 2 (frozen; Deviations D1-D9 at the end)
PROTOCOL_task4.md  protocol of Task 4 (frozen; deviations in the Task 4 section below)
PROGRESS.md     run diary
FIGURES.md      the two screenshot panels and how scripts/report/capture_figures.py makes them
functions.R     plotting functions of the figures
targets.R       their target list; the measurements do not run through it
scripts/
  run/          measurement: harness.py, task1/, task2/, task3/, tools/ (one builder per tool), task4/ (Task 4 on the Mac: t1_t2.R, t3.R, builders, lib.R)
  setup/        environment, inputs, environment record
  report/       results/task* -> summaries (aggregate_task*.py, summarize_task3.py, make_summary.py), capture_figures.py
results/        tables, per-run files (task1/ to task4/), evidence (logs and screenshots), environment.json, inputs.csv, hashes
figures/        the figures (PDF and PNG; fig-tool-comparison-task4 is Supplementary Figure S13; qa/ holds the SVG twins for the check)
```

`data/` (`raw/` downloads, `inputs/` derived inputs, `builds/` what each tool builds) and `env/` (Python, R library, JavaScript bundle) are created by the scripts and are git-ignored. Round 1 (CerebroNexus 6.0.0 `27ac995e`, R 4.5.0, 2026-10-22 to 2026-10-24) is in the Git history up to commit `983df03` (see Deviation D5 of the protocol).

## Running

The scripts locate everything relative to this folder. They target native Windows with Git Bash and the R install in `C:\R\R-4.6.1` (`scripts/run/run_r.sh` uses `cygpath`); the Python environment is `env/py`.

```bash
scripts/run/run_r.sh scripts/setup/setup_r_round2.R   # R library env/rlib
python scripts/run/harness.py pilot <I1|e18_10000> [tool ...]
bash scripts/run/task1/run_all.sh
bash scripts/run/task2/run_all.sh
python scripts/run/task3/run.py run [10000 100000 500000]

# results/task* -> summaries
python scripts/report/aggregate_task1.py
python scripts/report/aggregate_task2.py
python scripts/report/summarize_task3.py
python scripts/report/make_summary.py
```

## Task 4: building, deployment and save/restore

Run on 2026-10-27 on one Mac (Apple M1 Pro, 10 CPUs, 32 GB, macOS 27.0.1), as a task of its own; it is not part of Figure 9 (Tasks 1-3 ran on Windows). Protocol: [PROTOCOL_task4.md](PROTOCOL_task4.md), SHA-256 `e079d87d...c66828` recorded in `results/task4/PROTOCOL.sha256` before the first measured run. Versions: `results/task4/task4_environment.txt` (CerebroNexus 6.0.0 at `33150d9d7`, ShinyCell 2.1.0, iSEE 2.24.0, cellxgene 1.3.0, Vitessce Python 3.8.4 with JavaScript 3.9.9).

### Running

```bash
Rscript scripts/run/task4/t1_t2.R      # -> results/task4/task4_build.csv, task4_deploy.csv
Rscript scripts/run/task4/t3.R         # -> results/task4/task4_state.csv, task4_update.csv
sh scripts/run/task4/record_env.sh     # -> results/task4/task4_environment.txt
```

Tools are installed outside the repository under `$T4_G` (default `topics/tool_comparison/env/g`, git-ignored; the recorded runs used `/Volumes/bv_cache/g` on an external drive): R library for ShinyCell/iSEE and the ShinyCell app's runtime packages, a Python 3.11 venv for cellxgene and Vitessce, the Vitessce JavaScript bundle built with esbuild); CerebroNexus is the library of `topics/builder_validation`. Builds, deployments and logs are in `$T4_G/runs`. The Viewer library without CerebroNexus is `$BV_HERMETIC_LIB` (default `topics/builder_validation/env/hermetic-lib`).

### Results

#### T1 build and T2 deploy (3 runs each; median, min-max)

| Tool | Build route | Grade | Steps | Build (s) | Artifact (MB) | Deploy: start to main view (s) | Login documented | Data files by URL without login |
|---|---|---|---|---|---|---|---|---|
| CerebroNexus | Builder: file -> Review -> "CRB files + Viewer App" (headless route of `builder_validation`) | done | 4 UI actions (not driven) | 12.42 (12.03-12.86) | 25.6 | 4.09 (4.05-5.54) | yes (Builder login accounts) | no: CRB 404 |
| CerebroNexus with login | as above, one account | done | 6 UI actions | 13.16 (12.75-13.20) | 25.7 | 5.60 (5.55-5.61), sign-in included | - | no: CRB 404 |
| ShinyCell | `createConfig()` + `makeShinyApp()` on an SCE read with anndataR | done | 3 calls | 5.82 (5.77-5.88) | 17.4 | 2.97 (2.94-3.19) | no | no: `sc1gexpr.h5`, `sc1meta.rds` 404 |
| iSEE | `saveRDS(sce)` + an `app.R` with `iSEE(readRDS("sce.rds"))` written by the user | manual | 2 calls + app.R | 8.17 (8.16-8.21) | 22.8 | 7.87 (7.81-7.89) | no | no: `sce.rds` 404 |
| cellxgene | none; the `.h5ad` is the artifact (copied) | absent (not needed) | 0 | 0.06 (0.05-0.09) | 40.2 | 3.75 (3.73-4.47) | no | yes: `/api/v0.2/schema`, `/api/v0.2/annotations/obs` 200 (the API serves the data by design) |
| Vitessce | `optimize_adata()` + `write_zarr()` + `VitessceConfig` | done | about 10 calls | 1.53 (1.49-1.64) | 17.6 | 0.93 (0.93-0.94) | no | yes: `data.zarr/*` 200 (static files by design) |

Every build exited 0 and every artifact held 2,638 cells; every deployment answered HTTP 200 and drew its main view in headless Chrome in all three runs. Deployment = the artifact copied to a new empty directory and served from there by a fresh process on a new port (`shiny::runApp('.')` for the R tools, with a library without CerebroNexus for the CerebroNexus App; `cellxgene launch`; a one-origin Python server for Vitessce with the local JavaScript bundle). "Main view": the Gene expression projection with one gene for CerebroNexus, `#sc1a1oup1` for ShinyCell, `#ReducedDimensionPlot1` for iSEE, the graph canvas for cellxgene and the deck.gl canvas for Vitessce.

#### T3 save/restore (`results/task4/task4_state.csv`)

| Tool | Mechanism | Grade | Steps | Saved | Restored after restart |
|---|---|---|---|---|---|
| CerebroNexus | Linked views "Share view" -> "Download JSON"; "Open JSON" | done | save 2, restore 2 UI actions | yes (25-cell selection) | yes: 25 cells, through the App's own decoder |
| cellxgene | user annotations saved by the server to `--user-generated-data-dir` | manual | save 3 UI actions; restore: restart with `--annotations-file <saved csv>` | yes (`task4-cell-labels-<id>.csv`, 100 labelled cells) | not by the same server on the same directory: the file is named by a per-browser id kept in a session cookie whose key is new at each launch, so after a restart the labels are not shown (HTTP 400); yes when started with `--annotations-file` |
| ShinyCell | none in the generated app | absent | - | - | - |
| iSEE | panel settings exported as R code ("Display panel settings"), passed back as `iSEE(initial = ...)` | manual | save 2 UI actions; restore: edit `app.R` | not run | not run |
| Vitessce | the view is a static `config.json`; changes in the page are not saved by the tool | manual | edit `config.json` | not run | not run |

#### T3 update and killed update (`results/task4/task4_update.csv`)

The artifact was rebuilt into the same location from the changed input (`pbmc3k_minus100.h5ad`, 2,538 cells); then, from a fresh v1, the same rebuild was killed (SIGKILL) halfway through the median T1 build time.

| Tool | Update with the changed input | Kill after (s) | After the killed update | Recovery | Deploy after the kill |
|---|---|---|---|---|---|
| CerebroNexus | v2 (release replaced) | 6.21 | v1 kept | `builder_discover_recovery()`: ready, nothing to restore | v1 drawn |
| ShinyCell | v2 (files overwritten) | 2.91 | v1 kept (killed before files were written) | - | v1 drawn |
| iSEE | v2 | 4.08 | v1 kept (killed before `saveRDS`) | - | v1 drawn |
| cellxgene | v2 (file replaced) | 0.05 | **unreadable** (copy interrupted; in two earlier runs of this script the copy had finished first and v2 was in place) | - | server does not draw |
| Vitessce | v2 | 0.76 | v1 kept | - | v1 drawn |

Only CerebroNexus publishes through a staged release (`builder_validation` experiment C tests its recovery under kills at every publication phase). For the other tools "v1 kept" means the kill came before they started writing into the artifact directory: their builds write in place, so a kill while writing leaves a mixed or truncated artifact, as the cellxgene row shows.

### Supplementary Figure S13

`plot_task4_figure()` in `functions.R` (target `tool_comparison_task4_figure` in `targets.R`) draws `figures/fig-tool-comparison-task4.{pdf,png}` from `results/task4/task4_*.csv` with the theme of the other tool comparison figures (nothing is rerun); the manuscript copy is `figS13-tool-authoring-deploy.{pdf,png}`:

```bash
Rscript -e 'targets::tar_make(tool_comparison_task4_figure)'
Rscript topics/interface_figures/scripts/check_figures.R topics/tool_comparison/figures
```

Caption draft:

**Supplementary Figure S13. Building, deploying and keeping a shared view in five tools.** pbmc3k (2,638 cells), documented routes only, one Mac. **a**, Time to build the shareable artifact from the input and time from starting the deployed server to the drawn main view, three runs each (circles) and their median (bar). Deployment: the artifact copied to an empty directory and served by a fresh process. CerebroNexus with login: the same App built with one login account; its start time includes signing in. The cellxgene "build" is a file copy (0.06 s). **b**, Login documented for a shared artifact; data files returned to a plain HTTP request without login (cellxgene serves the data through its API and Vitessce as static files, by design); a saved view restored after the server is restarted (CerebroNexus: a 25-cell Linked views selection saved as View JSON and opened again by the App; cellxgene: user annotations, shown again only when the server is restarted with the saved file; iSEE and Vitessce restore by editing code or a configuration file and were not run; ShinyCell offers no state saving); and the previous version left in place when an update with a changed input is killed (SIGKILL) halfway through the median build time. Only CerebroNexus publishes through a staged release; ShinyCell, iSEE and Vitessce kept the previous version because the kill came before they wrote into the artifact directory, and cellxgene's interrupted copy left an unreadable file.

### Deviations from the protocol

- D1. anndataR refuses the legacy layout of the cellxgene `pbmc3k.h5ad` (anndata < 0.8), as in Tasks 1-3; every tool therefore got the file read and written once with anndata 0.12.19 (`pytools.py rewrite`, content unchanged, SHA-256 `4451252b...a943`), and the changed input was made from it (`daaacaf0...a0c2`).
- D2. CerebroNexus ran at `33150d9d7` (the head of `builder/03_builder` with three fixes from `topics/builder_validation`, not pushed when run), not at `001c4d4dd` named in the protocol; the fixes touch login and the H5 sidecar check, not the routes measured here.
- D3. The ShinyCell app needs runtime packages its installation does not pull in (`shinyhelper`, `hdf5r`, `ggdendro`, ...); they were installed from CRAN into the tools' library before the measured runs.
- D4. On 2026-10-28, after the runs, the Task 4 files moved from `task4_authoring_deploy/` into this topic's layout (`PROTOCOL.md` -> `PROTOCOL_task4.md`, `results/` -> `results/task4/`, the run scripts -> `scripts/run/task4/`, `scripts/figure.R` -> `plot_task4_figure()` in `functions.R`); paths inside the scripts were changed to match, nothing was rerun, and the figure drawn from the moved tables is identical. The protocol text is unchanged: its SHA-256 still matches `results/task4/PROTOCOL.sha256`, which names the file by its old name `PROTOCOL.md`.

### Limits

- One Mac, one small input (2,638 cells), documented routes only; no judgement of usability. Step counts are those of the documented routes; the Builder's browser UI was not driven (its headless route was), so its step count is read from the UI, not measured.
- Login was tested only for CerebroNexus, the only tool of the five that documents one for a shared artifact. "Data files by URL" lists what a plain HTTP request to the deployed server returned; for cellxgene and Vitessce, serving the data to any client is how the tools work.
- CerebroNexus save/restore: the view was saved through the page ("Share view" -> "Download JSON") and, after the restart, opened with the App's own decoder; the page's "Open JSON" file input was not driven. The Builder's own configuration save was not tested. iSEE and Vitessce restore by editing code or a config file and were not run.
- The cellxgene "build" is a file copy of about 0.05 s, so whether the kill interrupts it depends on timing (interrupted in the recorded run, not in two earlier ones).
- Timings are from one run of each script on a laptop with nothing else running; the T3 rows were run after the drive holding the runs had been disconnected and reattached once.
