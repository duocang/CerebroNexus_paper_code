# Figures for the tool comparison: what to capture and how

> Status: the two screenshot panels (A: the same view in five tools, B: the spatial view) were made for round 1 and are not part of round 2 yet; to make them for the CerebroNexus build of round 2, run `scripts/report/capture_figures.py` (output `figures/captures/`). The quantitative figures are in `figures/` (see README.md).

This is the work order for the figure captures. It is separate from the measured study in `PROTOCOL.md`: nothing here is timed, nothing here changes `results/`, and none of the measured runs is repeated.

## Why the existing screenshots are not used

`results/evidence/screens/`, `pilot/`, `task1/` and `task2/` stay as evidence that each run drew a plot. They cannot go into the paper:

- `scripts/run/harness.py` captures at `device_scale_factor=1` (1600 × 1000 viewport). The figure rules in `topics/interface_figures/README.md` require native 3× captures, placed without resampling, with interface text at 6 pt or more in print.
- The tools do not show the same view: iSEE opens on `X_pca`, the others on UMAP; CerebroNexus and Vitessce colour by cluster, ShinyCell by a continuous value, cellxgene and iSEE not at all.
- The cellxgene captures in `results/evidence/screens/` are covered by the "User Generated Data Directory" dialog.
- The harness saves the frame at which the ink threshold is first passed, which times the first plot but does not guarantee a finished, idle page.

## What the paper needs

Most of the comparison is drawn from the result tables in R, with no screenshot at all. Only two screenshot panels are needed.

| Panel | Source | Screenshot? | Where it runs |
|---|---|---|---|
| Capability matrix (Task 1) | `results/task1_summary.csv` | no, tile plot | R, any machine |
| Selection accuracy (Task 2) | `results/task2_summary.csv` | no, dot plot of Jaccard per tool and route | R, any machine |
| Scale (Task 3) | `results/task3/task3_builds.csv`, `results/task3/task3_starts.csv` | no, metric vs tier per tool | R, any machine |
| **A. Same view in five tools** | I1 (pbmc3k) | **yes, 5 captures** | Windows host |
| **B. Spatial view** | I3 (Visium H&E) | **yes, 2 captures** | Windows host |

Not captured: I2 (TCR) and I4 (duplicated names), whose differences are a yes/no in the capability matrix; the CerebroNexus TCR view is already in the interface figures. No E18 tier is captured. `cerebronexus_h5` draws the same plot as `cerebronexus_default` and is not captured separately; the caption says so.

### A. Same view in five tools (5 captures)

Dataset I1, `data/raw/pbmc3k.h5ad` (ShinyCell and iSEE read `data/inputs/I1_rewritten.h5ad`, as in Task 1). Every tool shows the UMAP (`X_umap`) coloured by `louvain`, with all 2,638 cells and no selection, no highlighted cell, no open menu, tooltip or dialog.

| id | Tool | How to reach the view | Element to capture |
|---|---|---|---|
| A1 | CerebroNexus (embedded backend) | Projection tab; projection UMAP; colour by `louvain` | the projection plot, `#cv-cv-a` |
| A2 | ShinyCell | first tab (cell info vs gene expression); dimension reduction UMAP; cell info `louvain` | the cell info plot, `#sc1a1oup1` |
| A3 | iSEE | start with an initial `ReducedDimensionPlot(Type = "X_umap", ColorBy = "Column data", ColorByColumnData = "louvain")` passed as `initial=` to `iSEE()`; the default panel opens on PCA | `#ReducedDimensionPlot1` |
| A4 | cellxgene 1.3.0 | embedding `umap`; colour by the `louvain` category; dismiss the annotation dialog (Cancel) | `canvas.graph-canvas` |
| A5 | Vitessce | the harness build (`scripts/run/tools/vitessce_build.py`) already uses `X_umap` and `louvain` cell sets | `canvas#deckgl-overlay-A` |

The selectors are the ones the harness used; the controls that switch embedding and colouring have not been scripted yet and must be found on the Windows host. Whatever had to be set beyond the tool's default (the iSEE `initial=`, any dropdown choice) is written into the capture record and goes into the caption.

### B. Spatial view (2 captures)

Dataset I3, `data/raw/visium_hne_adata.h5ad`. Only the two tools that show spatial coordinates are captured; ShinyCell, iSEE and cellxgene have no spatial view (Task 1: absent) and are named as such in the caption, not shown.

| id | Tool | View | Element to capture |
|---|---|---|---|
| B1 | CerebroNexus | Spatial view with the H&E image, spots coloured by `cluster` | the spatial plot area (plot canvas and tissue image together) |
| B2 | Vitessce | spatial view from the Task 1 configuration, spots coloured by `cluster`; no tissue image (Task 1: image absent) | the spatial view canvas |

Colour by the same column in both. If I3's cluster column has another name, use that name in both tools and record it.

## How the captures are run

### 1. Capture script

`scripts/report/capture_figures.py`, run with `env\py\Scripts\python.exe`. It imports `scripts/run/harness.py` for `build_spec`, `serve_spec`, `R`, `P`, `PORTS`, `kill_tree`, `port_free` and the environment helpers (`r_env`, `cellxgene_env`), and does not change `scripts/run/harness.py`.

```
python scripts/report/capture_figures.py            # all seven captures
python scripts/report/capture_figures.py A3 A4      # only these
python scripts/report/capture_figures.py --list     # print ids and exit
```

Limits, so it captures only what is listed and only the part that is needed:

- **Only the seven ids above.** No tier loop, no repeats, no timing columns. Each id builds its artifact once into `data/builds/fig_<id>/` (I1 and I3 builds take seconds), reusing it if it already exists, starts one server, captures, and kills the process tree before the next id. One tool runs at a time; nothing else heavy runs alongside.
- **Same browser for all.** Playwright with installed Chrome (`channel="chrome"`), headless, CSS viewport 1024 × 720, `device_scale_factor=3`, `color_scheme="light"`, `reduced_motion="reduce"`, locale `en-US`. This is the setting of the interface figures. If a plot element is cut off at 1024 × 720, enlarge the height only, and record it.
- **Only the plot element.** Capture with `locator(<element>).screenshot()`, never the full page. Before capturing, hide the parts that would sit inside the element's box and are not data: toolbars and buttons drawn over the canvas (cellxgene, Vitessce), tooltips, the mouse cursor (move the mouse to 0,0). Hide them with an injected stylesheet (`visibility: hidden`) and list the selectors in the record. Legends that are separate elements are not captured; colours are explained in the caption and the figure legend is drawn in R.
- **A finished, idle page.** After the view is set: wait for the network to be idle, for Shiny to be idle where the tool is a Shiny app (`$('html').hasClass('shiny-busy')` false), then take element screenshots every 500 ms until two in a row are pixel-identical. Save that frame. Give up after 120 s and record the failure; do not save a partial frame as if it were finished.
- **Check the view, not just the pixels.** Before saving, confirm from the page that the embedding is UMAP (or spatial) and the colouring column is the required one, by reading the selected value of the control or the visible label. Write what was read into the record; if it does not match, fail the id.
- **cellxgene:** start with `cellxgene_env()` (upgrade check blocked, Deviations D12) and add `--disable-annotations` so the annotation dialog never opens; if it opens anyway, click Cancel and check it is gone.

### 2. Output

```
figures/captures/<id>.png    3x element screenshot, unchanged
figures/captures/<id>.json   capture record
figures/captures/index.csv   one row per id: id, tool, version, dataset, view, colour_by, status, png_sha256
```

Each `<id>.json` holds: id, tool and version, dataset and input file with its SHA-256, the settings that were changed from the tool's default and how, the element selector and its bounding box in CSS px, viewport and device scale factor, the hidden selectors, every visible DOM text box inside the element with its font size in CSS px, the values read back for embedding and colouring, the time of capture, the Chrome version, and the PNG size and SHA-256.

`figures/captures/` is committed (seven PNGs of a few MB in total). `data/builds/` stays ignored.

### 3. Check by eye, then commit

Open the seven PNGs. Each shows only the plot, the whole cloud, coloured by the right column, no dialog, no menu, no cursor. Commit `scripts/report/capture_figures.py` and `figures/captures/`, and push.

## Assembly (any machine, R)

The figure is assembled in R from `figures/captures/`, following `topics/interface_figures/README.md`: 170 mm wide, panels labelled a, b, … in vector text with the tool name in vector text above each panel, PNGs placed without resampling, and checked with the same rules (`check_figures.R`). Interface text inside a panel is not meant to be read; for DOM text the 6 pt rule applies as in the interface figures. Axis text that iSEE and ShinyCell draw into their plot image is part of the picture, is not checked, and the caption says the panels are shown for the view, not for their labels.

The caption states: dataset and cell count; that every panel shows UMAP coloured by `louvain`; which settings had to be changed from each tool's default; tool versions; that point size, scaling and background follow each tool's defaults and differ between panels, so the panels compare the same view, not appearance; and that `cerebronexus_h5` draws the same plot as the embedded backend.
