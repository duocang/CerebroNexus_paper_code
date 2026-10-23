# Task 2 rerun: CerebroNexus attribute route through Group filters

## What was wrong

`results/task2_summary.csv` records the CerebroNexus attribute route as `route not found`: the run looked only at the legend of the Projection tab, where a click hides or shows a group but makes no selection. It missed the Group filters of the same tab. In CerebroNexus 6.0.0 (commit 27ac995e, the one installed for the study) a cell removed by a group filter is inactive, and inactive cells "are drawn in no panel and are not selectable" (`inst/viewer/www/cell_views.js`, `activeCell()`). So the attribute route exists:

1. Projection tab, projection UMAP (S1) or umap (S2).
2. Group filters: keep only the target value, everything else off.
3. Lasso around all remaining cells.
4. Table of selected cells, Show 1,000 entries, Download, CSV.

Step 3 is a lasso, but what decides which cells are selected is the filter, not the outline, so it is an attribute route as defined in `PROTOCOL.md` section 6 ("the tool's own select/filter by metadata value").

## What to run (Windows host, after FIGURES.md step 1)

Only CerebroNexus, only the attribute route, S1 and S2, three runs each, with the same artifacts, server script, browser settings and export path as `scripts/task2/t2_cerebronexus.py`. Add a route argument to that script (`region` stays the default, `attribute` is new) rather than writing a second harness.

- **S1** (`louvain == "B cells"`, 342 cells): Group filters on `louvain`, only `B cells` kept.
- **S2** (most frequent `CTaa`, 11 cells): Group filters only list the grouping variables registered at export. If `CTaa` (or a clonotype group carrying it) is not among them in the I2 CRB, record the S2 attribute route as `route not found` with a screenshot of the Group filters list as evidence, and say which groups were offered. Do not rebuild the CRB with extra groups for this run; that would change the import route graded in Task 1.

Lasso: drag a rectangle-like polygon around the whole plot area (inset 2 px from the canvas edge), so that the outline cannot cut any kept cell. Record the "Selected n / N cells" text before the download.

Per run, save a row as `results/task2_raw/cerebronexus_<S1|S2>_attribute_<rep>.json` with the same fields as the region rows (`route = "attribute (group filter + lasso)"`, `export_route`, `route_steps`, metrics, `ui_selected_text`, the group filter values set). Screenshots and CSVs go to `logs/task2/` as `cerebronexus_<set>_attribute_<rep>.*`.

## Then

1. `scripts/task2/aggregate.py` hard-codes a `route not found` row for the CerebroNexus attribute route of both sets (`extra`, `CN_NOTE`). Add that row only for a set that has no `cerebronexus_<set>_attribute_*` raw rows, and give the new rows a note saying the selection is made by the Group filter and the lasso only encloses the kept cells. Then rerun `scripts/task2/aggregate.py` (writes `results/task2_cerebronexus.csv` and `results/task2_summary.csv`) and `scripts/make_summary.py` (writes `results/SUMMARY.md`). The old `route not found` rows are replaced; keep a copy of the previous `task2_cerebronexus.csv` and `task2_summary.csv` under `results/superseded_task2_attribute/`.
2. Add Deviation **D14** at the end of `PROTOCOL.md` (after the Deviations heading, so the body hash in `results/PROTOCOL_body.sha256` stays valid; check it): the attribute route of CerebroNexus was missed in the first Task 2 run (legend only, Group filters not tried) and was run afterwards on <date> with the steps above; the region rows are unchanged.
3. Add an entry to `PROGRESS.md`.
4. Commit and push. The figure (`figures/fig-tool-comparison.pdf`, panel b) is redrawn from `task2_summary.csv` by the targets pipeline; nothing in `functions.R` needs to change as long as the route name starts with `attribute`.
