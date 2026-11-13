# Interface figures

Figures 1–7 and Supplementary Figures S1–S2 of the manuscript: screenshots of the CerebroNexus Viewer and Builder, and panels redrawn from the same data. Every screenshot is taken by a script from a fresh page, every count the figures quote is computed from the data and checked against the captured pages, and every figure is checked against the Genome Biology figure rules. Nothing is captured or cropped by hand, and no count is typed into a script.

## Run

```bash
CEREBRO_LARGE_CACHE=/path/to/large-examples bash topics/interface_figures/run.sh          # data, selections, capture, figures, checks
CEREBRO_LARGE_CACHE=/path/to/large-examples bash topics/interface_figures/run.sh capture  # up to the captures
CEREBRO_LARGE_CACHE=/path/to/large-examples bash topics/interface_figures/run.sh figures  # redraw from the stored captures
```

`CEREBRO_LARGE_CACHE` is the folder that `run-demo.R` of the pinned revision fills with the Ren COVID-19 and 10x E18 demo data sets (see `data-raw/large-demo/README.md` in CerebroNexus; about 55 GB of prepared files plus 75 GB of sources). `run.sh`:

1. makes a source snapshot of the locked commit with `git archive` into `INTERFACE_WORK` (default `~/.cache/cerebronexus-interface`), from the local clone `CEREBRONEXUS_CLONE` (default `C:/Users/wangx/Projects/CerebroNexus`, `/mnt/c/...` in WSL) if it has the commit, otherwise from the URL in `cerebronexus.lock`, and installs it into a library there; every R step then uses `library(CerebroNexus)` of that installation (no source-tree paths);
2. runs `run-demo.R --data=1m,ren --prepare-only`, which builds what is missing or out of date (the E18 data set is rebuilt when the recipe version changes) and downloads nothing that is complete;
3. runs `scripts/prepare_inputs.R` (selections, counts, plot inputs), starts the Viewer (`run-demo.R --data=1m,ren`, with `R_BROWSER=true` because the launcher always opens a browser) and the Builder (`launchCerebroBuilder()`), captures, draws the figures and runs the checks.

It needs R with `chromote`, `rhdf5`, `HDF5Array`, `qs2`, `scRepertoire`, `ggplot2`, `patchwork`, `ggrastr`, `svglite`, `ragg`, `png`, `digest` and what CerebroNexus imports, Chrome or Chromium, poppler (`pdfinfo`, `pdffonts`), git and Arial (the Windows font folder is used when the system has none). All steps run with `LC_ALL=en_US.UTF-8`; under the C locale the Viewer prints UTF-8 punctuation as escapes. Validation runs are done in WSL (`~/tmp_cerebro/<date>_interface-figures`).

## Software

The one revision every topic uses is in `../cerebronexus.pin`; `cerebronexus.lock` repeats its commit for the Viewer and the Builder (`tests/test-pin.R` checks both, and `run.sh` refuses a lock that differs from the pin). Current pin: branch `integration/8.3.0`, commit `e927cbf180fb1a50cf783245ab580e83a1334764`, version 8.3.0. The Viewer and Builder captures both show version 8.3.0, and one commit serves both. The commit exists only in the local clone until the branch is pushed, hence `CEREBRONEXUS_CLONE`. Figures were re-captured and redrawn from it on 2026-11-13.

## Captures

All captures use Chromium through `chromote` at a 1024 × 720 CSS viewport and devicePixelRatio 3 (3072 × 2160 px PNG); the Xenium Spatial page uses 1024 × 960 so the plot fits below its controls. Each capture is preceded by a fresh page load and a wait until Shiny is idle and the page shows the expected count; focus rings are removed and the page is scrolled to the top. For the RGB view, whose gene menus take room from the plot, the viewport is made taller by exactly what the plot lost, so it has the size and extent of the feature plot and Figure 4b,c share one crop. Each `captures/<name>.json` records the viewport, the page text, every visible text box with its font size, and the plot canvases' positions. The Builder script waits for the Shiny session before it clicks (a click on the first-paint button is otherwise lost).

The counts below are those of `data/checks.json`, written by `scripts/prepare_inputs.R` before the captures; the capture scripts read them from there.

| Capture | Data set | Steps | Wait for | Used in |
|---|---|---|---|---|
| `ren-projection` | Ren et al. COVID-19 atlas | Projection page; Projection `tsne`; Colour by `major_type` | `view with <ren.cells> points` | Fig. 1a |
| `ren-linked-local` | Ren | Linked views; colour by `major_type`; Share → Open JSON `data/selections/ren-linked-local.json` | `<ren.selected>` selected, `TCR <ren.selected_tcr>` | Fig. 3 status row |
| `xenium-cluster` | Mouse brain (Xenium) | Spatial page; FOV `fov`; Plot type ImageDimPlot; Colour by `cluster` | idle | Fig. 4a |
| `xenium-feature` | Xenium | Plot type ImageFeaturePlot; Feature `Slc17a7` | idle | Fig. 4b and its colour bar |
| `xenium-rgb` | Xenium | Plot type Co-expression (RGB); R `Slc17a7`, G `Gad1`, B `Gad2` | idle, plot as large as in the feature view | Fig. 4c |
| `xenium-linked-selected` | Xenium | Linked views; Open JSON `xenium-linked-selected.json` | `<xenium.selected>` selected | identity check for Fig. 4d,e |
| `hla-10` | HLA & TCR | Linked views; colour by `sample`; Open JSON `hla-10.json` | `<hla.strict>` selected | Fig. 5 status row |
| `hla-293` | HLA & TCR | Linked views; colour by `sample`; Open JSON `hla-293.json` | `<hla.gene>` selected | Fig. 7 status row |
| `hla-motif` | HLA & TCR | HLA & TCR Motifs; Chain TRB; Network scope All cells; Colour by Motif cluster | `view with N points` | Fig. 6a |
| `hla-associations` | HLA & TCR | same page, HLA Associations tab (opens on one allele and one motif component) | a donor table row | Fig. 6b values |
| `e18-projection` | 10x E18 mouse brain (1.3M) | Projection page; Projection `umap`; Colour by `seurat_clusters` | `view with <e18.cells> points` | Supp. Fig. S2 |
| `builder-configure` | Builder | Load example datasets (three built-in examples); Configure page of "Complete Viewer demo" | 180 cells, 164 genes | Fig. 2a |
| `builder-review` | Builder | Finish Checking for each dataset (no setting changed); Continue to Review | All datasets checked | Fig. 2b |

Linked views loads per-cell codes only for the active colouring and refuses a saved view whose colouring has none yet, so the script colours by the saved view's colouring before opening it. The Builder keeps its project in the server session, so `run.sh` starts a fresh Builder for every capture run.

### Saved selections

A saved Linked views file names its data set by cell count and cell fingerprint and lists cell identifiers, so a file made for a larger data set is refused. The example CRBs of the pinned revision are smaller than those of the revision the figures were first made from (HLA & TCR 12,000 → 2,000 cells, Xenium 5,000 → 2,000; only 2 of the 10, 55 of the 293 and 197 of the 500 selected cells still exist), so `prepare_inputs.R` makes the selections again, by rules on the data. The rules selected exactly 10, 293 and 500 cells on the earlier example CRBs:

- `hla-10` (Fig. 5): cells whose TRB has the genes TRBV19.None.TRBJ1-5.TRBC1 and the CDR3 CASSIYSNQPQHF (one exact TRB, found in donor 1 and donor 2);
- `hla-293` (Fig. 7): cells whose CTgene is TRAV27.TRAJ42.TRAC_TRBV19.None.TRBJ2-7.TRBC2 (the gene-defined clone), with its box in the stack layout computed from the clone order;
- `xenium-linked-selected` (Fig. 4d,e): cells with UMAP 1 in [−4.165, 0.447] and UMAP 2 ≥ 6.67, with the box in the Viewer's normalised UMAP coordinates;
- `ren-linked-local` (Fig. 3) is a file exported from the Viewer and kept; the script checks that it matches the Ren data (cell count, fingerprint, every identifier).

## Figures

`scripts/figures.R` draws every figure at its printed size with ggplot2 and patchwork:

- width 170 mm (double column), height at most 225 mm; PDF through `cairo_pdf` with Arial embedded and text kept as text, plus a 300 dpi PNG preview;
- panel labels 8 pt bold upright, all other text 7 pt; lines at least 0.25 pt (0.5 pt by default);
- legends inside the figure; no figure titles or captions in the files (they are in the manuscript);
- drawn panels use colour-blind-safe Okabe–Ito colours; point clouds are rasterised at 600 dpi inside the vector PDF;
- screenshot panels are rectangular crops of the native 3× captures, placed without resampling at a scale where the smallest interface text inside the crop prints at 6 pt or more (the Fig. 5 status strip is 96 mm wide for that reason; the Fig. 4 tissue crops end before the plot toolbar). Crops are derived from the capture records (page-content area, plot canvas, dark tissue image, Linked views status row, Builder Review list), not typed coordinates.

Redrawn panels (Fig. 3a–d, 4d–e, 5, 7, S1) use the original coordinates and identifiers from the data set the Viewer shows: `scripts/prepare_inputs.R` reads them with `readCerebro()` of the installed package from the Ren CRB (and its immune sidecar) and from the HLA & TCR and Xenium example CRBs of the installed package. The clone bands are the R translation of the Viewer's Expansion bands layout (one band per clone-size tier that the data set has, CTgene clones, the Viewer's deterministic jitter); the TRB sharing classes are the Viewer's Clone sharing rule (V;J;CDR3 clonotype, unit = sample, group = major type). The script stops only if the data contradict themselves; every count it computes is written to `data/checks.json`, and `figures.R` stops if a captured page shows a different count.

Counts of the pinned revision (2026-11-13) against the first revision of the figures (`data/checks.json` holds the current values; the old ones are from the previous README):

| Count | Now | Before |
|---|---|---|
| Ren cells / TCR-bearing cells / TCR and BCR records | 1,462,702 / 220,968 / 503,432 | same |
| Ren selection / with TCR / without TCR | 13,556 / 6,569 / 6,987 | same |
| Ren TRB sharing: private / within group / across groups | 157,507 / 1,462 / 553 | same (labels "major type" → "group") |
| HLA & TCR cells | 2,000 | 12,000 |
| HLA & TCR exact-TRB selection (donor 1 / donor 2) | 2 (1 / 1) | 10 (2 / 8) |
| HLA & TCR gene-defined selection (donor 1 / donor 2) | 55 (32 / 23) | 293 (142 / 151) |
| Distinct TRB CDR3 in it; largest | 5; 41 | 10; 227 |
| Xenium cells / selection / clusters | 2,000 / 197 / 24 | 5,000 / 500 / 24 |
| E18 cells | 1,306,127 | 1,306,127 |

**Where the meaning of a figure depends on these numbers.** Figures 1, 2, 3, S1 and S2 show data that did not change (Ren, E18) or the Builder's current interface. Figure 4 (Xenium) now has 2,000 cells and a 197-cell selection of the same UMAP region, so d,e show a sparser tissue and a smaller selection. Figures 5–7 use the HLA & TCR example, which now has 2,000 cells: Fig. 5 (the exact TRB shared by two donors) is two cells, one per donor, not ten; Fig. 7 (a gene-defined clone with several CDR3) is 55 cells with five CDR3 (largest 41 cells), not 293 cells with ten; Fig. 6 shows the motif network of the smaller data set (23 nodes in two motif clusters; the Viewer's page said `view with 23 points`) and, for HLA-A\*02:01 and the locked motif component `TRBV19::M13_4 (12 CDR3)`, a table of four donors with 54 of 492 and 44 of 510 cells in the component (carrier donors 1 and 2; donors 3 and 4 have none). The captions of these figures must quote the new numbers; they say what the example shows, not what the full 12,000-cell data set showed. Fig. 6b is read from the captured HLA Associations page (allele, locked feature, donor rows), also recorded in `data/checks.json` under `viewer_pages`.

## Checks

`scripts/check_figures.R` reads each PDF (page size, embedded fonts, file size), its SVG twin in `figures/qa/` (every font size and stroke width) and `figures/qa/screenshot-qa.csv` (per crop: printed width, effective ppi, smallest interface text in pt, any text below 6 pt, any text the crop cuts), writes `figures/qa/figure-check.csv` and fails on any breach. `cairo_pdf` rounds the page to whole points, so 170 mm is reported as 169.7 mm.

## Limits

- Interface text inside screenshots is raster, not editable text; it is sized, not converted.
- The Viewer's navigation mini-map is part of the plot canvas and is kept in the projection screenshots.
- The RGB co-expression view draws no tissue image; its crop uses the same plot extent as the feature plot (the page is made taller so the plot is as large).
- The motif-network canvas of the Viewer clips nodes at its top edge in the capture; the crop shows the Viewer as it draws.
- The 2026-11-13 validation run used WSL's headless Chrome without a GPU. Captures other than the Xenium ones were taken before `capture_lib.R` recorded the plot-toolbar buttons (`overlays` in the JSON); only Figure 4 uses them, and a full `run.sh all` records them everywhere.
- The Fig. 2 Review crop ends under the last dataset card: the Review page of this revision keeps its Output section behind a fixed footer bar at the 1024 × 720 viewport.
