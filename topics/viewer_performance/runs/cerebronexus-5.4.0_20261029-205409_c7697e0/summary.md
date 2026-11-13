# Viewer performance: CerebroNexus 5.4.0

- Run: `cerebronexus-5.4.0_20261029-205409_c7697e0`
- Revision: HEAD (`c7697e0bd5cf`)
- Rounds: 3; sessions: 51, failed twice: 0
- Datasets: 1m, ren, cosmx, example, demo_trekker
- Machine: NUIOI; Microsoft Windows 11 Pro 10.0.26300; 12th Gen Intel(R) Core(TM) i9-12900K
- R version 4.6.1 (2026-06-24 ucrt); Chrome/156.0.8078.48, drawn by ANGLE (NVIDIA, NVIDIA GeForce RTX 4060 (0x00002882) Direct3D11 vs_5_0 ps_5_0, D3D11); webgpu

## Problems

- not finished in every round: extra_material.content, spatial.section, markerGenes.table, enrichedPathways.table

## Pages and actions

Medians over the rounds that finished. Visual = click to the last frame that changes (the KPI); range = fastest and slowest round.

| Page | Visit | Dataset | Status | Visual (ms) | Range (ms) | Server busy (ms) | Trail (ms) | Largest msg (MB) | Loader (ms) | R peak (MiB) | Chrome peak (MiB) | Value |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| loadData | initial | 1m | ok | 726 | 524-871 | 550 | 10 | <0.1 | 517 | 600 | 679 |  |
| loadData.switch | action | 1m | ok | 567 | 513-624 | 476 | 5,038 | <0.1 | 536 | 597 | 680 | Demo dataset |
| loadData.switch_back | action | 1m | ok | 564 | 505-566 | 239 | 0 | <0.1 | 526 | 596 | 639 | Second dataset |
| overview | cold | 1m | ok | 1,978 | 1,655-2,335 | 4,584 | 1,076 | 29.0 | 1,734 | 924 | 922 |  |
| overview.colour_by | action | 1m | ok | 440 | 411-456 | 439 | 0 | <0.1 | 0 | 939 | 849 | sample |
| overview.zoom | action | 1m | ok | 130 | 126-137 | 0 | 0 | <0.1 | 0 | 683 | 813 | in |
| overview.lasso | action | 1m | ok | 3,773 | 3,518-3,985 | 4,088 | 0 | 5.6 | 0 | 1,289 | 842 | middle 40% |
| coordinated_views | cold | 1m | ok | 3,783 | 3,548-4,438 | 3,527 | 2,405 | <0.1 | 3,550 | 863 | 873 |  |
| coordinated_views.colour_by | action | 1m | ok | 173 | 171-208 | 61 | 0 | 1.3 | 0 | 654 | 861 | sample |
| groups | cold | 1m | ok | 1,309 | 1,262-1,645 | 1,266 | 5,136 | 0.4 | 1,250 | 628 | 702 |  |
| groups.group | action | 1m | ok | 1,842 | 1,791-3,529 | 1,832 | 0 | 3.9 | 0 | 1,045 | 721 | seurat_clusters |
| groups.plot_type | action | 1m | ok | 167 | 162-211 | 43 | 0 | <0.1 | 0 | 670 | 790 | Sankey plot |
| groups.percent | action | 1m | ok | 362 | 326-533 | 220 | 1,254 | <0.1 | 0 | 670 | 756 | on |
| geneExpression | cold | 1m | ok | 2,350 | 2,340-3,750 | 9,175 | 0 | <0.1 | 2,180 | 1,029 | 827 |  |
| geneExpression.gene | action | 1m | ok | 1,148 | 1,078-1,405 | 888 | 0 | 5.5 | 0 | 1,161 | 773 | 0610007P14Rik |
| geneExpression.genes12 | action | 1m | ok | 4,315 | 4,279-5,174 | 3,827 | 0 | 10.5 | 0 | 1,627 | 731 | 0610007P14Rik 0610009B22Rik 0610009L18Rik 0610009O20Rik 0610010F05Rik 0610010K14Rik 0610011F06Rik 0610012D04Rik 0610012G03Rik 0610025J13Rik 0610030E20Rik 0610031O16Rik |
| trajectory | cold | 1m | ok | 2,131 | 2,059-3,259 | 2,073 | 3,754 | <0.1 | 1,847 | 602 | 863 |  |
| trajectory.colour_by | action | 1m | ok | 312 | 227-475 | 354 | 0 | <0.1 | 0 | 597 | 795 | state |
| color_management | cold | 1m | ok | 1,060 | 1,040-1,621 | 826 | 4,807 | <0.1 | 1,033 | 600 | 684 |  |
| geneIdConversion | cold | 1m | ok | 1,332 | 1,305-2,094 | 1,106 | 4,734 | 0.3 | 1,334 | 625 | 689 |  |
| about | cold | 1m | ok | 820 | 774-1,051 | 530 | 5,136 | <0.1 | 767 | 599 | 659 |  |
| immune_repertoire | cold | ren | ok | 8,149 | 7,863-11,875 | 11,021 | 0 | 24.8 | 6,301 | 1,235 | 785 |  |
| immune_repertoire.tab | action | ren | ok | 3,693 | 3,464-9,328 | 3,588 | 0 | 0.2 | 0 | 1,323 | 971 | Abundance |
| hla_tcr_motifs | cold | ren | ok | 4,188 | 4,124-5,662 | 4,557 | 2,056 | 0.1 | 3,950 | 932 | 722 |  |
| hla_tcr_motifs.colour_by | action | ren | ok | 479 | 374-624 | 510 | 0 | <0.1 | 0 | 971 | 656 | major_type |
| extra_material | cold | ren | ok | 1,366 | 1,333-2,019 | 1,242 | 5,215 | <0.1 | 1,262 | 510 | 709 |  |
| extra_material.content | action | ren | unavailable (0/3 ok) | - | - | - | - | - | - | - | - |  |
| spatial | cold | cosmx | ok | 3,727 | 3,719-4,316 | 5,258 | 1,205 | 2.0 | 3,467 | 904 | 711 |  |
| spatial.section | action | cosmx | unavailable (0/3 ok) | - | - | - | - | - | - | - | - |  |
| markerGenes | cold | example | ok | 890 | 838-907 | 608 | 0 | <0.1 | 816 | 391 | 696 |  |
| markerGenes.table | action | example | unavailable (0/3 ok) | - | - | - | - | - | - | - | - |  |
| mostExpressedGenes | cold | example | ok | 852 | 838-966 | 742 | 0 | <0.1 | 800 | 392 | 693 |  |
| mostExpressedGenes.group | action | example | ok | 548 | 499-565 | 470 | 1,151 | <0.1 | 0 | 392 | 674 | seurat_clusters |
| enrichedPathways | cold | example | ok | 929 | 900-1,396 | 687 | 3,312 | <0.1 | 850 | 393 | 696 |  |
| enrichedPathways.table | action | example | unavailable (0/3 ok) | - | - | - | - | - | - | - | - |  |
| trekker | cold | demo_trekker | ok | 668 | 634-1,387 | 796 | 3,677 | 0.1 | 634 | 393 | 692 |  |
| trekker.colour_by | action | demo_trekker | ok | 16 | 15-26 | 0 | 706 | 0.1 | 0 | 391 | 609 | cluster |

## Memory per dataset

Largest peak of any session on the dataset (R server tree, Chrome tree) and the median server start.

| Dataset | Sessions | R peak (MiB) | Chrome peak (MiB) | Server start (s) |
|---|---|---|---|---|
| 1m | 27 | 1,627 | 946 | 7.2 |
| ren | 9 | 1,323 | 978 | 4.4 |
| cosmx | 3 | 904 | 725 | 4.9 |
| example | 9 | 398 | 709 | 2.9 |
| demo_trekker | 3 | 397 | 704 | 2.9 |

## Server steps

The R work behind the pages, without a browser (one fresh R process per dataset and round).

| Dataset | Step | Time (ms) | Status |
|---|---|---|---|
| 1m | read_crb | 7,690 | ok |
| 1m | cell_names | 0 | ok |
| 1m | metadata | 10 | ok |
| 1m | projection | 0 | ok |
| 1m | gene_row_first | 60 | ok |
| 1m | gene_row_repeat | 80 | ok |
| 1m | gene_block_12 | 10 | ok |
| 1m | mean_expression_12 | 920 | ok |
| 1m | cells_10pct_genes_12 | 440 | ok |
| 1m | linked_bundle_build | 860 | ok |
| 1m | linked_bundle_json | 7,220 | ok |
| ren | read_crb | 6,570 | ok |
| ren | cell_names | 0 | ok |
| ren | metadata | 0 | ok |
| ren | projection | 0 | ok |
| ren | gene_row_first | 40 | ok |
| ren | gene_row_repeat | 60 | ok |
| ren | gene_block_12 | 30 | ok |
| ren | mean_expression_12 | 930 | ok |
| ren | cells_10pct_genes_12 | 420 | ok |
| ren | linked_bundle_build | 9,730 | ok |
| ren | linked_bundle_json | 9,720 | ok |
| cosmx | read_crb | 5,050 | ok |
| cosmx | cell_names | 0 | ok |
| cosmx | metadata | 10 | ok |
| cosmx | projection | 0 | ok |
| cosmx | gene_row_first | 30 | ok |
| cosmx | gene_row_repeat | 50 | ok |
| cosmx | gene_block_12 | 30 | ok |
| cosmx | mean_expression_12 | 440 | ok |
| cosmx | cells_10pct_genes_12 | 290 | ok |
| cosmx | linked_bundle_build | 1,420 | ok |
| cosmx | linked_bundle_json | 7,100 | ok |
| example | read_crb | 50 | ok |
| example | cell_names | 0 | ok |
| example | metadata | 0 | ok |
| example | projection | 0 | ok |
| example | gene_row_first | 0 | ok |
| example | gene_row_repeat | 30 | ok |
| example | gene_block_12 | 0 | ok |
| example | mean_expression_12 | 0 | ok |
| example | cells_10pct_genes_12 | 0 | ok |
| example | linked_bundle_build | 0 | ok |
| example | linked_bundle_json | 20 | ok |
| demo_trekker | read_crb | 60 | ok |
| demo_trekker | cell_names | 0 | ok |
| demo_trekker | metadata | 0 | ok |
| demo_trekker | projection | 0 | ok |
| demo_trekker | gene_row_first | 0 | ok |
| demo_trekker | gene_row_repeat | 30 | ok |
| demo_trekker | gene_block_12 | 0 | ok |
| demo_trekker | mean_expression_12 | 20 | ok |
| demo_trekker | cells_10pct_genes_12 | 0 | ok |
| demo_trekker | linked_bundle_build | 20 | ok |
| demo_trekker | linked_bundle_json | 40 | ok |

