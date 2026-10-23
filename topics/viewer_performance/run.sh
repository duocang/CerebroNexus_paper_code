#!/usr/bin/env bash
# Viewer performance standard (STANDARD.md): l0/l1/l2/track on Linux or WSL, gpu on Windows (Git Bash).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
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
  track [--cerebro-repo DIR]
                           L1 run of origin/master if it changed since the last recorded L1 run
  gpu --candidate REF --baseline REF [--record]
                           Point renderer on the GPU (Windows; reported, not judged)
  standard-tests           Unit tests of the standard's verdict logic
Run from this repository with CerebroNexus cloned beside it (or CEREBRO_REPO set); see STANDARD.md.
HELP
    ;;
  *) printf 'Unknown command: %s (use --help)\n' "$action" >&2; exit 2 ;;
esac
