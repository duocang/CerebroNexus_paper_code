"""Start measurement of round 3 (PROTOCOL_round3.md, a draft: nothing here is frozen).

Reuses the tool registry, the samplers and the ink rule of harness.py, which is not changed. What differs:
  t_ready          TCP probe every 5 ms (20 ms timeout), then one GET; requests.get in a loop moves in 0.5 s steps on Windows
  frames           Chrome's screencast of the page, kept going by a 2 px marker that changes every 0.1 s; each frame
                   cropped to where the plot element (or the element declared to stand in for it) was at that moment
  t_first_pixels   first of two consecutive frames with ink in that region
  t_interactive    first of two consecutive gestures that are each followed by a change of the region before the next one
  bytes, requests  what the browser received up to each event
  cache            R_USER_CACHE_DIR per run

    python scripts/run/harness3.py start <tool> <artifact dir or input> <cache dir> <out prefix> [--lib <R library with the round-3 CerebroNexus>]
"""
import base64, io, json, os, socket, subprocess, sys, time
import numpy as np
import requests
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import harness as H

HERE = H.HERE
READY_TIMEOUT = 900
RUN_LIMIT = float(os.environ.get("HARNESS3_RUN_LIMIT", "120"))   # s after navigation; pilots keep it short
HEARTBEAT_MS = 100           # a 2 x 2 px marker in a corner of the page changes this often, so that Chrome keeps sending frames
GESTURE_EVERY = 0.25         # s between gestures
STILL_BEFORE_GESTURE = 0.30  # s without a change of the region before a gesture is made
CHANGE_PIXEL = 24            # 0-255: a pixel differs when one channel differs by more than this (JPEG noise is below)
CHANGE_SHARE = 0.005         # share of the region's pixels that has to differ for a frame to count as changed
AFTER_INTERACTIVE = 1.0      # s the run goes on after three answered gestures in a row
SPREAD_GRID = 8              # the region is cut into 8 x 8 blocks
SPREAD_BLOCK_INK = 0.002     # a block holds ink when this share of its pixels is ink
SPREAD_BLOCKS = 16           # a frame shows the plot when at least this many of the 64 blocks hold ink (and 1 % of all pixels)
GIVE_UP_AFTER = 16           # gestures made once the plot shows ink, none of them answered twice in a row: the plot has no such gesture
VIEWPORT = H.VIEWPORT

# Chrome's screencast sends a frame when it thinks the page changed, and sent none when Vitessce drew its cells on a
# WebGL canvas: the run ended on a picture of the loading state. Asking for captures instead (Page.captureScreenshot)
# changes the page's metrics for every clipped capture, which made each Shiny tool seconds slower and filled the
# screencast with frames of the capture itself. The marker below is the least that keeps the frames coming.
HEARTBEAT_JS = """(() => {
  const start = () => {
    if (!document.documentElement) return setTimeout(start, 5);
    const m = document.createElement('div');
    m.setAttribute('data-harness-heartbeat', '');
    m.style.cssText = 'position:fixed;right:0;bottom:0;width:2px;height:2px;z-index:2147483647;pointer-events:none;background:#000';
    document.documentElement.appendChild(m);
    let i = 0;
    setInterval(() => { m.style.background = (i++ % 2) ? '#000' : '#fff'; }, __MS__);
  };
  start();
})();""".replace("__MS__", str(HEARTBEAT_MS))

TOOLS = ["cerebronexus_default", "cerebronexus_h5", "cerebronexus_h5_start", "shinycell", "isee", "cellxgene", "vitessce"]
PORTS = dict(H.PORTS, cerebronexus_h5_start=8817)

# path: what Chrome navigates to. selector: the plot element of round 2, whose box at the end of the run is the plot region.
# early: an element that can stand in the same place before the plot element exists (looked at while the run is going).
# gesture: what the harness does to see whether the plot answers.
CEREBRO = dict(path="/?page=projection", selector="#cv-cv-a", early=".cerebro-first-view-canvas",
               gesture=("click_alternate", '[data-act="zin"]', '[data-act="zout"]'))
PLOT = {
    "cerebronexus_default": CEREBRO, "cerebronexus_h5": CEREBRO, "cerebronexus_h5_start": CEREBRO,
    # ShinyCell draws an image; no pointer gesture changes it (19 drags in the pilot, none answered): n/a.
    "shinycell": dict(path="/", selector="#sc1a1oup1", gesture=None),
    "isee": dict(path="/", selector="#ReducedDimensionPlot1", gesture=("drag",)),
    # cellxgene 1.3.0, started as in round 2, opens a dialog ("User Generated Data Directory") over its plot; "Cancel"
    # does not close it, a name has to be given. It also opens in lasso mode, where the wheel does nothing. The harness
    # names the directory and chooses pan-and-zoom, once, as a user who wants to zoom has to.
    "cellxgene": dict(path="/", selector="canvas.graph-canvas",
                      gesture=("wheel", ("name_dialog", "Create user generated data directory"),
                               ("css", "[data-testid='mode-pan-zoom']"))),
    "vitessce": dict(path="/", selector="canvas#deckgl-overlay-A", gesture=("wheel",)),
}


def cerebro_env(lib, cache):
    """R environment with the round-3 CerebroNexus in front of env/rlib, and the run's own cache directory."""
    e = H.r_env()
    base = os.path.join(HERE, "env", "rlib")
    if lib:
        e.update(R_LIBS=lib + ";" + base, R_LIBS_USER=lib)
    e["R_USER_CACHE_DIR"] = cache
    return e


def serve_spec(tool, art, inp, port, lib, cache):
    os.makedirs(cache, exist_ok=True)
    if tool in ("cerebronexus_default", "cerebronexus_h5"):
        return dict(cmd=[H.RSCRIPT, "--vanilla", os.path.join(HERE, "scripts", "run", "tools", "cerebronexus3_serve.R"),
                         H.find_one(art, ".crb"), str(port)], env=cerebro_env(lib, cache))
    if tool == "cerebronexus_h5_start":
        return dict(cmd=[H.RSCRIPT, "--vanilla", os.path.join(lib, "CerebroNexus", "start.R"), f"--port={port}",
                         H.find_one(art, ".crb")], env=cerebro_env(lib, cache))
    spec = H.serve_spec(tool, art, inp, port)
    spec["env"] = dict(spec["env"], R_USER_CACHE_DIR=cache)
    return spec


def wait_ready(port, proc, t0, limit=READY_TIMEOUT):
    """Spawn to the first HTTP 200 on / ."""
    while time.perf_counter() - t0 < limit:
        if proc.poll() is not None:
            return None, f"server exited with {proc.returncode}"
        s = socket.socket(); s.settimeout(0.02)
        try:
            s.connect(("127.0.0.1", int(port))); s.close()
        except OSError:
            s.close(); time.sleep(0.005); continue
        try:
            if requests.get(f"http://127.0.0.1:{port}/", timeout=60).status_code == 200:
                return time.perf_counter() - t0, None
        except requests.RequestException:
            pass
        time.sleep(0.005)
    return None, "no HTTP 200 within ready timeout"


# ----------------------------------------------------------------------------- frames
def decode(data):
    return np.asarray(Image.open(io.BytesIO(base64.b64decode(data))).convert("RGB"))


def crop(im, box, clip=None):
    """The part of a frame inside `box` (page coordinates). `clip`: the part of the page the frame shows, when not all of it."""
    ox, oy = (clip["x"], clip["y"]) if clip else (0, 0)
    x0, y0 = max(0, int(round(box["x"] - ox))), max(0, int(round(box["y"] - oy)))
    x1, y1 = min(im.shape[1], int(round(box["x"] + box["width"] - ox))), min(im.shape[0], int(round(box["y"] + box["height"] - oy)))
    return im[y0:y1, x0:x1]


def ink_mask(a):
    """The ink rule of harness.ink_fraction on an RGB array: which pixels are ink."""
    a = a.astype(np.int32)
    flat = (a[..., 0] << 16) | (a[..., 1] << 8) | a[..., 2]
    vals, counts = np.unique(flat, return_counts=True)
    bg = vals[counts.argmax()]
    bgc = np.array([(bg >> 16) & 255, (bg >> 8) & 255, bg & 255])
    dist = np.sqrt(((a - bgc) ** 2).sum(-1))
    mx = a.max(-1); mn = a.min(-1)
    v = mx / 255.0
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1), 0.0)
    return (dist > 60) & ((v < 0.5) | (s > H.INK_SATURATION))


def ink_share(a):
    return float(ink_mask(a).mean()) if a.size else 0.0


def ink_spread(a, grid=SPREAD_GRID):
    """(share of ink, number of the grid x grid blocks of the region that hold ink). A plot is spread over its
    region; a toolbar, a spinner or a message is not."""
    if a.size == 0:
        return 0.0, 0
    m = ink_mask(a)
    h, w = m.shape
    blocks = 0
    for i in range(grid):
        for j in range(grid):
            b = m[i * h // grid:(i + 1) * h // grid, j * w // grid:(j + 1) * w // grid]
            if b.size and b.mean() >= SPREAD_BLOCK_INK:
                blocks += 1
    return float(m.mean()), blocks


def shows_plot(ink, blocks, w, h):
    return w >= 200 and h >= 200 and ink >= H.INK_THRESHOLD and blocks >= SPREAD_BLOCKS


def changed_share(a, b):
    if a is None or b is None or a.size == 0 or b.size == 0:
        return 1.0
    if a.shape != b.shape:
        # an element that moved or grew by a pixel or two is the same picture; anything more is a change
        if abs(a.shape[0] - b.shape[0]) > 2 or abs(a.shape[1] - b.shape[1]) > 2:
            return 1.0
        h, w = min(a.shape[0], b.shape[0]), min(a.shape[1], b.shape[1])
        a, b = a[:h, :w], b[:h, :w]
    return float((np.abs(a.astype(np.int16) - b.astype(np.int16)).max(-1) > CHANGE_PIXEL).mean())


def box_of(page, selector):
    """Where the first visible element of the selector is on the page, in one round trip."""
    try:
        return page.evaluate("""(sel) => {
            for (const e of document.querySelectorAll(sel)) {
                const r = e.getBoundingClientRect(), style = getComputedStyle(e);
                if (r.width > 0 && r.height > 0 && style.visibility !== 'hidden' && style.display !== 'none')
                    return {x: r.left, y: r.top, width: r.width, height: r.height};
            }
            return null; }""", selector)
    except Exception:
        return None


def whole_pixels(box):
    """The box on whole pixels, so that two readings of an element at rest give the same region."""
    if box is None:
        return None
    x0, y0 = int(np.floor(box["x"])), int(np.floor(box["y"]))
    return dict(x=x0, y=y0, width=int(np.ceil(box["x"] + box["width"])) - x0, height=int(np.ceil(box["y"] + box["height"])) - y0)


def gesture(page, cfg, box, index):
    """Makes the tool's gesture once. Returns what it did, or None when it could not be made yet."""
    if not cfg.get("gesture"):
        return None
    kind = cfg["gesture"][0]
    try:
        if kind == "click_alternate":
            sel = cfg["gesture"][1 + index % 2]
            done = page.evaluate("""(sel) => { const b = Array.from(document.querySelectorAll(sel)).find(e => e.offsetParent !== null);
                                              if (!b) return false; b.click(); return true; }""", sel)
            return sel if done else None
        if box is None:
            return None
        cx, cy = box["x"] + box["width"] / 2, box["y"] + box["height"] / 2
        if kind == "wheel":
            if len(cfg["gesture"]) > 1 and index == 0:
                # what the tool needs before this gesture works, once
                for how, what in cfg["gesture"][1:]:
                    if how == "name_dialog":
                        page.locator(".bp3-dialog input").first.click(timeout=2000)
                        page.keyboard.type("r3")
                        page.get_by_role("button", name=what).click(timeout=2000)
                        page.locator(".bp3-dialog").first.wait_for(state="detached", timeout=3000)
                    else:
                        mode = box_of(page, what)
                        if mode is None:
                            return None
                        page.mouse.click(mode["x"] + mode["width"] / 2, mode["y"] + mode["height"] / 2)
            page.mouse.move(cx, cy)
            page.mouse.wheel(0, -240 if index % 2 == 0 else 240)
            return "wheel in" if index % 2 == 0 else "wheel out"
        if kind == "drag":
            dx, dy = box["width"] * (0.10 + 0.05 * (index % 2)), box["height"] * 0.10
            page.mouse.move(cx - dx, cy - dy); page.mouse.down()
            page.mouse.move(cx, cy, steps=3); page.mouse.move(cx + dx, cy + dy, steps=3); page.mouse.up()
            return "drag"
    except Exception as e:
        GESTURE_ERRORS.append(str(e)[:200])
        return None
    return None


GESTURE_ERRORS = []


# ----------------------------------------------------------------------------- one start
def run_start(spec, port, cfg, log_path, out_prefix, run_limit=RUN_LIMIT, chrome_args=None, network=None):
    """Spawn the server, wait for its first HTTP 200, open the plot in Chrome and watch it. Returns a dict.
    chrome_args: extra Chrome arguments (Task 6: no GPU). network: Network.emulateNetworkConditions arguments (Task 6)."""
    if not H.port_free(port):
        return dict(status="error", error=f"port {port} not free")
    res = dict(status="ok")
    from playwright.sync_api import sync_playwright
    t0 = time.perf_counter()
    lf = open(log_path, "w", encoding="utf-8", errors="replace")
    proc = subprocess.Popen(spec["cmd"], cwd=HERE, env=spec["env"], stdout=lf, stderr=subprocess.STDOUT)
    sm = H.Sampler(proc); sm.start()
    bs = H.BrowserSampler(proc); bs.start()
    pw = browser = None
    try:
        ready, err = wait_ready(port, proc, t0)
        if ready is None:
            res.update(status="timeout" if "timeout" in err else "error", error=err)
            return res
        res["t_ready_s"] = ready
        pw = sync_playwright().start()
        browser = pw.chromium.launch(channel="chrome", headless=True, args=list(chrome_args or []))
        context = browser.new_context(viewport=VIEWPORT, device_scale_factor=1)
        context.add_init_script(HEARTBEAT_JS)
        page = context.new_page()
        console = []
        page.on("console", lambda m: console.append(f"{m.type}: {m.text}"[:300]) if m.type == "error" else None)
        cdp = context.new_cdp_session(page)
        cdp.send("Network.enable"); cdp.send("Page.enable")
        if network:
            cdp.send("Network.emulateNetworkConditions", network)
        clock = {}
        received = []            # (wall time, bytes) of every finished response

        def wall(ts, wt=None):
            if wt is not None and "off" not in clock:
                clock["off"] = wt - ts
            return ts + clock.get("off", 0)
        cdp.on("Network.requestWillBeSent", lambda p: wall(p["timestamp"], p.get("wallTime")))
        cdp.on("Network.loadingFinished", lambda p: received.append((wall(p["timestamp"]), p.get("encodedDataLength", 0))))
        frames = []              # (wall time, base64 JPEG, the part of the page it shows or None for all of it)

        def on_frame(p):
            frames.append((p["metadata"]["timestamp"], p["data"], None))
            try:
                cdp.send("Page.screencastFrameAck", {"sessionId": p["sessionId"]})
            except Exception:
                pass
        cdp.on("Page.screencastFrame", on_frame)
        cdp.send("Page.startScreencast", {"format": "jpeg", "quality": 70, "everyNthFrame": 1})

        url = f"http://127.0.0.1:{port}{cfg['path']}"
        t_nav = time.time()
        try:
            page.goto(url, wait_until="commit", timeout=60000)
        except Exception as e:
            res.update(status="error", error=f"goto: {e}"[:300]); return res

        captures = 0
        gestures = []            # (wall time the gesture began, what)
        boxes = []               # (wall time, box or None, "plot" | "early" | None): where the plot element was, all through the run
        seen = 0; last_small = {}; last_change = t_nav; last_gesture = 0.0; live_box = None; box_checked = 0.0; last_shot = 0.0
        answered = []            # for every gesture: did the region change before the next one
        pending = None
        first_ink = None         # wall time of the first frame with ink in the region, as far as the running loop can tell
        end_at = None
        while time.time() - t_nav < run_limit:
            page.wait_for_timeout(20)
            now = time.time()
            if now - box_checked > 0.08:
                live_box, kind = whole_pixels(box_of(page, cfg["selector"])), "plot"
                if live_box is None and cfg.get("early"):
                    live_box, kind = whole_pixels(box_of(page, cfg["early"])), "early"
                boxes.append((now, live_box, kind if live_box else None))
                box_checked = now
            while seen < len(frames):
                ts, data, clip = frames[seen]; seen += 1
                if live_box is None:
                    last_small = {}
                    continue
                small = crop(decode(data), live_box, clip)[::4, ::4]
                # A capture and a screencast frame of the same picture differ a little (two encoders): each is
                # compared with the one before it of its own kind.
                source = "capture" if clip else "screencast"
                if first_ink is None:
                    share, blocks = ink_spread(small)
                    if shows_plot(share, blocks, small.shape[1] * 4, small.shape[0] * 4):
                        first_ink = ts
                if source in last_small and changed_share(small, last_small[source]) > CHANGE_SHARE:
                    last_change = ts
                    if pending is not None and ts > pending:
                        answered[-1] = True; pending = None
                last_small[source] = small
            if end_at is None and len(answered) >= 3 and all(answered[-3:]):
                end_at = now + AFTER_INTERACTIVE          # three gestures in a row were answered
            after_ink = [a for (t, _), a in zip(gestures, answered) if first_ink is not None and t >= first_ink]
            if end_at is None and first_ink is not None and not cfg.get("gesture") and now - first_ink > 2.0:
                end_at = now                               # a tool without a gesture: two seconds of its plot are enough
            if end_at is None and len(after_ink) >= GIVE_UP_AFTER and not any(a and b for a, b in zip(after_ink, after_ink[1:])):
                end_at = now                               # the plot is there and does not answer this gesture
            if end_at is not None and now >= end_at:
                break
            if (end_at is None and first_ink is not None and cfg.get("gesture") and now - last_gesture >= GESTURE_EVERY
                    and now - last_change >= STILL_BEFORE_GESTURE):
                began = time.time()
                what = gesture(page, cfg, live_box, len(gestures))
                last_gesture = time.time()
                if what is not None:
                    pending = began
                    gestures.append((began, what)); answered.append(False)
        final_box = whole_pixels(box_of(page, cfg["selector"]))
        cdp.send("Page.stopScreencast")
        try:                                               # the page as it is at the end, apart from the screencast
            page.screenshot(path=out_prefix + "_end.png", timeout=10000)
        except Exception:
            pass
        frames.sort(key=lambda f: f[0])
        res.update(n_frames=len(frames), n_captures=captures, n_gestures=len(gestures), console=console[-5:], region=final_box)
        if final_box is None:
            res.update(status="error", error="the plot element was not on the page at the end of the run")
            return res

        # ------------------------------------------------------------ after the run: the events
        # Each frame is cropped to where the plot element (or the element that stands in for it) was when the frame
        # was taken. A region fixed at the end of the run would also see whatever else passed through that place
        # while the page was laid out: Vitessce's collapsed panels were taken for a plot that way.
        def box_at(ts):
            found = (None, None)
            for t, b, kind in boxes:
                if t > ts + 0.02:
                    break
                found = (b, kind)
            return found
        series = []; before = {}
        for ts, data, clip in frames:
            b, kind = box_at(ts)
            im = crop(decode(data), b, clip) if b else None
            source = "capture" if clip else "screencast"
            prev = before.get(source)
            if im is None or im.size == 0:
                series.append(dict(t=round(ts - t_nav, 4), ink=0.0, blocks=0, changed=0.0, w=0, h=0, element=None, source=source)); before = {}
                continue
            share, blocks = ink_spread(im)
            series.append(dict(t=round(ts - t_nav, 4), ink=round(share, 4), blocks=blocks,
                               changed=round(changed_share(im, prev), 4) if prev is not None else 0.0,
                               w=int(im.shape[1]), h=int(im.shape[0]), element=kind, source=source))
            before[source] = im
        ok = [shows_plot(s_["ink"], s_["blocks"], s_["w"], s_["h"]) for s_ in series]
        first = None
        for i, good in enumerate(ok):
            # Chrome sends a frame when the page changed: a qualifying frame that stays is followed by none.
            if good and (i + 1 == len(ok) or ok[i + 1]):
                first = i; break
        json.dump(series, open(out_prefix + "_frames.json", "w"))
        if frames:
            open(out_prefix + "_last.jpg", "wb").write(base64.b64decode(frames[-1][1]))
        res["gesture_errors"] = GESTURE_ERRORS[-3:]; del GESTURE_ERRORS[:]
        if first is None:
            res.update(status="no_plot", frame_series=series[-6:]); return res
        res["t_first_pixels_s"] = series[first]["t"]
        res["first_pixels_element"] = series[first]["element"]
        open(out_prefix + "_first_pixels.jpg", "wb").write(base64.b64decode(frames[first][1]))
        plot_first = next((s_["t"] for s_, good in zip(series, ok) if good and s_["element"] == "plot"), None)
        res["t_plot_element_s"] = plot_first      # first ink in the plot element itself (round 2's event)

        g = [(t - t_nav, what) for t, what in gestures]
        changes = [s_["t"] for s_ in series if s_["changed"] > CHANGE_SHARE]
        hit = []
        for i, (t, what) in enumerate(g):
            until = g[i + 1][0] if i + 1 < len(g) else t + 1.0
            hit.append(any(t < c <= until for c in changes))
        interactive = None
        for i in range(len(g) - 1):
            if g[i][0] >= res["t_first_pixels_s"] and hit[i] and hit[i + 1]:
                interactive = i; break
        res["gestures"] = [dict(t=round(t, 3), what=what, answered=h) for (t, what), h in zip(g, hit)][:40]
        if interactive is not None:
            res["t_interactive_s"] = round(g[interactive][0], 4)
            after = next((i for i, s_ in enumerate(series) if s_["t"] > g[interactive][0] and s_["changed"] > CHANGE_SHARE), None)
            if after is not None:
                open(out_prefix + "_interactive.jpg", "wb").write(base64.b64decode(frames[after][1]))
        else:
            res["interactive_status"] = "n/a" if not cfg.get("gesture") else ("no gesture made" if not g else "no gesture answered")

        def got(t):
            upto = [b for w, b in received if w - t_nav <= t]
            return dict(bytes=int(sum(upto)), requests=len(upto))
        res["received_first_pixels"] = got(res["t_first_pixels_s"])
        if interactive is not None:
            res["received_interactive"] = got(res["t_interactive_s"])
        res["frame_gap_ms_p95"] = round(1000 * float(np.percentile(np.diff([s["t"] for s in series]), 95)), 1) if len(series) > 2 else None
        return res
    finally:
        sm.stop(); bs.stop()
        res["peak_rss_bytes"] = sm.peak; res["browser_peak_rss_bytes"] = bs.peak
        for close in ((browser.close if browser else None), (pw.stop if pw else None)):
            try:
                close() if close else None
            except Exception:
                pass
        H.kill_tree(proc); lf.close()
        for _ in range(50):
            if H.port_free(port):
                break
            time.sleep(0.2)


def idle_cpu(seconds=3.0):
    import psutil
    return psutil.cpu_percent(interval=seconds)


if __name__ == "__main__":
    args = sys.argv[1:]
    lib = None
    if "--lib" in args:
        i = args.index("--lib"); lib = args[i + 1]; del args[i:i + 2]
    if args[0] == "start":
        tool, art, cache, out_prefix = args[1:5]
        os.makedirs(os.path.dirname(out_prefix), exist_ok=True)
        spec = serve_spec(tool, art, art, PORTS[tool], lib, cache)
        row = dict(tool=tool, idle_cpu_pct_before=idle_cpu())
        row.update(run_start(spec, PORTS[tool], PLOT[tool], out_prefix + "_serve.log", out_prefix))
        print(json.dumps(row, default=str))
