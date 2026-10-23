# Figures for the tool comparison: panels and captures

The two screenshot panels of the figure and how they are captured. This is separate from the measured study in `PROTOCOL.md`: nothing here is timed, nothing here changes `results/`, and none of the measured runs is repeated.

## Why the existing screenshots are not used

`logs/screens/`, `logs/pilot/`, `logs/task1/` and `logs/task2/` stay as evidence that each run drew a plot. They cannot go into the paper:

- `harness.py` captures at `device_scale_factor=1` (1600 × 1000 viewport). The figure rules in `topics/interface_figures/README.md` require native 3× captures, placed without resampling, with interface text at 6 pt or more in print.
- The tools do not show the same view: iSEE opens on `X_pca`, the others on UMAP; CerebroNexus and Vitessce colour by cluster, ShinyCell by a continuous value, cellxgene and iSEE not at all.
- The cellxgene captures in `logs/screens/` are covered by the "User Generated Data Directory" dialog.
- The harness saves the frame at which the ink threshold is first passed, which times the first plot but does not guarantee a finished, idle page.

## What the paper needs

Most of the comparison is drawn from the result tables in R, with no screenshot at all. Only two screenshot panels are needed.

| Panel | Source | Screenshot? | Where it runs |
|---|---|---|---|
| Capability matrix (Task 1) | `results/task1_summary.csv` | no, tile plot | R |
| Selection accuracy (Task 2) | `results/task2_summary.csv` | no, dot plot of Jaccard per tool and route | R |
| Scale (Task 3) | `results/task3_builds.csv`, `results/task3_starts.csv` | no, metric vs tier per tool | R |
| **A. Same view in five tools** | I1 (pbmc3k) | **yes, 5 captures** | `capture_figures.py` |
| **B. Spatial view** | I3 (Visium H&E) | **yes, 2 captures** | `capture_figures.py` |

Not captured: I2 (TCR) and I4 (duplicated names), whose differences are a yes/no in the capability matrix; the CerebroNexus TCR view is already in the interface figures. No E18 tier is captured. `cerebronexus_h5` draws the same plot as `cerebronexus_default` and is not captured separately; the caption says so.

### A. Same view in five tools (5 captures)

Dataset I1, `data/pbmc3k.h5ad` (ShinyCell and iSEE read `inputs/I1_rewritten.h5ad`, as in Task 1). Every tool shows the UMAP (`X_umap`) coloured by `louvain`, with all 2,638 cells and no selection, no highlighted cell, no open menu, tooltip or dialog.

| id | Tool | How to reach the view | Element to capture |
|---|---|---|---|
| A1 | CerebroNexus (embedded backend) | Projection tab; projection UMAP; colour by `louvain` | the projection plot, `#cv-cv-a` |
| A2 | ShinyCell | first tab (cell info vs gene expression); dimension reduction UMAP; cell info `louvain` | the cell info plot, `#sc1a1oup1` |
| A3 | iSEE | start with an initial `ReducedDimensionPlot(Type = "X_umap", ColorBy = "Column data", ColorByColumnData = "louvain")` passed as `initial=` to `iSEE()`; the default panel opens on PCA | `#ReducedDimensionPlot1` |
| A4 | cellxgene 1.3.0 | embedding `umap`; colour by the `louvain` category; dismiss the annotation dialog (Cancel) | `canvas.graph-canvas` |
| A5 | Vitessce | the harness build (`vitessce_build.py`) already uses `X_umap` and `louvain` cell sets | `canvas#deckgl-overlay-A` |

The selectors are the ones the harness used; the controls that switch embedding and colouring are set in `capture_figures.py`. Whatever had to be set beyond the tool's default (the iSEE `initial=`, any dropdown choice) is written into the capture record and goes into the caption.

### B. Spatial view (2 captures)

Dataset I3, `data/visium_hne_adata.h5ad`. Only the two tools that show spatial coordinates are captured; ShinyCell, iSEE and cellxgene have no spatial view (Task 1: absent) and are named as such in the caption, not shown.

| id | Tool | View | Element to capture |
|---|---|---|---|
| B1 | CerebroNexus | Spatial view with the H&E image, spots coloured by `cluster` | the spatial plot area (plot canvas and tissue image together) |
| B2 | Vitessce | spatial view from the Task 1 configuration, spots coloured by `cluster`; no tissue image (Task 1: image absent) | the spatial view canvas |

Colour by the same column in both. If I3's cluster column has another name, use that name in both tools and record it.

## How the captures are made

`scripts/capture_figures.py` (run with `env/py`; `--list` prints the ids, `A3 A4` runs only those) builds each artifact once into `artifacts/fig_<id>/`, starts one server, captures the plot element and kills the process tree before the next id. It imports `harness.py` and changes nothing in `results/` or `logs/`; nothing is timed.

- Playwright with installed Chrome (`channel="chrome"`), headless, CSS viewport 1024 x 720, `device_scale_factor=3`, light colour scheme, reduced motion, locale `en-US`.
- Element screenshot of the plot only; overlaid toolbars, tooltips and the cursor are hidden by an injected stylesheet and the selectors are recorded.
- A frame is saved only when the page is idle (network idle, Shiny not busy) and two consecutive element screenshots are pixel-identical; it gives up after 120 s and records the failure.
- Before saving, the embedding and the colouring column are read back from the page and must match; otherwise the id fails.
- cellxgene is started with `cellxgene_env()` (upgrade check blocked, D12) and `--disable-annotations`.

Output: `captures/<id>.png` (3x element screenshot, unchanged), `captures/<id>.json` (record: settings changed from the tool default, selector and box, hidden selectors, visible text sizes, values read back, Chrome version, SHA-256) and `captures/index.csv`.

## Assembly (R)

The figure is assembled in R from `captures/`, following `topics/interface_figures/README.md`: 170 mm wide, panels labelled a, b, … in vector text with the tool name in vector text above each panel, PNGs placed without resampling, and checked with the same rules (`check_figures.R`). Interface text inside a panel is not meant to be read; for DOM text the 6 pt rule applies as in the interface figures. Axis text that iSEE and ShinyCell draw into their plot image is part of the picture, is not checked, and the caption says the panels are shown for the view, not for their labels.

The caption states: dataset and cell count; that every panel shows UMAP coloured by `louvain`; which settings had to be changed from each tool's default; tool versions; that point size, scaling and background follow each tool's defaults and differ between panels, so the panels compare the same view, not appearance; and that `cerebronexus_h5` draws the same plot as the embedded backend.
