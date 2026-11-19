# Reading of this run

Numbers: [summary.md](summary.md). Figures: `../../figures/fig-tool-timing.pdf` and `fig-tool-capability.pdf` (made by `plot.R`).
Every start (198) and every gene colouring (660) finished (`ok`). Three pairs of starts, one build and one 20-gene session per tool and tier.
Differences below 0.2 s are not results.

## What is in this folder

The run was made in two passes. **The rows of CerebroNexus (embedded), ShinyCell, iSEE, cellxgene and Vitessce are from the first pass**
(23:54 to 02:09, CerebroNexus commit `9156f50`, 8.4.1). **The rows of CerebroNexus (HDF5) were measured again** (finished 06:18) **with a later
commit, `7383f50`** (also 8.4.1; it keeps 32-bit values as 32-bit in the H5 file), and replace the first pass's rows; `manifest.tsv` names both
commits. The folder is still named after the first. The other tools do not depend on CerebroNexus, but the two passes were made at different times.

## Where CerebroNexus (HDF5) is ahead

- **Start does not grow with the number of cells.** Launch to first plot, first start: 2.7 to 3.6 s from 5,000 to 100,000 cells and 3.6 s at all 1,306,127;
  started again 1.7 to 2.2 s at every size. At 1.3 M cells cellxgene needs 26 s and Vitessce 12 s.
- **Colouring by a gene costs the same at every size.** Genes 2 to 20: 1.2 to 1.5 s at every size up to 1.3 M (1.3 s); Vitessce 1.8 s at 5,000, 2.2 s at 100,000 and
  5.2 s at 1.3 M; cellxgene 1.9 s up to 100,000 and 11.7 s at 1.3 M. The first gene at 1.3 M: 1.6 s (Vitessce 7.0 s, cellxgene 2.0 s).
- **Memory stays small**: 1.1 GiB (server + browser) at 100,000 cells and 1.8 GiB at 1.3 M; cellxgene 2.4 and 40 GiB.
- **A second start of the embedded layer is fast**: 7.8 s the first time at 100,000 cells (empty cache), 2.3 s when started again.

## Where it is not

- **Small and medium data: Vitessce is faster to the first plot** (1.8 s at 5,000, 2.3 s at 100,000 cells against 3.4 and 3.6 s) and has the smallest server (30 MB).
  The two cross between 100,000 and 1.3 M cells.
- **Build time**: CerebroNexus (HDF5) 55 s at 100,000 and 624 s at 1.3 M cells; Vitessce 17 s and 113 s. ShinyCell takes 140 s at 100,000.
- **Embedded layer at 100,000 cells**: first start 7.8 s, server 6.7 GiB. At 1.3 M it, ShinyCell and iSEE cannot hold the matrix (`skipped`).
- **iSEE is the slowest to start** (23 s at 100,000 cells).

## Method notes

- One machine; the CPU before each start was recorded (`idle_cpu_pct`). Other programs on the machine (other agents' browsers) were not controlled.
- *Again* is the second start of a pair with the same cache directory; *first* starts with an empty one.
- The first-plot rule needs 0.3 % ink (not 1 %): at 5,000 cells a plot is thin (see README).
- The capability and selection figure is not from this run (`../../features/README.md`).
