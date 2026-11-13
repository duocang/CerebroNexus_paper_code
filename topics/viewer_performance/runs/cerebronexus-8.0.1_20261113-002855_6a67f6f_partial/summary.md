# Viewer performance: CerebroNexus 8.0.1

- Run: `cerebronexus-8.0.1_20261113-002855_6a67f6f_partial`
- Revision: 6a67f6fcd (`6a67f6fcda05`)
- Rounds: 2; sessions: 8, failed twice: 0
- Datasets: 1m, example
- Machine: NUIOI; Microsoft Windows 11 专业版 10.0.26300; 12th Gen Intel(R) Core(TM) i9-12900K
- R version 4.6.1 (2026-06-24 ucrt); Chrome/157.0.8103.52, drawn by ANGLE (NVIDIA, NVIDIA GeForce RTX 4060 (0x00002882) Direct3D11 vs_5_0 ps_5_0, D3D11); webgpu
- Measured together with `cerebronexus-8.0.1_20261113-002855_e082d38_partial` (this run is the baseline), session by session in turn
- Host before the sessions: median 5.6 % CPU, at most 7.7 %; waited 3 s in all

## Problems

- not finished in every round: markerGenes.table

## Pages and actions

Medians over the rounds that finished. Visual = click to the last frame that changes (the KPI); range = fastest and slowest round.
On the `first_start` and `first_plot` rows both times run from Chrome's navigation to the Viewer instead of from a click: First plot = to the first frame that shows the projection, Visual = to the last frame that changes. `first_start`: the server's cache directory was emptied before the session; `first_plot`: it held what earlier sessions left.

| Page | Visit | Dataset | Status | Visual (ms) | First plot (ms) | Range (ms) | Server busy (ms) | Trail (ms) | Largest msg (MB) | Loader (ms) | R peak (MiB) | Chrome peak (MiB) | Value |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| overview | cold | 1m | ok | 673 | - | 438-908 | 1,315 | 2,680 | <0.1 | 290 | 634 | 858 |  |
| overview | first_start | 1m | ok | 2,450 | 2,659 | 2,215-2,685 | 3,405 | 8 | <0.1 | 1,382 | 896 | 827 |  |
| overview | first_plot | 1m | ok | 2,249 | 2,652 | 2,082-2,415 | 3,313 | 7 | <0.1 | 1,304 | 927 | 834 |  |
| overview.colour_by | action | 1m | ok | 179 | - | 170-188 | 79 | 0 | <0.1 | 0 | 653 | 824 | sample |
| overview.zoom | action | 1m | ok | 60 | - | 8-112 | 0 | 0 | <0.1 | 0 | 653 | 828 | in |
| overview.lasso | action | 1m | ok | 213 | - | 94-333 | 310 | 0 | 0.2 | 0 | 655 | 874 | middle 40% |
| markerGenes | cold | example | ok | 266 | - | 221-310 | 410 | 0 | <0.1 | 0 | 404 | 645 |  |
| markerGenes.table | action | example | unavailable (0/2 ok) | - | - | - | - | - | - | - | - | - |  |

## Memory per dataset

Largest peak of any session on the dataset (R server tree, Chrome tree) and the median server start.

| Dataset | Sessions | R peak (MiB) | Chrome peak (MiB) | Server start (s) |
|---|---|---|---|---|
| 1m | 6 | 927 | 880 | 5.8 |
| example | 2 | 409 | 654 | 2.9 |

## Server steps

The R work behind the pages, without a browser (one fresh R process per dataset and round).

| Dataset | Step | Time (ms) | Status |
|---|---|---|---|
| 1m | read_crb | 2,875 | ok |
| 1m | cell_names | 2,835 | ok |
| 1m | metadata | 0 | ok |
| 1m | projection | 0 | ok |
| 1m | gene_row_first | 60 | ok |
| 1m | gene_row_repeat | 55 | ok |
| 1m | gene_block_12 | 20 | ok |
| 1m | mean_expression_12 | 1,165 | ok |
| 1m | cells_10pct_genes_12 | 310 | ok |
| 1m | linked_bundle_build | 675 | ok |
| 1m | linked_bundle_json | 5,580 | ok |
| example | read_crb | 35 | ok |
| example | cell_names | 0 | ok |
| example | metadata | 0 | ok |
| example | projection | 0 | ok |
| example | gene_row_first | 0 | ok |
| example | gene_row_repeat | 15 | ok |
| example | gene_block_12 | 0 | ok |
| example | mean_expression_12 | 5 | ok |
| example | cells_10pct_genes_12 | 0 | ok |
| example | linked_bundle_build | 0 | ok |
| example | linked_bundle_json | 5 | ok |

