# Viewer performance: CerebroNexus 5.5.0

- Run: `cerebronexus-5.5.0_20261030-151330_953ed91`
- Revision: perf/viewer-page-open-round2 (`953ed9178ec7`)
- Rounds: 3; sessions: 51, failed twice: 0
- Datasets: 1m, ren, cosmx, example, demo_trekker
- Machine: NUIOI; Microsoft Windows 11 Pro 10.0.26300; 12th Gen Intel(R) Core(TM) i9-12900K
- R version 4.6.1 (2026-06-24 ucrt); Chrome/156.0.8078.76, drawn by ANGLE (NVIDIA, NVIDIA GeForce RTX 4060 (0x00002882) Direct3D11 vs_5_0 ps_5_0, D3D11); webgpu

## Problems

- the CPU canary changed by a factor 1.67 between start and end: the machine was busy with something else
- not finished in every round: extra_material.content, markerGenes.table

## Pages and actions

Medians over the rounds that finished. Visual = click to the last frame that changes (the KPI); range = fastest and slowest round.

| Page | Visit | Dataset | Status | Visual (ms) | Range (ms) | Server busy (ms) | Trail (ms) | Largest msg (MB) | Loader (ms) | R peak (MiB) | Chrome peak (MiB) | Value |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| loadData | initial | 1m | ok | 1,025 | 994-1,095 | 2,089 | 433 | <0.1 | 398 | 862 | 629 |  |
| loadData.switch | action | 1m | ok | 520 | 504-522 | 1,325 | 4,247 | <0.1 | 517 | 635 | 650 | Demo dataset |
| loadData.switch_back | action | 1m | ok | 1,164 | 1,162-1,181 | 1,153 | 0 | <0.1 | 525 | 631 | 608 | Second dataset |
| overview | cold | 1m | ok | 634 | 615-649 | 949 | 4,154 | <0.1 | 351 | 649 | 857 |  |
| overview.colour_by | action | 1m | ok | 191 | 169-203 | 75 | 0 | <0.1 | 0 | 668 | 772 | sample |
| overview.zoom | action | 1m | ok | 115 | 107-123 | 0 | 0 | <0.1 | 0 | 668 | 774 | in |
| overview.lasso | action | 1m | ok | 262 | 255-263 | 391 | 0 | 0.2 | 0 | 670 | 800 | middle 40% |
| coordinated_views | cold | 1m | ok | 947 | 909-963 | 894 | 3,890 | <0.1 | 577 | 666 | 804 |  |
| coordinated_views.colour_by | action | 1m | ok | 14 | 12-140 | 0 | 0 | 1.3 | 0 | 645 | 782 | sample |
| groups | cold | 1m | ok | 412 | 404-454 | 420 | 4,165 | <0.1 | 119 | 633 | 636 |  |
| groups.group | action | 1m | ok | 120 | 98-123 | 379 | 0 | <0.1 | 0 | 675 | 564 | seurat_clusters |
| groups.plot_type | action | 1m | ok | 119 | 107-128 | 0 | 0 | <0.1 | 0 | 601 | 655 | Sankey plot |
| groups.percent | action | 1m | ok | 188 | 130-199 | 0 | 0 | <0.1 | 0 | 601 | 657 | on |
| geneExpression | cold | 1m | ok | 806 | 771-975 | 1,404 | 3,821 | <0.1 | 410 | 643 | 859 |  |
| geneExpression.gene | action | 1m | ok | 938 | 850-1,159 | 1,079 | 0 | 5.5 | 0 | 781 | 979 | 0610007P14Rik |
| geneExpression.genes12 | action | 1m | ok | 984 | 940-1,094 | 632 | 0 | 10.5 | 0 | 927 | 992 | 0610007P14Rik 0610009B22Rik 0610009L18Rik 0610009O20Rik 0610010F05Rik 0610010K14Rik 0610011F06Rik 0610012D04Rik 0610012G03Rik 0610025J13Rik 0610030E20Rik 0610031O16Rik |
| trajectory | cold | 1m | ok | 977 | 937-1,038 | 1,115 | 3,692 | 5.1 | 595 | 824 | 873 |  |
| trajectory.colour_by | action | 1m | ok | 14 | 12-159 | 250 | 0 | 5.1 | 0 | 902 | 896 | state |
| color_management | cold | 1m | ok | 548 | 547-617 | 369 | 4,116 | <0.1 | 279 | 630 | 618 |  |
| geneIdConversion | cold | 1m | ok | 542 | 526-799 | 780 | 3,172 | 0.3 | 0 | 658 | 632 |  |
| about | cold | 1m | ok | 112 | 106-131 | 0 | 4,633 | <0.1 | 0 | 628 | 605 |  |
| immune_repertoire | cold | ren | ok | 1,075 | 940-1,146 | 1,119 | 2,831 | 2.6 | 317 | 697 | 867 |  |
| immune_repertoire.tab | action | ren | ok | 981 | 870-1,271 | 766 | 9 | 0.2 | 0 | 722 | 1,072 | Abundance |
| hla_tcr_motifs | cold | ren | ok | 715 | 682-838 | 732 | 3,753 | <0.1 | 388 | 522 | 661 |  |
| hla_tcr_motifs.colour_by | action | ren | ok | 13 | 10-16 | 0 | 0 | <0.1 | 0 | 513 | 625 | major_type |
| extra_material | cold | ren | ok | 563 | 556-618 | 578 | 4,557 | <0.1 | 313 | 504 | 671 |  |
| extra_material.content | action | ren | unavailable (0/3 ok) | - | - | - | - | - | - | - | - |  |
| spatial | cold | cosmx | ok | 834 | 786-858 | 1,221 | 4,552 | 0.1 | 343 | 675 | 750 |  |
| spatial.section | action | cosmx | ok | 334 | 295-352 | 511 | 297 | 0.1 | 0 | 704 | 711 | spatial_projection_sample=Lung5_Rep2 |
| markerGenes | cold | example | ok | 394 | 277-409 | 451 | 0 | <0.1 | 0 | 390 | 637 |  |
| markerGenes.table | action | example | unavailable (0/3 ok) | - | - | - | - | - | - | - | - |  |
| mostExpressedGenes | cold | example | ok | 516 | 507-644 | 491 | 0 | <0.1 | 11 | 390 | 634 |  |
| mostExpressedGenes.group | action | example | ok | 237 | 229-241 | 333 | 1,919 | <0.1 | 0 | 390 | 639 | seurat_clusters |
| enrichedPathways | cold | example | ok | 549 | 384-550 | 475 | 0 | <0.1 | 0 | 390 | 646 |  |
| enrichedPathways.table | action | example | ok | 230 | 211-305 | 0 | 1,581 | <0.1 | 0 | 388 | 649 | enriched_pathways_selected_method=cerebro_GSVA |
| trekker | cold | demo_trekker | ok | 163 | 162-174 | 339 | 0 | 0.1 | 0 | 391 | 629 |  |
| trekker.colour_by | action | demo_trekker | ok | 14 | 13-14 | 0 | 2,184 | 0.1 | 0 | 391 | 630 | cluster |

## Memory per dataset

Largest peak of any session on the dataset (R server tree, Chrome tree) and the median server start.

| Dataset | Sessions | R peak (MiB) | Chrome peak (MiB) | Server start (s) |
|---|---|---|---|---|
| 1m | 27 | 927 | 1,001 | 6.8 |
| ren | 9 | 775 | 1,074 | 4.0 |
| cosmx | 3 | 757 | 759 | 4.9 |
| example | 9 | 398 | 653 | 2.9 |
| demo_trekker | 3 | 398 | 641 | 2.9 |

## Server steps

The R work behind the pages, without a browser (one fresh R process per dataset and round).

| Dataset | Step | Time (ms) | Status |
|---|---|---|---|
| 1m | read_crb | 4,200 | ok |
| 1m | cell_names | 4,750 | ok |
| 1m | metadata | 0 | ok |
| 1m | projection | 0 | ok |
| 1m | gene_row_first | 70 | ok |
| 1m | gene_row_repeat | 60 | ok |
| 1m | gene_block_12 | 30 | ok |
| 1m | mean_expression_12 | 1,280 | ok |
| 1m | cells_10pct_genes_12 | 480 | ok |
| 1m | linked_bundle_build | 940 | ok |
| 1m | linked_bundle_json | 8,890 | ok |
| ren | read_crb | 3,220 | ok |
| ren | cell_names | 5,040 | ok |
| ren | metadata | 0 | ok |
| ren | projection | 0 | ok |
| ren | gene_row_first | 70 | ok |
| ren | gene_row_repeat | 80 | ok |
| ren | gene_block_12 | 30 | ok |
| ren | mean_expression_12 | 1,280 | ok |
| ren | cells_10pct_genes_12 | 520 | ok |
| ren | linked_bundle_build | 10,880 | ok |
| ren | linked_bundle_json | 11,200 | ok |
| cosmx | read_crb | 1,240 | ok |
| cosmx | cell_names | 3,450 | ok |
| cosmx | metadata | 0 | ok |
| cosmx | projection | 0 | ok |
| cosmx | gene_row_first | 30 | ok |
| cosmx | gene_row_repeat | 50 | ok |
| cosmx | gene_block_12 | 30 | ok |
| cosmx | mean_expression_12 | 420 | ok |
| cosmx | cells_10pct_genes_12 | 270 | ok |
| cosmx | linked_bundle_build | 1,250 | ok |
| cosmx | linked_bundle_json | 7,640 | ok |
| example | read_crb | 50 | ok |
| example | cell_names | 0 | ok |
| example | metadata | 0 | ok |
| example | projection | 0 | ok |
| example | gene_row_first | 0 | ok |
| example | gene_row_repeat | 20 | ok |
| example | gene_block_12 | 10 | ok |
| example | mean_expression_12 | 10 | ok |
| example | cells_10pct_genes_12 | 0 | ok |
| example | linked_bundle_build | 0 | ok |
| example | linked_bundle_json | 10 | ok |
| demo_trekker | read_crb | 50 | ok |
| demo_trekker | cell_names | 0 | ok |
| demo_trekker | metadata | 0 | ok |
| demo_trekker | projection | 0 | ok |
| demo_trekker | gene_row_first | 0 | ok |
| demo_trekker | gene_row_repeat | 20 | ok |
| demo_trekker | gene_block_12 | 0 | ok |
| demo_trekker | mean_expression_12 | 10 | ok |
| demo_trekker | cells_10pct_genes_12 | 0 | ok |
| demo_trekker | linked_bundle_build | 0 | ok |
| demo_trekker | linked_bundle_json | 50 | ok |

