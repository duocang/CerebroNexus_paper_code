"""Task 2 for ShinyCell: inventory of the generated app's selection and export controls (no code is run inside the app).
Finds: no box/lasso selection on the (static ggplot) plots; 'Toggle to subset cells' filters the plot by metadata only; the only exports are plot
PDF/PNG and a few summary tables (no cell IDs). Records 'no export route'. Usage: t2_shinycell.py"""
import json, os, sys, time, subprocess
from t2_common import *
S = load_sets()
PORT = 8844
res = {}
for sname, art in (("S1", "sc_I1_sce_rewritten_w1"), ("S2", "sc_I2_seurat_orig_w0")):
    srv = start_server(harness.R("serve_shiny_dir.R", os.path.join(HERE, "artifacts", "t1", art), PORT), PORT)
    br = harness.BrowserRun(); pg = br.page
    try:
        pg.goto(f"http://127.0.0.1:{PORT}/"); time.sleep(6)
        inv = {}
        tabs = [t for t in pg.evaluate("() => [...document.querySelectorAll('.nav-tabs a, ul.nav a')].map(a=>a.innerText.trim())") if t]
        for t in tabs:
            pg.get_by_text(t, exact=True).first.click(); time.sleep(2)
            inv[t] = pg.evaluate("""() => ({
                downloads: [...document.querySelectorAll('.shiny-download-link')].filter(e=>e.offsetParent!==null).map(e=>e.innerText.trim()),
                table_headers: [...document.querySelectorAll('table.dataTable')].filter(e=>e.offsetParent!==null).map(t=>[...t.querySelectorAll('thead th')].map(h=>h.innerText.trim())),
                brushable_plots: [...document.querySelectorAll('.shiny-plot-output')].filter(e=>e.offsetParent!==null && (e.getAttribute('data-brush') || e.querySelector('[data-brush]'))).length })""")
        # subset toggle on the first tab: what it offers
        pg.get_by_text(tabs[0], exact=True).first.click(); time.sleep(1)
        pg.get_by_role("button", name="Toggle to subset cells").first.click(); time.sleep(1.5)
        subset_text = pg.evaluate("() => document.body.innerText.slice(0, 1200)")
        row = dict(tool="ShinyCell", set=sname, set_definition=S[sname]["label"], status="no export route",
                   route_found="none: no box/lasso selection (static ggplot images, no brush); 'Toggle to subset cells' filters the plots by a metadata value only",
                   export_route="none: only plot PDF/PNG downloads and summary tables (no cell IDs)",
                   inventory=inv, subset_panel_excerpt=subset_text[:600], jaccard=None, repeat="n/a")
    finally:
        br.close(); stop_server(srv, PORT)
    save_row(row, f"shinycell_{sname}_none"); print(sname, row["status"], flush=True)
