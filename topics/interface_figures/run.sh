#!/usr/bin/env bash
# Capture the Viewer and Builder states and draw the interface figures.
#
#   bash topics/interface_figures/run.sh [all|capture|figures]
#
# Needs: R with the packages in install.R plus chromote, pkgload, rhdf5,
# HDF5Array, qs2, scRepertoire, ggrastr, svglite; Chrome or Chromium;
# poppler (pdfinfo, pdffonts); git.
# CEREBRO_LARGE_CACHE must name a folder with the Ren and E18 demo data built
# by `Rscript run-demo.R --prepare-only` of the viewer commit (about 140 GB
# with sources). INTERFACE_WORK (default: ~/.cache/cerebronexus-interface)
# holds the source snapshots and the prepared plot inputs.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
step="${1:-all}"
: "${CEREBRO_LARGE_CACHE:?Set CEREBRO_LARGE_CACHE to the run-demo.R data folder}"
work="${INTERFACE_WORK:-$HOME/.cache/cerebronexus-interface}"
export LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 LANGUAGE=en
eval "$(grep -E '^[a-z_]+=[A-Za-z0-9:/._-]+$' "$here/cerebronexus.lock")"

# A source snapshot of one locked commit (git archive, no checkout switching).
snapshot() {
  local repo="$1" commit="$2" dir="$work/src-${2:0:12}"
  if [ ! -f "$dir/DESCRIPTION" ]; then
    local mirror="$work/mirror.git"
    [ -d "$mirror" ] || git init -q --bare "$mirror"
    git -C "$mirror" cat-file -e "$commit^{commit}" 2>/dev/null ||
      git -C "$mirror" fetch -q "$repo" "$commit"
    mkdir -p "$dir"
    git -C "$mirror" archive "$commit" | tar -x -C "$dir"
  fi
  echo "$dir"
}

# Start a server in the background and wait until it listens; url_of prints
# the address from its log. (Runs in this shell so the trap can stop it.)
serve() {
  local log="$1"; shift
  "$@" >"$log" 2>&1 &
  local pid=$!
  pids+=("$pid")
  until grep -qE 'Listening on http' "$log"; do
    kill -0 "$pid" 2>/dev/null || { cat "$log" >&2; exit 1; }
    sleep 2
  done
}
url_of() { grep -oE 'http://127\.0\.0\.1:[0-9]+' "$1" | tail -n 1; }

mkdir -p "$work"
viewer_src="$(snapshot "$viewer_repo" "$viewer_commit")"
builder_src="$(snapshot "$builder_repo" "$builder_commit")"
pids=()
# Rscript runs R as a child process; stop both.
trap 'for p in "${pids[@]:-}"; do [ -n "$p" ] && { pkill -P "$p" 2>/dev/null; kill "$p" 2>/dev/null; } || true; done' EXIT

if [ "$step" = all ] || [ "$step" = capture ]; then
  # Fresh servers: the Builder keeps its project in the server session.
  serve "$work/viewer.log" Rscript "$viewer_src/run-demo.R" --no-browser
  serve "$work/builder.log" Rscript -e \
    "pkgload::load_all('$builder_src', export_all = FALSE, quiet = TRUE, helpers = FALSE); launchCerebroBuilder(port = 18772, launch_browser = FALSE)"
  Rscript "$here/scripts/capture_viewer.R" "$(url_of "$work/viewer.log")" "$here/captures"
  Rscript "$here/scripts/capture_builder.R" "$(url_of "$work/builder.log")" "$here/captures"
fi

if [ "$step" = all ] || [ "$step" = figures ]; then
  Rscript "$here/scripts/prepare_inputs.R" "$viewer_src" "$CEREBRO_LARGE_CACHE" "$work/inputs"
  cp "$work/inputs/checks.json" "$here/data/checks.json"
  Rscript "$here/scripts/figures.R" "$work/inputs" "$here/captures" "$here/figures"
  Rscript "$here/scripts/check_figures.R" "$here/figures"
fi
