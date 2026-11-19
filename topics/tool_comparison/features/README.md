# Capability and selection tables (Figure `fig-tool-capability`)

`capability.csv` (what each viewer does with the default import call: `auto`, `manual` = extra step or code, `absent`;
duplicated cell names: `rejected` or `silent`) and `selection.csv` (Jaccard index of the cells a viewer exports after a
selection with the truth set; empty = no route) were measured once, on 2026-10-27, with the CerebroNexus that was
current then (6.0.0) and the other tools of `manifest.tsv` of that study. They are **not** measured by `bench.py` and have
not been measured again; the study that made them (protocol, scripts, per-run files) is in Git history at commit
`b06a545` (`topics/tool_comparison/results/task1/`, `task2/`, and `scripts/run/task1`, `task2`). Measure them again
before quoting them for a later version.
