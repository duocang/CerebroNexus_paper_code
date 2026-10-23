"""Combine results/task1/*.json (one per run) into results/task1/task1_<tool>.json|csv and results/task1_summary.csv (PROTOCOL section 5).
Grades: auto / manual / absent / n/a (see PROTOCOL 5). The rules are written out here so every grade can be traced."""
import csv, glob, json, os

HERE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RAW = os.path.join(HERE, "results", "task1")
RES = os.path.join(HERE, "results")
BYTOOL = RAW


def L(x):
    return [] if x is None else (x if isinstance(x, list) else [x])


def load(pattern):
    return {os.path.basename(f)[:-5]: json.load(open(f, encoding="utf-8")) for f in sorted(glob.glob(os.path.join(RAW, pattern)))}


# what each dataset contains (from the files themselves)
HAS = {"I1": dict(embeddings=["X_pca", "X_tsne", "X_umap", "X_draw_graph_fr"], tcr=False, spatial=False, image=False),
       "I2": dict(embeddings=["X_umap"], tcr=True, spatial=False, image=False),
       "I3": dict(embeddings=["X_pca", "X_umap", "spatial"], tcr=False, spatial=True, image=True),
       "I4": dict(embeddings=["X_pca", "X_tsne", "X_umap", "X_draw_graph_fr"], tcr=False, spatial=False, image=False)}
GR = ["embedding", "clustering", "tcr_clonotype_view", "tcr_column", "spatial_coordinates", "tissue_image", "expression"]


def norm(s):
    return s.lower().replace("x_", "").replace("_", "").replace(" ", "")


def missing(ds, offered):
    off = {norm(o) for o in offered}
    return "|".join(e for e in HAS[ds]["embeddings"] if norm(e) not in off)


def grades(ds, emb, clustering, tcr_view, tcr_col, spatial, image, expression="auto"):
    h = HAS[ds]
    return dict(embedding=emb, clustering=clustering,
                tcr_clonotype_view=tcr_view if h["tcr"] else "n/a", tcr_column=tcr_col if h["tcr"] else "n/a",
                spatial_coordinates=spatial if h["spatial"] else "n/a", tissue_image=image if h["image"] else "n/a", expression=expression)


def err_grades():
    return {f"grade_{k}": ("error" if k in ("embedding", "clustering", "expression") else "n/a") for k in GR}


out, detail = {}, {}

# ---------------------------------------------------------------- CerebroNexus
cn = load("cerebronexus_*.json")
out["CerebroNexus"] = []
for ds in ["I1", "I2", "I3", "I4"]:
    key = "cerebronexus_I2_seurat" if ds == "I2" else f"cerebronexus_{ds}_h5ad"
    r = cn[key]
    d = dict(tool="CerebroNexus", dataset=ds,
             import_route=("convertH5adToCerebro(h5ad, groups=)" if ds != "I2" else "addImmuneRepertoire(from_metadata=TRUE) + exportFromSeurat(groups, nUMI, nGene)"),
             import_status=r["status"], error_message=r.get("error_message"), required_args=r["required_args"],
             default_route_failed=False, workaround_applied=False)
    if r["status"] == "ok":
        off = L(r["embeddings"])
        d.update(n_cells=r["n_cells"], n_genes=r["n_genes"], embeddings_offered="|".join(off), embeddings_missing=missing(ds, off),
                 annotations_offered="|".join(L(r["categorical_annotations"])), unique_cell_names_in_object=r["unique_cell_names"])
        g = grades(ds, "auto", "auto", "auto" if r.get("immune_repertoire_present") else "absent", "auto" if r.get("ctaa_column_in_metadata") else "absent",
                   "auto" if r.get("spatial_present") else "absent", "auto" if r.get("tissue_image_present") else "absent")
        d.update({f"grade_{k}": v for k, v in g.items()})
        d["notes"] = {"I1": "groups is required (omitting it errors); PCA is not offered as a projection; only the groups column given is a grouping variable",
                      "I2": "TCR needs the explicit addImmuneRepertoire() call (365 repertoire rows); via the h5ad route CTaa stays a metadata column but no repertoire is built (raw: cerebronexus_I2_h5ad)",
                      "I3": "spatial coordinates become a 'spatial' projection plus a Spatial data entry with the histology image; leiden is not a grouping variable (only groups=cluster)"}.get(ds, "")
        if ds == "I1":
            d["required_args_check"] = cn["cerebronexus_I1_h5ad-nogroups"]["error_message"]
    else:
        d.update(err_grades())
        if ds == "I4":
            d["i4_behaviour"] = "rejected"
            d["notes"] = "explicit refusal naming the cause; no file written"
    out["CerebroNexus"].append(d)
detail["CerebroNexus"] = cn


# ---------------------------------------------------------------- ShinyCell / iSEE
def rside(tool, prefix, heads, route, notes):
    raw = load(f"{prefix}_*_w?.json")
    ui = load(f"ui_{prefix}_*.json")
    res = []
    for ds in ["I1", "I2", "I3", "I4"]:
        hk = heads[ds]
        r = raw[f"{prefix}_{hk}"]
        same = [(k, v) for k, v in raw.items() if k.startswith(f"{prefix}_{ds}_")]
        fails = []
        for k, v in same:
            if v["status"] != "ok":
                msg = " ".join((v["error_message"] or "").split())
                fails.append(f"{k[len(prefix) + 1:]}: {msg}"[:260])
        d = dict(tool=tool, dataset=ds, import_route=route[ds], import_status=r["status"], error_message=r.get("error_message"),
                 required_args=r["required_args"], default_route_failed=bool(fails), default_route_errors=" || ".join(fails),
                 workaround_applied=bool(r.get("workaround")))
        off = L(r.get("embeddings"))
        d.update(n_cells=r.get("n_cells"), n_genes=r.get("n_genes"), unique_cell_names_in_object=r.get("unique_cell_names"))
        if prefix == "shinycell":
            d["in_app_cells"] = r.get("in_app_cells")
            d["in_app_unique_cell_names"] = r.get("in_app_unique_cell_names")
            d["annotations_offered"] = "|".join(L(r.get("in_app_grouping_variables")))
            d["in_app_metadata_columns"] = "|".join(L(r.get("in_app_metadata_columns")))
            d["in_app_dimension_columns"] = "|".join(L(r.get("in_app_dimension_columns")))
            ctaa_in = "CTaa" in L(r.get("in_app_metadata_columns"))
        else:
            d["annotations_offered"] = "|".join(L(r.get("categorical_annotations")))
            ctaa_in = bool(r.get("ctaa_column_in_metadata"))
        d["embeddings_offered"] = "|".join(off)
        d["embeddings_missing"] = missing(ds, off)
        u = ui.get(f"ui_{prefix}_{hk}")
        if u:
            d["ui_status"] = u.get("ui_status")
            d["ui_embedding_choices"] = "|".join(L(u.get("ui_embedding_choices")))
        g = grades(ds, "auto", "auto", "absent", "auto" if ctaa_in else "absent", "absent", "absent")
        d.update({f"grade_{k}": v for k, v in g.items()})
        d["notes"] = notes.get(ds, "")
        if ds == "I4":
            d["i4_behaviour"] = "silent" if (r["status"] == "ok" and r.get("unique_cell_names") is False) else "?"
        res.append(d)
    return res, raw


out["ShinyCell"], detail["ShinyCell"] = rside(
    "ShinyCell", "shinycell",
    {"I1": "I1_sce_rewritten_w1", "I2": "I2_seurat_orig_w0", "I3": "I3_sce_rewritten_w1", "I4": "I4_sce-dup_constructed_w1"},
    {"I1": "h5ad (rewritten) -> anndataR SCE -> createConfig -> makeShinyApp", "I2": "Seurat object -> createConfig -> makeShinyApp",
     "I3": "h5ad (rewritten) -> anndataR SCE -> createConfig -> makeShinyApp",
     "I4": "I1 SCE with the last ten names replaced by the first ten (built in R) -> createConfig -> makeShinyApp"},
    {"I1": "Default route failed twice: original file refused by anndataR (anndata<0.8); then the SCE with a LinearEmbeddingMatrix PCA failed in makeShinyApp. Works after plain-matrix reducedDims + default genes. Seurat route (object built by hand): 'argument is of length zero' without VariableFeatures, works after setting them (raw rows shinycell_I1_seurat_*).",
     "I2": "CTaa/CTgene/CTnt/CTstrict columns are not carried into the app (high-cardinality character columns dropped); only derived cloneSize/clonalFrequency/clonalProportion remain. No clonotype view.",
     "I3": "Coordinates appear only as a generic embedding pair spatial1/spatial2; no spatial view, no image. The UI plot is drawn (pale-yellow colouring by in_tissue misses the 1% ink rule; checked by screenshot).",
     "I4": "anndataR cannot read I4.h5ad (error at read, not in ShinyCell). With the same duplication built directly in R, ShinyCell builds (after the same LinearEmbeddingMatrix workaround as I1) and keeps the duplicated IDs silently."})
out["iSEE"], detail["iSEE"] = rside(
    "iSEE", "isee",
    {"I1": "I1_sce_rewritten_w0", "I2": "I2_sce_orig_w0", "I3": "I3_sce_rewritten_w0", "I4": "I4_sce-dup_constructed_w0"},
    {"I1": "h5ad (rewritten) -> anndataR SCE -> iSEE(sce)", "I2": "Seurat -> as.SingleCellExperiment -> iSEE(sce)",
     "I3": "h5ad (rewritten) -> anndataR SCE -> iSEE(sce)",
     "I4": "I1 SCE with the last ten names replaced by the first ten (built in R) -> iSEE(sce)"},
    {"I1": "Original file refused by anndataR (anndata<0.8): reader limit, not iSEE; works from the rewritten file (LinearEmbeddingMatrix PCA is accepted). First reducedDim in the UI is X_draw_graph_fr.",
     "I2": "CTaa is an ordinary colData column (usable in column data plots); no clonotype view.",
     "I3": "'spatial' is just another reducedDim (generic embedding); no spatial view or image.",
     "I4": "anndataR cannot read I4.h5ad (error at read). With the duplication built in R, iSEE builds and its app draws the plot; duplicated names are kept silently (no message)."})

# ---------------------------------------------------------------- cellxgene
cx = load("cellxgene_*.json")
out["cellxgene"] = []
for ds in ["I1", "I2", "I3", "I4"]:
    r = cx[f"cellxgene_{ds}"]
    d = dict(tool="cellxgene", dataset=ds, import_route=r["route"], import_status=r["status"], error_message=r.get("error_message"),
             required_args=r["required_args"], default_route_failed=False, workaround_applied=False)
    if r["status"] == "ok":
        off = r["embeddings"]
        d.update(n_cells=r["n_cells"], n_genes=r["n_genes"], embeddings_offered="|".join(off), embeddings_missing=missing(ds, off),
                 annotations_offered="|".join(r["categorical_annotations"]), unique_cell_names_in_object=r.get("unique_cell_names_in_file"))
        g = grades(ds, "auto", "auto", "absent", "auto" if r.get("ctaa_column_in_metadata") else "absent", "absent", "absent")
        d.update({f"grade_{k}": v for k, v in g.items()})
        d["notes"] = {"I3": "obsm['spatial'] is not offered as a layout (only X_-prefixed keys); no spatial view or image.",
                      "I2": "CTaa is an obs column; no clonotype view."}.get(ds, "")
    else:
        d["i4_behaviour"] = "rejected"
        d.update(err_grades())
        d["notes"] = "refuses at start-up with an explicit KeyError naming the cause ('Values in obs.index must be unique')"
    out["cellxgene"].append(d)
detail["cellxgene"] = cx

# ---------------------------------------------------------------- Vitessce
vt = load("vitessce_*.json")
out["Vitessce"] = []
for ds in ["I1", "I2", "I3", "I4"]:
    r = vt[f"vitessce_{ds}"]
    d = dict(tool="Vitessce", dataset=ds, import_route=r["route"], import_status=r["status"], error_message=r.get("error_message"),
             required_args="every component path written by hand: " + ", ".join(r.get("paths_written_by_hand", [])),
             default_route_failed=False, workaround_applied=False)
    if r["status"] == "ok":
        off = r["embeddings_offered_in_config"]
        d.update(n_cells=r["n_cells"], n_genes=r["n_genes"], embeddings_offered="|".join(off), embeddings_missing=missing(ds, off),
                 annotations_offered="|".join(r["categorical_annotations"]), unique_cell_names_in_object=r["unique_cell_names"],
                 ui_text=r["page_text"][:120].replace("\n", " | "))
        g = grades(ds, "manual", "manual", "absent", "manual", "manual", "absent", "manual")
        d.update({f"grade_{k}": v for k, v in g.items()})
        d["notes"] = {"I2": "CTaa added as a cell-set path by hand; no clonotype view.",
                      "I3": (r.get("notes", "") + " The tissue image in uns['spatial'] is not read (Vitessce needs a separate image file).").strip(),
                      "I4": "Zarr is written and the page shows 2,638 cells and 1,838 genes; duplicated names are kept silently, no message."}.get(ds, "")
        if ds == "I4":
            d["i4_behaviour"] = "silent"
    out["Vitessce"].append(d)
detail["Vitessce"] = vt

# ---------------------------------------------------------------- write
allrows = []


def write_csv(path, rows):
    keys = []
    for r in rows:
        for k in r:
            if k not in keys:
                keys.append(k)
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=keys)
        w.writeheader()
        w.writerows(rows)


for tool, rs in out.items():
    json.dump(dict(headline=rs, raw=detail[tool]), open(os.path.join(BYTOOL, f"task1_{tool.lower()}.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    write_csv(os.path.join(BYTOOL, f"task1_{tool.lower()}.csv"), rs)
    allrows += rs
write_csv(os.path.join(RES, "task1_summary.csv"), allrows)
print("rows", len(allrows))
for r in allrows:
    print(r["tool"], r["dataset"], r["import_status"], r.get("grade_embedding"), r.get("grade_clustering"), r.get("grade_tcr_clonotype_view"),
          r.get("grade_tcr_column"), r.get("grade_spatial_coordinates"), r.get("grade_tissue_image"), r.get("i4_behaviour"), "| default failed:", r["default_route_failed"])
