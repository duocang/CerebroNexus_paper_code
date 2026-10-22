# Tool comparison

Same-task comparison of five single-cell viewers: CerebroNexus 6.0.0 (default and H5 backend), ShinyCell, iSEE, cellxgene 1.3.0 and Vitessce 3.8.4 / 3.9.9, run on one native Windows 11 host (i9-12900K, 127.7 GB RAM, R 4.5.0, Python 3.11, Chrome 155).

- Task 1: import and capability recognition on I1-I4 (pbmc3k, scRepertoire example with TCR, Visium H&E, pbmc3k with duplicated cell names).
- Task 2: selection retrieval for S1 and S2 by region and attribute routes, Jaccard against the truth sets, three runs per route.
- Task 3: E18 first 10k / 100k / 500k cells, 3 builds x 3 starts per tool and tier; build time, artifact size, service-ready time, first plot, peak RSS.

Results: [results/SUMMARY.md](results/SUMMARY.md) and [results/summary_task3.md](results/summary_task3.md); raw rows in `results/task1_raw/`, `results/task2_raw/`, `results/task3_builds.csv`, `results/task3_starts.csv`. Superseded runs are kept under `results/superseded_*` and `logs/superseded_v1/` and are not in the tables.

The quantitative figure, [figures/fig-tool-comparison.pdf](figures/fig-tool-comparison.pdf) (a: Task 1 capability matrix, b: Task 2 Jaccard index per route, c: Task 3 build time, artifact size, start to first plot and server peak memory at 10k / 100k / 500k cells, median with min-max), is redrawn from `results/` by the root targets pipeline (`functions.R`, `targets.R`) and checked with `topics/interface_figures/scripts/check_figures.R`.

The screenshots in `logs/` are measurement evidence, not figure panels. What the paper needs, and how to capture it on the Windows host, is in [FIGURES.md](FIGURES.md).

## Layout

```
PROTOCOL.md     pre-registered protocol and Deviations D1-D13
PROGRESS.md     run diary
functions.R     plotting helpers for the quantitative figure
targets.R       its target list (targets_tool_comparison)
figures/        the quantitative figure and its check (qa/)
FIGURES.md      which figure panels are needed and how to capture them
TASK2_RERUN.md  rerun of the CerebroNexus attribute route (Group filters) missed in Task 2
scripts/        harness (harness.py, task3.py), per-task scripts, tool builders, summaries
results/        result tables, environment.json, inputs.csv, protocol hashes
logs/           run logs and screenshots
```

`data/`, `env/`, `inputs/` and `artifacts/` are created by the scripts and git-ignored (see `.gitignore`).

## Running

The scripts locate everything relative to this folder, so they run from wherever it sits. They target native Windows with Git Bash (`scripts/run_r.sh` uses `cygpath` and the R 4.5.0 install path); the Python environment is `env/py`.

```bash
python scripts/harness.py pilot <I1|e18_10000> [tool ...]
python scripts/task3.py run <10000|100000|500000>
```

## Paths in the frozen records

The study ran in a top-level `comparison/` folder, which was moved here afterwards. `PROTOCOL.md` still says `comparison/...`: its text before the Deviations heading is hashed in `results/PROTOCOL_body.sha256` and is left unchanged. Logs and raw results keep the original Windows paths (`C:\Users\wangx\Projects\CerebroNexus_paper_code\comparison\...`) as recorded.
