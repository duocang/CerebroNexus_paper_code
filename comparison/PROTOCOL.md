# Comparative evaluation: same-task comparison of five single-cell viewers

Protocol written 2026-10-22, before any measured run. This text is frozen once its SHA-256 is stored in `results/PROTOCOL.sha256`. Changes after that go into the **Deviations** section at the end, each with a date and a reason; nothing above it is edited.

## 1. Question and scope

Given the same data and the same machine, what do five tools import and recognise automatically, can a cell selection made in each tool be taken out of it, and how do build time, artifact size, start-up, first plot and memory grow with cell number?

Only machine-measurable quantities are compared. Usability, appearance and feature breadth beyond the checklists below are not rated. Every result is written down, including failures; no run is excluded.

## 2. Tools and pinned versions

| Tool | Pin | Role |
|---|---|---|
| CerebroNexus | 6.0.0, `duocang/CerebroNexus` commit `27ac995e983a3ff1c79a2d051c9a4374dde37ec6` | Viewer (`launchCerebro`) |
| ShinyCell | `SGDDNB/ShinyCell` commit `5c61db78` (full hash resolved at install and recorded) | generated Shiny app |
| iSEE | Bioconductor release current on the install day (version recorded) | Shiny app from a `SingleCellExperiment` |
| cellxgene | 1.3.0 (PyPI) | `cellxgene launch` on an `.h5ad` |
| Vitessce | Python package 3.8.4, JavaScript `vitessce@3.9.9` (the widget's default version) | Zarr plus a locally served page |

Other packages come from CRAN, Bioconductor or PyPI at the latest version available on the install day. `results/environment.json` records every version, the Chrome version and the host.

## 3. Host and environment

- Native Windows, no WSL, no containers. A tool that cannot be installed or run natively is recorded as `platform_limit` with the install or run log. It is not moved to another environment.
- Recorded in `results/environment.json`: CPU model and core count, RAM, OS build, R version, Python version, Chrome version, the active Windows power plan (read, not changed), disk free space at start.
- Python: `comparison/env/py`, Python 3.11, created with `uv venv`. Packages: `cellxgene==1.3.0 vitessce==3.8.4 anndata scanpy psutil requests playwright` plus what these pull in. If the Python pins conflict, the conflict is logged and the tool whose pin is kept to the version above wins; the other package takes the nearest version that installs.
- R: `comparison/env/rlib`, the only user library. R runs with `R_LIBS=R_LIBS_USER=<rlib>`, `R_LIBS_SITE` empty, `--vanilla`, `LANGUAGE=en`, `LANG=en_US.UTF-8`. Packages: iSEE, ShinyCell and the packages its generated `ui.R`/`server.R` load via `library()` (shinyhelper, DT, hdf5r, ggrepel, ggdendro, gridExtra and others found there), CerebroNexus from `git archive` of the pinned commit via `R CMD INSTALL`, anndataR (reads `.h5ad`), Seurat, scRepertoire, HDF5Array, rhdf5. The system R library and conda environments are not modified.
- Browser: system Chrome through Playwright `channel='chrome'`, headless, viewport 1600 x 1000, device scale factor 1, a new browser context for every measured run. Headless Chrome renders WebGL in software, which is the same for every tool.
- Ports are fixed per tool. One measured process tree runs at a time; the harness stores a 3 s CPU-idle sample before each run.
- The OS file cache is not flushed (not possible without changing system settings). Windows Defender and other background load are left as they are and noted in `environment.json`.

## 4. Data

All inputs are downloaded to `comparison/data/`; file size and SHA-256 are recorded in `results/inputs.csv`. Derived inputs go to `comparison/inputs/`. Neither folder is committed.

| ID | Source | Use |
|---|---|---|
| I1 | `pbmc3k.h5ad` from the cellxgene repository (`example-dataset/pbmc3k.h5ad`) | Task 1, Task 2 (S1) |
| I2 | scRepertoire example `scRep_example` (500 cells, Seurat, UMAP, `seurat_clusters`) with `contig_list` -> `combineTCR(samples = P17B,P17L,P18B,P18L,P19B,P19L,P20B,P20L)` -> `combineExpression(cloneCall = "strict")`; adds `CTgene`, `CTnt`, `CTaa`, `CTstrict`. Cells without a TCR have `CTaa = NA`. A matching `.h5ad` is written from the same object (counts in `X`, `obsm['X_umap']`, all metadata columns, `var_names` = gene symbols) | Task 1, Task 2 (S2) |
| I3 | `visium_hne_adata.h5ad` (squidpy Visium H&E mouse brain, `https://ndownloader.figshare.com/files/26098397`) | Task 1 |
| I4 | I1 with duplicated cell names: the names of the last ten cells are replaced by the names of the first ten cells in file order; nothing else changes, so a file of N rows has N - 10 unique names and 10 names that occur twice | Task 1 |
| E18 | `1M_neurons_filtered_gene_bc_matrices_h5.h5` from 10x Genomics (`https://cf.10xgenomics.com/samples/cell-exp/1.3.0/1M_neurons/1M_neurons_filtered_gene_bc_matrices_h5.h5`), expected 4,216,018,749 bytes; the SHA-256 is recorded | Task 3 |

A download whose size differs from the expected one is repeated once; if it still differs, the difference is recorded and the file is used only after the failure is noted in PROGRESS.md.

## 5. Task 1: import and capability recognition

For every tool and every dataset I1-I4 the harness imports the data once and records the fields below in `results/task1_<tool>.csv` and `results/task1_<tool>.json`. Task 1 is not timed and is not repeated.

**Import route.** The documented import call of the tool, with only the arguments the tool requires:

| Tool | I1, I3, I4 (input `.h5ad`) | I2 |
|---|---|---|
| CerebroNexus | `convertH5adToCerebro()` with `groups` (I1, I4: `louvain`; I3: `cluster`), then `launchCerebro(crb_file_to_load=)` | Seurat object -> `addImmuneRepertoire(from_metadata = TRUE)` -> `exportFromSeurat(..., nUMI = 'nCount_RNA', nGene = 'nFeature_RNA', groups = 'seurat_clusters')` |
| ShinyCell | `.h5ad` read with anndataR as `SingleCellExperiment` -> `createConfig()` -> `makeShinyApp()`. For I1 the Seurat route (object built from the same matrix, metadata and embeddings) is run as a second row | Seurat object -> `createConfig()` -> `makeShinyApp()` |
| iSEE | `.h5ad` read with anndataR as `SingleCellExperiment` -> `iSEE(sce)` | `as.SingleCellExperiment(seurat)` -> `iSEE()` |
| cellxgene | `cellxgene launch <file>.h5ad` | `.h5ad` written from the Seurat object |
| Vitessce | `.h5ad` -> Zarr -> `VitessceConfig` with `AnnDataWrapper` | same, from the I2 `.h5ad` |

Rules for the route:
- If the default call fails, the failure (first 500 characters of the message) is recorded as `default_route_failed`, then the smallest documented workaround is applied (for example setting `VariableFeatures` and default genes for ShinyCell) and the run is repeated; both outcomes are recorded.
- For Vitessce the component paths (`obsm/X_umap`, `obs/<cluster column>`, `X`, spatial and image paths) cannot be inferred and are written by hand into `AnnDataWrapper`; every path written by hand is recorded and the capability is graded `manual`.
- anndataR, not a CerebroNexus function, reads `.h5ad` for the R-side competitors.

**Recorded fields**
- `import_status`: `ok`, `error` (with message), `platform_limit`; warnings captured.
- Cells and genes in the loaded tool (read back from the artifact or the running tool).
- Capability grades, each `auto` (present with the default call and required arguments only), `manual` (available only after extra configuration or code), `absent`, or `n/a` (the dataset has no such component). Capabilities: embeddings (list of names offered), categorical annotation / clustering (list offered), TCR (`clonotype-aware` view or CTaa-style column only: separate grades), spatial coordinates, tissue image, expression of a gene. Evidence for each grade: the options listed in the running UI or API (cellxgene: `/api/v0.2/schema`), an element screenshot, or the read-back.
- Required arguments the user had to supply.
- I4 only: `rejected` (explicit refusal), `repaired` (names made unique, with or without a message), or `silent` (duplicates kept). Number of cells in the tool after import; whether cell names are still unique.

## 6. Task 2: selection retrieval

**Truth sets.** S1 = cells of I1 with `louvain == "B cells"`. S2 = cells of I2 with the most frequent non-`NA` `CTaa` (ties: first in alphabetical order). Set sizes are recorded.

**Routes.** For each tool and each set two routes are tried when the tool has them:
- *Region route*: the tool's own box or lasso selection on its `X_umap` embedding (lasso preferred). The shape is the convex hull of the target cells in the displayed coordinates (lasso) or their bounding box (box). Data coordinates are converted to pixels with the plot library's own axis objects; if those are not exposed, from an affine fit to landmark points found by image analysis, with the fit residual recorded. The mouse is driven by Playwright.
- *Attribute route*: the tool's own select/filter by metadata value (`louvain == "B cells"`, the `CTaa` value) where one exists.

**Export.** The identifiers must be taken out of the tool by a user-facing control: a download button, a table export button, or the clipboard. Grades: `export` (file or clipboard from a tool control), `display only` (IDs visible in the UI but no control to take them out; these are scraped from the page and reported as `no export route (IDs displayed only)`; the Jaccard index is computed and flagged), `none` (selection possible but IDs not shown: `no export route`). The route is found from the tool's documentation and UI in the pilot (at most 30 minutes per tool); the exact steps are written to the `route_steps` column. No code is run inside the tool to obtain IDs.

**Metric.** Jaccard index between the exported ID set and the truth set, together with precision and recall. Each route is run three times in new browser contexts; all three values are stored.

## 7. Task 3: scale

### 7.1 Inputs

Source order is the column order of the 10x H5 file. The first 10,000, 100,000 and 500,000 cells are taken with all genes (no cell or gene filtering). Library size normalisation to 1e4 followed by `log1p` (natural log, float32). One computation on the 500,000-cell object:
1. 2,000 highly variable genes: `scanpy.pp.highly_variable_genes(flavor='seurat', n_top_genes=2000)` on the log-normalised data.
2. PCA, 50 components on those genes (no scaling, centred, `svd_solver='arpack'`, `random_state=0`).
3. `scanpy.pp.neighbors(n_neighbors=15, n_pcs=50, random_state=0)` and `scanpy.tl.umap(random_state=0)`.
4. `MiniBatchKMeans(n_clusters=20, random_state=0, batch_size=10240, n_init=3)` on the 50 components; labels `"0"`-`"19"` stored as categorical `cluster`.

The 10,000 and 100,000 tiers reuse the rows of these results for the same cells (nothing is recomputed). Each tier is one `.h5ad`: `X` = log-normalised CSR float32, uncompressed; `obsm`: `X_umap` first, then `X_pca`; `obs`: `cluster`, `nUMI`, `nGene`; `var` = all genes, symbols made unique, Ensembl IDs in `gene_ids`. No raw-count layer. Two default genes (the two top-ranked HVGs) are stored in `inputs/default_genes.txt` for tools that need them. This preprocessing is not timed and is the common input of all tools.

### 7.2 Native formats and configurations

| Config | Build: from the tier `.h5ad` to what the server reads | Serve |
|---|---|---|
| `cerebronexus_default` | `convertH5adToCerebro(groups = "cluster", nUMI = "nUMI", nGene = "nGene")` -> `.crb` (default embedded matrix) | `launchCerebro(crb_file_to_load=)` |
| `cerebronexus_h5` | same, with `expression_matrix_mode = "h5"` and `HDF5Array::setHDF5DumpCompressionLevel(0L)` set first -> `.crb` plus H5 sidecar | `launchCerebro(crb_file_to_load=, expression_matrix_mode="h5", expression_matrix_h5=)` |
| `shinycell` | anndataR -> `SingleCellExperiment` -> `createConfig()` -> `makeShinyApp()` with the default genes | `shiny::runApp(<app dir>)` |
| `isee` | anndataR -> `SingleCellExperiment` -> `saveRDS()` | `readRDS()` -> `iSEE()` -> `runApp` |
| `cellxgene` | none (reads the `.h5ad`); build time recorded as `n/a`, artifact size = the `.h5ad` | `cellxgene launch --port <p> --disable-gene-sets-save <file>` |
| `vitessce` | `.h5ad` -> Zarr with `vitessce.data_utils.optimize_adata(optimize_X=True)` and `write_zarr`, as the documentation for the pinned version describes; config with `AnnDataWrapper` (`obsm/X_umap`, `obs/cluster`, `X`) | local server on one origin for page, JS and Zarr (`scripts/serve_vitessce.py`) |

If a function named here does not exist in the pinned version, the nearest documented equivalent is used and logged in Deviations.

### 7.3 Replication and schedule

For every config and tier: 3 builds; each build is served in 3 new processes (a new process tree and a new browser context each time). The build artifact is deleted after its three starts; size is measured before deletion. Builds of one tier run in rounds (round 1: one build of every config in a seeded random order, then its three starts; round 2; round 3). The order seed is 20261022. Tiers run in the order 10,000, 100,000, 500,000. All runs are sequential.

### 7.4 Measured per build and per start

Build (fresh process, from spawn to exit): wall time, peak process-tree RSS, exit status, log. R-side builds also record the part spent reading the `.h5ad` and the part spent in the tool's own step. Artifact size: total bytes of all files the server reads (apart from the `.h5ad` for cellxgene).

Start (fresh process tree): time from spawn to the first HTTP 200 on the root URL (`t_ready`); time from browser navigation start to the first qualifying frame of the embedding plot (`t_first_plot`); the sum (`t_total`); peak process-tree RSS from spawn until the first qualifying frame (browser excluded).

### 7.5 Timers, RSS, first plot

- Durations use `time.perf_counter()` in one Python harness (`scripts/harness.py`) that spawns every process, so all tools share one clock.
- Peak RSS: sum of `psutil` working-set RSS over the spawned process and all its descendants, sampled every 100 ms; the maximum sample is reported.
- First plot: the harness drives Chrome to the tool's page. Tool-specific steps to reach the embedding view are scripted (CerebroNexus opens on "Data info": click "Projection" first). The target element is the main embedding plot (CerebroNexus `#cv-cv-a`; the other selectors are fixed in the pilot). Every 250 ms an element screenshot is taken. The background colour is the most frequent colour of the screenshot; a pixel is *ink* if its RGB distance from the background is above 60 and it is dark (HSV value < 0.5) or saturated (HSV saturation > 0.4). A frame qualifies if the element is at least 200 x 200 px and at least 2% of its pixels are ink; the first qualifying frame is accepted when the next frame also qualifies, and `t_first_plot` is the time of the first of the two. The time resolution is therefore about 250 ms plus the screenshot time, and large canvases make the screenshot itself slower; the screenshot duration is stored per frame.
- The accepted frame is saved to `logs/screens/` for every run.

### 7.6 Timeouts and failures

- Build: 60 minutes. Server ready: 15 minutes from spawn. First plot: 15 minutes from navigation start; the whole start is cut at 30 minutes after spawn.
- Status per run: `ok`, `timeout`, `error` (non-zero exit, tool error, no ready response), `oom` (process killed or memory error in the log), `platform_limit`, or `not_run` (with reason). A failed build means its three starts are `not_run (build failed)`.
- Stop rule, fixed in advance: if the first build of a config in a tier ends in `timeout` or `oom`, builds 2 and 3 of that tier are `not_run (stop rule)`, and the next tier is attempted once. Other failures do not stop anything.
- Nothing is dropped from the raw tables. Summary tables show `n_ok / n_total` next to every statistic.

## 8. Pilot

Before measured runs, every tool is run once on I1 and once on the 10,000-cell tier. These runs are discarded from statistics but kept in `logs/pilot/`. The pilot has four uses only: (1) check on the saved screenshots that cells are really drawn (the ink rule does not decide this alone); (2) fix DOM selectors and scripted clicks; (3) find the export route for Task 2; (4) check the harness measures first plot on cellxgene and Vitessce. The final selectors and wait conditions go into `scripts/harness_config.json`; its SHA-256 is written to PROGRESS.md before the first measured run. If the pilot shows that a correct plot stays below the 2% rule, the rule is not changed silently: this goes into Deviations before the measured runs.

## 9. Outputs

- `results/task1_<tool>.csv|json`, `results/task2_<tool>.csv`, `results/task3_builds.csv`, `results/task3_starts.csv`: one row per run, including failed and not-run ones, with status, timestamps, tool and version, and the log file name.
- `results/summary_task3.csv` (and `.md`): per config and tier, median and min-max of each metric over `ok` runs, with `n_ok / n_total`. Start metrics use all starts; per-build medians are given as well.
- `results/inputs.csv`, `results/environment.json`, `results/PROTOCOL.sha256`.
- `logs/<task>/<tool>_<dataset-or-tier>_<run id>.log`; screenshots in `logs/screens/`.
- Scripts in `scripts/`. `data/`, `env/`, `inputs/` and `artifacts/` are in `comparison/.gitignore`. Nothing is committed or pushed without the owner's approval.

## 10. Known limits, stated in advance

- One machine, one operating system. Absolute numbers do not transfer to other hosts.
- The tools are not given identical interfaces: each uses its own documented route, so build time includes whatever the route needs (for the R-side tools, reading the `.h5ad`).
- Software WebGL in headless Chrome makes first-plot times of WebGL tools longer than on a machine with a GPU.
- Vitessce JavaScript is served from local copies of `vitessce@3.9.9` so that network speed is not in the timings; if that is not possible, the CDN use is recorded in Deviations.
- A pre-registered stop rule can leave some larger-tier cells with a single build.
- I2 has 500 cells, 365 of them with a TCR; it tests recognition, not scale.

## Deviations

Verification of the frozen text: `results/PROTOCOL.sha256` is the hash of the whole file as written on 2026-10-22 (with "None so far." under this heading). `results/PROTOCOL_body.sha256` is the hash of the text before this heading, which stays valid when entries are added here.

All entries below were made on 2026-10-22, after the pilot runs and before any measured run.

**D1. Embedding order in the tier `.h5ad` files (7.1).** The protocol asked for `X_umap` first and `X_pca` second. HDF5 stores the groups of `obsm` in alphabetical order, so `X_pca` comes first in the files. Tools that open on the first embedding therefore differ: in the pilot iSEE opened on `X_pca`, the others on UMAP (CerebroNexus on its first projection, cellxgene on `umap`, Vitessce on the configured UMAP, ShinyCell on the first reduction it lists). The first plot measured for iSEE in Task 3 is thus a PCA scatter. The default embedding of each tool is recorded with each run.

**D2. Ink threshold 1% instead of 2% (7.5).** In the pilot on the 10,000-cell tier the screenshot of Vitessce's scatterplot clearly shows the cells (checked by eye) but its ink fraction is 1.7%, below the 2% rule, because Vitessce draws small points. On I1 (2,638 cells) it is 0.5% and ShinyCell is 2.04%. With a 2% threshold Vitessce would have been recorded as "timeout" although it had drawn the cells. The threshold is lowered to 1% for every tool and every run; everything else in the rule is unchanged. The accepted ink fraction and the whole frame series are stored for every run. At 1%, the Vitessce pilot on I1 still does not qualify (0.5%); this pilot is only a visual check and I1 is not used for first-plot timing.

**D3. Vitessce conversion call (7.2).** `optimize_adata(optimize_X=True)` converts a sparse `X` to a dense array, which is not workable for the 500,000 x 27,998 tier (56 GB dense). `optimize_X=False` is used instead: the function then keeps `X` sparse and converts it to CSC, which is what its code comments say Vitessce can read efficiently. The function is loaded from its own file (`vitessce/data_utils/anndata.py`) because the package's `data_utils/__init__` imports `spatialdata`, `ome-zarr` and `negspy`, which are not part of the pinned install; the code is the same. The config uses `AnnDataWrapper(adata_url=...)` because the local-path mode needs `starlette`, which is also not installed.

**D4. Legacy `.h5ad` files and anndataR (section 5 rule applied).** anndataR 1.0.2 refuses `pbmc3k.h5ad` and `visium_hne_adata.h5ad` ("created with anndata<0.8.0"). Following the default-route-failed rule of section 5, these two files are rewritten unchanged with anndata 0.12.19 (`scripts/rewrite_h5ad.py`, outputs `inputs/I1_rewritten.h5ad`, `inputs/I3_rewritten.h5ad`) and used for ShinyCell and iSEE. CerebroNexus, cellxgene and Vitessce read the original files. The refusal is recorded in Task 1. In the pilot ShinyCell's default route on the I1 `SingleCellExperiment` also failed (anndataR stores the PCA as `LinearEmbeddingMatrix`, which ShinyCell cannot coerce); the workaround converts reduced dimensions to plain matrices and sets default genes (`workaround=1`). This is recorded in Task 1 as well. The tier files have no loadings (`varm`), so Task 3 uses the default route.

**D5. Installation notes (3).** `remotes::install_local` failed on CerebroNexus' `Remotes: bnprks/BPCells/r` entry with an HTTP 401 from GitHub; the hard dependencies were installed from CRAN and Bioconductor 3.22 binaries and CerebroNexus 6.0.0 (27ac995e) was then installed with `R CMD INSTALL` from `git archive` of that commit. BPCells is not installed (removed in 6.0.0). ShinyCell 5c61db78cdd624636e161406d5d42aeb2c0f1205 reports version 2.1.0. Vitessce JS is not loaded from a CDN: npm `vitessce@3.9.9` with `react@18.2.0` and `react-dom@18.2.0` is bundled with esbuild 0.28.2 (Node 22.23.1) into `inputs/vitessce-js` and served by `scripts/serve_vitessce.py`. An attempt to install `ome-zarr` for `data_utils` upgraded `zarr` to 3.x; the Python environment was rebuilt from scratch with exactly the packages listed in section 3.

**D6. Extra metric (7.4).** Besides the server process tree, the peak RSS of the Chrome process tree is recorded (`browser_peak_rss_bytes`), because cellxgene and Vitessce do much of their work in the browser. It is not part of the server peak RSS defined in 7.5.

**D7. Launch flags.** cellxgene shows a "User Generated Data Directory" dialog on top of the plot with the flags of 7.2. It is left as it is; the plot is drawn underneath and the screenshot of the plot element includes the dimmed overlay and the dialog. No annotation flag was added.

The entries below were made on 2026-10-22 after Task 1 and Task 2 were run and before any Task 3 measured run.

**D8. Region selection details (6).** (a) The shape is the convex hull of the target cells grown by 4 px around each dot (lasso) or the same grown bounding box (box), so that whole dots are enclosed. With the exact hull, the dots that form the hull vertices lie on the boundary and a 1 px calibration error already drops them (CerebroNexus S1: 282 of 342 targets selected instead of 342). (b) Data-to-pixel maps are fitted to a screenshot (`scripts/task2/calib.py`; objective: overlap between the drawn dots and dots rendered at the predicted positions), because none of the five plots exposes its axis objects. The fit quality is stored per run. (c) The element position is read again right before the drag, because CerebroNexus shifts the canvas by about 19 px when its selection banner appears. (d) iSEE's plots offer a box brush and a Shift+click lasso; both were run for S1 and S2. The lasso closes only when a click lands near its first waypoint; for the small S2 polygon it closed too early and no selection was formed, which is the recorded result. (e) cellxgene 1.3.0 has no browser download for a selection: the cell IDs come from the annotation CSV that the server writes when a category is created from the selection and a label is assigned (the dialog "Add label & assign N cells"). cellxgene also shows a mandatory "User Generated Data Directory" dialog; it was answered with a name and the launch flag `--user-generated-data-dir artifacts/t2/cx_ugd` was added for Task 2 only (Task 3 launches use the flags of 7.2). (f) Vitessce: region export is the three-dot menu of "My Selections" > "Export hierarchy (to CSV file)"; the attribute route exports the set with its own menu "Export set (to JSON file)". (g) CerebroNexus: the table export covers the displayed page only, so the page length was set to 1,000 before Download. (h) The attribute route of ShinyCell and CerebroNexus has no selection to export; iSEE's table column filter is shown in the UI but the export ignores it. All of this is stored in `route_steps` and `note` of `results/task2_*.csv`.

**D9. Task 1 grading details (5).** Grades are `auto`, `manual`, `absent`, `n/a` as planned plus `error` where the import failed. The I4 rows of ShinyCell and iSEE use a `SingleCellExperiment` built in R (the I1 object with the last ten cell names replaced by the first ten) because anndataR cannot read `I4.h5ad` at all; the anndataR failure is recorded as well. Besides the read-back, the UI was started for ShinyCell and iSEE (`results/task1_raw/ui_*.json`) to read the embedding choices; CerebroNexus, cellxgene (schema) and Vitessce (page text, screenshots) were read back as described in 5. ShinyCell's UI check on I3 did not pass the 1% ink rule because the plot is coloured pale yellow by the constant `in_tissue` column; the screenshot shows the cells.

The entries below were made on 2026-10-22 immediately before the first Task 3 measured run.

**D10. Task 3 build details (7.2).** (a) iSEE: the `SingleCellExperiment` is written with `saveRDS(compress = FALSE)` (default `saveRDS()` gzip-compresses a 12 GB object on one thread); this is the same choice as the uncompressed H5 of the second CerebroNexus configuration. (b) ShinyCell: `makeShinyApp()` receives the two default genes of `inputs/default_genes.txt` (S100a8, Ccl4) as 7.2 says; the flag `workaround=1` in the scripts therefore means "default genes set" for Task 3 (converting reduced dimensions to plain matrices does nothing on these files, which have no loadings). (c) cellxgene has no build step: its three build rows per tier are `n/a`, the artifact size is that of the `.h5ad`, and each of the three "builds" is started three times (nine starts in all, as for the other tools). (d) CerebroNexus is called without `organism` (default "Human") and with `launchCerebro(mode = "closed")`. (e) The embedding that each tool shows first is stored in every start row (D1). (f) Before every build and start a 3 s CPU-busy sample (`psutil.cpu_percent`) is stored; the run goes on whatever its value.

**D11. Ink rule: saturation threshold 0.1 instead of 0.4 (7.5), 2026-10-22, after the first 10,000-cell and the first 100,000-cell runs.** In the first 100,000-cell Vitessce start the plot was drawn (saved screenshot `logs/superseded_v1/screens/100000_vitessce_b1_s1.png`, cells clearly visible) but the run ended as a 15-minute `timeout`, because Vitessce draws its points in pale, translucent colours: 12.4% of the pixels differ from the background by more than 60 in RGB, but only 0.7% of them are dark or have a saturation above 0.4. The measurement rule, not the tool, produced the failure. The saturation limit is lowered to 0.1 for every tool (a pixel is ink if its RGB distance from the background is above 60 and it is dark, V < 0.5, or has S > 0.1); the 1% area limit of D2, the 250 ms sampling and the two-frame rule are unchanged. On the saved screenshots this gives 4.5% (Vitessce 10,000), 11.4% (Vitessce 100,000) and 8.7-15.4% for the other tools. The 10,000-cell tier (all 6 configs, 54 starts, all `ok`) and the one failed 100,000-cell start measured under the old rule were moved, unchanged, to `results/superseded_v1/` and `logs/superseded_v1/`, and the whole 10,000-cell tier was measured again under the new rule; nothing from the superseded runs enters the summary tables. Risk noted in advance: the cellxgene canvas element contains its toolbar, so a frame with toolbar and no dots could in principle count; the saved frame series (first frame with the element visible already shows the dots, ink about 9%) gives no sign of this.
Bookkeeping for D11: a first attempt to restart Task 3 started a second runner by mistake before the harness change was in place. It was stopped within about two minutes; its one build row and one failed start row were deleted (they were measured under the old rule and are not part of any table), its logs are in `logs/superseded_v1/accidental_restart/`, and the superseded v1 log of the 10,000-cell `cerebronexus_h5` build 1 was overwritten by it (the v1 CSV rows are intact).

**D12. cellxgene start-up and its upgrade check (7.2), 2026-10-22, during tier 100,000.** Every `cellxgene launch` calls the unauthenticated GitHub releases API (`server/cli/upgrade.py`). After about 35 starts within an hour the API returned a rate-limit reply that cellxgene does not handle (`TypeError: expected string or bytes-like object, got 'function'` in `split_version`), and four of the nine 10,000-cell cellxgene starts ended as `error` ("server exited with 1"). Those errors come from the repeated measurement, not from the data size, and the network round trip also adds a variable amount to cellxgene's service-ready time. From now on the cellxgene process is started with `HTTPS_PROXY=http://127.0.0.1:9` (and `NO_PROXY=127.0.0.1,localhost`), so the check fails at once with "Upgrade check failed." as on an offline machine; nothing else about the launch changes. All cellxgene rows measured before this change (tier 10,000: 3 build rows and 9 start rows, 4 of them errors; tier 100,000: 1 build row and 3 start rows) were moved unchanged to `results/superseded_v2_cellxgene_upgrade_check/` and were measured again under the new setting; they are not used in any table. Because of this the cellxgene runs of these two tiers were done after the other configs and not interleaved with them. The Task 1 and Task 2 cellxgene runs were few and are unaffected.

**D13. One invalid unit re-run (2026-10-22).** When the runner was restarted for D12 I deleted `artifacts/t3`, which held the finished build of `cerebronexus_h5` build 1 in tier 100,000 whose three starts had not yet run; the three starts then failed with "no such file" (`find_one` in the harness). That is an operator error, not a tool result. The build row and the three start rows were moved unchanged to `results/superseded_cleanup_error/`, and the build (a new build 1, with new timings) and its three starts were run again. No other unit was affected.
