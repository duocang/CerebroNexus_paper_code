#!/bin/sh
## First run, on 84ff72b3 (unsuffixed results). Install first:
##   scripts/install_cerebronexus.sh 84ff72b3368eb206354204d6e4871ac3600f1253
set -u
cd "$(dirname "$0")/.."
export BV_COMMIT=84ff72b3368eb206354204d6e4871ac3600f1253
export TMPDIR=${TMPDIR:-$PWD/data/tmp/}
mkdir -p "$TMPDIR" results/logs
Rscript scripts/environment.R > /dev/null
Rscript scripts/A_malformed_inputs.R > results/logs/A_malformed_inputs.log 2>&1; echo A $?
Rscript scripts/B_end_to_end.R > results/logs/B_end_to_end.log 2>&1; echo B $?
Rscript scripts/C_publish_faults.R > results/logs/C_publish_faults.log 2>&1; echo C $?
Rscript scripts/D_spatial_transforms.R synthetic > results/logs/D_spatial_transforms.log 2>&1; echo D $?
D_OUT=D_arrow.csv Rscript scripts/D_spatial_transforms.R arrow > results/logs/D_arrow.log 2>&1; echo D $?
D_OUT=D_multisection.csv Rscript scripts/D_spatial_transforms.R multisection > results/logs/D_multisection.log 2>&1; echo D $?
