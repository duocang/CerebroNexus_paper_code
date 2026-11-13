#!/bin/sh
## Run experiments A-F on the revision in topics/cerebronexus.pin.
##
##   scripts/run_pin.sh [A B C D E F ...]     default: all, in this order
##
## Nothing here names a commit or a version: the revision is read from the pin,
## installed with scripts/install_cerebronexus.sh when env/installed.txt does
## not hold it (CN_REPO=<local clone> when the pinned commit is not on a
## remote), and every result file carries the first 9 characters of the commit
## as its suffix. common.R stops a run when the installed commit is not the
## pin. Result files of earlier revisions are not touched.
##
## Inputs (data/inputs/) are made by `Rscript scripts/00_prepare_inputs.R`
## (README, "Running"); R_LIBS / BV_PYTHON / TMPDIR are passed through.
set -u
cd "$(dirname "$0")/.."
pin() { sed -n "s/^$1=//p" ../cerebronexus.pin | head -n 1 | tr -d '\r'; }
COMMIT=$(pin commit)
S=$(printf '%s' "$COMMIT" | cut -c1-9)
## Chrome (chromote) cannot start when TMPDIR is a long path (its socket path is limited), so the default
## data/tmp/ is used only when it is short; otherwise /tmp/bv_tmp. Set TMPDIR to choose.
if [ -z "${TMPDIR:-}" ]; then
  if [ "$(printf '%s' "$PWD/data/tmp/" | wc -c)" -le 60 ]; then TMPDIR=$PWD/data/tmp/; else TMPDIR=/tmp/bv_tmp; fi
fi
export TMPDIR
mkdir -p "$TMPDIR" results/logs

installed=$(sed -n 's/^commit=//p' env/installed.txt 2>/dev/null | head -n 1 | tr -d '\r')
if [ "$installed" != "$COMMIT" ]; then
  scripts/install_cerebronexus.sh || { echo "cannot install the pinned commit $COMMIT" >&2; exit 1; }
fi

want() { [ $# -eq 0 ] && return 0; for a in $WANT; do [ "$a" = "$1" ] && return 0; done; return 1; }
WANT=${*:-A B C D E F}
run() { # run <log name> <command...>; the log carries the suffix
  name=$1; shift
  "$@" > "results/logs/${name}_$S.log" 2>&1; echo "$name exit $?"
}

run environment Rscript scripts/environment.R
want A && run A_malformed_inputs Rscript scripts/A_malformed_inputs.R
want B && run B_end_to_end Rscript scripts/B_end_to_end.R
want C && run C_publish_faults Rscript scripts/C_publish_faults.R
if want D; then
  run D_spatial_transforms_synthetic env D_OUT="D_spatial_transforms_$S.csv" Rscript scripts/D_spatial_transforms.R synthetic
  run D_visium_crop env D_OUT="D_visium_crop_$S.csv" Rscript scripts/D_spatial_transforms.R crop
  run D_multisection env D_OUT="D_multisection_$S.csv" Rscript scripts/D_spatial_transforms.R multisection
fi
want E && run E_security Rscript scripts/E_security.R
if want F; then
  run F_selection Rscript scripts/F_selection.R
  run F_hdf5_end_to_end env B_BACKEND=h5 Rscript scripts/B_end_to_end.R
  run F_hdf5 Rscript scripts/F_hdf5.R
  run F_publish_faults_h5 env C_BACKEND=h5 C_DATA="C_h5_$S" Rscript scripts/C_publish_faults.R
fi
