# Viewer performance: CerebroNexus 8.0.0 (A) vs 8.1.1 (B)

- A: `cerebronexus-8.0.0_20261114-045716_24bbc02`
- B: `cerebronexus-8.1.1_20261114-045716_d79f5d8`
- Metric: `first_plot_ms`, median over the rounds that finished

Both runs have the same contract, platform, host, CPU, plan and large datasets.

The two runs were made together, their sessions taking turns, so both met the same state of the machine.

Change: `slower` or `faster` when the exact two-sided rank-sum test over the rounds gives p <= 0.05 and the medians differ by more than one frame; `not resolved` otherwise; `too few rounds` when the numbers of rounds cannot give such a p at all (3 against 3 cannot, 4 against 4 can).

| Page | Visit | Dataset | A (ms) | B (ms) | Delta (ms) | Delta (%) | Rounds A / B | p | B - A per round (ms) | Busy A / B (ms) | R peak A / B (MiB) | Change | Note |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| loadData | initial | 1m | - | - | - | - | 0 / 0 | - | - | 1,267 / 5,337 | 854 / 879 | - |  |
| loadData.switch | action | 1m | - | - | - | - | 0 / 0 | - | - | 1,252 / 3,808 | 625 / 770 | - |  |
| loadData.switch_back | action | 1m | - | - | - | - | 0 / 0 | - | - | 1,266 / 1,228 | 590 / 835 | - |  |
| overview | cold | 1m | - | - | - | - | 0 / 0 | - | - | 711 / 867 | 634 / 749 | - |  |
| overview | first_start | 1m | 2,195 | 3,542 | 1,348 | +61.4 | 5 / 5 | 0.008 | 1,288 to 1,561 | 3,047 / 10,837 | 882 / 1,078 | slower |  |
| overview | first_plot | 1m | 2,176 | 2,056 | -120 | -5.5 | 5 / 5 | 0.095 | -266 to -88 | 2,903 / 9,477 | 883 / 735 | not resolved |  |
| overview.colour_by | action | 1m | - | - | - | - | 0 / 0 | - | - | 0 / 29 | 653 / 767 | - |  |
| overview.zoom | action | 1m | - | - | - | - | 0 / 0 | - | - | 0 / 0 | 652 / 767 | - |  |
| overview.lasso | action | 1m | - | - | - | - | 0 / 0 | - | - | 0 / 250 | 655 / 775 | - |  |
| coordinated_views | cold | 1m | - | - | - | - | 0 / 0 | - | - | 654 / 737 | 655 / 756 | - |  |
| coordinated_views.colour_by | action | 1m | - | - | - | - | 0 / 0 | - | - | 162 / 78 | 634 / 734 | - |  |
| groups | cold | 1m | - | - | - | - | 0 / 0 | - | - | 267 / 428 | 618 / 668 | - |  |
| groups.group | action | 1m | - | - | - | - | 0 / 0 | - | - | 235 / 257 | 639 / 767 | - |  |
| groups.plot_type | action | 1m | - | - | - | - | 0 / 0 | - | - | 0 / 0 | 637 / 690 | - |  |
| groups.percent | action | 1m | - | - | - | - | 0 / 0 | - | - | 0 / 0 | 637 / 690 | - |  |
| geneExpression | cold | 1m | - | - | - | - | 0 / 0 | - | - | 1,111 / 1,122 | 635 / 748 | - |  |
| geneExpression.gene | action | 1m | - | - | - | - | 0 / 0 | - | - | 469 / 1,112 | 774 / 886 | - |  |
| geneExpression.genes12 | action | 1m | - | - | - | - | 0 / 0 | - | - | 510 / 658 | 930 / 963 | - |  |
| trajectory | cold | 1m | - | - | - | - | 0 / 0 | - | - | 897 / 1,203 | 813 / 914 | - |  |
| trajectory.colour_by | action | 1m | - | - | - | - | 0 / 0 | - | - | 144 / 314 | 892 / 904 | - |  |
| color_management | cold | 1m | - | - | - | - | 0 / 0 | - | - | 238 / 265 | 589 / 578 | - |  |
| geneIdConversion | cold | 1m | - | - | - | - | 0 / 0 | - | - | 391 / 433 | 660 / 596 | - |  |
| about | cold | 1m | - | - | - | - | 0 / 0 | - | - | 0 / 186 | 587 / 531 | - |  |
| immune_repertoire | cold | ren | - | - | - | - | 0 / 0 | - | - | 20,960 / 21,045 | 1,890 / 1,907 | - |  |
| immune_repertoire.tab | action | ren | - | - | - | - | 0 / 0 | - | - | 1,149 / 1,671 | 1,871 / 2,088 | - |  |
| hla_tcr_motifs | cold | ren | - | - | - | - | 0 / 0 | - | - | 539 / 808 | 523 / 696 | - |  |
| hla_tcr_motifs.colour_by | action | ren | - | - | - | - | 0 / 0 | - | - | 0 / 0 | 514 / 686 | - |  |
| extra_material | cold | ren | - | - | - | - | 0 / 0 | - | - | 482 / 559 | 506 / 691 | - |  |
| extra_material.content | action | ren | - | - | - | - | 0 / 0 | - | - | - / - | - / - | - |  |
| spatial | cold | cosmx | - | - | - | - | 0 / 0 | - | - | 970 / 1,125 | 750 / 981 | - |  |
| spatial.section | action | cosmx | - | - | - | - | 0 / 0 | - | - | 440 / 405 | 729 / 955 | - |  |
| markerGenes | cold | example | - | - | - | - | 0 / 0 | - | - | 326 / 397 | 404 / 540 | - |  |
| markerGenes.table | action | example | - | - | - | - | 0 / 0 | - | - | - / - | - / - | - |  |
| mostExpressedGenes | cold | example | - | - | - | - | 0 / 0 | - | - | 370 / 459 | 405 / 573 | - |  |
| mostExpressedGenes.group | action | example | - | - | - | - | 0 / 0 | - | - | 252 / 276 | 405 / 572 | - |  |
| enrichedPathways | cold | example | - | - | - | - | 0 / 0 | - | - | 364 / 470 | 405 / 565 | - |  |
| enrichedPathways.table | action | example | - | - | - | - | 0 / 0 | - | - | 0 / 0 | 403 / 573 | - |  |
| trekker | cold | demo_trekker | - | - | - | - | 0 / 0 | - | - | 223 / 2,788 | 410 / 506 | - |  |
| trekker.colour_by | action | demo_trekker | - | - | - | - | 0 / 0 | - | - | 0 / 0 | 410 / 446 | - |  |

Slower: 1; faster: 0; stopped finishing: 0; not resolved: 1; too few rounds: 0.
2 rows were tested, each at 0.05: up to 0.1 of them would be marked by chance alone if nothing had changed.
