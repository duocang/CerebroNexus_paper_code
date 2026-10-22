"""Measurement harness for the comparative evaluation (PROTOCOL.md sections 7.4-7.6).

One Python process spawns every tool process, so all durations share one clock (time.perf_counter()).
Run with the comparison Python 3.11 environment (env/py).

    python scripts/harness.py pilot <I1|e18_10000> [tool ...]
"""
import csv, io, json, os, subprocess, sys, threading, time, traceback
import numpy as np
import psutil
import requests
from PIL import Image

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RSCRIPT = r"C:\Program Files\R\R-4.5.0\bin\Rscript.exe"
PY = sys.executable
CONFIG = json.load(open(os.path.join(HERE, "scripts", "harness_config.json"))) if os.path.exists(os.path.join(HERE, "scripts", "harness_config.json")) else {}

BUILD_TIMEOUT = 3600          # s, protocol 7.6
READY_TIMEOUT = 900
PLOT_TIMEOUT = int(os.environ.get("HARNESS_PLOT_TIMEOUT", "900"))   # pilots may shorten it
START_CUTOFF = 1800
SAMPLE_INTERVAL = 0.1         # RSS sampling
FRAME_INTERVAL = 0.25         # first-plot frame sampling
INK_SATURATION = 0.1         # PROTOCOL says 0.4; lowered to 0.1, see Deviations D11 (2026-10-22)
INK_THRESHOLD = 0.01        # PROTOCOL says 2%; lowered to 1% for all tools, see Deviations (2026-10-22)
VIEWPORT = {"width": 1600, "height": 1000}


def r_env():
    e = dict(os.environ)
    lib = os.path.join(HERE, "env", "rlib")
    e.update(LANGUAGE="en", LANG="en_US.UTF-8", LC_ALL="en_US.UTF-8", R_LIBS=lib, R_LIBS_USER=lib, R_LIBS_SITE="",
             R_PROFILE_USER="", R_ENVIRON_USER="")
    return e


def py_env():
    e = dict(os.environ); e.update(PYTHONIOENCODING="utf-8", PYTHONUTF8="1"); return e


def cellxgene_env():
    """cellxgene 1.3.0 queries the GitHub releases API on every start; the unauthenticated rate limit made starts crash after ~35 starts in an
    hour (TypeError in log_upgrade_check). The check is made to fail at once, like on an offline machine (Deviations D12)."""
    e = py_env()
    e.update(HTTPS_PROXY="http://127.0.0.1:9", HTTP_PROXY="http://127.0.0.1:9", NO_PROXY="127.0.0.1,localhost")
    return e


def R(script, *args):
    return dict(cmd=[RSCRIPT, "--vanilla", os.path.join(HERE, "scripts", "tools", script), *map(str, args)], env=r_env())


def P(script, *args):
    return dict(cmd=[PY, "-W", "ignore", script, *map(str, args)], env=py_env())


# ----------------------------------------------------------------------------- process utilities
def tree_rss(proc):
    try:
        root = psutil.Process(proc.pid)
        total = 0
        for p in [root] + root.children(recursive=True):
            try:
                total += p.memory_info().rss
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
        return total
    except psutil.NoSuchProcess:
        return 0


class Sampler(threading.Thread):
    def __init__(self, proc):
        super().__init__(daemon=True); self.proc = proc; self.peak = 0; self.stop_flag = False

    def run(self):
        while not self.stop_flag:
            self.peak = max(self.peak, tree_rss(self.proc)); time.sleep(SAMPLE_INTERVAL)

    def stop(self):
        self.stop_flag = True; self.join(timeout=2)


class BrowserSampler(threading.Thread):
    """Peak RSS of Chrome (descendants of this harness process that are not in the server's process tree). Extra metric."""
    def __init__(self, server_proc):
        super().__init__(daemon=True); self.server = server_proc; self.peak = 0; self.stop_flag = False

    def run(self):
        me = psutil.Process(os.getpid())
        while not self.stop_flag:
            try:
                srv = {self.server.pid}
                try:
                    srv |= {c.pid for c in psutil.Process(self.server.pid).children(recursive=True)}
                except psutil.NoSuchProcess:
                    pass
                tot = 0
                for c in me.children(recursive=True):
                    if c.pid in srv:
                        continue
                    try:
                        tot += c.memory_info().rss
                    except (psutil.NoSuchProcess, psutil.AccessDenied):
                        pass
                self.peak = max(self.peak, tot)
            except Exception:
                pass
            time.sleep(SAMPLE_INTERVAL * 2)

    def stop(self):
        self.stop_flag = True; self.join(timeout=2)


def kill_tree(proc):
    try:
        subprocess.run(["taskkill", "/F", "/T", "/PID", str(proc.pid)], capture_output=True)
    except Exception:
        pass
    try:
        proc.wait(timeout=10)
    except Exception:
        pass


def dir_size(path):
    if os.path.isfile(path):
        return os.path.getsize(path)
    return sum(os.path.getsize(os.path.join(d, f)) for d, _, fs in os.walk(path) for f in fs)


def port_free(port):
    import socket
    s = socket.socket()
    try:
        return s.connect_ex(("127.0.0.1", port)) != 0
    finally:
        s.close()


# ----------------------------------------------------------------------------- build
def run_build(spec, log_path, timeout=BUILD_TIMEOUT):
    """spec = dict(cmd, env). Returns dict(status, wall_s, peak_rss_bytes, exit_code, timings)."""
    t0 = time.perf_counter()
    with open(log_path, "w", encoding="utf-8", errors="replace") as lf:
        proc = subprocess.Popen(spec["cmd"], cwd=HERE, env=spec["env"], stdout=lf, stderr=subprocess.STDOUT)
        sm = Sampler(proc); sm.start()
        status, code = "ok", None
        try:
            code = proc.wait(timeout=timeout)
            if code != 0:
                status = "error"
        except subprocess.TimeoutExpired:
            status = "timeout"; kill_tree(proc)
        wall = time.perf_counter() - t0
        sm.stop()
        kill_tree(proc) if proc.poll() is None else None
    timings = {}
    txt = open(log_path, encoding="utf-8", errors="replace").read()
    for line in txt.splitlines():
        if line.startswith("TIMING "):
            for kv in line[7:].split():
                k, v = kv.split("="); timings[k] = float(v)
    low = txt.lower()
    if status == "error" and any(s in low for s in ("cannot allocate", "memoryerror", "out of memory", "bad_alloc")):
        status = "oom"
    return dict(status=status, wall_s=wall, peak_rss_bytes=sm.peak, exit_code=code, **timings)


# ----------------------------------------------------------------------------- first plot
def ink_fraction(png):
    im = np.asarray(Image.open(io.BytesIO(png)).convert("RGB"))
    h, w, _ = im.shape
    a = im.astype(np.int32)
    flat = (a[..., 0] << 16) | (a[..., 1] << 8) | a[..., 2]
    vals, counts = np.unique(flat, return_counts=True)
    bg = vals[counts.argmax()]
    bgc = np.array([(bg >> 16) & 255, (bg >> 8) & 255, bg & 255])
    dist = np.sqrt(((a - bgc) ** 2).sum(-1))
    mx = a.max(-1); mn = a.min(-1)
    v = mx / 255.0
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1), 0.0)
    ink = (dist > 60) & ((v < 0.5) | (s > INK_SATURATION))   # INK_SATURATION 0.1, see Deviations D11
    return float(ink.mean()), w, h


class BrowserRun:
    """Browser, context and page are created BEFORE the server is spawned, so their start-up is not timed."""

    def __init__(self):
        from playwright.sync_api import sync_playwright
        self.pw = sync_playwright().start()
        self.browser = self.pw.chromium.launch(channel="chrome", headless=True)
        self.context = self.browser.new_context(viewport=VIEWPORT, device_scale_factor=1)
        self.page = self.context.new_page()
        self.console = []
        self.page.on("console", lambda m: self.console.append(f"{m.type}: {m.text}"[:300]) if m.type in ("error",) else None)

    def close(self):
        for f in (self.context.close, self.browser.close, self.pw.stop):
            try:
                f()
            except Exception:
                pass


def first_plot(br, url, tool_cfg, t_start, shot_path, timeout=PLOT_TIMEOUT):
    """Navigate and wait for the first accepted frame. Returns dict. t_first_plot_s counts from navigation start."""
    page = br.page
    t_nav = time.perf_counter()
    frames = []
    try:
        page.goto(url, wait_until="commit", timeout=60000)
    except Exception as e:
        return dict(plot_status="error", plot_error=f"goto: {e}"[:300])
    steps = list(tool_cfg.get("steps", []))
    sel = tool_cfg["selector"]
    prev_ok, prev_t = False, None
    last_png = None
    while time.perf_counter() - t_nav < timeout and time.perf_counter() - t_start < START_CUTOFF:
        try:
            if steps:
                kind, arg = steps[0]
                if kind == "click_text":
                    loc = page.get_by_text(arg, exact=True).first
                    loc.click(timeout=400); steps.pop(0)
                elif kind == "click_css":
                    page.locator(arg).first.click(timeout=400); steps.pop(0)
            if not steps:
                loc = page.locator(sel).first
                if loc.count() and loc.is_visible():
                    t_shot0 = time.perf_counter()
                    png = loc.screenshot(timeout=20000, animations="allow")
                    t_shot1 = time.perf_counter()
                    frac, w, h = ink_fraction(png)
                    ok = (w >= 200 and h >= 200 and frac >= INK_THRESHOLD)
                    frames.append((round(t_shot1 - t_nav, 3), round(frac, 4), w, h, round(t_shot1 - t_shot0, 3)))
                    last_png = png
                    if ok and prev_ok:
                        open(shot_path, "wb").write(png)
                        return dict(plot_status="ok", t_first_plot_s=prev_t - t_nav, frames=len(frames), ink_fraction=frac, frame_series=frames,
                                    screenshot_s=t_shot1 - t_shot0, elem_w=w, elem_h=h)
                    prev_ok, prev_t = ok, (t_shot1 if ok and not prev_ok else prev_t)
                    if not ok:
                        prev_t = None
        except Exception as e:  # element not there yet, click not possible yet, etc.
            frames.append(("exc", str(e)[:120]))
        time.sleep(FRAME_INTERVAL)
    if last_png:
        open(shot_path, "wb").write(last_png)
    return dict(plot_status="timeout", frames=len(frames), last_frames=frames[-4:], console=br.console[-5:])


# ----------------------------------------------------------------------------- start
def run_start(serve_spec, port, tool_cfg, log_path, shot_path):
    """Spawn the server, wait for HTTP 200, drive Chrome to the first accepted frame, kill the tree."""
    if not port_free(port):
        return dict(status="error", error=f"port {port} not free")
    res = dict(status="ok")
    br = BrowserRun()
    try:
        t0 = time.perf_counter()
        with open(log_path, "w", encoding="utf-8", errors="replace") as lf:
            proc = subprocess.Popen(serve_spec["cmd"], cwd=HERE, env=serve_spec["env"], stdout=lf, stderr=subprocess.STDOUT)
            sm = Sampler(proc); sm.start()
            bs = BrowserSampler(proc); bs.start()
            url = f"http://127.0.0.1:{port}/"
            ready = None
            try:
                while time.perf_counter() - t0 < READY_TIMEOUT:
                    if proc.poll() is not None:
                        res.update(status="error", error=f"server exited with {proc.returncode}"); break
                    try:
                        if requests.get(url, timeout=2).status_code == 200:
                            ready = time.perf_counter() - t0; break
                    except requests.RequestException:
                        pass
                    time.sleep(0.1)
                if ready is None:
                    if res["status"] == "ok":
                        res.update(status="timeout", error="no HTTP 200 within ready timeout")
                else:
                    res["t_ready_s"] = ready
                    pl = first_plot(br, url, tool_cfg, t0, shot_path)
                    res.update(pl)
                    if pl["plot_status"] == "ok":
                        res["t_total_s"] = ready + pl["t_first_plot_s"]
                    else:
                        res["status"] = "timeout" if pl["plot_status"] == "timeout" else "error"
            finally:
                sm.stop(); bs.stop()
                res["peak_rss_bytes"] = sm.peak; res["browser_peak_rss_bytes"] = bs.peak
                kill_tree(proc)
        for _ in range(50):
            if port_free(port):
                break
            time.sleep(0.2)
    finally:
        br.close()
    return res


# ----------------------------------------------------------------------------- tool registry
TOOLS_ORDER = ["cerebronexus_default", "cerebronexus_h5", "shinycell", "isee", "cellxgene", "vitessce"]
PORTS = {"cerebronexus_default": 8811, "cerebronexus_h5": 8812, "shinycell": 8813, "isee": 8814, "cellxgene": 8815, "vitessce": 8816}
PLOT = {
    "cerebronexus_default": dict(steps=[("click_text", "Projection")], selector="#cv-cv-a"),
    "cerebronexus_h5": dict(steps=[("click_text", "Projection")], selector="#cv-cv-a"),
    "shinycell": dict(selector="#sc1a1oup1"),
    "isee": dict(selector="#ReducedDimensionPlot1"),
    "cellxgene": dict(selector="canvas.graph-canvas"),
    "vitessce": dict(selector="canvas#deckgl-overlay-A"),
}
PLOT.update(CONFIG.get("plot", {}))


def build_spec(tool, ds, inp, outdir):
    """ds: dict(group, nUMI, nGene). Returns build spec or None when the tool reads the input directly."""
    g = [ds["group"]] + ([ds["nUMI"], ds["nGene"]] if ds.get("nUMI") else [])
    if tool == "cerebronexus_default":
        return R("cerebronexus_build.R", inp, outdir, "embedded", *g)
    if tool == "cerebronexus_h5":
        return R("cerebronexus_build.R", inp, outdir, "h5", *g)
    if tool == "shinycell":
        return R("shinycell_build.R", inp, outdir, "sce", ds.get("workaround", "0"))
    if tool == "isee":
        return R("isee_build.R", inp, outdir, "sce")
    if tool == "vitessce":
        return P(os.path.join(HERE, "scripts", "tools", "vitessce_build.py"), inp, outdir, ds["group"], "X_umap")
    if tool == "cellxgene":
        return None
    raise KeyError(tool)


def find_one(d, suffix):
    hits = sorted(f for f in os.listdir(d) if f.endswith(suffix))
    return os.path.join(d, hits[0]) if hits else None


def serve_spec(tool, art, inp, port):
    if tool == "cerebronexus_default":
        return R("cerebronexus_serve.R", find_one(art, ".crb"), port, "embedded")
    if tool == "cerebronexus_h5":
        return R("cerebronexus_serve.R", find_one(art, ".crb"), port, "h5", find_one(art, ".h5"))
    if tool == "shinycell":
        return R("serve_shiny_dir.R", art, port)
    if tool == "isee":
        return R("isee_serve.R", os.path.join(art, "sce.rds"), port)
    if tool == "cellxgene":
        return dict(cmd=[os.path.join(HERE, "env", "py", "Scripts", "cellxgene.exe"), "launch", inp, "--host", "127.0.0.1",
                         "--port", str(port), "--disable-gene-sets-save"], env=cellxgene_env())
    if tool == "vitessce":
        return dict(cmd=[PY, os.path.join(HERE, "scripts", "serve_vitessce.py"), art, str(port)], env=py_env())
    raise KeyError(tool)


def input_for(tool, ds):
    """Input file for a tool: R-side readers need the rewritten (anndata>=0.8) file for legacy datasets."""
    if tool in ("shinycell", "isee") and ds.get("input_r"):
        return ds["input_r"]
    return ds["input"]


DATASETS = {
    "I1": dict(input=os.path.join(HERE, "data", "pbmc3k.h5ad"), input_r=os.path.join(HERE, "inputs", "I1_rewritten.h5ad"),
               group="louvain", workaround="1"),
    "e18_10000": dict(input=os.path.join(HERE, "inputs", "e18_10000.h5ad"), group="cluster", nUMI="nUMI", nGene="nGene", workaround="1"),
    "e18_100000": dict(input=os.path.join(HERE, "inputs", "e18_100000.h5ad"), group="cluster", nUMI="nUMI", nGene="nGene", workaround="1"),
    "e18_500000": dict(input=os.path.join(HERE, "inputs", "e18_500000.h5ad"), group="cluster", nUMI="nUMI", nGene="nGene", workaround="1"),
}


def pilot(dsname, tools):
    ds = DATASETS[dsname]
    out = os.path.join(HERE, "logs", "pilot"); os.makedirs(out, exist_ok=True)
    rows = []
    for tool in tools:
        art = os.path.join(HERE, "artifacts", f"pilot_{tool}_{dsname}")
        if os.path.isdir(art):
            subprocess.run(["cmd", "/c", "rmdir", "/s", "/q", art], capture_output=True)
        inp = input_for(tool, ds)
        row = dict(tool=tool, dataset=dsname)
        try:
            bs = build_spec(tool, ds, inp, art)
            if bs is None:
                art_path = inp; row.update(build_status="n/a")
            else:
                b = run_build(bs, os.path.join(out, f"{tool}_{dsname}_build.log"))
                row.update({f"build_{k}": v for k, v in b.items()})
                art_path = art
                if b["status"] != "ok":
                    rows.append(row); print(json.dumps(row), flush=True); continue
            row["artifact_bytes"] = dir_size(art_path if bs is not None else inp)
            s = run_start(serve_spec(tool, art_path, inp, PORTS[tool]), PORTS[tool], PLOT[tool],
                          os.path.join(out, f"{tool}_{dsname}_serve.log"), os.path.join(out, f"{tool}_{dsname}.png"))
            row.update({f"start_{k}": v for k, v in s.items()})
        except Exception:
            row["exception"] = traceback.format_exc()[-600:]
        rows.append(row); print(json.dumps(row, default=str), flush=True)
    json.dump(rows, open(os.path.join(out, f"pilot_{dsname}.json"), "w"), indent=1, default=str)


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "pilot":
        pilot(sys.argv[2], sys.argv[3:] or TOOLS_ORDER)
