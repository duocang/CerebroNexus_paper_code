# Round 2 diary

Round 2 compares CerebroNexus `perf/viewer-page-open` with ShinyCell, iSEE, cellxgene and Vitessce. Protocol: [PROTOCOL.md](PROTOCOL.md). Round 1: Git history up to commit `983df03` (Deviation D5).

## 2026-10-25

- R 4.6.1 environment checked on the Windows host: `env/rlib` holds the dependency closure of the tools as binaries (266 packages); the R 4.6.1 system library has other packages, so an isolation check is part of the protocol. 170 loaded namespaces, all from `env/rlib`.
- 10,000-cell smoke test of all five tools with the R 4.6.1 library and the then-current branch commit (`663a990f`): all built, started and drew cells (scratch in `C:\Users\wangx\Projects\catch\tool_comparison\scratch_20261025\`, not part of any table). The branch had no `.h5ad` importer: round 2 builds CerebroNexus through Seurat.
- Headless Chrome 155 reports `ANGLE (NVIDIA, NVIDIA GeForce RTX 4060 ... Direct3D11)`: the browser is GPU-backed.

## 2026-10-26

- The branch moved to `30e6e9c8` (5.5.0); this commit is the pin.
- Layout: round-1 protocol, diary, work order and results moved to `archive/round1_cerebronexus-6.0.0/` with `git mv`; round-1 builds in `data/builds_round1/`, round-1 R library in `env/rlib_round1_r45_cerebronexus6.0.0/`; `env/rlib` is the R 4.6.1 library; scratch moved to `C:\Users\wangx\Projects\catch\tool_comparison\scratch_20261025\`. Worktree `C:\Users\wangx\Projects\worktrees\paper-tool-comparison-r2` (branch `feat/tool-comparison-round2`), with `env/` and `data/` as junctions to the main checkout (remove the junctions with `rmdir` before removing the worktree).
- PROTOCOL.md for round 2 written; waiting for the owner's approval before the harness changes and the pilot.

## 2026-10-26, after the owner approved the protocol

- `PROTOCOL.md` frozen: `results/PROTOCOL.sha256` 664d3b994798870235d4b52ac0f5de7e74c23ca86e76350f6106c501db5a6b20, `results/PROTOCOL_body.sha256` 3c3043a754844f709ff750c8ab7038c0ee738f73a09b6f10bf4b27728567268b (text before the Deviations heading).
- Environment recorded: `results/environment.json` (R 4.6.1, Bioconductor 3.23, iSEE 2.24.0, CerebroNexus 5.5.0 from `30e6e9c8`, tarball SHA-256, GPU RTX 4060 driver 621.01, WebGL renderer ANGLE/D3D11 NVIDIA, isolation check 170 loaded namespaces, 0 outside `env/rlib`). Installed by `scripts/setup/setup_r_round2.R`; `scripts/setup/r_isolation.R` is the check.
- Inputs: raw files have the round-1 sizes and SHA-256 (`results/inputs.csv`); the derived inputs, which round 1 did not hash, were last modified on 2026-10-22 and are hashed now in `results/inputs_derived.csv`; `1m/source` in `large-examples` has the same SHA-256 as `data/raw` E18.
- Harness changes before the pilot: R path 4.6.1 (`harness.py`, `run_r.sh`, `record_env.py`); Chrome launched after the server's first HTTP 200; CerebroNexus build/serve scripts for this branch (anndataR -> Seurat -> `exportFromSeurat`; the H5 sidecar is found next to the `.crb`, `launchCerebro` has no `expression_matrix_*` arguments); R-side `input_for` also gives CerebroNexus the rewritten I1 file.
- Pilot (not in any table; evidence in `results/evidence/pilot/`): I1 and the 10,000-cell tier, all six configs built, started and drew cells (screenshots of CerebroNexus and Vitessce looked at). 10,000 cells, ready / first plot in s: cerebronexus_default 3.8 / 1.8, cerebronexus_h5 3.3 / 2.0, shinycell 2.2 / 3.5, isee 7.0 / 9.7 (opens on `X_pca`), cellxgene 8.6 / 0.9, vitessce 0.6 / 1.9.
- Still to do before the first measured run: CerebroNexus routes for Task 1 (I1-I4) and Task 2 on this branch (the old scripts call `convertH5adToCerebro`), then the SHA-256 of `scripts/run/harness.py`, its config and the tool scripts here.

## 2026-10-26, Task 1 and Task 2 routes for CerebroNexus on this branch (trial, not in any table)

Trial outputs: `results/evidence/pilot/task1_trial/` and `results/evidence/pilot/task2_trial/`; they are re-run with all five tools in the measured pass.

- Task 1 (`scripts/run/task1/cerebronexus.R`; `scripts/report/aggregate_task1.py` updated): the documented route for an AnnData file is anndataR -> `SingleCellExperiment` -> `exportFromSCE()`, which needs `file`, `experiment_name`, `organism`, `groups`, `nUMI`, `nGene` (omitting `groups` errors). I1: original file refused by anndataR (anndata<0.8), works from the rewritten file, 3 projections (no PCA), `louvain`. I2: via the SCE route `CTaa` stays a metadata column and no repertoire is built; via Seurat + `addImmuneRepertoire()` 365 repertoire rows. I3: default route gives a `spatial` projection only, no Spatial entry and no image; a hand-built Seurat FOV image plus `spatial_images` (PNG of the H&E image with bounds) gives the Spatial view with the image (checked on the screen, aligned) and is graded `manual`. I4: anndataR 1.2.2 reads `I4.h5ad` with a warning ("duplicate row.names", obs dropped), `exportFromSCE` then fails on the missing group column; with the duplication built in R the CRB keeps the duplicated names without a message (`silent`; round 1 6.0.0 refused them).
- Task 2 (`scripts/run/task2/t2_cerebronexus.py`, CRBs of the Task 1 routes): S1 region J = 0.977 (350 exported for 342), S1 attribute (Group filters + lasso) J = 1.0, S2 region J = 0.647 (17 exported for 11), S2 attribute `route not found` (CTaa is not a grouping variable of the I2 CRB, as in round 1 D14). Control paths on 5.5.0 are the same as on 6.0.0.
- ShinyCell and iSEE Task 1 scripts run on R 4.6.1 / Bioconductor 3.23 (ShinyCell I1: default route error, works with the plain-matrix workaround, as in round 1).

## 2026-10-26, merged build from `tmp/应急` (Deviations D1, D2)

- The owner provided `tmp/应急` (`2786ff6d`, Builder 6.0.0 merged into `perf/viewer-page-open`), with the h5ad importer and the Viewer optimisations. It replaces the 5.5.0 branch as the CerebroNexus pin; the 5.5.0 trial results are kept in `results/evidence/pilot/` and are in no table. The round-1 Task 1, Task 2 and Task 3 build routes for CerebroNexus were restored (`scripts/run/task1/cerebronexus.R`, `task2/t2_cerebronexus.py`, `tools/cerebronexus_build.R`, `harness.py` build arguments); `cerebronexus_serve.R` stays the two-argument version.
- Installed into `env/rlib` (6.0.0, six more dependencies, isolation check 171 loaded namespaces, 0 outside `env/rlib`); `results/environment.json` recorded again.
- Pilot (I1, 10,000 cells, default and H5): built, started, drew cells. Task 1 on I1-I4 and Task 2 S1/S2 give exactly the round-1 results (I1/I2/I3 ok, I3 spatial and image `auto`, I4 rejected with the duplicate-name message, I2 TCR only through `addImmuneRepertoire()`; S1 region 0.977, S1 attribute 1.0, S2 region 0.647, S2 attribute no route).
- The host was busy (CPU 70-90% from other processes) during this pilot, so its start times (ready 12-14 s, first plot 5-7 s) are about 3x the earlier ones; load and `launchCerebro` times of 5.5.0 and 6.0.0 measured back to back are equal (D2). Measured runs wait for a quiet host.

Correction (same day): the whole-file hash above is that of the PROTOCOL.md as frozen before Deviations D1 and D2 were added (whole-file hash now differs by design); the body hash is unchanged and is checked.

## 2026-10-26, scripts frozen; measured runs start

- Owner: run everything at full scale; if a step fails, patch what the comparison needs, not perfection.
- `results/scripts_manifest.sha256` lists the SHA-256 of every script under `scripts/` as of the start of the measured runs (manifest hash $(cat /tmp/m.txt)). Task 3 seed set to 20261026 (`scripts/run/task3/run.py`, as PROTOCOL 8.3 says). Any later script change is a Deviation.
- Host load: `vmmemWSL` (the WSL virtual machine, work that is not part of this study) uses about 15 of the 24 logical cores (total CPU 70-90%). Task 1 and Task 2 are not timed and run now; Task 3 waits for a quiet host.

## 2026-10-26, Task 1 done; Task 2 started

- The owner stopped the WSL jobs. Idle CPU before the run about 25% (HipsDaemon about 1 core, vmmemWSL about 0.7 core, other desktop processes); round 1 had a median of 9.7% and p90 of 22.9% in `idle_cpu_pct_before`. Every run stores its own idle sample.
- Task 1 (`scripts/run/task1/run_all.sh`) ran for all five tools; the first attempt did not run the ShinyCell and iSEE rows because `run_shinycell.sh` and `run_isee.sh` still had the pre-reorganisation `cd ../..`; fixed to `../../..` and the whole driver was re-run (the first attempt's CerebroNexus, cellxgene and Vitessce rows were overwritten by identical re-runs). Script manifest regenerated (`results/scripts_manifest.sha256`).

## 2026-10-26, Task 2 done; Task 3 started

- Task 2 (`scripts/run/task2/run_all.sh`): all routes, three runs each; results as in round 1 (S1 region 0.977 for CerebroNexus and cellxgene, 0.974 Vitessce, 0.974 iSEE lasso; attribute 1.0 in CerebroNexus S1, cellxgene, Vitessce; ShinyCell no export route; CerebroNexus S2 attribute no route; iSEE attribute export ignores its filter). The first cellxgene Task 2 attempt failed with "server did not start" because `t2_cellxgene.py` launched cellxgene without the upgrade-check block of round-1 D12; it now uses `harness.cellxgene_env()`, the four cellxgene routes were re-run, and `results/task2/` holds only the re-run rows.
- Task 3 started: `python scripts/run/task3/run.py run` (tiers 10,000, 100,000, 500,000; seed 20261026). Nothing else heavy runs while it measures.

## 2026-10-26, Task 3 finished; tables and figure

- Task 3: 6 configs x 3 tiers x 3 builds x 3 starts, every build and every start `ok` (54 builds with 9 cellxgene `n/a`, 162 starts); about 2 h 50 min (03:04 to 05:50). No timeout, error or out-of-memory. Tables: `results/summary_task3.csv|md`, `results/SUMMARY.md` (one page for the three tasks), raw rows in `results/task3/`.
- Largest values at 500,000 cells (median): CerebroNexus embedded build 165 s, ready 20.6 s, first plot 2.5 s, server peak 15.8 GB; CerebroNexus HDF5 build 876 s, ready 3.2 s, first plot 1.95 s (total 5.2 s), server peak 0.56 GB; ShinyCell build 724 s, total 9.5 s; iSEE total 50.4 s, server peak 14.9 GB; cellxgene total 11.4 s, server peak 8.0 GB; Vitessce total 4.9 s, server 0.03 GB (Chrome 1.4 GB).
- Deviations D3 (script changes) and D4 (host load) added to `PROTOCOL.md`; the body hash is unchanged. Script manifest regenerated.
- Quantitative figure `figures/fig-tool-comparison.pdf|png` drawn from the three summary tables (patchwork, Arial, 170 x 120 mm, 6-8 pt text, line widths at least 0.38 pt, fonts embedded) and checked with `topics/interface_figures/scripts/check_figures.R`: all figures pass. Not committed.
- Idle CPU before the 162 Task 3 starts: median 3.7%, p90 7.8%, max 13.7% (round 1: 9.7%, 22.9%, 81.5%); a sample before Task 2 read about 25% (corrected in D4).

## 2026-10-26, merged to main

- The round-1 archive was removed from the tree at the owner's request (Deviation D5); the new results and `figures/` are the ones kept. `FIGURES.md` moved to the folder top, `capture_figures.py` writes to `figures/captures/`, `README.md` rewritten for round 2.

## 2026-10-26, CerebroNexus re-run with the H5 write optimisation (Deviation D6)

- New pin `c9bc0a0d` (`tmp/应急-优化`: H5 sidecar written with rhdf5 slabs instead of `writeTENxMatrix`). The new 10,000-cell `.h5` equals the old one in every dataset, type, chunk, filter and value. Both CerebroNexus configurations re-run on all three tiers (3 builds x 3 starts, 54 starts, all `ok`); the other four tools, Task 1 and Task 2 were not repeated. The old rows (`2786ff6d`) are in `results/superseded/cerebronexus_2786ff6d/`.
- A first launch of the re-run started two runners at once (my mistake; the process check I used to wait did not see the second one); the starts of that attempt failed or were `not_run`; stopped, moved to `results/superseded/cerebronexus_c9bc0a0d_aborted_two_runners/`, and the tier run again with one runner.
- Median at 500,000 cells: H5 build 876 s -> 176 s (5.0x), 100,000 cells 73 s -> 35 s; embedded build 165 s -> 183 s (unchanged within noise); ready 3.2 s and 20.6 -> 21.3 s; first plot 1.95 -> 2.15 s (H5) and 2.54 -> 2.81 s (embedded), 0.2-0.5 s longer than in the earlier runs for reasons not looked for (the change does not touch the Viewer). Idle CPU before the new starts: median 5.1%, maximum 8.4%.
- `figures/fig-tool-comparison-start.pdf|png` redrawn; `figures/fig-tool-comparison.pdf` could not be redrawn because the PDF is open in a viewer (file locked): it still shows the numbers before D6 until it is redrawn.
