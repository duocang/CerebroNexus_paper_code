# Task 4: building, deployment and save/restore (protocol)

Written 2026-10-27, before the measured runs; its SHA-256 is recorded in `results/PROTOCOL.sha256` before the first run. This is a separate task on one Mac (macOS arm64), not part of Figure 9 (Tasks 1-3 ran on Windows).

## Tools

| Tool | Version | Source |
|---|---|---|
| CerebroNexus | `duocang/CerebroNexus` branch `builder/03_builder`, commit `001c4d4dd68a6fc5c2c958d7c0c2a49961671b95` (6.0.0, not a release), the library of `topics/builder_validation` | Builder, headless route of `topics/builder_validation/scripts/apps.R` |
| ShinyCell | `SGDDNB/ShinyCell` commit `5c61db78` (2.1.0) | `createConfig()` + `makeShinyApp()` |
| iSEE | Bioconductor release of the install day (version recorded) | `iSEE(sce)` in an `app.R` |
| cellxgene | 1.3.0 (PyPI) | `cellxgene launch` |
| Vitessce | Python 3.8.4 (PyPI), JavaScript `vitessce@3.9.9` | `optimize_adata()` + `write_zarr()` + `VitessceConfig`, page served from one origin |

Installed versions are recorded in `results/task4_environment.txt`. A tool that cannot be installed or run on this Mac is recorded as `not run` with its log.

## Input

`pbmc3k.h5ad` (cellxgene example dataset, SHA-256 `0db367b991dd95809732b218539ede489bea99113807f62ebd7ccc970025fe38`, the I1 input of Tasks 1-3). For the "changed input" of task 3, the same file with the first 100 cells removed (`pbmc3k_minus100.h5ad`, written by `scripts/make_inputs.py`, SHA-256 recorded). Temporary files, builds and deployments live on the external drive (`CerebroNexus_large_cache/builder_validation/bv_cache.sparsebundle`).

## Measures

Each task is graded per tool:

- `done`: the tool's documented route does it without code beyond the documented calls;
- `manual`: possible only with code or steps the user writes beyond the documented route (said what);
- `absent`: the tool has no mechanism for it.

Steps are user-facing steps of the documented route: one per command or function call the user writes, plus one per UI action. Wall time is measured from the start of the step's process to its result; timed steps are run three times and reported as median (min-max).

### T1 Build

From the prepared input to a shareable artifact (a directory that can be copied). CerebroNexus: Builder route to "CRB files + Viewer App". ShinyCell: `makeShinyApp()` output directory. iSEE: `sce.rds` plus an `app.R` with `iSEE(readRDS("sce.rds"))` (the user writes `app.R`: `manual`). cellxgene: the `.h5ad` is the artifact (no build step: `absent`, nothing to build). Vitessce: `data.zarr` + `config.json` (+ the served page). Time: build process start to artifact written.

### T2 Deploy

The artifact is copied to a new empty directory; a fresh process is started on a port not used before from that directory only; headless Chrome (chromote) opens it and waits for the main embedding view (the targets of Task 1). Recorded: HTTP status, time from process start to the view drawn, whether the tool documents login or password protection and, if so, a second deployment with it; for every deployment, whether the artifact's data files can be fetched over HTTP without logging in (direct URL of the data file and the tool's data API).

### T3 Save/restore

(a) State: change the app state (a cell selection or an annotation; for builders, also an edit of the configuration), save it with the tool's own mechanism, stop the server, start it again from the same artifact, and check whether the state is restored. (b) Update: rebuild the artifact into the same location from the changed input; then repeat with the build process killed (SIGKILL) halfway through its run time measured in T1, and check whether the previous artifact is still served, restorable, or damaged.

## Limits stated in advance

One Mac; documented routes only; no usability judgement; small input (2,638 cells); login tested only where the tool documents it.
