# Viewer performance: CerebroNexus 8.3.0 (A) vs 8.3.0 (B)

- A: `cerebronexus-8.3.0_20261113-190931_e927cbf_base`
- B: `cerebronexus-8.3.0_20261113-190931_e927cbf`
- Metric: `visual_complete_ms`, median over the rounds that finished

**Noise check:** both runs measured the same revision, so every difference below is noise of the measurement. No row should be marked slower or faster.

Both runs have the same contract, platform, host, CPU, plan and large datasets.

The two runs were made together, their sessions taking turns, so both met the same state of the machine.

Change: `slower` or `faster` when the exact two-sided rank-sum test over the rounds gives p <= 0.05 and the medians differ by more than one frame; `not resolved` otherwise; `too few rounds` when the numbers of rounds cannot give such a p at all (3 against 3 cannot, 4 against 4 can).

| Page | Visit | Dataset | A (ms) | B (ms) | Delta (ms) | Delta (%) | Rounds A / B | p | B - A per round (ms) | Busy A / B (ms) | R peak A / B (MiB) | Change | Note |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| loadData | initial | 1m | 39 | 42 | 4 | +9.3 | 5 / 5 | 0.690 | -21 to 535 | 10,197 / 10,196 | 886 / 880 | not resolved |  |
| loadData.switch | action | 1m | 424 | 349 | -75 | -17.6 | 5 / 5 | 0.222 | -694 to 214 | 2,091 / 1,920 | 778 / 776 | not resolved |  |
| loadData.switch_back | action | 1m | 374 | 411 | 37 | +10.0 | 5 / 5 | 0.841 | -29 to 37 | 1,217 / 1,308 | 838 / 838 | not resolved |  |
| overview | cold | 1m | 787 | 618 | -170 | -21.5 | 5 / 5 | 0.222 | -602 to -31 | 2,499 / 3,516 | 742 / 746 | not resolved |  |
| overview | first_start | 1m | 4,135 | 4,007 | -127 | -3.1 | 5 / 5 | 0.841 | -673 to 146 | 11,420 / 11,703 | 1,061 / 1,061 | not resolved |  |
| overview | first_plot | 1m | 2,749 | 2,593 | -156 | -5.7 | 5 / 4 | 0.905 | -732 to 318 | 10,041 / 9,454 | 735 / 725 | stopped finishing |  |
| overview.colour_by | action | 1m | 165 | 145 | -21 | -12.4 | 5 / 5 | 0.310 | -230 to 2 | 0 / 358 | 761 / 761 | not resolved |  |
| overview.zoom | action | 1m | 8 | 8 | 0 | -2.7 | 5 / 5 | 0.841 | -6 to 7 | 658 / 2,176 | 761 / 761 | not resolved |  |
| overview.lasso | action | 1m | 300 | 328 | 28 | +9.4 | 5 / 5 | 1.000 | -171 to 91 | 2,593 / 1,784 | 769 / 769 | not resolved |  |
| coordinated_views | cold | 1m | 591 | 606 | 15 | +2.5 | 5 / 5 | 0.421 | -232 to 408 | 2,584 / 2,850 | 742 / 742 | not resolved |  |
| coordinated_views.colour_by | action | 1m | 13 | 22 | 9 | +68.8 | 5 / 5 | 0.841 | -65 to 12 | 220 / 686 | 718 / 718 | not resolved |  |
| groups | cold | 1m | 303 | 315 | 12 | +3.9 | 5 / 5 | 0.421 | -12 to 103 | 377 / 544 | 669 / 669 | not resolved |  |
| groups.group | action | 1m | 149 | 156 | 7 | +4.9 | 5 / 5 | 0.841 | -46 to 25 | 2,088 / 221 | 718 / 743 | not resolved |  |
| groups.plot_type | action | 1m | 9 | 9 | 0 | +2.2 | 5 / 5 | 0.841 | -2 to 10 | 0 / 1,998 | 685 / 684 | not resolved |  |
| groups.percent | action | 1m | 7 | 8 | 1 | +18.5 | 5 / 5 | 0.841 | -3 to 6 | 1,718 / 861 | 684 / 684 | not resolved |  |
| geneExpression | cold | 1m | 720 | 604 | -116 | -16.1 | 5 / 5 | 0.548 | -287 to 28 | 1,149 / 1,855 | 733 / 731 | not resolved |  |
| geneExpression.gene | action | 1m | 754 | 582 | -172 | -22.8 | 5 / 5 | 0.421 | -466 to 465 | 532 / 575 | 790 / 781 | not resolved |  |
| geneExpression.genes12 | action | 1m | 829 | 848 | 19 | +2.2 | 5 / 5 | 0.690 | -201 to 134 | 671 / 751 | 977 / 976 | not resolved |  |
| trajectory | cold | 1m | 666 | 708 | 42 | +6.3 | 5 / 5 | 0.548 | -105 to 982 | 1,144 / 2,465 | 898 / 902 | not resolved |  |
| trajectory.colour_by | action | 1m | 13 | 13 | 0 | -0.0 | 5 / 5 | 0.690 | -352 to 248 | 466 / 346 | 917 / 888 | not resolved |  |
| color_management | cold | 1m | 456 | 448 | -8 | -1.7 | 5 / 5 | 1.000 | -144 to 54 | 396 / 3,217 | 582 / 584 | not resolved |  |
| geneIdConversion | cold | 1m | 621 | 769 | 148 | +23.8 | 5 / 5 | 0.095 | 55 to 225 | 1,034 / 1,067 | 599 / 594 | not resolved |  |
| about | cold | 1m | 150 | 138 | -12 | -8.3 | 5 / 5 | 0.310 | -93 to 30 | 2,376 / 2,560 | 537 / 536 | not resolved |  |
| immune_repertoire | cold | ren | 29,858 | 28,288 | -1,570 | -5.3 | 4 / 2 | 0.800 | -1,132 to 150 | 31,865 / 29,253 | 1,759 / 1,699 | too few rounds |  |
| immune_repertoire.tab | action | ren | 1,601 | 1,438 | -163 | -10.2 | 5 / 5 | 1.000 | -916 to 1,015 | 1,720 / 1,683 | 1,676 / 1,677 | not resolved |  |
| hla_tcr_motifs | cold | ren | 733 | 706 | -27 | -3.7 | 5 / 5 | 0.841 | -130 to 224 | 3,022 / 1,198 | 698 / 700 | not resolved |  |
| hla_tcr_motifs.colour_by | action | ren | 13 | 14 | 1 | +4.8 | 5 / 5 | 0.548 | -2 to 3 | 95 / 470 | 687 / 686 | not resolved |  |
| extra_material | cold | ren | 606 | 581 | -25 | -4.1 | 5 / 5 | 1.000 | -250 to 213 | 798 / 891 | 683 / 684 | not resolved |  |
| extra_material.content | action | ren | - | - | - | - | 0 / 0 | - | - | - / - | - / - | - |  |
| spatial | cold | cosmx | 945 | 1,026 | 81 | +8.6 | 5 / 5 | 0.841 | -75 to 88 | 1,563 / 1,337 | 983 / 982 | not resolved |  |
| spatial.section | action | cosmx | 268 | 322 | 54 | +20.2 | 5 / 5 | 0.310 | -245 to 89 | 2,046 / 517 | 952 / 954 | not resolved |  |
| markerGenes | cold | example | 451 | 482 | 31 | +6.9 | 5 / 5 | 0.841 | -205 to 159 | 1,857 / 543 | 554 / 549 | not resolved |  |
| markerGenes.table | action | example | - | - | - | - | 0 / 0 | - | - | - / - | - / - | - |  |
| mostExpressedGenes | cold | example | 579 | 542 | -37 | -6.4 | 5 / 5 | 0.548 | -610 to 193 | 596 / 566 | 578 / 578 | not resolved |  |
| mostExpressedGenes.group | action | example | 182 | 170 | -12 | -6.8 | 5 / 5 | 1.000 | -209 to 1,912 | 448 / 1,278 | 572 / 572 | not resolved |  |
| enrichedPathways | cold | example | 924 | 837 | -87 | -9.4 | 5 / 5 | 0.690 | -158 to 495 | 896 / 3,309 | 576 / 574 | not resolved |  |
| enrichedPathways.table | action | example | 196 | 185 | -12 | -5.9 | 5 / 4 | 0.556 | -19 to 157 | 212 / 1,580 | 570 / 574 | stopped finishing |  |
| trekker | cold | demo_trekker | 337 | 362 | 25 | +7.4 | 5 / 5 | 0.690 | -1 to 219 | 574 / 3,715 | 547 / 540 | not resolved |  |
| trekker.colour_by | action | demo_trekker | 12 | 12 | 0 | +0.2 | 5 / 5 | 0.841 | -91 to 2 | 348 / 2,810 | 561 / 553 | not resolved |  |

Slower: 0; faster: 0; stopped finishing: 2; not resolved: 34; too few rounds: 1.
34 rows were tested, each at 0.05: up to 1.7 of them would be marked by chance alone if nothing had changed.
Noise: the medians of the two runs differ by 25 ms in the median row, by 159 at the 90th percentile and by 1,570 at most; 0 of 34 tested rows marked.
