# Viewer performance: CerebroNexus 8.0.0

- Run: `cerebronexus-8.0.0_20261114-045716_24bbc02`
- Revision: 24bbc029c3dba0df4e6af6f6ab69292bbed471fd (`24bbc029c3db`)
- Rounds: 5; sessions: 95, failed twice: 0
- Datasets: 1m, ren, cosmx, example, demo_trekker
- Machine: NUIOI; Microsoft Windows 11 Pro 10.0.26300; 12th Gen Intel(R) Core(TM) i9-12900K
- R version 4.6.1 (2026-06-24 ucrt); Chrome/157.0.8103.52, drawn by ANGLE (NVIDIA, NVIDIA GeForce RTX 4060 (0x00002882) Direct3D11 vs_5_0 ps_5_0, D3D11); webgpu
- Measured together with `cerebronexus-8.1.1_20261114-045716_d79f5d8` (this run is the baseline), session by session in turn
- Host before the sessions: median 3.2 % CPU, at most 8.3 %; waited 12 s in all

## Problems

- not finished in every round: extra_material.content, markerGenes.table

## Pages and actions

Medians over the rounds that finished. Visual = click to the last frame that changes (the KPI); range = fastest and slowest round.
On the `first_start` and `first_plot` rows both times run from Chrome's navigation to the Viewer instead of from a click: First plot = to the first frame that shows the projection, Visual = to the last frame that changes. `first_start`: the server's cache directory was emptied before the session; `first_plot`: it held what earlier sessions left.

| Page | Visit | Dataset | Status | Visual (ms) | First plot (ms) | Range (ms) | Server busy (ms) | Trail (ms) | Largest msg (MB) | Loader (ms) | R peak (MiB) | Chrome peak (MiB) | Value |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| loadData | initial | 1m | ok | 54 | - | 31-979 | 1,267 | 475 | <0.1 | 136 | 854 | 607 |  |
| loadData.switch | action | 1m | ok | 122 | - | 14-186 | 1,252 | 482 | <0.1 | 145 | 625 | 612 | Demo dataset |
| loadData.switch_back | action | 1m | ok | 13 | - | 11-14 | 1,266 | 1,273 | <0.1 | 120 | 590 | 625 | Second dataset |
| overview | cold | 1m | ok | 155 | - | 142-478 | 711 | 0 | <0.1 | 5 | 634 | 842 |  |
| overview | first_start | 1m | ok | 2,244 | 2,195 | 2,016-2,541 | 3,047 | 7 | <0.1 | 1,102 | 882 | 851 |  |
| overview | first_plot | 1m | ok | 2,176 | 2,176 | 2,114-2,244 | 2,903 | 7 | <0.1 | 1,171 | 883 | 842 |  |
| overview.colour_by | action | 1m | ok | 132 | - | 126-200 | 0 | 387 | <0.1 | 0 | 653 | 818 | sample |
| overview.zoom | action | 1m | ok | 7 | - | 6-106 | 0 | 0 | <0.1 | 0 | 652 | 800 | in |
| overview.lasso | action | 1m | ok | 88 | - | 87-265 | 0 | 0 | 0.2 | 0 | 655 | 880 | middle 40% |
| coordinated_views | cold | 1m | ok | 250 | - | 225-747 | 654 | 0 | <0.1 | 227 | 655 | 833 |  |
| coordinated_views.colour_by | action | 1m | ok | 9 | - | 9-11 | 162 | 1,203 | 1.3 | 0 | 634 | 845 | sample |
| groups | cold | 1m | ok | 154 | - | 122-168 | 267 | 0 | <0.1 | 0 | 618 | 627 |  |
| groups.group | action | 1m | ok | 81 | - | 11-144 | 235 | 1,146 | <0.1 | 0 | 639 | 625 | seurat_clusters |
| groups.plot_type | action | 1m | ok | 8 | - | 7-102 | 0 | 0 | <0.1 | 0 | 637 | 697 | Sankey plot |
| groups.percent | action | 1m | ok | 6 | - | 6-193 | 0 | 0 | <0.1 | 0 | 637 | 764 | on |
| geneExpression | cold | 1m | ok | 533 | - | 483-588 | 1,111 | 4,260 | <0.1 | 262 | 635 | 881 |  |
| geneExpression.gene | action | 1m | ok | 704 | - | 529-749 | 469 | 0 | 5.5 | 0 | 774 | 1,009 | 0610007P14Rik |
| geneExpression.genes12 | action | 1m | ok | 764 | - | 737-993 | 510 | 0 | 10.5 | 0 | 930 | 1,032 | 0610007P14Rik 0610009B22Rik 0610009L18Rik 0610009O20Rik 0610010F05Rik 0610010K14Rik 0610011F06Rik 0610012D04Rik 0610012G03Rik 0610025J13Rik 0610030E20Rik 0610031O16Rik |
| trajectory | cold | 1m | ok | 572 | - | 305-793 | 897 | 0 | 5.1 | 378 | 813 | 900 |  |
| trajectory.colour_by | action | 1m | ok | 13 | - | 10-199 | 144 | 420 | 5.1 | 0 | 892 | 975 | state |
| color_management | cold | 1m | ok | 158 | - | 139-278 | 238 | 0 | <0.1 | 0 | 589 | 614 |  |
| geneIdConversion | cold | 1m | ok | 466 | - | 417-620 | 391 | 0 | 0.3 | 344 | 660 | 623 |  |
| about | cold | 1m | ok | 144 | - | 134-152 | 0 | 0 | <0.1 | 0 | 587 | 599 |  |
| immune_repertoire | cold | ren | ok | 20,841 | - | 20,629-21,290 | 20,960 | 0 | 2.6 | 20,329 | 1,890 | 871 |  |
| immune_repertoire.tab | action | ren | ok | 1,659 | - | 1,016-1,760 | 1,149 | 0 | 0.2 | 0 | 1,871 | 997 | Abundance |
| hla_tcr_motifs | cold | ren | ok | 421 | - | 411-513 | 539 | 0 | <0.1 | 312 | 523 | 653 |  |
| hla_tcr_motifs.colour_by | action | ren | ok | 12 | - | 12-13 | 0 | 569 | <0.1 | 0 | 514 | 662 | major_type |
| extra_material | cold | ren | ok | 364 | - | 340-383 | 482 | 0 | <0.1 | 279 | 506 | 644 |  |
| extra_material.content | action | ren | unavailable (0/5 ok) | - | - | - | - | - | - | - | - | - |  |
| spatial | cold | cosmx | ok | 683 | - | 661-693 | 970 | 0 | 0.1 | 252 | 750 | 750 |  |
| spatial.section | action | cosmx | ok | 271 | - | 248-374 | 440 | 1,145 | 0.1 | 0 | 729 | 782 | spatial_projection_sample=Lung5_Rep2 |
| markerGenes | cold | example | ok | 376 | - | 244-419 | 326 | 0 | <0.1 | 5 | 404 | 623 |  |
| markerGenes.table | action | example | unavailable (0/5 ok) | - | - | - | - | - | - | - | - | - |  |
| mostExpressedGenes | cold | example | ok | 413 | - | 287-429 | 370 | 0 | <0.1 | 4 | 405 | 626 |  |
| mostExpressedGenes.group | action | example | ok | 145 | - | 133-171 | 252 | 1,856 | <0.1 | 0 | 405 | 637 | seurat_clusters |
| enrichedPathways | cold | example | ok | 445 | - | 350-538 | 364 | 0 | <0.1 | 0 | 405 | 625 |  |
| enrichedPathways.table | action | example | ok | 171 | - | 155-286 | 0 | 1,667 | <0.1 | 0 | 403 | 642 | enriched_pathways_selected_method=cerebro_GSVA |
| trekker | cold | demo_trekker | ok | 137 | - | 19-164 | 223 | 0 | 0.1 | 0 | 410 | 621 |  |
| trekker.colour_by | action | demo_trekker | ok | 10 | - | 9-12 | 0 | 2,049 | 0.1 | 0 | 410 | 616 | cluster |

## Memory per dataset

Largest peak of any session on the dataset (R server tree, Chrome tree) and the median server start.

| Dataset | Sessions | R peak (MiB) | Chrome peak (MiB) | Server start (s) |
|---|---|---|---|---|
| 1m | 55 | 950 | 1,048 | 4.8 |
| ren | 15 | 1,891 | 1,023 | 3.4 |
| cosmx | 5 | 785 | 787 | 3.4 |
| example | 15 | 409 | 657 | 2.5 |
| demo_trekker | 5 | 413 | 630 | 2.5 |

## Server steps

The R work behind the pages, without a browser (one fresh R process per dataset and round).

| Dataset | Step | Time (ms) | Status |
|---|---|---|---|
| 1m | read_crb | 2,330 | ok |
| 1m | cell_names | 2,600 | ok |
| 1m | metadata | 0 | ok |
| 1m | projection | 0 | ok |
| 1m | gene_row_first | 50 | ok |
| 1m | gene_row_repeat | 50 | ok |
| 1m | gene_block_12 | 20 | ok |
| 1m | mean_expression_12 | 1,070 | ok |
| 1m | cells_10pct_genes_12 | 200 | ok |
| 1m | linked_bundle_build | 540 | ok |
| 1m | linked_bundle_json | 4,730 | ok |
| ren | read_crb | 1,950 | ok |
| ren | cell_names | 2,770 | ok |
| ren | metadata | 0 | ok |
| ren | projection | 0 | ok |
| ren | gene_row_first | 50 | ok |
| ren | gene_row_repeat | 50 | ok |
| ren | gene_block_12 | 20 | ok |
| ren | mean_expression_12 | 1,080 | ok |
| ren | cells_10pct_genes_12 | 210 | ok |
| ren | linked_bundle_build | 5,710 | ok |
| ren | linked_bundle_json | 5,890 | ok |
| cosmx | read_crb | 920 | ok |
| cosmx | cell_names | 2,010 | ok |
| cosmx | metadata | 0 | ok |
| cosmx | projection | 0 | ok |
| cosmx | gene_row_first | 30 | ok |
| cosmx | gene_row_repeat | 30 | ok |
| cosmx | gene_block_12 | 10 | ok |
| cosmx | mean_expression_12 | 290 | ok |
| cosmx | cells_10pct_genes_12 | 170 | ok |
| cosmx | linked_bundle_build | 720 | ok |
| cosmx | linked_bundle_json | 4,490 | ok |
| example | read_crb | 30 | ok |
| example | cell_names | 0 | ok |
| example | metadata | 0 | ok |
| example | projection | 0 | ok |
| example | gene_row_first | 0 | ok |
| example | gene_row_repeat | 10 | ok |
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

