# Tool comparison

**Round 2 (current):** CerebroNexus `perf/viewer-page-open` (5.5.0) against ShinyCell, iSEE, cellxgene and Vitessce on native Windows with R 4.6.1 and a GPU-backed Chrome; see [PROTOCOL.md](PROTOCOL.md) and [PROGRESS.md](PROGRESS.md). Round 1 (CerebroNexus 6.0.0, R 4.5.0) is kept unchanged in [archive/round1_cerebronexus-6.0.0/](archive/round1_cerebronexus-6.0.0/). The text below describes round 1 and the scripts, and is updated as round 2 proceeds; figures now go to `figures/` beside `results/`.

Same-task comparison of five single-cell viewers: CerebroNexus 6.0.0 (default and H5 backend), ShinyCell, iSEE, cellxgene 1.3.0 and Vitessce 3.8.4 / 3.9.9, run on one native Windows 11 host (i9-12900K, 127.7 GB RAM, R 4.5.0, Python 3.11, Chrome 155).

- Task 1: import and capability recognition on I1-I4 (pbmc3k, scRepertoire example with TCR, Visium H&E, pbmc3k with duplicated cell names).
- Task 2: selection retrieval for S1 and S2 by region and attribute routes, Jaccard against the truth sets, three runs per route.
- Task 3: E18 first 10k / 100k / 500k cells, 3 builds x 3 starts per tool and tier; build time, artifact size, service-ready time, first plot, peak RSS.

Results: [results/SUMMARY.md](results/SUMMARY.md) and [results/summary_task3.md](results/summary_task3.md). One file or row per run, with the per-tool tables, is in `results/task1/`, `results/task2/` and `results/task3/`. Runs replaced after Deviations D11-D14 are in `results/superseded/` (tables in `v1/` and others, their logs in `v1/logs/`) and are in no table.

The quantitative figure, [results/figures/fig-tool-comparison.pdf](results/figures/fig-tool-comparison.pdf) (a: Task 1 capability matrix, b: Task 2 Jaccard index per route, c: Task 3 build time, artifact size, start to first plot and server peak memory at 10k / 100k / 500k cells, median with min-max), is redrawn from the three `results/*_summary.csv` into `results/figures/` by the root targets pipeline (`functions.R`, `targets.R`) and checked with `topics/interface_figures/scripts/check_figures.R`.

The screenshots in `results/evidence/` are measurement evidence, not figure panels. What the paper needs, and how to capture it on the Windows host, is in [FIGURES.md](FIGURES.md).

## Layout

```
PROTOCOL.md     pre-registered protocol and Deviations D1-D15
PROGRESS.md     run diary
FIGURES.md      the two screenshot panels and how scripts/report/capture_figures.py makes them
functions.R     plotting helpers for the quantitative figure (root targets pipeline)
targets.R       its target list; the measurements do not run through it
scripts/
  run/          measurement: harness.py, task1/, task2/, task3/, tools/ (one builder per tool)
  setup/        environment, inputs, environment record
  report/       results/task* -> summaries (aggregate_task*.py, summarize_task3.py, make_summary.py), capture_figures.py
results/
  SUMMARY.md, task1_summary.csv, task2_summary.csv, summary_task3.csv|md   what the paper uses
  environment.json, inputs.csv, task3_inputs_manifest.json, PROTOCOL*.sha256
  task1/ task2/ task3/   one file or row per run, plus the per-tool tables
  evidence/              run logs and screenshots behind the tables (see evidence/README.md)
  superseded/            replaced runs (tables in v1/ etc., their logs in v1/logs/)
  figures/               the quantitative figure (and qa/) and captures/ (the two screenshot panels)
```

`data/` (`data/raw/` downloads, `data/inputs/` derived inputs, `data/builds/` what each tool builds from them) and `env/` are created by the scripts and git-ignored (see `.gitignore`).

## Running

The scripts locate everything relative to this folder, so they run from wherever it sits. They target native Windows with Git Bash (`scripts/run/run_r.sh` uses `cygpath` and the R 4.5.0 install path); the Python environment is `env/py`.

```bash
python scripts/run/harness.py pilot <I1|e18_10000> [tool ...]
python scripts/run/task3/run.py run <10000|100000|500000>

# results/task* -> summaries
python scripts/report/aggregate_task1.py
python scripts/report/aggregate_task2.py
python scripts/report/summarize_task3.py
python scripts/report/make_summary.py
```

## Paths in the frozen records

The study ran in a top-level `comparison/` folder, which was moved here afterwards. `PROTOCOL.md` still says `comparison/...`: its text before the Deviations heading is hashed in `results/PROTOCOL_body.sha256` and is left unchanged. Logs and raw results keep the original Windows paths (`C:\Users\wangx\Projects\CerebroNexus_paper_code\comparison\...`) as recorded.
