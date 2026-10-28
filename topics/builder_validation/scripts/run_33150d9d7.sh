#!/bin/sh
## Rerun after the login and HDF5-sidecar fixes, on 33150d9d7, with the
## parameters of the recorded run (subsets of B, C and D). Install first:
##   scripts/install_cerebronexus.sh 33150d9d7a957607ccf43a0296903e073be2408f
set -u
cd "$(dirname "$0")/.."
S=33150d9d7
export BV_COMMIT=33150d9d7a957607ccf43a0296903e073be2408f
export TMPDIR=${TMPDIR:-$PWD/data/tmp/}
mkdir -p "$TMPDIR" results/logs
BV_ENV_OUT=environment_$S.txt Rscript scripts/environment.R > /dev/null
E_OUT=E_security_$S.csv Rscript scripts/E_security.R > results/logs/E_security_$S.log 2>&1; echo E $?
rm -rf results/E_evidence_$S; mv results/E_evidence results/E_evidence_$S
B_BACKEND=h5 B_OUT=F_hdf5_end_to_end_$S.csv Rscript scripts/B_end_to_end.R > results/logs/F_hdf5_end_to_end_$S.log 2>&1; echo Bh5 $?
## F_hdf5.R writes fixed names; keep them per revision and restore the 001c4d4dd files
F_H5_CHECKSUM=1 Rscript scripts/F_hdf5.R > results/logs/F_hdf5_$S.log 2>&1; echo F3 $?
mv results/F_hdf5_storage.csv results/F_hdf5_storage_$S.csv
mv results/F_hdf5_faults.csv results/F_hdf5_faults_$S.csv
git checkout -- results/F_hdf5_storage.csv results/F_hdf5_faults.csv
C_BACKEND=h5 C_DATA=C_h5_$S C_OUT=F_publish_faults_h5_$S.csv Rscript scripts/C_publish_faults.R > results/logs/F_publish_faults_h5_$S.log 2>&1; echo Ch5 $?
A_OUT=A_malformed_inputs_$S.csv Rscript scripts/A_malformed_inputs.R > results/logs/A_malformed_inputs_$S.log 2>&1; echo A $?
B_OUT=B_end_to_end_$S.csv Rscript scripts/B_end_to_end.R visium pbmc_seurat pbmc3k_h5ad > results/logs/B_end_to_end_$S.log 2>&1; echo B $?
C_DATA=C_$S C_OUT=C_publish_faults_$S.csv Rscript scripts/C_publish_faults.R C00 C04 K3 K5 T1 T4 > results/logs/C_publish_faults_$S.log 2>&1; echo C $?
D_DATA=D_$S D_CAPTURES=D_captures_$S D_OUT=D_spatial_transforms_$S.csv D_TRANSFORMS=identity,rotate_90,rotate_90_flip_x,combined Rscript scripts/D_spatial_transforms.R synthetic > results/logs/D_spatial_transforms_$S.log 2>&1; echo D $?
## Display captures of Supplementary Figure S11b (not measured)
BV_ENV_OUT=environment_figS11.txt Rscript scripts/environment.R > /dev/null
D_ARROW_FILL=1 D_POINT_SIZE=18 D_DATA=D_figS11_fill D_CAPTURES=D_captures_figS11_fill D_OUT=D_arrow_figS11_fill.csv \
  D_ARROW=identity,rotate_90,flip_x,scale_0.6 Rscript scripts/D_spatial_transforms.R arrow > results/logs/D_arrow_figS11_fill.log 2>&1; echo S11b $?
rm -f results/D_arrow_figS11_fill.csv
