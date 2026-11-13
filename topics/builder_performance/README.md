# Builder performance

Measures what the CerebroNexus Builder's own functions cost: an edit in the Configure page, importing a source
file, a Build with the matrix embedded or in an H5 sidecar, a Build after a change of the configuration only, and
the scripted H5 export. It exists for the Builder optimisations (`perf/builder-edit-latency`,
`perf/builder-load-export`), whose numbers had no protocol behind them. Each run is saved under [`runs/`](runs);
[`standard/compare.R`](standard/compare.R) compares two. How it measures is in [STANDARD.md](STANDARD.md).

## Before you start

- R (packages `processx`, `ps`, `jsonlite`, `Matrix`, `Seurat`, `testthat`, `rhdf5`, `HDF5Array`, `qs2`, `withr`) and
  Git; Windows or Linux. Close other work: a session waits until the whole machine is below 15 % CPU.
- A CerebroNexus checkout beside this repository (`..\CerebroNexus`), or `--cerebro-repo DIR`. Only committed
  code is measured: each revision is installed from `git archive`.
- The fixtures, made once per machine (about 5 GB, a few minutes), from the root of this repository:

  ```bash
  Rscript topics/builder_performance/standard/fixtures.R --out ../data/builder-perf
  ```

  | Fixture | Used by | Size |
  |---|---|---|
  | `meta60.rds` | `edit` | 20 000 cells, 63 metadata columns |
  | `meta_import.rds` | `import` | 200 000 cells, 63 metadata columns, one with 80 000 distinct values |
  | `cells100k.rds` | `build_embedded`, `build_h5`, `export_h5` | 100 000 cells, 198 M non-zero values |

  `--scale 0.01` makes a tiny set to see the harness run; a run on it says so and must not be used as a result.

## Measure one revision

```bash
Rscript topics/builder_performance/standard/run.R --fixtures ../data/builder-perf
```

| Option | Meaning |
|---|---|
| `--fixtures DIR` | required; where `fixtures.R` wrote the files |
| `--candidate REF` | the revision to measure (default: the commit in [`../cerebronexus.pin`](../cerebronexus.pin)) |
| `--baseline REF` | a second revision, measured in the same run with the sessions of the two taking turns |
| `--cerebro-repo DIR` | the CerebroNexus checkout (default `../CerebroNexus`) |
| `--rounds N` | default 5; with fewer than 4, `compare.R` cannot call anything slower or faster |
| `--scenarios a,b` | only these scenarios; the folder name ends in `_partial` |
| `--no-checks` | skip the equivalence checks |

Scenarios: `edit`, `import`, `build_embedded`, `build_h5`, `export_h5` ([`standard/scenarios.tsv`](standard/scenarios.tsv)).
A session that fails is retried by hand, not by the harness: it is a problem in the summary.

## Measure a change

```bash
Rscript topics/builder_performance/standard/run.R --fixtures ../data/builder-perf --candidate perf/builder-load-export --baseline master
Rscript topics/builder_performance/standard/compare.R <baseline run> <candidate run>
```

`perf/builder-edit-latency` is measured the same way: it changes the `edit` scenario, the others should not move.
Which scenario each branch is expected to move is in `scenarios.tsv` (`branch_change`).

Once per machine, measure a revision against itself (`--candidate master --baseline master`; the second folder
ends in `_base`): what `compare.R` reports for that pair is the noise, and nothing smaller can be claimed.

## Results

```
runs/cerebronexus-<version>_<YYYYMMDD-HHMMSS>_<sha7>[_base][_partial]/
  summary.md   read this first: every scenario, the equivalence checks, the problems
  scenarios.tsv, raw.tsv, checks.tsv, schedule.tsv, manifest.tsv
```

Commit the run folder.

## Other commands

```bash
Rscript -e 'testthat::test_dir("topics/builder_performance/tests")'   # unit tests
```
