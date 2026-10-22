# Builder builds from a SpatialData zip and a CITE-seq MuData file

Run on 2026-10-21 (macOS arm64, R 4.5.0). This archive backs the manuscript sentence in "Capability profiling and frozen build plans" that Builder built CRBs from the Visium SpatialData sample store packed as a `.zip` (6,484 spots in two sections) and from a CITE-seq MuData file (411 cells, 29 antibody features). Both counts were reproduced and are read back from the written `.crb` files, not from the source objects.

## Files here

| File | What it is |
|---|---|
| `build_crbs.R` | The build script: Builder import, inspect, freeze BuildPlan, execute BuildPlan, then read the CRB back |
| `data/build.log` | Full console output of the recorded run, including `sessionInfo()` and the exit status |
| `data/build-summary.csv` | Input and output checksums and the counts read from each CRB |

## Software

- CerebroNexus 6.0.0 from branch `feat/multi-format-on-builder`, commit `27ac995e9` ("chore: bump version to 6.0.0"; full hash in `data/build.log`). At the time of the run the `v6.0.0` tag was not yet published, and the release was expected to also contain the H5 gzip-level-0 default and BPCells removal (mihem/CerebroNexus#209, #212). Neither change is exercised here: both builds use the embedded expression backend.
- The package was installed with `R CMD INSTALL` into a separate library , so the run does not use the 5.1.3 installation in the user library. All other packages come from the user library; `arrow` 25.0.1 was installed for this run because Builder requires it to open SpatialData `.zip` sources.

## Inputs

| Dataset | URL | File | Bytes | SHA-256 |
|---|---|---|---|---|
| Visium SpatialData sample store (two mouse brain sections) | https://s3.embl.de/spatialdata/spatialdata-sandbox/visium_spatialdata_0.7.1.zip | `visium_spatialdata_0.7.1.zip` | 68,220,724 | `aabaabe06cdaf41472d8718eeba2fb44cf516a1952b63165cb408b1f4f222a3b` |
| minipbcite CITE-seq MuData (muon example) | https://github.com/gtca/h5xx-datasets/raw/main/datasets/minipbcite.h5mu | `minipbcite.h5mu` | 17,151,496 | `44b665aeb174acfa585d0775ee926c74219a9a68f0bfb66c5a9aad9f5da12167` |

The SpatialData bucket also publishes `visium_spatialdata_0.7.1.zip.checksum` with the value `2096212877`. The older address `spatialdata-sandbox/visium.zip` no longer exists (HTTP 404 `NoSuchKey`), so the 0.7.1 store is the one used here.

## Procedure

`build_crbs.R` loads the installed package and sources the Builder runtime from `system.file("builder", package = "CerebroNexus")` in the order `inst/builder/app.R` uses, leaving out the UI and server files. For each input it then does what the Builder's import handler (`inst/builder/server/imports.R`) does after a file is dropped in, and what Review and Build do after that:

1. `builder_seurat_file_adapter()` and `builder_adapter_inspect()` open the file with the Builder's registered reader ("SpatialData (zip)" or "h5mu").
2. `builder_default_settings()` and `builder_recommend_metadata()` give the Configure defaults; tissue pictures that the source brings are placed with `builder_source_image_settings()`.
3. `builder_snapshot_seurat()`, `builder_freeze_plan()` and `builder_execute_plan()` freeze and execute the BuildPlan.
4. The written CRB is reopened with `readCerebro()` to count cells, features, `prot:` features and spatial sections, and hashed.

Choices that differ from untouched defaults, each one a choice an author makes on the Configure or Build page:

- minipbcite: organism set to `hg` (human PBMCs); the file names no organism and the Builder does not freeze a plan without one.
- Visium: output "CRB files + Viewer App", because the Builder stores source tissue pictures next to the CRB and only allows that with a generated App. The CRB recorded here is the one in that release.
- Both: expression backend `embedded`; no optional analyses.

To rerun, from this folder (install CerebroNexus 6.0.0 into a library first, for example `R CMD INSTALL --library=<lib> <CerebroNexus checkout>`, and download the two inputs):

```sh
Rscript --vanilla build_crbs.R <library with CerebroNexus 6.0.0> <folder with the two inputs> <output folder>
```

## Results

| Input | CRB | Bytes | SHA-256 | Cells/spots | Features | `prot:` features | Spatial sections | Projection |
|---|---|---|---|---|---|---|---|---|
| `visium_spatialdata_0.7.1.zip` | `visium_spatialdata.crb` | 95,765,691 | `7794eeec83188d76505ad65a8340b64f2a6650076f9be0d693d5115c946c4123` | 6,484 | 31,053 | 0 | 2 (ST8059048, ST8059050) | `spatial_xy` |
| `minipbcite.h5mu` | `minipbcite.crb` | 5,529,732 | `79275e909544d2e50f8dacf63a8ecf943f899aa8dd347496139ab06bdc68a8a9` | 411 | 56 (27 RNA + 29 antibody) | 29 | 0 | `UMAP` |

An earlier trial build of each input on the same day produced byte-identical CRBs (same SHA-256). The CRBs are not kept in this repository; the Visium tissue pictures live beside its CRB in the release and are not part of the CRB hash.

## Limits

- The Builder's browser UI was not driven; the run calls the Builder's own import, plan and execute functions in one R process, without the isolated worker process and the publication step of the App.
- The minipbcite read logs two warnings from Seurat ("Feature names cannot have underscores" and "No layers found matching search pattern provided"); both are kept in `data/build.log`. The antibody features keep their source names (for example `prot:CD3_TotalSeqB`).
- The generated Viewer App for the Visium release was not opened.
