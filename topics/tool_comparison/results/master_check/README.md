# Start to first plot on CerebroNexus master

A side check outside the pre-registered study (it adds no Deviation entry and changes no table): CerebroNexus master `7b1cc488` (5.3.1, after #215) on the E18 first 500,000 cells, embedded CRB and uncompressed H5 sidecar, one build per configuration and two starts each, measured exactly as in Task 3 (`scripts/run/harness.py`: ready = process start to first HTTP 200, first plot = browser navigation to the first accepted frame of `#cv-cv-a` after clicking Projection; same ink rule as D11).

Differences from the Task 3 runs of 6.0.0 (`27ac995e`): master has no `convertH5adToCerebro`, so the CRB is built from the tier `.h5ad` through anndataR -> SingleCellExperiment -> Seurat -> `exportFromSeurat(expression_matrix_mode = "embedded" | "h5", h5_compression_level = 0L)` (`scripts/run/tools/cerebronexus_master_build.R`); the Viewer is master's (`launchCerebro` has no expression_matrix_* arguments, the sidecar next to the CRB is found by the viewer). The package is installed in `data/builds/rlib_master` (`scripts/setup/setup_r_master.R`), the 6.0.0 install in `env/rlib` is untouched.

`start_to_first_plot.csv` holds the rows (a 10,000-cell pilot and the 500,000-cell runs), `logs/` the build and server logs and the frame of every start. Run with `python scripts/run/master_first_plot.py <tier> [starts]`.
