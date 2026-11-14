# Viewer performance: CerebroNexus 6.0.0

- Run: `cerebronexus-6.0.0_20261114-074022_33150d9`
- Revision: d5ad68c3255d3dbf84b4d108b0cc0e2074925ab3 (`33150d9d7a95`)
- Rounds: 5; sessions: 95, failed twice: 0
- Datasets: 1m, ren, cosmx, example, demo_trekker
- Machine: NUIOI; Microsoft Windows 11 Pro 10.0.26300; 12th Gen Intel(R) Core(TM) i9-12900K
- R version 4.6.1 (2026-06-24 ucrt); Chrome/157.0.8103.52, drawn by ANGLE (NVIDIA, NVIDIA GeForce RTX 4060 (0x00002882) Direct3D11 vs_5_0 ps_5_0, D3D11); webgpu
- Measured together with `cerebronexus-8.1.1_20261114-074022_d79f5d8` (this run is the baseline), session by session in turn
- Host before the sessions: median 3.2 % CPU, at most 10.5 %; waited 10 s in all

## Problems

- not finished in every round: extra_material.content, markerGenes.table

## Pages and actions

Medians over the rounds that finished. Visual = click to the last frame that changes (the KPI); range = fastest and slowest round.
On the `first_start` and `first_plot` rows both times run from Chrome's navigation to the Viewer instead of from a click: First plot = to the first frame that shows the projection, Visual = to the last frame that changes. `first_start`: the server's cache directory was emptied before the session; `first_plot`: it held what earlier sessions left.

| Page | Visit | Dataset | Status | Visual (ms) | First plot (ms) | Range (ms) | Server busy (ms) | Trail (ms) | Largest msg (MB) | Loader (ms) | R peak (MiB) | Chrome peak (MiB) | Value |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| loadData | initial | 1m | ok | 173 | - | 38-209 | 1,309 | 391 | <0.1 | 126 | 856 | 654 |  |
| loadData.switch | action | 1m | ok | 411 | - | 156-427 | 122 | 0 | <0.1 | 379 | 599 | 659 | Demo dataset |
| loadData.switch_back | action | 1m | ok | 396 | - | 390-433 | 235 | 1,329 | <0.1 | 384 | 599 | 680 | Second dataset |
| overview | cold | 1m | ok | 509 | - | 416-740 | 1,051 | 4,043 | <0.1 | 648 | 651 | 887 |  |
| overview | first_start | 1m | ok | 2,420 | 2,421 | 2,231-2,441 | 3,080 | 7 | <0.1 | 1,161 | 910 | 836 |  |
| overview | first_plot | 1m | ok | 2,402 | 2,569 | 2,196-2,693 | 3,129 | 7 | <0.1 | 1,382 | 901 | 842 |  |
| overview.colour_by | action | 1m | ok | 137 | - | 113-249 | 0 | 0 | <0.1 | 0 | 668 | 852 | sample |
| overview.zoom | action | 1m | ok | 6 | - | 6-7 | 0 | 0 | <0.1 | 0 | 668 | 847 | in |
| overview.lasso | action | 1m | ok | 2,999 | - | 2,852-3,068 | 3,430 | 0 | 5.6 | 0 | 1,286 | 924 | middle 40% |
| coordinated_views | cold | 1m | ok | 952 | - | 831-1,347 | 1,069 | 4,652 | <0.1 | 845 | 731 | 854 |  |
| coordinated_views.colour_by | action | 1m | ok | 149 | - | 9-179 | 116 | 0 | 1.3 | 0 | 650 | 849 | sample |
| groups | cold | 1m | ok | 734 | - | 670-848 | 804 | 0 | 0.4 | 730 | 637 | 698 |  |
| groups.group | action | 1m | ok | 1,052 | - | 774-1,445 | 1,480 | 0 | 3.9 | 0 | 1,051 | 805 | seurat_clusters |
| groups.plot_type | action | 1m | ok | 136 | - | 130-193 | 194 | 0 | <0.1 | 0 | 677 | 873 | Sankey plot |
| groups.percent | action | 1m | ok | 8 | - | 6-10 | 0 | 0 | <0.1 | 0 | 641 | 940 | on |
| geneExpression | cold | 1m | ok | 1,030 | - | 956-1,054 | 1,337 | 4,993 | <0.1 | 525 | 647 | 828 |  |
| geneExpression.gene | action | 1m | ok | 733 | - | 558-743 | 825 | 0 | 5.5 | 0 | 774 | 800 | 0610007P14Rik |
| geneExpression.genes12 | action | 1m | ok | 5,460 | - | 5,305-5,541 | 5,234 | 0 | 10.5 | 0 | 1,611 | 836 | 0610007P14Rik 0610009B22Rik 0610009L18Rik 0610009O20Rik 0610010F05Rik 0610010K14Rik 0610011F06Rik 0610012D04Rik 0610012G03Rik 0610025J13Rik 0610030E20Rik 0610031O16Rik |
| trajectory | cold | 1m | ok | 864 | - | 725-880 | 771 | 4,800 | <0.1 | 634 | 606 | 780 |  |
| trajectory.colour_by | action | 1m | ok | 12 | - | 10-13 | 0 | 0 | <0.1 | 0 | 598 | 837 | state |
| color_management | cold | 1m | ok | 483 | - | 476-505 | 515 | 0 | <0.1 | 500 | 603 | 671 |  |
| geneIdConversion | cold | 1m | ok | 510 | - | 458-527 | 423 | 0 | 0.3 | 344 | 630 | 654 |  |
| about | cold | 1m | ok | 123 | - | 114-132 | 166 | 0 | <0.1 | 0 | 597 | 626 |  |
| immune_repertoire | cold | ren | ok | 3,760 | - | 3,666-4,516 | 3,845 | 1,713 | 2.6 | 596 | 905 | 840 |  |
| immune_repertoire.tab | action | ren | ok | 1,046 | - | 990-1,560 | 1,152 | 0 | 0.2 | 0 | 1,094 | 1,129 | Abundance |
| hla_tcr_motifs | cold | ren | ok | 713 | - | 665-812 | 974 | 4,909 | <0.1 | 594 | 544 | 685 |  |
| hla_tcr_motifs.colour_by | action | ren | ok | 10 | - | 9-11 | 0 | 0 | <0.1 | 0 | 537 | 651 | major_type |
| extra_material | cold | ren | ok | 539 | - | 459-658 | 571 | 5,191 | <0.1 | 562 | 509 | 697 |  |
| extra_material.content | action | ren | unavailable (0/5 ok) | - | - | - | - | - | - | - | - | - |  |
| spatial | cold | cosmx | ok | 1,122 | - | 1,067-1,168 | 1,370 | 0 | 1.2 | 638 | 740 | 738 |  |
| spatial.section | action | cosmx | ok | 543 | - | 379-568 | 616 | 363 | 1.3 | 0 | 866 | 729 | spatial_projection_sample=Lung5_Rep2 |
| markerGenes | cold | example | ok | 396 | - | 333-510 | 416 | 0 | <0.1 | 453 | 394 | 685 |  |
| markerGenes.table | action | example | unavailable (0/5 ok) | - | - | - | - | - | - | - | - | - |  |
| mostExpressedGenes | cold | example | ok | 496 | - | 441-515 | 476 | 0 | <0.1 | 428 | 394 | 685 |  |
| mostExpressedGenes.group | action | example | ok | 133 | - | 126-159 | 247 | 2,193 | <0.1 | 0 | 393 | 695 | seurat_clusters |
| enrichedPathways | cold | example | ok | 577 | - | 504-594 | 387 | 0 | <0.1 | 478 | 394 | 696 |  |
| enrichedPathways.table | action | example | ok | 280 | - | 275-283 | 0 | 1,634 | <0.1 | 0 | 391 | 705 | enriched_pathways_selected_method=cerebro_GSVA |
| trekker | cold | demo_trekker | ok | 472 | - | 413-520 | 335 | 0 | 0.1 | 435 | 394 | 698 |  |
| trekker.colour_by | action | demo_trekker | ok | 10 | - | 10-12 | 0 | 2,325 | 0.1 | 0 | 393 | 688 | cluster |

## Memory per dataset

Largest peak of any session on the dataset (R server tree, Chrome tree) and the median server start.

| Dataset | Sessions | R peak (MiB) | Chrome peak (MiB) | Server start (s) |
|---|---|---|---|---|
| 1m | 55 | 1,611 | 957 | 5.3 |
| ren | 15 | 1,094 | 1,132 | 3.4 |
| cosmx | 5 | 894 | 761 | 3.9 |
| example | 15 | 397 | 714 | 2.5 |
| demo_trekker | 5 | 399 | 712 | 2.5 |

## Server steps

The R work behind the pages, without a browser (one fresh R process per dataset and round).

| Dataset | Step | Time (ms) | Status |
|---|---|---|---|
| 1m | read_crb | 2,360 | ok |
| 1m | cell_names | 2,470 | ok |
| 1m | metadata | 0 | ok |
| 1m | projection | 0 | ok |
| 1m | gene_row_first | 40 | ok |
| 1m | gene_row_repeat | 50 | ok |
| 1m | gene_block_12 | 20 | ok |
| 1m | mean_expression_12 | 670 | ok |
| 1m | cells_10pct_genes_12 | 270 | ok |
| 1m | linked_bundle_build | 530 | ok |
| 1m | linked_bundle_json | 4,770 | ok |
| ren | read_crb | 1,970 | ok |
| ren | cell_names | 2,640 | ok |
| ren | metadata | 0 | ok |
| ren | projection | 0 | ok |
| ren | gene_row_first | 40 | ok |
| ren | gene_row_repeat | 50 | ok |
| ren | gene_block_12 | 20 | ok |
| ren | mean_expression_12 | 720 | ok |
| ren | cells_10pct_genes_12 | 280 | ok |
| ren | linked_bundle_build | 6,310 | ok |
| ren | linked_bundle_json | 5,490 | ok |
| cosmx | read_crb | 950 | ok |
| cosmx | cell_names | 1,980 | ok |
| cosmx | metadata | 0 | ok |
| cosmx | projection | 0 | ok |
| cosmx | gene_row_first | 20 | ok |
| cosmx | gene_row_repeat | 30 | ok |
| cosmx | gene_block_12 | 20 | ok |
| cosmx | mean_expression_12 | 280 | ok |
| cosmx | cells_10pct_genes_12 | 170 | ok |
| cosmx | linked_bundle_build | 1,090 | ok |
| cosmx | linked_bundle_json | 4,180 | ok |
| example | read_crb | 30 | ok |
| example | cell_names | 0 | ok |
| example | metadata | 0 | ok |
| example | projection | 0 | ok |
| example | gene_row_first | 0 | ok |
| example | gene_row_repeat | 10 | ok |
| example | gene_block_12 | 0 | ok |
| example | mean_expression_12 | 20 | ok |
| example | cells_10pct_genes_12 | 0 | ok |
| example | linked_bundle_build | 0 | ok |
| example | linked_bundle_json | 20 | ok |
| demo_trekker | read_crb | 30 | ok |
| demo_trekker | cell_names | 0 | ok |
| demo_trekker | metadata | 0 | ok |
| demo_trekker | projection | 0 | ok |
| demo_trekker | gene_row_first | 0 | ok |
| demo_trekker | gene_row_repeat | 20 | ok |
| demo_trekker | gene_block_12 | 0 | ok |
| demo_trekker | mean_expression_12 | 10 | ok |
| demo_trekker | cells_10pct_genes_12 | 0 | ok |
| demo_trekker | linked_bundle_build | 0 | ok |
| demo_trekker | linked_bundle_json | 30 | ok |

