#!/usr/bin/env bash
# Viewer performance standard (STANDARD.md): l0/l1/l2/track on Linux, WSL or Windows (Git Bash); gpu on Windows.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# Windows R needs a Windows path (Git Bash gives /c/...).
if command -v cygpath >/dev/null 2>&1; then here="$(cygpath -m "$here")"; fi
action="${1:-help}"
if (( $# )); then shift; fi
case "$action" in
  l0|l1|l2) exec Rscript "$here/standard/run.R" --tier "$action" "$@" ;;
  track) exec Rscript "$here/standard/run.R" --tier l1 --track --record "$@" ;;
  gpu) exec Rscript "$here/standard/gpu/run.R" "$@" ;;
  standard-tests) exec Rscript -e 'testthat::test_file("'"$here"'/tests/test-standard.R", reporter = "summary", stop_on_failure = TRUE)' ;;
  -h|--help|help)
    cat <<'HELP'
Usage: bash topics/viewer_performance/run.sh COMMAND [OPTIONS]
  l0|l1|l2 --candidate REF [--baseline REF|auto] [--record]
                           Measure under the performance standard (STANDARD.md)
  l0|l1|l2 --candidate REF --solo [--rounds N] [--record]
                           Measure one revision only and record its times (no baseline, no verdict)
  l0|l1|l2 ... --pages a,b  Only these pages and actions (a check while working on them; never recorded)
  track [--cerebro-repo DIR]
                           L1 run of origin/master if it changed since the last recorded L1 run
  gpu --candidate REF --baseline REF [--record]
                           Point renderer on the GPU (Windows; reported, not judged)
  standard-tests           Unit tests of the standard's verdict logic
Large datasets for l0|l1|l2|track (each optional; pages without one run on demo data):
  --mouse1m CRB  --ren CRB  --cosmx CRB
Run from this repository with CerebroNexus cloned beside it (or --cerebro-repo DIR); see README.md.
HELP
    ;;
  *) printf 'Unknown command: %s (use --help)\n' "$action" >&2; exit 2 ;;
esac
