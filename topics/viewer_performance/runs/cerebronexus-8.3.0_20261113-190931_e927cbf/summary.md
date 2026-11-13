# Viewer performance: CerebroNexus 8.3.0

- Run: `cerebronexus-8.3.0_20261113-190931_e927cbf`
- Revision: e927cbf180fb1a50cf783245ab580e83a1334764 (`e927cbf180fb`)
- Rounds: 5; sessions: 95, failed twice: 0
- Datasets: 1m, ren, cosmx, example, demo_trekker
- Machine: NUIOI; Microsoft Windows 11 Pro 10.0.26300; 12th Gen Intel(R) Core(TM) i9-12900K
- R version 4.6.1 (2026-06-24 ucrt); Chrome/157.0.8103.52, drawn by ANGLE (NVIDIA, NVIDIA GeForce RTX 4060 (0x00002882) Direct3D11 vs_5_0 ps_5_0, D3D11); webgpu
- Measured together with `cerebronexus-8.3.0_20261113-190931_e927cbf_base` (this run is the candidate), session by session in turn
- Host before the sessions: median 10.3 % CPU, at most 54.1 %; waited 1737 s in all

## Problems

- the CPU canary moved by a factor 1.68 during the run (370, 380, 370, 510, 620, 500 ms): the machine was busy with something else or changed its speed
- 2 of 95 sessions started on a busy machine (above 15 % CPU after waiting 600 s): schedule.tsv, host_idle
- not finished in every round: overview (first_plot), immune_repertoire, extra_material.content, markerGenes.table, enrichedPathways.table

## Pages and actions

Medians over the rounds that finished. Visual = click to the last frame that changes (the KPI); range = fastest and slowest round.
On the `first_start` and `first_plot` rows both times run from Chrome's navigation to the Viewer instead of from a click: First plot = to the first frame that shows the projection, Visual = to the last frame that changes. `first_start`: the server's cache directory was emptied before the session; `first_plot`: it held what earlier sessions left.

| Page | Visit | Dataset | Status | Visual (ms) | First plot (ms) | Range (ms) | Server busy (ms) | Trail (ms) | Largest msg (MB) | Loader (ms) | R peak (MiB) | Chrome peak (MiB) | Value |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| loadData | initial | 1m | ok | 42 | - | 30-581 | 10,196 | 11,409 | <0.1 | 0 | 880 | 584 |  |
| loadData.switch | action | 1m | ok | 349 | - | 19-638 | 1,920 | 2,268 | <0.1 | 396 | 776 | 638 | Demo dataset |
| loadData.switch_back | action | 1m | ok | 411 | - | 12-441 | 1,308 | 413 | <0.1 | 378 | 838 | 654 | Second dataset |
| overview | cold | 1m | ok | 618 | - | 286-651 | 3,516 | 2,000 | <0.1 | 504 | 746 | 844 |  |
| overview | first_start | 1m | ok | 4,007 | 4,007 | 3,331-5,275 | 11,703 | 6,806 | <0.1 | 1,357 | 1,061 | 809 |  |
| overview | first_plot | 1m | no_plot (4/5 ok) | 2,593 | 2,748 | 2,489-2,911 | 9,454 | 8,361 | <0.1 | 1,563 | 725 | 821 |  |
| overview.colour_by | action | 1m | ok | 145 | - | 142-167 | 358 | 0 | <0.1 | 0 | 761 | 825 | sample |
| overview.zoom | action | 1m | ok | 8 | - | 6-15 | 2,176 | 1,475 | <0.1 | 0 | 761 | 739 | in |
| overview.lasso | action | 1m | ok | 328 | - | 85-452 | 1,784 | 676 | 0.2 | 0 | 769 | 769 | middle 40% |
| coordinated_views | cold | 1m | ok | 606 | - | 599-987 | 2,850 | 1,130 | <0.1 | 631 | 742 | 830 |  |
| coordinated_views.colour_by | action | 1m | ok | 22 | - | 13-170 | 686 | 0 | 1.3 | 0 | 718 | 849 | sample |
| groups | cold | 1m | ok | 315 | - | 295-439 | 544 | 0 | <0.1 | 249 | 669 | 620 |  |
| groups.group | action | 1m | ok | 156 | - | 124-174 | 221 | 0 | <0.1 | 0 | 743 | 623 | seurat_clusters |
| groups.plot_type | action | 1m | ok | 9 | - | 8-18 | 1,998 | 1,335 | <0.1 | 0 | 684 | 700 | Sankey plot |
| groups.percent | action | 1m | ok | 8 | - | 6-13 | 861 | 116 | <0.1 | 0 | 684 | 596 | on |
| geneExpression | cold | 1m | ok | 604 | - | 451-761 | 1,855 | 0 | <0.1 | 356 | 731 | 860 |  |
| geneExpression.gene | action | 1m | ok | 582 | - | 419-741 | 575 | 0 | 5.5 | 0 | 781 | 1,019 | 0610007P14Rik |
| geneExpression.genes12 | action | 1m | ok | 848 | - | 768-1,004 | 751 | 0 | 10.5 | 0 | 976 | 994 | 0610007P14Rik 0610009B22Rik 0610009L18Rik 0610009O20Rik 0610010F05Rik 0610010K14Rik 0610011F06Rik 0610012D04Rik 0610012G03Rik 0610025J13Rik 0610030E20Rik 0610031O16Rik |
| trajectory | cold | 1m | ok | 708 | - | 561-1,740 | 2,465 | 670 | 5.1 | 567 | 902 | 885 |  |
| trajectory.colour_by | action | 1m | ok | 13 | - | 11-261 | 346 | 0 | 5.1 | 0 | 888 | 946 | state |
| color_management | cold | 1m | ok | 448 | - | 445-676 | 3,217 | 1,900 | <0.1 | 250 | 584 | 609 |  |
| geneIdConversion | cold | 1m | ok | 769 | - | 610-871 | 1,067 | 0 | 0.3 | 624 | 594 | 624 |  |
| about | cold | 1m | ok | 138 | - | 121-180 | 2,560 | 1,644 | <0.1 | 0 | 536 | 600 |  |
| immune_repertoire | cold | ren | stuck_busy (2/5 ok) | 28,288 | - | 26,441-30,134 | 29,253 | 467 | 2.6 | 26,832 | 1,699 | 732 |  |
| immune_repertoire.tab | action | ren | ok | 1,438 | - | 1,233-2,310 | 1,683 | 0 | 0.2 | 0 | 1,677 | 979 | Abundance |
| hla_tcr_motifs | cold | ren | ok | 706 | - | 608-911 | 1,198 | 0 | <0.1 | 599 | 700 | 660 |  |
| hla_tcr_motifs.colour_by | action | ren | ok | 14 | - | 11-16 | 470 | 0 | <0.1 | 0 | 686 | 669 | major_type |
| extra_material | cold | ren | ok | 581 | - | 510-757 | 891 | 0 | <0.1 | 502 | 684 | 656 |  |
| extra_material.content | action | ren | unavailable (0/5 ok) | - | - | - | - | - | - | - | - | - |  |
| spatial | cold | cosmx | ok | 1,026 | - | 814-1,032 | 1,337 | 0 | 0.1 | 419 | 982 | 742 |  |
| spatial.section | action | cosmx | ok | 322 | - | 278-357 | 517 | 0 | 0.1 | 0 | 954 | 749 | spatial_projection_sample=Lung5_Rep2 |
| markerGenes | cold | example | ok | 482 | - | 337-644 | 543 | 0 | <0.1 | 61 | 549 | 632 |  |
| markerGenes.table | action | example | unavailable (0/5 ok) | - | - | - | - | - | - | - | - | - |  |
| mostExpressedGenes | cold | example | ok | 542 | - | 429-747 | 566 | 0 | <0.1 | 94 | 578 | 614 |  |
| mostExpressedGenes.group | action | example | ok | 170 | - | 151-2,314 | 1,278 | 337 | <0.1 | 0 | 572 | 629 | seurat_clusters |
| enrichedPathways | cold | example | ok | 837 | - | 512-3,959 | 3,309 | 0 | <0.1 | 250 | 574 | 634 |  |
| enrichedPathways.table | action | example | unavailable (4/5 ok) | 185 | - | 170-310 | 1,580 | 1,105 | <0.1 | 0 | 574 | 639 | enriched_pathways_selected_method=cerebro_GSVA |
| trekker | cold | demo_trekker | ok | 362 | - | 140-643 | 3,715 | 3,044 | 0.1 | 4 | 540 | 634 |  |
| trekker.colour_by | action | demo_trekker | ok | 12 | - | 11-19 | 2,810 | 2,031 | 0.1 | 0 | 553 | 629 | cluster |

## Memory per dataset

Largest peak of any session on the dataset (R server tree, Chrome tree) and the median server start.

| Dataset | Sessions | R peak (MiB) | Chrome peak (MiB) | Server start (s) |
|---|---|---|---|---|
| 1m | 55 | 1,062 | 1,049 | 1.1 |
| ren | 15 | 1,763 | 987 | 1.1 |
| cosmx | 5 | 983 | 755 | 1.1 |
| example | 15 | 579 | 645 | 1.1 |
| demo_trekker | 5 | 577 | 651 | 1.1 |

## Server steps

The R work behind the pages, without a browser (one fresh R process per dataset and round).

| Dataset | Step | Time (ms) | Status |
|---|---|---|---|
| 1m | read_crb | 3,250 | ok |
| 1m | cell_names | 4,070 | ok |
| 1m | metadata | 0 | ok |
| 1m | projection | 0 | ok |
| 1m | gene_row_first | 70 | ok |
| 1m | gene_row_repeat | 90 | ok |
| 1m | gene_block_12 | 30 | ok |
| 1m | mean_expression_12 | 710 | ok |
| 1m | cells_10pct_genes_12 | 470 | ok |
| 1m | linked_bundle_build | 690 | ok |
| 1m | linked_bundle_json | 6,080 | ok |
| ren | read_crb | 2,400 | ok |
| ren | cell_names | 3,820 | ok |
| ren | metadata | 0 | ok |
| ren | projection | 0 | ok |
| ren | gene_row_first | 50 | ok |
| ren | gene_row_repeat | 60 | ok |
| ren | gene_block_12 | 30 | ok |
| ren | mean_expression_12 | 1,300 | ok |
| ren | cells_10pct_genes_12 | 330 | ok |
| ren | linked_bundle_build | 9,670 | ok |
| ren | linked_bundle_json | 10,770 | ok |
| cosmx | read_crb | 1,070 | ok |
| cosmx | cell_names | 3,760 | ok |
| cosmx | metadata | 0 | ok |
| cosmx | projection | 0 | ok |
| cosmx | gene_row_first | 30 | ok |
| cosmx | gene_row_repeat | 50 | ok |
| cosmx | gene_block_12 | 30 | ok |
| cosmx | mean_expression_12 | 480 | ok |
| cosmx | cells_10pct_genes_12 | 250 | ok |
| cosmx | linked_bundle_build | 1,830 | ok |
| cosmx | linked_bundle_json | 6,650 | ok |
| example | read_crb | 40 | ok |
| example | cell_names | 510 | ok |
| example | metadata | 0 | ok |
| example | projection | 0 | ok |
| example | gene_row_first | 0 | ok |
| example | gene_row_repeat | 10 | ok |
| example | gene_block_12 | 0 | ok |
| example | mean_expression_12 | 0 | ok |
| example | cells_10pct_genes_12 | 0 | ok |
| example | linked_bundle_build | 170 | ok |
| example | linked_bundle_json | 30 | ok |
| demo_trekker | read_crb | 50 | ok |
| demo_trekker | cell_names | 470 | ok |
| demo_trekker | metadata | 0 | ok |
| demo_trekker | projection | 0 | ok |
| demo_trekker | gene_row_first | 0 | ok |
| demo_trekker | gene_row_repeat | 20 | ok |
| demo_trekker | gene_block_12 | 0 | ok |
| demo_trekker | mean_expression_12 | 10 | ok |
| demo_trekker | cells_10pct_genes_12 | 0 | ok |
| demo_trekker | linked_bundle_build | 190 | ok |
| demo_trekker | linked_bundle_json | 50 | ok |

