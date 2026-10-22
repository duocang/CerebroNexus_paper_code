# Viewer smoke check

Check that a real CRB loads and supports rendering, selection, zoom and gene switching. Run from a CerebroNexus checkout in Linux or WSL, with this repository cloned beside it and Chrome/Chromium available. The checkout is installed into a temporary library and checked:

```bash
cd CerebroNexus
nix-shell default.nix -A shell
bash ../CerebroNexus_paper_code/topics/viewer_performance/run.sh smoke /data/brain.crb

# Check several files in one run.
bash ../CerebroNexus_paper_code/topics/viewer_performance/run.sh smoke /data/brain.crb /data/pfc.crb
```

The command prints the report location. By default, each run gets a directory under `${XDG_CACHE_HOME:-$HOME/.cache}/cerebronexus-benchmark/viewer-smoke/` containing `summary.md`, `viewer_validation.csv`, screenshots and `install.log`.

Set `VIEWER_VALIDATION_RESULT_DIR` to choose another output directory; it must not already exist, so previous reports and screenshots are preserved. `VIEWER_VALIDATION_TIMEOUT` changes the per-step timeout in milliseconds (default: 300000).

This checks functionality. It does not change backend benchmark results or measure repeated page-performance trials.
