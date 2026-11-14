# Viewer performance

Measures how fast the CerebroNexus Viewer's pages open, how fast the main controls on each page respond, and
how much memory it uses, for one CerebroNexus revision at a time. Each run is saved under [`runs/`](runs) in a
folder named after the CerebroNexus version and the date; [`standard/compare.R`](standard/compare.R) compares
two of them. How it measures is in [STANDARD.md](STANDARD.md).

## Before you start

- Windows (the reference platform; Linux works too, see STANDARD section 5), with R (packages `chromote`, `processx`, `ps`, `jsonlite`, `png`, `base64enc`, `testthat`), Chrome and Git.
- A CerebroNexus checkout beside this repository (`..\CerebroNexus`), or `--cerebro-repo DIR`. `PERF_CACHE=DIR` moves the cache of sources, libraries and server caches.
- The large example datasets, prepared once with CerebroNexus (`Rscript run-demo.R --prepare-only --cosmx` in
  its checkout). The folder must contain:

  | Dataset | File below the folder |
  |---|---|
  | `1m`: 10x E18 mouse brain, 1.3 M cells | `1m/cerebro-v2/cerebro_mouse_brain_1m_compressed.crb` |
  | `ren`: Ren et al. COVID-19, 1.46 M cells, TCR and BCR | `ren/cerebro-v2/cerebro_ren_covid_1.46m_compressed.crb` |
  | `cosmx`: CosMx NSCLC, 800 k cells | `cosmx/cerebro-v2/cerebro_cosmx_nsclc_compressed.crb` |

  Each CRB needs its `.h5` sidecar and `.viewer` folder beside it. The list is [`standard/fixtures.tsv`](standard/fixtures.tsv).
- Run every command from the root of this repository.

## Measure one revision

```bash
Rscript topics/viewer_performance/standard/run.R --large-examples ../data/large-examples
```

`--large-examples` is required and has no default; give it relative to the current folder or as an absolute
path. Options:

| Option | Meaning |
|---|---|
| `--candidate REF` | the CerebroNexus revision to measure (default: the commit in [`../cerebronexus.pin`](../cerebronexus.pin); only committed code is measured) |
| `--baseline REF` | a second revision, measured in the same run with the sessions of the two taking turns (see "Measure a change" below) |
| `--cerebro-repo DIR` | the CerebroNexus checkout (default `../CerebroNexus`) |
| `--rounds N` | how often every page is measured (default 5; with fewer than 4, `compare.R` cannot call anything slower or faster) |
| `--pages a,b` | only these pages and their actions, while working on them; the folder name ends in `_partial` |

The servers of a run keep their files (the finished page, first views, cell names) in a cache directory of
that run, not in yours, so a run neither finds what another revision left nor leaves anything behind. Close
other work first: a session waits until the whole machine is below 15 % CPU, for up to 10 minutes
(`PERF_IDLE_MAX_S=seconds` changes that), and then starts anyway and is marked.

Every page is measured **once, on one dataset** ([`standard/coverage.tsv`](standard/coverage.tsv)):

| Dataset | Pages |
|---|---|
| `1m` | Data info, Projection, Linked views, Groups, Gene expression, Trajectory, Colour management, Gene ID conversion, About |
| `ren` | Immune repertoire, HLA & TCR motifs, Extra material |
| `cosmx` | Spatial |
| demo CRBs that ship with CerebroNexus | Marker genes, Most expressed genes, Enriched pathways (`example`), Trekker (`demo_trekker`): none of the large datasets has them |

The Projection page is also measured from the start: Chrome navigates to a Viewer that has just started and
the clock runs to the first frame that shows the projection, the same event the tool comparison times for the
other viewers. Twice: with an emptied cache directory, as on a new installation (`first_start`, "From page
load, nothing kept"), and with what earlier sessions left (`first_plot`, "From page load"). The rows sit under
Projection in `figures/` and `summary.md`; `first_plot_ms` in `pages.tsv`; `plot.R --metric first_plot_ms`
draws only them.

After a page opens, its actions run on it ([`standard/actions.tsv`](standard/actions.tsv)): switching the
dataset and back, colouring by another column, zooming, a lasso selection, another grouping, plot type and
percent switch on Groups, one gene and then 12 genes on Gene expression, the next tab, section or content on
the other pages.

## Results

```
runs/cerebronexus-<version>_<YYYYMMDD-HHMMSS>_<sha7>/
  summary.md     read this first: every page and action, memory per dataset, server steps
  pages.tsv      one row per page and action: medians over the rounds (what compare.R reads)
  raw.tsv        every observation
  manifest.tsv   revision, version, machine, datasets (path, checksum, size), plan checksum
  plan.tsv, schedule.tsv, server.tsv
  logs/          per-session logs and CPU/memory traces (not committed)
```

Commit the run folder (without `logs/`, which is ignored).

## Measure a change

To say that revision B is faster or slower than revision A, measure both in one run:

```bash
Rscript topics/viewer_performance/standard/run.R --large-examples ../data/large-examples --candidate B --baseline A
```

The same page is measured for one revision and at once for the other, round after round, so both meet the
same machine. Each revision gets its own run folder; the command to compare them is printed at the end. Two
runs made on different days can be compared too, but a busier machine on one of the days then looks like a
change in the code.

Once per machine, measure a revision against itself (`--candidate A --baseline A`; the second folder ends in
`_base`): what `compare.R` reports for that pair is the noise, and nothing smaller can be claimed.

## Compare two runs

```bash
Rscript topics/viewer_performance/standard/compare.R cerebronexus-5.3.0_... cerebronexus-5.4.0_... [--metric first_plot_ms] [--out compare.md]
```

Prints, per page and action, the median in A and in B, the difference, the rounds behind it and the p-value of
an exact rank-sum test over those rounds, server busy time and R memory. A row is `slower` or `faster` when
p <= 0.05 and the medians differ by more than one frame; `not resolved` when the run cannot show a
difference; `too few rounds` when it could not have shown one (three rounds against three). It says whether
the two runs were made together, and when they were not made on the same machine, plan or datasets. The rule
is in [STANDARD.md](STANDARD.md), section 6.

## Draw several runs together

Runs are named by their folder in `runs/`; a full path works too.

```bash
Rscript topics/viewer_performance/standard/plot.R cerebronexus-5.4.0_... cerebronexus-5.5.0_... [more runs] [--out figure.pdf] [--metric server_busy_ms]
```

One row per page and action, one colour per run: the median over rounds, with a line from the fastest to
the slowest round, on a log time axis. The legend names each run by its CerebroNexus version; runs that share
a version also get the date (and the start time when the date is the same too). Runs are drawn by version,
then date.

The figure follows the Genome Biology rules used for `topics/expression_backends`: a vector PDF 170 mm wide
and at most 225 mm tall (two columns when there are many runs), Arial 7 pt, lines of at least 0.25 pt,
Okabe-Ito colours, legend in the figure, no title. A PNG at 300 dpi is written beside it. Default output:
`figures/viewer-performance.pdf` / `.png`; `--metric` takes any column of `pages.tsv`;
`--allow-font-substitute` draws a draft when Arial and Helvetica are not installed.

## Other commands

```bash
Rscript -e 'testthat::test_dir("topics/viewer_performance/tests")'                           # unit tests
Rscript topics/viewer_performance/standard/gpu/run.R --candidate HEAD --baseline origin/master # GPU point renderer alone
```

## History

The earlier version of this folder (tiers L0 to L2 comparing two revisions in one run with a PASS / FAIL
verdict, a journey session per dataset, the Ren BPCells / HDF5 figure) is in Git history before this change.
The BPCells / HDF5 comparison lives in `topics/expression_backends`.
