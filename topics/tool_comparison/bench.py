"""Tool comparison: build, start, start again and colour-by-gene time of five viewers on the same data. See README.md.

    python bench.py [--tiers 5000,...,1300000] [--tools a,b] [--reps 3] [--genes 20] [--candidate REF] [--resume RUN_DIR]

CerebroNexus is installed from the checkout next to this repository (HEAD, or --candidate); its commit goes into the run's manifest.
"""
import argparse, csv, datetime, os, platform, statistics, subprocess, sys, time, traceback
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import drive, lib
from lib import HERE

TIERS = (5000, 10000, 20000, 50000, 100000, 500000, 1300000)   # the first N cells of the E18 data; 1.3 M is all of it (1,306,127)
FULL = 1300000
NO_MATRIX = {"cerebronexus_embedded", "shinycell", "isee"}      # their R route holds the matrix as a dgCMatrix: at most 2^31-1 non-zeros, the full set has 2.6e9
TOOLS = {"cerebronexus_embedded": 8811, "cerebronexus_h5": 8812, "shinycell": 8813, "isee": 8814, "cellxgene": 8815, "vitessce": 8816}   # name: port
LABEL = {"cerebronexus_embedded": "CerebroNexus (embedded)", "cerebronexus_h5": "CerebroNexus (HDF5)", "shinycell": "ShinyCell", "isee": "iSEE",
         "cellxgene": "cellxgene", "vitessce": "Vitessce"}
# What a user opens, and where the plot is. Nobody clicks: CerebroNexus is opened by its page link, the others show their plot at once.
CNX = ("/?page=projection", [".cerebro-first-view-canvas", "#cv-cv-a"])
OPEN = {"cerebronexus_embedded": CNX, "cerebronexus_h5": CNX, "shinycell": ("/", ["#sc1a1oup1"]), "isee": ("/", ["#ReducedDimensionPlot1"]),
        "cellxgene": ("/", ["canvas.graph-canvas"]), "vitessce": ("/", ["canvas#deckgl-overlay-A"])}
GROUP = ("cluster", "nUMI", "nGene")

FIELDS = {
    "builds": ["tier", "tool", "status", "build_s", "build_peak_rss_gb", "artifact_gb", "note"],
    "starts": ["tier", "tool", "rep", "kind", "status", "t_ready_s", "t_first_plot_s", "t_total_s", "server_peak_gb", "browser_peak_gb", "idle_cpu_pct", "error"],
    "genes": ["tier", "tool", "gene_idx", "gene", "status", "t_s", "server_rss_gb", "browser_peak_gb", "error"],
}


def build_cmd(tool, inp, out, env):
    if tool.startswith("cerebronexus"):
        return lib.R("cerebronexus_build.R", inp, out, "embedded" if tool.endswith("embedded") else "h5", *GROUP, env=env)
    if tool == "shinycell":
        return lib.R("shinycell_build.R", inp, out, "sce", "1", env=env)
    if tool == "isee":
        return lib.R("isee_build.R", inp, out, "sce", env=env)
    if tool == "vitessce":
        return lib.P("vitessce_build.py", inp, out, GROUP[0], "X_umap")
    return None   # cellxgene reads the .h5ad


def serve_cmd(tool, art, inp, port, env):
    if tool.startswith("cerebronexus"):
        return lib.R("cerebronexus_serve.R", os.path.join(art, next(f for f in sorted(os.listdir(art)) if f.endswith(".crb"))), port, env=env)
    if tool == "shinycell":
        return lib.R("serve_shiny_dir.R", art, port, env=env)
    if tool == "isee":
        return lib.R("isee_serve.R", os.path.join(art, "sce.rds"), port, env=env)
    if tool == "cellxgene":
        return dict(cmd=[os.path.join(HERE, "env", "py", "Scripts", "cellxgene.exe"), "launch", inp, "--host", "127.0.0.1", "--port", str(port), "--disable-gene-sets-save"],
                    env=lib.cellxgene_env())
    return dict(cmd=[lib.PY, os.path.join(HERE, "tools", "serve_vitessce.py"), art, str(port)], env=lib.py_env())


# ----------------------------------------------------------------------------- tables: one tsv per kind, one row per measurement
def read(run, kind):
    p = os.path.join(run, kind + ".tsv")
    return list(csv.DictReader(open(p, encoding="utf-8"), delimiter="\t")) if os.path.exists(p) else []


def add(run, table, **row):
    p = os.path.join(run, table + ".tsv"); new = not os.path.exists(p)
    with open(p, "a", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS[table], delimiter="\t")
        if new:
            w.writeheader()
        w.writerow({k: "" if row.get(k) is None else row[k] for k in FIELDS[table]})


def drop(run, tier, tool):
    for kind in FIELDS:
        keep = [r for r in read(run, kind) if not (r["tier"] == str(tier) and r["tool"] == tool)]
        if os.path.exists(os.path.join(run, kind + ".tsv")):
            with open(os.path.join(run, kind + ".tsv"), "w", newline="", encoding="utf-8") as f:
                w = csv.DictWriter(f, fieldnames=FIELDS[kind], delimiter="\t"); w.writeheader(); w.writerows(keep)


def finished(run, tier, tool):
    b = [r for r in read(run, "builds") if r["tier"] == str(tier) and r["tool"] == tool]
    return bool(b) and (b[0]["status"] != "ok" and b[0]["status"] != "n/a" or any(r["tier"] == str(tier) and r["tool"] == tool for r in read(run, "genes")))


gb = lambda x: None if x in (None, "") else round(x / 2**30, 3)


# ----------------------------------------------------------------------------- measurements
def starts(run, tool, tier, art, inp, env, reps):
    """reps pairs of starts: the first with an empty cache, the second of the same app with what the first one left."""
    path, sel = OPEN[tool]; port = TOOLS[tool]; cache = None
    for rep in range(1, reps + 1):
        cache = os.path.join(run, "cache", f"{tool}_{tier}_{rep}"); lib.remove_tree(cache); os.makedirs(cache)
        for kind in ("first", "again"):
            idle = lib.wait_idle()
            r = lib.run_start(serve_cmd(tool, art, inp, port, env(cache)), port, path, sel, os.path.join(run, "logs", f"{tool}_{tier}_{rep}_{kind}.log"),
                              os.path.join(run, "screens", f"{tool}_{tier}_{rep}_{kind}.jpg"))
            add(run, "starts", tier=tier, tool=tool, rep=rep, kind=kind, status=r["status"], t_ready_s=r.get("t_ready_s"), t_first_plot_s=r.get("t_first_plot_s"),
                t_total_s=r.get("t_total_s"), server_peak_gb=gb(r.get("peak_rss_bytes")), browser_peak_gb=gb(r.get("browser_peak_rss_bytes")),
                idle_cpu_pct=round(idle, 1), error=r.get("error"))
            print(f"    start {kind} {rep}: {r['status']} ready {r.get('t_ready_s')} plot {r.get('t_first_plot_s')}", flush=True)
            facts.update({k: r[k] for k in ("browser", "renderer") if r.get(k)})
    return cache


def gene_session(run, tool, tier, art, inp, env, cache, genes):
    """One session: open the plot, go to the gene control, colour by gene 1 (nothing warm yet), then gene 2 ... N. Per gene: the gesture to the last frame that changes."""
    port = TOOLS[tool]; path, sel = OPEN[tool]
    spec = serve_cmd(tool, art, inp, port, env(cache)); br = None
    with open(os.path.join(run, "logs", f"{tool}_{tier}_genes.log"), "w", encoding="utf-8", errors="replace") as lf:
        proc = subprocess.Popen(spec["cmd"], cwd=HERE, env=spec["env"], stdout=lf, stderr=subprocess.STDOUT)
        mem = lib.BrowserSampler(proc); mem.start()
        try:
            ready = lib.wait_ready(port, proc, time.perf_counter())
            if isinstance(ready, str):
                return add(run, "genes", tier=tier, tool=tool, gene_idx=0, status="error", error=ready)
            br = lib.BrowserRun()
            if lib.first_plot(br, f"http://127.0.0.1:{port}{path}", sel, os.path.join(run, "screens", f"{tool}_{tier}_genes.jpg"))["plot_status"] != "ok":
                return add(run, "genes", tier=tier, tool=tool, gene_idx=0, status="error", error="no first plot")
            drive.navigate(br.page, tool); drive.wait_settled(br.page, drive.PLOT_SEL[tool], timeout=300)
            bad = 0
            for i, g in enumerate(genes, 1):
                try:
                    r = drive.sweep_gene(br.page, tool, g, time.perf_counter() + drive.GENE_TIMEOUT)
                except Exception as e:
                    r = dict(status="error", t_s=None, error=str(e)[:200])
                edge = i in (1, len(genes))
                add(run, "genes", tier=tier, tool=tool, gene_idx=i, gene=g, status=r["status"], t_s=r.get("t_s"), error=r.get("error"),
                    server_rss_gb=gb(lib.tree_rss(proc)) if edge else None, browser_peak_gb=gb(mem.peak) if edge else None)
                print(f"    gene {i} {g}: {r['status']} {r.get('t_s')}", flush=True)
                bad += r["status"] != "ok"
                if bad >= 3:
                    break
        finally:
            mem.stop()
            if br:
                br.close()
            lib.kill_tree(proc)
    lib.wait_port_free(port)


def measure(run, tool, tier, inp, env, reps, genes):
    art = os.path.join(run, "art", f"{tool}_{tier}"); lib.remove_tree(art)
    cmd = build_cmd(tool, inp, art, env(None))
    if cmd is None:
        art = inp; add(run, "builds", tier=tier, tool=tool, status="n/a", artifact_gb=round(lib.dir_size(inp) / 2**30, 3))
    else:
        os.makedirs(art); lib.wait_idle()
        r = lib.run_build(cmd, os.path.join(run, "logs", f"{tool}_{tier}_build.log"))
        add(run, "builds", tier=tier, tool=tool, status=r["status"], build_s=round(r["wall_s"], 1), build_peak_rss_gb=gb(r["peak_rss_bytes"]),
            artifact_gb=round(lib.dir_size(art) / 2**30, 3) if r["status"] == "ok" else None)
        print(f"    build {r['status']} {r['wall_s']:.0f} s", flush=True)
        if r["status"] != "ok":
            return
    try:
        cache = starts(run, tool, tier, art, inp, env, reps)
        if genes:
            gene_session(run, tool, tier, art, inp, env, cache, genes)
    finally:
        if cmd is not None:
            lib.remove_tree(art)


# ----------------------------------------------------------------------------- the record of a run
facts = {}
num = lambda r, k: float(r[k]) if r.get(k) not in (None, "") else None
med = lambda v: statistics.median([x for x in v if x is not None]) if any(x is not None for x in v) else None


def summary(run):
    B, S, G = (read(run, k) for k in FIELDS)
    f = lambda v, d=1: "-" if v is None else f"{v:.{d}f}"
    head = ["Cells", "Tool", "Build s", "Artifact GiB", "First start s", "Again s", "Server GiB", "Browser GiB", "Gene 1 s", "Genes 2+ s", "ok starts", "ok genes"]
    lines = ["# Tool comparison", "", "Medians over the runs that finished. First start = launching the server to the first plot, empty cache; Again = the same app started once more. "
             "Genes = the gesture that colours the plot by a gene to the last frame that changes (gene 1 first, nothing warm). Rows: `builds.tsv`, `starts.tsv`, `genes.tsv`.", "",
             "| " + " | ".join(head) + " |", "|" + "---|" * len(head)]
    for tier in sorted({int(r["tier"]) for r in B}):
        for tool in LABEL:
            b = [r for r in B if r["tier"] == str(tier) and r["tool"] == tool]
            if not b:
                continue
            s = [r for r in S if r["tier"] == str(tier) and r["tool"] == tool]; ok = [r for r in s if r["status"] == "ok"]
            g = [r for r in G if r["tier"] == str(tier) and r["tool"] == tool and r["status"] == "ok" and r["t_s"]]
            kind = lambda k, c: med([num(r, c) for r in ok if r["kind"] == k])
            lines.append("| " + " | ".join([f"{tier:,}", LABEL[tool], f(num(b[0], "build_s")), f(num(b[0], "artifact_gb"), 2), f(kind("first", "t_total_s"), 2), f(kind("again", "t_total_s"), 2),
                                            f(med([num(r, "server_peak_gb") for r in ok]), 2), f(med([num(r, "browser_peak_gb") for r in ok]), 2),
                                            f(med([num(r, "t_s") for r in g if r["gene_idx"] == "1"]), 2), f(med([num(r, "t_s") for r in g if r["gene_idx"] != "1"]), 2),
                                            f"{len(ok)}/{len(s)}", f"{len(g)}/{len([r for r in G if r['tier'] == str(tier) and r['tool'] == tool])}"]) + " |")
    skipped = [r for r in B if r["status"] == "skipped"]
    if skipped:
        lines += ["", "Not measured: " + "; ".join(f"{LABEL[r['tool']]} at {int(r['tier']):,} cells ({r['note']})" for r in skipped) + "."]
    open(os.path.join(run, "summary.md"), "w", encoding="utf-8").write("\n".join(lines) + "\n")


def manifest(run, cnx, started, args):
    import psutil
    p = os.path.join(run, "manifest.tsv")
    old = dict(l.split(chr(9), 1) for l in open(p, encoding="utf-8").read().splitlines()[1:] if chr(9) in l) if os.path.exists(p) else {}
    m = dict(run=os.path.basename(run), cerebronexus_commit=cnx["sha"], cerebronexus_version=cnx["version"], started=old.get("started", started),
             ended=datetime.datetime.now().astimezone().isoformat(timespec="seconds"), host=platform.node(), os=platform.platform(), cpu=platform.processor(),
             cores=psutil.cpu_count(), ram_gb=round(psutil.virtual_memory().total / 2**30, 1), tiers=args.tiers, tools=args.tools, reps=args.reps, genes=args.genes, **facts, **lib.versions())
    if old:   # a resumed run: keep the tools of the earlier pass, and say which commit made their rows
        m["tools"] = ",".join(dict.fromkeys(old.get("tools", "").split(",") + args.tools.split(",")))
        if old.get("cerebronexus_commit") != cnx["sha"]:
            rest = [t for t in old.get("tools", "").split(",") if t not in args.tools.split(",")]
            m["earlier_pass_commit"] = f"{old['cerebronexus_commit']} ({old.get('cerebronexus_version')}): the rows of {', '.join(rest)}"
    open(p, "w", encoding="utf-8").write("key" + chr(9) + "value" + chr(10) + "".join(f"{k}{chr(9)}{v}{chr(10)}" for k, v in m.items()))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tiers", default="5000,10000,20000,50000,100000,1300000", help="cells; 1300000 is the full data set")
    ap.add_argument("--tools", default=",".join(TOOLS))
    ap.add_argument("--reps", type=int, default=3, help="pairs of starts per tool and tier")
    ap.add_argument("--genes", type=int, default=20, help="genes in the sweep (0: none)")
    ap.add_argument("--candidate", default="HEAD", help="CerebroNexus revision (default: HEAD of the checkout)")
    ap.add_argument("--cerebro-repo", default=os.path.normpath(os.path.join(HERE, "..", "..", "..", "CerebroNexus")))
    ap.add_argument("--resume", default=None, help="continue this run folder: finished tiers and tools are skipped")
    a = ap.parse_args()
    cnx = lib.install_cerebronexus(a.cerebro_repo, a.candidate)
    started = datetime.datetime.now().astimezone().isoformat(timespec="seconds")
    run = os.path.abspath(a.resume) if a.resume else os.path.join(HERE, "runs", f"{datetime.datetime.now():%Y%m%d-%H%M%S}_{cnx['sha'][:7]}")
    for d in ("logs", "screens", "cache", "art"):
        os.makedirs(os.path.join(run, d), exist_ok=True)
    env = lambda cache: lib.r_env(cnx["lib"], cache)
    genes = open(os.path.join(HERE, "data", "inputs", "sweep_genes.txt")).read().split()[:a.genes]
    for tier in map(int, a.tiers.split(",")):
        inp = os.path.join(HERE, "data", "inputs", f"e18_{tier}.h5ad")
        for tool in a.tools.split(","):
            if finished(run, tier, tool):
                continue
            drop(run, tier, tool); print(f"=== {tier} {LABEL[tool]}", flush=True)
            if tier >= FULL and tool in NO_MATRIX:
                add(run, "builds", tier=tier, tool=tool, status="skipped", note="the matrix does not fit a dgCMatrix (2^31-1 non-zeros)"); continue
            try:
                measure(run, tool, tier, inp, env, a.reps, genes)
            except Exception:
                print(traceback.format_exc(), flush=True)
            finally:
                lib.remove_tree(os.path.join(run, "cache")); os.makedirs(os.path.join(run, "cache"))
            summary(run)
    manifest(run, cnx, started, a); summary(run)
    print("run:", run)


if __name__ == "__main__":
    main()
