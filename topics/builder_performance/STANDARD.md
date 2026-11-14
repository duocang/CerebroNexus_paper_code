# How Builder performance is measured

The rules that `standard/` implements, so that two runs in `runs/` can be compared and a Builder optimisation can
be claimed, or refused. How to run it is in [README.md](README.md). It follows
[`../viewer_performance/STANDARD.md`](../viewer_performance/STANDARD.md) (contract `blackbox-v7`) where the two
measure the same kind of thing: a revision installed from `git archive`, rounds, a candidate and a baseline that
take turns in one run, an exact rank-sum test over the rounds, a machine that must be idle. It differs where the
object differs: this topic times the Builder's own functions in an R process, not a page in a browser.

## 1. What is measured, and what is not

The Builder is a Shiny app with a worker process behind it. What a user waits for is one of five things; each is
a **scenario** (`standard/scenarios.tsv`) that calls, in a fresh R process, the functions the Builder calls for it:

| Scenario | The Builder does | Calls | Fixture | KPI |
|---|---|---|---|---|
| `edit` | the user changes something in the Configure page (a group ticked, a default chosen) | the reducer's `replace` and the state the rail derives from it (`builder_reduce_state`, `builder_cached_dataset_state`) | `meta60`: 63 metadata columns, 20 k cells | `edit_ms` (one edit, median of 15 after 3 warm-up edits); `reduce_ms` (the reducer alone) |
| `import` | a source file is imported and inspected | `.builder_register_adapter` | `meta_import`: 200 k cells, 63 columns, one with 80 000 distinct values | `import_s` |
| `build_embedded` | Build, with the expression matrix inside the CRB | `builder_freeze_plan`, `builder_execute_plan` (export, verification, Viewer Pack) | `cells100k`: 100 k cells, 198 M non-zero values | `build_s` (and `import_s`, `freeze_s`) |
| `build_h5` | Build, with an H5 sidecar; then a second Build after a change of the configuration only, offered the first one's sidecar | the same, twice | `cells100k` | `build_s`; `rebuild_s` |
| `export_h5` | the scripted export (`exportFromSeurat`, H5) that Build shares its writer with | `exportFromSeurat` | `cells100k` | `export_s` |

Every session also reports `cpu_s`, `peak_mib` (peak memory of the worker process) and `out_mib` (what it wrote).

**Clock and compiling (contract `builder-perf-v2`).** Times are wall time read with `Sys.time()`, which on
Windows is precise to below a millisecond. The Builder runtime is sourced from the revision (as its own end-to-end
tests do) and byte-compiled before anything is timed, as the installed package is. Under `builder-perf-v1` the JIT
compiled each sourced function the first time it ran, inside the first edit and the first Build (`freeze_s` was
mostly that), and `proc.time()` moved in steps of 10 to 16 ms on Windows, coarse for an edit of 50 ms. Runs of the
two contracts are not comparable.

**Why not a browser.** The slow steps of these five are in R: the Shiny process validating an entry, the worker
decoding a file. A browser adds a second clock (the time Chrome needs to draw) that none of the optimisations
touches, and a user-interface session is much noisier than a function call. The browser timing of an edit
(0.27 to 0.43 s in `perf/builder-edit-latency`) is a check of this standard's `edit_ms`, not its replacement;
it is not part of the run record (section 8).

**Fixtures.** Synthetic Seurat objects (`standard/fixtures.R`), seeded, so that anyone gets the same bytes; a
fixture is a count of cells, columns and non-zero values, not a biology. The MD5 of every fixture is in the
manifest, and `compare.R` says when two runs read different files. A fixture made with `--scale` is a smoke
test: the run says so in its problems and in its manifest (`fixtures_scale`).

## 2. A session, a round, a run

One **session** is one fresh `Rscript --vanilla` process, one scenario, one revision (`standard/worker.R`):
nothing is cached in the process, and the process is gone before the next session starts. One **round** measures
every scenario once per revision. A **run** is `--rounds` rounds (default 5; with fewer than 4, `compare.R`
cannot call anything slower or faster) of one revision, or of a candidate and a baseline in turns.

A fresh process per session is what a user gets: the Builder's worker starts, imports and builds. It also
means a number never depends on which scenario ran before it.

**Caches.** The Builder keeps nothing between processes except files: the snapshots of an import and the
sidecars of a Build. A session builds its own snapshot folder and its own stage folders below the run's `work/`
and deletes them when it ends, so a session never finds what another left. The one cache that is meant to be
found is the one under test: in `build_h5` the second Build is **offered** the first Build's sidecar through the
option `cerebro.expression_sidecars`, as the Builder offers the sidecar of a dataset's earlier cache. A revision
that does not know the option ignores it and writes the matrix again, which is exactly what its `rebuild_s`
must show.

## 3. Candidate against baseline

`run.R --candidate B --baseline A` measures both in one run. For every scenario and round, the two sessions run
one after the other, and which goes first alternates with the round and the scenario (`build_schedule`), so
that neither always meets the machine first, or the other's disk traffic. Each revision gets its own run folder;
both manifests carry the same `pair_id`, and `compare.R` then also prints the range of B − A within each round.
Runs made on different days can be compared too, but a busier machine on one of the days then looks like a
change in the code.

## 4. The machine

Windows or Linux (WSL included), the machine facts are in the manifest; numbers from different machines are not
comparable. Before every session the harness waits until the whole machine has been below 15 % CPU for three
seconds in a row (up to 10 minutes, then it starts anyway and counts the session as started on a busy machine).
A CPU canary (a fixed single-threaded computation of about 0.4 s) is read before the run and after every round;
if its readings move by more than a factor of 1.2 the run says so. Both are the same functions as in
`viewer_performance` (`standard/proc.R`). Disk matters for the build scenarios: run with the run folder and the
fixtures on the same drive every time, and nothing else heavy running.

## 5. The run record

```
runs/cerebronexus-<version>_<YYYYMMDD-HHMMSS>_<sha7>[_base][_partial]/
  manifest.tsv   contract (builder-perf-v2), revision, machine, fixtures (MD5), scale, canary, host load, harness commit
  raw.tsv        one row per session: every metric, status, wall time, the host's CPU before the session
  scenarios.tsv  one row per scenario: medians over the rounds that finished
  checks.tsv     the equivalence checks (section 7)
  schedule.tsv   the order of the sessions and what the machine was doing before each
  summary.md     the table to read first, the checks, and the problems
```

A session that fails is `error` in `raw.tsv`; medians are taken over the `ok` rounds, and the failure is a
problem in the summary.

## 6. Comparing, and the noise

`compare.R A B` joins `raw.tsv` of the two runs and, per scenario and metric, calls the difference
`slower` or `faster` only when **both** hold:

1. the exact two-sided rank-sum test over the rounds gives p ≤ 0.05 (equal values share their rank, so ties are
   exact; the same function as `viewer_performance`), and
2. the medians differ by more than **3 % of A's median**, and by more than the timer's resolution (15 ms).

`not resolved` is neither: the rounds overlap, or the difference is below the floor. `too few rounds` means that
with these numbers of rounds no outcome could give p ≤ 0.05 (3 against 3 cannot; 5 against 5 can, at p ≥ 0.008).
Memory, CPU and output size are reported and not judged.

The floor is a convention, not a measurement of the noise. **The noise is measured once per machine** by
measuring a revision against itself (`--candidate A --baseline A`; the second folder ends in `_base`):
`compare.R` then states how far the medians of the same code differ, and how many rows it would call a change
by accident. A difference that the self-comparison could produce is not a result. Until that has been done on a
machine, a "faster" from it is indicative.

## 7. Equivalence checks

An optimisation here is a fast path that reuses something (a sidecar, a CRB of an earlier Build) or writes it a
faster way. A faster number is worth nothing if the path reuses what no longer fits or writes other data.
`standard/checks.R` runs once per revision on a tiny synthetic object and writes `checks.tsv`:

| Check | Passes when |
|---|---|
| `sidecar_config_change_same_matrix` | after a change of groups only, the export offered the earlier sidecar holds the same matrix as one offered nothing |
| `sidecar_changed_matrix_rewritten` | a changed matrix offered the old sidecar holds the new matrix, not the old |
| `sidecar_wrong_md5_rewritten` | an offered sidecar whose recorded MD5 does not match is not copied |
| `sidecar_missing_rewritten` | an offered sidecar that does not exist is not an error: the matrix is written again |
| `h5_content_digest` | always, and records a digest of every dataset's path, dimensions, type and values; `compare.R` flags a digest that differs between the runs of a pair, which is how the faster H5 writer is held to "same data" |

"Same" means the same data: the check compares what every dataset of the H5 holds, so a digest attribute or a
timestamp that differs does not fail it. A failed check is a problem in the summary and makes `run.R` exit
with status 2. The baseline passes the first four by writing the matrix every time; the checks hold a candidate
to what the baseline does.

The same experiments for a full Builder Build and Save, including the CRB that a Save adopts from an earlier
Build, belong with the validation of `topics/builder_validation` (the end-to-end and publish-fault experiments);
see section 8.

## 8. Not measured yet

- **Save that creates the Project.** `perf/builder-load-export` adopts the CRBs of an earlier Build instead of
  building the caches again (55 s for 100 000 cells). It happens in the Shiny process through the Project
  queue, not in a function this harness can call; its correctness is covered by
  `tests/testthat/test-builder-project-deferred-build.R`. Measuring it needs the browser session of
  `catch/builder-perf/ui`, which has no protocol yet.
- **The browser.** The time from the click to the repainted Configure page; the time a file picker takes.
- **Datasets.** The `cells100k` fixture is synthetic and has no spatial images, immune repertoire or trajectory.
- **1 M cells.** The import fix is quoted at 1 M cells (324 s to 23 s); the fixture has 200 k so that a
  baseline round takes minutes, not an hour. The effect should only be larger at 1 M.
- **Chunks and filters** of the H5 are not in the content digest, only its data, dimensions and type.
- **Linux with a cold disk cache.**
