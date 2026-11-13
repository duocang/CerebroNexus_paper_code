# Viewer performance: CerebroNexus 8.0.1

- Run: `cerebronexus-8.0.1_20261113-170708_6a67f6f`
- Revision: master (`6a67f6fcda05`)
- Rounds: 5; sessions: 95, failed twice: 0
- Datasets: 1m, ren, cosmx, example, demo_trekker
- Machine: NUIOI; Microsoft Windows 11 Pro 10.0.26300; 12th Gen Intel(R) Core(TM) i9-12900K
- R version 4.6.1 (2026-06-24 ucrt); Chrome/157.0.8103.52, drawn by ANGLE (NVIDIA, NVIDIA GeForce RTX 4060 (0x00002882) Direct3D11 vs_5_0 ps_5_0, D3D11); webgpu
- Measured together with `cerebronexus-8.3.0_20261113-170708_e927cbf` (this run is the baseline), session by session in turn
- Host before the sessions: median 5.2 % CPU, at most 9.2 %; waited 16 s in all

## Problems

- not finished in every round: extra_material.content, markerGenes.table

## Pages and actions

Medians over the rounds that finished. Visual = click to the last frame that changes (the KPI); range = fastest and slowest round.
On the `first_start` and `first_plot` rows both times run from Chrome's navigation to the Viewer instead of from a click: First plot = to the first frame that shows the projection, Visual = to the last frame that changes. `first_start`: the server's cache directory was emptied before the session; `first_plot`: it held what earlier sessions left.

| Page | Visit | Dataset | Status | Visual (ms) | First plot (ms) | Range (ms) | Server busy (ms) | Trail (ms) | Largest msg (MB) | Loader (ms) | R peak (MiB) | Chrome peak (MiB) | Value |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| loadData | initial | 1m | ok | 191 | - | 38-872 | 1,456 | 501 | <0.1 | 147 | 854 | 610 |  |
| loadData.switch | action | 1m | ok | 163 | - | 42-424 | 1,286 | 387 | <0.1 | 155 | 625 | 620 | Demo dataset |
| loadData.switch_back | action | 1m | ok | 14 | - | 11-15 | 1,256 | 1,338 | <0.1 | 124 | 590 | 634 | Second dataset |
| overview | cold | 1m | ok | 398 | - | 262-449 | 767 | 4,751 | <0.1 | 6 | 634 | 838 |  |
| overview | first_start | 1m | ok | 2,238 | 2,525 | 2,161-2,575 | 3,202 | 7 | <0.1 | 1,203 | 902 | 840 |  |
| overview | first_plot | 1m | ok | 2,312 | 2,380 | 2,068-2,608 | 3,210 | 8 | <0.1 | 1,357 | 913 | 841 |  |
| overview.colour_by | action | 1m | ok | 128 | - | 126-146 | 0 | 2 | <0.1 | 0 | 653 | 812 | sample |
| overview.zoom | action | 1m | ok | 6 | - | 6-7 | 0 | 0 | <0.1 | 0 | 653 | 821 | in |
| overview.lasso | action | 1m | ok | 88 | - | 84-96 | 148 | 0 | 0.2 | 0 | 655 | 876 | middle 40% |
| coordinated_views | cold | 1m | ok | 261 | - | 178-542 | 674 | 5,552 | <0.1 | 241 | 655 | 830 |  |
| coordinated_views.colour_by | action | 1m | ok | 152 | - | 9-186 | 66 | 0 | 1.3 | 0 | 634 | 829 | sample |
| groups | cold | 1m | ok | 20 | - | 13-177 | 225 | 0 | <0.1 | 0 | 618 | 620 |  |
| groups.group | action | 1m | ok | 120 | - | 114-140 | 269 | 1,065 | <0.1 | 0 | 640 | 617 | seurat_clusters |
| groups.plot_type | action | 1m | ok | 8 | - | 7-11 | 0 | 0 | <0.1 | 0 | 637 | 706 | Sankey plot |
| groups.percent | action | 1m | ok | 6 | - | 6-10 | 0 | 0 | <0.1 | 0 | 637 | 767 | on |
| geneExpression | cold | 1m | ok | 531 | - | 482-613 | 1,045 | 5,208 | <0.1 | 198 | 635 | 876 |  |
| geneExpression.gene | action | 1m | ok | 695 | - | 632-1,011 | 461 | 0 | 5.5 | 0 | 763 | 1,008 | 0610007P14Rik |
| geneExpression.genes12 | action | 1m | ok | 851 | - | 658-888 | 576 | 0 | 10.5 | 0 | 915 | 1,040 | 0610007P14Rik 0610009B22Rik 0610009L18Rik 0610009O20Rik 0610010F05Rik 0610010K14Rik 0610011F06Rik 0610012D04Rik 0610012G03Rik 0610025J13Rik 0610030E20Rik 0610031O16Rik |
| trajectory | cold | 1m | ok | 579 | - | 358-641 | 952 | 5,039 | 5.1 | 337 | 818 | 881 |  |
| trajectory.colour_by | action | 1m | ok | 12 | - | 11-244 | 136 | 0 | 5.1 | 0 | 892 | 953 | state |
| color_management | cold | 1m | ok | 135 | - | 125-174 | 218 | 0 | <0.1 | 0 | 589 | 617 |  |
| geneIdConversion | cold | 1m | ok | 541 | - | 422-608 | 522 | 0 | 0.3 | 375 | 659 | 638 |  |
| about | cold | 1m | ok | 146 | - | 128-156 | 0 | 0 | <0.1 | 0 | 587 | 613 |  |
| immune_repertoire | cold | ren | ok | 21,993 | - | 21,920-22,444 | 22,263 | 0 | 2.6 | 21,572 | 1,872 | 868 |  |
| immune_repertoire.tab | action | ren | ok | 1,038 | - | 986-1,692 | 1,210 | 0 | 0.2 | 0 | 1,870 | 998 | Abundance |
| hla_tcr_motifs | cold | ren | ok | 465 | - | 395-527 | 544 | 5,192 | <0.1 | 314 | 523 | 660 |  |
| hla_tcr_motifs.colour_by | action | ren | ok | 13 | - | 11-18 | 0 | 0 | <0.1 | 0 | 515 | 663 | major_type |
| extra_material | cold | ren | ok | 344 | - | 315-383 | 460 | 5,385 | <0.1 | 279 | 506 | 658 |  |
| extra_material.content | action | ren | unavailable (0/5 ok) | - | - | - | - | - | - | - | - | - |  |
| spatial | cold | cosmx | ok | 715 | - | 640-1,278 | 1,065 | 0 | 0.1 | 289 | 750 | 739 |  |
| spatial.section | action | cosmx | ok | 278 | - | 261-337 | 516 | 1,536 | 0.1 | 0 | 738 | 757 | spatial_projection_sample=Lung5_Rep2 |
| markerGenes | cold | example | ok | 341 | - | 182-444 | 375 | 0 | <0.1 | 0 | 404 | 639 |  |
| markerGenes.table | action | example | unavailable (0/5 ok) | - | - | - | - | - | - | - | - | - |  |
| mostExpressedGenes | cold | example | ok | 356 | - | 264-383 | 410 | 0 | <0.1 | 0 | 405 | 624 |  |
| mostExpressedGenes.group | action | example | ok | 152 | - | 135-199 | 241 | 2,435 | <0.1 | 0 | 405 | 630 | seurat_clusters |
| enrichedPathways | cold | example | ok | 470 | - | 399-523 | 367 | 0 | <0.1 | 0 | 405 | 638 |  |
| enrichedPathways.table | action | example | ok | 162 | - | 146-278 | 0 | 2,148 | <0.1 | 0 | 402 | 646 | enriched_pathways_selected_method=cerebro_GSVA |
| trekker | cold | demo_trekker | ok | 139 | - | 19-217 | 206 | 0 | 0.1 | 0 | 410 | 623 |  |
| trekker.colour_by | action | demo_trekker | ok | 11 | - | 8-18 | 0 | 2,496 | 0.1 | 0 | 410 | 619 | cluster |

## Memory per dataset

Largest peak of any session on the dataset (R server tree, Chrome tree) and the median server start.

| Dataset | Sessions | R peak (MiB) | Chrome peak (MiB) | Server start (s) |
|---|---|---|---|---|
| 1m | 55 | 928 | 1,049 | 5.4 |
| ren | 15 | 1,891 | 1,008 | 3.4 |
| cosmx | 5 | 774 | 758 | 3.9 |
| example | 15 | 409 | 655 | 2.5 |
| demo_trekker | 5 | 413 | 644 | 2.5 |

## Server steps

The R work behind the pages, without a browser (one fresh R process per dataset and round).

| Dataset | Step | Time (ms) | Status |
|---|---|---|---|
| 1m | read_crb | 2,550 | ok |
| 1m | cell_names | 2,640 | ok |
| 1m | metadata | 0 | ok |
| 1m | projection | 0 | ok |
| 1m | gene_row_first | 50 | ok |
| 1m | gene_row_repeat | 70 | ok |
| 1m | gene_block_12 | 20 | ok |
| 1m | mean_expression_12 | 1,150 | ok |
| 1m | cells_10pct_genes_12 | 210 | ok |
| 1m | linked_bundle_build | 560 | ok |
| 1m | linked_bundle_json | 5,010 | ok |
| ren | read_crb | 2,010 | ok |
| ren | cell_names | 2,870 | ok |
| ren | metadata | 0 | ok |
| ren | projection | 0 | ok |
| ren | gene_row_first | 40 | ok |
| ren | gene_row_repeat | 50 | ok |
| ren | gene_block_12 | 20 | ok |
| ren | mean_expression_12 | 1,120 | ok |
| ren | cells_10pct_genes_12 | 230 | ok |
| ren | linked_bundle_build | 6,080 | ok |
| ren | linked_bundle_json | 6,180 | ok |
| cosmx | read_crb | 950 | ok |
| cosmx | cell_names | 2,110 | ok |
| cosmx | metadata | 0 | ok |
| cosmx | projection | 0 | ok |
| cosmx | gene_row_first | 30 | ok |
| cosmx | gene_row_repeat | 30 | ok |
| cosmx | gene_block_12 | 20 | ok |
| cosmx | mean_expression_12 | 300 | ok |
| cosmx | cells_10pct_genes_12 | 170 | ok |
| cosmx | linked_bundle_build | 720 | ok |
| cosmx | linked_bundle_json | 4,610 | ok |
| example | read_crb | 30 | ok |
| example | cell_names | 0 | ok |
| example | metadata | 0 | ok |
| example | projection | 0 | ok |
| example | gene_row_first | 0 | ok |
| example | gene_row_repeat | 10 | ok |
| example | gene_block_12 | 0 | ok |
| example | mean_expression_12 | 0 | ok |
| example | cells_10pct_genes_12 | 0 | ok |
| example | linked_bundle_build | 0 | ok |
| example | linked_bundle_json | 10 | ok |
| demo_trekker | read_crb | 30 | ok |
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

