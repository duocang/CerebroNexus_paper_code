# One standard for the topics

Every topic measures, installs or captures **one** CerebroNexus revision: the commit in
[`cerebronexus.pin`](cerebronexus.pin) (branch `integration/8.3.0`, version 8.3.0). `tests/test-pin.R` checks that
the lock files and the defaults of the run scripts agree with it. When the final branch moves, change the pin and
nothing else; then run the topics again.

## 1. Rules the measurement topics share

These are the rules of [`viewer_performance`](viewer_performance/STANDARD.md) (`blackbox-v7`); `builder_performance`
and `app_export` follow them, and the others should where they measure time.

| Rule | What it means |
|---|---|
| One revision, installed from `git archive` | only committed code is measured; the manifest records the commit |
| A fresh process per measurement | nothing cached in the process; caches that live in files are isolated per run (`R_USER_CACHE_DIR` for the Viewer; a work folder per session for the Builder) |
| Candidate and baseline in one run, in turns | which goes first alternates with round and scenario; both run folders carry the same `pair_id` |
| At least 5 rounds | with 3 against 3 no outcome can reach p ≤ 0.05; `compare.R` says `too few rounds` |
| The decision rule | exact two-sided rank-sum test over the rounds, p ≤ 0.05, **and** a difference of medians above a floor (Viewer: one frame; Builder: 3 % and 15 ms) |
| The machine is idle | each session waits for the whole machine below 15 % CPU; a CPU canary is read per round; both are in the manifest |
| Noise is measured once per machine | `--candidate A --baseline A`: what `compare.R` reports is the noise; nothing smaller is a result |
| Faster paths are checked for equivalence | a path that reuses a file or writes it another way gets a check that it gives the same data and does not reuse what no longer fits (`builder_performance/standard/checks.R`) |
| The run record | `manifest.tsv` (revision, machine, fixtures with checksums, harness commit), `raw.tsv` (every observation), a summary, the problems |
| Smoke runs are marked | fixtures made with `--scale` say so in the problems and the manifest; never a result |

## 2. Where each topic stands on the pin

Status on 2026-11-13. "Smoke" is a run on tiny data that shows the harness works; "rerun" is a complete run of the topic on
the pin.

| Topic | Status on the pin | What has to be done |
|---|---|---|
| `viewer_performance` | **measured on the pin** (2026-11-13, Windows): 8.3.0 against master, and 8.3.0 against itself (noise); runs in `runs/` | not faster as a whole: 3 rows faster, 7 slower (cold page visits, first start); the noise run resolves 0 of 35 rows, but its canary moved by 1.68 and 2 sessions started on a busy machine. The fixtures are the old CRB layout; the 8.3.0 layout cannot be read by master. Open: STANDARD section 8 (page links, interactive time, `start.R`) |
| `builder_performance` | **measured on the pin** (2026-11-13, Windows, real-size fixtures): 8.3.0 against master, and against itself | faster by 36 to 88 % in every scenario but the import inside a Build (`runs/compare_master_vs_8.3.0.md`); noise: 0 of 11 rows. `freeze_s` is 0.2 s slower. Peak memory unchanged for H5 |
| `app_export` | **measured on the pin** (5 rounds, 8.3.0 and master, one after the other) | embedded and H5 100 k faster with lower peak memory; small CRBs: first export 0.5 to 1.1 s but the whole session faster. Its comparison is still the old 20 % + 0.3 s rule, no rank-sum, no noise run |
| `tool_comparison` | **rewritten and run** (2026-11-19, Windows): start, start again, colouring by a gene, memory and build time of five viewers at 5k, 10k, 20k, 50k, 100k and 1.3 M cells; CerebroNexus = HEAD of the checkout, nothing frozen | the capability and selection figure uses the earlier measurement (`features/README.md`); the skill's alignment gate could not audit the nested layout (checked on the rendered edges) |
| `expression_backends` | **retired**: BPCells was removed from the package; not rerun | none; results stay as the record of `17a6a35`. Storage of the current package: `builder_performance`, `app_export` |
| `builder_validation` | **rerun on the pin**, A to F (WSL); results in `results/*_e927cbf18*` | D arrow rows are history only; S11b and the figures not regenerated; F1 sub-check is weaker; package tests of the pin not run |
| `builder` | **rerun on the pin** (WSL); three builds byte-identical; CRB checksums changed | whether the bytes differ on another day (the CRB records its export date) |
| `interface_figures` | **recaptured and redrawn on the pin** (WSL); `check_figures.R` passes for 9 figures | a single `run.sh all` end to end was not run; figures 4 to 7 changed (smaller demo CRBs), so their legends and the text must follow |

### `expression_backends`

Retired by the owner: BPCells is gone from the package, so the comparison it supported is closed. The README says so, the
lock keeps the commit of the measurement, the pin test does not check it. The audit found the harness could not run on the
pin anyway (BPCells functions, an H5 layout without `/expression/genes`, gzip level 6 recorded as the default, lazy H5
attachment changing `startup_secs`).

### What the three reruns changed

None of the three ties itself to a version or a commit any more: each reads `cerebronexus.pin`, records the installed commit
and version, and stops only when the installed commit is not the pin. Helpers come from the installed package, not from file
paths of an older source layout; a runtime file that is missing is skipped and recorded.

- `builder_validation`: A (20 cases) and B (6 of 6) give the same outcomes as on 6.0.0; C (36 rows), E (37 pass, 1 fail, 2 info),
  F1/F2 and F3 (12 of 12 refused) agree row by row on their state columns; D (spatial transforms) stays within 0.53 px. The arrow
  rows (D, S11b) cannot be reproduced because the fixture is gone: the Visium crop that the package ships replaces them
  (`D_visium_crop`, 24 rows), and the old rows are marked history only. The lockout finding is stale: on loopback only the account
  is counted. F1's server-side table of selected cells no longer exists, so that sub-check is now a metadata-row match.
- `builder`: both builds give 6,484 cells and 411 cells as before, with the same two Seurat warnings; the CRB bytes and SHA-256
  differ from 6.0.0 (new native readers), so the README tables were replaced, the old ones are in Git history.
- `interface_figures`: one commit for Viewer and Builder. The demo CRBs are smaller than when the figures were first made, so
  the selections of figures 4 to 7 were made again by rules in the script and every count is computed into `data/checks.json`
  (HLA 12,000 to 2,000 cells; selections 10, 293 to 2, 55; Xenium 500 to 197; the motif network 94 to 23 points). The Ren numbers
  are unchanged. The captures are of the pinned Viewer, so any text in the manuscript that quotes the old counts has to change.

## 3. Not decided yet

- The pinned commit is only on this machine; the reruns above installed it from the local clone. A reader cannot reproduce them
  until the branch is pushed, and `interface_figures/run.sh` falls back to the URL only then.
- The three reruns, and the performance topics, were not committed. The harness commit in every manifest is `-dirty` until
  they are.
