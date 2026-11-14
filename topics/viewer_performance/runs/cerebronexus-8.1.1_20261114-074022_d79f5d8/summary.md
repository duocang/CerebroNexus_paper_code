# Viewer performance: CerebroNexus 8.1.1

- Run: `cerebronexus-8.1.1_20261114-074022_d79f5d8`
- Revision: d79f5d8bb743287eb9325686ce697393964596be (`d79f5d8bb743`)
- Rounds: 5; sessions: 95, failed twice: 0
- Datasets: 1m, ren, cosmx, example, demo_trekker
- Machine: NUIOI; Microsoft Windows 11 Pro 10.0.26300; 12th Gen Intel(R) Core(TM) i9-12900K
- R version 4.6.1 (2026-06-24 ucrt); Chrome/157.0.8103.52, drawn by ANGLE (NVIDIA, NVIDIA GeForce RTX 4060 (0x00002882) Direct3D11 vs_5_0 ps_5_0, D3D11); webgpu
- Measured together with `cerebronexus-6.0.0_20261114-074022_33150d9` (this run is the candidate), session by session in turn
- Host before the sessions: median 3.1 % CPU, at most 6.5 %; waited 10 s in all

## Problems

- not finished in every round: overview (first_start), extra_material.content, markerGenes.table

## Pages and actions

Medians over the rounds that finished. Visual = click to the last frame that changes (the KPI); range = fastest and slowest round.
On the `first_start` and `first_plot` rows both times run from Chrome's navigation to the Viewer instead of from a click: First plot = to the first frame that shows the projection, Visual = to the last frame that changes. `first_start`: the server's cache directory was emptied before the session; `first_plot`: it held what earlier sessions left.

| Page | Visit | Dataset | Status | Visual (ms) | First plot (ms) | Range (ms) | Server busy (ms) | Trail (ms) | Largest msg (MB) | Loader (ms) | R peak (MiB) | Chrome peak (MiB) | Value |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| loadData | initial | 1m | ok | 34 | - | 29-859 | 5,534 | 4,895 | <0.1 | 0 | 885 | 583 |  |
| loadData.switch | action | 1m | ok | 19 | - | 17-740 | 3,296 | 2,407 | <0.1 | 139 | 768 | 618 | Demo dataset |
| loadData.switch_back | action | 1m | ok | 148 | - | 12-159 | 1,205 | 407 | <0.1 | 141 | 834 | 629 | Second dataset |
| overview | cold | 1m | ok | 363 | - | 294-376 | 758 | 0 | <0.1 | 243 | 750 | 845 |  |
| overview | first_start | 1m | no_plot (4/5 ok) | 3,550 | 3,614 | 3,486-3,642 | 10,836 | 7,476 | <0.1 | 1,266 | 1,089 | 818 |  |
| overview | first_plot | 1m | ok | 1,840 | 2,053 | 1,754-2,028 | 9,416 | 8,807 | <0.1 | 819 | 749 | 825 |  |
| overview.colour_by | action | 1m | ok | 154 | - | 124-181 | 0 | 0 | <0.1 | 0 | 768 | 843 | sample |
| overview.zoom | action | 1m | ok | 7 | - | 6-8 | 0 | 0 | <0.1 | 0 | 767 | 784 | in |
| overview.lasso | action | 1m | ok | 87 | - | 83-88 | 307 | 0 | 0.2 | 0 | 776 | 772 | middle 40% |
| coordinated_views | cold | 1m | ok | 465 | - | 443-683 | 789 | 0 | <0.1 | 459 | 756 | 830 |  |
| coordinated_views.colour_by | action | 1m | ok | 8 | - | 8-152 | 84 | 0 | 1.3 | 0 | 734 | 851 | sample |
| groups | cold | 1m | ok | 265 | - | 171-302 | 332 | 0 | <0.1 | 125 | 668 | 610 |  |
| groups.group | action | 1m | ok | 11 | - | 9-139 | 197 | 0 | <0.1 | 0 | 767 | 620 | seurat_clusters |
| groups.plot_type | action | 1m | ok | 8 | - | 7-9 | 0 | 0 | <0.1 | 0 | 690 | 693 | Sankey plot |
| groups.percent | action | 1m | ok | 7 | - | 6-7 | 0 | 0 | <0.1 | 0 | 690 | 661 | on |
| geneExpression | cold | 1m | ok | 506 | - | 437-584 | 1,038 | 0 | <0.1 | 284 | 748 | 873 |  |
| geneExpression.gene | action | 1m | ok | 655 | - | 505-742 | 458 | 0 | 5.5 | 0 | 886 | 1,031 | 0610007P14Rik |
| geneExpression.genes12 | action | 1m | ok | 803 | - | 760-832 | 578 | 0 | 10.5 | 0 | 964 | 1,038 | 0610007P14Rik 0610009B22Rik 0610009L18Rik 0610009O20Rik 0610010F05Rik 0610010K14Rik 0610011F06Rik 0610012D04Rik 0610012G03Rik 0610025J13Rik 0610030E20Rik 0610031O16Rik |
| trajectory | cold | 1m | ok | 697 | - | 556-890 | 962 | 0 | 5.1 | 434 | 918 | 893 |  |
| trajectory.colour_by | action | 1m | ok | 11 | - | 10-12 | 312 | 0 | 5.1 | 0 | 903 | 988 | state |
| color_management | cold | 1m | ok | 341 | - | 274-414 | 278 | 0 | <0.1 | 218 | 579 | 603 |  |
| geneIdConversion | cold | 1m | ok | 428 | - | 368-473 | 438 | 0 | 0.3 | 344 | 590 | 613 |  |
| about | cold | 1m | ok | 120 | - | 109-138 | 180 | 0 | <0.1 | 0 | 531 | 582 |  |
| immune_repertoire | cold | ren | ok | 22,039 | - | 21,643-22,437 | 24,110 | 1,173 | 2.6 | 20,835 | 1,723 | 737 |  |
| immune_repertoire.tab | action | ren | ok | 662 | - | 620-1,348 | 991 | 0 | 0.2 | 0 | 1,700 | 992 | Abundance |
| hla_tcr_motifs | cold | ren | ok | 579 | - | 498-620 | 668 | 0 | <0.1 | 406 | 696 | 654 |  |
| hla_tcr_motifs.colour_by | action | ren | ok | 11 | - | 11-13 | 0 | 0 | <0.1 | 0 | 686 | 668 | major_type |
| extra_material | cold | ren | ok | 367 | - | 342-480 | 493 | 2,413 | <0.1 | 313 | 681 | 658 |  |
| extra_material.content | action | ren | unavailable (0/5 ok) | - | - | - | - | - | - | - | - | - |  |
| spatial | cold | cosmx | ok | 864 | - | 738-973 | 1,147 | 2,047 | 0.1 | 416 | 983 | 734 |  |
| spatial.section | action | cosmx | ok | 255 | - | 172-315 | 423 | 0 | 0.1 | 0 | 956 | 740 | spatial_projection_sample=Lung5_Rep2 |
| markerGenes | cold | example | ok | 426 | - | 323-611 | 3,712 | 2,363 | <0.1 | 139 | 542 | 626 |  |
| markerGenes.table | action | example | unavailable (0/5 ok) | - | - | - | - | - | - | - | - | - |  |
| mostExpressedGenes | cold | example | ok | 482 | - | 326-513 | 493 | 0 | <0.1 | 35 | 573 | 613 |  |
| mostExpressedGenes.group | action | example | ok | 156 | - | 131-179 | 283 | 0 | <0.1 | 0 | 572 | 619 | seurat_clusters |
| enrichedPathways | cold | example | ok | 598 | - | 512-619 | 424 | 0 | <0.1 | 59 | 566 | 626 |  |
| enrichedPathways.table | action | example | ok | 168 | - | 156-287 | 0 | 0 | <0.1 | 0 | 573 | 634 | enriched_pathways_selected_method=cerebro_GSVA |
| trekker | cold | demo_trekker | ok | 289 | - | 121-331 | 2,991 | 3,280 | 0.1 | 21 | 506 | 627 |  |
| trekker.colour_by | action | demo_trekker | ok | 10 | - | 8-11 | 0 | 0 | 0.1 | 0 | 445 | 619 | cluster |

## Memory per dataset

Largest peak of any session on the dataset (R server tree, Chrome tree) and the median server start.

| Dataset | Sessions | R peak (MiB) | Chrome peak (MiB) | Server start (s) |
|---|---|---|---|---|
| 1m | 55 | 1,089 | 1,046 | 0.6 |
| ren | 15 | 1,737 | 995 | 0.6 |
| cosmx | 5 | 983 | 750 | 0.6 |
| example | 15 | 574 | 648 | 0.6 |
| demo_trekker | 5 | 553 | 635 | 0.6 |

## Server steps

The R work behind the pages, without a browser (one fresh R process per dataset and round).

| Dataset | Step | Time (ms) | Status |
|---|---|---|---|
| 1m | read_crb | 2,260 | ok |
| 1m | cell_names | 3,440 | ok |
| 1m | metadata | 0 | ok |
| 1m | projection | 0 | ok |
| 1m | gene_row_first | 40 | ok |
| 1m | gene_row_repeat | 60 | ok |
| 1m | gene_block_12 | 20 | ok |
| 1m | mean_expression_12 | 610 | ok |
| 1m | cells_10pct_genes_12 | 260 | ok |
| 1m | linked_bundle_build | 550 | ok |
| 1m | linked_bundle_json | 4,600 | ok |
| ren | read_crb | 1,770 | ok |
| ren | cell_names | 3,190 | ok |
| ren | metadata | 0 | ok |
| ren | projection | 0 | ok |
| ren | gene_row_first | 40 | ok |
| ren | gene_row_repeat | 50 | ok |
| ren | gene_block_12 | 20 | ok |
| ren | mean_expression_12 | 1,040 | ok |
| ren | cells_10pct_genes_12 | 220 | ok |
| ren | linked_bundle_build | 5,560 | ok |
| ren | linked_bundle_json | 5,730 | ok |
| cosmx | read_crb | 860 | ok |
| cosmx | cell_names | 2,600 | ok |
| cosmx | metadata | 0 | ok |
| cosmx | projection | 0 | ok |
| cosmx | gene_row_first | 30 | ok |
| cosmx | gene_row_repeat | 30 | ok |
| cosmx | gene_block_12 | 20 | ok |
| cosmx | mean_expression_12 | 280 | ok |
| cosmx | cells_10pct_genes_12 | 170 | ok |
| cosmx | linked_bundle_build | 1,080 | ok |
| cosmx | linked_bundle_json | 4,470 | ok |
| example | read_crb | 170 | ok |
| example | cell_names | 400 | ok |
| example | metadata | 0 | ok |
| example | projection | 0 | ok |
| example | gene_row_first | 0 | ok |
| example | gene_row_repeat | 20 | ok |
| example | gene_block_12 | 0 | ok |
| example | mean_expression_12 | 0 | ok |
| example | cells_10pct_genes_12 | 0 | ok |
| example | linked_bundle_build | 0 | ok |
| example | linked_bundle_json | 20 | ok |
| demo_trekker | read_crb | 180 | ok |
| demo_trekker | cell_names | 390 | ok |
| demo_trekker | metadata | 0 | ok |
| demo_trekker | projection | 0 | ok |
| demo_trekker | gene_row_first | 0 | ok |
| demo_trekker | gene_row_repeat | 20 | ok |
| demo_trekker | gene_block_12 | 0 | ok |
| demo_trekker | mean_expression_12 | 0 | ok |
| demo_trekker | cells_10pct_genes_12 | 0 | ok |
| demo_trekker | linked_bundle_build | 0 | ok |
| demo_trekker | linked_bundle_json | 30 | ok |

