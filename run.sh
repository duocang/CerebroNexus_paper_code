#!/usr/bin/env bash
# Redraw the paper figures. See README.md.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

usage() {
  cat <<'HELP'
Usage: bash run.sh [--nix] [topic ...]          redraw figures (all topics, or the ones named)
       bash run.sh install [figures|benchmark]  install the R packages into your library
       bash run.sh [--nix] benchmark <topic> quick|scale|status   run a topic's benchmark
       bash run.sh --help
Figure topics: expression_backends, viewer_performance. Benchmark topics: expression-backends.
--nix uses the pinned Nix environment instead of your local R.
HELP
}

# Run topics/<topic>/benchmark/run.sh; $1 is 1 for the Nix environment, 0 for your R.
run_benchmark() {
  export BENCH_NIX=$1
  shift
  local topic=${1:-}
  if [ -z "$topic" ] || [ ! -f "topics/$topic/benchmark/run.sh" ]; then
    [ -z "$topic" ] || echo "Topic '$topic' has no benchmark in this repository." >&2
    echo "Topics with a benchmark:" >&2
    for script in topics/*/benchmark/run.sh; do
      [ -f "$script" ] && echo "  $(basename "$(dirname "$(dirname "$script")")")" >&2
    done
    echo "Usage: bash run.sh [--nix] benchmark <topic> quick|scale|status" >&2
    exit 1
  fi
  shift
  [ "$#" -gt 0 ] || { usage >&2; exit 2; }
  # CerebroNexus comes from topics/<topic>/cerebronexus.lock unless
  # CEREBRONEXUS_SRC names a local checkout.
  if [ -n "${CEREBRONEXUS_SRC:-}" ] && [ ! -f "$CEREBRONEXUS_SRC/DESCRIPTION" ]; then
    echo "CEREBRONEXUS_SRC is not a CerebroNexus checkout: $CEREBRONEXUS_SRC" >&2
    exit 1
  fi
  exec bash "topics/$topic/benchmark/run.sh" "$@"
}

case "${1:-}" in
  -h|--help|help) usage; exit 0 ;;
  install) shift; exec Rscript install.R "${1:-figures}" ;;
  benchmark) shift; run_benchmark 0 "$@" ;;
  --nix)
    shift
    if [ "${1:-}" = "benchmark" ]; then shift; run_benchmark 1 "$@"; fi
    # Keep a personal R library (e.g. ~/Library/R on macOS) out of the Nix R.
    export R_LIBS_USER=/nonexistent
    printf -v cmd 'Rscript make.R'
    for topic in "$@"; do printf -v cmd '%s %q' "$cmd" "$topic"; done
    exec nix-shell nix/figures/default.nix -A shell --run "$cmd"
    ;;
  *) exec Rscript make.R "$@" ;;
esac
