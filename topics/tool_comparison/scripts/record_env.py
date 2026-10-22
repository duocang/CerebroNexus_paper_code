"""Write results/environment.json and results/inputs.csv (run with env/py)."""
import csv, hashlib, json, os, platform, subprocess, sys, datetime
from importlib import metadata
import psutil

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
R_DIR = r"C:\Program Files\R\R-4.5.0\bin\Rscript.exe"

def ps(cmd):
    return subprocess.run(["powershell", "-NoProfile", "-Command", "[Console]::OutputEncoding=[Text.Encoding]::UTF8; " + cmd], capture_output=True, text=True, encoding="utf-8", errors="replace").stdout.strip()

def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1 << 24), b""):
            h.update(b)
    return h.hexdigest()

chrome = ps(r"(Get-Item 'C:\Program Files\Google\Chrome\Application\chrome.exe').VersionInfo.ProductVersion")
r_env = dict(os.environ, LANGUAGE="en", LANG="en_US.UTF-8", R_LIBS=os.path.join(HERE, "env", "rlib"), R_LIBS_USER=os.path.join(HERE, "env", "rlib"), R_LIBS_SITE="")
rv = subprocess.run([R_DIR, "--vanilla", os.path.join(HERE, "scripts", "r_versions.R")], capture_output=True, text=True, env=r_env).stdout
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
    "node": {"node": subprocess.run(["node", "--version"], capture_output=True, text=True).stdout.strip(),
             "packages": {n: json.load(open(os.path.join(HERE, "env", "js", "node_modules", n, "package.json")))["version"]
                          for n in ["vitessce", "react", "react-dom", "esbuild"]}},
    "tools": {
        "CerebroNexus": {"version": rpk.get("CerebroNexus"), "commit": "27ac995e983a3ff1c79a2d051c9a4374dde37ec6"},
        "ShinyCell": {"version": rpk.get("ShinyCell"), "commit": "5c61db78cdd624636e161406d5d42aeb2c0f1205"},
        "iSEE": {"version": rpk.get("iSEE"), "source": "Bioconductor " + ("3.22")},
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
    p = os.path.join(HERE, "data", name)
    rows.append({"file": name, "url": url, "bytes": os.path.getsize(p), "sha256": sha256(p)})
with open(os.path.join(HERE, "results", "inputs.csv"), "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=["file", "url", "bytes", "sha256"]); w.writeheader(); w.writerows(rows)
print(json.dumps(env["host"], indent=1)); print(rows)
