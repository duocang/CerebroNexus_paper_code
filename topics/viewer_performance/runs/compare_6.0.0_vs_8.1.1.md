# Viewer performance: CerebroNexus 6.0.0 (A) vs 8.1.1 (B)

- A: `cerebronexus-6.0.0_20261114-074022_33150d9`
- B: `cerebronexus-8.1.1_20261114-074022_d79f5d8`
- Metric: `visual_complete_ms`, median over the rounds that finished

Both runs have the same contract, platform, host, CPU, plan and large datasets.

The two runs were made together, their sessions taking turns, so both met the same state of the machine.

Change: `slower` or `faster` when the exact two-sided rank-sum test over the rounds gives p <= 0.05 and the medians differ by more than one frame; `not resolved` otherwise; `too few rounds` when the numbers of rounds cannot give such a p at all (3 against 3 cannot, 4 against 4 can).

| Page | Visit | Dataset | A (ms) | B (ms) | Delta (ms) | Delta (%) | Rounds A / B | p | B - A per round (ms) | Busy A / B (ms) | R peak A / B (MiB) | Change | Note |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| loadData | initial | 1m | 173 | 34 | -139 | -80.3 | 5 / 5 | 0.151 | -173 to 650 | 1,309 / 5,534 | 856 / 885 | not resolved |  |
| loadData.switch | action | 1m | 411 | 19 | -392 | -95.4 | 5 / 5 | 0.222 | -410 to 330 | 122 / 3,296 | 599 / 768 | not resolved |  |
| loadData.switch_back | action | 1m | 396 | 148 | -248 | -62.6 | 5 / 5 | 0.008 | -416 to -231 | 235 / 1,205 | 599 / 834 | faster |  |
| overview | cold | 1m | 509 | 363 | -146 | -28.7 | 5 / 5 | 0.008 | -376 to -48 | 1,051 / 758 | 651 / 750 | faster |  |
| overview | first_start | 1m | 2,420 | 3,550 | 1,130 | +46.7 | 5 / 4 | 0.016 | 1,067 to 1,202 | 3,080 / 10,836 | 910 / 1,089 | stopped finishing |  |
| overview | first_plot | 1m | 2,402 | 1,840 | -562 | -23.4 | 5 / 5 | 0.008 | -939 to -270 | 3,129 / 9,416 | 901 / 749 | faster |  |
| overview.colour_by | action | 1m | 137 | 154 | 17 | +12.1 | 5 / 5 | 0.841 | -125 to 55 | 0 / 0 | 668 / 768 | not resolved |  |
| overview.zoom | action | 1m | 6 | 7 | 1 | +8.5 | 5 / 5 | 0.690 | -1 to 1 | 0 / 0 | 668 / 767 | not resolved |  |
| overview.lasso | action | 1m | 2,999 | 87 | -2,912 | -97.1 | 5 / 5 | 0.008 | -2,985 to -2,764 | 3,430 / 307 | 1,286 / 776 | faster |  |
| coordinated_views | cold | 1m | 952 | 465 | -487 | -51.2 | 5 / 5 | 0.008 | -904 to -269 | 1,069 / 789 | 731 / 756 | faster |  |
| coordinated_views.colour_by | action | 1m | 149 | 8 | -141 | -94.4 | 5 / 5 | 0.095 | -170 to 143 | 116 / 84 | 650 / 734 | not resolved |  |
| groups | cold | 1m | 734 | 265 | -469 | -63.9 | 5 / 5 | 0.008 | -594 to -405 | 804 / 332 | 637 / 668 | faster |  |
| groups.group | action | 1m | 1,052 | 11 | -1,042 | -99.0 | 5 / 5 | 0.008 | -1,436 to -654 | 1,480 / 197 | 1,051 / 767 | faster |  |
| groups.plot_type | action | 1m | 136 | 8 | -128 | -94.4 | 5 / 5 | 0.008 | -185 to -122 | 194 / 0 | 677 / 690 | faster |  |
| groups.percent | action | 1m | 8 | 7 | -1 | -15.9 | 5 / 5 | 0.056 | -3 to -1 | 0 / 0 | 641 / 690 | not resolved |  |
| geneExpression | cold | 1m | 1,030 | 506 | -525 | -50.9 | 5 / 5 | 0.008 | -591 to -451 | 1,337 / 1,038 | 647 / 748 | faster |  |
| geneExpression.gene | action | 1m | 733 | 655 | -77 | -10.5 | 5 / 5 | 0.222 | -228 to 106 | 825 / 458 | 774 / 886 | not resolved |  |
| geneExpression.genes12 | action | 1m | 5,460 | 803 | -4,658 | -85.3 | 5 / 5 | 0.008 | -4,738 to -4,515 | 5,234 / 578 | 1,611 / 964 | faster |  |
| trajectory | cold | 1m | 864 | 697 | -167 | -19.4 | 5 / 5 | 0.151 | -308 to 26 | 771 / 962 | 606 / 918 | not resolved |  |
| trajectory.colour_by | action | 1m | 12 | 11 | -1 | -11.0 | 5 / 5 | 0.222 | -2 to 2 | 0 / 312 | 598 / 903 | not resolved |  |
| color_management | cold | 1m | 483 | 341 | -142 | -29.4 | 5 / 5 | 0.008 | -210 to -91 | 515 / 278 | 603 / 579 | faster |  |
| geneIdConversion | cold | 1m | 510 | 428 | -81 | -16.0 | 5 / 5 | 0.016 | -111 to -47 | 423 / 438 | 630 / 590 | not resolved |  |
| about | cold | 1m | 123 | 120 | -3 | -2.8 | 5 / 5 | 0.690 | -15 to 13 | 166 / 180 | 597 / 531 | not resolved |  |
| immune_repertoire | cold | ren | 3,760 | 22,039 | 18,280 | +486.2 | 5 / 5 | 0.008 | 17,238 to 18,634 | 3,845 / 24,110 | 905 / 1,723 | slower |  |
| immune_repertoire.tab | action | ren | 1,046 | 662 | -384 | -36.7 | 5 / 5 | 0.095 | -928 to 83 | 1,152 / 991 | 1,094 / 1,700 | not resolved |  |
| hla_tcr_motifs | cold | ren | 713 | 579 | -134 | -18.7 | 5 / 5 | 0.008 | -232 to -54 | 974 / 668 | 544 / 696 | faster |  |
| hla_tcr_motifs.colour_by | action | ren | 10 | 11 | 1 | +12.0 | 5 / 5 | 0.032 | 0 to 3 | 0 / 0 | 537 / 686 | not resolved |  |
| extra_material | cold | ren | 539 | 367 | -172 | -31.9 | 5 / 5 | 0.016 | -316 to -12 | 571 / 493 | 509 / 681 | faster |  |
| extra_material.content | action | ren | - | - | - | - | 0 / 0 | - | - | - / - | - / - | - |  |
| spatial | cold | cosmx | 1,122 | 864 | -258 | -23.0 | 5 / 5 | 0.008 | -356 to -94 | 1,370 / 1,147 | 740 / 983 | faster |  |
| spatial.section | action | cosmx | 543 | 255 | -288 | -53.0 | 5 / 5 | 0.008 | -371 to -126 | 616 / 423 | 866 / 956 | faster |  |
| markerGenes | cold | example | 396 | 426 | 29 | +7.4 | 5 / 5 | 1.000 | -148 to 278 | 416 / 3,712 | 394 / 542 | not resolved |  |
| markerGenes.table | action | example | - | - | - | - | 0 / 0 | - | - | - / - | - / - | - |  |
| mostExpressedGenes | cold | example | 496 | 482 | -14 | -2.9 | 5 / 5 | 0.421 | -184 to 22 | 476 / 493 | 394 / 573 | not resolved |  |
| mostExpressedGenes.group | action | example | 133 | 156 | 23 | +17.5 | 5 / 5 | 0.222 | -21 to 39 | 247 / 283 | 393 / 572 | not resolved |  |
| enrichedPathways | cold | example | 577 | 598 | 21 | +3.6 | 5 / 5 | 0.310 | -83 to 96 | 387 / 424 | 394 / 566 | not resolved |  |
| enrichedPathways.table | action | example | 280 | 168 | -111 | -39.8 | 5 / 5 | 0.151 | -125 to 7 | 0 / 0 | 391 / 573 | not resolved |  |
| trekker | cold | demo_trekker | 472 | 289 | -183 | -38.8 | 5 / 5 | 0.008 | -356 to -124 | 335 / 2,991 | 394 / 506 | faster |  |
| trekker.colour_by | action | demo_trekker | 10 | 10 | 0 | -1.0 | 5 / 5 | 0.548 | -4 to 2 | 0 / 0 | 393 / 445 | not resolved |  |

Slower: 1; faster: 16; stopped finishing: 1; not resolved: 19; too few rounds: 0.
36 rows were tested, each at 0.05: up to 1.8 of them would be marked by chance alone if nothing had changed.
