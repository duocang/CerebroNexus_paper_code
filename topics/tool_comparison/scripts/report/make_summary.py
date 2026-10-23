"""results/SUMMARY.md: one page over Task 1, Task 2 and Task 3 (built from the CSVs)."""
import csv, os
HERE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))); R = os.path.join(HERE, "results")
rd = lambda f: list(csv.DictReader(open(os.path.join(R, f), encoding="utf-8")))
out = ["# Comparative evaluation: summary of results", "", "Host: native Windows 11, i9-12900K (24 threads), 127.7 GB RAM, R 4.5.0, Python 3.11.15, Chrome 155 (see `environment.json`). "
       "Protocol: `../PROTOCOL.md` (frozen text, deviations D1-D15 at its end). Raw rows: `task1/`, `task2/`, `task3/`.", ""]
# ---- Task 1
t1 = rd("task1_summary.csv")
out += ["## Task 1: import and capability recognition", "", "Grades: auto = present with the documented default call and required arguments; manual = needs extra configuration or code; absent; n/a = dataset lacks it. "
        "I4 = duplicated cell names.", "", "| Tool | Dataset | Import | Embeddings | Clustering | TCR view | TCR column | Spatial | Image | I4 behaviour | Default route failed |", "|---|---|---|---|---|---|---|---|---|---|---|"]
for r in t1:
    out.append(f"| {r['tool']} | {r['dataset']} | {r['import_status']} | {r.get('grade_embedding','')} | {r.get('grade_clustering','')} | {r.get('grade_tcr_clonotype_view','')} | "
               f"{r.get('grade_tcr_column','')} | {r.get('grade_spatial_coordinates','')} | {r.get('grade_tissue_image','')} | {r.get('i4_behaviour','') if r['dataset']=='I4' else ''} | {r['default_route_failed']} |")
out += ["", "Details, errors and notes per row: `task1_<tool>.csv|json`.", ""]
# ---- Task 2
t2 = rd("task2_summary.csv")
out += ["## Task 2: selection retrieval (Jaccard index with the truth set)", "", "S1 = I1 cells with louvain == 'B cells' (342); S2 = I2 cells with the most frequent CTaa (11). Three runs per row; all identical.", "",
        "| Tool | Set | Route | Result | Jaccard | Exported | Precision | Recall |", "|---|---|---|---|---|---|---|---|"]
for r in t2:
    j = r["jaccard_median"] or "-"
    out.append(f"| {r['tool']} | {r['set']} | {r['route']} | {r['result']} | {j} | {r['n_exported_median'] or '-'} | {r['precision_median'] or '-'} | {r['recall_median'] or '-'} |")
out += ["", "Notes per row: `task2_summary.csv`.", ""]
# ---- Task 3
out += ["## Task 3: scale (E18 first 10,000 / 100,000 / 500,000 cells)", "", open(os.path.join(R, "summary_task3.md"), encoding="utf-8").read().split("\n", 2)[2], ""]
open(os.path.join(R, "SUMMARY.md"), "w", encoding="utf-8").write("\n".join(out))
print("written", len(out), "lines")
