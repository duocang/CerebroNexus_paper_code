# Viewer performance

Measures how fast the CerebroNexus Viewer's pages open and how much memory it uses, for any Git revision.
The rules are in [STANDARD.md](STANDARD.md).

## Before you start

- Linux or WSL, with R and Chrome.
- A CerebroNexus checkout beside this repository (`../CerebroNexus`), or `--cerebro-repo DIR`.
- Run every command from the root of this repository.
- Optional, for large datasets: download and prepare them once with CerebroNexus, from its checkout:

  ```bash
  Rscript run-demo.R --prepare-only --cosmx    # mouse brain, Ren and CosMx
  ```

  Without `--cosmx` it prepares the mouse brain and Ren only.

  They go to `~/.cache/R/CerebroNexus/large-examples/` and need about 150 GB of disk; the first run
  downloads and converts for hours, later runs reuse them. `--cosmx` is on the CerebroNexus branch
  `feat/demo-cosmx-tcell` until it is merged. Without large datasets everything runs on the small
  demo data that ships with CerebroNexus.

## Measure one revision

```bash
bash topics/viewer_performance/run.sh l2 --candidate origin/master --solo
```

Records the time of every page, of one or a few actions per page (switch a grouping, colour by, select cells with a lasso, switch the dataset, ...; listed in [`standard/actions.tsv`](standard/actions.tsv)) and the memory. No comparison, no verdict. `--rounds N` sets how many times
everything is repeated (default: 1 for `l0`, 3 for `l1`, 5 for `l2`).

## Compare two revisions

```bash
bash topics/viewer_performance/run.sh l0 --candidate HEAD --baseline origin/master
```

Both revisions are measured in the same run, taking turns, so the machine is the same for both. The result
is `PASS`, `FAIL` (a page got slower) or `INVALID` (the measurement itself is not trustworthy).

- `l0`: 1 round. Run it before merging a pull request; do not merge on `FAIL`.
- `l1`: 3 rounds. `--baseline auto` compares with the last recorded run; `track` does this for `origin/master`.
- `l2`: 5 rounds, strictest. Run it before a release.

## Large datasets

Without them, every page runs on the small demo datasets that ship with CerebroNexus. To use large ones, give
their CRB files:

```bash
bash topics/viewer_performance/run.sh l2 \
  --candidate origin/master --solo \
  --mouse1m ~/.cache/R/CerebroNexus/large-examples/1m/cerebro-v2/cerebro_mouse_brain_1m.crb \
  --ren     ~/.cache/R/CerebroNexus/large-examples/ren/cerebro-v2/cerebro_ren_covid_1.46m.crb \
  --cosmx   ~/.cache/R/CerebroNexus/large-examples/cosmx/cerebro-v1/cerebro_cosmx_nsclc.crb
```

| Option | Dataset | Pages measured on it |
|---|---|---|
| `--mouse1m` | 10x E18 mouse brain, 1.3 M cells | Data info, Projection, Linked views, Groups, Gene expression, Trajectory, Colour management, Gene ID conversion, About |
| `--ren` | Ren et al. COVID-19, 1.46 M cells | Immune repertoire, Extra material |
| `--cosmx` | CosMx NSCLC, 800 k cells | Spatial |

Give any of them; the others fall back to demo data. The paths above are where CerebroNexus's `run-demo.R`
builds them; on another machine use that machine's paths. Which page uses which dataset is
[`standard/coverage.tsv`](standard/coverage.tsv).

## Results

Each run writes a folder with `summary.md` (read this first), `raw.tsv` (every measurement) and
`manifest.tsv` (revisions, machine, datasets). Without `--record` it goes to
`~/.cache/cerebronexus-viewer-perf/runs/`; with `--record` to [`runs/`](runs) in this repository, and one line
is added to `runs/INDEX.tsv`. A comparison can only be recorded once its tier is calibrated (STANDARD.md,
section 4); a `--solo` run can always be recorded.

## Other commands

```bash
bash topics/viewer_performance/run.sh standard-tests                                # unit tests
bash topics/viewer_performance/run.sh gpu --candidate HEAD --baseline origin/master # GPU renderer, Windows (Git Bash)
```

`targets::tar_make()` draws the trend of the recorded L1 runs and the Ren v2 BPCells / HDF5 figure
(`data/ren-backends-20261008.tsv`) into `figures/`.

## History

The older one-off benchmarks (million-cell page and release comparison, startup, renderer, Linked transport,
smoke, and their result tables) were removed when this standard was introduced. They are in Git history:
`git ls-tree -r --name-only 983df03 topics/viewer_performance`.
