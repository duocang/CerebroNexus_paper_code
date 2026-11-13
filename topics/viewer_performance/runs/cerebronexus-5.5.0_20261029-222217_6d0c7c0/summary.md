# Viewer performance: CerebroNexus 5.5.0

- Run: `cerebronexus-5.5.0_20261029-222217_6d0c7c0`
- Revision: perf/viewer-page-open (`6d0c7c0c386d`)
- Rounds: 3; sessions: 51, failed twice: 0
- Datasets: 1m, ren, cosmx, example, demo_trekker
- Machine: NUIOI; Microsoft Windows 11 Pro 10.0.26300; 12th Gen Intel(R) Core(TM) i9-12900K
- R version 4.6.1 (2026-06-24 ucrt); Chrome/156.0.8078.48, drawn by ANGLE (NVIDIA, NVIDIA GeForce RTX 4060 (0x00002882) Direct3D11 vs_5_0 ps_5_0, D3D11); webgpu

## Problems

- not finished in every round: extra_material.content, markerGenes.table

## Pages and actions

Medians over the rounds that finished. Visual = click to the last frame that changes (the KPI); range = fastest and slowest round.

| Page | Visit | Dataset | Status | Visual (ms) | Range (ms) | Server busy (ms) | Trail (ms) | Largest msg (MB) | Loader (ms) | R peak (MiB) | Chrome peak (MiB) | Value |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| loadData | initial | 1m | ok | 1,097 | 1,067-1,169 | 1,936 | 262 | <0.1 | 441 | 862 | 641 |  |
| loadData.switch | action | 1m | ok | 554 | 498-558 | 1,344 | 4,675 | <0.1 | 534 | 636 | 644 | Demo dataset |
| loadData.switch_back | action | 1m | ok | 1,148 | 1,117-1,150 | 1,282 | 0 | <0.1 | 526 | 631 | 611 | Second dataset |
| overview | cold | 1m | ok | 705 | 658-731 | 1,010 | 4,033 | <0.1 | 305 | 649 | 850 |  |
| overview.colour_by | action | 1m | ok | 215 | 187-244 | 168 | 0 | <0.1 | 0 | 668 | 776 | sample |
| overview.zoom | action | 1m | ok | 125 | 110-134 | 0 | 0 | <0.1 | 0 | 668 | 778 | in |
| overview.lasso | action | 1m | ok | 268 | 260-311 | 317 | 0 | 0.2 | 0 | 671 | 812 | middle 40% |
| coordinated_views | cold | 1m | ok | 993 | 989-1,110 | 979 | 3,988 | <0.1 | 642 | 665 | 819 |  |
| coordinated_views.colour_by | action | 1m | ok | 157 | 14-162 | 51 | 0 | 1.3 | 0 | 645 | 775 | sample |
| groups | cold | 1m | ok | 427 | 417-442 | 469 | 4,429 | <0.1 | 172 | 633 | 642 |  |
| groups.group | action | 1m | ok | 100 | 98-111 | 390 | 0 | <0.1 | 0 | 669 | 579 | seurat_clusters |
| groups.plot_type | action | 1m | ok | 123 | 104-132 | 0 | 0 | <0.1 | 0 | 608 | 669 | Sankey plot |
| groups.percent | action | 1m | ok | 203 | 127-229 | 0 | 0 | <0.1 | 0 | 608 | 668 | on |
| geneExpression | cold | 1m | ok | 857 | 827-992 | 1,517 | 3,611 | <0.1 | 467 | 641 | 845 |  |
| geneExpression.gene | action | 1m | ok | 2,563 | 2,480-2,665 | 854 | 0 | 5.5 | 0 | 755 | 1,096 | 0610007P14Rik |
| geneExpression.genes12 | action | 1m | ok | 9,354 | 9,311-9,622 | 9,003 | 0 | 10.5 | 0 | 1,464 | 1,076 | 0610007P14Rik 0610009B22Rik 0610009L18Rik 0610009O20Rik 0610010F05Rik 0610010K14Rik 0610011F06Rik 0610012D04Rik 0610012G03Rik 0610025J13Rik 0610030E20Rik 0610031O16Rik |
| trajectory | cold | 1m | ok | 940 | 935-1,029 | 1,256 | 3,886 | 5.1 | 656 | 810 | 913 |  |
| trajectory.colour_by | action | 1m | ok | 176 | 13-268 | 229 | 57 | 5.1 | 0 | 873 | 900 | state |
| color_management | cold | 1m | ok | 342 | 259-1,747 | 381 | 4,614 | <0.1 | 0 | 630 | 627 |  |
| geneIdConversion | cold | 1m | ok | 897 | 795-975 | 798 | 4,143 | 0.3 | 566 | 657 | 630 |  |
| about | cold | 1m | ok | 152 | 130-155 | 0 | 4,575 | <0.1 | 0 | 628 | 607 |  |
| immune_repertoire | cold | ren | ok | 1,269 | 1,085-1,723 | 1,415 | 3,258 | 2.6 | 451 | 729 | 869 |  |
| immune_repertoire.tab | action | ren | ok | 2,065 | 1,296-2,390 | 1,397 | 0 | 0.2 | 0 | 721 | 1,100 | Abundance |
| hla_tcr_motifs | cold | ren | ok | 851 | 693-905 | 835 | 3,309 | <0.1 | 568 | 521 | 657 |  |
| hla_tcr_motifs.colour_by | action | ren | ok | 17 | 15-18 | 0 | 0 | <0.1 | 0 | 512 | 621 | major_type |
| extra_material | cold | ren | ok | 686 | 636-901 | 718 | 3,435 | <0.1 | 500 | 504 | 674 |  |
| extra_material.content | action | ren | unavailable (0/3 ok) | - | - | - | - | - | - | - | - |  |
| spatial | cold | cosmx | ok | 999 | 845-1,075 | 1,548 | 4,828 | 0.1 | 458 | 674 | 757 |  |
| spatial.section | action | cosmx | ok | 354 | 312-492 | 536 | 0 | 0.1 | 0 | 705 | 700 | spatial_projection_sample=Lung5_Rep2 |
| markerGenes | cold | example | ok | 579 | 423-675 | 534 | 0 | <0.1 | 12 | 389 | 638 |  |
| markerGenes.table | action | example | unavailable (0/3 ok) | - | - | - | - | - | - | - | - |  |
| mostExpressedGenes | cold | example | ok | 523 | 488-583 | 553 | 0 | <0.1 | 6 | 390 | 630 |  |
| mostExpressedGenes.group | action | example | ok | 234 | 219-369 | 284 | 1,963 | <0.1 | 0 | 390 | 640 | seurat_clusters |
| enrichedPathways | cold | example | ok | 553 | 441-743 | 492 | 0 | <0.1 | 0 | 390 | 652 |  |
| enrichedPathways.table | action | example | ok | 262 | 173-294 | 0 | 1,823 | <0.1 | 0 | 388 | 662 | enriched_pathways_selected_method=cerebro_GSVA |
| trekker | cold | demo_trekker | ok | 149 | 23-182 | 238 | 0 | 0.1 | 0 | 391 | 634 |  |
| trekker.colour_by | action | demo_trekker | ok | 12 | 12-12 | 0 | 2,222 | 0.1 | 0 | 391 | 638 | cluster |

## Memory per dataset

Largest peak of any session on the dataset (R server tree, Chrome tree) and the median server start.

| Dataset | Sessions | R peak (MiB) | Chrome peak (MiB) | Server start (s) |
|---|---|---|---|---|
| 1m | 27 | 1,468 | 1,109 | 6.3 |
| ren | 9 | 776 | 1,124 | 4.0 |
| cosmx | 3 | 757 | 763 | 4.9 |
| example | 9 | 397 | 671 | 2.9 |
| demo_trekker | 3 | 398 | 643 | 2.9 |

## Server steps

The R work behind the pages, without a browser (one fresh R process per dataset and round).

| Dataset | Step | Time (ms) | Status |
|---|---|---|---|
| 1m | read_crb | 3,030 | ok |
| 1m | cell_names | 3,020 | ok |
| 1m | metadata | 0 | ok |
| 1m | projection | 0 | ok |
| 1m | gene_row_first | 50 | ok |
| 1m | gene_row_repeat | 60 | ok |
| 1m | gene_block_12 | 20 | ok |
| 1m | mean_expression_12 | 810 | ok |
| 1m | cells_10pct_genes_12 | 310 | ok |
| 1m | linked_bundle_build | 680 | ok |
| 1m | linked_bundle_json | 5,860 | ok |
| ren | read_crb | 2,570 | ok |
| ren | cell_names | 3,170 | ok |
| ren | metadata | 0 | ok |
| ren | projection | 0 | ok |
| ren | gene_row_first | 40 | ok |
| ren | gene_row_repeat | 60 | ok |
| ren | gene_block_12 | 30 | ok |
| ren | mean_expression_12 | 810 | ok |
| ren | cells_10pct_genes_12 | 360 | ok |
| ren | linked_bundle_build | 7,140 | ok |
| ren | linked_bundle_json | 7,590 | ok |
| cosmx | read_crb | 1,140 | ok |
| cosmx | cell_names | 2,280 | ok |
| cosmx | metadata | 0 | ok |
| cosmx | projection | 0 | ok |
| cosmx | gene_row_first | 20 | ok |
| cosmx | gene_row_repeat | 40 | ok |
| cosmx | gene_block_12 | 20 | ok |
| cosmx | mean_expression_12 | 330 | ok |
| cosmx | cells_10pct_genes_12 | 210 | ok |
| cosmx | linked_bundle_build | 860 | ok |
| cosmx | linked_bundle_json | 5,300 | ok |
| example | read_crb | 40 | ok |
| example | cell_names | 0 | ok |
| example | metadata | 0 | ok |
| example | projection | 0 | ok |
| example | gene_row_first | 0 | ok |
| example | gene_row_repeat | 20 | ok |
| example | gene_block_12 | 0 | ok |
| example | mean_expression_12 | 0 | ok |
| example | cells_10pct_genes_12 | 0 | ok |
| example | linked_bundle_build | 10 | ok |
| example | linked_bundle_json | 0 | ok |
| demo_trekker | read_crb | 50 | ok |
| demo_trekker | cell_names | 0 | ok |
| demo_trekker | metadata | 0 | ok |
| demo_trekker | projection | 0 | ok |
| demo_trekker | gene_row_first | 0 | ok |
| demo_trekker | gene_row_repeat | 20 | ok |
| demo_trekker | gene_block_12 | 0 | ok |
| demo_trekker | mean_expression_12 | 0 | ok |
| demo_trekker | cells_10pct_genes_12 | 10 | ok |
| demo_trekker | linked_bundle_build | 0 | ok |
| demo_trekker | linked_bundle_json | 30 | ok |

