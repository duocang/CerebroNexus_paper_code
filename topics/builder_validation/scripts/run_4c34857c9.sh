#!/bin/sh
## Rerun of D and the PBMC SCE row of B after the alignment and QC-column
## fixes, on 4c34857c9. Install first:
##   scripts/install_cerebronexus.sh 4c34857c9
set -u
cd "$(dirname "$0")/.."
S=4c34857c9
export BV_COMMIT=$S
export TMPDIR=${TMPDIR:-$PWD/data/tmp/}
mkdir -p "$TMPDIR" results/logs
BV_ENV_OUT=environment_$S.txt Rscript scripts/environment.R > /dev/null
B_OUT=B_end_to_end_$S.csv Rscript scripts/B_end_to_end.R pbmc_sce > results/logs/B_end_to_end_$S.log 2>&1; echo B $?
for part in synthetic arrow multisection; do
  case $part in synthetic) out=D_spatial_transforms_$S.csv ;; arrow) out=D_arrow_$S.csv ;; *) out=D_multisection_$S.csv ;; esac
  D_DATA=D_$S D_CAPTURES=D_captures_$S D_OUT=$out Rscript scripts/D_spatial_transforms.R $part > results/logs/${out%.csv}.log 2>&1; echo D $part $?
done
