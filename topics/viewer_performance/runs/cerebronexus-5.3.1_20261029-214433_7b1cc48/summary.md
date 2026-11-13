# Viewer performance: CerebroNexus 5.3.1

- Run: `cerebronexus-5.3.1_20261029-214433_7b1cc48`
- Revision: master (`7b1cc488bfc0`)
- Rounds: 3; sessions: 51, failed twice: 0
- Datasets: 1m, ren, cosmx, example, demo_trekker
- Machine: NUIOI; Microsoft Windows 11 Pro 10.0.26300; 12th Gen Intel(R) Core(TM) i9-12900K
- R version 4.6.1 (2026-06-24 ucrt); Chrome/156.0.8078.48, drawn by ANGLE (NVIDIA, NVIDIA GeForce RTX 4060 (0x00002882) Direct3D11 vs_5_0 ps_5_0, D3D11); webgpu

## Problems

- the CPU canary changed by a factor 1.50 between start and end: the machine was busy with something else
- not finished in every round: extra_material.content, markerGenes.table

## Pages and actions

Medians over the rounds that finished. Visual = click to the last frame that changes (the KPI); range = fastest and slowest round.

| Page | Visit | Dataset | Status | Visual (ms) | Range (ms) | Server busy (ms) | Trail (ms) | Largest msg (MB) | Loader (ms) | R peak (MiB) | Chrome peak (MiB) | Value |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| loadData | initial | 1m | ok | 1,002 | 753-1,029 | 896 | 17 | <0.1 | 533 | 607 | 666 |  |
| loadData.switch | action | 1m | ok | 617 | 475-666 | 581 | 4,193 | <0.1 | 663 | 596 | 666 | Demo dataset |
| loadData.switch_back | action | 1m | ok | 525 | 494-594 | 314 | 518 | <0.1 | 525 | 596 | 629 | Second dataset |
| overview | cold | 1m | ok | 2,510 | 1,686-2,706 | 5,523 | 0 | 29.0 | 2,263 | 923 | 877 |  |
| overview.colour_by | action | 1m | ok | 249 | 185-379 | 241 | 0 | <0.1 | 0 | 944 | 870 | sample |
| overview.zoom | action | 1m | ok | 151 | 134-159 | 0 | 0 | <0.1 | 0 | 943 | 839 | in |
| overview.lasso | action | 1m | ok | 3,439 | 610-3,836 | 4,011 | 0 | 5.7 | 0 | 1,291 | 796 | middle 40% |
| coordinated_views | cold | 1m | ok | 3,559 | 3,298-4,053 | 3,557 | 2,308 | <0.1 | 3,334 | 863 | 867 |  |
| coordinated_views.colour_by | action | 1m | ok | 242 | 154-265 | 110 | 0 | 1.3 | 0 | 654 | 860 | sample |
| groups | cold | 1m | ok | 1,253 | 1,217-1,327 | 1,147 | 4,590 | 0.4 | 1,163 | 628 | 703 |  |
| groups.group | action | 1m | ok | 1,973 | 1,951-2,106 | 1,932 | 0 | 3.9 | 0 | 1,046 | 713 | seurat_clusters |
| groups.plot_type | action | 1m | ok | 144 | 142-173 | 0 | 0 | <0.1 | 0 | 666 | 772 | Sankey plot |
| groups.percent | action | 1m | ok | 135 | 133-141 | 96 | 0 | <0.1 | 0 | 666 | 782 | on |
| geneExpression | cold | 1m | ok | 2,470 | 2,171-2,546 | 9,032 | 0 | <0.1 | 2,284 | 1,086 | 827 |  |
| geneExpression.gene | action | 1m | ok | 950 | 944-1,122 | 969 | 0 | 5.5 | 0 | 1,187 | 791 | 0610007P14Rik |
| geneExpression.genes12 | action | 1m | ok | 4,311 | 4,256-4,742 | 3,859 | 0 | 10.5 | 0 | 1,629 | 771 | 0610007P14Rik 0610009B22Rik 0610009L18Rik 0610009O20Rik 0610010F05Rik 0610010K14Rik 0610011F06Rik 0610012D04Rik 0610012G03Rik 0610025J13Rik 0610030E20Rik 0610031O16Rik |
| trajectory | cold | 1m | ok | 1,860 | 1,828-1,909 | 1,861 | 3,844 | <0.1 | 1,666 | 602 | 859 |  |
| trajectory.colour_by | action | 1m | ok | 204 | 195-235 | 283 | 0 | <0.1 | 0 | 597 | 803 | state |
| color_management | cold | 1m | ok | 1,027 | 971-1,116 | 747 | 4,685 | <0.1 | 1,001 | 600 | 679 |  |
| geneIdConversion | cold | 1m | ok | 1,236 | 1,151-1,240 | 933 | 4,227 | 0.3 | 1,192 | 634 | 687 |  |
| about | cold | 1m | ok | 750 | 711-843 | 537 | 4,632 | <0.1 | 750 | 599 | 668 |  |
| immune_repertoire | cold | ren | ok | 7,882 | 7,124-8,311 | 10,952 | 0 | 24.8 | 6,017 | 1,221 | 801 |  |
| immune_repertoire.tab | action | ren | ok | 3,838 | 3,500-3,857 | 3,498 | 0 | 0.2 | 0 | 1,322 | 949 | Abundance |
| hla_tcr_motifs | cold | ren | ok | 4,114 | 3,933-5,097 | 4,574 | 1,728 | <0.1 | 3,800 | 950 | 725 |  |
| hla_tcr_motifs.colour_by | action | ren | ok | 511 | 403-1,161 | 546 | 0 | <0.1 | 0 | 970 | 644 | major_type |
| extra_material | cold | ren | ok | 1,208 | 1,108-1,473 | 1,121 | 4,210 | <0.1 | 1,150 | 507 | 704 |  |
| extra_material.content | action | ren | unavailable (0/3 ok) | - | - | - | - | - | - | - | - |  |
| spatial | cold | cosmx | ok | 3,945 | 3,497-4,656 | 5,291 | 1,623 | 2.0 | 3,684 | 1,051 | 734 |  |
| spatial.section | action | cosmx | ok | 2,896 | 2,873-3,494 | 3,192 | 0 | 2.2 | 0 | 1,056 | 653 | spatial_projection_sample=Lung5_Rep2 |
| markerGenes | cold | example | ok | 923 | 900-1,117 | 723 | 0 | <0.1 | 867 | 391 | 695 |  |
| markerGenes.table | action | example | unavailable (0/3 ok) | - | - | - | - | - | - | - | - |  |
| mostExpressedGenes | cold | example | ok | 1,037 | 843-1,170 | 727 | 0 | <0.1 | 917 | 392 | 685 |  |
| mostExpressedGenes.group | action | example | ok | 625 | 487-655 | 457 | 561 | <0.1 | 0 | 392 | 668 | seurat_clusters |
| enrichedPathways | cold | example | ok | 1,132 | 908-1,226 | 792 | 4,656 | <0.1 | 1,051 | 392 | 704 |  |
| enrichedPathways.table | action | example | ok | 284 | 234-285 | 0 | 37 | <0.1 | 0 | 389 | 618 | enriched_pathways_selected_method=cerebro_GSVA |
| trekker | cold | demo_trekker | ok | 671 | 610-889 | 905 | 4,303 | 0.1 | 650 | 391 | 703 |  |
| trekker.colour_by | action | demo_trekker | ok | 18 | 17-19 | 0 | 614 | 0.1 | 0 | 390 | 620 | cluster |

## Memory per dataset

Largest peak of any session on the dataset (R server tree, Chrome tree) and the median server start.

| Dataset | Sessions | R peak (MiB) | Chrome peak (MiB) | Server start (s) |
|---|---|---|---|---|
| 1m | 27 | 1,629 | 901 | 6.8 |
| ren | 9 | 1,322 | 1,030 | 4.4 |
| cosmx | 3 | 1,057 | 743 | 4.9 |
| example | 9 | 397 | 713 | 2.9 |
| demo_trekker | 3 | 397 | 713 | 2.9 |

## Server steps

The R work behind the pages, without a browser (one fresh R process per dataset and round).

| Dataset | Step | Time (ms) | Status |
|---|---|---|---|
| 1m | read_crb | 5,890 | ok |
| 1m | cell_names | 0 | ok |
| 1m | metadata | 0 | ok |
| 1m | projection | 0 | ok |
| 1m | gene_row_first | 50 | ok |
| 1m | gene_row_repeat | 70 | ok |
| 1m | gene_block_12 | 20 | ok |
| 1m | mean_expression_12 | 690 | ok |
| 1m | cells_10pct_genes_12 | 350 | ok |
| 1m | linked_bundle_build | 670 | ok |
| 1m | linked_bundle_json | 5,500 | ok |
| ren | read_crb | 5,110 | ok |
| ren | cell_names | 0 | ok |
| ren | metadata | 0 | ok |
| ren | projection | 0 | ok |
| ren | gene_row_first | 60 | ok |
| ren | gene_row_repeat | 70 | ok |
| ren | gene_block_12 | 20 | ok |
| ren | mean_expression_12 | 1,050 | ok |
| ren | cells_10pct_genes_12 | 450 | ok |
| ren | linked_bundle_build | 7,370 | ok |
| ren | linked_bundle_json | 8,160 | ok |
| cosmx | read_crb | 4,830 | ok |
| cosmx | cell_names | 0 | ok |
| cosmx | metadata | 0 | ok |
| cosmx | projection | 0 | ok |
| cosmx | gene_row_first | 20 | ok |
| cosmx | gene_row_repeat | 40 | ok |
| cosmx | gene_block_12 | 30 | ok |
| cosmx | mean_expression_12 | 380 | ok |
| cosmx | cells_10pct_genes_12 | 220 | ok |
| cosmx | linked_bundle_build | 1,060 | ok |
| cosmx | linked_bundle_json | 5,880 | ok |
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
| demo_trekker | read_crb | 50 | ok |
| demo_trekker | cell_names | 0 | ok |
| demo_trekker | metadata | 0 | ok |
| demo_trekker | projection | 0 | ok |
| demo_trekker | gene_row_first | 0 | ok |
| demo_trekker | gene_row_repeat | 20 | ok |
| demo_trekker | gene_block_12 | 0 | ok |
| demo_trekker | mean_expression_12 | 0 | ok |
| demo_trekker | cells_10pct_genes_12 | 0 | ok |
| demo_trekker | linked_bundle_build | 0 | ok |
| demo_trekker | linked_bundle_json | 30 | ok |

