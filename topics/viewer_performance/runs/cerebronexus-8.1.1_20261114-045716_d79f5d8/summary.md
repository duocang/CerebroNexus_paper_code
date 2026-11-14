# Viewer performance: CerebroNexus 8.1.1

- Run: `cerebronexus-8.1.1_20261114-045716_d79f5d8`
- Revision: d79f5d8bb743287eb9325686ce697393964596be (`d79f5d8bb743`)
- Rounds: 5; sessions: 95, failed twice: 0
- Datasets: 1m, ren, cosmx, example, demo_trekker
- Machine: NUIOI; Microsoft Windows 11 Pro 10.0.26300; 12th Gen Intel(R) Core(TM) i9-12900K
- R version 4.6.1 (2026-06-24 ucrt); Chrome/157.0.8103.52, drawn by ANGLE (NVIDIA, NVIDIA GeForce RTX 4060 (0x00002882) Direct3D11 vs_5_0 ps_5_0, D3D11); webgpu
- Measured together with `cerebronexus-8.0.0_20261114-045716_24bbc02` (this run is the candidate), session by session in turn
- Host before the sessions: median 3.2 % CPU, at most 6.7 %; waited 9 s in all

## Problems

- not finished in every round: extra_material.content, markerGenes.table

## Pages and actions

Medians over the rounds that finished. Visual = click to the last frame that changes (the KPI); range = fastest and slowest round.
On the `first_start` and `first_plot` rows both times run from Chrome's navigation to the Viewer instead of from a click: First plot = to the first frame that shows the projection, Visual = to the last frame that changes. `first_start`: the server's cache directory was emptied before the session; `first_plot`: it held what earlier sessions left.

| Page | Visit | Dataset | Status | Visual (ms) | First plot (ms) | Range (ms) | Server busy (ms) | Trail (ms) | Largest msg (MB) | Loader (ms) | R peak (MiB) | Chrome peak (MiB) | Value |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| loadData | initial | 1m | ok | 37 | - | 23-43 | 5,337 | 4,731 | <0.1 | 0 | 879 | 581 |  |
| loadData.switch | action | 1m | ok | 149 | - | 15-796 | 3,808 | 2,321 | <0.1 | 145 | 770 | 619 | Demo dataset |
| loadData.switch_back | action | 1m | ok | 163 | - | 13-317 | 1,228 | 325 | <0.1 | 152 | 835 | 623 | Second dataset |
| overview | cold | 1m | ok | 391 | - | 265-512 | 867 | 0 | <0.1 | 234 | 749 | 849 |  |
| overview | first_start | 1m | ok | 3,542 | 3,542 | 3,498-3,577 | 10,837 | 7,234 | <0.1 | 1,048 | 1,078 | 822 |  |
| overview | first_plot | 1m | ok | 2,056 | 2,056 | 1,932-2,295 | 9,477 | 8,907 | <0.1 | 883 | 735 | 816 |  |
| overview.colour_by | action | 1m | ok | 138 | - | 133-159 | 29 | 0 | <0.1 | 0 | 767 | 848 | sample |
| overview.zoom | action | 1m | ok | 7 | - | 6-103 | 0 | 0 | <0.1 | 0 | 767 | 784 | in |
| overview.lasso | action | 1m | ok | 90 | - | 87-275 | 250 | 0 | 0.2 | 0 | 775 | 775 | middle 40% |
| coordinated_views | cold | 1m | ok | 476 | - | 436-865 | 737 | 0 | <0.1 | 452 | 756 | 838 |  |
| coordinated_views.colour_by | action | 1m | ok | 9 | - | 7-11 | 78 | 0 | 1.3 | 0 | 734 | 861 | sample |
| groups | cold | 1m | ok | 290 | - | 276-367 | 428 | 0 | <0.1 | 125 | 668 | 611 |  |
| groups.group | action | 1m | ok | 134 | - | 11-144 | 257 | 0 | <0.1 | 0 | 767 | 620 | seurat_clusters |
| groups.plot_type | action | 1m | ok | 8 | - | 7-104 | 0 | 0 | <0.1 | 0 | 690 | 702 | Sankey plot |
| groups.percent | action | 1m | ok | 7 | - | 6-194 | 0 | 0 | <0.1 | 0 | 690 | 657 | on |
| geneExpression | cold | 1m | ok | 426 | - | 412-611 | 1,122 | 0 | <0.1 | 276 | 748 | 882 |  |
| geneExpression.gene | action | 1m | ok | 706 | - | 282-927 | 1,112 | 66 | 5.5 | 0 | 886 | 1,034 | 0610007P14Rik |
| geneExpression.genes12 | action | 1m | ok | 784 | - | 620-902 | 658 | 0 | 10.5 | 0 | 963 | 946 | 0610007P14Rik 0610009B22Rik 0610009L18Rik 0610009O20Rik 0610010F05Rik 0610010K14Rik 0610011F06Rik 0610012D04Rik 0610012G03Rik 0610025J13Rik 0610030E20Rik 0610031O16Rik |
| trajectory | cold | 1m | ok | 727 | - | 707-860 | 1,203 | 0 | 5.1 | 449 | 914 | 879 |  |
| trajectory.colour_by | action | 1m | ok | 10 | - | 10-226 | 314 | 0 | 5.1 | 0 | 904 | 970 | state |
| color_management | cold | 1m | ok | 351 | - | 229-409 | 265 | 0 | <0.1 | 218 | 578 | 598 |  |
| geneIdConversion | cold | 1m | ok | 466 | - | 407-529 | 433 | 0 | 0.3 | 342 | 596 | 615 |  |
| about | cold | 1m | ok | 126 | - | 114-132 | 186 | 0 | <0.1 | 0 | 531 | 587 |  |
| immune_repertoire | cold | ren | ok | 21,053 | - | 20,656-21,116 | 21,045 | 0 | 2.6 | 20,391 | 1,907 | 769 |  |
| immune_repertoire.tab | action | ren | ok | 1,032 | - | 656-1,444 | 1,671 | 0 | 0.2 | 0 | 2,088 | 1,002 | Abundance |
| hla_tcr_motifs | cold | ren | ok | 572 | - | 528-617 | 808 | 2,161 | <0.1 | 406 | 696 | 652 |  |
| hla_tcr_motifs.colour_by | action | ren | ok | 11 | - | 9-12 | 0 | 0 | <0.1 | 0 | 686 | 655 | major_type |
| extra_material | cold | ren | ok | 481 | - | 344-504 | 559 | 2,491 | <0.1 | 374 | 691 | 648 |  |
| extra_material.content | action | ren | unavailable (0/5 ok) | - | - | - | - | - | - | - | - | - |  |
| spatial | cold | cosmx | ok | 805 | - | 710-921 | 1,125 | 0 | 0.1 | 334 | 981 | 739 |  |
| spatial.section | action | cosmx | ok | 272 | - | 261-322 | 405 | 0 | 0.1 | 0 | 955 | 752 | spatial_projection_sample=Lung5_Rep2 |
| markerGenes | cold | example | ok | 393 | - | 252-465 | 397 | 0 | <0.1 | 60 | 540 | 621 |  |
| markerGenes.table | action | example | unavailable (0/5 ok) | - | - | - | - | - | - | - | - | - |  |
| mostExpressedGenes | cold | example | ok | 416 | - | 325-482 | 459 | 9 | <0.1 | 62 | 573 | 615 |  |
| mostExpressedGenes.group | action | example | ok | 168 | - | 146-271 | 276 | 0 | <0.1 | 0 | 572 | 628 | seurat_clusters |
| enrichedPathways | cold | example | ok | 439 | - | 419-634 | 470 | 28 | <0.1 | 56 | 565 | 627 |  |
| enrichedPathways.table | action | example | ok | 283 | - | 164-303 | 0 | 0 | <0.1 | 0 | 573 | 638 | enriched_pathways_selected_method=cerebro_GSVA |
| trekker | cold | demo_trekker | ok | 127 | - | 114-314 | 2,788 | 2,641 | 0.1 | 0 | 506 | 629 |  |
| trekker.colour_by | action | demo_trekker | ok | 11 | - | 8-11 | 0 | 0 | 0.1 | 0 | 446 | 626 | cluster |

## Memory per dataset

Largest peak of any session on the dataset (R server tree, Chrome tree) and the median server start.

| Dataset | Sessions | R peak (MiB) | Chrome peak (MiB) | Server start (s) |
|---|---|---|---|---|
| 1m | 55 | 1,082 | 1,048 | 0.6 |
| ren | 15 | 2,089 | 1,006 | 0.6 |
| cosmx | 5 | 982 | 767 | 0.6 |
| example | 15 | 574 | 643 | 0.6 |
| demo_trekker | 5 | 554 | 647 | 0.6 |

## Server steps

The R work behind the pages, without a browser (one fresh R process per dataset and round).

| Dataset | Step | Time (ms) | Status |
|---|---|---|---|
| 1m | read_crb | 2,290 | ok |
| 1m | cell_names | 3,470 | ok |
| 1m | metadata | 0 | ok |
| 1m | projection | 0 | ok |
| 1m | gene_row_first | 50 | ok |
| 1m | gene_row_repeat | 60 | ok |
| 1m | gene_block_12 | 10 | ok |
| 1m | mean_expression_12 | 630 | ok |
| 1m | cells_10pct_genes_12 | 270 | ok |
| 1m | linked_bundle_build | 550 | ok |
| 1m | linked_bundle_json | 4,700 | ok |
| ren | read_crb | 1,780 | ok |
| ren | cell_names | 3,210 | ok |
| ren | metadata | 0 | ok |
| ren | projection | 0 | ok |
| ren | gene_row_first | 30 | ok |
| ren | gene_row_repeat | 50 | ok |
| ren | gene_block_12 | 20 | ok |
| ren | mean_expression_12 | 1,050 | ok |
| ren | cells_10pct_genes_12 | 220 | ok |
| ren | linked_bundle_build | 5,590 | ok |
| ren | linked_bundle_json | 5,720 | ok |
| cosmx | read_crb | 860 | ok |
| cosmx | cell_names | 2,610 | ok |
| cosmx | metadata | 0 | ok |
| cosmx | projection | 0 | ok |
| cosmx | gene_row_first | 20 | ok |
| cosmx | gene_row_repeat | 30 | ok |
| cosmx | gene_block_12 | 20 | ok |
| cosmx | mean_expression_12 | 290 | ok |
| cosmx | cells_10pct_genes_12 | 180 | ok |
| cosmx | linked_bundle_build | 1,060 | ok |
| cosmx | linked_bundle_json | 4,530 | ok |
| example | read_crb | 170 | ok |
| example | cell_names | 400 | ok |
| example | metadata | 0 | ok |
| example | projection | 0 | ok |
| example | gene_row_first | 0 | ok |
| example | gene_row_repeat | 10 | ok |
| example | gene_block_12 | 0 | ok |
| example | mean_expression_12 | 0 | ok |
| example | cells_10pct_genes_12 | 0 | ok |
| example | linked_bundle_build | 0 | ok |
| example | linked_bundle_json | 20 | ok |
| demo_trekker | read_crb | 170 | ok |
| demo_trekker | cell_names | 390 | ok |
| demo_trekker | metadata | 0 | ok |
| demo_trekker | projection | 0 | ok |
| demo_trekker | gene_row_first | 0 | ok |
| demo_trekker | gene_row_repeat | 20 | ok |
| demo_trekker | gene_block_12 | 0 | ok |
| demo_trekker | mean_expression_12 | 20 | ok |
| demo_trekker | cells_10pct_genes_12 | 0 | ok |
| demo_trekker | linked_bundle_build | 0 | ok |
| demo_trekker | linked_bundle_json | 40 | ok |

