# Interface figures

Figures 1–7 and Supplementary Figures S1–S2 of the manuscript: screenshots of the CerebroNexus Viewer and Builder, and panels redrawn from the same data. Every screenshot is taken by a script from a fresh page, every count the figures quote is checked against the data, and every figure is checked against the Genome Biology figure rules. Nothing is captured or cropped by hand.

## Run

```bash
CEREBRO_LARGE_CACHE=/path/to/large-examples bash topics/interface_figures/run.sh          # capture + figures
CEREBRO_LARGE_CACHE=/path/to/large-examples bash topics/interface_figures/run.sh figures  # redraw from the stored captures
```

`CEREBRO_LARGE_CACHE` is the folder that `Rscript run-demo.R --prepare-only` of the viewer commit filled with the Ren COVID-19 and 10x E18 demo data sets (see `data-raw/large-demo/README.md` in CerebroNexus; about 55 GB of prepared files plus 75 GB of sources). `run.sh` fetches the two locked commits into `INTERFACE_WORK` (default `~/.cache/cerebronexus-interface`) as plain source snapshots, starts the Viewer (`run-demo.R --no-browser`) and the Builder from them, captures, prepares the plot inputs, draws the figures and runs the checks. It needs R with `chromote`, `pkgload`, `rhdf5`, `HDF5Array`, `qs2`, `scRepertoire`, `ggplot2`, `patchwork`, `ggrastr`, `svglite`, `ragg`, `png`, Chrome or Chromium, poppler (`pdfinfo`, `pdffonts`) and git. All steps run with `LC_ALL=en_US.UTF-8`; under the C locale the Viewer prints UTF-8 punctuation as escapes.

## Software

`cerebronexus.lock` pins two commits:

- Viewer: mihem/CerebroNexus `d7b773d6` (master after #212 and #218), the commit whose `run-demo.R` builds the demo data. Its interface reports version 5.2.0.
- Builder: duocang/CerebroNexus `13682cae` (branch `feat/multi-format-on-builder`, mihem/CerebroNexus#216, version 6.0.0). The Builder is not on master yet, and this branch cannot open the H5-backed demo data, so the two are captured from different commits.

After the v6.0.0 release both lines should name the release commit; `run.sh` then re-captures everything unchanged.

## Captures

All captures use Chromium through `chromote` at a 1024 × 720 CSS viewport and devicePixelRatio 3 (3072 × 2160 px PNG); the Xenium Spatial page uses 1024 × 960 so the plot fits below its controls. Each capture is preceded by a fresh page load and a wait until Shiny is idle and the page shows the expected count; focus rings are removed and the page is scrolled to the top (the RGB view is scrolled so the plot fits). Each `captures/<name>.json` records the viewport, the page text, every visible text box with its font size, and the plot canvases' positions.

| Capture | Data set | Steps | Wait for | Used in |
|---|---|---|---|---|
| `ren-projection` | Ren et al. COVID-19 atlas | Projection page; Projection `tsne`; Colour by `major_type` | `view with 1462702 points` | Fig. 1a |
| `ren-linked-local` | Ren | Linked views; colour by `major_type`; Share → Open JSON `data/selections/ren-linked-local.json` | `13,556` selected, `TCR 6,569` | Fig. 3 status row |
| `xenium-cluster` | Mouse brain (Xenium) | Spatial page; FOV `fov`; Plot type ImageDimPlot; Colour by `cluster` | idle | Fig. 4a |
| `xenium-feature` | Xenium | Plot type ImageFeaturePlot; Feature `Slc17a7` | idle | Fig. 4b and its colour bar |
| `xenium-rgb` | Xenium | Plot type Co-expression (RGB); R `Slc17a7`, G `Gad1`, B `Gad2` | idle | Fig. 4c |
| `xenium-linked-selected` | Xenium | Linked views; Open JSON `xenium-linked-selected.json` | `500` selected | identity check for Fig. 4d,e |
| `hla-10` | HLA & TCR | Linked views; colour by `sample`; Open JSON `hla-10.json` | `10` selected | Fig. 5 status row |
| `hla-293` | HLA & TCR | Linked views; colour by `sample`; Open JSON `hla-293.json` | `293` selected | Fig. 7 status row |
| `hla-motif` | HLA & TCR | HLA & TCR Motifs; Chain TRB; Network scope All cells; Colour by Motif cluster | `view with 94 points` | Fig. 6a |
| `hla-associations` | HLA & TCR | same page, HLA Associations tab (opens on HLA-A\*02:01 and `TRBV19::M13_15 (30 CDR3)`) | donor table rows | Fig. 6b values |
| `e18-projection` | 10x E18 mouse brain (1.3M) | Projection page; Projection `umap`; Colour by `seurat_clusters` | `view with 1306127 points` | Supp. Fig. S2 |
| `builder-configure` | Builder | Load example datasets (three built-in examples); Configure page of "Complete Viewer demo" | 180 cells, 164 genes | Fig. 2a |
| `builder-review` | Builder | Finish Checking for each dataset (no setting changed); Continue to Review | All datasets checked | Fig. 2b |

Linked views loads per-cell codes only for the active colouring and refuses a saved view whose colouring has none yet, so the script colours by the saved view's colouring before opening it. The Builder keeps its project in the server session, so `run.sh` starts a fresh Builder for every capture run. The saved selections in `data/selections/` are the files exported when the selections were first made; they carry cell identifiers, not screen positions.

## Figures

`scripts/figures.R` draws every figure at its printed size with ggplot2 and patchwork:

- width 170 mm (double column), height at most 225 mm; PDF through `cairo_pdf` with Arial embedded and text kept as text, plus a 300 dpi PNG preview;
- panel labels 8 pt bold upright, all other text 7 pt; lines at least 0.25 pt (0.5 pt by default);
- legends inside the figure; no figure titles or captions in the files (they are in the manuscript);
- drawn panels use colour-blind-safe Okabe–Ito colours; point clouds are rasterised at 600 dpi inside the vector PDF;
- screenshot panels are rectangular crops of the native 3× captures, placed without resampling at a scale where the smallest interface text inside the crop prints at 6 pt or more. Crops are derived from the capture records (page-content area, plot canvas, dark tissue image, Linked views status row), not typed coordinates.

Redrawn panels (Fig. 3a–d, 4d–e, 5, 7, S1) use the original coordinates and identifiers from the data set the Viewer shows: `scripts/prepare_inputs.R` reads them from the Ren CRB with its cell order and immune file, and from the HLA & TCR and Xenium example CRBs of the viewer commit. The clone bands are the R translation of the Viewer's Expansion bands layout (one band per clone-size tier, CTgene clones, the Viewer's deterministic jitter). It stops if any of these counts differs; `data/checks.json` records them:

| Count | Value |
|---|---|
| Ren cells / TCR-bearing cells / TCR and BCR records | 1,462,702 / 220,968 / 503,432 |
| Ren selection / with TCR / without TCR | 13,556 / 6,569 / 6,987 |
| Ren TRB sharing: private / within major type / across major types | 157,507 / 1,462 / 553 |
| HLA & TCR cells; exact-TRB selection (donor 1 / donor 2) | 12,000; 10 (2 / 8) |
| Gene-defined selection (donor 1 / donor 2); distinct TRB CDR3; largest | 293 (142 / 151); 10; 227 |
| Xenium cells / selection / clusters | 5,000 / 500 / 24 |

The Fig. 6b table is read from the captured HLA Associations page (donor, carrier status, motif cells, total cells), not typed in.

## Checks

`scripts/check_figures.R` reads each PDF (page size, embedded fonts, file size), its SVG twin in `figures/qa/` (every font size and stroke width) and `figures/qa/screenshot-qa.csv` (per crop: printed width, effective ppi, smallest interface text in pt, any text below 6 pt, any text the crop cuts), writes `figures/qa/figure-check.csv` and fails on any breach. `cairo_pdf` rounds the page to whole points, so 170 mm is reported as 169.7 mm.

## Limits

- Interface text inside screenshots is raster, not editable text; it is sized, not converted.
- The Viewer captures show version 5.2.0 and the Builder captures 6.0.0 until both are re-captured from the release.
- The Viewer's navigation mini-map is part of the plot canvas and is kept in the projection screenshots.
- The RGB co-expression view draws no tissue image; its crop uses the same plot extent as the feature plot.
