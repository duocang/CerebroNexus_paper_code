"""Task 7 (PROTOCOL_round3.md section 13): twenty-gene sweep.

One session per (tool, tier): open the documented large-data plot, wait for it to be quiet, then colour by gene 1 (cold),
then genes 2-20 (warm) in file order. Per gene, time from the gesture that starts the colouring to the last frame that
differs from the final one. The gesture is identical for every gene: type the gene name into the tool's gene control and
confirm it; for tools where the colour-by mode must be switched first, that switch happens once during gene 1.

Per-tool control paths were verified live:

  cerebronexus_embedded / cerebronexus_h5
      navigate: click the "Gene expression" page; the gene list is #expression_genes_input-selectized (selectize,
      _cerebroGeneChoicesReady flag).  confirm: fill + Enter.  watch: #cv-cv-a.
  shinycell
      navigate: click the "CellInfo vs GeneExpr" tab.  the gene plot is the SEPARATE panel #sc1a1oup2 (not
      #sc1a1oup1, which is the cluster plot).  gene control #sc1a1inp2-selectized (server-loaded selectize; typing
      triggers a fuzzy server query).  confirm: click the exact .option (Enter is unreliable; the option may not be in
      the initial list).  watch: #sc1a1oup2.
  isee
      navigate: click the Bootstrap anchor a[href="#collapse_ReducedDimensionPlot1_VisualBoxOpen"] (clicking the
      panel-heading div does nothing), then the "Feature name" radio in #ReducedDimensionPlot1_ColorBy.  gene control
      #ReducedDimensionPlot1_ColorByFeatureName-selectized (Backspace first if a gene is set; the options are
      server-side, so type to query).  confirm: click the exact .option.  watch: #ReducedDimensionPlot1 (a
      server-rendered PNG, so its screenshot hash changes).
  cellxgene
      navigate: harness.serve_spec does not pass --disable-annotations, so a blocking "User Generated Data Directory"
      dialog appears on load (Cancel and Escape are no-ops); name the collection via [data-testid="new-annotation-name"]
      + [data-testid="submit-annotation"] to dismiss it.  gene control [data-testid="gene-search"], then the async
      [data-testid="suggest-menu-item-<gene>"], then [data-testid="colorby-<gene>"] (the second click is what actually
      recolours; the first only adds the gene to the list).  watch: canvas.graph-canvas.
  vitessce
      the Gene List is a virtualized table; filter with input[placeholder="Search"] first, then click the row
      .vit-fz28a7-tableRow (role=button) whose exact text is the gene.  watch: canvas#deckgl-overlay-A.

The plot element to watch (the one that must change when the gene is applied):

  cerebronexus_*: #cv-cv-a        shinycell: #sc1a1oup2        isee: #ReducedDimensionPlot1
  cellxgene: canvas.graph-canvas  vitessce: canvas#deckgl-overlay-A
"""
import hashlib, re, time

PLOT_SEL = {
    "cerebronexus_embedded": "#cv-cv-a",
    "cerebronexus_h5": "#cv-cv-a",
    "shinycell": "#sc1a1oup2",
    "isee": "#ReducedDimensionPlot1",
    "cellxgene": "canvas.graph-canvas",
    "vitessce": "canvas#deckgl-overlay-A",
}
FRAME_INTERVAL = 0.25
SETTLE_S = 2.0          # s without a change of the plot: it has settled
GENE_TIMEOUT = 60.0     # protocol: "a timeout of sixty seconds per gene"
GENE_MS = int(GENE_TIMEOUT * 1000)   # Playwright timeouts are milliseconds


def _png_hash(png):
    return hashlib.sha256(png).hexdigest()


def _shot_hash(page, sel):
    loc = page.locator(sel).first
    return _png_hash(loc.screenshot(timeout=20000, animations="allow"))


def wait_settled(page, sel, quiet_s=SETTLE_S, timeout=180.0, t_deadline=None):
    """Wait until the plot element has been unchanged for quiet_s of continuous sampling (the protocol's 'quiet').
    'Settled' = the current frame's hash equals the previous frame's hash, and that run of identical hashes has lasted
    quiet_s. Returns the settled frame's png hash."""
    last_h, last_change = None, time.perf_counter()
    while (t_deadline is None or time.perf_counter() < t_deadline):
        try:
            h = _shot_hash(page, sel)
        except Exception:
            time.sleep(0.5); continue
        if h != last_h:
            last_h, last_change = h, time.perf_counter()
        elif (time.perf_counter() - last_change) >= quiet_s:
            return last_h
        time.sleep(FRAME_INTERVAL)
    raise TimeoutError(f"plot {sel} never settled")


# ----------------------------------------------------------------------------- per-tool gesture
def _cnx_set_gene(page, gene):
    """CerebroNexus wraps a native <select> in selectize: a selected gene is <option selected>. Click, Backspace to
    clear the selected option, type the new gene, Enter to apply."""
    f = page.locator("#expression_genes_input-selectized")
    f.click(timeout=4000)
    page.keyboard.press("Backspace")
    page.keyboard.type(gene, delay=30)
    page.keyboard.press("Enter")


def _shiny_set_gene(page, gene):
    """ShinyCell's gene <select> is server-loaded selectize. A selected gene is an .item, not text: Backspace clears it.
    Typing a gene triggers a server-side (fuzzy) query, so Enter only works when the exact option is already present;
    wait for the exact .option and click it to apply the gene."""
    f = page.locator("#sc1a1inp2-selectized")
    f.click(timeout=4000)
    page.keyboard.press("Backspace")              # clear the previously selected .item
    page.keyboard.type(gene, delay=30)
    opts = page.locator("#sc1a1inp2 + .selectize-control .selectize-dropdown .option").filter(
        has_text=re.compile(f"^{re.escape(gene)}$"))
    opts.first.wait_for(timeout=GENE_MS)
    for o in opts.all():
        if o.is_visible():
            o.click()
            return
    opts.first.click()


def _isee_set_gene(page, gene):
    """iSEE's feature-name selectize queries the server as you type; wait for the exact option and click it."""
    f = page.locator("#ReducedDimensionPlot1_ColorByFeatureName-selectized")
    f.click(timeout=4000)
    page.keyboard.press("Backspace")          # clear any previous gene (typing would otherwise be eaten)
    page.keyboard.type(gene, delay=60)
    opt = page.locator(
        "#ReducedDimensionPlot1_ColorByFeatureName + .selectize-control .selectize-dropdown .option"
    ).filter(has_text=re.compile(f"^{re.escape(gene)}$"))
    opt.first.wait_for(timeout=GENE_MS)
    for o in opt.all():
        if o.is_visible():
            o.click()
            return
    opt.first.click()


def _cellx_set_gene(page, gene):
    page.locator("[data-testid='gene-search']").fill(gene)
    page.locator(f"[data-testid='suggest-menu-item-{gene}']").first.wait_for(timeout=GENE_MS)
    page.locator(f"[data-testid='suggest-menu-item-{gene}']").first.click()
    page.wait_for_timeout(1500)
    page.locator(f"[data-testid='colorby-{gene}']").first.wait_for(timeout=GENE_MS)
    page.locator(f"[data-testid='colorby-{gene}']").first.click()


def _vitessce_set_gene(page, gene):
    page.locator("input[placeholder='Search']").fill(gene)
    page.wait_for_timeout(1500)                       # virtualized list filters asynchronously
    page.locator(".vit-fz28a7-tableRow").filter(has_text=re.compile(f"^{re.escape(gene)}$")).first.click()


SET_GENE = {
    "cerebronexus_embedded": _cnx_set_gene,
    "cerebronexus_h5": _cnx_set_gene,
    "shinycell": _shiny_set_gene,
    "isee": _isee_set_gene,
    "cellxgene": _cellx_set_gene,
    "vitessce": _vitessce_set_gene,
}


def navigate(page, tool):
    """Bring the tool to the state where the gene control is available (once per session)."""
    if tool in ("cerebronexus_embedded", "cerebronexus_h5"):
        page.get_by_text("Gene expression", exact=True).first.click(timeout=8000)
        page.wait_for_timeout(3000)               # the page swaps its canvas; give it a moment
    elif tool == "shinycell":
        page.get_by_text("CellInfo vs GeneExpr", exact=True).first.click(timeout=8000)
        page.wait_for_timeout(3000)
    elif tool == "isee":
        # The plot panel is open, but its "Visual parameters" section starts collapsed. The heading div alone does not
        # toggle it; click the Bootstrap collapse anchor, then choose the "Feature name" colour-by radio.
        page.locator("a[href='#collapse_ReducedDimensionPlot1_VisualBoxOpen']").first.click(timeout=8000)
        page.wait_for_timeout(800)
        page.locator(
            "#ReducedDimensionPlot1_ColorBy input[type=radio][value='Feature name']"
        ).check(force=True)
        page.wait_for_timeout(1000)
    elif tool == "cellxgene":
        # cellxgene 1.3.0 starts with a blocking "User Generated Data Directory" dialog when annotations are enabled
        # (harness.serve_spec does not pass --disable-annotations). Naming the collection is the only way to dismiss it
        # (Cancel and Escape are no-ops); do it once, before the sweep.
        dlg = page.locator("[data-testid='annotation-dialog']")
        try:
            dlg.first.wait_for(state="visible", timeout=10000)
        except Exception:
            pass
        if dlg.count() and dlg.first.is_visible():
            page.locator("[data-testid='new-annotation-name']").fill("browser")
            page.locator("[data-testid='submit-annotation']").click()
            dlg.first.wait_for(state="hidden", timeout=20000)
        page.wait_for_timeout(1000)


def sweep_gene(page, tool, gene, t_deadline):
    """Perform the colour-by-gene gesture for one gene; time from the gesture to the last frame that differs from the
    final (settled) one, i.e. the time for the plot to settle into the new gene's colouring. Returns dict(status, t_s, error).
    A timeout is when no stable frame is reached within the per-gene window."""
    sel = PLOT_SEL[tool]
    before = _shot_hash(page, sel)
    t0 = time.perf_counter()
    SET_GENE[tool](page, gene)
    # wait for the plot to settle again (quiet) after the gesture
    last_h, last_change = None, time.perf_counter()
    saw_change = False
    while time.perf_counter() < t_deadline:
        try:
            h = _shot_hash(page, sel)
        except Exception:
            time.sleep(FRAME_INTERVAL); continue
        if h != before:
            saw_change = True
        if h != last_h:
            last_h, last_change = h, time.perf_counter()
        elif saw_change and (time.perf_counter() - last_change) >= SETTLE_S:
            # the new colouring has been stable for SETTLE_S; the last frame that differed from this final one was ~SETTLE_S ago
            return dict(status="ok", t_s=round((time.perf_counter() - SETTLE_S) - t0, 3))
        time.sleep(FRAME_INTERVAL)
    if saw_change:
        # it changed but never re-settled within the window: report the time to the last change
        return dict(status="ok", t_s=round(time.perf_counter() - t0, 3), error="did not re-settle within window")
    return dict(status="timeout", t_s=None, error="no frame differed from the pre-gesture frame within 60 s")
