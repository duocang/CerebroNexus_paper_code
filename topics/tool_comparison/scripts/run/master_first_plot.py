"""Start to first plot of CerebroNexus master (5.3.1) on an E18 tier: embedded CRB and uncompressed H5 sidecar, repeated starts.
Not part of the pre-registered study; a side check requested after Deviations D14 (see results/master_check/README.md).
Usage: master_first_plot.py <tier> [starts per config, default 2]"""
import csv, datetime, os, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import harness
HERE = harness.HERE
tier = int(sys.argv[1]); starts = int(sys.argv[2]) if len(sys.argv) > 2 else 2
inp = harness.DATASETS[f"e18_{tier}"]["input"]
OUT = os.path.join(HERE, "results", "master_check"); LOG = os.path.join(OUT, "logs"); os.makedirs(LOG, exist_ok=True)
lib = os.path.join(HERE, "data", "builds", "rlib_master"); base = os.path.join(HERE, "env", "rlib")
def env():
    e = harness.r_env(); e["R_LIBS"] = lib + ";" + base; e["R_LIBS_USER"] = lib; return e
RS = harness.RSCRIPT
rows_path = os.path.join(OUT, "start_to_first_plot.csv")
fields = ["tier", "config", "start_idx", "status", "t_ready_s", "t_first_plot_s", "t_total_s", "server_peak_rss_gb", "browser_peak_rss_gb", "ink_fraction", "build_s", "artifact_gb", "started_at", "error"]
for mode, config, port in (("embedded", "master_embedded", 8821), ("h5", "master_h5_uncompressed", 8822)):
    art = os.path.join(HERE, "data", "builds", f"master_{mode}_{tier}")
    crb = os.path.join(art, "cerebro_e18.crb")
    build = None
    if not os.path.exists(crb):
        os.makedirs(art, exist_ok=True)
        spec = dict(cmd=[RS, "--vanilla", os.path.join(HERE, "scripts", "run", "tools", "cerebronexus_master_build.R"), inp, art, mode], env=env())
        build = harness.run_build(spec, os.path.join(LOG, f"{config}_{tier}_build.log"))
        print(config, "build", build["status"], round(build["wall_s"], 1), "s", flush=True)
        if build["status"] != "ok":
            continue
    size = harness.dir_size(art) / 2**30
    for j in range(1, starts + 1):
        serve = dict(cmd=[RS, "--vanilla", os.path.join(HERE, "scripts", "run", "tools", "cerebronexus_master_serve.R"), crb, str(port)], env=env())
        r = harness.run_start(serve, port, harness.PLOT["cerebronexus_default"], os.path.join(LOG, f"{config}_{tier}_s{j}_serve.log"),
                              os.path.join(OUT, "logs", f"{config}_{tier}_s{j}.png"))
        row = dict(tier=tier, config=config, start_idx=j, status=r.get("status"), t_ready_s=r.get("t_ready_s"), t_first_plot_s=r.get("t_first_plot_s"), t_total_s=r.get("t_total_s"),
                   server_peak_rss_gb=(r.get("peak_rss_bytes") or 0) / 2**30, browser_peak_rss_gb=(r.get("browser_peak_rss_bytes") or 0) / 2**30, ink_fraction=r.get("ink_fraction"),
                   build_s=(build or {}).get("wall_s"), artifact_gb=round(size, 2), started_at=datetime.datetime.now().astimezone().isoformat(timespec="seconds"), error=r.get("error") or r.get("plot_error"))
        new = not os.path.exists(rows_path)
        with open(rows_path, "a", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=fields); 
            if new: w.writeheader()
            w.writerow(row)
        print(config, "start", j, row["status"], "ready", row["t_ready_s"], "first_plot", row["t_first_plot_s"], "total", row["t_total_s"], flush=True)
