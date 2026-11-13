# Comparative evaluation, round 3: start-up, first plot and interaction at scale

**DRAFT, written 2026-11-12. Not frozen: no hash is stored, nothing has been measured, and the points under
"Open decisions" are the owner's to settle.** When they are settled and the pilot (section 12) is done, this
text is frozen as round 2 was (SHA-256 in `results/round3/PROTOCOL.sha256`, later changes only under
**Deviations**).

**Revision under test (changed 2026-11-13).** CerebroNexus is the commit in [`../cerebronexus.pin`](../cerebronexus.pin):
branch `integration/8.3.0`, version 8.3.0, the same commit every other topic of this repository measures. It
replaces the `perf/viewer-startup` pin of the first draft. Findings 1 and 2 of the pilot record are expected to
be settled by the branch (the H5 file is hashed once, in the background; the H5 writer of the round-2 pin is in
it); the pilot is repeated on the new commit and says whether they are.

Round 2 ([PROTOCOL.md](PROTOCOL.md), Deviations D1-D9) stays as it is and its results stay in `results/`.
Round 3 repeats Task 3 with a changed measurement and adds two tasks. Tasks 1, 2 and 4 are not repeated.

## 1. Why a third round

Round 2 cannot see what CerebroNexus changed since, and two of its instruments are too coarse for the
differences that are left.

| Round 2 | What it misses |
|---|---|
| First plot = ink in the element `#cv-cv-a`, after a click on "Projection" | A `?page=projection` link now shows the cells before the session exists, in another canvas. The click route never asks for it, and the selector would not see it. |
| `t_ready` polled with `requests.get` every 0.1 s | On Windows a connection to a port nobody listens on fails only after about 0.5 s, so the result moves in steps of 0.5 to 0.6 s. Vitessce reads 0.5 s in the round-2 table and 0.30 s with a socket probe. |
| One element screenshot every 0.25 s | The differences between the fastest tools are 0.1 to 0.3 s. |
| No rule for the user's cache directory | CerebroNexus now keeps its page, a data set's first view and its cell names file there. Whether a start finds them decides its time. |
| One launch route | `start.R` answers before the package is loaded; `launchCerebro()` does not. |
| Largest tier 500,000 cells | The first plot of several tools grows with the cell number (round 2, Vitessce: 1.29, 1.68, 4.34 s); the full data set has 1.3 million. |
| Start-up only | Nothing is measured after the first plot. |

The question is the one of round 2: on the same data and the same machine, how do start-up, first plot and
memory grow with the cell number? Round 3 adds: when can the plot be used, how long do three common actions
take once it can, and what do a client without a GPU and a slow connection change?

Only machine-measurable quantities are compared. Every result is written down, including failures and the
configurations in which CerebroNexus is slow. No run is excluded.

## 2. What differs from round 2

| | Round 2 | Round 3 |
|---|---|---|
| CerebroNexus | `tmp/应急` at `f86667ae` (6.0.0) | the commit of `../cerebronexus.pin` (`integration/8.3.0`, 8.3.0); installed from `git archive` of that commit |
| CerebroNexus configurations | `cerebronexus_default` (embedded), `cerebronexus_h5` | the same two, and `cerebronexus_h5_start` (the same artifact started with `start.R`) |
| Other tools | pinned in round 2 | the same pins; versions recorded again |
| Tiers | 10,000, 100,000, 500,000 | the same, and all 1,306,127 cells |
| `t_ready` | `requests.get` every 0.1 s | TCP probe every 5 ms with a 20 ms timeout, then one GET (section 7.2) |
| Frames | element screenshot every 0.25 s | Chrome's screencast, kept going by a 2 px marker that changes every 0.1 s, cropped to where the plot element is (7.3) |
| First plot | 1 % ink in the tool's plot element | 1 % ink, spread over the region, in the plot element or the element that stands in for it: `t_first_pixels` (7.4) |
| Usable plot | not measured | `t_interactive`: the plot answers a scripted gesture (7.5) |
| Route to the plot | CerebroNexus: click "Projection" | CerebroNexus: the page link `/?page=projection`; no click |
| Cache | not controlled | one cache directory per configuration and tier; three start classes (7.6) |
| Starts per build | 3 | 4 |
| Host | idle sample stored | a start waits for an idle host; CPU canary per round (section 4) |
| After the first plot | nothing | Task 5: three actions (section 8) |
| Client | GPU, local network | also without GPU and on a throttled connection: Task 6 (section 9) |
| Gene access | one gene in Task 2 and 3 only | twenty genes in turn, at the large tiers: Task 7 (section 13) |
| Results shown | what is recognised on import (Task 1) | which analysis results each viewer can show: Task 8 (section 14) |
| Fairness | stated in the limits | rules, predictions written down before the run: section 15 |

Round-2 and round-3 numbers are not paired: the clock for `t_ready`, the frames and the route differ.

## 3. Tools and pins

As round 2, section 3, apart from CerebroNexus. The Python environment `env/py` and the R library `env/rlib`
are the ones of round 2; CerebroNexus is replaced in `env/rlib` by the pinned commit and the isolation check is
run again. `results/round3/environment.json` records every version, the Chrome version, the WebGL renderer
string and the host.

## 4. Host and environment

As round 2, section 4, with these additions.

- **Idle gate.** A build or a start begins only when the CPU has been below 15 % for 3 s. The harness waits up
  to 10 minutes; a run that cannot begin is `host_busy` and is run again at the end of its tier. The idle value
  is stored with every run.
- **CPU canary.** A fixed computation (the one of `topics/viewer_performance`) is timed before and after every
  round of a tier. A round whose two values differ by more than a factor 1.2 is kept and marked; its tier is
  measured once more at the end and both are shown.
- **WSL.** The WSL virtual machine is stopped for the whole of the measured runs (round-2 D4).
- **Cache directory.** `R_USER_CACHE_DIR` is set for every R process to
  `data/cache/<config>/<tier>/`, never the user's own. Whether the Python tools keep anything between runs, and
  where on Windows, is found in the pilot; if they do, that place is handled the same way. What each tool
  leaves behind is listed after the pilot.

## 5. Data

The three tier files of round 2, unchanged, checked against `results/inputs.csv`.

**Full tier.** `data/inputs/e18_1306127.h5ad`: all cells of E18 with the recipe of the tiers (log-normalised,
2,000 HVGs, 50 PCs, UMAP, `MiniBatchKMeans(20)` as `cluster`, `nUMI`, `nGene`; no filtering), made by a copy of
`scripts/setup/prep_task3.py` with `N` set to all cells. Its embedding is computed on all cells: it is not the
embedding of the 500,000-cell object with more cells added, and the figure says so. Size and SHA-256 go into
`results/round3/inputs.csv`. Not timed.

## 6. Configurations

As round 2, section 8.2, and:

| Config | Build | Serve |
|---|---|---|
| `cerebronexus_h5_start` | none of its own: the artifact of `cerebronexus_h5` of the same round | `Rscript <CerebroNexus>/start.R --port=<p> <crb>` |

The H5 configuration is the one CerebroNexus documents for large data. The embedded one is measured on the
three round-2 tiers like every other configuration and is in every table; on the full tier the stop rule of
8.6 of round 2 applies to it as to any other.

The CerebroNexus build is the one of round 2 (`convertH5adToCerebro()`), run with the pinned commit, so the
artifact has the current CRB layout and a Viewer Pack where the build makes one by default.

## 7. Task 3: start

### 7.1 Per start

`t_ready`, `t_first_pixels`, `t_interactive`, the two sums with `t_ready`, the bytes and the number of requests
the browser received up to each of the two events, peak RSS of the server's process tree and of Chrome's up to
`t_interactive`, the start class (7.6), the idle value, the status.

### 7.2 `t_ready`

Spawn of the server process to the first HTTP 200 on `/`. The port is probed with a TCP connect every 5 ms
(20 ms timeout); once it connects, one GET is sent and awaited. Chrome is started after that, as in round 2.

`t_ready` is the first answer of the server, not a usable Viewer: a static server (Vitessce) answers as soon
as it listens, and CerebroNexus now answers with a kept page before it has read the data. It is reported
because round 2 reported it; the sums with the two events below are what a visitor waits for.

### 7.3 Frames

Chrome's screencast of the page (`Page.startScreencast`, JPEG quality 70, every frame), with the time Chrome
gives each frame, and a marker that keeps the frames coming: a 2 x 2 px element in the bottom right corner of
the page, added by the harness, that changes colour every 0.1 s. It lies outside every tool's plot region.

The marker is needed because Chrome sends a frame only when it thinks the page changed. In the pilot it sent
none when Vitessce drew its cells on a WebGL canvas, so the run ended on a picture of the loading state while
the page showed the plot. The alternative, captures asked for by the harness (`Page.captureScreenshot`
clipped to the region), changed the measurement: each clipped capture resets the page's metrics, the Shiny
tools became seconds slower (iSEE 9 to 12 s to its first plot instead of 7 to 8), and the screencast filled
with frames of the captures themselves. With the marker, CerebroNexus reached the same events at the same
times as under a tracer without marker, captures or gestures (real plot after 2.50 to 2.56 s and 2.49 to
2.68 s). The time resolution is the marker's 0.1 s (95 % of the gaps between frames were 0.125 s or less).

The **plot region** is the bounding box of the tool's plot element (the selectors of round 2, section 8.5),
followed through the run: the harness reads where the element is about every 0.1 s, and each frame is cropped
to where the element was when the frame was taken. A region fixed at the end of the run is wrong: it also
sees whatever passes through that place while the page is laid out, and in the pilot Vitessce's collapsed
panels were taken for a plot 1 s before its cells were drawn.

A tool may have an element that shows the same cells in the same place before its plot element exists. For
CerebroNexus that is the canvas of the first view (`.cerebro-first-view-canvas`); no other tool has one. It
stands in for the plot element until that exists, every result says which of the two the first pixels were in,
and the first ink in the plot element itself is recorded too (`t_plot_element`, the event of round 2).

### 7.4 `t_first_pixels`

Navigation start to the first of two consecutive frames that show the plot. A frame shows the plot when the
region is at least 200 x 200 px, at least 1 % of its pixels are ink (the ink rule of round 2, section 8.5),
and the ink is spread: of the 8 x 8 blocks the region is cut into, at least 16 hold ink (0.2 % of the block's
pixels). The last condition is new. A plot is spread over its region; a toolbar, a spinner or a message is
not, and the 1 % rule alone accepted Vitessce's toolbar strip (7 % ink in 8 blocks) for its plot (2.5 % ink in
41 blocks). The accepted frame is saved for every run and looked at before a tier is accepted.

For CerebroNexus this can be a picture of the cells that does not answer the pointer yet. That is why it is
never reported without `t_interactive`.

### 7.5 `t_interactive`

Navigation start to the first moment the plot answers a pointer gesture.

- Once a frame shows the plot, the harness makes the tool's gesture, at most every 0.25 s and only when the
  region has not changed for 0.3 s, so that a plot still drawing itself is not taken for an answer.
- A gesture is **answered** when the region changes (more than 0.5 % of its pixels differ by more than 24 of
  255 in one channel) after the gesture began and before the next one begins.
- `t_interactive` is the time the first of two consecutive answered gestures began, at or after
  `t_first_pixels`. One answered gesture is not enough: the first gesture often falls on a picture that is
  still being completed. Its resolution is the gap between gestures.
- The run ends 1 s after three gestures in a row were answered, or when 16 gestures after the first plot frame
  gave no two answered in a row (`no gesture answered`).

| Tool | Gesture | In the pilot |
|---|---|---|
| CerebroNexus | the toolbar's "Zoom in" and "Zoom out" buttons in turn (`[data-act="zin"]`, `[data-act="zout"]`) | answered; the buttons exist only with the plot itself, not with the first view |
| cellxgene | started as in round 2, it opens a dialog ("User Generated Data Directory") over its plot that "Cancel" does not close, and it opens in lasso mode, where the wheel does nothing. The harness names the directory and chooses "pan and zoom" (`[data-testid='mode-pan-zoom']`), once, then turns the wheel in and out over the centre | answered; without the two steps, 16 gestures changed nothing |
| Vitessce | the wheel in and out over the centre of the plot | answered |
| iSEE | a rectangle dragged in the plot (the brush) | answered |
| ShinyCell | the embedding is an image; 19 drags changed nothing | `n/a`; the sum uses `t_first_pixels` |

The gesture is the simplest one each tool offers for its embedding. A tool for which no gesture changes the
picture is `n/a`; this is a property of the tool and is shown as such.

### 7.6 Start classes

A build is served in four new processes. The cache directory of a configuration and tier (section 4) is
emptied before its first build and not afterwards.

| Class | Which starts | Meaning |
|---|---|---|
| `first_start` | start 1 of build 1 | nothing kept: a new installation |
| `new_dataset` | start 1 of builds 2 and 3 | the tool has run before; this artifact is new to it |
| `later_start` | starts 2 to 4 of every build | the same artifact has been opened before |

Every tool gets the same four starts and the same three classes, whether or not it keeps anything. Results
are given per class; a figure that shows one class names it, and `later_start` is never shown without
`first_start` beside it or in the same table.

### 7.7 Replication, schedule, timeouts

As round 2, sections 8.3 and 8.6, with four starts per build and a new seed. The tiers run in the order
10,000, 100,000, 500,000, full.

## 8. Task 5: three actions on the open plot

Per tool and tier, in one session per build: the plot is opened as in Task 3 and the session waits until the
server's process tree and Chrome have been quiet for 3 s. Then each action runs five times, with the same
wait before each.

| Action | What |
|---|---|
| colour by a column | switch the colouring from `cluster` to `nUMI` |
| colour by a gene | colour by the first gene of `data/inputs/default_genes.txt` |
| select a region | a lasso (or the tool's region tool) around the central 40 % of the plot region, until the tool shows what was selected |

Metric: the gesture that starts the action to the last frame of the page that differs from the final one
(more than 0.05 % of the pixels; the session is watched for 2 s after the last change). Median and range of
the five. A tool without the action is `absent`; one that does not finish in 60 s is `timeout`.

The control path of every action in every tool is found in the pilot and written into this section before
freezing. An action for which no stable path is found in a tool is dropped for all tools, and that is
recorded.

## 9. Task 6: a client with less

Tiers 100,000 and 500,000 only, the configurations of Task 3, three `later_start` starts and the Task 5
actions.

- **No GPU:** Chrome with `--disable-gpu` (software rendering; the renderer string is recorded).
- **Slow connection:** `Network.emulateNetworkConditions` with 20 Mbit/s down, 5 Mbit/s up and 40 ms latency.

Run only if the pilot shows that every tool starts under both conditions; a tool that does not is
`platform_limit` with its log.

## 10. Outputs and figures

`results/round3/task3/`, `task5/`, `task6/`, `task7/`, `task8/` (one row per run, including failed, `host_busy` and not-run),
`summary_*.csv|md`, `environment.json`, `inputs.csv`, the frame series and the accepted frames in
`results/round3/evidence/`. Figures as round 2, section 10, in `figures/round3/`. Candidates: first pixels and
interactive time against the cell number, one panel per start class; the decomposition of the total; server
and browser memory; bytes to the first plot; the three actions; the two constrained clients. The owner
chooses after the results exist.

## 11. Known limits, stated in advance

- One machine, one operating system, one GPU.
- `t_first_pixels` counts a preview. It is shown with `t_interactive` for that reason; neither alone
  describes a start.
- The plot region, the ink rule and the gestures are choices of this protocol, applied to all tools.
- What a tool keeps between runs is part of the tool. The start classes show the effect; they do not remove it.
- `t_ready` compares a static file server with application servers.
- Task 5 times three actions on one data set; it says nothing about the analyses each tool offers.
- The full tier has its own embedding.
- Not measured, and not in our favour: many visitors at once. A static server (Vitessce) serves any number of
  visitors from files; CerebroNexus runs one R process per application and keeps the data in it. Hosting a
  static page costs less than hosting a Shiny application, and this study does not measure it.
- CerebroNexus is developed by the authors of this comparison and was changed with these measurements in
  view. The other tools run as released.

## 12. Pilot (not measured, nothing from it enters a table)

On the 10,000-cell tier and, for items 5 and 7, on 500,000 cells. Each item has to hold before the text is
frozen; what fails changes the text above, not the result.

1. The socket probe gives the same `t_ready` as a log line of each server within 20 ms.
2. The screencast delivers frames at least every 50 ms for every tool while its page loads, and the cropped
   region is the plot (frames looked at by eye).
3. `t_first_pixels` of round 2's selector and of the region agree within one frame for the four tools that
   draw only in their plot element.
4. The gesture of 7.5 changes the picture in every tool that has one, three times out of three, and does
   nothing visible before the plot can answer.
5. The three start classes differ for CerebroNexus and do not differ beyond run-to-run spread for a tool
   that keeps nothing; what each tool writes to the cache directory is listed.
6. A control path for each Task 5 action in each tool, three runs each, the same every time.
7. The full tier: every tool is built once and started once, with the timeouts of round 2. A tool that does
   not build or start is recorded as it will be in the measured runs.
8. Both conditions of Task 6 start every tool once.
9. The idle gate and the canary: one tier is run with and without a background load to see that the gate
   holds runs back and the canary marks the round.
10. Task 7: a control path for "colour by this gene" in each tool, the twenty genes colour in turn without the
    page failing in any tool, and the quiet wait between genes is reached (three runs each on 10,000 cells).
11. Task 8: the inputs are made and hashed, and for every tool and result the documented route is tried and the
    evidence stored. A result for which two people cannot agree on the grade is described in the text first.
12. The pin: the pilot of findings 1 and 2 (the H5 hash before the first plot; the H5 written by the pinned
    commit) is repeated on the pinned commit, with the numbers next to the old ones.

## 13. Task 7: many genes, one after another

A viewer is used to look at gene after gene. Task 5 colours by one gene; this task colours by twenty, in turn,
on the open plot, and asks what the twentieth costs as well as the first.

- **Genes.** `data/inputs/sweep_genes.txt`: 20 genes drawn once, with seed 20261113, from the genes detected in
  at least 1 % and at most 50 % of the cells of the 10,000-cell tier, and written down **before** the first
  measured run (its SHA-256 goes into `results/round3/inputs.csv`). All 20 are in every tier. Nobody chooses a
  gene after seeing a result.
- **Run.** One session per build, as in Task 5: open the plot, wait until the server and Chrome have been quiet
  for 3 s, then colour by gene 1, wait for the same quiet, gene 2, and so on to gene 20. The order is the file's.
- **Metric.** For each gene, as in Task 5: the gesture that starts the colouring to the last frame that differs
  from the final one. Per session: the first gene alone (nothing of the expression matrix is warm yet), and the
  median, 90th percentile and maximum of genes 2 to 20. Over builds and starts: median and range.
- **Tiers.** 100,000, 500,000 and the full tier. The expression layer is the one the tool documents for large
  data (section 15, rule 2).
- **Failures.** A gene that does not finish in 60 s is `timeout`; a session with three timeouts is stopped and
  recorded as it is. Memory (server and Chrome) at gene 1 and at gene 20 is recorded, so growth is visible.

What this tests is what each design pays for random access into a matrix with a million columns: the page a
gene is read from, whether the browser or the server holds it, and whether the cost of gene 20 differs from
that of gene 1. It says nothing about the analysis that follows the colouring.

## 14. Task 8: which results a viewer can show

Task 1 asks what a viewer recognises in an input. This task asks what it can **show** of the results that an
analysis leaves behind, with the documented route and without writing a viewer.

Inputs are produced once, by a fixed script, from the pbmc3k input (I1), the scRepertoire example with TCR (I2)
and the Visium H&E input (I3) of round 2, and are hashed: marker genes per cluster, enriched pathways per
cluster, a pseudotime along the embedding, clonotype size and clonotype sharing between groups, and a numeric
result column on the tissue image. Each result is stored in the place the target tool documents for it (for
the AnnData tools `uns` and `obs`; for the R tools the object's metadata, or `misc`, as the build route reads
it); where a tool documents no place, the result is stored in the most conventional one and that is recorded.

| Result | Shown when |
|---|---|
| marker genes per cluster | a table of the genes of the chosen cluster, with their statistics, is on the screen |
| enriched pathways per cluster | a table or chart of the terms of the chosen cluster is on the screen |
| trajectory | the pseudotime is drawn on the embedding as a colour scale |
| clonotype size | the cells are coloured or sized by the size of their clonotype |
| clonotype sharing | a view shows which clonotypes occur in more than one group, and from it the cells of one clonotype can be selected |
| result on a tissue | the result column is drawn over the tissue image, aligned |

Grade per tool and result, as in Task 1: `auto` (the documented build route, with no argument that the other
tools are not also given, shows it), `manual` (it needs code or a configuration the user writes beyond the
build route), `absent` (no way found in the documentation, searched with the same words for every tool; the
search terms are stored), `rejected`. The evidence is a screenshot and the commands. Two people grade; a
disagreement is shown, not settled in our favour.

A grade is a statement about the documented routes on the day of the pin; it is not a statement about what a
skilled user could build. `manual` is as much a result as `auto` and is reported as such.

## 15. Rules that keep Tasks 3, 5, 6, 7 and 8 fair

1. **Frozen first.** The tasks, the genes, the gestures, the grades and the predictions below are hashed before
   the first measured run (`results/round3/PROTOCOL.sha256`). Changes after that are Deviations, with the date
   and the reason, and are shown in the same table as the results.
2. **Each tool gets its best documented route for the size.** Vitessce: `optimize_adata()` with the layout its
   documentation recommends for gene access, chunked Zarr, served by a static server; cellxgene as released;
   ShinyCell with its H5 option; iSEE as the Bioconductor release builds it; CerebroNexus with the H5 backend.
   The build script of every tool is stored with the results and named in the text. A developer of any of the
   tools is invited to read their tool's script before the measured run; a change they show to be better
   documented practice is made for the whole run, not for one task.
3. **Same input, same gestures, same clock.** One input file per tier, one gene list, one set of regions, and the
   clock of section 7. No tool is started, warmed or timed in a way another is not, except where a start class
   (7.6) says so for everyone.
4. **Predictions are written down.** Before the first measured run, the authors write what they expect, and it
   is kept in `results/round3/PREDICTIONS.md`:
   - CerebroNexus with the H5 backend has the lowest server memory among the tools that need an application
     server, and the lowest browser memory of all tools at the full tier;
   - at 10,000 cells Vitessce has the shortest `t_first_pixels`;
   - at the full tier the time per gene of Task 7 grows with the cell number for the tools that read the
     expression into the browser or into the server, and stays flat for the H5 backend;
   - Vitessce builds fastest and needs the fewest build steps;
   - only CerebroNexus shows the clonotype results of Task 8 with `auto`.
   A prediction that fails is reported with the others; none is removed.
5. **Everything is reported.** The summary tables list every task, tool, tier and class that was run, in the
   same order, whoever is fastest. Figures may select a panel for space; the table with all of them is in the
   same supplementary file. Tasks where CerebroNexus is expected to lose are kept (Task 3 at 10,000 cells,
   section 11).

## Pilot record (2026-11-12)

Not measured runs. 10,000-cell tier, CerebroNexus `perf/viewer-startup` at `29a6df077` installed from
`git archive` into a library of its own in front of `env/rlib`, built with `cerebronexus_build.R`; the other
tools from their round-2 pilot artifacts. Scripts: `scripts/run/harness3.py`, `scripts/run/pilot3.py`,
`scripts/run/tools/cerebronexus3_serve.R`. Everything else is in
`C:\Users\wangx\Projects\catch\tool_comparison\20261112_round3-pilot\`.

**What the pilot changed in this text** (sections 7.3 to 7.5): the region follows the plot element; ink has to
be spread; frames come from the screencast with a marker; gestures begin after the first plot frame and two in
a row have to be answered; the gestures of cellxgene and ShinyCell.

**Found, and to be settled before a pin**

1. *CerebroNexus hashes the whole H5 file in the first session of every process.* A CRB built by the current
   code records the MD5 of its H5 sidecar, and the Viewer checks it when the data set is loaded: 0.93 s for the
   234 MB file of this tier, in proportion to the file (about 30 s for the 7.6 GB of the 500,000-cell tier).
   The same data built by the round-2 pin, which records no checksum, drew its plot 1.04 s after the
   navigation; built by the current code, 2.62 s. The large demo data sets were built before the check
   existed, which is why earlier measurements did not show it.

   *Later the same day:* the file was hashed twice in every process, by `launchCerebro()` for the gene count
   of the overview as well. A change in the working tree of `perf/viewer-startup` (on `369915bd3`, not
   committed) has a background process hash the file, asks for the answer before expression is read, and
   keeps a verified file in the cache directory for later processes. `cerebronexus_h5`, five rounds of four
   starts, before and after: later starts, first ink in the plot element 2.35 to 2.60 s and 1.30 to 1.58 s,
   `t_interactive` 2.88 to 3.15 s and 1.84 to 2.11 s; first starts, `t_ready` 2.61 to 2.83 s and 1.82 to
   1.86 s, `t_interactive` 2.72 to 3.08 s and 1.99 to 2.43 s. The table below is from before the change.
2. *The branch does not have the H5 write optimisations of the round-2 pin* (`tmp/应急`, Deviation D7 of round
   2): the 10,000-cell H5 is 245 MB again (164 MB there) and the build took 39 s (8.8 s there; the host was
   busy during this build, so only the file size is certain).
3. *cellxgene's plot of round 2 was behind a dialog.* Its first plot is drawn under the dialog named above and
   cannot be used until a name is given. `t_first_pixels` counts it as round 2 did; `t_interactive` includes
   the two steps. Starting it with `--disable-annotations` would avoid the dialog and is the owner's choice.

**Results on a quiet host** (idle CPU 4 to 10 % before every start; the two later starts, the first start in
brackets; seconds; two or three starts per cell, so these show that the instrument works, not what the tools
do):

| Config | `t_ready` | `t_first_pixels` | first ink in the plot element | `t_interactive` |
|---|---|---|---|---|
| `cerebronexus_h5` | 0.64, 0.69 (2.73) | 0.37, 0.56, first view (2.20) | 2.50, 2.56 (2.20) | 3.08, 3.10 (2.60) |
| `cerebronexus_h5_start` | 0.53, 0.56 (2.87) | 0.51, 0.53, first view (2.11) | 2.85, 2.85 (2.11) | 3.35, 3.38 (2.53) |
| `cerebronexus_default` | 0.64, 0.69 (3.20) | 0.57, 0.57, first view (1.29) | 2.17, 2.23 (1.29) | 2.68, 2.75 (1.75) |
| `vitessce` | 0.31, 0.33 (0.37) | 1.59, 1.61 (1.46) | as first pixels | 1.91, 1.93 (1.78) |
| `cellxgene` | 8.01, 8.14 | 0.83, 0.88 | as first pixels | 1.32, 1.35 |
| `shinycell` | 1.58, 1.60 (1.58) | 3.11, 3.16 (3.11) | as first pixels | n/a |
| `isee` | 6.81, 7.83 (6.74) | 8.18, 13.53 (8.27) | as first pixels | 8.62, 14.32 (8.79) |

The CerebroNexus rows include finding 1 (0.93 s of hashing before the plot). cellxgene's row is from a
separate pair of starts after its gesture was found; both are starts of the same class.

**Items of section 12**

| Item | State |
|---|---|
| 1 socket probe against a server log | not done |
| 2 frames | changed: the screencast alone and forced captures both failed; marker adopted, resolution 0.1 s, not 0.05 s |
| 3 region against round 2's selector | agrees for the four tools without a stand-in; a fixed region and the 1 % rule alone did not (Vitessce) |
| 4 gestures | answered three times in a row by CerebroNexus, Vitessce, iSEE and cellxgene in every start; ShinyCell has none |
| 5 start classes | differ for CerebroNexus (five cache files after its first start); the other tools left the cache directory empty |
| 6 Task 5 control paths | not done |
| 7 full tier | not done; findings 1 and 2 would decide its CerebroNexus numbers |
| 8 Task 6 conditions | not done |
| 9 idle gate | held a start back for its 10 minutes while another job used 65 to 75 % of the CPU, and waited up to 63 s on the otherwise quiet host; the canary was not tried |

## Open decisions (owner)

1. **Pin.** Decided 2026-11-13: the commit of `../cerebronexus.pin` (`integration/8.3.0`), for every topic.
   Whether `start.R` is one of the measured routes is decision 2. The commit is on this machine only: it has
   to be pushed before the topics that fetch it from GitHub can run, and before a reader can reproduce it.
2. **`start.R` as a configuration.** It is a second way to start the same Viewer. Measured as its own
   configuration here; the alternative is to measure only the route the paper recommends.
3. **Embedded configuration on the full tier.** Kept under the stop rule here. Dropping it would hide the
   slowest CerebroNexus numbers.
4. **Starts per build.** Four here (one first, three later). Three would keep the cost of round 2 with only
   two later starts.
5. **Task 6.** Optional; it doubles the starts of two tiers.
6. **Round-2 results.** Kept in `results/` as measured, or moved to `results/round2/` when round 3 is done.
7. **cellxgene's dialog.** Started as in round 2 (the dialog is part of what a visitor meets), or with
   `--disable-annotations`.

## Deviations

None: not frozen.

---

## Appendix: the Viewer standard (`topics/viewer_performance`)

Not part of this protocol. The Viewer standard measures one CerebroNexus revision against another and has
the same blind spots.

Done in contract `blackbox-v7` (2026-11-13; `topics/viewer_performance/STANDARD.md`):

- `R_USER_CACHE_DIR` per run and revision, and the first plot once with an emptied cache (`first_start`) and
  once as a later start (`first_plot`), as two visits.
- Candidate and baseline run alternately in one run (`run.R --baseline`). `compare.R` decides with an exact
  rank-sum test over the rounds and a floor of one frame instead of the threshold of 20 % + 300 ms, which was
  wider than the changes now being made, and reports the differences within each round.
- An idle machine before every session and a CPU canary per round, as in section 4.

Still open:

- First-plot visits: open `/?page=projection` instead of clicking; report first pixels in the plot region and
  the interactive time of 7.5 as two metrics.
- A `ready_ms` metric: spawn to the first HTTP 200, with the socket probe.
- A launch-route option (`launchCerebro()` or `start.R`), recorded in the manifest.
- Fixtures in both CRB layouts. Revisions before the cell-index layout cannot read the new files, so a
  comparison across that change measures the layout and the code together; `compare.R` already reports
  differing CRB checksums and should name this case.
