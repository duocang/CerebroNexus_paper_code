#!/bin/sh
## Full rerun on 001c4d4dd. A, C and D are the commands of the recorded run;
## B, E and F write the file names the recorded results carry (E and F
## unsuffixed). Install first:
##   scripts/install_cerebronexus.sh 001c4d4dd68a6fc5c2c958d7c0c2a49961671b95
set -u
cd "$(dirname "$0")/.."
S=001c4d4dd
export BV_COMMIT=001c4d4dd68a6fc5c2c958d7c0c2a49961671b95
export TMPDIR=${TMPDIR:-$PWD/data/tmp/}
mkdir -p "$TMPDIR" results/logs
BV_ENV_OUT=environment_$S.txt Rscript scripts/environment.R > /dev/null
A_OUT=A_malformed_inputs_$S.csv Rscript scripts/A_malformed_inputs.R > results/logs/A_malformed_inputs_$S.log 2>&1; echo A $?
B_OUT=B_end_to_end_$S.csv Rscript scripts/B_end_to_end.R > results/logs/B_end_to_end_$S.log 2>&1; echo B $?
D_DATA=D_$S D_CAPTURES=D_captures_$S D_OUT=D_spatial_transforms_$S.csv Rscript scripts/D_spatial_transforms.R synthetic > results/logs/D_spatial_transforms_$S.log 2>&1; echo D $?
D_DATA=D_$S D_CAPTURES=D_captures_$S D_OUT=D_arrow_$S.csv Rscript scripts/D_spatial_transforms.R arrow > results/logs/D_arrow_$S.log 2>&1; echo D $?
D_DATA=D_$S D_CAPTURES=D_captures_$S D_OUT=D_multisection_$S.csv Rscript scripts/D_spatial_transforms.R multisection > results/logs/D_multisection_$S.log 2>&1; echo D $?
C_DATA=C_$S C_OUT=C_publish_faults_$S.csv Rscript scripts/C_publish_faults.R > results/logs/C_publish_faults_$S.log 2>&1; echo C $?
Rscript scripts/E_security.R > results/logs/E_security.log 2>&1; echo E $?
rm -rf results/E_evidence_$S; mv results/E_evidence results/E_evidence_$S
Rscript scripts/F_selection.R > results/logs/F_selection.log 2>&1; echo F1/F2 $?
B_BACKEND=h5 B_OUT=F_hdf5_end_to_end.csv Rscript scripts/B_end_to_end.R > results/logs/F_hdf5_end_to_end.log 2>&1; echo Bh5 $?
Rscript scripts/F_hdf5.R > results/logs/F_hdf5.log 2>&1; echo F3 $?
C_BACKEND=h5 C_DATA=C_h5 C_OUT=F_publish_faults_h5.csv Rscript scripts/C_publish_faults.R > results/logs/F_publish_faults_h5.log 2>&1; echo Ch5 $?
