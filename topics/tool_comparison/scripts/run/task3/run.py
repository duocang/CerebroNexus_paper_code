"""Task 3 orchestrator (PROTOCOL section 7). Sequential, resumable.

    python scripts/run/task3/run.py run [tier ...]        tiers: 10000 100000 500000 (default: all, in this order)
    python scripts/run/task3/run.py status

For every tier: three rounds; in a round every config is built once (seeded random order) and the build is started three times in new
process trees. Rows are appended to results/task3/task3_builds.csv and results/task3/task3_starts.csv as soon as they exist, so an interrupted run
resumes where it stopped (a finished row is never repeated). Nothing is dropped: failed, timed-out and not-run attempts are rows too.
"""
import csv, datetime, json, os, random, shutil, subprocess, sys, time, traceback
import psutil
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import harness
from harness import HERE

SEED = 20261026
TIERS = [10000, 100000, 500000]
CONFIGS = harness.TOOLS_ORDER                       # cerebronexus_default, cerebronexus_h5, shinycell, isee, cellxgene, vitessce
ROUNDS, STARTS = 3, 3
RES = os.path.join(HERE, "results", "task3")
BUILDS_CSV = os.path.join(RES, "task3_builds.csv")
STARTS_CSV = os.path.join(RES, "task3_starts.csv")
EMBEDDING_SHOWN = {"cerebronexus_default": "UMAP", "cerebronexus_h5": "UMAP", "shinycell": "UMAP", "isee": "X_pca (first reducedDim, D1)",
                   "cellxgene": "umap", "vitessce": "UMAP"}
BUILD_FIELDS = ["tier", "config", "build_idx", "status", "reason", "wall_s", "read_input_s", "tool_step_s", "peak_rss_bytes", "exit_code",
                "artifact_bytes", "artifact_files", "log", "started_at", "idle_cpu_pct_before", "free_disk_gb_before"]
START_FIELDS = ["tier", "config", "build_idx", "start_idx", "status", "reason", "t_ready_s", "t_first_plot_s", "t_total_s", "peak_rss_bytes",
                "browser_peak_rss_bytes", "ink_fraction", "frames", "screenshot_s", "elem_w", "elem_h", "embedding_shown", "screenshot", "log",
                "started_at", "idle_cpu_pct_before", "error"]


def read_rows(path):
    if not os.path.exists(path):
        return []
    return list(csv.DictReader(open(path, encoding="utf-8")))


def append_row(path, fields, row):
    new = not os.path.exists(path)
    with open(path, "a", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        if new:
            w.writeheader()
        w.writerow(row)


def rmtree(path):
    if os.path.isdir(path):
        subprocess.run(["cmd", "/c", "rmdir", "/s", "/q", path], capture_output=True)


def idle_cpu_before():
    return round(psutil.cpu_percent(interval=3.0), 1)


def order_for_tiers():
    """One seeded random order of the configs per (tier, round); drawn in a fixed sequence so it is reproducible."""
    rng = random.Random(SEED)
    out = {}
    for t in TIERS:
        for r in range(1, ROUNDS + 1):
            o = list(CONFIGS)
            rng.shuffle(o)
            out[(t, r)] = o
    return out


def done_keys():
    b = {(int(r["tier"]), r["config"], int(r["build_idx"])) for r in read_rows(BUILDS_CSV)}
    s = {(int(r["tier"]), r["config"], int(r["build_idx"]), int(r["start_idx"])) for r in read_rows(STARTS_CSV)}
    return b, s


def stop_rule_active(tier, config):
    """True when build 1 of this config in this tier ended in timeout or oom (builds 2 and 3 are then not run)."""
    for r in read_rows(BUILDS_CSV):
        if int(r["tier"]) == tier and r["config"] == config and int(r["build_idx"]) == 1 and r["status"] in ("timeout", "oom"):
            return True
    return False


def run_one(tier, config, k, dsname, ds):
    done_b, done_s = done_keys()
    tag = f"{tier}_{config}_b{k}"
    logdir = os.path.join(HERE, "results", "evidence", "task3", str(tier)); os.makedirs(logdir, exist_ok=True)
    screens = os.path.join(HERE, "results", "evidence", "screens"); os.makedirs(screens, exist_ok=True)
    inp = harness.input_for(config, ds)
    art = os.path.join(HERE, "data", "builds", "t3", str(tier), f"{config}_b{k}")
    now = lambda: datetime.datetime.now().astimezone().isoformat(timespec="seconds")
    brow = dict(tier=tier, config=config, build_idx=k, started_at=now())
    # ------------------------------------------------------------------ build
    if (tier, config, k) not in done_b:
        if k > 1 and stop_rule_active(tier, config):
            brow.update(status="not_run", reason="stop rule (build 1 timed out or ran out of memory)")
            append_row(BUILDS_CSV, BUILD_FIELDS, brow)
        else:
            rmtree(art)
            spec = harness.build_spec(config, ds, inp, art)
            brow["idle_cpu_pct_before"] = idle_cpu_before()
            brow["free_disk_gb_before"] = round(psutil.disk_usage(HERE).free / 2**30, 1)
            if spec is None:
                brow.update(status="n/a", reason="reads the input file directly", artifact_bytes=os.path.getsize(inp), artifact_files=1)
            else:
                log = os.path.join(logdir, f"{config}_b{k}_build.log")
                b = harness.run_build(spec, log)
                brow.update(status=b["status"], wall_s=round(b["wall_s"], 3), peak_rss_bytes=b["peak_rss_bytes"], exit_code=b["exit_code"],
                            read_input_s=b.get("read_input"), tool_step_s=b.get("tool_step"), log=os.path.relpath(log, HERE))
                if b["status"] == "ok":
                    brow["artifact_bytes"] = harness.dir_size(art)
                    brow["artifact_files"] = sum(len(fs) for _, _, fs in os.walk(art))
                else:
                    brow["reason"] = (open(log, encoding="utf-8", errors="replace").read()[-300:]).replace("\n", " ")
            append_row(BUILDS_CSV, BUILD_FIELDS, brow)
            print(f"[{now()}] build {tag}: {brow['status']} {brow.get('wall_s')}s", flush=True)
    build_row = [r for r in read_rows(BUILDS_CSV) if int(r["tier"]) == tier and r["config"] == config and int(r["build_idx"]) == k][0]
    # ------------------------------------------------------------------ starts
    for j in range(1, STARTS + 1):
        if (tier, config, k, j) in done_s:
            continue
        srow = dict(tier=tier, config=config, build_idx=k, start_idx=j, started_at=now(), embedding_shown=EMBEDDING_SHOWN[config])
        if build_row["status"] not in ("ok", "n/a"):
            srow.update(status="not_run", reason=f"build {build_row['status']}")
            append_row(STARTS_CSV, START_FIELDS, srow); continue
        srow["idle_cpu_pct_before"] = idle_cpu_before()
        art_path = inp if build_row["status"] == "n/a" else art
        log = os.path.join(logdir, f"{config}_b{k}_s{j}_serve.log")
        shot = os.path.join(screens, f"{tier}_{config}_b{k}_s{j}.png")
        try:
            s = harness.run_start(harness.serve_spec(config, art_path, inp, harness.PORTS[config]), harness.PORTS[config], harness.PLOT[config], log, shot)
        except Exception:
            s = dict(status="error", error=traceback.format_exc()[-300:])
        srow.update(status=s.get("status"), reason=s.get("error") or s.get("plot_error"), t_ready_s=s.get("t_ready_s"), t_first_plot_s=s.get("t_first_plot_s"),
                    t_total_s=s.get("t_total_s"), peak_rss_bytes=s.get("peak_rss_bytes"), browser_peak_rss_bytes=s.get("browser_peak_rss_bytes"),
                    ink_fraction=s.get("ink_fraction"), frames=s.get("frames"), screenshot_s=s.get("screenshot_s"), elem_w=s.get("elem_w"), elem_h=s.get("elem_h"),
                    screenshot=os.path.relpath(shot, HERE) if os.path.exists(shot) else None, log=os.path.relpath(log, HERE), error=s.get("error"))
        if s.get("frame_series"):
            json.dump(s["frame_series"], open(os.path.join(logdir, f"{config}_b{k}_s{j}_frames.json"), "w"))
        append_row(STARTS_CSV, START_FIELDS, srow)
        print(f"[{now()}] start {tag}_s{j}: {srow['status']} ready={srow.get('t_ready_s')} first_plot={srow.get('t_first_plot_s')}", flush=True)
    if build_row["status"] == "ok":
        rmtree(art)


def run(tiers):
    os.makedirs(RES, exist_ok=True)
    orders = order_for_tiers()
    for tier in tiers:
        dsname = f"e18_{tier}"; ds = harness.DATASETS[dsname]
        print(f"=== tier {tier}", flush=True)
        for r in range(1, ROUNDS + 1):
            for config in orders[(tier, r)]:
                run_one(tier, config, r, dsname, ds)


def status():
    b, s = read_rows(BUILDS_CSV), read_rows(STARTS_CSV)
    for t in TIERS:
        for c in CONFIGS:
            bb = [r for r in b if int(r["tier"]) == t and r["config"] == c]
            ss = [r for r in s if int(r["tier"]) == t and r["config"] == c]
            print(t, c, "builds", len(bb), "/3", "starts", len(ss), "/9", "ok starts", sum(r["status"] == "ok" for r in ss))


if __name__ == "__main__":
    if sys.argv[1] == "run":
        run([int(x) for x in sys.argv[2:]] or TIERS)
    elif sys.argv[1] == "status":
        status()
