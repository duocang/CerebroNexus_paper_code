"""Figure captures for the tool comparison (FIGURES.md): A1-A5 (pbmc3k, UMAP coloured by louvain) and B1-B2 (Visium, spatial view).

Run with the comparison Python environment (env/py), from anywhere:

    python scripts/report/capture_figures.py            # all seven captures
    python scripts/report/capture_figures.py A3 A4      # only these
    python scripts/report/capture_figures.py --list     # print ids and exit

Nothing here is timed, nothing here touches harness.py or results/. One id at a time: build once into data/builds/fig_<id>/ (reused if
present), start one server, capture the plot element only, kill the process tree, then the next id.
Output: figures/captures/<id>.png (3x element screenshot, unchanged), <id>.json (record), index.csv.
"""
import argparse, csv, datetime, hashlib, json, os, subprocess, sys, time

HERE_SCRIPTS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "run")
sys.path.insert(0, HERE_SCRIPTS)
import harness                                    # noqa: E402  (build_spec, serve_spec, R, P, PORTS, kill_tree, port_free, env helpers)
import requests                                   # noqa: E402
from playwright.sync_api import sync_playwright   # noqa: E402

HERE = harness.HERE
OUT = os.path.join(HERE, "figures", "captures")
ART = os.path.join(HERE, "data", "builds")
VIEWPORT = {"width": 1024, "height": 720}
DSF = 3
GIVE_UP_S = 120
POLL_S = 0.5
MIN_INK = 0.01          # a saved frame must show a drawn plot (same ink rule as the harness, D2/D11), not a blank canvas

I1 = dict(file=os.path.join(HERE, "data", "raw", "pbmc3k.h5ad"), file_r=os.path.join(HERE, "data", "inputs", "I1_rewritten.h5ad"), group="louvain", name="I1 pbmc3k, 2,638 cells")
I3 = dict(file=os.path.join(HERE, "data", "raw", "visium_hne_adata.h5ad"), file_r=os.path.join(HERE, "data", "inputs", "I3_rewritten.h5ad"), group="cluster", name="I3 Visium H&E mouse brain, 2,688 spots")

# JS helpers, injected into every page. No regular expressions or backslashes on purpose.
JS_HELPERS = """
window.__cap = {
  path(e) { const out = []; while (e && e.nodeType === 1 && e !== document.body) { let s = e.tagName.toLowerCase(); if (e.id) s += '#' + e.id;
      const c = typeof e.className === 'string' ? e.className : (e.className && e.className.baseVal) || '';
      if (c) s += '.' + c.split(' ').filter(x => x).slice(0, 2).join('.'); const tid = e.getAttribute && e.getAttribute('data-testid'); if (tid) s += '[data-testid=' + tid + ']';
      out.unshift(s); e = e.parentElement; } return out.slice(-4).join(' > '); },
  box(e) { const b = e.getBoundingClientRect(); return {x: b.left + window.scrollX, y: b.top + window.scrollY, width: b.width, height: b.height}; },
  hideOverlays(target, keepSel) {
    // everything that is drawn over the target's box and is not the target, an ancestor or descendant of it, nor one of the plot's own layers
    if (!document.getElementById('__cap_style')) { const st = document.createElement('style'); st.id = '__cap_style';
      st.textContent = '[data-capture-hidden]{visibility:hidden !important}'; document.head.appendChild(st); }
    const tb = target.getBoundingClientRect(); const done = [];
    for (const e of document.body.querySelectorAll('*')) {
      if (['SCRIPT', 'STYLE', 'LINK', 'META', 'HEAD', 'TITLE'].includes(e.tagName)) continue;
      if (e === target || e.contains(target) || target.contains(e)) continue;
      if (keepSel && (e.matches(keepSel) || e.closest(keepSel))) continue;
      if (e.closest('[data-capture-hidden]')) continue;
      const b = e.getBoundingClientRect(); if (b.width <= 0 || b.height <= 0) continue;
      // the screenshot is rounded out to whole device pixels, so neighbours within 1 css px of the box are tested too
      const ex = Math.min(b.right, tb.right + 1) - Math.max(b.left, tb.left - 1), ey = Math.min(b.bottom, tb.bottom + 1) - Math.max(b.top, tb.top - 1);
      if (ex <= 0 || ey <= 0) continue;
      if (getComputedStyle(e).visibility === 'hidden') continue;
      const ix = Math.min(b.right, tb.right) - Math.max(b.left, tb.left), iy = Math.min(b.bottom, tb.bottom) - Math.max(b.top, tb.top);
      // a neighbour that only touches the box by a sliver is hidden too
      if (ix <= 2 || iy <= 2) { e.setAttribute('data-capture-hidden', '1'); done.push(window.__cap.path(e) + ' (edge sliver)'); continue; }
      // only things positioned over the plot count as overlays; plain page content that merely lies in the box would be a layout error and is reported
      let p = e, over = false; while (p && p !== document.body) { const pos = getComputedStyle(p).position; if (pos === 'absolute' || pos === 'fixed') { over = true; break; } p = p.parentElement; }
      if (!over) continue;
      e.setAttribute('data-capture-hidden', '1'); done.push(window.__cap.path(e));
    }
    return done;
  },
  textBoxes(target, hiddenAttr) {
    const tb = target.getBoundingClientRect(); const out = [];
    for (const e of document.body.querySelectorAll('*')) {
      let own = ''; for (const n of e.childNodes) if (n.nodeType === 3) own += n.textContent;
      own = own.trim(); if (!own) continue;
      if (e.closest('[data-capture-hidden]')) continue;
      const b = e.getBoundingClientRect(); if (b.width <= 0 || b.height <= 0) continue;
      const ix = Math.min(b.right, tb.right) - Math.max(b.left, tb.left), iy = Math.min(b.bottom, tb.bottom) - Math.max(b.top, tb.top);
      if (ix <= 0 || iy <= 0 || ix * iy < 0.5 * b.width * b.height) continue;
      const cs = getComputedStyle(e); if (cs.visibility === 'hidden' || cs.display === 'none') continue;
      out.push({text: own.slice(0, 80), font_px: parseFloat(cs.fontSize), path: window.__cap.path(e), x: b.left - tb.left, y: b.top - tb.top, width: b.width, height: b.height});
    }
    return out;
  },
  labeled(label) {
    // selected text of the selectize/select control that carries the visible label
    for (const l of document.querySelectorAll('label')) {
      if (l.textContent.trim() !== label || l.offsetParent === null) continue;
      const g = l.closest('.form-group') || l.parentElement; const it = g.querySelector('.selectize-input .item'); if (it) return it.textContent.trim();
      const s = g.querySelector('select'); if (s) return s.value;
    }
    return null;
  },
  shinyBusy() { return !!(window.jQuery && window.jQuery('html').hasClass('shiny-busy')); },
  hasShiny() { return !!window.Shiny; }
};
"""


def now():
    return datetime.datetime.now().astimezone().isoformat(timespec="seconds")


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1 << 22), b""):
            h.update(b)
    return h.hexdigest()


def sh(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, errors="replace").stdout.strip()


# ----------------------------------------------------------------------------------------------- servers
def build_once(tool, ds, art, input_file, extra_marker=""):
    """Build the artifact into art/ unless it already exists (marker file). Returns the build record."""
    marker = os.path.join(art, ".built")
    if os.path.exists(marker):
        return dict(reused=True)
    os.makedirs(art, exist_ok=True)
    spec = harness.build_spec(tool, ds, input_file, art)
    res = harness.run_build(spec, os.path.join(art, "build.log"))
    if res["status"] != "ok":
        raise RuntimeError(f"build failed ({res['status']}), see {os.path.join(art, 'build.log')}")
    open(marker, "w").write(now())
    return dict(reused=False, wall_s=round(res["wall_s"], 1))


def start_server(cmd, env, port, log):
    if not harness.port_free(port):
        raise RuntimeError(f"port {port} is not free")
    lf = open(log, "w", encoding="utf-8", errors="replace")
    proc = subprocess.Popen(cmd, cwd=HERE, env=env, stdout=lf, stderr=subprocess.STDOUT)
    t0 = time.time()
    while time.time() - t0 < 300:
        if proc.poll() is not None:
            raise RuntimeError(f"server exited with {proc.returncode}, see {log}")
        try:
            if requests.get(f"http://127.0.0.1:{port}/", timeout=2).status_code == 200:
                return proc
        except requests.RequestException:
            pass
        time.sleep(0.3)
    harness.kill_tree(proc)
    raise RuntimeError("server did not answer within 300 s")


def stop_server(proc, port):
    harness.kill_tree(proc)
    for _ in range(100):
        if harness.port_free(port):
            return
        time.sleep(0.2)
    raise RuntimeError(f"port {port} still busy after the server was killed")


def isee_serve_script(art):
    """iSEE opens on PCA by default; the capture starts it with an initial UMAP panel coloured by louvain (written next to the artifact)."""
    path = os.path.join(art, "serve_initial.R")
    with open(path, "w") as f:
        f.write('a <- commandArgs(TRUE)\n'
                'suppressMessages(library(iSEE))\n'
                'sce <- readRDS(a[1])\n'
                'app <- iSEE(sce, initial = list(ReducedDimensionPlot(Type = "X_umap", ColorBy = "Column data", ColorByColumnData = "louvain", PanelWidth = 6L)))\n'
                'shiny::runApp(app, host = "127.0.0.1", port = as.integer(a[2]), launch.browser = FALSE)\n')
    return path


# ----------------------------------------------------------------------------------------------- per-tool page setup
def set_selectize(page, element_id, value):
    page.evaluate("([i, v]) => document.getElementById(i).selectize.setValue(v)", [element_id, value])


def setup_A1(page, art):   # CerebroNexus, Projection tab
    page.get_by_text("Projection", exact=True).first.click()
    page.wait_for_selector("#cv-cv-a", state="visible", timeout=60000)
    changed = []
    before = page.evaluate("() => document.getElementById('overview_projection_to_display').value")
    if before != "UMAP":
        set_selectize(page, "overview_projection_to_display", "UMAP")
        changed.append(f"Projection selector set from '{before}' (default) to 'UMAP'")
    before_c = page.evaluate("() => document.getElementById('overview_projection_point_color').value")
    if before_c != "louvain":
        set_selectize(page, "overview_projection_point_color", "louvain")
        changed.append(f"Colour by set from '{before_c}' to 'louvain'")
    return changed


def read_A1(page):
    return page.evaluate("""() => ({projection: document.getElementById('overview_projection_to_display').value,
        colour_by: document.getElementById('overview_projection_point_color').value,
        description: (document.getElementById('cv-description-a') || {}).textContent})""")


def check_A1(r):
    return r["projection"] == "UMAP" and r["colour_by"] == "louvain" and "2638 points" in (r["description"] or "")


def setup_A2(page, art):   # ShinyCell, first tab
    page.wait_for_selector("#sc1a1oup1", state="visible", timeout=60000)
    changed = []
    for cid, want, what in (("sc1a1drX", "Xumap1", "X-axis"), ("sc1a1drY", "Xumap2", "Y-axis"), ("sc1a1inp1", "louvain", "Cell information")):
        cur = page.evaluate("(i) => document.getElementById(i).value", cid)
        if cur != want:
            set_selectize(page, cid, want)
            changed.append(f"{what} set from '{cur}' (default) to '{want}'")
    # At 1024 px the plot column is 465 px wide; with the default font size the 8-entry legend does not fit the plot image and is cut off at its
    # bottom and sides (the image is drawn by ShinyCell at that size). The graphics control "Font size" is set to Small.
    page.evaluate("() => document.querySelector('input[name=sc1a1fsz][value=Small]').click()")
    changed.append("Graphics control 'Font size' set from 'Medium' (default) to 'Small' so that the legend fits the plot image at this width")
    return changed


def read_A2(page):
    return page.evaluate("""() => ({x_axis: document.getElementById('sc1a1drX').value, y_axis: document.getElementById('sc1a1drY').value,
        cell_info: document.getElementById('sc1a1inp1').value, font_size: (document.querySelector('input[name=sc1a1fsz]:checked') || {}).value})""")


def check_A2(r):
    return r["x_axis"] == "Xumap1" and r["y_axis"] == "Xumap2" and r["cell_info"] == "louvain" and r["font_size"] == "Small"


def setup_A3(page, art):   # iSEE: everything is set through initial= at start-up
    page.wait_for_selector("#ReducedDimensionPlot1", state="visible", timeout=120000)
    return ["iSEE started with initial = list(ReducedDimensionPlot(Type = 'X_umap', ColorBy = 'Column data', ColorByColumnData = 'louvain', PanelWidth = 6L)); "
            "its default panel opens on X_pca; PanelWidth 6 (default 4 of 12) because at 4 the plot is 313 px wide and the legend loses its last two labels"]


def read_A3(page):
    return page.evaluate("""() => ({type: document.getElementById('ReducedDimensionPlot1_Type').value,
        colour_by_mode: (document.querySelector('input[name=ReducedDimensionPlot1_ColorBy]:checked') || {}).value || null,
        colour_by_column: document.getElementById('ReducedDimensionPlot1_ColorByColumnData').value,
        plot_title_text: [...document.querySelectorAll('#ReducedDimensionPlot1 *')].length})""")


def check_A3(r):
    return r["type"] == "X_umap" and r["colour_by_mode"] == "Column data" and r["colour_by_column"] == "louvain"


def setup_A4(page, art):   # cellxgene
    page.wait_for_selector("canvas.graph-canvas", state="visible", timeout=120000)
    changed = ["launched with --disable-annotations (no annotation dialog), upgrade check blocked (D12)"]
    if page.locator(".bp3-dialog").count():
        page.get_by_role("button", name="Cancel").first.click()
        time.sleep(1)
        if page.locator(".bp3-dialog").count():
            raise RuntimeError("the annotation dialog is still open after Cancel")
        changed.append("annotation dialog dismissed with Cancel")
    page.locator("[data-testid='colorby-louvain']").click()
    changed.append("Color by set to the 'louvain' category (click on its colour button)")
    return changed


def read_A4(page):
    return page.evaluate("""() => ({embedding_label: (document.getElementById('embedding') || {}).textContent,
        colorby_active: [...document.querySelectorAll('[data-testid^=colorby]')].filter(e => e.classList.contains('bp3-active')).map(e => e.getAttribute('data-testid')),
        dialogs: document.querySelectorAll('.bp3-dialog').length})""")


def check_A4(r):
    return (r["embedding_label"] or "").startswith("umap") and "2638 out of 2638 cells" in (r["embedding_label"] or "") and r["colorby_active"] == ["colorby-louvain"] and r["dialogs"] == 0


def setup_A5(page, art):   # Vitessce, harness build: X_umap embedding, louvain cell sets
    page.wait_for_selector("canvas#deckgl-overlay-A", state="visible", timeout=120000)
    return []


def read_A5(page):
    cfg = page.evaluate("() => document.documentElement.innerHTML").replace(" ", "")
    return dict(
        title=page.evaluate("() => { const t = [...document.querySelectorAll('*')].find(e => e.children.length === 0 && (e.textContent || '').startsWith('Scatterplot')); return t ? t.textContent.trim() : null }"),
        count_text=page.evaluate("() => { const t = [...document.querySelectorAll('*')].find(e => e.children.length === 0 && (e.textContent || '').endsWith(' cells')); return t ? t.textContent.trim() : null }"),
        config_embedding_path="obsm/X_umap" if '"path":"obsm/X_umap"' in cfg else None,
        config_cell_sets="obs/louvain" if '"path":"obs/louvain"' in cfg else None,
        cell_set_group=page.evaluate("() => { const t = [...document.querySelectorAll('*')].find(e => e.children.length === 0 && (e.textContent || '').trim() === 'louvain'); return t ? t.textContent.trim() : null }"))


def check_A5(r):
    return r["title"] == "Scatterplot (UMAP)" and r["count_text"] == "2,638 cells" and r["config_embedding_path"] == "obsm/X_umap" and r["config_cell_sets"] == "obs/louvain" and r["cell_set_group"] == "louvain"


def setup_B1(page, art):   # CerebroNexus, Spatial tab
    page.evaluate("() => [...document.querySelectorAll('.sidebar-menu a')].find(a => a.innerText.trim() === 'Spatial').click()")
    page.wait_for_selector("#cv-cv-a", state="visible", timeout=60000)
    return []


def read_B1(page):
    return page.evaluate("""() => ({fov: window.__cap.labeled('FOV / section'), plot_type: window.__cap.labeled('Plot type'), colour_by: window.__cap.labeled('Colour by'),
        split_by: window.__cap.labeled('Split by'), background: [...document.querySelectorAll('.selectize-input .item')].map(e => e.textContent.trim()).filter(t => t.startsWith('hires')).length > 0,
        page_heading: [...document.querySelectorAll('.content-wrapper h1, .content-wrapper h2, .cerebro-page-title')].filter(e => e.offsetParent !== null).map(e => e.textContent.trim()).slice(0, 2)})""")


def check_B1(r):
    return r["fov"] == "spatial" and r["plot_type"] == "ImageDimPlot" and r["colour_by"] == "cluster" and r["split_by"] == "None"


def build_B2(art):
    """Vitessce spatial view of the Visium spots. The default 'spatial' view draws no spots (Task 1: blank); the 'spatialBeta' view with a
    spot layer does. The spatial coordinates are written as float32 (the Zarr of the harness build has them as uint16)."""
    marker = os.path.join(art, ".built")
    if os.path.exists(marker):
        return dict(reused=True)
    import math, shutil, warnings
    warnings.filterwarnings("ignore")
    import numpy as np, anndata as ad
    from vitessce import VitessceConfig, CoordinationType as ct, AnnDataWrapper, CoordinationLevel as CL
    os.makedirs(art, exist_ok=True)
    shutil.rmtree(os.path.join(art, "data.zarr"), ignore_errors=True)
    a = ad.read_h5ad(I3["file"])
    b = ad.AnnData(X=a.X.tocsc(), obs=a.obs[["cluster"]].copy(), var=a.var[[]].copy())
    b.obsm["spatial"] = np.asarray(a.obsm["spatial"], dtype=np.float32)
    b.write_zarr(os.path.join(art, "data.zarr"))
    xy = b.obsm["spatial"]
    names = list(a.obs["cluster"].cat.categories)
    cx, cy = float((xy[:, 0].min() + xy[:, 0].max()) / 2), float((xy[:, 1].min() + xy[:, 1].max()) / 2)
    span = float(max(np.ptp(xy[:, 0]), np.ptp(xy[:, 1])))
    vc = VitessceConfig(schema_version="1.0.17", name="visium spatial")
    w = AnnDataWrapper(adata_url="__ORIGIN__/data.zarr", obs_spots_path="obsm/spatial", obs_set_paths=["obs/cluster"], obs_set_names=["cluster"],
                       obs_feature_matrix_path="X", coordination_values={"obsType": "spot"})
    ds = vc.add_dataset(name="d").add_object(w)
    sp = vc.add_view("spatialBeta", dataset=ds)
    sets = vc.add_view("obsSets", dataset=ds)
    vc.link_views_by_dict([sp], {"spotLayer": CL([{"obsType": "spot", "spatialLayerVisible": True, "spatialLayerOpacity": 1.0, "spatialSpotRadius": 70,
                                                   "spatialSpotFilled": True, "obsColorEncoding": "cellSetSelection",
                                                   "obsSetSelection": [["cluster", n] for n in names]}])})
    vc.link_views([sp, sets], [ct.OBS_TYPE], ["spot"])
    vc.link_views([sp], [ct.SPATIAL_ZOOM, ct.SPATIAL_TARGET_X, ct.SPATIAL_TARGET_Y], [math.log2(600.0 / span), cx, cy])
    vc.layout(sp | sets)
    json.dump(vc.to_dict(), open(os.path.join(art, "config.json"), "w"))
    open(marker, "w").write(now())
    return dict(reused=False, clusters=len(names))


def setup_B2(page, art):
    page.wait_for_selector("canvas#deckgl-overlay-A", state="visible", timeout=120000)
    return ["view type 'spatialBeta' (the default 'spatial' view draws no spots), spot layer with spatialSpotRadius 70, obsType 'spot', cell-set colouring by 'cluster' "
            "(all 15 sets selected), spatialZoom and target set from the coordinate range; spatial coordinates stored as float32; no tissue image (Task 1: image absent)"]


def read_B2(page):
    cfg = page.evaluate("() => document.documentElement.innerHTML").replace(" ", "")
    return dict(
        title=page.evaluate("() => { const t = [...document.querySelectorAll('*')].find(e => e.children.length === 0 && (e.textContent || '').trim() === 'Spatial'); return t ? t.textContent.trim() : null }"),
        count_text=page.evaluate("() => { const t = [...document.querySelectorAll('*')].find(e => e.children.length === 0 && (e.textContent || '').endsWith(' spots')); return t ? t.textContent.trim() : null }"),
        legend_title=page.evaluate("() => { const t = [...document.querySelectorAll('svg text')].find(e => e.textContent.trim() === 'cluster'); return t ? t.textContent.trim() : null }"),
        legend_entries=page.evaluate("() => [...document.querySelectorAll('svg text')].map(e => e.textContent.trim()).filter(t => t && t !== 'cluster' && !(t[0] >= '0' && t[0] <= '9'))"),
        config_view="spatialBeta" if '"component":"spatialBeta"' in cfg else None,
        config_spots="obsm/spatial" if '"obsSpots":{"path":"obsm/spatial"}' in cfg else None,
        config_cell_sets="obs/cluster" if '"path":"obs/cluster"' in cfg else None)


def check_B2(r):
    return (r["title"] == "Spatial" and r["count_text"] == "2,688 spots" and r["legend_title"] == "cluster" and len(r["legend_entries"]) == 15
            and r["config_view"] == "spatialBeta" and r["config_spots"] == "obsm/spatial" and r["config_cell_sets"] == "obs/cluster")


# id -> spec. `element` is a CSS selector resolved by Playwright. `keep` = selector of the plot's own layers that must stay visible while overlays are hidden.
SPECS = {
    "A1": dict(tool="cerebronexus_default", version="CerebroNexus 6.0.0 (27ac995e), embedded backend", ds=I1, view="Projection, UMAP", colour_by="louvain",
               input_key="file", element="#cv-cv-a", keep="#cv-cv-a, .cv-canvas-wrap > canvas:not(.cv-mini)", setup=setup_A1, read=read_A1, check=check_A1, shiny=True),
    "A2": dict(tool="shinycell", version="ShinyCell 2.1.0 (5c61db78)", ds=I1, view="cell info vs gene expression tab, UMAP", colour_by="louvain",
               input_key="file_r", element="#sc1a1oup1", keep="#sc1a1oup1", setup=setup_A2, read=read_A2, check=check_A2, shiny=True),
    "A3": dict(tool="isee", version="iSEE 2.22.0", ds=I1, view="Reduced dimension plot, X_umap", colour_by="louvain",
               input_key="file_r", element="#ReducedDimensionPlot1", keep="#ReducedDimensionPlot1", setup=setup_A3, read=read_A3, check=check_A3, shiny=True),
    "A4": dict(tool="cellxgene", version="cellxgene 1.3.0", ds=I1, view="umap embedding", colour_by="louvain",
               input_key="file", element="canvas.graph-canvas", keep="canvas.graph-canvas", setup=setup_A4, read=read_A4, check=check_A4, shiny=False),
    "A5": dict(tool="vitessce", version="Vitessce 3.8.4 (Python) / vitessce@3.9.9 (JS)", ds=I1, view="Scatterplot, UMAP", colour_by="louvain (cell sets)",
               input_key="file", element="canvas#deckgl-overlay-A", keep="canvas#deckgl-overlay-A", setup=setup_A5, read=read_A5, check=check_A5, shiny=False),
    "B1": dict(tool="cerebronexus_default", version="CerebroNexus 6.0.0 (27ac995e), embedded backend", ds=I3, view="Spatial, ImageDimPlot with the H&E image", colour_by="cluster",
               input_key="file", element=".cv-canvas-wrap:has(#cv-cv-a)", keep=".cv-canvas-wrap > canvas:not(.cv-mini)", setup=setup_B1, read=read_B1, check=check_B1, shiny=True),
    "B2": dict(tool="vitessce", version="Vitessce 3.8.4 (Python) / vitessce@3.9.9 (JS)", ds=I3, view="Spatial (spatialBeta) view, spots only", colour_by="cluster",
               input_key="file", element="canvas#deckgl-overlay-A", keep="canvas#deckgl-overlay-A", setup=setup_B2, read=read_B2, check=check_B2, shiny=False),
}


# ----------------------------------------------------------------------------------------------- capture
def wait_idle(page, spec):
    """Network idle, Shiny idle (Shiny apps); then element screenshots every 500 ms until two in a row are pixel-identical."""
    page.wait_for_load_state("networkidle", timeout=GIVE_UP_S * 1000)
    if spec["shiny"]:
        page.wait_for_function("() => !window.__cap.hasShiny() || !window.__cap.shinyBusy()", timeout=GIVE_UP_S * 1000)


def capture_stable(page, spec, hidden_log):
    loc = page.locator(spec["element"]).first
    prev, t0 = None, time.time()
    while time.time() - t0 < GIVE_UP_S:
        hidden = page.evaluate("([s, k]) => window.__cap.hideOverlays(document.querySelector(s), k)", [spec["element"], spec["keep"]])
        for h in hidden:
            if h not in hidden_log:
                hidden_log.append(h)
        page.mouse.move(0, 0)
        png = loc.screenshot(animations="allow", caret="hide")
        if prev is not None and png == prev and harness.ink_fraction(png)[0] >= MIN_INK:
            return png
        prev = png
        time.sleep(POLL_S)
    raise RuntimeError(f"no finished, idle frame within {GIVE_UP_S} s (frames kept changing or the plot stayed blank)")


def fit_viewport(page, spec, record):
    """If the plot element is cut off at 1024 x 720, enlarge the height only."""
    for _ in range(4):
        b = page.evaluate("(s) => window.__cap.box(document.querySelector(s))", spec["element"])
        bottom = b["y"] + b["height"] - page.evaluate("() => window.scrollY")
        vh = page.viewport_size["height"]
        if bottom <= vh + 0.5 and b["y"] >= 0:
            return b
        new_h = int(b["y"] + b["height"]) + 24
        record.setdefault("viewport_enlarged_from", dict(VIEWPORT))
        page.set_viewport_size({"width": VIEWPORT["width"], "height": max(new_h, vh + 1)})
        time.sleep(2)
        wait_idle(page, spec)
    return page.evaluate("(s) => window.__cap.box(document.querySelector(s))", spec["element"])


def capture_id(cid):
    spec = SPECS[cid]
    tool, ds = spec["tool"], spec["ds"]
    art = os.path.join(ART, f"fig_{cid}")
    inp = ds[spec["input_key"]]
    port = harness.PORTS[tool]
    logdir = os.path.join(art, "logs"); os.makedirs(logdir, exist_ok=True)
    rec = dict(id=cid, tool=tool, tool_version=spec["version"], dataset=ds["name"], input_file=os.path.relpath(inp, HERE).replace("\\", "/"), input_sha256=sha256(inp),
               view=spec["view"], colour_by=spec["colour_by"], status="failed", started_at=now())
    proc = None
    try:
        # ---- build / serve spec
        if cid == "A5":
            res = build_once("vitessce", ds, art, ds["file"])
            serve = harness.serve_spec("vitessce", art, ds["file"], port)
        elif cid == "B2":
            res = build_B2(art)
            serve = harness.serve_spec("vitessce", art, ds["file"], port)
        elif cid == "A4":
            res = dict(reused=True, note="cellxgene reads the .h5ad directly")
            serve = harness.serve_spec("cellxgene", None, ds["file"], port)
            serve["cmd"] = serve["cmd"] + ["--disable-annotations"]
        elif cid == "A3":
            res = build_once("isee", ds, art, inp)
            serve = harness.R("isee_serve.R", os.path.join(art, "sce.rds"), port)       # replaced below
            serve["cmd"] = [harness.RSCRIPT, "--vanilla", isee_serve_script(art), os.path.join(art, "sce.rds"), str(port)]
        else:
            ds2 = dict(ds); ds2.setdefault("workaround", "1")
            res = build_once(tool, ds2, art, inp)
            serve = harness.serve_spec(tool, art, inp, port)
        rec["build"] = res
        rec["server_cmd"] = [os.path.relpath(c, HERE) if os.path.isabs(c) and c.startswith(HERE) else c for c in serve["cmd"]]
        proc = start_server(serve["cmd"], serve["env"], port, os.path.join(logdir, "server.log"))
        # ---- browser
        with sync_playwright() as pw:
            browser = pw.chromium.launch(channel="chrome", headless=True)
            ctx = browser.new_context(viewport=dict(VIEWPORT), device_scale_factor=DSF, color_scheme="light", reduced_motion="reduce", locale="en-US")
            page = ctx.new_page()
            page.add_init_script(JS_HELPERS)
            page.goto(f"http://127.0.0.1:{port}/", wait_until="load", timeout=120000)
            rec["chrome_version"] = browser.version
            time.sleep(3)
            rec["changed_from_default"] = spec["setup"](page, art)
            wait_idle(page, spec)
            time.sleep(1)
            box = fit_viewport(page, spec, rec)
            hidden_log = []
            png = capture_stable(page, spec, hidden_log)
            # ---- read back what the page shows, and fail if it is not the required view
            rb = spec["read"](page)
            rec["read_back"] = rb
            if not spec["check"](rb):
                raise RuntimeError(f"the page does not show the required view: {json.dumps(rb)}")
            rec["element"] = dict(selector=spec["element"], bbox_css_px=box)
            rec["hidden_overlay_selectors"] = hidden_log
            rec["text_boxes_in_element"] = page.evaluate("(s) => window.__cap.textBoxes(document.querySelector(s))", spec["element"])
            rec["viewport"] = page.viewport_size
            rec["device_scale_factor"] = DSF
            rec["browser_settings"] = dict(channel="chrome", headless=True, color_scheme="light", reduced_motion="reduce", locale="en-US")
            browser.close()
        os.makedirs(OUT, exist_ok=True)
        png_path = os.path.join(OUT, f"{cid}.png")
        open(png_path, "wb").write(png)
        w, h = harness.ink_fraction(png)[1:]
        rec.update(png=f"figures/captures/{cid}.png", png_width_px=w, png_height_px=h, png_bytes=len(png), png_sha256=hashlib.sha256(png).hexdigest(), status="ok")
    except Exception as e:                                    # a failed id is recorded, never saved as a partial frame
        rec["error"] = f"{type(e).__name__}: {e}"[:600]
        old = os.path.join(OUT, f"{cid}.png")
        if os.path.exists(old):
            os.remove(old)
    finally:
        if proc is not None:
            try:
                stop_server(proc, port)
            except Exception as e:
                rec["cleanup_warning"] = str(e)
        rec["finished_at"] = now()
        os.makedirs(OUT, exist_ok=True)
        json.dump(rec, open(os.path.join(OUT, f"{cid}.json"), "w", encoding="utf-8"), indent=2, ensure_ascii=False)
    return rec


def write_index(recs):
    path = os.path.join(OUT, "index.csv")
    rows = {}
    if os.path.exists(path):
        for r in csv.DictReader(open(path, encoding="utf-8")):
            rows[r["id"]] = r
    for r in recs:
        rows[r["id"]] = dict(id=r["id"], tool=r["tool"], version=r["tool_version"], dataset=r["dataset"], view=r["view"], colour_by=r["colour_by"],
                             status=r["status"], png_sha256=r.get("png_sha256", ""))
    fields = ["id", "tool", "version", "dataset", "view", "colour_by", "status", "png_sha256"]
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for k in SPECS:
            if k in rows:
                w.writerow(rows[k])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ids", nargs="*")
    ap.add_argument("--list", action="store_true")
    a = ap.parse_args()
    if a.list:
        for k, s in SPECS.items():
            print(k, s["tool"], s["ds"]["name"], "|", s["view"], "| colour by", s["colour_by"])
        return
    ids = a.ids or list(SPECS)
    bad = [i for i in ids if i not in SPECS]
    if bad:
        sys.exit(f"unknown id(s): {bad}")
    recs = []
    for cid in ids:                                           # strictly one id (one tool) at a time
        print(f"== {cid} ({SPECS[cid]['tool']})", flush=True)
        r = capture_id(cid)
        recs.append(r)
        print(f"   {r['status']}" + (f": {r.get('error')}" if r["status"] != "ok" else f", {r['png_width_px']}x{r['png_height_px']} px, {r['png_bytes'] // 1024} KB"), flush=True)
        write_index(recs)
    sys.exit(0 if all(r["status"] == "ok" for r in recs) else 1)


if __name__ == "__main__":
    main()
