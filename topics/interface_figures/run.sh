#!/usr/bin/env bash
# Capture the Viewer and Builder states and draw the interface figures.
#
#   bash topics/interface_figures/run.sh [all|capture|figures]
#
#   all      prepare the demo data, make the selections and counts, capture, draw, check
#   capture  the same up to and including the captures
#   figures  make the selections and counts again, draw the figures from the stored captures, check
#
# Needs: R with chromote, rhdf5, HDF5Array, qs2, scRepertoire, ggplot2,
# patchwork, ggrastr, svglite, ragg, png, digest and the packages CerebroNexus
# imports; Chrome or Chromium; poppler (pdfinfo, pdffonts); git; Arial (a
# Windows font folder is used if the system has none).
#
# CerebroNexus is taken from the commit in cerebronexus.lock (the commit of
# ../cerebronexus.pin): a source snapshot is made with `git archive`, installed
# into INTERFACE_WORK, and every R step uses that installed package. The
# snapshot comes from the local clone CEREBRONEXUS_CLONE if it has the commit
# (default: C:/Users/wangx/Projects/CerebroNexus, /mnt/c/... in WSL), otherwise
# from the repository URL in the lock.
#
# CEREBRO_LARGE_CACHE must name the folder run-demo.R fills with the Ren and
# E18 demo data (about 55 GB prepared, 75 GB sources; see
# data-raw/large-demo/README.md of CerebroNexus). `run-demo.R --data=1m,ren`
# builds what is missing there (a change of the data recipe's version rebuilds
# a data set) and does not download what is complete. INTERFACE_WORK (default:
# ~/.cache/cerebronexus-interface) holds the snapshot, the library and the
# plot inputs.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
step="${1:-all}"
case "$step" in all | capture | figures) ;; *)
  echo "Usage: run.sh [all|capture|figures]" >&2
  exit 2
  ;;
esac
: "${CEREBRO_LARGE_CACHE:?Set CEREBRO_LARGE_CACHE to the run-demo.R data folder}"
work="${INTERFACE_WORK:-$HOME/.cache/cerebronexus-interface}"
export LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 LANGUAGE=en
# run-demo.R and the Viewer ask the browser package to open the page; the
# captures drive their own Chrome.
export R_BROWSER=true BROWSER=true
# (A Windows checkout may have CRLF line ends.)
eval "$(tr -d '\r' <"$here/cerebronexus.lock" | grep -E '^[a-z_]+=[A-Za-z0-9:/._-]+$')"

# One commit serves the Viewer and the Builder.
if [ "$viewer_commit" != "$builder_commit" ]; then
  echo "cerebronexus.lock names two commits; the figures use the one commit of ../cerebronexus.pin." >&2
  exit 1
fi
commit="$viewer_commit"
pin="$here/../cerebronexus.pin"
if [ -f "$pin" ] && [ "$(tr -d '\r' <"$pin" | sed -n 's/^commit=//p')" != "$commit" ]; then
  echo "cerebronexus.lock differs from ../cerebronexus.pin; set the lock to the pinned commit." >&2
  exit 1
fi

# The local clone to take the commit from.
clone="${CEREBRONEXUS_CLONE:-}"
if [ -z "$clone" ]; then
  for candidate in /mnt/c/Users/wangx/Projects/CerebroNexus C:/Users/wangx/Projects/CerebroNexus; do
    if [ -d "$candidate/.git" ] || [ -f "$candidate/.git" ]; then
      clone="$candidate"
      break
    fi
  done
fi

# A source snapshot of one locked commit (git archive, no checkout switching).
snapshot() {
  local repo="$1" commit="$2" dir="$work/src-${2:0:12}"
  if [ ! -f "$dir/DESCRIPTION" ]; then
    rm -rf "$dir.part" && mkdir -p "$dir.part"
    if [ -n "$clone" ] && git -C "$clone" cat-file -e "$commit^{commit}" 2>/dev/null; then
      git -C "$clone" archive "$commit" | tar -x -C "$dir.part"
    else
      local mirror="$work/mirror.git"
      [ -d "$mirror" ] || git init -q --bare "$mirror"
      git -C "$mirror" cat-file -e "$commit^{commit}" 2>/dev/null ||
        git -C "$mirror" fetch -q "$repo" "$commit"
      git -C "$mirror" archive "$commit" | tar -x -C "$dir.part"
    fi
    mv "$dir.part" "$dir"
  fi
  echo "$dir"
}

mkdir -p "$work"
src="$(snapshot "$viewer_repo" "$commit")"

# The installed package every R step loads (library(CerebroNexus)).
lib="$work/lib-${commit:0:12}"
if [ ! -f "$lib/CerebroNexus/DESCRIPTION" ]; then
  mkdir -p "$lib"
  R CMD INSTALL --no-docs --no-multiarch --library="$lib" "$src" >"$work/install.log" 2>&1 ||
    { cat "$work/install.log" >&2; exit 1; }
fi
export R_LIBS="$lib${R_LIBS:+:$R_LIBS}"
export CEREBRO_COMMIT="$commit"

# Arial for the figures: the system's, else the Windows font folder's.
if ! fc-list 2>/dev/null | grep -qi 'arial'; then
  for dir in "${ARIAL_DIR:-}" /mnt/c/Windows/Fonts; do
    if [ -n "$dir" ] && [ -f "$dir/arial.ttf" ]; then
      mkdir -p "$work/fonts"
      cp -f "$dir"/arial*.ttf "$work/fonts/"
      printf '<?xml version="1.0"?><fontconfig><include ignore_missing="yes">/etc/fonts/fonts.conf</include><dir>%s</dir><cachedir>%s</cachedir></fontconfig>\n' \
        "$work/fonts" "$work/fonts/cache" >"$work/fonts.conf"
      export FONTCONFIG_FILE="$work/fonts.conf"
      break
    fi
  done
fi

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
pids=()
# Rscript runs R as a child process; stop both.
trap 'for p in "${pids[@]:-}"; do [ -n "$p" ] && { pkill -P "$p" 2>/dev/null; kill "$p" 2>/dev/null; } || true; done' EXIT

if [ "$step" = all ] || [ "$step" = capture ]; then
  # The Ren and E18 demo data of this revision (what is complete is kept).
  Rscript "$src/run-demo.R" --data=1m,ren --prepare-only
fi

# The saved selections and every count (data/checks.json).
Rscript "$here/scripts/prepare_inputs.R" "$CEREBRO_LARGE_CACHE" "$work/inputs"

if [ "$step" = all ] || [ "$step" = capture ]; then
  # Fresh servers: the Builder keeps its project in the server session.
  serve "$work/viewer.log" Rscript "$src/run-demo.R" --data=1m,ren
  serve "$work/builder.log" Rscript -e \
    "library(CerebroNexus); launchCerebroBuilder(port = 18772, launch_browser = FALSE)"
  Rscript "$here/scripts/capture_viewer.R" "$(url_of "$work/viewer.log")" "$here/captures"
  Rscript "$here/scripts/capture_builder.R" "$(url_of "$work/builder.log")" "$here/captures"
fi

if [ "$step" = all ] || [ "$step" = figures ]; then
  Rscript "$here/scripts/figures.R" "$work/inputs" "$here/captures" "$here/figures"
  Rscript "$here/scripts/check_figures.R" "$here/figures"
fi
