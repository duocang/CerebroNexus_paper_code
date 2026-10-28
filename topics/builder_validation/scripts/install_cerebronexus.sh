#!/bin/sh
## Install one CerebroNexus commit into env/rlib, as for every recorded run:
## git archive of the commit to env/src, then R CMD INSTALL.
##
## Usage: scripts/install_cerebronexus.sh <commit> [repository]
##   repository: a local clone or a URL (default: $CN_REPO, else
##   https://github.com/duocang/CerebroNexus.git); the commit must be reachable
##   from branch builder/03_builder or already be in the clone.
## Writes results/install_<short commit>.log.
set -eu
[ $# -ge 1 ] || { echo "usage: $0 <commit> [repository]" >&2; exit 2; }
commit=$1
repo=${2:-${CN_REPO:-https://github.com/duocang/CerebroNexus.git}}
cd "$(dirname "$0")/.."
mkdir -p env data results
case $repo in
  http*|git@*)
    clone=env/repo
    [ -d "$clone" ] || git clone --quiet --bare "$repo" "$clone"
    git -C "$clone" fetch --quiet origin builder/03_builder || true
    ;;
  *) clone=$repo ;;
esac
rm -rf env/src env/rlib
mkdir -p env/src env/rlib
git -C "$clone" archive "$commit" | tar -x -C env/src
short=$(git -C "$clone" rev-parse --short=9 "$commit")
R CMD INSTALL --library=env/rlib env/src > "results/install_$short.log" 2>&1
echo "installed $commit into env/rlib (log results/install_$short.log)"
