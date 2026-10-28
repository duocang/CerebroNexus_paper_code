# Builder validation on real data

Run on 2026-10-27 (macOS arm64, R 4.6.1, Chrome via chromote). Six experiments test the CerebroNexus Builder headlessly, through the functions its tests and its Shiny server call: malformed inputs (A), end to end on real inputs including the exported Viewer App (B), publication faults and recovery (C), spatial background-image transforms rendered in the Viewer (D), authorization boundary and data leakage of generated Apps (E, threat model in `THREAT_MODEL.md`), and cell selection, cross-view mapping and HDF5/immune sidecars (F). A-D were run again, unchanged, on the head of the branch, so that every executed row exists on one revision (section "Rerun on 001c4d4dd").

## Software under test

`duocang/CerebroNexus`, branch `builder/03_builder`, commit `84ff72b3368eb206354204d6e4871ac3600f1253` (version 6.0.0). It was fetched into the existing checkout `../CerebroNexus` (`git fetch origin builder/03_builder` only; that checkout's working tree and branch were not touched), exported with `git archive` to `env/src` and installed with `R CMD INSTALL --library=env/rlib`. Every script puts `env/rlib` first on the library path and checks that CerebroNexus is loaded from there. Versions and `sessionInfo()` are in `results/environment.txt`.

Experiments A-D below were run on `84ff72b3`. Three of the findings were then fixed on the same branch (section "After the fixes"): `9e6cc425c` (aligned images in the Viewer) and `4c34857c9` (QC columns), pushed to `origin/builder/03_builder`, then `001c4d4dd` (arrow example preset). `4c34857c9` was installed into `env/rlib` in the same way (`results/environment_4c34857c9.txt`), and D and the PBMC SCE row of B were run again; files from that run carry the suffix `_4c34857c9`.

## How the Builder is driven

`scripts/common.R` sources the Builder runtime from the installed package in the order `inst/builder/app.R` uses (without UI, Shiny server programs, worker and session files) and runs the route of `tests/testthat/test-builder-end-to-end.R`:

| Stage | Functions |
|---|---|
| profile | `builder_seurat_file_adapter()`, `builder_adapter_inspect()` |
| plan | `builder_recommend_metadata()`, `builder_default_settings()`, Review policy as `builder_e2e_review_metadata_policy()` in the test helper, `builder_snapshot_seurat()`, `builder_freeze_plan()` |
| build | `builder_coordinator_prepare()`, `builder_execute_plan()` |
| publish | `builder_coordinator_publish()`; in C via `builder_coordinator_settle()`, the function the server calls (`server/imports.R`) |

All builds use the embedded expression backend and output "CRB files + Viewer App". Spatial images are attached as external image records built with `builder_alignment_record()`, as the Spatial page stores them. The Viewer is started with `shiny::runApp()` in a separate R process whose library has every package except CerebroNexus (the exported App must be self-contained, as in `privacy_start_app()` of the tests), and is driven with shinytest2/chromote (headless Chrome).

## Inputs (`scripts/00_prepare_inputs.R`, checksums in `results/inputs.csv`)

| Input | Source | Size |
|---|---|---|
| `visium_anterior1.rds` + `visium_anterior1_he.png` | SeuratData `stxBrain` anterior1 (10x Visium), all spots and genes, light processing as `data-raw/build_spatial_demos.R`; lowres H&E 600 x 599 px | 2,696 spots x 31,053 genes |
| `xenium_brain.rds` + `xenium_dapi.png` | 10x Xenium mouse brain CTX+HP outs bundle (`cf.10xgenomics.com/.../Xenium_V1_FF_Mouse_Brain_Coronal_Subset_CTX_HP_outs.zip`), matrix read with rhdf5, centroids FOV in microns; DAPI MIP via RBioFormats, 1602 x 1040 px | 36,602 cells x 248 genes |
| `pbmc_seurat.rds`, `pbmc_SCE.rds` | `inst/extdata/examples` of the package | 80 cells x 230 genes |
| `pbmc3k.h5ad` | cellxgene example dataset (`chanzuckerberg/cellxgene/main/example-dataset/pbmc3k.h5ad`, legacy AnnData layout) | 2,638 cells x 1,838 genes |

## Running

The recorded runs were made on macOS 27 with R 4.6.1 and Google Chrome (versions in `results/environment_*.txt`); package versions are recorded there, not locked. Every step runs from this directory.

1. Packages: the R packages listed in `results/environment_33150d9d7.txt` (Seurat, SeuratObject, SeuratData with `stxBrain`, shinytest2/chromote, EBImage, rhdf5, RBioFormats, sp, png, ...) and Chrome for chromote.
2. Work directories: `env/` (CerebroNexus source and library) and `data/` (inputs, builds, releases) are git-ignored; create them as plain directories (`mkdir env data`) or as symlinks to a larger disk (the recorded runs used symlinks into `/Volumes/bv_cache`). The Builder refuses symbolic links in source and output paths and an exFAT volume adds `._*` files to every release, so use a local APFS/ext4 file system. `TMPDIR` defaults to `data/tmp/` in the run scripts.
3. CerebroNexus: `scripts/install_cerebronexus.sh <commit> [clone or URL]` writes the `git archive` of the commit to `env/src` and installs it into `env/rlib` (log `results/install_<commit>.log`). Install the revision of a run before running it.
4. Inputs: download `pbmc3k.h5ad` (cellxgene example dataset) to `data/raw/` and unzip the Xenium outs bundle (table above) to `data/raw/xenium/brain/`, then `Rscript scripts/00_prepare_inputs.R` (checks against `results/inputs.csv`; sources in `results/inputs_provenance.csv`).
5. Runs, one script per revision, each with the parameters and output names of the recorded run:

```bash
scripts/install_cerebronexus.sh 84ff72b3368eb206354204d6e4871ac3600f1253 && scripts/run_84ff72b3.sh   # unsuffixed A-D
scripts/install_cerebronexus.sh 4c34857c9 && scripts/run_4c34857c9.sh                                  # *_4c34857c9 (B SCE, D)
scripts/install_cerebronexus.sh 001c4d4dd68a6fc5c2c958d7c0c2a49961671b95 && scripts/run_001c4d4dd.sh   # *_001c4d4dd, E and F unsuffixed
scripts/install_cerebronexus.sh 33150d9d7a957607ccf43a0296903e073be2408f && scripts/run_33150d9d7.sh   # *_33150d9d7, S11b display captures
```

6. Figures: from the repository root, `Rscript topics/builder_validation/scripts/figures.R` and `Rscript topics/interface_figures/scripts/check_figures.R topics/builder_validation/figures` (they read only `results/`).

Logs of the recorded runs are in `results/logs/`.

## Results

### A. Malformed inputs (`results/A_malformed_inputs.csv`, 20 cases)

| Case | Stopped at | Outcome |
|---|---|---|
| truncated .rds; PNG bytes named .rds | profile | explicit error ("Could not read with RDS") |
| truncated h5ad; h5ad header only | profile | explicit error ("not a readable HDF5/h5ad file") |
| duplicated barcodes (SCE; Seurat cannot hold them) | profile | explicit error, generic ("duplicate 'row.names'") |
| zero cells / zero genes (SCE) | profile | explicit error, generic (Seurat conversion message) |
| image file deleted after Review | plan | explicit error ("has no valid external source file") |
| image file not an image | plan | explicit error (image reader) |
| image replaced after Review | build | explicit error ("failed its integrity check") |
| requested layer absent | plan | explicit error, clear |
| requested assay absent | plan | explicit error, cryptic (`invalid_artifact_identity`) |
| coordinate barcodes match no cell | plan | explicit error ("blocking capability: spatial") |
| own `nUMI`/`nGene` columns next to `nCount_*`/`nFeature_*` | build | explicit error, misleading ("staged CRB metadata differs from BuildPlan"), see Findings |
| spatial data removed | published | correct: no spatial section, all else identical |
| coordinates for half of the spots | published | correct: 1,348 coordinates, all equal by barcode |
| coordinate rows shuffled | published | correct: every coordinate equal by barcode |
| empty-string column; all-NA column | published | correct: kept as metadata, not offered as groups |
| 100 NA expression values | published | NA kept exactly (100 in, 100 out), no warning |

No case produced a CRB whose content differs from its source.

### B. End to end (`results/B_end_to_end.csv`)

| Input | Profile -> publish (s) | Viewer HTTP / dataset loaded | Cells, genes, order | Expression max abs diff (values) | Projections | Groups | Coordinates | Image |
|---|---|---|---|---|---|---|---|---|
| Visium + H&E | 15.5 | 200 / yes, Spatial page, image listed | identical | 0 (83,718,888) | 0 | 0 mismatches | 2,696, max diff 0 | 600 x 599, pixel diff 0, bytes identical |
| Xenium + DAPI | 9.0 | 200 / yes, Spatial page, image listed | identical | 0 (9,077,296) | 0 | 0 | 36,602, max diff 0 | 1602 x 1040, pixel diff 0, bytes identical |
| PBMC Seurat | 3.1 | 200 / yes | identical | 0 (18,400) | 0 | 0 | - | - |
| PBMC SCE, defaults | fails at build | - | - | - | - | - | - | - |
| PBMC SCE, own nUMI/nGene chosen | 3.3 | 200 / yes | identical | 0 (18,400) vs `logcounts` | 0 | 0 | - | - |
| pbmc3k.h5ad | 4.6 | 200 / yes | identical | 0 (4,848,644) vs `X` read with rhdf5 | 0 (TSNE, UMAP, draw_graph_fr) | 0 (`louvain`) | - | - |

"Dataset loaded" means: in headless Chrome the Gene expression page selected a gene and the projection canvas painted points (the Viewer draws a subset of cells by its own display settings: 1,025 of 2,696 for Visium). Total time per input including the Viewer check was 9-28 s.

### C. Publication faults and recovery (`results/C_publish_faults.csv`, 36 rows)

v1 is published, then v2 (same input, other dataset name) is published into the same output with one fault. Restore or abort is applied when recovery is required (each fault is run once per action).

| Fault | Release after fault | Recovery state | After restore | After abort | Residue after restore |
|---|---|---|---|---|---|
| App verification fails (before lock); payload check fails before or after the v2 rename; install move fails | v1 (rolled back by the Builder) | ready | v1 (no-op) | v1 (no-op) | none |
| SIGKILL after verification / at `old_moving` | v1 | recovery_required | v1, ready | v1, ready | none |
| SIGKILL right after v1 moved to backup / at `old_moved` | absent | recovery_required | v1, ready | refused ("A preserved prior release cannot be discarded by abort"), release stays absent | none |
| SIGKILL at `new_published` | v2 | recovery_required | v1, ready | refused, v2 stays | none |
| Exception after v1 moved to backup / at `old_moved` / at `new_published`; install and restore moves both fail (process stays alive) | absent / absent / v2 / absent | recovery_required | refused: "The release lock is not safely recoverable; manual inspection is required." | same | backup and lock kept |
| Same exceptions in a child process that then exits | absent / v2 | recovery_required | v1, ready | refused | none |
| Byte appended to the staged CRB after build / after the ownership record / after v1 moved to backup | v1 | ready | v1 | - | none |
| Byte appended to the published v1 CRB after v2 was planned | v1 (changed byte kept) | ready | - | - | refused: "The release changed after Review; nothing was published." |
| Foreign file in the v1 release | v1 | ready | - | - | refused, file preserved |

How faults were injected: in-process through the injection arguments that `test-builder-publish.R` uses (`builder_publish_release(.move, .after_phase, .after_move, .verify_payload)`, `builder_coordinator_publish(.verify_app, .publish)`), with publication run through `builder_coordinator_settle()`; SIGKILL by `processx` `$kill()` of a `callr` child that builds and publishes v2 and parks at the chosen phase; tampering by appending one byte to the file. In every case the previous verified release was either intact or restorable to an identity equal to v1 (`builder_release_identity()`). The one exception: an in-process error after v1 had been moved, while the owning process kept running.

### D. Spatial transforms (`results/D_spatial_transforms.csv`, `D_arrow.csv`, `D_multisection.csv`; captures in `results/D_captures/`)

Expected positions follow the Builder's alignment preview (`builder-spatial-canvas.js`, `drawImage()`): the image is scaled, flipped (in the image frame) and rotated about its own centre, then shifted by (dx, dy). Cells are placed where the preview puts the landmarks, the image gets that alignment, the App is exported and started, and the rendered Linked views and Spatial canvases are captured. Residuals are in source-image pixels; the capture resolution is about 0.6-2 capture px per image px, so 1-3 px is the measurement floor. "Predicted" is where the Viewer's drawing code (`cell_views.js`, `drawImage()`) puts the same pixels.

Synthetic landmarks (five discs on a 600 x 400 px image, bounds 1000-1600 x 2000-2400):

| Setting | Linked views max residual | Spatial page max residual | Predicted |
|---|---|---|---|
| identity, translate (120, -80), scale 1.5, scale 0.6, flip x, flip y | 0.23 | 0.21 | 0 |
| rotate 90 / 180 / 270 / 30, rotate 90 + flip x, combined | image not in view | image not in view | 1,323-5,111 |
| bounds centred on origin: rotate 90 / rotate 30 | 0.28 / 0.37 | 0.27 / 0.24 | 0 |
| bounds centred on origin: rotate 90 + flip x | 385 | 406 | 385 |
| bounds centred on origin: combined (dx 60, dy 40, scale 1.25, rotate 45, flip y) | 268 | 268 | 340 |

Builder example arrow (`inst/builder/fixtures/spatial_alignment`): `arrow_background.png` is 800 x 500 px with an arrow polygon (orange outline, vertices (80,190) (470,190) (470,90) (720,250) (470,410) (470,310) (80,310)), a dashed spine at row 250, 50-px corner squares (red, green, blue, yellow centred at (25,25) (775,25) (25,475) (775,475)) and TOP/RIGHT/BOTTOM labels. `arrow_spatial.rds` has 159 cells whose coordinates are pixel positions of that image (x = column, y = row; 119 on the outline, 38 on the spine, anchors at (0,0) and (800,500)); both are written by `data-raw/build_builder_spatial_fixtures.R`. Data y points up and image rows point down, so with bounds 0-800 x 0-500 the pair is registered only with flip y. The arrow is mirror-symmetric about row 250, so only the corner squares and labels show the difference. Per setting the cells are moved to where the preview puts their pixels and one CRB + App is exported:

| Setting | Linked: corner max / outline p95 | Spatial: corner max / outline p95 | Predicted |
|---|---|---|---|
| identity | 3.1 / 2.7 | 1.0 / 1.1 | 0 |
| translate (120, -80) | 2.4 / 2.4 | 1.3 / 1.0 | 0 |
| scale 1.5 | 2.4 / 2.2 | 1.2 / 1.2 | 0 |
| scale 0.6 | 2.1 / 1.8 | 0.7 / 1.0 | 0 |
| flip x | 3.6 / 2.7 | 0.8 / 1.0 | 0 |
| flip y | 3.3 / 2.7 | 1.1 / 1.1 | 0 |
| rotate 90 | image not in view | 947 / 1,102 | 667 |
| rotate 180 | 926 (one square in view) | 934 | 943 |
| rotate 270 | 667 / 219 | 668 / 228 | 667 |
| rotate 28 | 227 / 215 | 227 / 217 | 228 |
| fixture as is, identity alignment | 451 / 2.7 | 450 / 1.1 | (vertical flip) |
| Builder example preset as shipped (rotation 28, fitted bounds) | 441 / 259 | 438 / 165 | 228 + vertical flip |

Screenshots: `D_captures/arrow_identity_*.png`, `arrow_rotate_90_*.png`, `arrow_rotate_28_*.png`, `arrow_example_preset_rotation_28_*.png`.

Multi-section (`complete_viewer`, three sections with their real coordinates, one image per section, one CRB, measured on the Spatial page per sample):

| Section | Setting | Max residual |
|---|---|---|
| section_a_1_fov_1 | dx 15, flip y | 0.23 |
| section_a_2_fov_1 | flip x, scale 1.2 | 0.10 |
| section_b_1_fov_1 | rotate 90, dy -10 | image not in view (predicted 2,273) |

## Findings

1. **Rotation is not WYSIWYG (silently wrong display; fixed in `9e6cc425c`).** The Builder preview rotates the image about its own centre; the Viewer (`inst/viewer/www/cell_views.js`, `drawImage()`) rotates the image bounds about the data origin (0, 0), and applies flips in screen axes after the rotation instead of in the image frame before it. Any non-zero rotation therefore moves the image away from the cells by about 2 sin(θ/2) times the distance of the image centre from the origin: off screen for the Visium/Xenium-scale coordinates tested, 228 px for the arrow at 28°. When the bounds are centred on the origin, rotation alone matches, but rotation combined with a flip is still wrong (385 px). The App shows no warning. Translate, scale and flips without rotation match to within the measurement floor on both Viewer pages and across sections.
2. **The Builder's own arrow example opens misaligned.** Its preset (rotation 28, no flip) displays 228-440 px off in the exported Viewer. The fixture itself is registered only with flip y. After `9e6cc425c` the Viewer shows what the Builder preview shows, but the preset itself was still not the fixture's registration. The example also rotated the cells by 28 degrees (a spatial coordinate transform), which the "preset as shipped" rows of D did not apply; in the Builder preview image and cells were therefore rotated together and differed by the missing flip y. Fixed in `001c4d4dd`: the preset is now flip y with no rotation, offset or scale, and no coordinate transform.
3. **Default settings cannot build sources that carry their own `nUMI`/`nGene` next to `nCount_*`/`nFeature_*` (fixed in `4c34857c9`)**, including the shipped `pbmc_SCE.rds`. `builder_default_settings()` picks `nCount_*`, the expected metadata list (`plan/assets.R`, `make.unique`) then contains `nUMI.1`/`nGene.1` while the CRB does not, and the build stops with "The staged CRB metadata differs from BuildPlan". This is loud, not silent, and choosing the source's own columns on Configure works. The import handler's settings (`server/imports.R`) fail the same way. Behind the check, `.addExportMetaData()` overwrote the chosen QC values with the source columns of the same name.
4. **An in-process publication error after the prior release was moved leaves the output absent or unfinalised, and recovery refuses while that process lives.** Restore works once the owning process has exited (rows X1 and X2), as it does after every SIGKILL. Abort never discards a preserved prior release; that is by design.
5. Minor: a missing assay gives `invalid_artifact_identity`; duplicated barcodes and zero-cell/zero-gene SCE inputs give raw Seurat conversion messages; NA expression values are kept without a warning.
6. **The login token can be replayed by a second client (E11; fixed in `c5462c264`).** After login, shinymanager reloads the page with `?token=<64 hex digits>` and `keep_token = FALSE` removes it from the address bar. Opening that URL in a second browser while the first session is open shows the login form, but the App starts the Viewer server function for that second session: its websocket receives the dataset-load messages (dataset name, which pages exist), the same messages a logged-in session receives at start. Minimal reproduction: build a login App (`scripts/apps.R`), log in in one headless Chrome, read the `token=` document URL from the network log, open it in a second Chrome, and record the second page's websocket frames (`scripts/E_security.R`, E11). `viewer_auth_apply()` (`inst/viewer/auth.R`) starts `server()` when shinymanager's `auth$user` is set, and shinymanager sets it from a token that its UI function no longer treats as valid. How far a second client can get beyond these messages was not explored. After logout or timeout the token is removed and replay fails (E12).
7. **No lockout or throttling of login attempts (E08; fixed in `58a604a0d`).** The Viewer reads the credentials table into memory (`shinymanager::check_credentials(<data.frame>)`), so shinymanager's per-user failure counters in the database are not used; 25 wrong passwords in 20 s were followed by a successful login.
8. **A replaced H5 sidecar with the same cell and gene IDs is shown without error (F3; fixed in `33150d9d7`).** The App checks that the sidecar exists, opens and has the CRB's cell and feature names, but not its content: an H5 with the same IDs and doubled values loaded and was displayed. The Builder records sidecar digests at build time (release identity, C), and the immune sidecar carries a checksum the reader checks; the expression sidecar does not. Reproduction: `scripts/F_hdf5.R`, case `replace_same_ids_changed_values`.
9. **The database key ships with the App (E17, by design).** The Builder writes the 64-hex-digit key to `viewer-auth.env` (mode 0600) in the App root, next to the encrypted database; encryption at rest therefore protects the credentials only together with the file permissions. Supplying the key as `CEREBRO_AUTH_PASSPHRASE` and deleting the file works (E24), but the Builder offers no export without the file.
10. Minor (F1): a View JSON with any unknown cell ID is rejected as a whole with a generic message; known and unknown IDs are not reported separately. A repertoire with rows for IDs that are not cells holds the build at Review without naming them.

## After the fixes (commit `4c34857c9`)

- `9e6cc425c` `fix(builder): render aligned images in the Viewer as previewed`. `builder_alignment_viewer_setting()` (`inst/builder/extras.R`) converts the Builder alignment into the settings the Viewer receives (`inst/builder/build.R`). Rotation t stays t, or becomes -t when exactly one axis is flipped. The offset becomes c + (dx, dy) - R(t')c for the base-bounds centre c. The Viewer keeps its origin-pivot rotation, which `spatial_plot_rotation` relies on (`tests/testthat/fixtures/background-rotation.js`). The CRB keeps the Builder alignment record unchanged. Embedded images were not affected, since their calibration is baked into the pixels. New tests are in `tests/testthat/test-builder-viewer-alignment.R`: the converted settings against the preview geometry for 26 cases, landmarks of the arrow fixture under rotation 0/90/180/270/33 with and without flip x, and a Node fixture (`fixtures/builder-viewer-alignment.js`) that runs the real `drawImage()` of `builder-spatial-canvas.js` and of `cell_views.js` and compares the image corners.
- `4c34857c9` `fix(builder): keep chosen nUMI/nGene when the source has its own`. `.addExportMetaData()` (`R/export_builders.R`) no longer lets other source columns overwrite `cell_barcode`, `nUMI` or `nGene`, and the BuildPlan expectation (`inst/builder/plan/assets.R`) leaves those names out of the additional metadata in the same way. Tests: `pbmc_SCE.rds` with the import handler's default settings builds and its CRB `nUMI`/`nGene` equal the chosen `nCount_RNA`/`nFeature_RNA` (`test-builder-end-to-end.R`); `.addExportMetaData()` keeps the chosen values and the barcodes (`test-export-core.R`).
- Package tests (`devtools::test()` filtered to Builder spatial/plan/build/app-bundle/end-to-end, all spatial, Viewer node fixtures, export and coordinated-views; 44 files, 647 tests, 4,856 expectations): all new tests pass. There were 2 failures and 4 errors, and the same 6 occur on the unmodified `84ff72b3`: `test-builder-build.R:898`, `:1358`, `test-builder-app-bundle.R:637`, `test-coordinated-views.R:2663`, `:2684` (spatial molecule sidecar and native-encoding of non-ASCII names in this R session) and `test-builder-end-to-end.R:648` ("supplementary sidecars attached").

D on `4c34857c9` (`results/D_spatial_transforms_4c34857c9.csv`, `D_arrow_4c34857c9.csv`, `D_multisection_4c34857c9.csv`; captures in `results/D_captures_4c34857c9/`), max residual in source-image px, `84ff72b3` in brackets:

| Case | Linked views | Spatial page |
|---|---|---|
| synthetic identity, translate, scale 1.5/0.6, flip x, flip y | 0.23 (0.23) | 0.21 (0.21) |
| synthetic rotate 90 / 180 / 270 | 0.28 / 0.23 / 0.28 (not in view) | 0.29 / 0.21 / 0.27 (not in view) |
| synthetic rotate 30 | 0.37 (not in view) | 0.24 (not in view) |
| synthetic rotate 90 + flip x | 0.28 (not in view) | 0.29 (not in view) |
| synthetic combined | 0.42 (not in view) | 0.28 (not in view) |
| synthetic, origin-centred bounds: rotate 90 + flip x / combined | 0.28 / 0.42 (385 / 268) | 0.27 / 0.28 (406 / 268) |
| arrow identity, translate, scale, flips (corners) | 2.1-3.6 (same) | 0.7-1.3 (same) |
| arrow rotate 90 (corners / outline p95) | 1.9 / 1.9 (not in view) | 1.4 / 1.3 (947 / 1,102) |
| arrow rotate 180 | 3.8 / 2.7 (926) | 1.4 / 1.6 (934) |
| arrow rotate 270 | 1.5 / 1.1 (667 / 219) | 2.3 / 1.1 (668 / 228) |
| arrow rotate 28 | 3.5 / 2.7 (227 / 215) | 1.4 / 1.8 (227 / 217) |
| arrow fixture as is, identity alignment | 451 / 2.7 (same) | 450 / 1.1 (same) |
| arrow example preset (rotation 28, no flip), against the fixture's registration | 618 / 114 (441 / 259) | 255 / 115 (438 / 165) |
| multi-section a_1 (dx 15, flip y) / a_2 (flip x, scale 1.2) / b_1 (rotate 90, dy -10) | - | 0.23 / 0.10 / 0.15 (0.23 / 0.10 / not in view) |

The arrow preset rows measure the distance to the fixture's own registration (cells = pixels, which needs flip y and no rotation), not to the preview. With the fix the Viewer draws the preset exactly as the Builder preview draws it, rotated 28 degrees and upside down. Before/after screenshots: `results/D_captures/` and `results/D_captures_4c34857c9/`, for example `arrow_identity_spatial.png`, `arrow_rotate_90_spatial.png`, `arrow_rotate_28_spatial.png`, `synthetic_rotate_90_flip_x_linked.png`.

Arrow example preset on `001c4d4dd` (`fix(builder): open the arrow alignment example registered`), built from the Builder's own `builder_example_configure_entry()` with image and point opacity set to 1 for measuring (`results/D_arrow_001c4d4dd.csv`, captures in `results/D_captures_001c4d4dd/`): corner squares 3.3 px (Linked views) / 1.1 px (Spatial page), outline p95 2.7 / 1.1 px against the fixture's registration, the same as the hand-built flip y case. The package test `test-builder-seurat-omnibus.R` checks the new preset and that every cell's pixel lands on the cell through the converted Viewer settings.

B, PBMC SCE with default settings on `4c34857c9` (`results/B_end_to_end_4c34857c9.csv`): published in 10.2 s, Viewer HTTP 200 and dataset loaded, cells and genes identical, expression max abs diff 0 against `logcounts`, projection diff 0, 0 group-label mismatches.

## Rerun on 001c4d4dd

`duocang/CerebroNexus` branch `builder/03_builder` at `001c4d4dd68a6fc5c2c958d7c0c2a49961671b95` (head of the branch on 2026-10-27; version 6.0.0; there is no release tag, so this is the tested revision and not a release). Installed as before from `git archive` into `env/rlib` (`results/install_001c4d4dd.log`, `results/environment_001c4d4dd.txt`). The inputs were rebuilt with `00_prepare_inputs.R` from the same raw files (`results/inputs_001c4d4dd.csv`: the Xenium outs bundle and `pbmc3k.h5ad` have the SHA-256 of `inputs_provenance.csv`; the derived `visium_anterior1.rds` and `xenium_brain.rds` differ by one or two bytes from the first run, since UMAP and clustering are not bit-reproducible across sessions; their cells, genes and expression are the source of every comparison). A-D and E-F all ran on this revision. The scripts changed only in paths and output names (`bv_data`, `A_OUT`, `C_OUT`/`C_DATA`/`C_BACKEND`, `B_BACKEND`, `BV_HERMETIC_LIB`); the logic of A-D is unchanged.

| Experiment | File | Result on 001c4d4dd |
|---|---|---|
| A, 20 cases | `A_malformed_inputs_001c4d4dd.csv` | as on 84ff72b3, except A12 (own `nUMI`/`nGene` next to `nCount_*`/`nFeature_*`), which now publishes (fix `4c34857c9`) |
| B, 6 inputs | `B_end_to_end_001c4d4dd.csv` | all published; Viewer HTTP 200 and dataset loaded; cells, genes, order identical; expression max abs diff 0; projection and coordinate diff 0; 0 group mismatches; images pixel-identical and byte-identical. PBMC SCE with default settings now builds. Profile to publish 3.1-16.0 s |
| C, 36 rows | `C_publish_faults_001c4d4dd.csv` | release after the fault and final release identical to 84ff72b3 in all 36 rows |
| D, 32 + 26 + 3 rows | `D_*_001c4d4dd.csv`, `D_captures_001c4d4dd/` | every residual identical to `4c34857c9` (max difference 0.00 px); the arrow run adds the example preset as configured (corner squares 3.3 / 1.1 px) |

### E. Authorization boundary and data leakage (`results/E_security.csv`, evidence in `results/E_evidence_001c4d4dd/`)

Threat model, assets, actors, trust boundaries and scope: `THREAT_MODEL.md`. Three Apps were built through the headless Builder route with the login route of the Builder server (`builder_auth_summary()` in the BuildPlan, `builder_auth_create_material()` in the coordinator's stage, the material handed to `builder_execute_plan()`; `scripts/apps.R`): Visium + H&E with login (two accounts), PBMC with login (two other accounts) and Visium + H&E without login. Each App ran as a deployment would (`shiny::runApp()`, no test mode) in a process without CerebroNexus on its library path. HTTP probes used `curl --path-as-is`; browser tests used headless Chrome through CDP, recording every websocket frame and request. "Data terms" are 200 cell barcodes, 200 gene names and the dataset name of the CRB.

| Test | Visium login | PBMC login |
|---|---|---|
| E01 unauthenticated `GET /`: login form only, no Viewer UI, no data terms | pass | pass |
| E02 every private file (CRB, external image, credentials database, `viewer-auth.env`, `cerebro_config.rds`, `app.R`, release files) by direct URL and 11 path-traversal forms (`..`, `%2e%2e`, `%2f`, double encoding, backslash, via the `cerebro_www` and `shinymanager` prefixes): 61 requests | pass (400 x25, 404 x36, nothing served) | pass |
| E03 before login: websocket frames, inputs injected by the client (page, gene, selection), data-object URLs guessed with the pre-login session token | pass (no data terms; guesses HTTP 500) | pass |
| E04-E07b wrong password, empty password, empty username, SQL-like username, another account's password | pass (rejected, no data) | pass |
| E08 lockout or rate limit after 25 wrong passwords | none: about 0.8 s per attempt, then the right password works | none |
| E09 positive control: right password, Viewer opens, a gene is shown | pass | pass |
| E10 session data URLs (`/session/<token>/dataobj/...`: gene list, spatial image) fetched by another client without cookies while the session is open | 200 (capability URLs, by design) | 200 |
| E11 the login token of the post-login URL replayed by a second client while the first session is open | **fail**, see Findings 6 | **fail** |
| E12 logout: login form back, the session's data URLs 404, the token no longer valid, no data after logout | pass | pass |
| E13 inactivity timeout (copy with `timeout_minutes` 1; the Builder sets 15) | pass: login form after 60 s idle, data URLs 404 | - |
| E14 two concurrent sessions (alice, bob): own gene view, own Linked views selection, no request with the other's session token | pass: each shows its own gene and selection (A 25 cells, B 0), no cross-session request | - |
| E15 an account or token of the PBMC App on the Visium App | pass (rejected) | - |
| E16 credentials database at rest: tables encrypted, no username or password in the bytes, wrong key fails, passwords hashed | pass | - |
| E17 database key not in the App files | **fail** (by design): `viewer-auth.env` (mode 0600) in the App root, next to the database; no other file holds it | - |
| E18 no plaintext password in App, release or Builder work files | pass | pass |
| E19 no password, key or login token in the build log or App stdout/stderr | pass | pass |
| E20-E24b startup with `viewer-auth.env` mode 0644, a wrong key, the file removed, the file a symlink, the database removed | pass: each refuses with an explicit error (for example "viewer-auth.env has insecure permissions: 0644") | - |
| E24 key in the process environment, file removed | pass (starts, login works) | - |

App without login (E25): the Viewer opens for anyone who reaches the port (by design); the 39 private-file requests were all refused.

### F. Cell selection, cross-view mapping and sidecars

F1/F2 (`results/F_selection.csv`, `results/F_mapping.csv`, `scripts/F_selection.R`, variants in `scripts/F_variants.R`). Fixture: the package's `complete_viewer` (180 cells, UMAP/t-SNE, a monocle2 trajectory, six spatial sections of 20-60 cells, an immune repertoire for every cell: 122 TCR and 58 BCR cells). Variants, each built into its own App: as shipped; cells in random order with the repertoire rows shuffled; two cell IDs that differ only by letter case (`patient_a_cell_001` and `PATIENT_A_CELL_001`); repertoire removed for 60 cells; five repertoire rows for IDs that are not cells. Each App was started and loaded in headless Chrome. The checks then ran the Viewer server code of that App (`viewer/coordinated_views/config.R`, `bundle.R`, `viewer/clone_contract.R`) on its CRB: a Linked views View JSON for each predeclared set was written with the App's own `cv_config_prepare()` and opened with `cv_config_decode()` as the server does for "Open JSON"; the restored set, the selection indices sent to the browser and the server's "Table of selected cells" were compared with the set; per Linked views space, the cells the bundle code places (`cv_spatial_section_rows()`, `cv_clone_per_cell()`, projections) were compared with the source object.

| Set (per variant) | Restored set, indices and table equal the set |
|---|---|
| complete (180), partial (60), zero, one section (30), partial in reverse order | identical in all four variants that built (base, reordered, case IDs, immune part): 20 of 20 |
| one of two IDs that differ only by case | identical: exactly that cell, 2 of 2 |
| partial (40) plus three unknown IDs | the whole View JSON is rejected ("The configuration selects cells that are not in this data set."); the unknown IDs are not named and the 40 known cells are not restored: 4 of 4 |

| Variant | Mapping rows (set x space) | Viewer placed = truth | Coverage |
|---|---|---|---|
| base, reordered, immune part | 45 each | 45 | per space all / part / none as in the source |
| case IDs | 63 | 63 | |

The clone space shows one receptor class (TCR, the first present), so it covers 122 of 180 cells in the base fixture and 80 in the immune-part variant, as the source says. The variant with repertoire rows for IDs that are not cells does not build: the BuildPlan is held at Review ("A dataset capability still needs attention"), without naming the IDs.

F3, HDF5 and immune sidecars (`results/F_hdf5_end_to_end.csv`, `F_hdf5_storage.csv`, `F_hdf5_faults.csv`, `F_publish_faults_h5.csv`, `scripts/F_hdf5.R`).

- B with the HDF5 backend (`B_BACKEND=h5`), all six inputs: published, Viewer loaded, every expression value equal to the source (max abs diff 0), groups, projections, coordinates and images as with the embedded backend. The Builder passes no level, so the H5 is written with the `exportFromSeurat()` default, gzip level 0 (shuffle and deflate filters present; Visium 185 MB). The Builder has no compression setting; the package route `exportFromSeurat(h5_compression_level = 6)` gave 113 MB for Visium and max abs diff 0.
- Faults on copies of the Visium HDF5 App and of an App with an immune sidecar (`saveCerebro(immune_sidecar = "always")` + `createShinyApp()`, because the Builder writes `.immune.qs2` only from 100,000 repertoire rows):

| Sidecar | Fault | readCerebro | App |
|---|---|---|---|
| `.h5` | deleted / renamed | "The h5 expression sidecar is missing" | dataset not loaded |
| `.h5` | truncated to half | "HDF5. File accessibility. Unable to open file." | not loaded |
| `.h5` | replaced by another dataset's H5 | "The H5 cell names do not match CRB ..." | not loaded |
| `.h5` | replaced by a valid H5 with the same cells and genes, values x2 | **no error**; values differ | **loads and shows the changed values**, see Findings 8 |
| `.h5` | replaced by the level-6 H5 of the same data | accepted, values identical | loads |
| `.immune.qs2` | deleted / renamed | "The immune repertoire sidecar is missing" | not loaded |
| `.immune.qs2` | truncated / replaced by another valid repertoire | "The immune repertoire sidecar checksum does not match." | not loaded |

- C with HDF5 output (`C_BACKEND=h5`, 38 rows): the 36 cases of C give the same release after the fault and the same final release as with the embedded backend; the H5 is published and readable after every restore. Two cases were added: a byte appended to the staged v2 `.h5` is refused before publication ("The staged App copied content differs from frozen input", v1 kept); a byte appended to the published v1 `.h5` after v2 was planned is refused ("The release changed after Review; nothing was published.", the changed byte kept), as for the CRB (T4).

## After the security and sidecar fixes (33150d9d7)

Findings 6-8 were fixed on `builder/03_builder` in three local commits on top of `001c4d4dd` (not pushed when these runs were made): `c5462c264` `fix(viewer): start the Viewer only for the page's own session`, `58a604a0d` `fix(viewer): slow down repeated failed sign-ins`, `33150d9d7` `fix(crb): check the H5 sidecar against its recorded checksum`. `33150d9d7a957607ccf43a0296903e073be2408f` was installed into `env/rlib` in the same way (`results/install_33150d9d7.log`, `environment_33150d9d7.txt`); files of this run carry the suffix `_33150d9d7`.

- `c5462c264`: the page the provider renders for a login token's first use carries a one-time grant bound to that token (`inst/viewer/auth.R`); the Viewer server starts only in the session that returns the grant and was opened with the same token. Tests in `test-viewer-auth-runtime.R`: no start without a grant, with a made-up grant, with a grant for another token, and a grant is redeemed once.
- `58a604a0d`: failed sign-ins are counted per account and per client address (`REMOTE_ADDR`; behind a reverse proxy every client has the proxy's address, so the per-client count then acts for all users together). From the fifth failure a key waits 30 s, doubling up to 15 min; during a wait the password is not checked and the provider's usual "incorrect" message is shown. Tests with a fake clock, and through the provider's checker.
- `33150d9d7`: H5 exports (`exportFromSeurat()`, `export_core.R`) record the sidecar's MD5 in the expression-backend descriptor; `readCerebro()` and the Viewer (`.verifyRuntimeH5Checksum()` in `utility_functions.R`, a process-wide helper of `source_cache.R`) refuse a mismatch with "The h5 expression sidecar checksum does not match CRB '<file>'.". Each file is hashed once per process until its size or modification time changes. CRBs written before this record no checksum and are read as before. Tests in `test-h5-sidecar-checksum.R`, including one that every process-wide Viewer helper calls only process-wide helpers (a first version of the fix, `a7401ae9a`, missed that list, so generated H5 Apps did not load; its runs were discarded).
- Package tests (auth runtime, createShinyApp auth and HTTP privacy, Builder auth, H5 and demo-H5 suites, export core, Builder build, end-to-end and app bundle, generated-App immune pages), in a UTF-8 locale: all pass except the known baseline (`test-builder-build.R` "CRB read-back matches exact frozen artifact identity" and `test-builder-app-bundle.R` "App requests freeze spatial molecule sidecar identities", identical on `001c4d4dd`). In a non-UTF-8 locale `test-createShinyApp-auth.R` has 13 vignette text failures (an em dash), also identical on `001c4d4dd`.

| Run on 33150d9d7 | File | Result (001c4d4dd in brackets) |
|---|---|---|
| E, 40 rows | `E_security_33150d9d7.csv`, `E_evidence_33150d9d7/` | 37 pass, 1 fail (E17, unchanged by design), 2 info (E10) [33 pass, 3 fail, 2 info + 2 info (none)] |
| E08 lockout | | 25 wrong passwords, then the right password is refused; accepted after 32 s [no lockout] |
| E11 token replay | | the second client receives the login form and no Viewer message: 0 data terms in its frames, no dataset-load message [Viewer server started] |
| F3 H5 build, 6 inputs | `F_hdf5_end_to_end_33150d9d7.csv` | all published and loaded, every expression value equal; checksum verified at load in 0.33 s (Visium, 185 MB), 0.10 s (pbmc3k, 58 MB), 0.05 s (Xenium, 32 MB), < 0.01 s (PBMC) |
| F3 sidecar faults, 12 | `F_hdf5_faults_33150d9d7.csv` | all refused with an explicit error, including the same-IDs/changed-values H5 [loaded and shown] and the level-6 H5 of the same values (other bytes; accepted before) |
| C with HDF5 output, 38 | `F_publish_faults_h5_33150d9d7.csv` | 37 rows as before; T7 (byte appended to the published v1 H5 after v2 was planned): publication refused as before, and the kept v1 is now reported as unreadable (checksum) instead of being read |
| A, 20 | `A_malformed_inputs_33150d9d7.csv` | identical to 001c4d4dd |
| B smoke (Visium, PBMC Seurat, pbmc3k h5ad) | `B_end_to_end_33150d9d7.csv` | published, loaded, expression max abs diff 0, 0 group mismatches |
| C smoke (C00, C04, K3, K5, T1, T4; 9 rows) | `C_publish_faults_33150d9d7.csv` | identical to 001c4d4dd |
| D smoke (synthetic identity, rotate 90, rotate 90 + flip x, combined; 8 rows) | `D_spatial_transforms_33150d9d7.csv` | residuals identical |

E17 is left as designed: the Builder keeps writing the database key to `viewer-auth.env` (mode 0600) in the App; `THREAT_MODEL.md` now recommends supplying the key as `CEREBRO_AUTH_PASSPHRASE` to the service and removing the file on shared hosts.

## Input provenance

`results/inputs_provenance.csv` lists every input with its source URL, version, size, SHA-256, licence as the provider states it (and where that was read), and how to retrieve it:

| Input | Licence |
|---|---|
| 10x Xenium mouse brain CTX+HP outs bundle (3,479,544,713 bytes, SHA-256 `da383f55...b71f`) | CC BY 4.0, stated on the 10x Genomics dataset page |
| SeuratData `stxBrain` anterior1 (`stxBrain.SeuratData` 0.1.2) | CC BY 4.0, stated in the package DESCRIPTION |
| cellxgene `pbmc3k.h5ad` (SHA-256 `0db367b9...e038`) | not stated for the file; the cellxgene repository is MIT; the terms of the underlying 10x PBMC 3k data are not stated there |
| CerebroNexus `pbmc_seurat.rds`, `pbmc_SCE.rds` | package licence MIT; origin of the 80 cells not documented |
| arrow and `complete_viewer` fixtures | package licence MIT; synthetic |

No versioned archive identifier (for example a Zenodo DOI) exists yet for these inputs or for the derived files.

## Limits

- The Builder's browser UI was not driven; the headless route calls the same functions its server and tests call, in one R process (C uses child processes for the kills). The Viewer was driven in a real headless Chrome.
- D measures what the Viewer renders against what the Builder preview defines. The preview itself was not rendered: its transform was transcribed from `builder-spatial-canvas.js`. The "predicted" column transcribes the Viewer's `drawImage()`; it matched the measured residual wherever the image was in view, except the origin-centred combined case (340 predicted vs 268 measured).
- Viewer interactions that change the alignment after publication (the Viewer's own image controls) were not exercised.
- Xenium and Visium were run with every cell but with one tissue section each. The multi-section check used the package's synthetic `complete_viewer` fixture (real section structure, synthetic landmark pictures).
- Runtimes are from one run on a laptop; C and B partly overlapped with D runs.
- E tested one host over loopback HTTP. TLS, reverse proxies and their logs, HTTP headers, multi-user hosting and the OS-level actor (another local user) were not exercised beyond file modes; see `THREAT_MODEL.md` for the scope. The Apps' upload UI was off. Per-dataset authorization does not exist (login is per App) and was not tested. The timeout was tested with a 1-minute copy, not the Builder's 15 minutes.
- E11 was stopped at recording what the second client receives at session start; no attempt was made to request further outputs through it.
- F1/F2 ran the Viewer's server functions on the App's own code and CRB, and loaded every App in headless Chrome, but did not drive the page's "Open JSON" file input or read the coverage readout from the page; the panel order of a View JSON is not used by the mapping code and was not varied. The "duplicate display labels" case was taken as IDs that differ only by case.
- F3 compressed H5 was made with the package route, since the Builder has no compression setting; the immune sidecar App was made with `createShinyApp()`, since the Builder writes no immune sidecar below 100,000 repertoire rows. The Immune repertoire page itself was not opened in the browser; the App was loaded on the Gene expression page.

## Supplementary Figures S11 and S12

`scripts/figures.R` draws both from `results/` (nothing is rerun) into `figures/` (PDF, PNG at 600 dpi, SVG twin and `screenshot-qa.csv` in `figures/qa/`). Run it from the repository root with your own R, then the rule check:

```bash
Rscript topics/builder_validation/scripts/figures.R
Rscript topics/interface_figures/scripts/check_figures.R topics/builder_validation/figures
```

Panel S11b uses `results/D_captures_figS11_fill/`: the identity, rotate 90, flip x and scale 0.6 arrow cases rerun on 33150d9d7 with the display variant of the arrow cells (`D_ARROW_FILL=1`: a 30-px grid filling the arrow at least 14 px inside its outline, plus one cell just inside the tip so the Viewer's fitted view holds the whole arrow, labelled tail, shaft or head) and point size 18 (`D_ARROW_FILL=1 D_POINT_SIZE=18 D_DATA=D_figS11_fill D_CAPTURES=D_captures_figS11_fill D_ARROW=identity,rotate_90,flip_x,scale_0.6 Rscript scripts/D_spatial_transforms.R arrow`; log `results/logs/D_arrow_figS11_fill.log`). Environment: `results/environment_figS11.txt`. Display captures are not measured: large points cover the corner squares, so the residuals shown are from `D_arrow_001c4d4dd.csv`. The Viewer drew the regions in its default palette (the `group_colors` set on the object were not carried through the Builder). S12 shows each row on the last revision it ran on (33150d9d7 where run, otherwise 001c4d4dd). The captions are in `supplement.md` of the manuscript draft.
