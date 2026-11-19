# Tool comparison

How long do five single-cell viewers take on the same data and machine: CerebroNexus (embedded and HDF5 expression layer), ShinyCell,
iSEE, cellxgene, Vitessce, on the first 5,000 to 100,000 cells of the 10x E18 mouse brain and on all 1,306,127 of them.
It measures **time** and memory, nothing else.

| Measured | What |
|---|---|
| Build | the documented route from the `.h5ad` to what the viewer reads |
| Start | launching the server to the first plot on screen, with an empty cache |
| Start again | the same app once more, with what the first start left in its cache |
| Colour by a gene | the gesture to the last frame that changes: the first gene (nothing warm) and the next 19 |
| Memory | peak resident memory of the server and of Chrome during a start |

At 1.3 M cells the matrix does not fit a `dgCMatrix` (at most 2^31-1 non-zeros), so CerebroNexus (embedded), ShinyCell and iSEE are skipped there and
recorded as `skipped`.

## Run

Native Windows (Chrome uses the GPU), Git Bash, R 4.6.1, from this folder. CerebroNexus is the HEAD of `../../../CerebroNexus` (or `--candidate REF`),
installed from `git archive`; its commit and version are written into the run and nowhere else.

```bash
env/py/Scripts/python.exe bench.py                                                # every tool, 6 tiers: hours
env/py/Scripts/python.exe bench.py --tiers 5000 --reps 1 --genes 3                # a quick look
env/py/Scripts/python.exe bench.py --candidate integration/8.4.1 --resume runs/X  # continue a run
Rscript plot.R                                                                    # figures/ from the newest run
```

The machine must be otherwise idle: no WSL, no builds, no tests while it runs.

`runs/<date>_<commit>/` holds `summary.md` (read first), `builds.tsv`, `starts.tsv`, `genes.tsv` (one row per measurement) and `manifest.tsv` (commit,
machine, browser, tool versions). Nothing is overwritten; to measure again, run again.

## Files

```
bench.py       the run: build, start, start again, genes
lib.py         processes, the CerebroNexus install, Chrome, the first-plot rule
drive.py       how each viewer is told to colour by a gene
tools/         build and serve scripts, one per viewer
plot.R         figures/fig-tool-timing, figures/fig-tool-capability
features/      capability.csv, selection.csv: measured once, earlier, not by bench.py (see its README)
setup/         inputs (prep_inputs*.py, subset_tiers.py) and the R library (r_env.R)
data/ env/     inputs and environments, not committed
```

## How it is measured

- **Clock.** One Python process starts every server and the browser; all times are `time.perf_counter()`.
- **Start.** Spawn to the first HTTP 200 (`t_ready`, a TCP probe every 5 ms); then a new Chrome opens the viewer and the time to the first plot counts from that navigation.
  Nobody clicks: CerebroNexus is opened by its page link (`/?page=projection`), the others show their plot on their first page.
- **First plot.** Viewport screenshots back to back (about 0.1 s). A frame shows the plot when its element is at least 200 x 200 px, at least 0.3 % of its pixels are ink
  (more than 60 from the element's most frequent colour on the 0-255 RGB scale, and dark or coloured) and the ink covers at least 16 of its 8 x 8 blocks; the first plot is the first of two
  frames in a row that show it. The rule of `topics/viewer_performance`, with the ink share lowered from 1 % to 0.3 %: at 5,000 cells a plot is thin (Vitessce draws 0.9 %).
- **Again.** Each pair of starts has its own cache directory (`R_USER_CACHE_DIR`). The viewers that keep nothing there start twice the same way.
- **Genes.** One session per tool and tier: open the plot, go to the gene control, colour by 20 genes in the same order (`data/inputs/sweep_genes.txt`). Time = the gesture
  to the last frame that differs from the final one (2 s unchanged = settled).
- **Repeats.** Three pairs of starts, one build and one gene session per tool and tier; medians with ranges.

## Figures

`Rscript plot.R` draws two files into `figures/` (170 mm wide, Arial 7 pt, vector PDF with embedded fonts and a 300 dpi PNG):
`fig-tool-timing` (scorecard at 100,000 and 1.3 M cells, and how start, colouring by a gene, memory and build time grow with the number of cells)
and `fig-tool-capability` (what each viewer does with the default import call, and how well a selection can be taken out of it;
from `features/`, not from `bench.py`). The text size is 7 pt at least.

## Limits

- One machine, one OS, one GPU: absolute numbers do not transfer.
- Frames are 0.1 s apart; differences below 0.2 s are not results.
- The gene gesture includes typing and choosing the entry; viewers that query their gene list on a server pay that too.
- cellxgene opens a dialog over its plot at start; its plot is seen behind it and the dialog is closed (by naming a directory) before the gene test.
- The OS file cache is not flushed.
