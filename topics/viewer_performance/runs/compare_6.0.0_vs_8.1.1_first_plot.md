# Viewer performance: CerebroNexus 6.0.0 (A) vs 8.1.1 (B)

- A: `cerebronexus-6.0.0_20261114-074022_33150d9`
- B: `cerebronexus-8.1.1_20261114-074022_d79f5d8`
- Metric: `first_plot_ms`, median over the rounds that finished

Both runs have the same contract, platform, host, CPU, plan and large datasets.

The two runs were made together, their sessions taking turns, so both met the same state of the machine.

Change: `slower` or `faster` when the exact two-sided rank-sum test over the rounds gives p <= 0.05 and the medians differ by more than one frame; `not resolved` otherwise; `too few rounds` when the numbers of rounds cannot give such a p at all (3 against 3 cannot, 4 against 4 can).

| Page | Visit | Dataset | A (ms) | B (ms) | Delta (ms) | Delta (%) | Rounds A / B | p | B - A per round (ms) | Busy A / B (ms) | R peak A / B (MiB) | Change | Note |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| loadData | initial | 1m | - | - | - | - | 0 / 0 | - | - | 1,309 / 5,534 | 856 / 885 | - |  |
| loadData.switch | action | 1m | - | - | - | - | 0 / 0 | - | - | 122 / 3,296 | 599 / 768 | - |  |
| loadData.switch_back | action | 1m | - | - | - | - | 0 / 0 | - | - | 235 / 1,205 | 599 / 834 | - |  |
| overview | cold | 1m | - | - | - | - | 0 / 0 | - | - | 1,051 / 758 | 651 / 750 | - |  |
| overview | first_start | 1m | 2,421 | 3,614 | 1,193 | +49.3 | 5 / 4 | 0.016 | 831 to 1,434 | 3,080 / 10,836 | 910 / 1,089 | stopped finishing |  |
| overview | first_plot | 1m | 2,569 | 2,053 | -516 | -20.1 | 5 / 5 | 0.008 | -669 to -349 | 3,129 / 9,416 | 901 / 749 | faster |  |
| overview.colour_by | action | 1m | - | - | - | - | 0 / 0 | - | - | 0 / 0 | 668 / 768 | - |  |
| overview.zoom | action | 1m | - | - | - | - | 0 / 0 | - | - | 0 / 0 | 668 / 767 | - |  |
| overview.lasso | action | 1m | - | - | - | - | 0 / 0 | - | - | 3,430 / 307 | 1,286 / 776 | - |  |
| coordinated_views | cold | 1m | - | - | - | - | 0 / 0 | - | - | 1,069 / 789 | 731 / 756 | - |  |
| coordinated_views.colour_by | action | 1m | - | - | - | - | 0 / 0 | - | - | 116 / 84 | 650 / 734 | - |  |
| groups | cold | 1m | - | - | - | - | 0 / 0 | - | - | 804 / 332 | 637 / 668 | - |  |
| groups.group | action | 1m | - | - | - | - | 0 / 0 | - | - | 1,480 / 197 | 1,051 / 767 | - |  |
| groups.plot_type | action | 1m | - | - | - | - | 0 / 0 | - | - | 194 / 0 | 677 / 690 | - |  |
| groups.percent | action | 1m | - | - | - | - | 0 / 0 | - | - | 0 / 0 | 641 / 690 | - |  |
| geneExpression | cold | 1m | - | - | - | - | 0 / 0 | - | - | 1,337 / 1,038 | 647 / 748 | - |  |
| geneExpression.gene | action | 1m | - | - | - | - | 0 / 0 | - | - | 825 / 458 | 774 / 886 | - |  |
| geneExpression.genes12 | action | 1m | - | - | - | - | 0 / 0 | - | - | 5,234 / 578 | 1,611 / 964 | - |  |
| trajectory | cold | 1m | - | - | - | - | 0 / 0 | - | - | 771 / 962 | 606 / 918 | - |  |
| trajectory.colour_by | action | 1m | - | - | - | - | 0 / 0 | - | - | 0 / 312 | 598 / 903 | - |  |
| color_management | cold | 1m | - | - | - | - | 0 / 0 | - | - | 515 / 278 | 603 / 579 | - |  |
| geneIdConversion | cold | 1m | - | - | - | - | 0 / 0 | - | - | 423 / 438 | 630 / 590 | - |  |
| about | cold | 1m | - | - | - | - | 0 / 0 | - | - | 166 / 180 | 597 / 531 | - |  |
| immune_repertoire | cold | ren | - | - | - | - | 0 / 0 | - | - | 3,845 / 24,110 | 905 / 1,723 | - |  |
| immune_repertoire.tab | action | ren | - | - | - | - | 0 / 0 | - | - | 1,152 / 991 | 1,094 / 1,700 | - |  |
| hla_tcr_motifs | cold | ren | - | - | - | - | 0 / 0 | - | - | 974 / 668 | 544 / 696 | - |  |
| hla_tcr_motifs.colour_by | action | ren | - | - | - | - | 0 / 0 | - | - | 0 / 0 | 537 / 686 | - |  |
| extra_material | cold | ren | - | - | - | - | 0 / 0 | - | - | 571 / 493 | 509 / 681 | - |  |
| extra_material.content | action | ren | - | - | - | - | 0 / 0 | - | - | - / - | - / - | - |  |
| spatial | cold | cosmx | - | - | - | - | 0 / 0 | - | - | 1,370 / 1,147 | 740 / 983 | - |  |
| spatial.section | action | cosmx | - | - | - | - | 0 / 0 | - | - | 616 / 423 | 866 / 956 | - |  |
| markerGenes | cold | example | - | - | - | - | 0 / 0 | - | - | 416 / 3,712 | 394 / 542 | - |  |
| markerGenes.table | action | example | - | - | - | - | 0 / 0 | - | - | - / - | - / - | - |  |
| mostExpressedGenes | cold | example | - | - | - | - | 0 / 0 | - | - | 476 / 493 | 394 / 573 | - |  |
| mostExpressedGenes.group | action | example | - | - | - | - | 0 / 0 | - | - | 247 / 283 | 393 / 572 | - |  |
| enrichedPathways | cold | example | - | - | - | - | 0 / 0 | - | - | 387 / 424 | 394 / 566 | - |  |
| enrichedPathways.table | action | example | - | - | - | - | 0 / 0 | - | - | 0 / 0 | 391 / 573 | - |  |
| trekker | cold | demo_trekker | - | - | - | - | 0 / 0 | - | - | 335 / 2,991 | 394 / 506 | - |  |
| trekker.colour_by | action | demo_trekker | - | - | - | - | 0 / 0 | - | - | 0 / 0 | 393 / 445 | - |  |

Slower: 0; faster: 1; stopped finishing: 1; not resolved: 0; too few rounds: 0.
1 rows were tested, each at 0.05: up to 0.0 of them would be marked by chance alone if nothing had changed.
