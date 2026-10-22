#!/usr/bin/env bash
# Run Rscript in the isolated comparison environment (native Windows, English locale).
# Usage: scripts/run_r.sh <script.R> [args...]
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export LANGUAGE=en LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export R_LIBS="$(cygpath -w "$HERE/env/rlib")" R_LIBS_USER="$(cygpath -w "$HERE/env/rlib")" R_LIBS_SITE=""
export R_PROFILE_USER="" R_ENVIRON_USER=""
exec "/c/Program Files/R/R-4.5.0/bin/Rscript.exe" --vanilla "$@"
