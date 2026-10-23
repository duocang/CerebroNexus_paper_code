# Viewer performance

Page speed and memory of the CerebroNexus Viewer, measured under one standard:

- [`STANDARD.md`](STANDARD.md): the rules (what is measured, tiers L0/L1/L2 and GPU, thresholds, verdict, record format).
- [`standard/`](standard): the implementation. `run.R` is the single entry point; `measure_session.R`,
  `server.R`, `hook.js` and `sampler.R` make one measured session; `lib.R` and `policy.tsv` hold the verdict
  logic and thresholds (unit tested in `tests/test-standard.R`); `calibrate.R` checks the noise of an
  A/A run, which is how the thresholds are set; `coverage.tsv` and `fixtures.tsv` say which page runs on
  which dataset, `actions.tsv` which in-page actions are measured; `server_steps.R` times the R work behind
  the pages; `gpu/` is the GPU renderer tier (Windows).
- [`runs/`](runs): one record per run (manifest with SHAs, raw observations, verdict, summary),
  `INDEX.tsv`, and `calibration/`. Empty so far.

## Run it

Linux or WSL, with this repository cloned beside a CerebroNexus checkout (or `CEREBRO_REPO` set):

```bash
bash topics/viewer_performance/run.sh l0 --candidate HEAD --baseline origin/master          # one pull request
bash topics/viewer_performance/run.sh l1 --candidate origin/master --baseline auto --record # follow master
bash topics/viewer_performance/run.sh track          # the same, only when master moved since the last record
bash topics/viewer_performance/run.sh standard-tests # unit tests of the verdict logic
```

The GPU tier runs on Windows (Git Bash), where Chrome has the GPU:

```bash
bash topics/viewer_performance/run.sh gpu --candidate HEAD --baseline origin/master
```

L0 is run by hand before merging a pull request; do not merge on `FAIL`. `targets::tar_make()` draws the trend of the recorded L1 runs (`runs/INDEX.tsv`) and the Ren v2
BPCells / HDF5 figure (`data/ren-backends-20261008.tsv`, the figure in the CerebroNexus "Large-dataset
benchmarks" article) into `figures/`.

## Not covered yet

L0 uses the demo CRBs only. L1 and L2 use the large fixtures where they exist; today only `ren` does.
L0 to L2 render in software; the GPU tier measures the renderer alone on synthetic points. See "Limits" in [STANDARD.md](STANDARD.md).

## History

The earlier one-off benchmarks were removed when the standard was introduced: the million-cell page and
release comparison (`run.sh pages|release`), startup, renderer, Linked transport and smoke scripts, the PR184 and million-cell result
tables, the BPCells storage-order and Ren expression-backend benchmarks, and the 11-page figure script. They
are in Git history, for example
`git show 983df03:topics/viewer_performance/data/VIEWER_1M_RESULTS.md` or
`git ls-tree -r --name-only 983df03 topics/viewer_performance/scripts`. The H5 / BPCells / embedded storage
study has its own folder, [`topics/expression_backends/`](../expression_backends/README.md).
