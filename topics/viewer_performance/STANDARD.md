# Viewer performance standard

How the CerebroNexus Viewer's page speed and memory are measured, compared and recorded, so that any two
numbers in this repository can be compared and a regression is caught when it is made. The code is in
`standard/`; this page is the rule it implements.

## 1. What a measurement is

One **observation** is a user action on a running Viewer. One **session** is one fresh R server and one fresh
headless Chrome on one dataset. A **run** is a set of sessions that compares a **candidate** with a
**baseline**. There are two kinds of session, and six kinds of observation (`visit`):

| Session | Visits, in order |
|---|---|
| **cold**, one per page | Data info (not recorded), the page (`cold`), Data info, the same page again at once (`repeat`) |
| **journey**, one per dataset | Data info loading the dataset (`initial`), every page in sidebar order (`journey`), then every page again after going back to Data info (`revisit_after_tour`), then the in-page actions (`action`, below) |

Many things load the first time a page needs them (the expression backend, the repertoire tables), and
the cache is shared by the whole R process. In a journey whoever comes first pays: Immune repertoire took
11.6 s right after Extra material and 6.7 s after all the other pages. So **`cold` is the first visit that
counts**: a fresh server and Chrome, only Data info before it, the same cost whatever pages exist. `journey`
is what a user who clicks through the menu meets; its numbers belong to its order, which every summary
prints. `repeat` is reopening one page right after leaving it; `revisit_after_tour` is reopening it after
the whole tour (Linked views shares its renderer with Projection, so there it measures a rebuild).

**Every page is measured on one dataset** (section 3), in its cold session and in the journey. A page that
does not depend on the data (About, Gene ID conversion) is not repeated on every dataset, and a page is not
measured on a dataset where it means little. What is repeated is the *round*: the whole plan runs again,
because one measurement of one page is too noisy to tell a regression from noise (section 4).

| Metric (contract `blackbox-v4`) | Meaning | Use |
|---|---|---|
| `visual_complete_ms` | Click to the last frame that differs from the final screen. Screenshots every ~50 ms at quarter scale; a frame counts as different when more than 0.05 % of its pixels differ from the last frame. | **KPI, gated** |
| `server_busy_ms` | Click to the moment the R server's process tree goes quiet: from then on every 1 s window stays under 5 % of a core until the harness has seen 3 quiet seconds. A shorter pause is part of the work (on Projection, R waits about 1 s while Chrome draws, then sends 29 MB of cell names). | counts towards the budget, reported |
| `trail_ms` | After the page was finished (below), how long the R server or Chrome kept working: the wait before the next click, put on the page that caused it. | reported |
| `ws_in_bytes`, `ws_out_bytes`, `ws_max_msg_bytes` | Websocket traffic from the click to the end of the trail, and the largest single message, counted in the page (`ws.js`). | reported |
| `loader_visible_ms` | Time a loading card or overlay is on screen (exact, from the DOM). | gated, needs corroboration |
| `visual_90_ms` | Click to the first frame that is 90 % identical to the final screen. | reported |
| `settled_ms`, `visible_ms`, `chrome_busy_ms` | Last DOM change anywhere / inside the page; when Chrome went quiet. | diagnostic |
| R / Chrome tree memory | Peak PSS of the server's process tree and of Chrome's, sampled every 150 ms from `/proc`. PSS, not RSS, because Chrome's processes share pages. | reported at L0/L1, gated at L2 |
| JS heap | `JSHeapUsedSize` peak per observation, shown per page in the summary. | reported |
| Server steps | Time of each R step behind the pages, without a browser (below). | reported |

Why pixels: the Viewer cannot be asked when a plot has finished drawing in every version, and a DOM signal
(a loading card, a "recalculating" class) exists in some versions only. A metric that needs the Viewer's
cooperation is not comparable across versions. Screenshots are. But pixels miss work that changes none of
them, and a user who clicks on waits for it. On the mouse brain (7b1cc488), Projection looks done while R
keeps working to send 29 MB of cell names: 1.6 s more on the first visit (Windows; 3 to 6 s in WSL), and
again whenever Projection is opened after Linked views, which shares its renderer (not when it is reopened
straight from Data info). Gene expression looks done after about 2 s, but its gene list arrives after 7 s
(Windows; about 10 s in WSL), because the expression backend loads on first use. `server_busy_ms`, `trail_ms`
and the websocket counts show that work; they need no cooperation from the Viewer either.

**Quiet start and end.** Every observation starts when the R server's tree and Chrome's tree have both been
quiet for 3 seconds (every 1 s window under 5 % of a core for R, under 25 % for Chrome, which uses 0.1 to
0.2 of a core while idle), and ends only when they are quiet again. Without the start, a click races with
work left from before (on the 1.46 M-cell data the same code then measured 0.3 s or 6 s for the same page);
without the end, that work would belong to no page. The wait before is recorded (`idle_wait_s`, 0 when the
previous observation just ended quiet); the time until quiet after is the page's `trail_ms`. Websocket
traffic is counted in the page by wrapping `WebSocket` (`ws.js`, added with
`Page.addScriptToEvaluateOnNewDocument`), not with CDP's Network domain: its events carry every message
whole, and a 29 MB message is larger than chromote's websocket limit and breaks the CDP connection.

**Warm-up.** The first read of a large fixture's H5 comes from disk and the rest from the page cache. One
discarded session per large fixture precedes the measured ones.

A page is **finished** when it has content, Shiny has been quiet for 500 ms and nothing in the page has
changed for 500 ms. A page that Shiny still reports as busy after 15 s without any change is `stuck_busy`
(older versions leave the flag set after the server is idle); one not finished after 90 s is `timeout`.
A page that finishes with an output error or a lost connection on screen is `error`: a page that fails
fast must not count as fast. These are results, not errors of the harness.

**In-page actions** (`standard/actions.tsv`, code in `hook.js`). Opening a page is not all a user waits for.
The journey session also, after the page visits, opens a page and does one thing on it, measured like a page:

| Page | Actions |
|---|---|
| Projection | colour by the next column; zoom in once; lasso over the middle 40 % of the cells (selects them) |
| Gene expression | show one new gene |
| Linked views | colour by the next field |
| Groups, Most expressed genes | switch to the next grouping variable |
| Marker genes, Enriched pathways | switch the table to the next grouping variable |
| Trajectory, HLA & TCR motifs, Trekker | colour by the next variable |
| Immune repertoire | open the next analysis tab |
| Spatial | show the next FOV / section |
| Extra material | show the next content |
| Data info | switch to another dataset in the menu, then back to the session's own (`loadData.switch`, `loadData.switch_back`) |

The full list with one line each is `standard/actions.tsv`. The value an action switches to is chosen the
same way on every revision and recorded (`arg`). An action runs on the dataset of its page. A control that a
revision does not have is `unavailable`. Switching datasets needs a second dataset in the menu, so the
session that runs it also loads the revision's small `example` CRB (`demo_trekker` when its own dataset is
`example`); switching back measures opening the session's own, usually large, dataset from the menu.

**Server steps** (`standard/server_steps.R`). After the sessions, each revision runs the R work behind the
pages in a fresh R process per dataset and round, step by step and without a browser: reading the CRB, cell
names, metadata, projection, one gene (first and repeated read), a block of 12 genes, their mean
expression, 10 % of the cells for those genes, and building and JSON-encoding the Linked views bundle with
the revision's own Viewer code. Only the Cerebro object's public methods are called; a step a revision
does not have is `unavailable`. Each step also stores a hash of its result, so the run shows when two
revisions return different data. A slower page can then be traced to the step that got slower.

## 2. Platform

**Linux, WSL or Windows.** Candidates are installed (`R CMD INSTALL`) and run as a deployment runs them,
not loaded with `load_all`: `load_all` attaches every Imports package, which enlarges the R heap and moves
its GC pauses onto whichever page step allocates next. Numbers produced before this standard on Windows
(`load_all`, a WMI memory sampler about every 4 s) are not comparable and are not recorded here.

The two platforms measure the same things the same way, except what draws and how memory is counted:

| | Linux / WSL | Windows (Git Bash) |
|---|---|---|
| Chrome draws with | software (no GPU in WSL) | the machine's GPU (`--disable-gpu` removed, WebGPU on) |
| CPU and memory sampler | `sampler.R`, from `/proc` | `sampler.ps1`, from the Windows process API |
| Memory of a tree | PSS | private bytes (Windows has no PSS) |
| Screenshots | taken at quarter scale | taken at full size, every 4th pixel kept: with the GPU, Chrome's own downscaling alternates between two samplings from one capture to the next, so a static page never looked final |

The platform is part of the run id and the manifest records the renderer each session saw (`renderer`),
so **records are compared only within one platform**. The GPU renderer alone, on synthetic points, has its
own tier (section 4).

The run's own conditions are part of the evidence (section 6): host, kernel, CPU, memory, R and Chrome
versions, a CPU noise canary before and after, and the load average.

## 3. Candidates, baselines and data

- Only **committed revisions** are measured. Each is exported with `git archive` and installed into its
  own library. The server refuses to start if the loaded package is not the one in the candidate's library.
- Candidate and baseline are measured **in the same run**, alternating, with the order flipping every
  round, dataset and cold page. Old numbers are never reused as a baseline.
- **Which page runs on which dataset** is `standard/coverage.tsv`: per page, its large dataset and the demo
  CRB that stands in when that dataset is not given. A large dataset is one prepared CRB (with its H5
  sidecar and Viewer Pack), **given on the command line**: `--mouse1m FILE`, `--ren FILE`, `--cosmx FILE`.
  A path that does not exist stops the run; a dataset that is not given is not an error.

| Page | Large dataset (option) | Demo CRB when it is not given |
|---|---|---|
| Data info, Projection, Linked views, Groups, Gene expression, Trajectory, Colour management, Gene ID conversion, About | `--mouse1m` (10x E18 mouse brain, 1.3 M cells): the main fixture, most pages run here | `example`, `demo_full_tcr_bcr` (Trajectory) |
| Immune repertoire, Extra material | `--ren` (1.46 M cells, TCR and BCR): only what the mouse brain lacks | `demo_full_tcr_bcr`, `example` |
| Spatial | `--cosmx` (NSCLC, 800 k+ cells) | `demo_spatial_visium` |
| Marker genes, Most expressed genes, Enriched pathways | none exists | `example` |
| Trekker | none exists | `demo_trekker` |
| HLA & TCR motifs | none exists | `demo_hla_tcr_dextramer` |

Adding a large dataset is a new name in the `fixture` column of `coverage.tsv`, which becomes the option
`--<name>`; no other code changes. A page with no dataset in a run is listed under
"Not measured" in the summary, never silently dropped. `plan.tsv` in the run record says what ran where,
and its checksum is in the manifest: **records are comparable only when their plans are equal**, because
moving a page from a demo to a large fixture changes its numbers.

**Same-era rule.** The large fixtures are built by current CerebroNexus and opened by both revisions, so
compare revisions that read the same CRB format. Each revision also ships its own demo CRBs, and those
changed over time (HLA 12,000 cells in 4.3.6, 2,000 today), so comparing across eras on demo data measures
the data as much as the code.

## 4. Tiers

| Tier | Purpose | When | Data | Rounds | Latency tolerance | Loading card | Memory | Recorded |
|---|---|---|---|---|---|---|---|---|
| **L0** | catch a regression before it merges | by hand, before merging a pull request | demo CRBs (large ones if given) | 1 | 30 % + 300 ms (provisional) | > 250 ms on at least 2 pages | reported | not recorded |
| **L1** | follow master | when `origin/master` changes (`track`) | the large datasets given, demo otherwise | 3 | 20 % + 300 ms (provisional) | > 300 ms on at least 2 pages | reported | `runs/` + `INDEX.tsv` |
| **L2** | release evidence | before a release | as L1 | 5 | 15 % + 300 ms (provisional) | > 250 ms on at least 2 pages | gated 10 % + 128 MiB | `runs/` + `INDEX.tsv` |
| **GPU** | the point renderer on a real GPU | by hand, when the renderer changes, and before a release | 1 M synthetic points | 5 | reported, not judged | - | - | `runs/gpu/` |

The numbers are `standard/policy.tsv`. They are set from **A/A runs** (the same revision as baseline and
candidate, stored under `runs/calibration/`, checked with `calibrate.R`). A tier whose `calibrated_by` is
`-` has no A/A behind it and **cannot be recorded**; it can still be run. No tier is calibrated yet, so all
tolerances are provisional. Whatever the A/A shows, **a tier sees only regressions larger than its noise**.

**GPU tier.** WSL gives Chrome no usable GPU, so this tier runs on Windows (`standard/gpu/run.R`). It takes
only `inst/viewer/www/cell_points_gpu.js` from each revision, loads it in a blank page in Chrome with the GPU
on, and times the renderer on the same synthetic points: start, building and uploading the colours, the
first frame, and pan/zoom frames (median and 95th percentile), for group colours and for RGB. The two
revisions alternate, each in a fresh Chrome. The run is invalid when the renderer did not use WebGPU, lost
its GPU context or failed. It is reported only, until A/A runs show its noise.

## 5. Verdict

`judge()` in `standard/lib.R` compares, per page and visit, the median over rounds of the candidate with the
baseline's.

1. **Completion.** A page or action that finished on the baseline must finish on the candidate (`error`,
   `unavailable`, `timeout` and `stuck_busy` are not finished), and a planned page that the baseline measured
   must still be there. One the baseline itself does not finish is `SKIP`.
2. **Latency.** `visual_complete_ms` fails when `candidate > baseline x (1 + rel) + floor`. Actions are judged
   the same way, except when the two revisions chose a different value (another gene, another colour
   column): that is reported, because they did different work.
3. **Loading card.** `loader_visible_ms` fails when it grows by more than the loader floor **on at least two
   pages**; on one page it is only reported. A card appears only when a page is not ready after 180 ms, so
   a page near that line flips between 0 and 150 ms from run to run, while a real change to the mechanism
   shows on many pages.
4. **Budget.** First visits (`cold`, `journey`) under 2 s (3 s for Trajectory and HLA), repeat visits
   (`repeat`, `revisit_after_tour`) under 500 ms; Data info's initial load and actions have no budget yet. A
   page is held against its budget with the **later of `visual_complete_ms` and `server_busy_ms`**: a page
   that looks done while the server is still busy is not done. Under budget on the baseline and over budget
   plus the latency floor on the candidate fails. Pages over budget are listed in every summary, with which
   of the two held them: that list is the 3-second target.
5. **Memory.** Session peaks of the R and Chrome trees, reported; at L2 `> base x 1.10 + 128 MiB` fails.
6. **Server steps.** Reported with their change, and a note when a step is unavailable or the two revisions
   return different results. Not judged.

Outcome and exit code: `PASS` 0, `FAIL` 1, `INVALID` 2 (an R error is also 2). Evidence is **invalid**,
never a pass or a fail, when: fewer rounds or pages than the tier requires; a session failed twice; the CPU
canary drifted by more than the tier's ratio between the start and the end of the run; or another benchmark
or headless browser was already running (a run takes a lock and checks `/proc`). A new metric definition
gets a new contract name; **results of different contracts are never pooled**.

**One revision only (`--solo`).** Measures just the given revision with the tier's plan and rounds
(`--rounds N` overrides them) and records its times: no baseline, no verdict, outcome `RECORDED` (exit 0)
or `INVALID`. The evidence checks above still apply. Because nothing is judged, a solo run can be recorded
without a calibrated tier; in `INDEX.tsv` its baseline columns are empty. Its absolute numbers depend on the
machine: compare them only with runs from the same host.

## 6. The run record

```
runs/<UTC>-<candidate sha12>-<tier>-<platform>/
  manifest.tsv   tier, contract, candidate and baseline refs, SHAs and package versions, rounds, datasets,
                 fixture paths, sizes and version stamps, plan checksum, uncovered pages, host, kernel, CPU,
                 memory, R, Chrome, canary, load, harness commit, the policy row used, verdict
  plan.tsv       which page ran on which dataset
  raw.tsv        one row per observation (session mode, its place in the session, all metrics, status,
                 action argument, error text, idle wait, memory peaks)
  server.tsv     one row per server step, revision, dataset and round (time, status, result hash)
  schedule.tsv   the order the sessions ran in and the pages each visited
  verdict.tsv    one row per rule applied
  summary.md     failures, coverage, pages over budget, journey order, pages and actions (visual, busy,
                 trail, largest message, loader, JS heap), server steps, memory
  logs/          one log and one CPU/memory trace per session (not committed)
runs/INDEX.tsv   one line per recorded run: refs, SHAs, verdict, headline medians for the candidate and baseline
runs/CURRENT_<tier>   id of the newest recorded run of the tier
runs/calibration/     the A/A runs behind policy.tsv
runs/gpu/<UTC>-<candidate sha12>-gpu-windows/   manifest.tsv, raw.tsv, summary.md of a GPU run
```

Runs are never overwritten. `INVALID` runs are kept in their folder but are not entered in `INDEX.tsv` and
do not move `CURRENT_<tier>`. Commit everything except `logs/`.

## 7. How it runs

```bash
# from the paper-code repository, in Linux or WSL, with CerebroNexus beside it (or --cerebro-repo DIR)
bash topics/viewer_performance/run.sh l0 --candidate HEAD --baseline origin/master
bash topics/viewer_performance/run.sh l1 --candidate origin/master --baseline auto --record
bash topics/viewer_performance/run.sh track        # L1 of origin/master if it moved; otherwise does nothing
bash topics/viewer_performance/run.sh l1 --candidate REF --baseline REF --allow-same   # A/A
bash topics/viewer_performance/run.sh l2 --candidate REF --solo [--rounds N] [--record] # one revision, times only
bash topics/viewer_performance/run.sh l1 --candidate REF --solo --pages overview,geneExpression --mouse1m FILE  # part of the plan, never recorded
Rscript topics/viewer_performance/standard/calibrate.R RUN_DIR                         # noise check
bash topics/viewer_performance/run.sh standard-tests
# on Windows (Git Bash), with Chrome and R (chromote, httpuv, jsonlite):
bash topics/viewer_performance/run.sh gpu --candidate REF --baseline REF --record
```

Any of these takes `--mouse1m FILE --ren FILE --cosmx FILE` for the large datasets (section 3); `plan.tsv`
and the manifest (path, H5 size, version stamp of each one used) say what was measured.

- **L0 is run by hand** on the maintainer's machine (WSL) before a pull request is merged: the pull request's
  head as candidate, its merge base (or `origin/master`) as baseline. Do not merge on `FAIL`; repeat an
  `INVALID` run once.
- **L1 follows master from the maintainer's machine** (WSL): run `track` from cron, or from Windows Task
  Scheduler as `wsl.exe -e bash -lc "cd .../CerebroNexus_paper_code && bash topics/viewer_performance/run.sh track"`.
  Cloud runners cannot do this tier: it needs a quiet machine and the large datasets.
- **L2 is run by hand before a release.**
- **GPU is run by hand on Windows** when `cell_points_gpu.js` changes, and before a release.

## 8. Changing the standard

- A new or changed metric: new contract name in `standard/lib.R` and `hook.js`, new tests.
- A changed threshold, plan or fixture: run an A/A for the tier, store it under `runs/calibration/`, put its
  id in `calibrated_by`, and check it with `calibrate.R` (every tier must pass its own A/A). A different plan
  has different noise.
- The verdict logic is unit tested (`tests/test-standard.R`); `standard-tests` must pass.

## 9. Limits (today)

- **Large datasets:** a page whose large dataset is not given runs on its small demo CRB; it does not move
  to a different large dataset instead, so the plan stays what the table says. HLA, Trekker and the table pages (Marker genes, Most
  expressed genes, Enriched pathways) have no large dataset at all and stay on demos.
- **The mouse brain's trajectory** is a marker-guided illustration that CerebroNexus `run-demo.R` adds, not a
  fitted trajectory; it exercises the page, not the biology.
- **Resolution.** About 50 ms per frame, about 150 ms CPU and memory samples, `trail_ms` about 250 ms; the
  noise floor is larger than all of them. `server_busy_ms` cannot tell a pause of 3 s or more from the end
  of the work, and sees only CPU: an R server blocked waiting (on disk, on memory the host is short of)
  looks quiet.
- **Cost.** One cold session per page, revision and round: a run takes several times as long as one
  session per dataset did, most of it starting servers on the large datasets.
- **GPU.** L0 to L2 render in software, so the Viewer's WebGPU path is not exercised there. The GPU tier
  measures the renderer alone on synthetic points, not the whole Viewer on real data.
- **Actions.** One or a few per page (`actions.tsv`). Not scripted: Linked views filters and brushing across panels, export and download, and the options inside the Immune repertoire, Spatial and Trajectory pages beyond the one listed.
- **One dataset per page** means no median over datasets: a page's number is its own, so a dataset-specific
  slowdown cannot hide behind other datasets, and a dataset-specific outlier cannot be averaged away. Rounds
  are what separate signal from noise.
- **All tolerances are provisional** until each tier's A/A run is stored (for L1 and L2, with the large
  datasets).

## 10. Records so far

None. No calibration and no comparison run has been recorded under this standard yet.
