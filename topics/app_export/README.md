# App export

Measures how long `createShinyApp()` takes to write a self-contained App, how much memory it needs and how much it
writes, for one CerebroNexus revision at a time. Each run is saved under [`runs/`](runs) in a folder named after
the CerebroNexus version and the date. How it measures is in [STANDARD.md](STANDARD.md). How fast the pages of a
running Viewer open is a different question and lives in [`../viewer_performance`](../viewer_performance).

## Before you start

- R with `processx`, `ps`, `jsonlite`, and Git; a CerebroNexus checkout beside this repository (`..\CerebroNexus`),
  or `--cerebro-repo DIR`.
- The large example datasets, as for `viewer_performance` (`1m` and `cosmx` below `--large-examples`).
- For the `embedded_100k` and `h5_100k` scenarios, two CRBs made once from the `builder_performance` fixture (about
  5 GB for the embedded one; needs `cells100k.rds`, see [`../builder_performance`](../builder_performance)):

  ```bash
  Rscript topics/app_export/standard/fixtures.R --from ../data/builder-perf --out ../data/app-export
  ```

  Pass `--fixtures ../data/app-export` to `run.R`; without it those two scenarios are left out.

## Measure one revision

```bash
Rscript topics/app_export/standard/run.R --large-examples ../data/large-examples
```

| Option | Meaning |
|---|---|
| `--fixtures DIR` | where `fixtures.R` wrote the CRBs of `embedded_100k` and `h5_100k` |
| `--candidate REF` | the revision to measure (default: the commit in [`../cerebronexus.pin`](../cerebronexus.pin); only committed code is measured) |
| `--cerebro-repo DIR` | the CerebroNexus checkout (default `../CerebroNexus`) |
| `--rounds N` | sessions per scenario (default 3) |
| `--scenarios a,b` | only these scenarios; the folder name ends in `_partial` |

## Compare two revisions

```bash
Rscript topics/app_export/standard/compare.R <run A> <run B>
```

with the folder names below `runs/`. Measure the two revisions on the same machine, one after the other, with
nothing else running.

## Files

| File | What it is |
|---|---|
| `standard/run.R` | installs the revision from `git archive`, starts one session per scenario and round, writes the run |
| `standard/worker.R` | the session: two `createShinyApp()` calls in a fresh R process |
| `standard/scenarios.tsv` | which CRBs are exported |
| `standard/fixtures.R` | writes the two 100 k CRBs of the `fixture` scenarios |
| `standard/compare.R` | compares two runs |
