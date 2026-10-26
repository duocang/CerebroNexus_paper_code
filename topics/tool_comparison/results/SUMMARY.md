# Comparative evaluation: summary of results

Host: native Windows 11, i9-12900K (24 threads), 127.7 GB RAM, R 4.5.0, Python 3.11.15, Chrome 155 (see `environment.json`). Protocol: `../PROTOCOL.md` (frozen text, deviations D1-D15 at its end). Raw rows: `task1/`, `task2/`, `task3/`.

## Task 1: import and capability recognition

Grades: auto = present with the documented default call and required arguments; manual = needs extra configuration or code; absent; n/a = dataset lacks it. I4 = duplicated cell names.

| Tool | Dataset | Import | Embeddings | Clustering | TCR view | TCR column | Spatial | Image | I4 behaviour | Default route failed |
|---|---|---|---|---|---|---|---|---|---|---|
| CerebroNexus | I1 | ok | auto | auto | n/a | n/a | n/a | n/a |  | False |
| CerebroNexus | I2 | ok | auto | auto | auto | auto | n/a | n/a |  | False |
| CerebroNexus | I3 | ok | auto | auto | n/a | n/a | auto | auto |  | False |
| CerebroNexus | I4 | error | error | error | n/a | n/a | n/a | n/a | rejected | False |
| ShinyCell | I1 | ok | auto | auto | n/a | n/a | n/a | n/a |  | True |
| ShinyCell | I2 | ok | auto | auto | absent | absent | n/a | n/a |  | False |
| ShinyCell | I3 | ok | auto | auto | n/a | n/a | absent | absent |  | True |
| ShinyCell | I4 | ok | auto | auto | n/a | n/a | n/a | n/a | silent | True |
| iSEE | I1 | ok | auto | auto | n/a | n/a | n/a | n/a |  | True |
| iSEE | I2 | ok | auto | auto | absent | auto | n/a | n/a |  | False |
| iSEE | I3 | ok | auto | auto | n/a | n/a | absent | absent |  | True |
| iSEE | I4 | ok | auto | auto | n/a | n/a | n/a | n/a | silent | False |
| cellxgene | I1 | ok | auto | auto | n/a | n/a | n/a | n/a |  | False |
| cellxgene | I2 | ok | auto | auto | absent | auto | n/a | n/a |  | False |
| cellxgene | I3 | ok | auto | auto | n/a | n/a | absent | absent |  | False |
| cellxgene | I4 | error | error | error | n/a | n/a | n/a | n/a | rejected | False |
| Vitessce | I1 | ok | manual | manual | n/a | n/a | n/a | n/a |  | False |
| Vitessce | I2 | ok | manual | manual | absent | manual | n/a | n/a |  | False |
| Vitessce | I3 | ok | manual | manual | n/a | n/a | manual | absent |  | False |
| Vitessce | I4 | ok | manual | manual | n/a | n/a | n/a | n/a | silent | False |

Details, errors and notes per row: `task1_<tool>.csv|json`.

## Task 2: selection retrieval (Jaccard index with the truth set)

S1 = I1 cells with louvain == 'B cells' (342); S2 = I2 cells with the most frequent CTaa (11). Three runs per row; all identical.

| Tool | Set | Route | Result | Jaccard | Exported | Precision | Recall |
|---|---|---|---|---|---|---|---|
| CerebroNexus | S1 | attribute (group filter + lasso) | ok | 1.0 | 342 | 1.0 | 1.0 |
| CerebroNexus | S1 | region (lasso) | ok | 0.9771 | 350 | 0.9771 | 1.0 |
| CerebroNexus | S2 | attribute (group filter + lasso) | route not found | - | - | - | - |
| CerebroNexus | S2 | region (lasso) | ok | 0.6471 | 17 | 0.6471 | 1.0 |
| ShinyCell | S1 | none available (region or attribute) | no export route | - | - | - | - |
| ShinyCell | S2 | none available (region or attribute) | no export route | - | - | - | - |
| Vitessce | S1 | attribute (cell set) | ok | 1.0 | 342 | 1.0 | 1.0 |
| Vitessce | S1 | region (lasso) | ok | 0.9743 | 349 | 0.9771 | 0.9971 |
| Vitessce | S2 | attribute (cell set) | ok | 1.0 | 11 | 1.0 | 1.0 |
| Vitessce | S2 | region (lasso) | ok | 0.5294 | 15 | 0.6 | 0.8182 |
| cellxgene | S1 | attribute (category value) | ok | 1.0 | 342 | 1.0 | 1.0 |
| cellxgene | S1 | region (lasso) | ok | 0.9771 | 350 | 0.9771 | 1.0 |
| cellxgene | S2 | attribute (category value) | ok | 1.0 | 11 | 1.0 | 1.0 |
| cellxgene | S2 | region (lasso) | ok | 0.6471 | 17 | 0.6471 | 1.0 |
| iSEE | S1 | attribute (table column filter) | ok | 0.1296 | 2638 | 0.1296 | 1.0 |
| iSEE | S1 | region (box brush) | ok | 0.1296 | 2638 | 0.1296 | 1.0 |
| iSEE | S1 | region (lasso, Shift+click waypoints) | ok | 0.9744 | 351 | 0.9744 | 1.0 |
| iSEE | S2 | attribute (table column filter) | ok | 0.022 | 500 | 0.022 | 1.0 |
| iSEE | S2 | region (box brush) | ok | 0.022 | 500 | 0.022 | 1.0 |
| iSEE | S2 | region (lasso, Shift+click waypoints) | ok | 0.022 | 500 | 0.022 | 1.0 |

Notes per row: `task2_summary.csv`.

## Task 3: scale (E18 first 10,000 / 100,000 / 500,000 cells)

Median (min-max) over `ok` runs. `Builds ok` and `Starts ok` give ok / all attempted rows (failed, timed-out and not-run rows are in the raw tables and in the status columns of `summary_task3.csv`). Start metrics use all starts (nine per config and tier). Build time of cellxgene is n/a (it reads the `.h5ad`); its artifact is the `.h5ad`.

| Tier | Config | Builds ok | Build s | Artifact GB | Starts ok | Ready s | First plot s | Total s | Server peak RSS GB | Chrome peak RSS GB |
|---|---|---|---|---|---|---|---|---|---|---|
| 10,000 | cerebronexus_default | 3/3 | 10.1 (9.9-10.2) | 0.04 (0.04-0.04) | 9/9 | 3.7 (3.7-3.8) | 1.53 (1.48-1.90) | 5.3 (5.2-5.6) | 1.29 (1.28-1.29) | 0.77 (0.76-0.78) |
| 10,000 | cerebronexus_h5 | 3/3 | 12.5 (12.3-12.8) | 0.23 (0.23-0.23) | 9/9 | 3.2 (2.7-3.2) | 1.58 (1.53-1.88) | 4.8 (4.2-4.9) | 0.48 (0.48-0.49) | 0.77 (0.76-0.77) |
| 10,000 | shinycell | 3/3 | 21.4 (21.1-22.9) | 0.09 (0.09-0.09) | 9/9 | 1.5 (1.4-1.5) | 2.88 (2.53-2.93) | 4.3 (4.0-4.4) | 0.45 (0.45-0.45) | 0.66 (0.65-0.66) |
| 10,000 | isee | 3/3 | 8.1 (8.1-8.4) | 0.23 (0.23-0.23) | 9/9 | 6.4 (6.4-6.4) | 6.80 (6.70-7.07) | 13.2 (13.1-13.5) | 1.52 (1.50-1.52) | 0.74 (0.73-0.75) |
| 10,000 | cellxgene | 3/3 | - | 0.16 (0.16-0.16) | 9/9 | 6.4 (5.8-6.4) | 0.74 (0.73-0.79) | 7.1 (6.5-7.1) | 0.40 (0.40-0.40) | 0.63 (0.63-0.65) |
| 10,000 | vitessce | 3/3 | 2.8 (2.6-6.0) | 0.08 (0.08-0.08) | 9/9 | 0.5 (0.5-0.6) | 1.29 (1.25-1.47) | 1.8 (1.8-2.0) | 0.03 (0.03-0.03) | 0.77 (0.76-0.77) |
| 100,000 | cerebronexus_default | 3/3 | 28.2 (28.1-29.6) | 0.36 (0.36-0.36) | 9/9 | 6.4 (6.4-7.0) | 1.74 (1.67-1.84) | 8.2 (8.1-8.7) | 6.57 (6.57-6.59) | 0.79 (0.79-0.81) |
| 100,000 | cerebronexus_h5 | 3/3 | 73.3 (71.6-76.6) | 2.22 (2.22-2.22) | 9/9 | 3.2 (2.7-3.2) | 1.70 (1.58-2.07) | 4.9 (4.3-5.3) | 0.48 (0.47-0.50) | 0.79 (0.79-0.80) |
| 100,000 | shinycell | 3/3 | 139.2 (131.6-141.5) | 0.82 (0.82-0.82) | 9/9 | 1.5 (1.4-1.6) | 3.95 (3.90-4.00) | 5.5 (5.4-5.6) | 0.50 (0.48-0.50) | 0.65 (0.65-0.66) |
| 100,000 | isee | 3/3 | 26.1 (25.7-27.5) | 2.26 (2.26-2.26) | 9/9 | 9.0 (8.5-9.1) | 11.63 (11.26-11.92) | 20.7 (19.8-21.0) | 3.91 (3.83-3.97) | 0.70 (0.69-0.70) |
| 100,000 | cellxgene | 3/3 | - | 1.50 (1.50-1.50) | 9/9 | 6.9 (6.9-7.4) | 0.77 (0.73-0.81) | 7.7 (7.6-8.2) | 1.76 (1.76-1.76) | 0.66 (0.65-0.66) |
| 100,000 | vitessce | 3/3 | 8.7 (8.5-9.0) | 0.79 (0.79-0.79) | 9/9 | 0.6 (0.5-0.6) | 1.68 (1.66-2.13) | 2.2 (2.2-2.7) | 0.03 (0.03-0.03) | 0.91 (0.90-0.92) |
| 500,000 | cerebronexus_default | 3/3 | 165.0 (165.0-165.3) | 1.83 (1.83-1.83) | 9/9 | 20.6 (20.6-20.6) | 2.54 (2.49-2.72) | 23.2 (23.1-23.4) | 15.81 (15.81-15.82) | 0.85 (0.84-0.90) |
| 500,000 | cerebronexus_h5 | 3/3 | 876.1 (876.0-876.7) | 11.43 (11.43-11.43) | 9/9 | 3.2 (3.2-3.2) | 1.95 (1.86-2.10) | 5.2 (5.1-5.3) | 0.56 (0.55-0.56) | 0.86 (0.84-0.87) |
| 500,000 | shinycell | 3/3 | 723.5 (723.4-724.4) | 4.21 (4.21-4.21) | 9/9 | 1.5 (1.4-1.5) | 8.01 (7.81-8.05) | 9.5 (9.3-9.5) | 0.75 (0.75-0.75) | 0.66 (0.66-0.66) |
| 500,000 | isee | 3/3 | 122.5 (122.5-122.7) | 11.64 (11.64-11.64) | 9/9 | 18.0 (18.0-18.5) | 32.38 (32.16-32.78) | 50.4 (50.2-51.2) | 14.91 (14.35-15.00) | 0.69 (0.67-0.71) |
| 500,000 | cellxgene | 3/3 | - | 7.73 (7.73-7.73) | 9/9 | 10.6 (10.0-10.6) | 0.81 (0.78-0.82) | 11.4 (10.8-11.4) | 8.02 (8.02-8.05) | 0.73 (0.73-0.97) |
| 500,000 | vitessce | 3/3 | 29.1 (28.9-31.0) | 4.02 (4.02-4.02) | 9/9 | 0.5 (0.5-0.6) | 4.34 (4.05-4.74) | 4.9 (4.6-5.3) | 0.03 (0.03-0.03) | 1.36 (1.34-1.39) |

