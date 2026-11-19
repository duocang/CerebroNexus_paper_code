"""Building blocks of the tool comparison (see README.md): processes, builds, one start from launch to first plot.

One Python process spawns every tool process, so all durations share one clock (time.perf_counter()).
Run with the comparison Python 3.11 environment (env/py) on native Windows.
"""
import io, os, re, socket, subprocess, sys, tempfile, threading, time
import numpy as np
import psutil
import requests
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RSCRIPT = os.environ.get("TC_RSCRIPT", "C:/R/R-4.6.1/bin/Rscript.exe")
RBIN = os.path.join(os.path.dirname(RSCRIPT), "R.exe")
PY = sys.executable

BUILD_TIMEOUT = 3600          # s
READY_TIMEOUT = 900           # s from spawn to the first HTTP 200
PLOT_TIMEOUT = 600            # s from navigation to the first plot
SAMPLE_INTERVAL = 0.1         # s between RSS samples
VIEWPORT = {"width": 1600, "height": 1000}
INK_DIST, INK_SATURATION, INK_SHARE, MIN_PX = 60, 0.1, 0.003, 200   # 0.3 % ink: at 5,000 cells a plot is thin (Vitessce: 0.9 %)
SPREAD_GRID, SPREAD_BLOCK_INK, SPREAD_BLOCKS = 8, 0.002, 16


# ----------------------------------------------------------------------------- environments
def r_env(cnx_lib=None, cache=None):
    """R environment: the user library env/rlib (ShinyCell, iSEE, dependencies), the CerebroNexus library of this
    run in front of it, and a cache directory of its own (CerebroNexus keeps its first view there)."""
    e = dict(os.environ)
    base = os.path.join(HERE, "env", "rlib")
    libs = ";".join(x for x in (cnx_lib, base) if x)
    e.update(LANGUAGE="en", LANG="en_US.UTF-8", LC_ALL="en_US.UTF-8", R_LIBS=libs, R_LIBS_USER=libs, R_LIBS_SITE="",
             R_PROFILE_USER="", R_ENVIRON_USER="")
    if cache:
        e["R_USER_CACHE_DIR"] = cache
    return e


def py_env():
    e = dict(os.environ); e.update(PYTHONIOENCODING="utf-8", PYTHONUTF8="1"); return e


def cellxgene_env():
    """cellxgene queries the GitHub releases API on every start and crashes when rate limited: make the check fail at once."""
    e = py_env()
    e.update(HTTPS_PROXY="http://127.0.0.1:9", HTTP_PROXY="http://127.0.0.1:9", NO_PROXY="127.0.0.1,localhost")
    return e


def R(script, *args, env=None):
    return dict(cmd=[RSCRIPT, "--vanilla", os.path.join(HERE, "tools", script), *map(str, args)], env=env or r_env())


def P(script, *args):
    return dict(cmd=[PY, "-W", "ignore", os.path.join(HERE, "tools", script), *map(str, args)], env=py_env())


# ----------------------------------------------------------------------------- the CerebroNexus under test
def install_cerebronexus(repo, ref="HEAD"):
    """Install `ref` of the CerebroNexus checkout from `git archive` into data/cnx/lib/<sha12> (only committed code is measured).
    Returns dict(lib, sha, version). An interrupted install is redone."""
    sha = subprocess.run(["git", "-C", repo, "rev-parse", "--verify", "--quiet", ref + "^{commit}"], capture_output=True, text=True).stdout.strip()
    if not sha:
        raise SystemExit(f"cannot resolve {ref} in {repo}")
    src = os.path.join(HERE, "data", "cnx", "src", sha[:12]); lib = os.path.join(HERE, "data", "cnx", "lib", sha[:12])
    if not os.path.exists(os.path.join(lib, "CerebroNexus", "R", "CerebroNexus.rdb")):
        remove_tree(lib); remove_tree(src); os.makedirs(src); os.makedirs(lib)
        tar = os.path.join(tempfile.gettempdir(), f"cnx_{sha[:12]}.tar")
        subprocess.run(["git", "-C", repo, "archive", "--format=tar", "-o", tar, sha], check=True)
        subprocess.run(["tar", "-xf", tar, "-C", src], check=True); os.remove(tar)
        print("installing CerebroNexus", sha[:12], flush=True)
        if subprocess.run([RBIN, "CMD", "INSTALL", "--no-docs", "--no-multiarch", f"--library={lib}", src], env=r_env()).returncode:
            raise SystemExit("R CMD INSTALL failed")
    return dict(lib=lib, sha=sha, version=re.search(r"^Version:\s*(\S+)", open(os.path.join(src, "DESCRIPTION")).read(), re.M).group(1))


def versions():
    """Versions of the other tools, for the manifest."""
    v = {}
    spec = R("versions.R")
    out = subprocess.run(spec["cmd"], capture_output=True, text=True, env=spec["env"]).stdout
    v.update({k.strip(): w.strip() for k, w in (l.split(" = ") for l in out.splitlines() if " = " in l)})
    import importlib.metadata as md
    for p in ("vitessce", "cellxgene", "scanpy", "anndata"):
        try:
            v[p] = md.version(p)
        except Exception:
            pass
    return v


# ----------------------------------------------------------------------------- process utilities
def tree_rss(proc):
    try:
        root = psutil.Process(proc.pid); total = 0
        for p in [root] + root.children(recursive=True):
            try:
                total += p.memory_info().rss
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
        return total
    except psutil.NoSuchProcess:
        return 0


class Sampler(threading.Thread):
    """Peak RSS of a process tree."""
    def __init__(self, proc):
        super().__init__(daemon=True); self.proc = proc; self.peak = 0; self._halt = False

    def run(self):
        while not self._halt:
            self.peak = max(self.peak, tree_rss(self.proc)); time.sleep(SAMPLE_INTERVAL)

    def stop(self):
        self._halt = True; self.join(timeout=2)


class BrowserSampler(threading.Thread):
    """Peak RSS of Chrome: the descendants of this process that are not in the server's tree."""
    def __init__(self, server_proc):
        super().__init__(daemon=True); self.server = server_proc; self.peak = 0; self._halt = False

    def run(self):
        me = psutil.Process(os.getpid())
        while not self._halt:
            try:
                srv = {self.server.pid}
                try:
                    srv |= {c.pid for c in psutil.Process(self.server.pid).children(recursive=True)}
                except psutil.NoSuchProcess:
                    pass
                tot = 0
                for c in me.children(recursive=True):
                    if c.pid not in srv:
                        try:
                            tot += c.memory_info().rss
                        except (psutil.NoSuchProcess, psutil.AccessDenied):
                            pass
                self.peak = max(self.peak, tot)
            except Exception:
                pass
            time.sleep(SAMPLE_INTERVAL * 2)

    def stop(self):
        self._halt = True; self.join(timeout=2)


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


def remove_tree(path):
    if os.path.isdir(path):
        subprocess.run(["cmd", "/c", "rmdir", "/s", "/q", path], capture_output=True)


def port_free(port):
    s = socket.socket()
    try:
        return s.connect_ex(("127.0.0.1", port)) != 0
    finally:
        s.close()


def wait_port_free(port, tries=50):
    for _ in range(tries):
        if port_free(port):
            return True
        time.sleep(0.2)
    return False


def wait_idle(limit=30, below=20.0):
    """Wait until the whole machine is below `below` % CPU over 2 s (at most `limit` s). Returns the last reading."""
    t0 = time.perf_counter(); cpu = psutil.cpu_percent(interval=2.0)
    while cpu >= below and time.perf_counter() - t0 < limit:
        cpu = psutil.cpu_percent(interval=2.0)
    return cpu


# ----------------------------------------------------------------------------- build
def run_build(spec, log_path, timeout=BUILD_TIMEOUT):
    """spec = dict(cmd, env). Returns dict(status, wall_s, peak_rss_bytes)."""
    t0 = time.perf_counter()
    with open(log_path, "w", encoding="utf-8", errors="replace") as lf:
        proc = subprocess.Popen(spec["cmd"], cwd=HERE, env=spec["env"], stdout=lf, stderr=subprocess.STDOUT)
        sm = Sampler(proc); sm.start(); status = "ok"
        try:
            if proc.wait(timeout=timeout) != 0:
                status = "error"
        except subprocess.TimeoutExpired:
            status = "timeout"; kill_tree(proc)
        wall = time.perf_counter() - t0
        sm.stop()
        if proc.poll() is None:
            kill_tree(proc)
    txt = open(log_path, encoding="utf-8", errors="replace").read().lower()
    if status == "error" and any(s in txt for s in ("cannot allocate", "memoryerror", "out of memory", "bad_alloc")):
        status = "oom"
    return dict(status=status, wall_s=wall, peak_rss_bytes=sm.peak)


# ----------------------------------------------------------------------------- frames and the first plot
def decode(jpeg):
    return np.asarray(Image.open(io.BytesIO(jpeg)).convert("RGB"))


def ink_mask(a):
    """Ink: further than INK_DIST from the most frequent colour of the region and dark (V < 0.5) or coloured (S > 0.1).
    Computed on every 2nd pixel in each direction (a plot of at least 200 x 200 px is far above that resolution)."""
    a = a[::2, ::2].astype(np.int32)
    flat = (a[..., 0] << 16) | (a[..., 1] << 8) | a[..., 2]
    vals, counts = np.unique(flat, return_counts=True)
    bg = vals[counts.argmax()]
    bgc = np.array([(bg >> 16) & 255, (bg >> 8) & 255, bg & 255])
    dist = np.sqrt(((a - bgc) ** 2).sum(-1))
    mx = a.max(-1); mn = a.min(-1)
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1), 0.0)
    return (dist > INK_DIST) & ((mx / 255.0 < 0.5) | (s > INK_SATURATION))


def shows_plot(region):
    """Does this part of the screen show a plot? At least 200 x 200 px, at least 1 % ink, and the ink spread over the
    region (at least 16 of its 8 x 8 blocks hold some): a toolbar, a spinner or a message is not a plot."""
    h, w = region.shape[:2]
    if w < MIN_PX or h < MIN_PX:
        return False, 0.0
    m = ink_mask(region)
    share = float(m.mean())
    if share < INK_SHARE:
        return False, share
    mh, mw = m.shape; blocks = 0
    for i in range(SPREAD_GRID):
        for j in range(SPREAD_GRID):
            b = m[i * mh // SPREAD_GRID:(i + 1) * mh // SPREAD_GRID, j * mw // SPREAD_GRID:(j + 1) * mw // SPREAD_GRID]
            if b.size and b.mean() >= SPREAD_BLOCK_INK:
                blocks += 1
    return blocks >= SPREAD_BLOCKS, share


BOX_JS = """(sels) => {
  let best = null;
  for (const sel of sels) for (const e of document.querySelectorAll(sel)) {
    const r = e.getBoundingClientRect(), st = getComputedStyle(e);
    if (r.width > 0 && r.height > 0 && st.visibility !== 'hidden' && st.display !== 'none' && (!best || r.width * r.height > best.width * best.height))
      best = {x: r.left, y: r.top, width: r.width, height: r.height};
  }
  return best; }"""


class BrowserRun:
    """Chrome through Playwright, headless, with the machine's GPU. Created AFTER the server answered, so that the
    browser's start-up is in no time. A new context (no HTTP cache) for every start."""

    def __init__(self):
        from playwright.sync_api import sync_playwright
        self.pw = sync_playwright().start()
        self.browser = self.pw.chromium.launch(channel="chrome", headless=True)
        self.context = self.browser.new_context(viewport=VIEWPORT, device_scale_factor=1)
        self.page = self.context.new_page()
        self.version = self.browser.version
        self.renderer = None

    def gpu(self):
        if self.renderer is None:
            try:
                self.renderer = self.page.evaluate("""() => { const g = document.createElement('canvas').getContext('webgl2');
                  if (!g) return 'none'; const x = g.getExtension('WEBGL_debug_renderer_info'); return x ? g.getParameter(x.UNMASKED_RENDERER_WEBGL) : 'unknown'; }""")
            except Exception:
                self.renderer = "unknown"
        return self.renderer

    def close(self):
        for f in (self.context.close, self.browser.close, self.pw.stop):
            try:
                f()
            except Exception:
                pass


def first_plot(br, url, selectors, shot_path, timeout=PLOT_TIMEOUT):
    """From the navigation to the first plot. Viewport screenshots are taken back to back (about every 0.1 s); a frame
    shows the plot when the plot element, wherever it is in that frame, passes shows_plot(). The first plot is the
    first of two frames in a row that show it, stamped with the middle of its capture. `selectors`: the plot element or
    the elements that stand in its place while it loads."""
    page = br.page
    t_nav = time.perf_counter()
    try:
        page.goto(url, wait_until="commit", timeout=60000)
    except Exception as e:
        return dict(plot_status="error", plot_error=f"goto: {e}"[:300])
    prev = None; frames = 0; last = None
    while time.perf_counter() - t_nav < timeout:
        try:
            box = page.evaluate(BOX_JS, selectors)
            t_a = time.perf_counter()
            jpg = page.screenshot(type="jpeg", quality=70)
            t_b = time.perf_counter()
        except Exception:
            time.sleep(0.05); continue
        frames += 1; last = jpg
        ok, share = False, 0.0
        if box:
            im = decode(jpg)
            x0, y0 = max(0, int(box["x"])), max(0, int(box["y"]))
            x1, y1 = min(im.shape[1], int(box["x"] + box["width"])), min(im.shape[0], int(box["y"] + box["height"]))
            if x1 > x0 and y1 > y0:
                ok, share = shows_plot(im[y0:y1, x0:x1])
        t = (t_a + t_b) / 2 - t_nav
        if ok and prev is not None:
            open(shot_path, "wb").write(prev[1])
            return dict(plot_status="ok", t_first_plot_s=prev[0], frames=frames, ink=prev[2])
        prev = (t, jpg, share) if ok else None
    if last:
        open(shot_path, "wb").write(last)
    return dict(plot_status="timeout", frames=frames)


# ----------------------------------------------------------------------------- one start
def run_start(serve, port, url_path, selectors, log_path, shot_path):
    """Spawn the server, wait for its first HTTP 200 (a TCP probe every 5 ms, so that Windows' slow refusals do not
    round the time to 0.5 s steps), then start Chrome and time the first plot. Kills the tree at the end.
    Returns dict(status, t_ready_s, t_first_plot_s, t_total_s, peak_rss_bytes, browser_peak_rss_bytes, ...)."""
    if not port_free(port):
        return dict(status="error", error=f"port {port} not free")
    res = dict(status="ok"); br = None
    try:
        t0 = time.perf_counter()
        with open(log_path, "w", encoding="utf-8", errors="replace") as lf:
            proc = subprocess.Popen(serve["cmd"], cwd=HERE, env=serve["env"], stdout=lf, stderr=subprocess.STDOUT)
            sm = Sampler(proc); sm.start(); bs = BrowserSampler(proc); bs.start()
            try:
                ready = wait_ready(port, proc, t0)
                if isinstance(ready, str):
                    res.update(status="error" if "exited" in ready else "timeout", error=ready)
                else:
                    res["t_ready_s"] = ready
                    br = BrowserRun()
                    pl = first_plot(br, f"http://127.0.0.1:{port}{url_path}", selectors, shot_path)
                    res.update({k: v for k, v in pl.items() if k != "plot_status"})
                    res["browser"] = br.version; res["renderer"] = br.gpu()
                    if pl["plot_status"] == "ok":
                        res["t_total_s"] = ready + pl["t_first_plot_s"]
                    else:
                        res.update(status="timeout" if pl["plot_status"] == "timeout" else "error", error=pl.get("plot_error"))
            finally:
                sm.stop(); bs.stop()
                res["peak_rss_bytes"] = sm.peak; res["browser_peak_rss_bytes"] = bs.peak
                kill_tree(proc)
    finally:
        if br is not None:
            br.close()
    wait_port_free(port)
    return res


def wait_ready(port, proc, t0, limit=READY_TIMEOUT):
    """Spawn to the first HTTP 200 on /. Returns seconds, or a string saying why not."""
    while time.perf_counter() - t0 < limit:
        if proc.poll() is not None:
            return f"server exited with {proc.returncode}"
        s = socket.socket(); s.settimeout(0.02)
        try:
            s.connect(("127.0.0.1", int(port))); s.close()
        except OSError:
            s.close(); time.sleep(0.005); continue
        try:
            if requests.get(f"http://127.0.0.1:{port}/", timeout=60).status_code == 200:
                return time.perf_counter() - t0
        except requests.RequestException:
            pass
        time.sleep(0.005)
    return "no HTTP 200 within the ready timeout"
