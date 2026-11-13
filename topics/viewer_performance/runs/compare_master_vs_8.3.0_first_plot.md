# Viewer performance: CerebroNexus 8.0.1 (A) vs 8.3.0 (B)

- A: `cerebronexus-8.0.1_20261113-170708_6a67f6f`
- B: `cerebronexus-8.3.0_20261113-170708_e927cbf`
- Metric: `first_plot_ms`, median over the rounds that finished

Both runs have the same contract, platform, host, CPU, plan and large datasets.

The two runs were made together, their sessions taking turns, so both met the same state of the machine.

Change: `slower` or `faster` when the exact two-sided rank-sum test over the rounds gives p <= 0.05 and the medians differ by more than one frame; `not resolved` otherwise; `too few rounds` when the numbers of rounds cannot give such a p at all (3 against 3 cannot, 4 against 4 can).

| Page | Visit | Dataset | A (ms) | B (ms) | Delta (ms) | Delta (%) | Rounds A / B | p | B - A per round (ms) | Busy A / B (ms) | R peak A / B (MiB) | Change | Note |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| loadData | initial | 1m | - | - | - | - | 0 / 0 | - | - | 1,456 / 5,727 | 854 / 884 | - |  |
| loadData.switch | action | 1m | - | - | - | - | 0 / 0 | - | - | 1,286 / 1,695 | 625 / 766 | - |  |
| loadData.switch_back | action | 1m | - | - | - | - | 0 / 0 | - | - | 1,256 / 1,353 | 590 / 838 | - |  |
| overview | cold | 1m | - | - | - | - | 0 / 0 | - | - | 767 / 888 | 634 / 746 | - |  |
| overview | first_start | 1m | 2,525 | 3,495 | 970 | +38.4 | 5 / 5 | 0.008 | 790 to 1,553 | 3,202 / 10,952 | 902 / 1,058 | slower |  |
| overview | first_plot | 1m | 2,380 | 2,196 | -184 | -7.8 | 5 / 5 | 0.690 | -343 to 329 | 3,210 / 9,176 | 913 / 729 | not resolved |  |
| overview.colour_by | action | 1m | - | - | - | - | 0 / 0 | - | - | 0 / 0 | 653 / 761 | - |  |
| overview.zoom | action | 1m | - | - | - | - | 0 / 0 | - | - | 0 / 0 | 653 / 761 | - |  |
| overview.lasso | action | 1m | - | - | - | - | 0 / 0 | - | - | 148 / 214 | 655 / 769 | - |  |
| coordinated_views | cold | 1m | - | - | - | - | 0 / 0 | - | - | 674 / 2,784 | 655 / 742 | - |  |
| coordinated_views.colour_by | action | 1m | - | - | - | - | 0 / 0 | - | - | 66 / 86 | 634 / 718 | - |  |
| groups | cold | 1m | - | - | - | - | 0 / 0 | - | - | 225 / 368 | 618 / 668 | - |  |
| groups.group | action | 1m | - | - | - | - | 0 / 0 | - | - | 269 / 242 | 640 / 743 | - |  |
| groups.plot_type | action | 1m | - | - | - | - | 0 / 0 | - | - | 0 / 0 | 637 / 684 | - |  |
| groups.percent | action | 1m | - | - | - | - | 0 / 0 | - | - | 0 / 0 | 637 / 684 | - |  |
| geneExpression | cold | 1m | - | - | - | - | 0 / 0 | - | - | 1,045 / 1,027 | 635 / 733 | - |  |
| geneExpression.gene | action | 1m | - | - | - | - | 0 / 0 | - | - | 461 / 1,989 | 763 / 790 | - |  |
| geneExpression.genes12 | action | 1m | - | - | - | - | 0 / 0 | - | - | 576 / 587 | 915 / 976 | - |  |
| trajectory | cold | 1m | - | - | - | - | 0 / 0 | - | - | 952 / 943 | 818 / 898 | - |  |
| trajectory.colour_by | action | 1m | - | - | - | - | 0 / 0 | - | - | 136 / 306 | 892 / 887 | - |  |
| color_management | cold | 1m | - | - | - | - | 0 / 0 | - | - | 218 / 317 | 589 / 580 | - |  |
| geneIdConversion | cold | 1m | - | - | - | - | 0 / 0 | - | - | 522 / 486 | 659 / 596 | - |  |
| about | cold | 1m | - | - | - | - | 0 / 0 | - | - | 0 / 331 | 587 / 532 | - |  |
| immune_repertoire | cold | ren | - | - | - | - | 0 / 0 | - | - | 22,263 / 23,202 | 1,872 / 1,943 | - |  |
| immune_repertoire.tab | action | ren | - | - | - | - | 0 / 0 | - | - | 1,210 / 2,223 | 1,870 / 2,117 | - |  |
| hla_tcr_motifs | cold | ren | - | - | - | - | 0 / 0 | - | - | 544 / 751 | 523 / 700 | - |  |
| hla_tcr_motifs.colour_by | action | ren | - | - | - | - | 0 / 0 | - | - | 0 / 0 | 515 / 687 | - |  |
| extra_material | cold | ren | - | - | - | - | 0 / 0 | - | - | 460 / 576 | 506 / 684 | - |  |
| extra_material.content | action | ren | - | - | - | - | 0 / 0 | - | - | - / - | - / - | - |  |
| spatial | cold | cosmx | - | - | - | - | 0 / 0 | - | - | 1,065 / 1,271 | 750 / 984 | - |  |
| spatial.section | action | cosmx | - | - | - | - | 0 / 0 | - | - | 516 / 389 | 738 / 954 | - |  |
| markerGenes | cold | example | - | - | - | - | 0 / 0 | - | - | 375 / 2,629 | 404 / 549 | - |  |
| markerGenes.table | action | example | - | - | - | - | 0 / 0 | - | - | - / - | - / - | - |  |
| mostExpressedGenes | cold | example | - | - | - | - | 0 / 0 | - | - | 410 / 465 | 405 / 578 | - |  |
| mostExpressedGenes.group | action | example | - | - | - | - | 0 / 0 | - | - | 241 / 1,224 | 405 / 573 | - |  |
| enrichedPathways | cold | example | - | - | - | - | 0 / 0 | - | - | 367 / 552 | 405 / 574 | - |  |
| enrichedPathways.table | action | example | - | - | - | - | 0 / 0 | - | - | 0 / 0 | 402 / 576 | - |  |
| trekker | cold | demo_trekker | - | - | - | - | 0 / 0 | - | - | 206 / 680 | 410 / 540 | - |  |
| trekker.colour_by | action | demo_trekker | - | - | - | - | 0 / 0 | - | - | 0 / 0 | 410 / 552 | - |  |

Slower: 1; faster: 0; stopped finishing: 0; not resolved: 1; too few rounds: 0.
2 rows were tested, each at 0.05: up to 0.1 of them would be marked by chance alone if nothing had changed.
