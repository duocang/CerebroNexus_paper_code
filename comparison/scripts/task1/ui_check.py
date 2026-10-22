"""Task 1 UI check for the Shiny tools: serve an app, wait for the main embedding plot, read the embedding choices the UI offers.
Usage: ui_check.py <tool isee|shinycell> <dataset> <route> <kind> <workaround 0|1> <out.json>"""
import json, os, subprocess, sys, time
HERE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(HERE, "scripts")); import harness
tool, ds, route, kind, wk, out = sys.argv[1:7]
PORT = 8832
art = os.path.join(HERE, "artifacts", "t1", f"ui_{tool}_{ds}_{route}_{kind}_w{wk}")
if tool == "isee":
    subprocess.run(harness.R("../task1/isee_artifact.R", ds, route, kind, wk, art)["cmd"], cwd=HERE, env=harness.r_env(), capture_output=True)
    spec = harness.R("isee_serve.R", os.path.join(art, "sce.rds"), PORT)
else:
    art = os.path.join(HERE, "artifacts", "t1", f"sc_{ds}_{route}_{kind}_w{wk}")
    spec = harness.R("serve_shiny_dir.R", art, PORT)
row = dict(tool=tool, dataset=ds, route=route, input=kind, workaround=wk == "1")
if not os.path.exists(art):
    row["ui_status"] = "no artifact"; json.dump(row, open(out, "w")); sys.exit()
br = harness.BrowserRun()
log = os.path.join(HERE, "logs", "task1", f"ui_{tool}_{ds}_{route}_{kind}_w{wk}.log")
with open(log, "w") as lf:
    p = subprocess.Popen(spec["cmd"], cwd=HERE, env=spec["env"], stdout=lf, stderr=subprocess.STDOUT)
    try:
        t0 = time.time(); ok = False
        while time.time() - t0 < 90:
            if p.poll() is not None: break
            try:
                import requests
                if requests.get(f"http://127.0.0.1:{PORT}/", timeout=2).status_code == 200: ok = True; break
            except Exception: pass
            time.sleep(0.3)
        if not ok:
            row["ui_status"] = "server did not start"; row["server_log_tail"] = open(log, errors="replace").read()[-400:]
        else:
            res = harness.first_plot(br, f"http://127.0.0.1:{PORT}/", harness.PLOT[tool], time.perf_counter(),
                                     os.path.join(HERE, "logs", "task1", f"ui_{tool}_{ds}_{route}_{kind}_w{wk}.png"), timeout=60)
            row["ui_status"] = "plot drawn" if res["plot_status"] == "ok" else "plot not drawn within 60 s"
            row["ink_fraction"] = res.get("ink_fraction")
            time.sleep(1)
            if tool == "isee":
                row["ui_embedding_choices"] = br.page.evaluate("""() => { const s = document.querySelector('#ReducedDimensionPlot1_Type');
                    return s ? (s.selectize ? Object.keys(s.selectize.options) : [...s.options].map(o => o.value)) : null }""")
                row["ui_notifications"] = br.page.evaluate("() => [...document.querySelectorAll('.shiny-notification-content, .shiny-output-error')].map(e => e.innerText.slice(0,200))")
            else:
                row["ui_embedding_choices"] = br.page.evaluate("""() => { const s = document.querySelector('#sc1a1drX');
                    return s ? [...(s.selectize ? Object.values(s.selectize.options).map(o => o.value) : [...s.options].map(o => o.value))] : null }""")
            row["console_errors"] = br.console[:8]
    finally:
        br.close(); harness.kill_tree(p)
json.dump(row, open(out, "w"), indent=1)
print(json.dumps(row)[:400])
