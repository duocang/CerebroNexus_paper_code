#!/usr/bin/env bash
# H5 / BPCells / embedded expression-storage comparison, on Linux or WSL.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
case "${1:-run}" in
  -h|--help|help)
    cat <<'HELP'
Usage: bash topics/expression_backends/run.sh [quick|run|scale|full|status|resume DIRECTORY]
Compare H5, BPCells and embedded expression storage: construction, size,
startup, memory and materialized gene reads. Uses the project's Nix environment;
set BENCH_NIX=0 to use your own R (install packages with: Rscript install.R benchmark).
quick: 1,000 cells per source, one build and access process per backend.
run (default), scale: independent scale study, including 300k and each full-dataset endpoint.
full: optional separate full-source study; not required by scale.
Measurement modes download and cache the complete source files on first use.
See topics/expression_backends/README.md before interpreting historical records.
HELP
    ;;
  *) exec bash "$here/scripts/run.sh" "$@" ;;
esac
