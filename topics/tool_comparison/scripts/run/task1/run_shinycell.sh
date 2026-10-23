#!/usr/bin/env bash
# All ShinyCell Task 1 rows (dataset route input workaround)
cd "$(dirname "$0")/../.."
while read -r d r k w; do
  scripts/run/run_r.sh scripts/run/task1/shinycell.R $d $r $k $w results/task1/shinycell_${d}_${r}_${k}_w${w}.json > results/evidence/task1/shinycell_${d}_${r}_${k}_w${w}.log 2>&1
  tail -1 results/evidence/task1/shinycell_${d}_${r}_${k}_w${w}.log | cut -c1-120
done <<'ROWS'
I1 sce orig 0
I1 sce rewritten 0
I1 sce rewritten 1
I1 seurat rewritten 0
I1 seurat rewritten 1
I2 seurat orig 0
I3 sce orig 0
I3 sce rewritten 0
I3 sce rewritten 1
I4 sce orig 0
I4 sce-dup constructed 0
I4 sce-dup constructed 1
ROWS
