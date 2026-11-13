# How App export is measured

The rules that `standard/` implements, so that two runs in `runs/` can be compared. How to run it is in
[README.md](README.md). It follows [`../viewer_performance/STANDARD.md`](../viewer_performance/STANDARD.md) where the
two measure the same kind of thing (a run is one CerebroNexus revision, installed from `git archive`, rounds,
medians over the rounds that finished) and differs where the object differs: this topic times a function call
that writes a folder, not a page in a browser.

## 1. What a measurement is

One **session** is one fresh `Rscript --vanilla` process that calls `createShinyApp()` twice on one CRB into the
same result folder (`standard/worker.R`), with `launch_browser = FALSE`. A **run** measures one revision: every
scenario (`standard/scenarios.tsv`), `--rounds` times (default 3), each time in its own session.

| Metric | Meaning |
|---|---|
| `first_s` | wall-clock seconds of the first `createShinyApp()` in the session: nothing is cached in the process, and the result folder is empty. **The KPI.** |
| `repeat_s` | the second call, same process, same folder, `overwrite = TRUE`: what the preflight cache and the copy of unchanged files save. |
| `cpu_s` | user + system CPU seconds of the whole session (both calls). Separates work from waiting. |
| `peak_mib` | peak resident memory of the worker process itself (Windows: peak working set; Linux: VmHWM), read by the worker at the end; child processes are not counted. |
| `out_files`, `out_mib` | files and size of the folder after the first call. |
| `status` | `ok`, or `error` with the message; a session that dies is `error` (`worker died`). Medians are taken over the `ok` rounds. |

## 2. Scenarios

| Scenario | CRB | Why |
|---|---|---|
| `example` | `inst/extdata/examples/example.crb` of the revision | the smallest App: the fixed cost of the template, the Viewer files and the launcher |
| `spatial_visium` | `demo_spatial_visium.crb` of the revision | a spatial CRB: spatial-image handling and the spatial contracts |
| `1m` | 10x mouse brain, 1.3 M cells (`--large-examples`) | a thin CRB with an H5 sidecar: preflight and the copy of a large file |
| `cosmx` | CosMx NSCLC, 800 k cells (`--large-examples`) | the largest spatial data set |
| `embedded_100k` | 100 k cells with the matrix **inside** the CRB and a Viewer Pack beside it (`--fixtures`) | preflight checks the Viewer Pack; for an embedded CRB it used to read the CRB a second time, which `perf/builder-load-export` removed. `example` is too small and `1m` is thin, so neither shows it |
| `h5_100k` | the same cells as a thin CRB with an H5 sidecar (`--fixtures`) | the copy of an H5 at a size between `example` and `1m` |

The two `fixture` CRBs are written by `standard/fixtures.R` from the `cells100k` fixture of
[`../builder_performance`](../builder_performance) and are the same files for every revision measured; their MD5
is in the manifest (`fixture_md5`). Without `--fixtures` they are left out of the run.

The demo CRBs belong to the measured revision and change between versions: those scenarios compare data as much
as code across distant revisions. The large ones are the same files as in `viewer_performance`.

## 3. Platform and noise

Windows, as in `viewer_performance`; the harness also runs on Linux. Numbers from different machines are not
comparable. Disk matters here more than for a page: run with the result folder on the same drive every time
(the harness writes below `runs/`, in `work/`, and deletes it). Nothing else heavy may run during a run
(CI, builds, another benchmark); a noisy run is kept, with that in its notes. There is no CPU canary yet.

## 4. The run record

```
runs/cerebronexus-<version>_<YYYYMMDD-HHMMSS>_<sha7>[_partial]/
  manifest.tsv   contract (app-export-v1), version, SHA, ref, platform, host, R, rounds, start
  raw.tsv        one row per session
  scenarios.tsv  one row per scenario: medians over the rounds that finished
  summary.md     the table to read first, and the problems
```

## 5. Comparing

`standard/compare.R A B` joins `scenarios.tsv` of two runs and prints `first_s`, `repeat_s`, `peak_mib`,
`out_mib` with `slower` / `faster` for a difference above 20 % (+ 0.3 s for the times). This is an indicative
line, not a calibrated threshold: until one revision has been measured repeatedly on one machine, the noise is
not known.

## 6. What this topic does not measure

Reusing an H5 sidecar when only the configuration of a dataset changed (`perf/builder-load-export`) is not here:
`createShinyApp()` takes a finished CRB and copies its sidecar, it never writes the matrix. The reuse is in the
Builder's export, and is measured, with the check that the reused file holds the right matrix, by
[`../builder_performance`](../builder_performance) (`build_h5`, `rebuild_s`; `standard/checks.R`).

## 7. Not measured yet

Starting the exported App and the time to its first page (the `viewer_performance` harness measures a running
Viewer and could be pointed at an exported App); exports with many spatial images; Linux with a cold disk cache.
