# Viewer performance: CerebroNexus 8.0.1 (A) vs 8.3.0 (B)

- A: `cerebronexus-8.0.1_20261113-170708_6a67f6f`
- B: `cerebronexus-8.3.0_20261113-170708_e927cbf`
- Metric: `visual_complete_ms`, median over the rounds that finished

Both runs have the same contract, platform, host, CPU, plan and large datasets.

The two runs were made together, their sessions taking turns, so both met the same state of the machine.

Change: `slower` or `faster` when the exact two-sided rank-sum test over the rounds gives p <= 0.05 and the medians differ by more than one frame; `not resolved` otherwise; `too few rounds` when the numbers of rounds cannot give such a p at all (3 against 3 cannot, 4 against 4 can).

| Page | Visit | Dataset | A (ms) | B (ms) | Delta (ms) | Delta (%) | Rounds A / B | p | B - A per round (ms) | Busy A / B (ms) | R peak A / B (MiB) | Change | Note |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| loadData | initial | 1m | 191 | 26 | -165 | -86.6 | 5 / 5 | 0.032 | -847 to 3 | 1,456 / 5,727 | 854 / 884 | faster |  |
| loadData.switch | action | 1m | 163 | 449 | 286 | +175.3 | 5 / 5 | 0.222 | -265 to 425 | 1,286 / 1,695 | 625 / 766 | not resolved |  |
| loadData.switch_back | action | 1m | 14 | 414 | 400 | +2903.1 | 5 / 5 | 0.056 | 2 to 415 | 1,256 / 1,353 | 590 / 838 | not resolved |  |
| overview | cold | 1m | 398 | 398 | 0 | +0.1 | 5 / 5 | 0.690 | -51 to 283 | 767 / 888 | 634 / 746 | not resolved |  |
| overview | first_start | 1m | 2,238 | 3,317 | 1,079 | +48.2 | 5 / 5 | 0.008 | 790 to 1,553 | 3,202 / 10,952 | 902 / 1,058 | slower |  |
| overview | first_plot | 1m | 2,312 | 2,097 | -215 | -9.3 | 5 / 5 | 0.421 | -343 to 153 | 3,210 / 9,176 | 913 / 729 | not resolved |  |
| overview.colour_by | action | 1m | 128 | 136 | 8 | +6.6 | 5 / 5 | 1.000 | -10 to 30 | 0 / 0 | 653 / 761 | not resolved |  |
| overview.zoom | action | 1m | 6 | 7 | 1 | +12.9 | 5 / 5 | 0.032 | -1 to 1 | 0 / 0 | 653 / 761 | not resolved |  |
| overview.lasso | action | 1m | 88 | 88 | 0 | +0.1 | 5 / 5 | 0.548 | -8 to 18 | 148 / 214 | 655 / 769 | not resolved |  |
| coordinated_views | cold | 1m | 261 | 512 | 251 | +96.1 | 5 / 5 | 0.095 | -3 to 339 | 674 / 2,784 | 655 / 742 | not resolved |  |
| coordinated_views.colour_by | action | 1m | 152 | 9 | -143 | -94.2 | 5 / 5 | 0.310 | -177 to 144 | 66 / 86 | 634 / 718 | not resolved |  |
| groups | cold | 1m | 20 | 285 | 265 | +1337.4 | 5 / 5 | 0.008 | 104 to 294 | 225 / 368 | 618 / 668 | slower |  |
| groups.group | action | 1m | 120 | 137 | 17 | +13.8 | 5 / 5 | 0.056 | 3 to 46 | 269 / 242 | 640 / 743 | not resolved |  |
| groups.plot_type | action | 1m | 8 | 8 | 0 | +4.7 | 5 / 5 | 0.421 | -1 to 2 | 0 / 0 | 637 / 684 | not resolved |  |
| groups.percent | action | 1m | 6 | 6 | 0 | -0.2 | 5 / 5 | 1.000 | -2 to 1 | 0 / 0 | 637 / 684 | not resolved |  |
| geneExpression | cold | 1m | 531 | 554 | 23 | +4.4 | 5 / 5 | 0.095 | -59 to 217 | 1,045 / 1,027 | 635 / 733 | not resolved |  |
| geneExpression.gene | action | 1m | 695 | 543 | -152 | -21.9 | 5 / 5 | 0.016 | -551 to -19 | 461 / 1,989 | 763 / 790 | faster |  |
| geneExpression.genes12 | action | 1m | 851 | 839 | -13 | -1.5 | 5 / 5 | 0.548 | -160 to 185 | 576 / 587 | 915 / 976 | not resolved |  |
| trajectory | cold | 1m | 579 | 577 | -3 | -0.5 | 5 / 5 | 0.690 | -48 to 252 | 952 / 943 | 818 / 898 | not resolved |  |
| trajectory.colour_by | action | 1m | 12 | 13 | 1 | +8.2 | 5 / 5 | 1.000 | -231 to 197 | 136 / 306 | 892 / 887 | not resolved |  |
| color_management | cold | 1m | 135 | 344 | 209 | +154.5 | 5 / 5 | 0.008 | 95 to 218 | 218 / 317 | 589 / 580 | slower |  |
| geneIdConversion | cold | 1m | 541 | 490 | -51 | -9.4 | 5 / 5 | 0.548 | -157 to 68 | 522 / 486 | 659 / 596 | not resolved |  |
| about | cold | 1m | 146 | 124 | -22 | -15.3 | 5 / 5 | 0.310 | -33 to 40 | 0 / 331 | 587 / 532 | not resolved |  |
| immune_repertoire | cold | ren | 21,993 | 21,990 | -3 | -0.0 | 5 / 5 | 0.690 | -349 to 1,025 | 22,263 / 23,202 | 1,872 / 1,943 | not resolved |  |
| immune_repertoire.tab | action | ren | 1,038 | 742 | -297 | -28.6 | 5 / 5 | 0.032 | -981 to -5 | 1,210 / 2,223 | 1,870 / 2,117 | faster |  |
| hla_tcr_motifs | cold | ren | 465 | 609 | 143 | +30.7 | 5 / 5 | 0.008 | 67 to 217 | 544 / 751 | 523 / 700 | slower |  |
| hla_tcr_motifs.colour_by | action | ren | 13 | 12 | -1 | -9.9 | 5 / 5 | 0.421 | -6 to 1 | 0 / 0 | 515 / 687 | not resolved |  |
| extra_material | cold | ren | 344 | 345 | 0 | +0.1 | 5 / 5 | 0.548 | -7 to 128 | 460 / 576 | 506 / 684 | not resolved |  |
| extra_material.content | action | ren | - | - | - | - | 0 / 0 | - | - | - / - | - / - | - |  |
| spatial | cold | cosmx | 715 | 826 | 112 | +15.6 | 5 / 5 | 0.310 | -429 to 204 | 1,065 / 1,271 | 750 / 984 | not resolved |  |
| spatial.section | action | cosmx | 278 | 261 | -17 | -6.1 | 5 / 5 | 0.222 | -114 to 22 | 516 / 389 | 738 / 954 | not resolved |  |
| markerGenes | cold | example | 341 | 470 | 129 | +37.9 | 5 / 5 | 0.032 | 3 to 305 | 375 / 2,629 | 404 / 549 | slower |  |
| markerGenes.table | action | example | - | - | - | - | 0 / 0 | - | - | - / - | - / - | - |  |
| mostExpressedGenes | cold | example | 356 | 517 | 161 | +45.1 | 5 / 5 | 0.008 | 51 to 200 | 410 / 465 | 405 / 578 | slower |  |
| mostExpressedGenes.group | action | example | 152 | 168 | 17 | +10.9 | 5 / 5 | 1.000 | -51 to 58 | 241 / 1,224 | 405 / 573 | not resolved |  |
| enrichedPathways | cold | example | 470 | 547 | 77 | +16.3 | 5 / 5 | 0.032 | 10 to 148 | 367 / 552 | 405 / 574 | not resolved |  |
| enrichedPathways.table | action | example | 162 | 179 | 17 | +10.7 | 5 / 5 | 0.222 | -114 to 153 | 0 / 0 | 402 / 576 | not resolved |  |
| trekker | cold | demo_trekker | 139 | 454 | 316 | +227.8 | 5 / 5 | 0.032 | -34 to 439 | 206 / 680 | 410 / 540 | slower |  |
| trekker.colour_by | action | demo_trekker | 11 | 12 | 1 | +7.2 | 5 / 5 | 0.841 | -5 to 4 | 0 / 0 | 410 / 552 | not resolved |  |

Slower: 7; faster: 3; stopped finishing: 0; not resolved: 27; too few rounds: 0.
37 rows were tested, each at 0.05: up to 1.8 of them would be marked by chance alone if nothing had changed.
