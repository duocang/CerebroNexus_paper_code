# Viewer performance: CerebroNexus 8.0.1

- Run: `cerebronexus-8.0.1_20261113-002855_e082d38_partial`
- Revision: e082d38e9 (`e082d38e9a95`)
- Rounds: 2; sessions: 8, failed twice: 0
- Datasets: 1m, example
- Machine: NUIOI; Microsoft Windows 11 专业版 10.0.26300; 12th Gen Intel(R) Core(TM) i9-12900K
- R version 4.6.1 (2026-06-24 ucrt); Chrome/157.0.8103.52, drawn by ANGLE (NVIDIA, NVIDIA GeForce RTX 4060 (0x00002882) Direct3D11 vs_5_0 ps_5_0, D3D11); webgpu
- Measured together with `cerebronexus-8.0.1_20261113-002855_6a67f6f_partial` (this run is the candidate), session by session in turn
- Host before the sessions: median 5.4 % CPU, at most 9.8 %; waited 7 s in all

## Problems

- not finished in every round: markerGenes.table

## Pages and actions

Medians over the rounds that finished. Visual = click to the last frame that changes (the KPI); range = fastest and slowest round.
On the `first_start` and `first_plot` rows both times run from Chrome's navigation to the Viewer instead of from a click: First plot = to the first frame that shows the projection, Visual = to the last frame that changes. `first_start`: the server's cache directory was emptied before the session; `first_plot`: it held what earlier sessions left.

| Page | Visit | Dataset | Status | Visual (ms) | First plot (ms) | Range (ms) | Server busy (ms) | Trail (ms) | Largest msg (MB) | Loader (ms) | R peak (MiB) | Chrome peak (MiB) | Value |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| overview | cold | 1m | ok | 516 | - | 380-652 | 950 | 0 | <0.1 | 271 | 744 | 866 |  |
| overview | first_start | 1m | ok | 3,787 | 4,198 | 3,592-3,982 | 10,913 | 6,284 | <0.1 | 1,510 | 932 | 813 |  |
| overview | first_plot | 1m | ok | 2,393 | 2,393 | 2,327-2,459 | 9,396 | 8,320 | <0.1 | 1,344 | 736 | 823 |  |
| overview.colour_by | action | 1m | ok | 189 | - | 133-246 | 1,008 | 518 | <0.1 | 0 | 761 | 874 | sample |
| overview.zoom | action | 1m | ok | 57 | - | 8-106 | 0 | 893 | <0.1 | 0 | 761 | 850 | in |
| overview.lasso | action | 1m | ok | 171 | - | 94-248 | 245 | 0 | 0.2 | 0 | 768 | 791 | middle 40% |
| markerGenes | cold | example | ok | 375 | - | 267-484 | 2,148 | 895 | <0.1 | 76 | 550 | 629 |  |
| markerGenes.table | action | example | unavailable (0/2 ok) | - | - | - | - | - | - | - | - | - |  |

## Memory per dataset

Largest peak of any session on the dataset (R server tree, Chrome tree) and the median server start.

| Dataset | Sessions | R peak (MiB) | Chrome peak (MiB) | Server start (s) |
|---|---|---|---|---|
| 1m | 6 | 1,061 | 884 | 0.8 |
| example | 2 | 553 | 633 | 0.6 |

## Server steps

The R work behind the pages, without a browser (one fresh R process per dataset and round).

| Dataset | Step | Time (ms) | Status |
|---|---|---|---|
| 1m | read_crb | 2,540 | ok |
| 1m | cell_names | 3,725 | ok |
| 1m | metadata | 0 | ok |
| 1m | projection | 0 | ok |
| 1m | gene_row_first | 45 | ok |
| 1m | gene_row_repeat | 50 | ok |
| 1m | gene_block_12 | 15 | ok |
| 1m | mean_expression_12 | 630 | ok |
| 1m | cells_10pct_genes_12 | 285 | ok |
| 1m | linked_bundle_build | 600 | ok |
| 1m | linked_bundle_json | 4,635 | ok |
| example | read_crb | 30 | ok |
| example | cell_names | 425 | ok |
| example | metadata | 10 | ok |
| example | projection | 0 | ok |
| example | gene_row_first | 0 | ok |
| example | gene_row_repeat | 15 | ok |
| example | gene_block_12 | 0 | ok |
| example | mean_expression_12 | 10 | ok |
| example | cells_10pct_genes_12 | 0 | ok |
| example | linked_bundle_build | 140 | ok |
| example | linked_bundle_json | 20 | ok |

