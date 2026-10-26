# Tool comparison

Same-task comparison of five single-cell viewers on one native Windows 11 host (i9-12900K, 127.7 GB RAM, RTX 4060, Chrome 155 with a hardware WebGL renderer): CerebroNexus (default and H5 backend), ShinyCell, iSEE, cellxgene 1.3.0 and Vitessce 3.8.4 / 3.9.9. The current run is round 2; the tools are pinned in [PROTOCOL.md](PROTOCOL.md), the diary is [PROGRESS.md](PROGRESS.md).

- CerebroNexus: commit `2786ff6d09a53f54e25bb1affbc6ed58aac70b43` of the branch `tmp/应急` (version 6.0.0, the Builder merged into `perf/viewer-page-open`). R 4.6.1 with Bioconductor 3.23 (iSEE 2.24.0).
- Task 1: import and capability recognition on I1-I4 (pbmc3k, scRepertoire example with TCR, Visium H&E, pbmc3k with duplicated cell names).
- Task 2: selection retrieval for S1 and S2 by region and attribute routes, Jaccard against the truth sets, three runs per route.
- Task 3: E18 first 10k / 100k / 500k cells, 3 builds x 3 starts per tool and size; build time, artifact size, service-ready time, first plot, peak RSS.

Results: [results/SUMMARY.md](results/SUMMARY.md) and [results/summary_task3.md](results/summary_task3.md); one file or row per run, with per-tool tables, in `results/task1/`, `results/task2/` and `results/task3/`; logs and screenshots behind them in `results/evidence/`.

Figures (R, ggplot2, Genome Biology rules; `functions.R` and `targets.R`): `figures/fig-tool-comparison.pdf` (a: capability matrix, b: Jaccard per route, c: build time, artifact size, start to first plot and server memory at 10k / 100k / 500k cells) and `figures/fig-tool-comparison-start.pdf` (service-ready and first-plot time, every single start). Checked with `topics/interface_figures/scripts/check_figures.R`. The screenshot panels of [FIGURES.md](FIGURES.md) are not redone yet.

## Layout

```
PROTOCOL.md     protocol of round 2 (frozen; Deviations D1-D5 at the end)
PROGRESS.md     run diary
FIGURES.md      the two screenshot panels and how scripts/report/capture_figures.py makes them
functions.R     plotting functions of the figures
targets.R       their target list; the measurements do not run through it
scripts/
  run/          measurement: harness.py, task1/, task2/, task3/, tools/ (one builder per tool)
  setup/        environment, inputs, environment record
  report/       results/task* -> summaries (aggregate_task*.py, summarize_task3.py, make_summary.py), capture_figures.py
results/        tables, per-run files, evidence (logs and screenshots), environment.json, inputs.csv, hashes
figures/        the figures (PDF and PNG; qa/ holds the SVG twins for the check)
```

`data/` (`raw/` downloads, `inputs/` derived inputs, `builds/` what each tool builds) and `env/` (Python, R library, JavaScript bundle) are created by the scripts and are git-ignored. Round 1 (CerebroNexus 6.0.0 `27ac995e`, R 4.5.0, 2026-10-22 to 2026-10-24) is in the Git history up to commit `983df03` (see Deviation D5 of the protocol).

## Running

The scripts locate everything relative to this folder. They target native Windows with Git Bash and the R install in `C:\R\R-4.6.1` (`scripts/run/run_r.sh` uses `cygpath`); the Python environment is `env/py`.

```bash
scripts/run/run_r.sh scripts/setup/setup_r_round2.R   # R library env/rlib
python scripts/run/harness.py pilot <I1|e18_10000> [tool ...]
bash scripts/run/task1/run_all.sh
bash scripts/run/task2/run_all.sh
python scripts/run/task3/run.py run [10000 100000 500000]

# results/task* -> summaries
python scripts/report/aggregate_task1.py
python scripts/report/aggregate_task2.py
python scripts/report/summarize_task3.py
python scripts/report/make_summary.py
```
