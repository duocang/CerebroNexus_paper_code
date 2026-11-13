# Viewer performance: CerebroNexus 5.5.0

- Run: `cerebronexus-5.5.0_20261029-235928_446e021`
- Revision: perf/viewer-page-open (`446e02112695`)
- Rounds: 3; sessions: 51, failed twice: 0
- Datasets: 1m, ren, cosmx, example, demo_trekker
- Machine: NUIOI; Microsoft Windows 11 Pro 10.0.26300; 12th Gen Intel(R) Core(TM) i9-12900K
- R version 4.6.1 (2026-06-24 ucrt); Chrome/156.0.8078.48, drawn by ANGLE (NVIDIA, NVIDIA GeForce RTX 4060 (0x00002882) Direct3D11 vs_5_0 ps_5_0, D3D11); webgpu

## Problems

- the CPU canary changed by a factor 1.43 between start and end: the machine was busy with something else
- not finished in every round: extra_material.content, markerGenes.table

## Pages and actions

Medians over the rounds that finished. Visual = click to the last frame that changes (the KPI); range = fastest and slowest round.

| Page | Visit | Dataset | Status | Visual (ms) | Range (ms) | Server busy (ms) | Trail (ms) | Largest msg (MB) | Loader (ms) | R peak (MiB) | Chrome peak (MiB) | Value |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| loadData | initial | 1m | ok | 187 | 56-331 | 1,709 | 820 | <0.1 | 171 | 846 | 628 |  |
| loadData.switch | action | 1m | ok | 323 | 318-427 | 1,362 | 5,521 | <0.1 | 392 | 636 | 649 | Demo dataset |
| loadData.switch_back | action | 1m | ok | 418 | 411-423 | 1,200 | 121 | <0.1 | 377 | 631 | 608 | Second dataset |
| overview | cold | 1m | ok | 572 | 295-835 | 977 | 4,083 | <0.1 | 325 | 649 | 846 |  |
| overview.colour_by | action | 1m | ok | 141 | 127-169 | 34 | 0 | <0.1 | 0 | 668 | 755 | sample |
| overview.zoom | action | 1m | ok | 8 | 7-8 | 0 | 0 | <0.1 | 0 | 668 | 757 | in |
| overview.lasso | action | 1m | ok | 294 | 110-380 | 295 | 0 | 0.2 | 0 | 670 | 813 | middle 40% |
| coordinated_views | cold | 1m | ok | 530 | 394-1,052 | 949 | 2,884 | <0.1 | 565 | 666 | 812 |  |
| coordinated_views.colour_by | action | 1m | ok | 11 | 8-206 | 0 | 0 | 1.3 | 0 | 645 | 758 | sample |
| groups | cold | 1m | ok | 290 | 282-486 | 388 | 4,294 | <0.1 | 155 | 633 | 610 |  |
| groups.group | action | 1m | ok | 15 | 14-159 | 410 | 0 | <0.1 | 0 | 669 | 562 | seurat_clusters |
| groups.plot_type | action | 1m | ok | 12 | 9-13 | 0 | 0 | <0.1 | 0 | 608 | 654 | Sankey plot |
| groups.percent | action | 1m | ok | 8 | 7-14 | 0 | 0 | <0.1 | 0 | 608 | 647 | on |
| geneExpression | cold | 1m | ok | 718 | 700-1,128 | 1,223 | 3,879 | <0.1 | 350 | 655 | 860 |  |
| geneExpression.gene | action | 1m | ok | 2,212 | 1,318-3,033 | 2,231 | 0 | 5.5 | 0 | 780 | 1,076 | 0610007P14Rik |
| geneExpression.genes12 | action | 1m | ok | 1,208 | 1,138-1,573 | 1,031 | 0 | 10.5 | 0 | 1,114 | 1,111 | 0610007P14Rik 0610009B22Rik 0610009L18Rik 0610009O20Rik 0610010F05Rik 0610010K14Rik 0610011F06Rik 0610012D04Rik 0610012G03Rik 0610025J13Rik 0610030E20Rik 0610031O16Rik |
| trajectory | cold | 1m | ok | 741 | 680-805 | 1,220 | 3,973 | 5.1 | 579 | 824 | 887 |  |
| trajectory.colour_by | action | 1m | ok | 13 | 13-14 | 251 | 0 | 5.1 | 0 | 902 | 851 | state |
| color_management | cold | 1m | ok | 464 | 453-479 | 386 | 4,674 | <0.1 | 282 | 629 | 610 |  |
| geneIdConversion | cold | 1m | ok | 730 | 579-740 | 596 | 4,459 | 0.3 | 531 | 658 | 622 |  |
| about | cold | 1m | ok | 129 | 111-130 | 0 | 4,984 | <0.1 | 0 | 628 | 596 |  |
| immune_repertoire | cold | ren | ok | 1,046 | 936-1,785 | 1,155 | 3,504 | 2.6 | 382 | 729 | 857 |  |
| immune_repertoire.tab | action | ren | ok | 1,067 | 1,043-2,363 | 1,212 | 0 | 0.2 | 0 | 721 | 1,101 | Abundance |
| hla_tcr_motifs | cold | ren | ok | 598 | 595-909 | 645 | 4,443 | <0.1 | 408 | 521 | 668 |  |
| hla_tcr_motifs.colour_by | action | ren | ok | 14 | 14-209 | 0 | 0 | <0.1 | 0 | 512 | 621 | major_type |
| extra_material | cold | ren | ok | 358 | 326-876 | 596 | 4,624 | <0.1 | 309 | 504 | 668 |  |
| extra_material.content | action | ren | unavailable (0/3 ok) | - | - | - | - | - | - | - | - |  |
| spatial | cold | cosmx | ok | 790 | 695-1,226 | 1,189 | 0 | 0.1 | 338 | 675 | 745 |  |
| spatial.section | action | cosmx | ok | 298 | 271-533 | 541 | 205 | 0.1 | 0 | 705 | 743 | spatial_projection_sample=Lung5_Rep2 |
| markerGenes | cold | example | ok | 371 | 256-706 | 328 | 0 | <0.1 | 0 | 390 | 632 |  |
| markerGenes.table | action | example | unavailable (0/3 ok) | - | - | - | - | - | - | - | - |  |
| mostExpressedGenes | cold | example | ok | 468 | 390-488 | 485 | 0 | <0.1 | 0 | 389 | 625 |  |
| mostExpressedGenes.group | action | example | ok | 154 | 150-402 | 300 | 1,956 | <0.1 | 0 | 390 | 640 | seurat_clusters |
| enrichedPathways | cold | example | ok | 580 | 544-808 | 513 | 0 | <0.1 | 0 | 389 | 641 |  |
| enrichedPathways.table | action | example | ok | 285 | 160-325 | 0 | 1,843 | <0.1 | 0 | 388 | 650 | enriched_pathways_selected_method=cerebro_GSVA |
| trekker | cold | demo_trekker | ok | 153 | 153-201 | 271 | 0 | 0.1 | 0 | 391 | 638 |  |
| trekker.colour_by | action | demo_trekker | ok | 14 | 11-15 | 0 | 2,133 | 0.1 | 0 | 391 | 632 | cluster |

## Memory per dataset

Largest peak of any session on the dataset (R server tree, Chrome tree) and the median server start.

| Dataset | Sessions | R peak (MiB) | Chrome peak (MiB) | Server start (s) |
|---|---|---|---|---|
| 1m | 27 | 1,134 | 1,113 | 6.3 |
| ren | 9 | 776 | 1,103 | 3.9 |
| cosmx | 3 | 757 | 761 | 4.4 |
| example | 9 | 398 | 672 | 2.9 |
| demo_trekker | 3 | 398 | 667 | 2.9 |

## Server steps

The R work behind the pages, without a browser (one fresh R process per dataset and round).

| Dataset | Step | Time (ms) | Status |
|---|---|---|---|
| 1m | read_crb | 3,020 | ok |
| 1m | cell_names | 3,030 | ok |
| 1m | metadata | 0 | ok |
| 1m | projection | 0 | ok |
| 1m | gene_row_first | 60 | ok |
| 1m | gene_row_repeat | 70 | ok |
| 1m | gene_block_12 | 30 | ok |
| 1m | mean_expression_12 | 800 | ok |
| 1m | cells_10pct_genes_12 | 320 | ok |
| 1m | linked_bundle_build | 640 | ok |
| 1m | linked_bundle_json | 5,920 | ok |
| ren | read_crb | 2,560 | ok |
| ren | cell_names | 3,330 | ok |
| ren | metadata | 0 | ok |
| ren | projection | 0 | ok |
| ren | gene_row_first | 40 | ok |
| ren | gene_row_repeat | 50 | ok |
| ren | gene_block_12 | 30 | ok |
| ren | mean_expression_12 | 890 | ok |
| ren | cells_10pct_genes_12 | 380 | ok |
| ren | linked_bundle_build | 7,240 | ok |
| ren | linked_bundle_json | 7,660 | ok |
| cosmx | read_crb | 1,190 | ok |
| cosmx | cell_names | 2,250 | ok |
| cosmx | metadata | 0 | ok |
| cosmx | projection | 0 | ok |
| cosmx | gene_row_first | 20 | ok |
| cosmx | gene_row_repeat | 50 | ok |
| cosmx | gene_block_12 | 30 | ok |
| cosmx | mean_expression_12 | 320 | ok |
| cosmx | cells_10pct_genes_12 | 210 | ok |
| cosmx | linked_bundle_build | 910 | ok |
| cosmx | linked_bundle_json | 5,330 | ok |
| example | read_crb | 50 | ok |
| example | cell_names | 0 | ok |
| example | metadata | 0 | ok |
| example | projection | 0 | ok |
| example | gene_row_first | 0 | ok |
| example | gene_row_repeat | 20 | ok |
| example | gene_block_12 | 0 | ok |
| example | mean_expression_12 | 10 | ok |
| example | cells_10pct_genes_12 | 0 | ok |
| example | linked_bundle_build | 0 | ok |
| example | linked_bundle_json | 0 | ok |
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

