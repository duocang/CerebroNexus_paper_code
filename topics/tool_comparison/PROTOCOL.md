# Comparative evaluation, round 2: CerebroNexus `perf/viewer-page-open` against four viewers

Protocol written 2026-10-26, before any round-2 measured run. This text is frozen once its SHA-256 is stored in `results/PROTOCOL.sha256`. Changes after that go into the **Deviations** section at the end, each with a date and a reason; nothing above it is edited.

Round 1 (CerebroNexus 6.0.0, R 4.5.0) is complete and kept unchanged in `archive/round1_cerebronexus-6.0.0/` (its protocol, deviations D1-D15, diary, figures work order and all results). Round 2 reuses its design, its inputs and its scripts; this document lists what is different (section 2) and restates the rules, so that it can be read on its own.

## 1. Question and scope

Given the same data and the same machine, what do five tools import and recognise automatically, can a cell selection made in each tool be taken out of it, and how do build time, artifact size, start-up, first plot and memory grow with cell number? Round 2 repeats this with the CerebroNexus branch `perf/viewer-page-open` (Viewer optimised for page opening), on a GPU-backed browser, and with every tool measured again on the new R.

Only machine-measurable quantities are compared. Usability, appearance and feature breadth beyond the checklists below are not rated. Every result is written down, including failures; no run is excluded.

## 2. What differs from round 1

| | Round 1 | Round 2 |
|---|---|---|
| CerebroNexus | 6.0.0, `27ac995e` (has `convertH5adToCerebro`) | branch `perf/viewer-page-open`, commit `30e6e9c8524bbcb9b115df4ddbb9b7096f483755` (5.5.0); no h5ad importer, so see 7.2 |
| R | 4.5.0 | 4.6.1 (`C:\R\R-4.6.1`), Bioconductor 3.23 (iSEE 2.24.0 and others, versions recorded) |
| Browser start | Chrome launched before the server was spawned | Chrome launched after the server's first HTTP 200, so browser start-up is not inside `t_ready` (round 1 measured about 1 s more) |
| WebGL | described as software rendering (wrong) | hardware: ANGLE / Direct3D 11 on the NVIDIA GPU; the renderer string is read from the page and stored in `results/environment.json` |
| Layout | `results/figures/` | `figures/` next to `results/`; round-1 results in `archive/` |

Round-1 numbers are not paired with round-2 numbers (different R, different browser start, different CerebroNexus route). Where both are shown, the figure says so.

## 3. Tools and pinned versions

| Tool | Pin | Role |
|---|---|---|
| CerebroNexus | `duocang/CerebroNexus` branch `perf/viewer-page-open`, commit `30e6e9c8524bbcb9b115df4ddbb9b7096f483755`, version 5.5.0, installed from `git archive` of that commit | Viewer (`launchCerebro`) |
| ShinyCell | `SGDDNB/ShinyCell` commit `5c61db78` (as round 1, version 2.1.0) | generated Shiny app |
| iSEE | Bioconductor 3.23 release (version recorded) | Shiny app from a `SingleCellExperiment` |
| cellxgene | 1.3.0 (PyPI), as round 1 | `cellxgene launch` on an `.h5ad` |
| Vitessce | Python package 3.8.4, JavaScript `vitessce@3.9.9`, as round 1 | Zarr plus a locally served page |

Other packages come from CRAN, Bioconductor or PyPI at the latest version available on the install day. The Python environment is the one of round 1 (`env/py`, unchanged). `results/environment.json` records every version, the Chrome version and the host.

## 4. Host and environment

- Native Windows only. No WSL, no containers, no `/mnt/c` or `\\wsl$` paths anywhere in scripts or logs (WSL has no GPU). A tool that cannot be installed or run natively is recorded as `platform_limit` with the install or run log.
- Recorded in `results/environment.json`: CPU model and core count, RAM, GPU name and driver, OS build, R, Python and Chrome versions, the WebGL `UNMASKED_RENDERER` string of the headless Chrome used, the active Windows power plan (read, not changed), disk free space at start.
- R: `C:\R\R-4.6.1\bin\Rscript.exe`. The only user library is `env/rlib` (R 4.6.1; the dependency closure of every package below, binaries only). R runs with `R_LIBS=R_LIBS_USER=<env/rlib>`, `R_LIBS_SITE` empty, `--vanilla`, `LANGUAGE=en`, `LANG=en_US.UTF-8`. The R 4.6.1 system library holds other packages (about 700) and cannot be removed from the library path, so after every change to `env/rlib` an isolation check loads the tools and verifies that every loaded non-base namespace comes from `env/rlib`; the result is stored in `results/environment.json`. The round-1 R 4.5.0 library is kept as `env/rlib_round1_r45_cerebronexus6.0.0`, unused.
- Browser: system Chrome through Playwright `channel='chrome'`, headless, viewport 1600 x 1000, device scale factor 1, a new browser context for every measured run, launched after the server is ready (section 2).
- Ports are fixed per tool. One measured process tree runs at a time; the harness stores a 3 s CPU-idle sample before each run.
- The OS file cache is not flushed. Windows Defender and other background load are left as they are and noted in `environment.json`; other processes the owner runs on the machine during a measurement are noted in PROGRESS.md.
- Where files go (all on the Windows side, none in `C:\Users\wangx\Projects\data` or `...\Projects\tmp`): `topics/tool_comparison/data/raw/` downloads, `data/inputs/` derived inputs, `data/builds/` what each tool builds in round 2 (round 1: `data/builds_round1/`), `env/` environments; scratch, probe scripts and ad-hoc logs in `C:\Users\wangx\Projects\catch\tool_comparison\<date>_<topic>\`. `data/` and `env/` are git-ignored.

## 5. Data

Inputs are the files of round 1 and are not recomputed: `data/raw/` (I1, I3, E18 download) and `data/inputs/` (I1/I3 rewritten, I2, I4, `e18_10000|100000|500000.h5ad`, `default_genes.txt`, `vitessce-js`). Their size and SHA-256 are recomputed into `results/inputs.csv` and compared with round 1 (`archive/round1_cerebronexus-6.0.0/results/inputs.csv`); a difference stops the run.

| ID | Source | Use |
|---|---|---|
| I1 | `pbmc3k.h5ad` from the cellxgene repository | Task 1, Task 2 (S1) |
| I2 | scRepertoire example `scRep_example` with TCR (500 cells, `CTaa`), as Seurat object and `.h5ad` | Task 1, Task 2 (S2) |
| I3 | `visium_hne_adata.h5ad` (squidpy Visium H&E mouse brain) | Task 1 |
| I4 | I1 with duplicated cell names (last ten replaced by the first ten) | Task 1 |
| E18 | 10x `1M_neurons_filtered_gene_bc_matrices_h5.h5`, 4,216,018,749 bytes, SHA-256 `255a36ee92de25cb3568faa2c27d31fe6d0db30f285c5c977be8d6245de14044` | Task 3 |

The large demo data sets in `C:\Users\wangx\Projects\data\large-examples` (mouse brain 1.3 M, Ren 1.46 M, CosMx, T-cell; made for the CerebroNexus Viewer) are read-only for this study: nothing is written there and nothing is copied unless a deviation says so. The file `1m/source/1M_neurons_filtered_gene_bc_matrices_h5.h5` is compared by SHA-256 with `data/raw` (same data, not used twice).

## 6. Task 1: import and capability recognition

Unchanged from round 1 (archive `PROTOCOL.md` section 5, with its D4, D9): every tool on I1-I4, not timed, not repeated, the documented import route, `default_route_failed` rule, grades `auto` / `manual` / `absent` / `n/a` / `error`, and the I4 duplicate-name outcome. CerebroNexus has no `.h5ad` importer on this branch, so its route for I1, I3 and I4 is the documented one for an AnnData file there: `.h5ad` read with anndataR as `SingleCellExperiment` -> `exportFromSCE()` (or, where that cannot carry a component, -> Seurat -> `exportFromSeurat()`), then `launchCerebro(crb_file_to_load=)`. The call, its arguments and any component that the route cannot carry (spatial coordinates, tissue image) are written to the Task 1 record; absence of an importer is itself recorded as `absent` for "reads `.h5ad` directly".

## 7. Task 2: selection retrieval

Unchanged from round 1 (archive `PROTOCOL.md` section 6, with D8 and D14): truth sets S1 (`louvain == "B cells"` in I1) and S2 (most frequent `CTaa` in I2); region route and attribute route; export through a user-facing control; Jaccard, precision, recall; three runs per route. CerebroNexus attribute route: Projection -> Group filters, then a lasso around the whole plot (the filter decides the selection). The control paths on the branch are re-found in the pilot; changes go into Deviations.

## 8. Task 3: scale

### 8.1 Inputs

The three tier files of round 1: first 10,000, 100,000 and 500,000 cells of E18, log-normalised, 2,000 HVGs, 50 PCs, UMAP, `MiniBatchKMeans(20)` as `cluster`, `nUMI`, `nGene` in `obs`, no cell or gene filtering. Not recomputed.

### 8.2 Native formats and configurations

| Config | Build: from the tier `.h5ad` to what the server reads | Serve |
|---|---|---|
| `cerebronexus_default` | anndataR -> `SingleCellExperiment` -> Seurat object -> `exportFromSeurat(groups = "cluster", nUMI = "nUMI", nGene = "nGene", expression_matrix_mode = "embedded")` -> `.crb` (script `scripts/run/tools/cerebronexus_build.R`, new for this branch; same steps as the round-1 side check) | `launchCerebro(mode = "closed", crb_file_to_load=)` |
| `cerebronexus_h5` | same, `expression_matrix_mode = "h5"`, `h5_compression_level = 0L` -> `.crb` plus uncompressed H5 sidecar | same (the Viewer finds the sidecar next to the `.crb`) |
| `shinycell` | anndataR -> `SingleCellExperiment` -> `createConfig()` -> `makeShinyApp()` with the default genes (S100a8, Ccl4) | `shiny::runApp(<app dir>)` |
| `isee` | anndataR -> `SingleCellExperiment` -> `saveRDS(compress = FALSE)` | `readRDS()` -> `iSEE()` -> `runApp` (opens on `X_pca`, as in round 1) |
| `cellxgene` | none (reads the `.h5ad`); build `n/a`, artifact size = the `.h5ad` | `cellxgene launch --port <p> --disable-gene-sets-save <file>` with the upgrade check made to fail at once (`HTTPS_PROXY=http://127.0.0.1:9`, round-1 D12) |
| `vitessce` | `.h5ad` -> Zarr with `optimize_adata(optimize_X=False)` (round-1 D3), config `AnnDataWrapper` (`obsm/X_umap`, `obs/cluster`, `X`) | local server on one origin (`scripts/run/serve_vitessce.py`) |

Because the CerebroNexus build starts from Seurat objects, its build time contains reading the `.h5ad`, building the object and the export; this is stated next to every build-time number. Start metrics do not depend on the route.

### 8.3 Replication and schedule

For every config and tier: 3 builds; each build is served in 3 new processes (new process tree, new browser context). The build artifact is deleted after its three starts (size measured before deletion). Builds of one tier run in rounds (one build of every config in a seeded random order, then its three starts; three rounds), seed 20261026. Tiers run in the order 10,000, 100,000, 500,000. All runs are sequential. cellxgene runs are not interleaved with the others only if the upgrade check cannot be blocked.

### 8.4 Measured per build and per start

Build (fresh process, spawn to exit): wall time, peak process-tree RSS, exit status, log; for R-side builds also the time reading the `.h5ad` and the time in the tool's own step. Artifact size: bytes of all files the server reads (apart from the `.h5ad` for cellxgene).

Start (fresh process tree): `t_ready` (spawn to first HTTP 200), `t_first_plot` (browser navigation start to the first qualifying frame of the embedding plot), `t_total` = sum, peak process-tree RSS of the server until the first qualifying frame, and the peak RSS of the Chrome process tree.

### 8.5 Timers, RSS, first plot

- Durations use `time.perf_counter()` in one Python harness (`scripts/run/harness.py`), one clock for all tools. The browser is started after `t_ready` is known and before navigation; its start-up is in neither time.
- Peak RSS: `psutil` working-set RSS summed over the spawned process and descendants, every 100 ms.
- First plot: scripted steps to the embedding view (CerebroNexus: click "Projection"); target element the main embedding plot (CerebroNexus `#cv-cv-a`, ShinyCell `#sc1a1oup1`, iSEE `#ReducedDimensionPlot1`, cellxgene `canvas.graph-canvas`, Vitessce `canvas#deckgl-overlay-A`); an element screenshot every 250 ms; a pixel is *ink* if its RGB distance from the most frequent colour is above 60 and it is dark (V < 0.5) or has saturation above 0.1; a frame qualifies if the element is at least 200 x 200 px and at least 1% of its pixels are ink; the first qualifying frame is accepted when the next one also qualifies (round-1 D2, D11). The accepted frame is saved for every run and looked at before a tier is accepted.

### 8.6 Timeouts and failures

Build 60 minutes; server ready 15 minutes from spawn; first plot 15 minutes from navigation, whole start cut at 30 minutes. Status per run: `ok`, `timeout`, `error`, `oom`, `platform_limit`, `not_run` (with reason). Stop rule fixed in advance: if the first build of a config in a tier ends in `timeout` or `oom`, builds 2 and 3 of that tier are `not_run (stop rule)` and the next tier is attempted once. Nothing is dropped from the raw tables; summaries show `n_ok / n_total`.

## 9. Order of work

1. Environment: `env/rlib` for R 4.6.1, the pinned CerebroNexus commit, isolation check, `environment.json`, input hashes (done and checked before any pilot).
2. Harness changes made before the pilot (Chrome after ready; R 4.6.1 paths; CerebroNexus build/serve scripts for this branch). The harness, its configuration and these scripts are hashed and the hashes written to PROGRESS.md before the first measured run.
3. Pilot: every tool on I1 and on the 10,000-cell tier (not used in statistics; screenshots checked by eye; selectors, export routes, the CerebroNexus Task 1 route). Findings that change the protocol go into Deviations before the measured runs.
4. Task 1, Task 2, then Task 3 tiers in order. Owner approves the plan (this file and the pilot result) before step 4.
5. Summaries, quantitative figure, screenshot captures, figure checks.

## 10. Outputs and figures

- `results/task1/`, `results/task2/`, `results/task3/` (one row per run, including failed and not-run), `results/summary_task3.csv|md`, `results/task1_summary.csv`, `results/task2_summary.csv`, `results/SUMMARY.md`, `results/inputs.csv`, `results/environment.json`, `results/PROTOCOL*.sha256`, `results/evidence/` (logs and screenshots behind the tables), `results/superseded/` (any run replaced during the round, with a Deviation).
- `figures/` (next to `results/`): drawn in R with ggplot2 following the Genome Biology rules of the owner's `CLAUDE.md`: 85 mm or 170 mm wide, height at most 225 mm, Arial, panel labels 8 pt bold, all other text 7 pt (nothing below 6 pt), lines at least 0.25 pt, colour-blind-safe colours, one file per figure with all panels, `cairo_pdf` with embedded fonts, legends inside the figure, no titles in the figure, tight crop; checked with `topics/interface_figures/scripts/check_figures.R`. The figure set is chosen after the results exist and the owner has chosen from the candidates (capability matrix, selection accuracy, scale curves, ready / first-plot decomposition, memory, artifact size, run-to-run spread, round 1 against round 2 for CerebroNexus, screenshot panels A and B of the work order in `archive/round1_cerebronexus-6.0.0/FIGURES.md`).
- Scripts in `scripts/`. Nothing is committed or pushed without the owner's approval; commits in English Conventional Commits style without any AI attribution, pushes through the SSH remote.

## 11. Known limits, stated in advance

- One machine, one operating system, one GPU. Absolute numbers do not transfer.
- The tools are not given identical interfaces: each uses its own documented route, so build time includes whatever the route needs. CerebroNexus on this branch has no `.h5ad` importer; its build time includes the anndataR / Seurat steps.
- The headless Chrome uses the GPU (ANGLE / D3D11), as the owner's Chrome would; software rendering is not measured.
- Round-1 and round-2 numbers differ in R version, browser start and CerebroNexus route and are not a paired comparison.
- Vitessce JavaScript is served from local copies of `vitessce@3.9.9`.
- A pre-registered stop rule can leave some larger-tier cells with a single build.
- I2 has 500 cells, 365 of them with a TCR; it tests recognition, not scale.

## Deviations

Verification of the frozen text: `results/PROTOCOL.sha256` is the hash of the whole file as written, with "None so far." under this heading. `results/PROTOCOL_body.sha256` is the hash of the text before this heading, which stays valid when entries are added here.

All entries below were made on 2026-10-26, after the pilot runs and before any measured run.

**D1. CerebroNexus pin changed to the merged build `tmp/应急` (sections 2, 3, 6, 8.2).** The pin in section 3 was the branch `perf/viewer-page-open` at `30e6e9c8` (5.5.0), which has the optimised Viewer but no `.h5ad` importer. On 2026-10-26 the owner provided the branch `tmp/应急`, commit `2786ff6d09a53f54e25bb1affbc6ed58aac70b43` (Builder 6.0.0 merged into `perf/viewer-page-open`; `DESCRIPTION` version 6.0.0; it has `convertH5adToCerebro()` and the Viewer optimisations; it contains `perf/viewer-page-open` at `30e6e9c8` and the Builder 6.0.0 head `13682caeb`). From now on this commit is the CerebroNexus of round 2, installed into `env/rlib` from `git archive` of that commit (`env/src/CerebroNexus-tmp-emergency-2786ff6d.tar.gz`; the archive is of the commit, not of the worktree, which holds one uncommitted change in `inst/builder/app_bundle/topology.R`). Consequences: (a) the Task 1 and Task 2 routes and the Task 3 builds for CerebroNexus are those of round 1 (`convertH5adToCerebro(groups, nUMI, nGene)`, with `expression_matrix_mode = "h5"` and `HDF5Array::setHDF5DumpCompressionLevel(0L)` for the H5 configuration; I2 through Seurat and `addImmuneRepertoire()`), so build times are comparable with round 1 in route, not in R version or browser start; (b) `launchCerebro()` of this build has no `expression_matrix_*` arguments, the H5 sidecar next to the `.crb` is found by the Viewer, so `cerebronexus_serve.R` takes only the `.crb` and the port; (c) the sentences in sections 2, 6 and 8.2 about the missing importer, `exportFromSCE` and the Seurat route no longer apply and the section 11 limit about the CerebroNexus build time does not apply. The pilot of the 5.5.0 route (Task 1 and Task 2 trials, Task 3 pilot rows) is kept unchanged in `results/evidence/pilot/cerebronexus_5.5.0_branch_route/`, `task1_trial/` and `task2_trial/` and is in no table; the scripts of that route are not in the repository. Pilot of the new pin (I1 and the 10,000-cell tier, both CerebroNexus configurations; Task 1 on I1-I4; Task 2 S1/S2 by both routes): everything built and started and drew cells, and Task 1 and Task 2 gave the round-1 results (`results/evidence/pilot/task1_trial_6.0.0merged/`, `task2_trial_6.0.0merged/`).

**D2. Host load during the pilot of D1.** The pilot start times of D1 (ready 12-14 s, first plot 5-7 s at 10,000 cells) are about three times those of the 5.5.0 pilot of the same day (3.3-3.8 s and 1.8-2.0 s). The load is not in the new build: with the CPU at 70-90% from processes that were not the harness (no single process found), `library(CerebroNexus)` took 5.4-6.9 s and `launchCerebro()` 2.7-3.6 s for the 5.5.0 build and 6.2-6.9 s and 2.7-3.6 s for the merged build, run back to back; earlier the same day they took about 2 s and 1 s. The pilot times are therefore not used. Measured runs start only when the host is quiet (CPU-idle sample stored before every run, as in section 4, and checked against this value before the first run).

**D3. Script changes made after the protocol was frozen and before the measured runs (2026-10-26).** All are in `results/scripts_manifest.sha256` (the list of SHA-256 of every script as run). (a) `scripts/run/task3/run.py`: order seed 20261026 instead of 20261022, as section 8.3 says. (b) `scripts/run/task1/run_shinycell.sh` and `run_isee.sh`: the `cd` to the study folder had one level too few after the folder reorganisation of round 1; the first Task 1 driver run wrote no ShinyCell or iSEE row because of it, so the whole driver was run again (all rows of that run are the ones in `results/task1/`). (c) `scripts/run/task2/t2_cellxgene.py`: cellxgene is started with `harness.cellxgene_env()` (upgrade check made to fail at once, as round-1 D12 and section 8.2 say); the first Task 2 attempt used the plain environment and the four cellxgene routes ended with "server did not start", so they were run again, and `results/task2/` holds only the re-run rows. (d) New drivers `scripts/run/task1/run_all.sh` and `scripts/run/task2/run_all.sh` (the run lists of round 1, written down). (e) `scripts/setup/setup_r_figures.R` installs patchwork and svglite for the figure. (f) The quantitative figure is written to `figures/` beside `results/` (`targets.R`, `functions.R` unchanged in content).

**D4. Host load during the measured Task 3 runs.** The WSL virtual machine was stopped by the owner before Task 2 and Task 3. The idle CPU stored before the 162 starts of Task 3 had a median of 3.7%, p90 7.8% and maximum 13.7% (round 1: median 9.7%, p90 22.9%, maximum 81.5%); a sample taken just before Task 2 read about 25% (HipsDaemon, `vmmemWSL` and desktop processes). Every run stores its own `idle_cpu_pct_before`. No other job of the study ran during Task 3.
