# Builder builds from a SpatialData zip and a CITE-seq MuData file

Run on 2026-11-13 (Ubuntu 24.04 under WSL2, R 4.6.1) with CerebroNexus 8.3.0, the revision pinned in `../cerebronexus.pin`. The results of the earlier run (2026-10-21, CerebroNexus 6.0.0, macOS arm64) are in Git history of this folder; the byte and SHA-256 values below replace them. This archive backs the manuscript sentence in "Capability profiling and frozen build plans" that Builder built CRBs from the Visium SpatialData sample store packed as a `.zip` (6,484 spots in two sections) and from a CITE-seq MuData file (411 cells, 29 antibody features). Both counts were reproduced and are read back from the written `.crb` files, not from the source objects.

## Files here

| File | What it is |
|---|---|
| `install_pin.R` | Installs the revision of `../cerebronexus.pin` from `git archive` into a library and stamps its commit on the installation |
| `build_crbs.R` | The build script: Builder import, inspect, freeze BuildPlan, execute BuildPlan, then read the CRB back |
| `data/build.log` | Full console output of the recorded run, including `sessionInfo()` and the exit status |
| `data/build-summary.csv` | Input and output checksums and the counts read from each CRB |

## Software

- CerebroNexus 8.3.0, branch `integration/8.3.0`, commit `e927cbf180fb1a50cf783245ab580e83a1334764` ("fix(cerebro_io): a sidecar the export verified is also kept for the next process"), the revision in `../cerebronexus.pin`. That commit exists only in a local clone, so `install_pin.R` installs it from `git archive` and writes the commit into the installation (`CerebroNexus/PIN_COMMIT`). The script reads the version from the installed package and from the pin, records both in the log and in `data/build-summary.csv`, and stops only when the installed commit is not the pinned one; it does not test for a version number.
- Both builds use the embedded expression backend (the H5 and BPCells paths are not exercised).
- The Builder runtime is read from the installed package: the list of files is taken from the `source()` calls of the installed `inst/builder/app.R` (UI, server and session files left out) and the HLA core from the package namespace, so the script does not depend on the file layout of any source tree. All other packages come from the user library of the run (`Seurat` 5.6.0, `SeuratObject` 5.4.0, `arrow` 26.0.0, `rhdf5` 2.56.1); `arrow` is needed to open SpatialData `.zip` sources.

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

To rerun, from this folder (the CerebroNexus checkout holding the pinned commit and the two downloaded inputs are needed):

```sh
Rscript --vanilla install_pin.R <CerebroNexus checkout> <library>
Rscript --vanilla build_crbs.R <library> <folder with the two inputs> <output folder>
```

## Results

| Input | CRB | Bytes | SHA-256 | Cells/spots | Features | `prot:` features | Spatial sections | Projection |
|---|---|---|---|---|---|---|---|---|
| `visium_spatialdata_0.7.1.zip` | `visium_spatialdata.crb` | 95,842,540 | `1968cda3cc4aa2e0dd5cc33a4958988da88bdf1e2f77300901e719850395b78d` | 6,484 | 31,053 | 0 | 2 (ST8059048, ST8059050) | `spatial_xy` |
| `minipbcite.h5mu` | `minipbcite.crb` | 5,357,958 | `9f5fca7cb9ae24b5335b60cf486525d5d1d7181df432a254433719a6c544a621` | 411 | 56 (27 RNA + 29 antibody) | 29 | 0 | `UMAP` |

The same inputs built twice more in the same session produced byte-identical CRBs (same SHA-256); the CRB carries its export date (2026-11-13), so a build on another day may differ in bytes (not tested). The CRBs are not kept in this repository; the Visium tissue pictures live beside its CRB in the release and are not part of the CRB hash.

## Limits

- The Builder's browser UI was not driven; the run calls the Builder's own import, plan and execute functions in one R process, without the isolated worker process and the publication step of the App.
- The minipbcite read logs the same two warnings from Seurat as before ("Feature names cannot have underscores" and "No layers found matching search pattern provided"); both are kept in `data/build.log`. The antibody features keep their source names (for example `prot:CD3_TotalSeqB`).
- The generated Viewer App for the Visium release was not opened.
