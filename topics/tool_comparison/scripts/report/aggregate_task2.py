"""Combine results/task2/*.json (one per run) into results/task2/task2_<tool>.csv and results/task2_summary.csv (PROTOCOL 6)."""
import csv, glob, json, os, statistics as stat
HERE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RES = os.path.join(HERE, "results")
BYTOOL = os.path.join(HERE, "results", "task2")
raw = []
for f in sorted(glob.glob(os.path.join(HERE, "results", "task2", "*.json"))):
    raw.append(json.load(open(f, encoding="utf-8")))
# routes with nothing to run, recorded from the explorations (see the notes)
extra = []
for sname, label in (("S1", "louvain == 'B cells'"), ("S2", None)):
    pass
CN_NOTE = ("legend click only toggles the visibility of a group; no selection by attribute value exists in the Projection tab, so no cohort and no table of selected cells "
           "is produced (evidence: results/evidence/task2/cerebronexus_attribute_legend_click.png)")
sets = {r["set"]: r["set_definition"] for r in raw if r.get("set_definition")}
# The legend-only 'route not found' row is added only for a set without CerebroNexus attribute rows (rows through the Group filters replace it, Deviations D14)
for s in ("S1", "S2"):
    if not any(r["tool"] == "CerebroNexus" and r["set"] == s and (r.get("route") or "").startswith("attribute") for r in raw):
        extra.append(dict(tool="CerebroNexus", set=s, set_definition=sets.get(s), route="attribute (legend / group filter)", status="route_not_found", repeat="n/a",
                          export_route="n/a", jaccard=None, note=CN_NOTE))
rows = raw + extra
def note(r):
    n = r.get("note", "") or ""
    if r["tool"] == "CerebroNexus" and r.get("export_route", "").startswith("Table"):
        n = "export covers the displayed page only (max 1,000 rows per page); page length was set to 1,000 before Download"
    if r["tool"] == "CerebroNexus" and (r.get("route") or "").startswith("attribute (group filter"):
        if r["status"] == "route not found":
            n = ("Group filters offer only " + ", ".join(r.get("group_filters_offered", [])) + "; CTaa is not a registered grouping variable in the I2 CRB (groups = seurat_clusters at export), "
                 "and the CRB was not rebuilt for this run (it would change the Task 1 import route); evidence: results/evidence/task2/cerebronexus_S2_attribute_*_groupfilters.png")
        else:
            n = ("the selection is made by the Group filter (only '" + ", ".join(r.get("group_filter_values_set", [])) + "' kept; cells removed by a filter are not selectable) and the lasso only encloses "
                 "the kept cells; export covers the displayed page only (page length 1,000)")
    if r["tool"] == "iSEE" and (r.get("route") or "").startswith("region (lasso") and r.get("set") == "S2":
        n = "lasso did not close for this small polygon (iSEE closes on a click near the first waypoint), so no selection was formed and the table exported all 500 cells; see results/evidence/task2/isee_S2_region_*_selection.png"
    if r["tool"] == "iSEE" and (r.get("route") or "").startswith("attribute"):
        n = "the table column filter is applied in the UI (342 / 11 rows shown) but 'Download panel output' exports the unfiltered table"
    if r["tool"] == "iSEE" and (r.get("route") or "").startswith("region (box"):
        n = "plots in iSEE offer a box brush and a Shift+click lasso; the box row is an extra route"
    if r["tool"] == "ShinyCell":
        n = "no cell-ID export route: " + r.get("route_found", "")
    if r["tool"] == "cellxgene" and r["route"].startswith("region"):
        n = "annotation CSV written by the server after 'Create new category' + 'Add label & assign'; launched with --user-generated-data-dir (D8)"
    if r["tool"] == "Vitessce" and r["route"].startswith("attribute"):
        n = "set exported with the three-dot menu of the set ('Export set (to JSON file)')"
    return n
out = []
for r in rows:
    out.append(dict(tool=r["tool"], set=r["set"], set_definition=r.get("set_definition"), route=r.get("route") or "none available (region or attribute)", repeat=r.get("repeat"), status=r["status"],
                    export_route=r.get("export_route"), n_truth=r.get("n_truth"), n_exported=r.get("n_exported"), n_intersection=r.get("n_intersection"),
                    jaccard=r.get("jaccard"), precision=r.get("precision"), recall=r.get("recall"),
                    calibration_quality=(r.get("calibration") or {}).get("quality"), margin_px=r.get("margin_px"), ui_selected_text=r.get("ui_selected_text"),
                    route_steps=" > ".join(r.get("route_steps", [])) if r.get("route_steps") else "", export_file=r.get("export_file"), error=r.get("error"), note=note(r)))
def write(path, rows_):
    keys = []
    for x in rows_:
        for k in x:
            if k not in keys: keys.append(k)
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=keys); w.writeheader(); w.writerows(rows_)
for tool in sorted({o["tool"] for o in out}):
    write(os.path.join(BYTOOL, f"task2_{tool.lower()}.csv"), [o for o in out if o["tool"] == tool])
summ = []
for key in sorted({(o["tool"], o["set"], o["route"]) for o in out}):
    g = [o for o in out if (o["tool"], o["set"], o["route"]) == key]
    ok = [o for o in g if o["status"] == "ok" and o["jaccard"] is not None]
    js = [float(o["jaccard"]) for o in ok]
    first = g[0]
    summ.append(dict(tool=key[0], set=key[1], route=key[2], runs=len([o for o in g if o["repeat"] != "n/a"]), runs_ok=len(ok),
                     result=("no export route" if first["status"] in ("no export route",) else ("route not found" if first["status"] == "route_not_found" else ("ok" if ok else first["status"]))),
                     jaccard_median=(round(stat.median(js), 4) if js else None), jaccard_min=(round(min(js), 4) if js else None), jaccard_max=(round(max(js), 4) if js else None),
                     n_truth=first.get("n_truth"), n_exported_median=(stat.median([o["n_exported"] for o in ok]) if ok else None),
                     precision_median=(round(stat.median([float(o["precision"]) for o in ok]), 4) if ok else None), recall_median=(round(stat.median([float(o["recall"]) for o in ok]), 4) if ok else None),
                     export_route=first["export_route"], note=first["note"]))
write(os.path.join(RES, "task2_summary.csv"), summ)
for s in summ:
    print(s["tool"], s["set"], s["route"], s["result"], s["jaccard_median"], s["n_exported_median"], s["runs_ok"], "/", s["runs"])
