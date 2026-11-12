"""Pilot of round 3 (PROTOCOL_round3.md section 12). Nothing it writes enters a table.

Everything goes to a scratch folder outside the repository (PILOT3_DIR): the R library with the round-3
CerebroNexus (rlib/), its builds, the cache directories, logs and frames.

    python scripts/run/pilot3.py build  <tier> [cerebronexus_h5 cerebronexus_default]
    python scripts/run/pilot3.py starts <tier> <n> [tool ...]        n starts per tool, tools interleaved; the cache is emptied before the first
    python scripts/run/pilot3.py show   <tier>
"""
import csv, json, os, shutil, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import harness as H
import harness3 as H3

PILOT = os.environ.get("PILOT3_DIR", "C:/Users/wangx/Projects/catch/tool_comparison/20261112_round3-pilot")
LIB = os.environ.get("PILOT3_LIB", os.path.join(PILOT, "rlib"))      # another CerebroNexus build to compare with
OUT = os.environ.get("PILOT3_OUT", os.path.join(PILOT, "out"))
CACHE = os.environ.get("PILOT3_CACHE", os.path.join(PILOT, "cache"))
IDLE_LIMIT = float(os.environ.get("PILOT3_IDLE_LIMIT", "15"))        # % CPU: a start waits for a host below it (protocol section 4)
IDLE_PATIENCE = float(os.environ.get("PILOT3_IDLE_PATIENCE", "600"))  # s it waits; a pilot on a busy host sets 0 and says so


def tier_input(tier):
    return os.path.join(H.HERE, "data", "inputs", f"e18_{tier}.h5ad")


def artifact(tool, tier):
    """Where the tool's artifact of the tier is: CerebroNexus built by this pilot, the others by the round-2 pilot."""
    if tool.startswith("cerebronexus"):
        config = "cerebronexus_default" if tool == "cerebronexus_default" else "cerebronexus_h5"
        return os.path.join(PILOT, "builds", f"{config}_{tier}")
    if tool == "cellxgene":
        return tier_input(tier)
    return os.path.join(H.HERE, "data", "builds", f"pilot_{tool}_e18_{tier}")


def wait_idle(limit=IDLE_LIMIT, patience=IDLE_PATIENCE):
    t0 = time.time()
    while True:
        cpu = H3.idle_cpu(3.0)
        if cpu < limit or time.time() - t0 > patience:
            return cpu, time.time() - t0
        time.sleep(2)


def build(tier, configs):
    for config in configs:
        art = artifact(config, tier)
        shutil.rmtree(art, ignore_errors=True)
        mode = "embedded" if config == "cerebronexus_default" else "h5"
        spec = dict(cmd=[H.RSCRIPT, "--vanilla", os.path.join(H.HERE, "scripts", "run", "tools", "cerebronexus_build.R"),
                         tier_input(tier), art, mode, "cluster", "nUMI", "nGene"],
                    env=H3.cerebro_env(LIB, os.path.join(CACHE, "build")))
        os.makedirs(os.path.join(OUT, "logs"), exist_ok=True)
        b = H.run_build(spec, os.path.join(OUT, "logs", f"{config}_{tier}_build.log"))
        files = sorted(os.listdir(art)) if os.path.isdir(art) else []
        print(config, tier, b["status"], f"{b['wall_s']:.1f} s", f"{H.dir_size(art) / 2**20:.0f} MB" if files else "", files, flush=True)


def starts(tier, n, tools):
    rows_path = os.path.join(OUT, f"starts_{tier}.csv")
    fields = ["tier", "tool", "start_idx", "start_class", "status", "t_ready_s", "t_first_pixels_s", "first_pixels_element", "t_plot_element_s", "t_interactive_s", "interactive_status",
              "n_frames", "frame_gap_ms_p95", "n_gestures", "bytes_first_pixels", "requests_first_pixels", "bytes_interactive",
              "server_peak_rss_gb", "browser_peak_rss_gb", "idle_cpu_pct_before", "waited_for_idle_s", "cache_files", "started_at", "error"]
    os.makedirs(OUT, exist_ok=True)
    new = not os.path.exists(rows_path)
    with open(rows_path, "a", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=fields, extrasaction="ignore")
        if new:
            w.writeheader()
        for tool in tools:
            shutil.rmtree(os.path.join(CACHE, tool, str(tier)), ignore_errors=True)
        for j in range(1, n + 1):
            for tool in tools:
                cache = os.path.join(CACHE, tool, str(tier))
                art = artifact(tool, tier)
                prefix = os.path.join(OUT, f"t{tier}", f"{tool}_{j}")
                os.makedirs(os.path.dirname(prefix), exist_ok=True)
                cpu, waited = wait_idle()
                spec = H3.serve_spec(tool, art, art, H3.PORTS[tool], LIB, cache)
                started = time.strftime("%Y-%m-%d %H:%M:%S")
                r = H3.run_start(spec, H3.PORTS[tool], H3.PLOT[tool], prefix + "_serve.log", prefix)
                json.dump(r, open(prefix + ".json", "w"), indent=1, default=str)
                kept = sum(len(fs) for _, _, fs in os.walk(cache))
                row = dict(tier=tier, tool=tool, start_idx=j, start_class="first_start" if j == 1 else "later_start", started_at=started,
                           idle_cpu_pct_before=round(cpu, 1), waited_for_idle_s=round(waited, 1), cache_files=kept,
                           server_peak_rss_gb=round(r.get("peak_rss_bytes", 0) / 2**30, 3),
                           browser_peak_rss_gb=round(r.get("browser_peak_rss_bytes", 0) / 2**30, 3),
                           bytes_first_pixels=(r.get("received_first_pixels") or {}).get("bytes"),
                           requests_first_pixels=(r.get("received_first_pixels") or {}).get("requests"),
                           bytes_interactive=(r.get("received_interactive") or {}).get("bytes"), **r)
                w.writerow(row); fh.flush()
                print(f"{tool:24s} {j} {r.get('status'):8s} ready {r.get('t_ready_s', float('nan')):6.2f}  first pixels {r.get('t_first_pixels_s', float('nan')):6.2f}"
                      f" ({r.get('first_pixels_element')}; plot element {r.get('t_plot_element_s')})  interactive {r.get('t_interactive_s', float('nan')):6.2f}  frames {r.get('n_frames', 0):4d} (p95 gap {r.get('frame_gap_ms_p95')} ms)"
                      f"  gestures {r.get('n_gestures', 0):3d}  cache files {kept}  idle {cpu:.0f}%  {r.get('interactive_status', '') or ''} {r.get('error', '') or ''}", flush=True)


def show(tier):
    import statistics as st
    rows = list(csv.DictReader(open(os.path.join(OUT, f"starts_{tier}.csv"), encoding="utf-8")))
    for tool in H3.TOOLS:
        for cls in ("first_start", "later_start"):
            rs = [r for r in rows if r["tool"] == tool and r["start_class"] == cls and r["status"] == "ok"]
            if not rs:
                continue
            med = lambda k: st.median(float(r[k]) for r in rs if r[k] not in ("", "nan"))
            has = lambda k: any(r[k] not in ("", "nan") for r in rs)
            print(f"{tool:24s} {cls:12s} n={len(rs)}  ready {med('t_ready_s'):.2f}  first pixels {med('t_first_pixels_s'):.2f}"
                  f"  interactive {med('t_interactive_s'):.2f}" if has("t_interactive_s") else
                  f"{tool:24s} {cls:12s} n={len(rs)}  ready {med('t_ready_s'):.2f}  first pixels {med('t_first_pixels_s'):.2f}  interactive n/a")


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "build":
        build(int(sys.argv[2]), sys.argv[3:] or ["cerebronexus_h5", "cerebronexus_default"])
    elif cmd == "starts":
        starts(int(sys.argv[2]), int(sys.argv[3]), sys.argv[4:] or H3.TOOLS)
    elif cmd == "show":
        show(int(sys.argv[2]))
