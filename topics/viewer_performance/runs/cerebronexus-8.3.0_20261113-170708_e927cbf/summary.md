# Viewer performance: CerebroNexus 8.3.0

- Run: `cerebronexus-8.3.0_20261113-170708_e927cbf`
- Revision: e927cbf180fb1a50cf783245ab580e83a1334764 (`e927cbf180fb`)
- Rounds: 5; sessions: 95, failed twice: 0
- Datasets: 1m, ren, cosmx, example, demo_trekker
- Machine: NUIOI; Microsoft Windows 11 Pro 10.0.26300; 12th Gen Intel(R) Core(TM) i9-12900K
- R version 4.6.1 (2026-06-24 ucrt); Chrome/157.0.8103.52, drawn by ANGLE (NVIDIA, NVIDIA GeForce RTX 4060 (0x00002882) Direct3D11 vs_5_0 ps_5_0, D3D11); webgpu
- Measured together with `cerebronexus-8.0.1_20261113-170708_6a67f6f` (this run is the candidate), session by session in turn
- Host before the sessions: median 5.1 % CPU, at most 9.2 %; waited 18 s in all

## Problems

- not finished in every round: extra_material.content, markerGenes.table

## Pages and actions

Medians over the rounds that finished. Visual = click to the last frame that changes (the KPI); range = fastest and slowest round.
On the `first_start` and `first_plot` rows both times run from Chrome's navigation to the Viewer instead of from a click: First plot = to the first frame that shows the projection, Visual = to the last frame that changes. `first_start`: the server's cache directory was emptied before the session; `first_plot`: it held what earlier sessions left.

| Page | Visit | Dataset | Status | Visual (ms) | First plot (ms) | Range (ms) | Server busy (ms) | Trail (ms) | Largest msg (MB) | Loader (ms) | R peak (MiB) | Chrome peak (MiB) | Value |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| loadData | initial | 1m | ok | 26 | - | 22-46 | 5,727 | 5,080 | <0.1 | 0 | 884 | 582 |  |
| loadData.switch | action | 1m | ok | 449 | - | 153-766 | 1,695 | 1,553 | <0.1 | 532 | 766 | 643 | Demo dataset |
| loadData.switch_back | action | 1m | ok | 414 | - | 13-431 | 1,353 | 317 | <0.1 | 375 | 838 | 656 | Second dataset |
| overview | cold | 1m | ok | 398 | - | 380-545 | 888 | 0 | <0.1 | 265 | 746 | 846 |  |
| overview | first_start | 1m | ok | 3,317 | 3,495 | 3,181-3,768 | 10,952 | 7,284 | <0.1 | 1,016 | 1,058 | 813 |  |
| overview | first_plot | 1m | ok | 2,097 | 2,196 | 1,846-2,761 | 9,176 | 8,936 | <0.1 | 1,186 | 729 | 817 |  |
| overview.colour_by | action | 1m | ok | 136 | - | 121-170 | 0 | 0 | <0.1 | 0 | 761 | 845 | sample |
| overview.zoom | action | 1m | ok | 7 | - | 6-7 | 0 | 0 | <0.1 | 0 | 761 | 789 | in |
| overview.lasso | action | 1m | ok | 88 | - | 87-105 | 214 | 0 | 0.2 | 0 | 769 | 777 | middle 40% |
| coordinated_views | cold | 1m | ok | 512 | - | 403-600 | 2,784 | 1,259 | <0.1 | 519 | 742 | 829 |  |
| coordinated_views.colour_by | action | 1m | ok | 9 | - | 8-156 | 86 | 0 | 1.3 | 0 | 718 | 849 | sample |
| groups | cold | 1m | ok | 285 | - | 211-308 | 368 | 0 | <0.1 | 125 | 668 | 619 |  |
| groups.group | action | 1m | ok | 137 | - | 131-167 | 242 | 0 | <0.1 | 0 | 743 | 622 | seurat_clusters |
| groups.plot_type | action | 1m | ok | 8 | - | 8-10 | 0 | 0 | <0.1 | 0 | 684 | 701 | Sankey plot |
| groups.percent | action | 1m | ok | 6 | - | 6-8 | 0 | 0 | <0.1 | 0 | 684 | 662 | on |
| geneExpression | cold | 1m | ok | 554 | - | 544-730 | 1,027 | 0 | <0.1 | 286 | 733 | 878 |  |
| geneExpression.gene | action | 1m | ok | 543 | - | 387-676 | 1,989 | 565 | 5.5 | 0 | 790 | 1,029 | 0610007P14Rik |
| geneExpression.genes12 | action | 1m | ok | 839 | - | 639-860 | 587 | 0 | 10.5 | 0 | 976 | 998 | 0610007P14Rik 0610009B22Rik 0610009L18Rik 0610009O20Rik 0610010F05Rik 0610010K14Rik 0610011F06Rik 0610012D04Rik 0610012G03Rik 0610025J13Rik 0610030E20Rik 0610031O16Rik |
| trajectory | cold | 1m | ok | 577 | - | 435-746 | 943 | 0 | 5.1 | 448 | 898 | 881 |  |
| trajectory.colour_by | action | 1m | ok | 13 | - | 11-208 | 306 | 0 | 5.1 | 0 | 887 | 983 | state |
| color_management | cold | 1m | ok | 344 | - | 220-353 | 317 | 0 | <0.1 | 0 | 580 | 604 |  |
| geneIdConversion | cold | 1m | ok | 490 | - | 451-529 | 486 | 0 | 0.3 | 344 | 596 | 620 |  |
| about | cold | 1m | ok | 124 | - | 118-176 | 331 | 190 | <0.1 | 0 | 532 | 587 |  |
| immune_repertoire | cold | ren | ok | 21,990 | - | 21,682-22,946 | 23,202 | 450 | 2.6 | 21,477 | 1,943 | 742 |  |
| immune_repertoire.tab | action | ren | ok | 742 | - | 711-1,034 | 2,223 | 0 | 0.2 | 0 | 2,117 | 988 | Abundance |
| hla_tcr_motifs | cold | ren | ok | 609 | - | 532-626 | 751 | 0 | <0.1 | 406 | 700 | 657 |  |
| hla_tcr_motifs.colour_by | action | ren | ok | 12 | - | 11-13 | 0 | 0 | <0.1 | 0 | 687 | 670 | major_type |
| extra_material | cold | ren | ok | 345 | - | 332-511 | 576 | 0 | <0.1 | 311 | 684 | 650 |  |
| extra_material.content | action | ren | unavailable (0/5 ok) | - | - | - | - | - | - | - | - | - |  |
| spatial | cold | cosmx | ok | 826 | - | 710-848 | 1,271 | 0 | 0.1 | 343 | 984 | 746 |  |
| spatial.section | action | cosmx | ok | 261 | - | 163-323 | 389 | 0 | 0.1 | 0 | 954 | 751 | spatial_projection_sample=Lung5_Rep2 |
| markerGenes | cold | example | ok | 470 | - | 408-605 | 2,629 | 1,395 | <0.1 | 110 | 549 | 628 |  |
| markerGenes.table | action | example | unavailable (0/5 ok) | - | - | - | - | - | - | - | - | - |  |
| mostExpressedGenes | cold | example | ok | 517 | - | 427-537 | 465 | 0 | <0.1 | 62 | 578 | 609 |  |
| mostExpressedGenes.group | action | example | ok | 168 | - | 147-194 | 1,224 | 400 | <0.1 | 0 | 573 | 627 | seurat_clusters |
| enrichedPathways | cold | example | ok | 547 | - | 521-658 | 552 | 0 | <0.1 | 59 | 574 | 626 |  |
| enrichedPathways.table | action | example | ok | 179 | - | 164-299 | 0 | 0 | <0.1 | 0 | 576 | 637 | enriched_pathways_selected_method=cerebro_GSVA |
| trekker | cold | demo_trekker | ok | 454 | - | 181-507 | 680 | 3,011 | 0.1 | 344 | 540 | 633 |  |
| trekker.colour_by | action | demo_trekker | ok | 12 | - | 9-13 | 0 | 0 | 0.1 | 0 | 552 | 630 | cluster |

## Memory per dataset

Largest peak of any session on the dataset (R server tree, Chrome tree) and the median server start.

| Dataset | Sessions | R peak (MiB) | Chrome peak (MiB) | Server start (s) |
|---|---|---|---|---|
| 1m | 55 | 1,061 | 1,042 | 0.6 |
| ren | 15 | 2,117 | 999 | 0.6 |
| cosmx | 5 | 984 | 758 | 0.6 |
| example | 15 | 578 | 643 | 0.6 |
| demo_trekker | 5 | 561 | 641 | 0.6 |

## Server steps

The R work behind the pages, without a browser (one fresh R process per dataset and round).

| Dataset | Step | Time (ms) | Status |
|---|---|---|---|
| 1m | read_crb | 2,440 | ok |
| 1m | cell_names | 3,520 | ok |
| 1m | metadata | 0 | ok |
| 1m | projection | 0 | ok |
| 1m | gene_row_first | 40 | ok |
| 1m | gene_row_repeat | 70 | ok |
| 1m | gene_block_12 | 20 | ok |
| 1m | mean_expression_12 | 630 | ok |
| 1m | cells_10pct_genes_12 | 280 | ok |
| 1m | linked_bundle_build | 550 | ok |
| 1m | linked_bundle_json | 4,640 | ok |
| ren | read_crb | 1,780 | ok |
| ren | cell_names | 3,310 | ok |
| ren | metadata | 0 | ok |
| ren | projection | 0 | ok |
| ren | gene_row_first | 40 | ok |
| ren | gene_row_repeat | 40 | ok |
| ren | gene_block_12 | 20 | ok |
| ren | mean_expression_12 | 1,060 | ok |
| ren | cells_10pct_genes_12 | 230 | ok |
| ren | linked_bundle_build | 5,900 | ok |
| ren | linked_bundle_json | 5,960 | ok |
| cosmx | read_crb | 840 | ok |
| cosmx | cell_names | 2,690 | ok |
| cosmx | metadata | 0 | ok |
| cosmx | projection | 0 | ok |
| cosmx | gene_row_first | 20 | ok |
| cosmx | gene_row_repeat | 30 | ok |
| cosmx | gene_block_12 | 20 | ok |
| cosmx | mean_expression_12 | 330 | ok |
| cosmx | cells_10pct_genes_12 | 180 | ok |
| cosmx | linked_bundle_build | 1,150 | ok |
| cosmx | linked_bundle_json | 4,620 | ok |
| example | read_crb | 30 | ok |
| example | cell_names | 400 | ok |
| example | metadata | 0 | ok |
| example | projection | 0 | ok |
| example | gene_row_first | 0 | ok |
| example | gene_row_repeat | 20 | ok |
| example | gene_block_12 | 0 | ok |
| example | mean_expression_12 | 0 | ok |
| example | cells_10pct_genes_12 | 0 | ok |
| example | linked_bundle_build | 140 | ok |
| example | linked_bundle_json | 20 | ok |
| demo_trekker | read_crb | 30 | ok |
| demo_trekker | cell_names | 410 | ok |
| demo_trekker | metadata | 0 | ok |
| demo_trekker | projection | 0 | ok |
| demo_trekker | gene_row_first | 0 | ok |
| demo_trekker | gene_row_repeat | 20 | ok |
| demo_trekker | gene_block_12 | 0 | ok |
| demo_trekker | mean_expression_12 | 0 | ok |
| demo_trekker | cells_10pct_genes_12 | 0 | ok |
| demo_trekker | linked_bundle_build | 140 | ok |
| demo_trekker | linked_bundle_json | 40 | ok |

