"""results/task3_builds.csv + task3_starts.csv -> results/summary_task3.csv and .md (median and min-max over ok runs, n_ok/n_total)."""
import os, sys
import numpy as np, pandas as pd
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
R = os.path.join(HERE, "results")
b = pd.read_csv(os.path.join(R, "task3_builds.csv"), keep_default_na=False, na_values=[""]); s = pd.read_csv(os.path.join(R, "task3_starts.csv"), keep_default_na=False, na_values=[""])
CONFIGS = ["cerebronexus_default", "cerebronexus_h5", "shinycell", "isee", "cellxgene", "vitessce"]
def stat(x):
    x = pd.to_numeric(x, errors="coerce").dropna()
    return (float(x.median()), float(x.min()), float(x.max())) if len(x) else (np.nan, np.nan, np.nan)
rows = []
for tier in sorted(b.tier.unique()):
    for c in CONFIGS:
        bb = b[(b.tier == tier) & (b.config == c)]; ss = s[(s.tier == tier) & (s.config == c)]
        r = dict(tier=tier, config=c)
        built = bb[bb.status.isin(["ok", "n/a"])]
        r["builds_ok"] = f"{int((bb.status == 'ok').sum() + (bb.status == 'n/a').sum())}/{len(bb)}"
        r["build_statuses"] = ",".join(bb.status.astype(str))
        for name, col in (("build_s", "wall_s"), ("build_peak_rss_gb", "peak_rss_bytes"), ("artifact_gb", "artifact_bytes")):
            x = pd.to_numeric(bb[bb.status == "ok"][col] if name != "artifact_gb" else built[col], errors="coerce")
            if name.endswith("gb"): x = x / 2**30
            r[name + "_median"], r[name + "_min"], r[name + "_max"] = stat(x)
        r["starts_ok"] = f"{int((ss.status == 'ok').sum())}/{len(ss)}"
        r["start_statuses"] = ",".join(sorted(ss.status.astype(str).unique()))
        ok = ss[ss.status == "ok"]
        for name, col, div in (("ready_s", "t_ready_s", 1), ("first_plot_s", "t_first_plot_s", 1), ("total_s", "t_total_s", 1),
                               ("server_peak_rss_gb", "peak_rss_bytes", 2**30), ("browser_peak_rss_gb", "browser_peak_rss_bytes", 2**30)):
            x = pd.to_numeric(ok[col], errors="coerce") / div
            r[name + "_median"], r[name + "_min"], r[name + "_max"] = stat(x)
            pb = (pd.to_numeric(ok[col], errors="coerce") / div).groupby(ok.build_idx).median()   # median per build, then median of those
            r[name + "_median_of_builds"] = float(pb.median()) if len(pb) else np.nan
        rows.append(r)
out = pd.DataFrame(rows)
out.to_csv(os.path.join(R, "summary_task3.csv"), index=False)
def fmt(m, lo, hi, nd=1):
    return "-" if pd.isna(m) else f"{m:.{nd}f} ({lo:.{nd}f}-{hi:.{nd}f})"
lines = ["| Tier | Config | Builds ok | Build s | Artifact GB | Starts ok | Ready s | First plot s | Total s | Server peak RSS GB | Chrome peak RSS GB |", "|---|---|---|---|---|---|---|---|---|---|---|"]
for _, r in out.iterrows():
    lines.append(f"| {int(r.tier):,} | {r.config} | {r.builds_ok} | {fmt(r.build_s_median, r.build_s_min, r.build_s_max)} | {fmt(r.artifact_gb_median, r.artifact_gb_min, r.artifact_gb_max, 2)} | {r.starts_ok} | "
                 f"{fmt(r.ready_s_median, r.ready_s_min, r.ready_s_max)} | {fmt(r.first_plot_s_median, r.first_plot_s_min, r.first_plot_s_max, 2)} | {fmt(r.total_s_median, r.total_s_min, r.total_s_max)} | "
                 f"{fmt(r.server_peak_rss_gb_median, r.server_peak_rss_gb_min, r.server_peak_rss_gb_max, 2)} | {fmt(r.browser_peak_rss_gb_median, r.browser_peak_rss_gb_min, r.browser_peak_rss_gb_max, 2)} |")
md = "# Task 3 summary\n\nMedian (min-max) over `ok` runs. `Builds ok` and `Starts ok` give ok / all attempted rows (failed, timed-out and not-run rows are in the raw tables and in the status columns of `summary_task3.csv`). Start metrics use all starts (nine per config and tier). Build time of cellxgene is n/a (it reads the `.h5ad`); its artifact is the `.h5ad`.\n\n" + "\n".join(lines) + "\n"
open(os.path.join(R, "summary_task3.md"), "w", encoding="utf-8").write(md)
print(md)
