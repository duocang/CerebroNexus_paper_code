# Task 3 summary

Median (min-max) over `ok` runs. `Builds ok` and `Starts ok` give ok / all attempted rows (failed, timed-out and not-run rows are in the raw tables and in the status columns of `summary_task3.csv`). Start metrics use all starts (nine per config and tier). Build time of cellxgene is n/a (it reads the `.h5ad`); its artifact is the `.h5ad`.

| Tier | Config | Builds ok | Build s | Artifact GB | Starts ok | Ready s | First plot s | Total s | Server peak RSS GB | Chrome peak RSS GB |
|---|---|---|---|---|---|---|---|---|---|---|
| 10,000 | cerebronexus_default | 3/3 | 11.4 (10.6-11.8) | 0.04 (0.04-0.04) | 9/9 | 4.4 (4.4-7.6) | 2.27 (2.20-2.37) | 6.7 (6.6-9.9) | 0.63 (0.62-0.63) | 0.80 (0.77-0.81) |
| 10,000 | cerebronexus_h5 | 3/3 | 14.5 (14.3-16.7) | 0.23 (0.23-0.23) | 9/9 | 6.5 (6.5-7.0) | 2.28 (2.19-4.13) | 8.8 (8.7-11.2) | 0.90 (0.89-0.90) | 0.80 (0.80-0.80) |
| 10,000 | shinycell | 3/3 | 25.0 (24.8-25.1) | 0.09 (0.09-0.09) | 9/9 | 2.3 (2.2-2.5) | 3.01 (2.95-3.48) | 5.3 (5.2-5.7) | 0.45 (0.44-0.45) | 0.65 (0.65-0.65) |
| 10,000 | isee | 3/3 | 11.2 (11.1-11.5) | 0.23 (0.23-0.23) | 9/9 | 8.0 (7.5-8.1) | 8.22 (8.01-8.47) | 16.2 (15.6-16.5) | 1.50 (1.49-1.52) | 0.71 (0.71-0.72) |
| 10,000 | cellxgene | 3/3 | - | 0.16 (0.16-0.16) | 9/9 | 8.1 (8.0-9.6) | 0.79 (0.78-0.85) | 8.9 (8.8-10.4) | 0.40 (0.40-0.40) | 0.63 (0.62-0.63) |
| 10,000 | vitessce | 3/3 | 4.9 (4.9-5.4) | 0.08 (0.08-0.08) | 9/9 | 0.6 (0.6-0.6) | 1.41 (1.34-1.47) | 2.0 (1.9-2.0) | 0.03 (0.03-0.03) | 0.77 (0.76-0.77) |
