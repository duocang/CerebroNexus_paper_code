#!/usr/bin/env bash
# Task 2 for all five tools (PROTOCOL 7): three runs per route, then the summary. Not timed. Needs the Task 1 artifacts (run task1/run_all.sh first).
cd "$(dirname "$0")/../../.."
PY=env/py/Scripts/python.exe
mkdir -p results/task2 results/evidence/task2
for s in S1 S2; do
  for r in region attribute; do echo "== CerebroNexus $s $r"; $PY scripts/run/task2/t2_cerebronexus.py $s 3 $r 2>&1 | tail -3 | cut -c1-220; done
  for r in region attribute; do echo "== cellxgene $s $r"; $PY scripts/run/task2/t2_cellxgene.py $s $r 3 2>&1 | tail -3 | cut -c1-220; done
  for r in region region-box attribute; do echo "== iSEE $s $r"; $PY scripts/run/task2/t2_isee.py $s $r 3 2>&1 | tail -3 | cut -c1-220; done
  for r in region attribute; do echo "== Vitessce $s $r"; $PY scripts/run/task2/t2_vitessce.py $s $r 3 2>&1 | tail -3 | cut -c1-220; done
done
echo "== ShinyCell"; $PY scripts/run/task2/t2_shinycell.py 2>&1 | tail -3 | cut -c1-220
echo "== summary"; $PY scripts/report/aggregate_task2.py 2>&1 | tail -5
echo "TASK2 DONE"
