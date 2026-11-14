# How Viewer performance is measured

The rules that `standard/` implements, so that two runs in `runs/` can be compared and a slower page can be
traced. How to run it is in [README.md](README.md).

## 1. What a measurement is

One **observation** is a user action on a running Viewer. One **session** is one fresh R server and one fresh
headless Chrome on one dataset, for **one page**. A **run** measures one CerebroNexus revision: every page of
the plan, `--rounds` times (default 5), each time in its own session. The Projection page also gets two
sessions of its own for its first plot (below). With `--baseline` a second revision is measured in the same
run (section 6).

| Visit | What is timed |
|---|---|
| `initial` | Data info loading the dataset (only in the session of the Data info page) |
| `cold` | the page opened after Data info only, in its fresh session: it pays its own first-use costs (the expression backend, the repertoire tables), whatever other pages exist |
| `first_start` | the Projection page from the start, with nothing kept from an earlier start: the server's cache directory is emptied before the session, as on a new installation. Chrome navigates to a Viewer that has just started, the page is opened as soon as the sidebar offers it, and the clock runs from the navigation (below). Its own session; only pages with `first_plot = yes` in `standard/coverage.tsv` have it |
| `first_plot` | the same from a later start: the cache directory holds what earlier sessions of the run left. Its own session, right after `first_start` |
| `action` | one thing done on the open page, right after its cold visit (`standard/actions.tsv`, in the listed order) |

Many things load the first time a page needs them, and the cache is shared by the whole R process. A fresh
session per page makes a page's number its own: it does not depend on which pages came before.

**What the Viewer keeps between starts.** CerebroNexus keeps files in the user's cache directory
(`tools::R_user_dir("CerebroNexus", "cache")`: the finished page, a data set's first view, its cell names
file, the result of checking an H5 file). Whether a start finds them decides its time, and a revision would
find what another revision left. So every server of a run gets `R_USER_CACHE_DIR` set to a directory of that
run and that revision, never the user's own, and the directory is deleted when the run ends:

- `kept` is empty when the run begins, is filled by the warm-up (below) and stays. Every `initial`, `cold`,
  `action` and `first_plot` observation, and the server steps, are therefore **later starts**: the same data
  set has been opened by this revision before, in round 1 as in round 5.
- `empty` is emptied before every `first_start` session.

`raw.tsv` records how many files the cache directory held before each server started (`cache_files`: 0 for
`first_start`). The operating system's file cache is not emptied: a `first_start` reads its files from memory,
not from a cold disk.

| Metric (contract `blackbox-v7`) | Meaning |
|---|---|
| `visual_complete_ms` | **the KPI.** Click to the last frame that differs from the final screen. Screenshots back to back (about every 50 ms); a frame counts as different when more than 0.05 % of its pixels differ from the last frame. |
| `first_plot_ms` | only on the `first_start` and `first_plot` visits: navigation to the first frame that shows the projection (below). The number the tool comparison reports as "first plot". `plot_click_ms` (when the Projection page was opened, on the page's clock, which starts at the navigation) and `plot_ink` (the ink share of the accepted frame) are in `raw.tsv` |
| `server_busy_ms` | Click to the moment the R server's process tree goes quiet: from then on every 1 s window stays under 5 % of a core until the harness has seen 3 quiet seconds. A shorter pause is part of the work. |
| `trail_ms` | After the page looked finished, how long the R server or Chrome kept working. |
| `ws_in_bytes`, `ws_out_bytes`, `ws_max_msg_bytes` | Websocket traffic from the click to the end of the trail, and the largest single message (`ws.js`). |
| `loader_visible_ms` | Time a loading card or overlay is on screen (from the DOM). |
| `visual_90_ms` | Click to the first frame that is 90 % identical to the final screen. |
| `settled_ms`, `visible_ms`, `chrome_busy_ms` | Last DOM change anywhere / inside the page; when Chrome went quiet. Diagnostic. |
| `r_peak_mib`, `chrome_peak_mib` | Peak memory of the R server's and Chrome's process trees during the observation and its trail, sampled every ~150 ms. On Windows private bytes (Windows has no PSS), on Linux PSS. |
| `js_peak_mib` | JS heap (`JSHeapUsedSize`) peak per observation. |
| Server steps | Time of each R step behind the pages, without a browser (section 4). |

Why pixels: the Viewer cannot be asked when a plot has finished drawing in every version, and DOM signals
exist in some versions only. Screenshots need no cooperation from the Viewer, so they are comparable across
versions. Pixels miss work that changes none of them (on the mouse brain, Projection looks done while R
still sends 29 MB of cell names), which `server_busy_ms`, `trail_ms` and the websocket counts show.

**First plot from the start.** The click-to-last-frame KPI cannot be set beside the tool comparison
(`topics/tool_comparison`), which times what the other viewers show without any click: from the browser's
navigation to the first plot. The `first_start` and `first_plot` visits measure that event on the same Viewer
(they differ only in what the cache directory holds), so the numbers of the two topics can be read against
each other. Definition, as in the tool comparison (`harness.py`):

- The clock starts when Chrome is told to navigate to the Viewer. The server has answered its first connection
  and Chrome was started before, so neither start-up is in the time. Unlike the other visits it does not wait
  for a quiet server first: the work the server still has after starting is part of starting.
- The hook opens the Projection page as soon as the sidebar offers it and Shiny is connected and idle (a click before
  that is dropped and the page stays on Data info), on every frame of the load, and clicks again every 2 s until the
  page is shown. The clock stays at the first click.
- A frame **shows the plot** when the projection canvas is at least 200 x 200 px on screen and at least 1 % of
  its pixels are ink: further than 60 (0-255 RGB distance) from the canvas's most frequent colour, and dark
  (V < 0.5) or coloured (saturation above 0.1). `first_plot_ms` is the time of the first of two frames in a
  row that show it, so a flash that is gone the next frame does not count.
- `visual_complete_ms` and `visual_90_ms` of this visit run from the same navigation, to the last frame that
  differs from the final screen; `server_busy_ms`, memory and websocket traffic also start there. The session
  ends one second after the page finished, then the usual wait for a quiet server and Chrome.
- A page that finishes without ever showing the plot is `no_plot`; the other statuses are as below.

What still differs from the tool comparison, and is not corrected: frames come about every 50 ms from the full
page, one after the other as fast as a capture allows (`frame_ms` in `raw.tsv`: about 90 ms, more while the page
loads; there the element every 250 ms plus the time of the capture), stamped when the capture was taken (there:
when it was received, a little later); the viewport is 1619 x 950 (there 1600 x 1000); Chrome is driven with chromote (there
Playwright); the dataset is the full 1m mouse brain with all its metadata (there the first 10k to 500k cells
with three columns). Read the numbers as the same event, not as the same measurement: measure both on one
revision before comparing them.

**Quiet start and end.** Every observation, except the first plot above, starts when the R server's tree and Chrome's tree have both been
quiet for 3 seconds (every 1 s window under 5 % of a core for R, under 25 % for Chrome), and ends only when
they are quiet again. Without the start a click races with work left from before; without the end that work
would belong to no page.

**Idle machine.** The two trees say nothing about the rest of the machine. Before every session the harness
waits until all CPUs together were below 15 % for 3 one-second windows in a row (`ps::ps_system_cpu_times()`).
After 10 minutes of waiting (`PERF_IDLE_MAX_S`) the session starts anyway and is marked: `schedule.tsv` has
the CPU share, the wait and `host_idle` of every session, and a run with marked sessions says so under
"Problems".

**CPU canary.** A fixed single-threaded computation of about 0.4 s is timed (the fastest of 5) when the run
begins and after every round. A run whose readings differ by more than a factor 1.2 says so under "Problems":
the machine was busy with something else or changed its speed. All readings are in the manifest.

**Warm-up.** One discarded session per revision and dataset precedes the measured ones (also for the demo
CRBs, and for the example CRB the dataset-switching actions load). The first read of a large dataset's H5
comes from disk, later ones from the file cache; and the session leaves in `kept` what the Viewer keeps for
the data set. On the Projection page's dataset the warm-up opens that page too.

A page is **finished** when it has content, Shiny has been quiet for 500 ms and nothing in the page has
changed for 500 ms. A page that Shiny still reports busy after 15 s without any change is `stuck_busy`; one
not finished after 90 s is `timeout`; one that finishes with an output error or a lost connection on screen
is `error`. An action whose control a revision does not have is `unavailable`. These are results, not errors
of the harness; medians are taken over the rounds that finished (`ok`).

## 2. What is measured where

Every page is measured on **exactly one dataset**, never twice (`standard/coverage.tsv`; the two first-plot
sessions of Projection are the same page on the same dataset, other visits). The large
datasets are given with `--large-examples DIR` (required); `standard/fixtures.tsv` says where each CRB lies
below it, and a missing one stops the run, so a run always measures the whole plan.

| Dataset | Pages | Why |
|---|---|---|
| `1m` (10x E18 mouse brain, 1.3 M cells) | Data info, Projection, Linked views, Groups, Gene expression, Trajectory, Colour management, Gene ID conversion, About | the main dataset: the pages every dataset has |
| `ren` (Ren et al. COVID-19, 1.46 M cells) | Immune repertoire, HLA & TCR motifs, Extra material | TCR and BCR, HLA: what the mouse brain lacks |
| `cosmx` (CosMx NSCLC, 800 k cells, 8 FOVs) | Spatial | the only spatial dataset |
| `example`, `demo_trekker` (demo CRBs of the measured revision) | Marker genes, Most expressed genes, Enriched pathways; Trekker | none of the large datasets has them |

Shared pages (Projection, Groups, ...) are measured on `1m` only, not again on `ren` or `cosmx`. The fourth
prepared dataset (`tcell`, pan-cancer T cells) adds no page the others do not cover and is not used.
Switching datasets (`loadData.switch`) needs a second dataset in the menu: that session also loads the
revision's `example` CRB. The demo CRBs come from the measured revision and change between versions, so
those pages compare the data as much as the code across distant versions.

## 3. Platform

**Windows**, with the data on Windows (the reference platform). Revisions are installed with `R CMD INSTALL` from
`git archive` of the commit into a cache library (`PERF_CACHE`, default `%LOCALAPPDATA%\cerebronexus-viewer-perf`), not
loaded with `load_all`; the server refuses to start when the loaded package is not that library's. Chrome draws with
the machine's GPU (`--disable-gpu` removed, `--ignore-gpu-blocklist`, WebGPU on). CPU and memory come from `sampler.ps1`. Screenshots are taken at full
size and every 4th pixel is kept (Chrome's own downscaling alternates between two samplings with the GPU).

The harness also runs on Linux (`sampler.R`, PSS; Chrome with `--use-gl=angle --use-angle=gl`; without a GPU, as in WSL,
it renders in software and the manifest's `renderer` says SwiftShader), but numbers from different platforms
or machines are not comparable; `compare.R` says when two runs differ in platform, host or CPU.

## 4. Server steps

After the sessions of each round, `server_steps.R` runs the R work behind the pages once per dataset in a
fresh R process, without a browser, with the `kept` cache directory: reading the CRB, cell names, metadata, projection, one gene (first and repeated
read), a block of 12 genes, their mean expression, 10 % of the cells for those genes, and the Linked views
bundle. Each step stores a hash of its result. A slower page can be traced to the step that got slower.

## 5. The run record

```
runs/cerebronexus-<version>_<YYYYMMDD-HHMMSS>_<sha7>[_base][_partial]/
  manifest.tsv   contract, CerebroNexus version, ref and SHA, platform, host, OS, CPU, memory, GPU, renderer,
                 R and Chrome versions, harness commit, --large-examples, each dataset's relative path, CRB
                 checksum, H5 size and version stamp, plan checksum, the cache rule, every CPU canary reading
                 and their ratio, the idle limit and how many sessions started on a busy machine, the run it
                 was measured with (pair_id, pair_role, pair_with), start and end
  plan.tsv       which page ran on which dataset, with its actions
  schedule.tsv   the order of the sessions (of both revisions, when two were measured), and for each the
                 machine's CPU share before it, the wait for an idle machine and whether it finished
  raw.tsv        one row per observation (all metrics, status, action value, error text, idle wait, files in
                 the cache directory before the server started)
  pages.tsv      one row per page and visit: medians over the rounds that finished, KPI range, share ok
  server.tsv     one row per server step, dataset and round
  summary.md     pages and actions, memory per dataset, server steps, problems
  logs/          one log and one CPU/memory trace per session (ignored by Git)
```

The version comes from the measured revision's `DESCRIPTION`. Runs are never overwritten. A run whose
session failed twice, whose CPU canary moved by more than a factor 1.2, whose sessions started on a busy
machine, whose `first_start` found files in its cache directory, or whose pages did not finish in every round
says so under "Problems" in its summary; it is kept, not discarded. `--pages` runs end in `_partial` and are
not a full record. `_base` marks the baseline of a noise check (below), whose folder would otherwise have the
candidate's name.

## 6. Comparing runs

**Two revisions in one run.** `run.R --candidate B --baseline A` measures both in the same run. Their
sessions take turns: the same page of the same round is measured for one revision and then at once for the
other, and which one goes first changes with every page and every round. Each revision has its own library,
its own cache directories and its own run folder, a full record as above; the two manifests carry the same
`pair_id`. Both revisions therefore meet the same state of the machine. Two runs made at different times do
not: a machine that was busier during one of them shows as a difference between the revisions, and
`compare.R` says which of the two cases it has.

**The decision.** `compare.R A B` takes the observations of the rounds that finished from `raw.tsv` of both
runs, for every page and visit:

- the medians of A and B and their difference;
- the p-value of an exact two-sided rank-sum (Mann-Whitney) test: the share of all ways the observed values
  could be dealt into two groups of these sizes that separate the groups at least as far as observed (equal
  values share their rank);
- `slower` or `faster` when p <= 0.05 **and** the medians differ by more than the resolution of the metric:
  for the metrics read off frames, the median time between two frames of that row (about 50 to 130 ms);
- `not resolved` otherwise: the rounds overlap, or the difference is below one frame. This is not "the
  same": it says the run could not show a difference;
- `too few rounds` when the numbers of rounds cannot give p <= 0.05 whatever the values: the smallest
  possible p is 0.10 for 3 rounds against 3, 0.029 for 4 against 4 and 0.008 for 5 against 5. This is why
  the default is 5 rounds, and why the runs made with 3 rounds can be listed against each other but not
  judged.

There is no percentage threshold. The earlier line (20 % + 300 ms) could not mark a page of 300 ms that
became three times faster, and marked nothing with a known error rate.

Every tested row is tested at 0.05, so of the about 40 rows of a full plan up to two would be marked by
chance if nothing had changed; `compare.R` prints that number. A single marked row among many is weak evidence; a
change that the code explains, and that the server steps or the server busy time show too, is not.

For runs made together, `compare.R` also gives the smallest and largest difference B - A within one round.
`--metric` compares any other column of `raw.tsv` the same way (`first_plot_ms`, `server_busy_ms`,
`r_peak_mib`, ...), without the frame floor for metrics that are not read off frames.

**Noise check.** `run.R --candidate A --baseline A` measures one revision against itself. Every difference
`compare.R` then reports is noise of the measurement; it prints the median, the 90th percentile and the
largest difference of the medians, and no row should be marked beyond the chance number above. Do this once
per machine and contract, and again when the machine or the harness changes; a change smaller than this noise
needs more rounds, not a second look at the same numbers.

`compare.R` also marks pages that stopped finishing, pages present in one run only, actions that switched to a
different value (another gene, another column), and the manifest facts in which the runs differ (contract,
platform, host, CPU, memory measure, plan, large datasets). Compare runs from the same machine and plan.

## 7. Changing the standard

- A new or changed metric: new contract name in `standard/lib.R` and `hook.js`, new tests.
- A new page or action: a row in `coverage.tsv` or `actions.tsv`, and for an action its code in `hook.js`;
  the tests check that every listed action exists in `hook.js` and every page is listed once.
- A changed plan changes `plan_md5`, so `compare.R` flags runs before and after it.
- `tests/test-standard.R` must pass.

## 8. Limits

- **Resolution.** About 50 ms per frame, about 150 ms CPU and memory samples. `server_busy_ms` cannot tell a
  pause of 3 s or more from the end of the work, and sees only CPU: a server waiting on disk looks quiet.
- **Cost.** One session per page and round, most of the time spent starting servers on the large datasets;
  five rounds and a second revision make a run about three times as long as one revision with three rounds.
- **First plot.** Measured on the Projection page of `1m` only. It is one number from one navigation, with
  frames about 90 to 130 ms apart; the first-plot rule (1 % ink) is a judgement about what a plot is, taken over from the tool
  comparison, not something the Viewer reports.
- **Not yet as the tool comparison's round 3** (`topics/tool_comparison/PROTOCOL_round3.md`, appendix). The
  first-plot visits still click "Projection" and look for ink in the projection canvas only: a
  `?page=projection` link, and the preview a newer Viewer draws in another canvas before its session exists,
  are not measured, and there is no time at which the plot answers a gesture. The start of the server
  (`server_start_s`) is polled every 0.2 s with connections that take up to a second to fail, so it is too
  coarse for the differences between ways of starting, and only `launchCerebro()` is used, not `start.R`.
- **Cache.** Two states are measured, nothing kept and a later start; a data set that is new to a Viewer
  that has run before is not. The file cache of the operating system is always warm.
- **Fixtures.** The large CRBs were written before the cell-index layout and before CRBs recorded the
  checksum of their H5 file. A revision that reads both layouts is measured on the old one, so what it
  gains or pays on files it writes itself is not in these numbers.
- **Small differences.** With five rounds a row is marked only when the two revisions do not overlap at
  all, or nearly. A real difference smaller than the spread of the rounds stays `not resolved`.
- **Actions.** Not scripted: Linked views filters and brushing, export and download, and most options inside
  Immune repertoire, Spatial and Trajectory beyond the one listed.
- **The mouse brain's trajectory** is a marker-guided illustration added by `run-demo.R`; it exercises the
  page, not the biology.
- **GPU.** `standard/gpu/run.R` measures the point renderer alone on synthetic points, two revisions in one
  run, separately from this standard.
