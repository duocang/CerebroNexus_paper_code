"""Write results/environment.json and results/inputs.csv (run with env/py)."""
import csv, hashlib, json, os, platform, subprocess, sys, datetime
from importlib import metadata
import psutil

HERE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
R_DIR = "C:/R/R-4.6.1/bin/Rscript.exe"

def ps(cmd):
    return subprocess.run(["powershell", "-NoProfile", "-Command", "[Console]::OutputEncoding=[Text.Encoding]::UTF8; " + cmd], capture_output=True, text=True, encoding="utf-8", errors="replace").stdout.strip()

def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1 << 24), b""):
            h.update(b)
    return h.hexdigest()

def gpu():
    smi = subprocess.run(["nvidia-smi", "--query-gpu=name,driver_version,memory.total", "--format=csv,noheader"], capture_output=True, text=True).stdout.strip()
    from playwright.sync_api import sync_playwright
    with sync_playwright() as pw:
        b = pw.chromium.launch(channel="chrome", headless=True); pg = b.new_page(); pg.set_content("<canvas id=c></canvas>")
        r = pg.evaluate("""()=>{const c=document.getElementById('c');const gl=c.getContext('webgl2')||c.getContext('webgl');if(!gl)return null;const e=gl.getExtension('WEBGL_debug_renderer_info');return e?gl.getParameter(e.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER)}""")
        ver = b.version; b.close()
    return {"nvidia_smi": smi, "headless_chrome_version": ver, "webgl_unmasked_renderer": r}

chrome = ps(r"(Get-Item 'C:\Program Files\Google\Chrome\Application\chrome.exe').VersionInfo.ProductVersion")
r_env = dict(os.environ, LANGUAGE="en", LANG="en_US.UTF-8", R_LIBS=os.path.join(HERE, "env", "rlib"), R_LIBS_USER=os.path.join(HERE, "env", "rlib"), R_LIBS_SITE="")
rv = subprocess.run([R_DIR, "--vanilla", os.path.join(HERE, "scripts", "setup", "r_versions.R")], capture_output=True, text=True, env=r_env).stdout
iso = subprocess.run([R_DIR, "--vanilla", os.path.join(HERE, "scripts", "setup", "r_isolation.R")], capture_output=True, text=True, env=r_env).stdout
iso_line = [l for l in iso.splitlines() if l.startswith("ISO")]
iso_p = iso_line[0].split() if iso_line else ["ISO", "?", "?", "BIOC", "?"]
bioc = iso_p[4]
rpk = {}
for line in rv.splitlines():
    p = line.split()
    if len(p) == 3 and p[2] in ("TRUE", "FALSE"):
        rpk[p[0]] = p[1]
py_pk = {d: metadata.version(d) for d in ["cellxgene", "vitessce", "anndata", "scanpy", "numpy", "pandas", "scipy", "zarr", "h5py", "numba", "umap-learn", "scikit-learn", "playwright", "psutil", "requests", "flask", "werkzeug"]}
env = {
    "recorded_at": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
    "host": {
        "cpu": ps("(Get-CimInstance Win32_Processor).Name"),
        "physical_cores": psutil.cpu_count(logical=False), "logical_cores": psutil.cpu_count(logical=True),
        "ram_gb": round(psutil.virtual_memory().total / 2**30, 1),
        "os": ps("(Get-CimInstance Win32_OperatingSystem).Caption") + " " + platform.version(),
        "power_plan": subprocess.run(["powercfg", "/getactivescheme"], capture_output=True).stdout.decode("utf-8", errors="replace").strip(),
        "disk_free_gb": round(psutil.disk_usage(HERE).free / 2**30, 1),
        "wsl": False,
    },
    "r": {"version": ps("& '%s' --version 2>&1 | Select-Object -First 1" % R_DIR), "packages": rpk},
    "python": {"version": sys.version.split()[0], "executable": sys.executable, "packages": py_pk},
    "chrome": chrome,
    "gpu": gpu(),
    "r_isolation_check": {"loaded_namespaces": iso_p[1], "outside_env_rlib": iso_p[2], "note": "R 4.6.1 system library holds other packages and stays on the library path; every loaded non-base namespace must come from env/rlib"},
    "node": {"node": subprocess.run(["node", "--version"], capture_output=True, text=True).stdout.strip(),
             "packages": {n: json.load(open(os.path.join(HERE, "env", "js", "node_modules", n, "package.json")))["version"]
                          for n in ["vitessce", "react", "react-dom", "esbuild"]}},
    "tools": {
        "CerebroNexus": {"version": rpk.get("CerebroNexus"), "branch": "tmp/应急 (with the H5 sidecar and export optimisations, compiled code)", "commit": "f86667ae9",
                         "source_tarball": "env/src/CerebroNexus-tmp-emergency-f86667ae.tar.gz", "tarball_sha256": sha256(os.path.join(HERE, "env", "src", "CerebroNexus-tmp-emergency-f86667ae.tar.gz"))},
        "ShinyCell": {"version": rpk.get("ShinyCell"), "commit": "5c61db78cdd624636e161406d5d42aeb2c0f1205"},
        "iSEE": {"version": rpk.get("iSEE"), "source": "Bioconductor " + bioc},
        "cellxgene": {"version": py_pk["cellxgene"]},
        "Vitessce": {"python": py_pk["vitessce"], "js": "vitessce@3.9.9"},
    },
}
os.makedirs(os.path.join(HERE, "results"), exist_ok=True)
with open(os.path.join(HERE, "results", "environment.json"), "w", encoding="utf-8") as f:
    json.dump(env, f, indent=2, ensure_ascii=False)

rows = []
urls = {
    "pbmc3k.h5ad": "https://raw.githubusercontent.com/chanzuckerberg/cellxgene/main/example-dataset/pbmc3k.h5ad",
    "visium_hne_adata.h5ad": "https://ndownloader.figshare.com/files/26098397",
    "1M_neurons_filtered_gene_bc_matrices_h5.h5": "https://cf.10xgenomics.com/samples/cell-exp/1.3.0/1M_neurons/1M_neurons_filtered_gene_bc_matrices_h5.h5",
}
for name, url in urls.items():
    p = os.path.join(HERE, "data", "raw", name)
    rows.append({"file": name, "url": url, "bytes": os.path.getsize(p), "sha256": sha256(p)})
with open(os.path.join(HERE, "results", "inputs.csv"), "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=["file", "url", "bytes", "sha256"]); w.writeheader(); w.writerows(rows)
print(json.dumps(env["host"], indent=1)); print(rows)
