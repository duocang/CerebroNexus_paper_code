#!/usr/bin/env bash
# Task 1 for all five tools (PROTOCOL 6), then the summary. Not timed. Run from anywhere; env/py is the Python.
cd "$(dirname "$0")/../../.."
PY=env/py/Scripts/python.exe
mkdir -p results/task1 results/evidence/task1
echo "== CerebroNexus"
while read -r d r; do
  scripts/run/run_r.sh scripts/run/task1/cerebronexus.R $d $r results/task1/cerebronexus_${d}_${r}.json > results/evidence/task1/cerebronexus_${d}_${r}.log 2>&1
  tail -1 results/evidence/task1/cerebronexus_${d}_${r}.log | cut -c1-140
done <<'ROWS'
I1 h5ad
I1 h5ad-nogroups
I2 h5ad
I2 seurat
I3 h5ad
I4 h5ad
ROWS
echo "== ShinyCell"; bash scripts/run/task1/run_shinycell.sh
echo "== iSEE"; bash scripts/run/task1/run_isee.sh
echo "== cellxgene"; $PY scripts/run/task1/t1_cellxgene.py results/task1 2>&1 | tail -4 | cut -c1-200
echo "== Vitessce"; $PY scripts/run/task1/t1_vitessce.py results/task1 2>&1 | tail -4 | cut -c1-200
echo "== UI checks"
while read -r t d r k w; do
  if [ "$t" = shinycell ]; then rm -rf data/builds/t1/ui_${t}_${d}_${r}_${k}_w${w}; cp -r data/builds/t1/sc_${d}_${r}_${k}_w${w} data/builds/t1/ui_${t}_${d}_${r}_${k}_w${w}; fi
  $PY scripts/run/task1/ui_check.py $t $d $r $k $w results/task1/ui_${t}_${d}_${r}_${k}_w${w}.json 2>&1 | tail -1 | cut -c1-200
done <<'ROWS'
isee I1 sce rewritten 0
isee I1 sce rewritten 1
isee I2 sce orig 0
isee I3 sce rewritten 0
isee I3 sce rewritten 1
isee I4 sce-dup constructed 0
shinycell I1 sce rewritten 1
shinycell I1 seurat rewritten 1
shinycell I2 seurat orig 0
shinycell I3 sce rewritten 1
shinycell I4 sce-dup constructed 1
ROWS
echo "== summary"; $PY scripts/report/aggregate_task1.py 2>&1 | tail -5
echo "TASK1 DONE"
