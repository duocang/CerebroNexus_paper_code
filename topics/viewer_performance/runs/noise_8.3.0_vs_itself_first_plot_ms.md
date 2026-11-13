# Viewer performance: CerebroNexus 8.3.0 (A) vs 8.3.0 (B)

- A: `cerebronexus-8.3.0_20261113-190931_e927cbf_base`
- B: `cerebronexus-8.3.0_20261113-190931_e927cbf`
- Metric: `first_plot_ms`, median over the rounds that finished

**Noise check:** both runs measured the same revision, so every difference below is noise of the measurement. No row should be marked slower or faster.

Both runs have the same contract, platform, host, CPU, plan and large datasets.

The two runs were made together, their sessions taking turns, so both met the same state of the machine.

Change: `slower` or `faster` when the exact two-sided rank-sum test over the rounds gives p <= 0.05 and the medians differ by more than one frame; `not resolved` otherwise; `too few rounds` when the numbers of rounds cannot give such a p at all (3 against 3 cannot, 4 against 4 can).

| Page | Visit | Dataset | A (ms) | B (ms) | Delta (ms) | Delta (%) | Rounds A / B | p | B - A per round (ms) | Busy A / B (ms) | R peak A / B (MiB) | Change | Note |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| loadData | initial | 1m | - | - | - | - | 0 / 0 | - | - | 10,197 / 10,196 | 886 / 880 | - |  |
| loadData.switch | action | 1m | - | - | - | - | 0 / 0 | - | - | 2,091 / 1,920 | 778 / 776 | - |  |
| loadData.switch_back | action | 1m | - | - | - | - | 0 / 0 | - | - | 1,217 / 1,308 | 838 / 838 | - |  |
| overview | cold | 1m | - | - | - | - | 0 / 0 | - | - | 2,499 / 3,516 | 742 / 746 | - |  |
| overview | first_start | 1m | 4,135 | 4,007 | -127 | -3.1 | 5 / 5 | 1.000 | -235 to 186 | 11,420 / 11,703 | 1,061 / 1,061 | not resolved |  |
| overview | first_plot | 1m | 2,867 | 2,748 | -118 | -4.1 | 5 / 4 | 0.730 | -382 to 162 | 10,041 / 9,454 | 735 / 725 | stopped finishing |  |
| overview.colour_by | action | 1m | - | - | - | - | 0 / 0 | - | - | 0 / 358 | 761 / 761 | - |  |
| overview.zoom | action | 1m | - | - | - | - | 0 / 0 | - | - | 658 / 2,176 | 761 / 761 | - |  |
| overview.lasso | action | 1m | - | - | - | - | 0 / 0 | - | - | 2,593 / 1,784 | 769 / 769 | - |  |
| coordinated_views | cold | 1m | - | - | - | - | 0 / 0 | - | - | 2,584 / 2,850 | 742 / 742 | - |  |
| coordinated_views.colour_by | action | 1m | - | - | - | - | 0 / 0 | - | - | 220 / 686 | 718 / 718 | - |  |
| groups | cold | 1m | - | - | - | - | 0 / 0 | - | - | 377 / 544 | 669 / 669 | - |  |
| groups.group | action | 1m | - | - | - | - | 0 / 0 | - | - | 2,088 / 221 | 718 / 743 | - |  |
| groups.plot_type | action | 1m | - | - | - | - | 0 / 0 | - | - | 0 / 1,998 | 685 / 684 | - |  |
| groups.percent | action | 1m | - | - | - | - | 0 / 0 | - | - | 1,718 / 861 | 684 / 684 | - |  |
| geneExpression | cold | 1m | - | - | - | - | 0 / 0 | - | - | 1,149 / 1,855 | 733 / 731 | - |  |
| geneExpression.gene | action | 1m | - | - | - | - | 0 / 0 | - | - | 532 / 575 | 790 / 781 | - |  |
| geneExpression.genes12 | action | 1m | - | - | - | - | 0 / 0 | - | - | 671 / 751 | 977 / 976 | - |  |
| trajectory | cold | 1m | - | - | - | - | 0 / 0 | - | - | 1,144 / 2,465 | 898 / 902 | - |  |
| trajectory.colour_by | action | 1m | - | - | - | - | 0 / 0 | - | - | 466 / 346 | 917 / 888 | - |  |
| color_management | cold | 1m | - | - | - | - | 0 / 0 | - | - | 396 / 3,217 | 582 / 584 | - |  |
| geneIdConversion | cold | 1m | - | - | - | - | 0 / 0 | - | - | 1,034 / 1,067 | 599 / 594 | - |  |
| about | cold | 1m | - | - | - | - | 0 / 0 | - | - | 2,376 / 2,560 | 537 / 536 | - |  |
| immune_repertoire | cold | ren | - | - | - | - | 0 / 0 | - | - | 31,865 / 29,253 | 1,759 / 1,699 | - |  |
| immune_repertoire.tab | action | ren | - | - | - | - | 0 / 0 | - | - | 1,720 / 1,683 | 1,676 / 1,677 | - |  |
| hla_tcr_motifs | cold | ren | - | - | - | - | 0 / 0 | - | - | 3,022 / 1,198 | 698 / 700 | - |  |
| hla_tcr_motifs.colour_by | action | ren | - | - | - | - | 0 / 0 | - | - | 95 / 470 | 687 / 686 | - |  |
| extra_material | cold | ren | - | - | - | - | 0 / 0 | - | - | 798 / 891 | 683 / 684 | - |  |
| extra_material.content | action | ren | - | - | - | - | 0 / 0 | - | - | - / - | - / - | - |  |
| spatial | cold | cosmx | - | - | - | - | 0 / 0 | - | - | 1,563 / 1,337 | 983 / 982 | - |  |
| spatial.section | action | cosmx | - | - | - | - | 0 / 0 | - | - | 2,046 / 517 | 952 / 954 | - |  |
| markerGenes | cold | example | - | - | - | - | 0 / 0 | - | - | 1,857 / 543 | 554 / 549 | - |  |
| markerGenes.table | action | example | - | - | - | - | 0 / 0 | - | - | - / - | - / - | - |  |
| mostExpressedGenes | cold | example | - | - | - | - | 0 / 0 | - | - | 596 / 566 | 578 / 578 | - |  |
| mostExpressedGenes.group | action | example | - | - | - | - | 0 / 0 | - | - | 448 / 1,278 | 572 / 572 | - |  |
| enrichedPathways | cold | example | - | - | - | - | 0 / 0 | - | - | 896 / 3,309 | 576 / 574 | - |  |
| enrichedPathways.table | action | example | - | - | - | - | 0 / 0 | - | - | 212 / 1,580 | 570 / 574 | stopped finishing |  |
| trekker | cold | demo_trekker | - | - | - | - | 0 / 0 | - | - | 574 / 3,715 | 547 / 540 | - |  |
| trekker.colour_by | action | demo_trekker | - | - | - | - | 0 / 0 | - | - | 348 / 2,810 | 561 / 553 | - |  |

Slower: 0; faster: 0; stopped finishing: 2; not resolved: 1; too few rounds: 0.
1 rows were tested, each at 0.05: up to 0.0 of them would be marked by chance alone if nothing had changed.
Noise: the medians of the two runs differ by 123 ms in the median row, by 126 at the 90th percentile and by 127 at most; 0 of 1 tested rows marked.
