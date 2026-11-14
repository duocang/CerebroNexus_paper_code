# Viewer performance: CerebroNexus 8.0.0 (A) vs 8.1.1 (B)

- A: `cerebronexus-8.0.0_20261114-045716_24bbc02`
- B: `cerebronexus-8.1.1_20261114-045716_d79f5d8`
- Metric: `visual_complete_ms`, median over the rounds that finished

Both runs have the same contract, platform, host, CPU, plan and large datasets.

The two runs were made together, their sessions taking turns, so both met the same state of the machine.

Change: `slower` or `faster` when the exact two-sided rank-sum test over the rounds gives p <= 0.05 and the medians differ by more than one frame; `not resolved` otherwise; `too few rounds` when the numbers of rounds cannot give such a p at all (3 against 3 cannot, 4 against 4 can).

| Page | Visit | Dataset | A (ms) | B (ms) | Delta (ms) | Delta (%) | Rounds A / B | p | B - A per round (ms) | Busy A / B (ms) | R peak A / B (MiB) | Change | Note |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| loadData | initial | 1m | 54 | 37 | -17 | -31.7 | 5 / 5 | 0.056 | -941 to 11 | 1,267 / 5,337 | 854 / 879 | not resolved |  |
| loadData.switch | action | 1m | 122 | 149 | 26 | +21.6 | 5 / 5 | 0.690 | -106 to 636 | 1,252 / 3,808 | 625 / 770 | not resolved |  |
| loadData.switch_back | action | 1m | 13 | 163 | 150 | +1151.5 | 5 / 5 | 0.056 | 0 to 302 | 1,266 / 1,228 | 590 / 835 | not resolved |  |
| overview | cold | 1m | 155 | 391 | 236 | +152.2 | 5 / 5 | 0.222 | -213 to 340 | 711 / 867 | 634 / 749 | not resolved |  |
| overview | first_start | 1m | 2,244 | 3,542 | 1,299 | +57.9 | 5 / 5 | 0.008 | 1,028 to 1,561 | 3,047 / 10,837 | 882 / 1,078 | slower |  |
| overview | first_plot | 1m | 2,176 | 2,056 | -120 | -5.5 | 5 / 5 | 0.151 | -243 to 51 | 2,903 / 9,477 | 883 / 735 | not resolved |  |
| overview.colour_by | action | 1m | 132 | 138 | 6 | +4.4 | 5 / 5 | 0.548 | -41 to 9 | 0 / 29 | 653 / 767 | not resolved |  |
| overview.zoom | action | 1m | 7 | 7 | 0 | -1.7 | 5 / 5 | 0.548 | -4 to 0 | 0 / 0 | 652 / 767 | not resolved |  |
| overview.lasso | action | 1m | 88 | 90 | 2 | +2.0 | 5 / 5 | 0.421 | -1 to 141 | 0 / 250 | 655 / 775 | not resolved |  |
| coordinated_views | cold | 1m | 250 | 476 | 226 | +90.1 | 5 / 5 | 0.421 | -11 to 249 | 654 / 737 | 655 / 756 | not resolved |  |
| coordinated_views.colour_by | action | 1m | 9 | 9 | -1 | -10.2 | 5 / 5 | 0.151 | -3 to 0 | 162 / 78 | 634 / 734 | not resolved |  |
| groups | cold | 1m | 154 | 290 | 135 | +87.7 | 5 / 5 | 0.008 | 122 to 246 | 267 / 428 | 618 / 668 | slower |  |
| groups.group | action | 1m | 81 | 134 | 53 | +65.4 | 5 / 5 | 0.548 | -69 to 131 | 235 / 257 | 639 / 767 | not resolved |  |
| groups.plot_type | action | 1m | 8 | 8 | 0 | -5.1 | 5 / 5 | 0.841 | -1 to 2 | 0 / 0 | 637 / 690 | not resolved |  |
| groups.percent | action | 1m | 6 | 7 | 1 | +20.6 | 5 / 5 | 0.222 | 0 to 1 | 0 / 0 | 637 / 690 | not resolved |  |
| geneExpression | cold | 1m | 533 | 426 | -107 | -20.0 | 5 / 5 | 0.548 | -121 to 35 | 1,111 / 1,122 | 635 / 748 | not resolved |  |
| geneExpression.gene | action | 1m | 704 | 706 | 3 | +0.4 | 5 / 5 | 1.000 | -440 to 178 | 469 / 1,112 | 774 / 886 | not resolved |  |
| geneExpression.genes12 | action | 1m | 764 | 784 | 20 | +2.6 | 5 / 5 | 1.000 | -121 to 53 | 510 / 658 | 930 / 963 | not resolved |  |
| trajectory | cold | 1m | 572 | 727 | 155 | +27.2 | 5 / 5 | 0.095 | 67 to 406 | 897 / 1,203 | 813 / 914 | not resolved |  |
| trajectory.colour_by | action | 1m | 13 | 10 | -2 | -17.8 | 5 / 5 | 0.421 | -188 to 215 | 144 / 314 | 892 / 904 | not resolved |  |
| color_management | cold | 1m | 158 | 351 | 194 | +122.9 | 5 / 5 | 0.016 | 11 to 248 | 238 / 265 | 589 / 578 | slower |  |
| geneIdConversion | cold | 1m | 466 | 466 | 0 | +0.0 | 5 / 5 | 0.841 | -127 to 50 | 391 / 433 | 660 / 596 | not resolved |  |
| about | cold | 1m | 144 | 126 | -18 | -12.6 | 5 / 5 | 0.008 | -30 to -7 | 0 / 186 | 587 / 531 | not resolved |  |
| immune_repertoire | cold | ren | 20,841 | 21,053 | 212 | +1.0 | 5 / 5 | 0.548 | -174 to 257 | 20,960 / 21,045 | 1,890 / 1,907 | not resolved |  |
| immune_repertoire.tab | action | ren | 1,659 | 1,032 | -627 | -37.8 | 5 / 5 | 0.151 | -729 to 428 | 1,149 / 1,671 | 1,871 / 2,088 | not resolved |  |
| hla_tcr_motifs | cold | ren | 421 | 572 | 151 | +36.0 | 5 / 5 | 0.008 | 69 to 201 | 539 / 808 | 523 / 696 | slower |  |
| hla_tcr_motifs.colour_by | action | ren | 12 | 11 | -2 | -13.9 | 5 / 5 | 0.016 | -4 to 0 | 0 / 0 | 514 / 686 | not resolved |  |
| extra_material | cold | ren | 364 | 481 | 118 | +32.4 | 5 / 5 | 0.310 | -4 to 139 | 482 / 559 | 506 / 691 | not resolved |  |
| extra_material.content | action | ren | - | - | - | - | 0 / 0 | - | - | - / - | - / - | - |  |
| spatial | cold | cosmx | 683 | 805 | 121 | +17.7 | 5 / 5 | 0.008 | 49 to 248 | 970 / 1,125 | 750 / 981 | not resolved |  |
| spatial.section | action | cosmx | 271 | 272 | 1 | +0.6 | 5 / 5 | 0.690 | -113 to 48 | 440 / 405 | 729 / 955 | not resolved |  |
| markerGenes | cold | example | 376 | 393 | 17 | +4.6 | 5 / 5 | 0.690 | -167 to 149 | 326 / 397 | 404 / 540 | not resolved |  |
| markerGenes.table | action | example | - | - | - | - | 0 / 0 | - | - | - / - | - / - | - |  |
| mostExpressedGenes | cold | example | 413 | 416 | 3 | +0.7 | 5 / 5 | 0.548 | -99 to 195 | 370 / 459 | 405 / 573 | not resolved |  |
| mostExpressedGenes.group | action | example | 145 | 168 | 23 | +15.7 | 5 / 5 | 0.310 | -4 to 128 | 252 / 276 | 405 / 572 | not resolved |  |
| enrichedPathways | cold | example | 445 | 439 | -7 | -1.5 | 5 / 5 | 0.548 | -103 to 272 | 364 / 470 | 405 / 565 | not resolved |  |
| enrichedPathways.table | action | example | 171 | 283 | 112 | +65.8 | 5 / 5 | 0.421 | -119 to 142 | 0 / 0 | 403 / 573 | not resolved |  |
| trekker | cold | demo_trekker | 137 | 127 | -10 | -7.1 | 5 / 5 | 1.000 | -23 to 178 | 223 / 2,788 | 410 / 506 | not resolved |  |
| trekker.colour_by | action | demo_trekker | 10 | 11 | 0 | +1.5 | 5 / 5 | 1.000 | -1 to 1 | 0 / 0 | 410 / 446 | not resolved |  |

Slower: 4; faster: 0; stopped finishing: 0; not resolved: 33; too few rounds: 0.
37 rows were tested, each at 0.05: up to 1.8 of them would be marked by chance alone if nothing had changed.
