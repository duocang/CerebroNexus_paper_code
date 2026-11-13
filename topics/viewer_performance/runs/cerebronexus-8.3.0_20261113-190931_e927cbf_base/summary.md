# Viewer performance: CerebroNexus 8.3.0

- Run: `cerebronexus-8.3.0_20261113-190931_e927cbf_base`
- Revision: e927cbf180fb1a50cf783245ab580e83a1334764 (`e927cbf180fb`)
- Rounds: 5; sessions: 95, failed twice: 0
- Datasets: 1m, ren, cosmx, example, demo_trekker
- Machine: NUIOI; Microsoft Windows 11 Pro 10.0.26300; 12th Gen Intel(R) Core(TM) i9-12900K
- R version 4.6.1 (2026-06-24 ucrt); Chrome/157.0.8103.52, drawn by ANGLE (NVIDIA, NVIDIA GeForce RTX 4060 (0x00002882) Direct3D11 vs_5_0 ps_5_0, D3D11); webgpu
- Measured together with `cerebronexus-8.3.0_20261113-190931_e927cbf` (this run is the baseline), session by session in turn
- Host before the sessions: median 9.5 % CPU, at most 98.7 %; waited 1242 s in all

## Problems

- the CPU canary moved by a factor 1.68 during the run (370, 380, 370, 510, 620, 500 ms): the machine was busy with something else or changed its speed
- 1 of 95 sessions started on a busy machine (above 15 % CPU after waiting 600 s): schedule.tsv, host_idle
- not finished in every round: immune_repertoire, extra_material.content, markerGenes.table

## Pages and actions

Medians over the rounds that finished. Visual = click to the last frame that changes (the KPI); range = fastest and slowest round.
On the `first_start` and `first_plot` rows both times run from Chrome's navigation to the Viewer instead of from a click: First plot = to the first frame that shows the projection, Visual = to the last frame that changes. `first_start`: the server's cache directory was emptied before the session; `first_plot`: it held what earlier sessions left.

| Page | Visit | Dataset | Status | Visual (ms) | First plot (ms) | Range (ms) | Server busy (ms) | Trail (ms) | Largest msg (MB) | Loader (ms) | R peak (MiB) | Chrome peak (MiB) | Value |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| loadData | initial | 1m | ok | 39 | - | 30-51 | 10,197 | 11,350 | <0.1 | 0 | 886 | 594 |  |
| loadData.switch | action | 1m | ok | 424 | - | 360-712 | 2,091 | 1,612 | <0.1 | 411 | 778 | 644 | Demo dataset |
| loadData.switch_back | action | 1m | ok | 374 | - | 12-452 | 1,217 | 189 | <0.1 | 387 | 838 | 662 | Second dataset |
| overview | cold | 1m | ok | 787 | - | 402-1,227 | 2,499 | 749 | <0.1 | 423 | 742 | 851 |  |
| overview | first_start | 1m | ok | 4,135 | 4,135 | 3,475-5,948 | 11,420 | 7,220 | <0.1 | 1,525 | 1,061 | 802 |  |
| overview | first_plot | 1m | ok | 2,749 | 2,867 | 2,171-3,333 | 10,041 | 10,451 | <0.1 | 1,662 | 735 | 813 |  |
| overview.colour_by | action | 1m | ok | 165 | - | 141-373 | 0 | 0 | <0.1 | 0 | 761 | 850 | sample |
| overview.zoom | action | 1m | ok | 8 | - | 6-16 | 658 | 0 | <0.1 | 0 | 761 | 689 | in |
| overview.lasso | action | 1m | ok | 300 | - | 123-391 | 2,593 | 1,593 | 0.2 | 0 | 769 | 765 | middle 40% |
| coordinated_views | cold | 1m | ok | 591 | - | 198-888 | 2,584 | 944 | <0.1 | 625 | 742 | 840 |  |
| coordinated_views.colour_by | action | 1m | ok | 13 | - | 10-235 | 220 | 0 | 1.3 | 0 | 718 | 850 | sample |
| groups | cold | 1m | ok | 303 | - | 270-353 | 377 | 0 | <0.1 | 156 | 669 | 618 |  |
| groups.group | action | 1m | ok | 149 | - | 137-190 | 2,088 | 1,269 | <0.1 | 0 | 718 | 619 | seurat_clusters |
| groups.plot_type | action | 1m | ok | 9 | - | 8-11 | 0 | 0 | <0.1 | 0 | 685 | 612 | Sankey plot |
| groups.percent | action | 1m | ok | 7 | - | 6-10 | 1,718 | 1,067 | <0.1 | 0 | 684 | 653 | on |
| geneExpression | cold | 1m | ok | 720 | - | 493-1,011 | 1,149 | 0 | <0.1 | 346 | 733 | 875 |  |
| geneExpression.gene | action | 1m | ok | 754 | - | 276-885 | 532 | 0 | 5.5 | 0 | 790 | 1,036 | 0610007P14Rik |
| geneExpression.genes12 | action | 1m | ok | 829 | - | 803-969 | 671 | 0 | 10.5 | 0 | 977 | 1,009 | 0610007P14Rik 0610009B22Rik 0610009L18Rik 0610009O20Rik 0610010F05Rik 0610010K14Rik 0610011F06Rik 0610012D04Rik 0610012G03Rik 0610025J13Rik 0610030E20Rik 0610031O16Rik |
| trajectory | cold | 1m | ok | 666 | - | 509-758 | 1,144 | 0 | 5.1 | 535 | 898 | 899 |  |
| trajectory.colour_by | action | 1m | ok | 13 | - | 11-364 | 466 | 0 | 5.1 | 0 | 917 | 978 | state |
| color_management | cold | 1m | ok | 456 | - | 443-622 | 396 | 0 | <0.1 | 281 | 582 | 610 |  |
| geneIdConversion | cold | 1m | ok | 621 | - | 544-676 | 1,034 | 0 | 0.3 | 437 | 599 | 619 |  |
| about | cold | 1m | ok | 150 | - | 126-231 | 2,376 | 1,357 | <0.1 | 0 | 537 | 593 |  |
| immune_repertoire | cold | ren | stuck_busy (4/5 ok) | 29,858 | - | 27,573-31,000 | 31,865 | 2,112 | 2.6 | 28,389 | 1,759 | 735 |  |
| immune_repertoire.tab | action | ren | ok | 1,601 | - | 1,296-2,314 | 1,720 | 0 | 0.2 | 0 | 1,676 | 977 | Abundance |
| hla_tcr_motifs | cold | ren | ok | 733 | - | 545-850 | 3,022 | 1,233 | <0.1 | 595 | 698 | 656 |  |
| hla_tcr_motifs.colour_by | action | ren | ok | 13 | - | 11-14 | 95 | 0 | <0.1 | 0 | 687 | 660 | major_type |
| extra_material | cold | ren | ok | 606 | - | 509-893 | 798 | 0 | <0.1 | 502 | 683 | 659 |  |
| extra_material.content | action | ren | unavailable (0/5 ok) | - | - | - | - | - | - | - | - | - |  |
| spatial | cold | cosmx | ok | 945 | - | 889-1,029 | 1,563 | 0 | 0.1 | 433 | 983 | 749 |  |
| spatial.section | action | cosmx | ok | 268 | - | 237-523 | 2,046 | 896 | 0.1 | 0 | 952 | 752 | spatial_projection_sample=Lung5_Rep2 |
| markerGenes | cold | example | ok | 451 | - | 339-657 | 1,857 | 657 | <0.1 | 63 | 554 | 627 |  |
| markerGenes.table | action | example | unavailable (0/5 ok) | - | - | - | - | - | - | - | - | - |  |
| mostExpressedGenes | cold | example | ok | 579 | - | 414-1,039 | 596 | 0 | <0.1 | 91 | 578 | 612 |  |
| mostExpressedGenes.group | action | example | ok | 182 | - | 138-401 | 448 | 0 | <0.1 | 0 | 572 | 631 | seurat_clusters |
| enrichedPathways | cold | example | ok | 924 | - | 583-3,464 | 896 | 0 | <0.1 | 520 | 576 | 625 |  |
| enrichedPathways.table | action | example | ok | 196 | - | 153-466 | 212 | 0 | <0.1 | 0 | 570 | 636 | enriched_pathways_selected_method=cerebro_GSVA |
| trekker | cold | demo_trekker | ok | 337 | - | 134-424 | 574 | 0 | 0.1 | 116 | 547 | 622 |  |
| trekker.colour_by | action | demo_trekker | ok | 12 | - | 10-109 | 348 | 0 | 0.1 | 0 | 561 | 622 | cluster |

## Memory per dataset

Largest peak of any session on the dataset (R server tree, Chrome tree) and the median server start.

| Dataset | Sessions | R peak (MiB) | Chrome peak (MiB) | Server start (s) |
|---|---|---|---|---|
| 1m | 55 | 1,065 | 1,050 | 1.1 |
| ren | 15 | 1,774 | 984 | 1.1 |
| cosmx | 5 | 983 | 765 | 1.1 |
| example | 15 | 578 | 656 | 1.1 |
| demo_trekker | 5 | 567 | 635 | 1.1 |

## Server steps

The R work behind the pages, without a browser (one fresh R process per dataset and round).

| Dataset | Step | Time (ms) | Status |
|---|---|---|---|
| 1m | read_crb | 3,250 | ok |
| 1m | cell_names | 4,840 | ok |
| 1m | metadata | 0 | ok |
| 1m | projection | 0 | ok |
| 1m | gene_row_first | 50 | ok |
| 1m | gene_row_repeat | 100 | ok |
| 1m | gene_block_12 | 30 | ok |
| 1m | mean_expression_12 | 980 | ok |
| 1m | cells_10pct_genes_12 | 440 | ok |
| 1m | linked_bundle_build | 870 | ok |
| 1m | linked_bundle_json | 7,020 | ok |
| ren | read_crb | 3,190 | ok |
| ren | cell_names | 5,870 | ok |
| ren | metadata | 0 | ok |
| ren | projection | 0 | ok |
| ren | gene_row_first | 60 | ok |
| ren | gene_row_repeat | 70 | ok |
| ren | gene_block_12 | 40 | ok |
| ren | mean_expression_12 | 1,860 | ok |
| ren | cells_10pct_genes_12 | 390 | ok |
| ren | linked_bundle_build | 10,080 | ok |
| ren | linked_bundle_json | 9,160 | ok |
| cosmx | read_crb | 1,030 | ok |
| cosmx | cell_names | 3,760 | ok |
| cosmx | metadata | 0 | ok |
| cosmx | projection | 0 | ok |
| cosmx | gene_row_first | 30 | ok |
| cosmx | gene_row_repeat | 50 | ok |
| cosmx | gene_block_12 | 30 | ok |
| cosmx | mean_expression_12 | 460 | ok |
| cosmx | cells_10pct_genes_12 | 220 | ok |
| cosmx | linked_bundle_build | 1,750 | ok |
| cosmx | linked_bundle_json | 7,440 | ok |
| example | read_crb | 50 | ok |
| example | cell_names | 500 | ok |
| example | metadata | 0 | ok |
| example | projection | 0 | ok |
| example | gene_row_first | 0 | ok |
| example | gene_row_repeat | 20 | ok |
| example | gene_block_12 | 0 | ok |
| example | mean_expression_12 | 10 | ok |
| example | cells_10pct_genes_12 | 0 | ok |
| example | linked_bundle_build | 170 | ok |
| example | linked_bundle_json | 30 | ok |
| demo_trekker | read_crb | 50 | ok |
| demo_trekker | cell_names | 480 | ok |
| demo_trekker | metadata | 0 | ok |
| demo_trekker | projection | 0 | ok |
| demo_trekker | gene_row_first | 0 | ok |
| demo_trekker | gene_row_repeat | 20 | ok |
| demo_trekker | gene_block_12 | 0 | ok |
| demo_trekker | mean_expression_12 | 0 | ok |
| demo_trekker | cells_10pct_genes_12 | 0 | ok |
| demo_trekker | linked_bundle_build | 190 | ok |
| demo_trekker | linked_bundle_json | 40 | ok |

