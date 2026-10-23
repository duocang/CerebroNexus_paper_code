# Run logs and evidence screenshots

Nothing in this folder is a figure panel. The images here are 1× frames saved by the harness as proof that a run drew a plot (`PROTOCOL.md` 7.5 and 9); they show each tool's default view and are not comparable across tools. Figure panels are in `../captures/`, made as described in `../FIGURES.md`.

| Folder | What it holds | Used in the tables |
|---|---|---|
| `setup/` | download, R, Python and npm install logs | no |
| `pilot/` | one build and start per tool on I1 and the 10,000-cell tier (PROTOCOL 8) | no |
| `task1/` | Task 1 import logs and UI-check frames | yes, `results/task1_*` |
| `task2/` | Task 2 selection and export logs and frames | yes, `results/task2_*` |
| `task3/<tier>/` | Task 3 build and serve logs per run | yes, `results/task3_*` |
| `screens/` | Task 3 accepted first-plot frame per start (`<tier>_<config>_b<build>_s<start>.png`) | evidence for `t_first_plot_s` |
