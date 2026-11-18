# How Viewer performance is measured

The rules that `standard/` implements, so that two runs in `runs/` can be compared and a slower page can be
traced. How to run it is in [README.md](README.md).

## 1. What a measurement is

One **observation** is a user action on a running Viewer. One **session** is one fresh R server and one fresh
headless Chrome on one dataset, for **one page**. A **run** measures one CerebroNexus revision: every page of
the plan, `--rounds` times (default 7), each time in its own session. The Projection page also gets two
sessions of its own for its first plot (below), and every round ends with one **tour** session per revision.
With `--baseline` a second revision is measured in the same run (section 6).

| Visit | What is timed |
|---|---|
| `initial` | Data info loading the dataset (only in the session of the Data info page) |
| `cold` | the page opened after Data info only, in its fresh session: it pays its own first-use costs (the expression backend, the repertoire tables), whatever other pages exist |
| `first_start` | the Projection page from the start, with nothing kept from an earlier start: the server's cache directory is emptied before the session, as on a new installation. Chrome navigates to a Viewer that has just started, the page is opened as soon as the sidebar offers it, and the clock runs from the navigation (below). Its own session; only pages with `first_plot = yes` in `standard/coverage.tsv` have it |
| `first_plot` | the same from a later start: the cache directory holds what earlier sessions of the run left. Its own session, right after `first_start` |
| `tour` | a page opened on the way, as a visitor goes on: one session per round opens the Viewer, stays 15 s on the page it opens on, then opens the other pages of `1m` one after another, 1.5 s after the last one finished, without waiting for a quiet server. What the Viewer prepares while a page is read, and what an earlier page left loaded, is part of these times |
| `action` | one thing done on the open page, right after its cold visit (`standard/actions.tsv`, in the listed order) |

Many things load the first time a page needs them, and the cache is shared by the whole R process. A fresh
session per page makes a page's `cold` number its own: it does not depend on which pages came before. A
visitor does not see that number for most pages, though: they open a page in a session that is already
running, after reading another one. The `tour` visit measures that, and depends on the pages before it by
design; its order is fixed (the plan's), so it is the same in every round and revision.

**What the Viewer keeps between starts.** CerebroNexus keeps files in the user's cache directory
(`tools::R_user_dir("CerebroNexus", "cache")`: the finished page, a data set's first view, its cell names
file, the result of checking an H5 file). Whether a start finds them decides its time, and a revision would
find what another revision left. So every server of a run gets `R_USER_CACHE_DIR` set to a directory of that
run and that revision, never the user's own, and the directory is deleted when the run ends:

- `kept` is empty when the run begins, is filled by the warm-up (below) and stays. Every `initial`, `cold`,
  `tour`, `action` and `first_plot` observation, and the server steps, are therefore **later starts**: the same
  data set has been opened by this revision before, in round 1 as in round 7.
- `empty` is emptied before every `first_start` session.

These directories lie below a short root (`PERF_RCACHE`, default `C:/cnxp` on Windows). The Viewer writes
several directories deep below `R_USER_CACHE_DIR`, and on Windows a path longer than 260 characters cannot be
written unless long paths are switched on; the write then fails without a word. Under the default
`%LOCALAPPDATA%` (redirected to a much longer path for a packaged app) that is what happened: the runs before
contract `blackbox-v8` kept nothing, and their "later starts" were first starts. `run.R` therefore writes a
file 160 characters deep below each directory before the run and stops when it cannot; the manifest records
how many files the warm-up left (`kept_files_after_warmup`), and a run where it left none says so.

`raw.tsv` records how many files the cache directory held before each server started (`cache_files`: 0 for
`first_start`). The operating system's file cache is not emptied: a `first_start` reads its files from memory,
not from a cold disk.

| Metric (contract `blackbox-v10`) | Meaning |
|---|---|
| `visual_complete_ms` | **the KPI.** Click to the last frame that differs from the final screen. By default screenshots back to back, as fast as a capture allows: on Windows, at full size, 75 to 140 ms apart (`frame_ms` in `raw.tsv`), so the KPI cannot resolve less than that; with `PERF_CAPTURE=screencast` every frame Chrome draws (**Frames** below). A frame counts as different when more than 0.05 % of its pixels differ from the last frame. A page that shows the Viewer's loading card (from 180 ms on) also counts the card's 150 ms fade: a page just slower than 180 ms reads about 150 ms slower than one just faster. |
| `page_ready_ms` | click (on the first-plot visits: navigation) to the page's own `cerebro:page-ready` event, on revisions that send it, read from the DOM without the frame interval. Diagnostic: the page sends it when its outputs are drawn and Shiny is idle, which can be after the last visible change; actions do not send it |
| `painted_ms` | on the same clock, the cell view's first `cerebro:cell-view-ready` event with `painted` for the overview projection, on revisions that send it (since `blackbox-v10`). Diagnostic, not a first-pixel time: the view sends it after the GPU queue is idle and two more frames, so it can trail the first frame that shows the points by a few hundred milliseconds (up to about 225 ms on 1.3 million cells). Re-renders do not move it |
| `first_plot_ms` | only on the `first_start` and `first_plot` visits: navigation to the first frame that shows the projection (below). The number the tool comparison reports as "first plot". `plot_click_ms` (when the Projection page was opened, on the page's clock, which starts at the navigation) and `plot_ink` (the ink share of the accepted frame) are in `raw.tsv` |
| `start_plot_ms` | the same frame, from the launch of the R server: **the first-plot number to compare across revisions** (below) |
| `server_busy_ms` | Click to the moment the R server's process tree goes quiet: from then on every 1 s window stays under 5 % of a core until the harness has seen 3 quiet seconds. A shorter pause is part of the work. |
| `trail_ms` | After the page looked finished, how long the R server or Chrome kept working. |
| `ws_in_bytes`, `ws_out_bytes`, `ws_max_msg_bytes` | Websocket traffic from the click to the end of the trail, and the largest single message (`ws.js`). |
| `loader_visible_ms` | Time a loading card or overlay is on screen (from the DOM). |
| `visual_90_ms` | Click to the first frame that is 90 % identical to the final screen. |
| `settled_ms`, `visible_ms`, `chrome_busy_ms` | Last DOM change anywhere / inside the page; when Chrome went quiet. Diagnostic. |
| `r_peak_mib`, `chrome_peak_mib` | Peak memory of the R server's and Chrome's process trees during the observation and its trail, sampled every ~150 ms. On Windows private bytes (Windows has no PSS), on Linux PSS. |
| `js_peak_mib` | JS heap (`JSHeapUsedSize`) peak per observation, read every 5th poll of the page (since `blackbox-v9`; before, every poll). |
| Server steps | Time of each R step behind the pages, without a browser (section 4). |

Why pixels: the Viewer cannot be asked when a plot has finished drawing in every version, and DOM signals
exist in some versions only. Screenshots need no cooperation from the Viewer, so they are comparable across
versions. Pixels miss work that changes none of them (on the mouse brain, Projection looks done while R
still sends 29 MB of cell names), which `server_busy_ms`, `trail_ms` and the websocket counts show.

**Frames.** How frames are captured is chosen with the environment variable `PERF_CAPTURE` and recorded as
`capture` in `raw.tsv`, the manifest and the summary. Runs of `blackbox-v9` made with different modes are **not
comparable**: `compare.R` lists `capture` among the facts in which they differ (a manifest without it took
screenshots).

- `screenshot` (the default): while the page works, the harness polls the hook and takes a full screenshot
  (`Page.captureScreenshot`) after each poll, back to back; a frame is stamped half way through its poll and
  capture. Frames come 110 to 140 ms apart on Windows whether the screen changed or not, so every frame metric
  is quantised by about that much.
- `screencast` (to be validated before it becomes the default): `Page.startScreencast` (PNG, every frame, at most
  1619 x 950, the viewport: Chrome does not scale the frames) sends a frame each time Chrome's compositor draws a
  new one; each is acknowledged at once, as Chrome sends the next only after that. Frames are stamped by Chrome
  (`metadata.timestamp`, seconds since 1970 on the machine's wall clock, the clock of the click, `Sys.time()`).
  No frame means no change: a frame stands for the screen until the next one. The screencast starts before the
  click; the first frame it sends is the screen at the click (it counts as time 0). The hook is polled every 40 ms
  meanwhile, without screenshots. When the page is done, the screencast is restarted once for a check frame of the
  final screen: `capture_check` in `raw.tsv` is `same` when it equals the last frame received and `differs` when
  the screen changed after it (a frame Chrome dropped, or a change after the page was done: such a row's visual
  times are too early). `frame_lag_ms` is the median time from a frame's stamp to its arrival in R: it must be
  small and positive, or the two clocks disagree. `frame_ms` is still the median interval of the frames received
  after the click; frames only come with changes, so it is not the resolution of this mode (that is one frame of
  the compositor, about 17 ms, plus the time stamp) but an upper bound of it, and `compare.R`, which takes it as
  the smallest difference it marks, is then conservative.

Screencast frames, like screenshots on Windows, are full size and every 4th pixel is compared (Chrome's own
downscaling alternates between two samplings with the GPU; Linux screenshots are taken at quarter scale); a
screencast frame of another size than the viewport is reported in the session log. The faster polling also
makes the hook react sooner: on the first-plot visits it opens the Projection page up to about 100 ms earlier
than with screenshots.

**First plot from the start.** The click-to-last-frame KPI cannot be set beside the tool comparison
(`topics/tool_comparison`), which times what the other viewers show without any click: from the browser's
navigation to the first plot. The `first_start` and `first_plot` visits measure that event on the same Viewer
(they differ only in what the cache directory holds), so the numbers of the two topics can be read against
each other. Definition, as in the tool comparison (`harness.py`):

- The clock of `first_plot_ms` starts when Chrome is told to navigate to the Viewer. The server has answered
  its first connection and Chrome was started before, so neither start-up is in that time. Chrome and the
  CPU/memory sampler are started before the server is launched (since `blackbox-v9`; before, after the server
  listened, which put their 1-1.5 s start in `start_plot_ms` and had the sampler compete with the server's
  start for the CPU), as a visitor's browser is open before the App starts: `start_plot_ms` of `blackbox-v8`
  and `blackbox-v9` are not comparable. On 1.3 million cells the two give about the same `start_plot_ms`
  (4.0-4.2 s for 8.2.1 05b200515): the 1-1.5 s Chrome and the sampler took overlapped the server's reading of
  the data set, which the page now waits for instead. Because Chrome now navigates while the server may still
  read the data set, a first-plot observation is not done before the projection's own canvas exists (the page
  can show only its preview and stay quiet meanwhile). Unlike the other
  visits it does not wait for a quiet server first: the work the server still has after starting is part of
  starting. Where the server's start ends is the revision's choice, though: a revision that answers sooner and
  prepares the data set afterwards moves that work into `first_plot_ms` (8.2 answers after 0.6 s, 8.0 after
  5.3 s). `start_plot_ms` runs from the launch of the server's R process instead and does not depend on that
  choice. The server counts as started when Shiny reports that it listens (its log, read every 20 ms) and a
  connection is accepted: `server_start_s`.
- The hook opens the Projection page as soon as the sidebar offers it and Shiny is connected and idle (a click before
  that is dropped and the page stays on Data info), on every frame of the load, and clicks again every 2 s until the
  page is shown. The clock stays at the first click.
- A frame **shows the plot** when the projection canvas is at least 200 x 200 px on screen and at least 1 % of
  its pixels are ink: further than 60 (0-255 RGB distance) from the canvas's most frequent colour, and dark
  (V < 0.5) or coloured (saturation above 0.1). `first_plot_ms` is the time of the first of two frames in a
  row that show it, so a flash that is gone the next frame does not count. With a screencast, where an
  unchanged screen sends no second frame, a frame that shows it also counts when it stayed on screen 100 ms
  (about one screenshot interval) before the next frame or the end of the capture.
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

**Quiet start and end.** Every observation, except the first plot above and the tour, starts when the R server's tree and Chrome's tree have both been
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

The `initial` visit waits for the Data info page; a revision that opens on another page (8.2.1 and later open
on the Projection) is taken to Data info by a click, as a visitor would.

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

Shared pages (Projection, Groups, ...) are measured on `1m` only, not again on `ren` or `cosmx`. The tour
opens the pages of `1m` other than Data info and the Projection, in this order.

**Viewer Packs.** A large fixture carries the Viewer Pack written when it was prepared (`<crb>.viewer/`).
A revision may read it, rebuild part of it at run time (an older repertoire encoding: Immune repertoire then
took 25 s on `ren` instead of 1 s), or not use it at all, and that decides its pages' times more than its
code does. `pack_state.R` asks each measured revision what it makes of each Pack (`current`, `outdated`,
`invalid`, `none`, `unsupported`); the manifest records the answer (`fixture.<name>.pack`) and a run whose
Pack is not current for it says so under "Problems". Rebuild the Packs with the newest revision
(`buildViewerPack(crb, overwrite = TRUE)`) when they are not. The fourth
prepared dataset (`tcell`, pan-cancer T cells) adds no page the others do not cover and is not used.
Switching datasets (`loadData.switch`) needs a second dataset in the menu: that session also loads the
revision's `example` CRB. The demo CRBs come from the measured revision and change between versions, so
those pages compare the data as much as the code across distant versions.

## 3. Platform

**Windows**, with the data on Windows (the reference platform). Revisions are installed with `R CMD INSTALL` from
`git archive` of the commit into a cache library (`PERF_CACHE`, default `%LOCALAPPDATA%\cerebronexus-viewer-perf`), not
loaded with `load_all`; the server refuses to start when the loaded package is not that library's. Chrome draws with
the machine's GPU (`--disable-gpu` removed, `--ignore-gpu-blocklist`, WebGPU on). CPU and memory come from `sampler.ps1`. Screenshots (and
screencast frames) are taken at full size and every 4th pixel is kept (Chrome's own downscaling alternates between two samplings with the GPU).

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
                 checksum, H5 size and version stamp, its Viewer Pack's state for this revision, plan checksum,
                 the cache rule and directory, the files the warm-up kept, the tour, every CPU canary reading
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
- the p-values of all rows tested are adjusted together (Holm), so that the chance of marking **any** row
  when nothing changed is at most 0.05, not 0.05 per row;
- the Hodges-Lehmann shift of B against A (the median of all differences between a round of B and a round of
  A) with its 95 % confidence interval: how large the difference is, and how well it is known;
- `slower` or `faster` when the adjusted p <= 0.05 **and** the medians differ by more than the resolution of
  the metric: for the metrics read off frames, the median time between two frames of that row (about 75 to
  130 ms on Windows);
- `suggestive` when only the unadjusted p is <= 0.05: the kind of row that chance alone marks among many.
  Measure again with more rounds before reading anything into it;
- `not resolved` otherwise: the rounds overlap, or the difference is below one frame. This is not "the
  same": it says the run could not show a difference;
- `too few rounds` when no values could survive the adjustment with these numbers of rounds: the smallest
  possible p (0.10 for 3 rounds against 3, 0.008 for 5 against 5, 0.0006 for 7 against 7) times the number
  of rows tested is above 0.05. 5 rounds against 5 can mark a row among 6 at most, 7 against 7 among 85: this
  is why the default is 7 rounds for a full plan of about 40 rows.

There is no percentage threshold. The earlier line (20 % + 300 ms) could not mark a page of 300 ms that
became three times faster, and marked nothing with a known error rate. Contracts before `blackbox-v8` tested
every row at 0.05 on its own, so of the about 40 rows of a full plan up to two were marked by chance alone.

For runs made together, `compare.R` also gives the smallest and largest difference B - A within one round.
`--metric` compares any other column of `raw.tsv` the same way (`first_plot_ms`, `server_busy_ms`,
`r_peak_mib`, ...), without the frame floor for metrics that are not read off frames.

**Noise check.** `run.R --candidate A --baseline A` measures one revision against itself. Every difference
`compare.R` then reports is noise of the measurement; it prints the median, the 90th percentile and the
largest difference of the medians, and no row should be marked `slower` or `faster`. Do this once per machine
and contract, and again when the machine or the harness changes; a change smaller than this noise needs more
rounds, not a second look at the same numbers. A noise check is only valid when its own run has no problems:
one whose CPU canary moved, or whose sessions started on a busy machine, measured the machine, not the noise.

`compare.R` also marks pages that stopped finishing, pages present in one run only, actions that switched to a
different value (another gene, another column), and the manifest facts in which the runs differ (contract,
platform, host, CPU, memory measure, frame capture, plan, large datasets). Compare runs from the same machine and plan.

## 7. Changing the standard

- A new or changed metric: new contract name in `standard/lib.R` and `hook.js`, new tests.
- A new page or action: a row in `coverage.tsv` or `actions.tsv`, and for an action its code in `hook.js`;
  the tests check that every listed action exists in `hook.js` and every page is listed once.
- A changed plan changes `plan_md5`, so `compare.R` flags runs before and after it.
- `tests/test-standard.R` must pass.

## 8. Limits

- **Resolution.** 75 to 140 ms per frame on Windows with screenshots (`page_ready_ms` is finer where a revision
  sends the event); a screencast resolves single compositor frames, but is not validated yet (section 1,
  **Frames**). About 150 ms CPU and memory samples. `server_busy_ms` cannot tell a
  pause of 3 s or more from the end of the work, and sees only CPU: a server waiting on disk looks quiet.
- **Cost.** One session per page and round and one tour per round, most of the time spent starting servers
  on the large datasets; seven rounds and a second revision make a run about five times as long as one
  revision with three rounds.
- **First plot.** Measured on the Projection page of `1m` only. It is one number from one navigation, with
  frames about 90 to 130 ms apart; the first-plot rule (1 % ink) is a judgement about what a plot is, taken over from the tool
  comparison, not something the Viewer reports.
- **Not yet as the tool comparison's round 3** (`topics/tool_comparison/PROTOCOL_round3.md`, appendix). The
  first-plot visits still click "Projection" and look for ink in the projection canvas only: a
  `?page=projection` link, and the preview a newer Viewer draws in another canvas before its session exists,
  are not measured, and there is no time at which the plot answers a gesture. Only `launchCerebro()` is
  used, not `start.R`.
- **Cache.** Two states are measured, nothing kept and a later start; a data set that is new to a Viewer
  that has run before is not. The file cache of the operating system is always warm. Runs before contract
  `blackbox-v8` kept nothing between starts (section 1): their `cold`, `action` and `first_plot` rows are
  first starts too, and are not comparable with later runs.
- **Fixtures.** The large CRBs were written before the cell-index layout and before CRBs recorded the
  checksum of their H5 file. A revision that reads both layouts is measured on the old one, so what it
  gains or pays on files it writes itself is not in these numbers. Their Viewer Packs are those of one
  revision; an older revision measured on them may find them of another version (section 2).
- **Tour.** One fixed order of pages, one wait (15 s) and one pause between pages (1.5 s): a visitor who
  reads longer finds more prepared, one who clicks faster less.
- **Small differences.** With five rounds a row is marked only when the two revisions do not overlap at
  all, or nearly. A real difference smaller than the spread of the rounds stays `not resolved`.
- **Actions.** Not scripted: Linked views filters and brushing, export and download, and most options inside
  Immune repertoire, Spatial and Trajectory beyond the one listed.
- **The mouse brain's trajectory** is a marker-guided illustration added by `run-demo.R`; it exercises the
  page, not the biology.
- **GPU.** `standard/gpu/run.R` measures the point renderer alone on synthetic points, two revisions in one
  run, separately from this standard.
