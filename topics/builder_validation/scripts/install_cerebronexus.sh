#!/bin/sh
## Install one CerebroNexus commit into env/rlib: git archive of the commit to
## env/src, then R CMD INSTALL. Records what was installed in env/installed.txt
## (commit, version, where it came from); common.R reads that file and refuses
## to run when the commit is not the one in topics/cerebronexus.pin.
##
## Usage: scripts/install_cerebronexus.sh [<commit> [<repository>]]
##   commit      default: the commit in ../../cerebronexus.pin (topics/cerebronexus.pin)
##   repository  a local clone (a path: /mnt/c/... on WSL, C:\... or C:/... on Windows,
##               relative paths too) or a URL. Default: $CN_REPO, else the `repo` of the
##               pin. For a URL the commit is fetched into a bare clone in env/repo; a
##               commit that no remote has (the pin says so while the branch is not pushed)
##               must be given as a local clone.
## Writes results/install_<first 9 characters of the commit>.log.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
topic=$(cd "$here/.." && pwd)
pinfile=$topic/../cerebronexus.pin
pin() { if [ -f "$pinfile" ]; then sed -n "s/^$1=//p" "$pinfile" | head -n 1 | tr -d '\r'; fi; }

commit=${1:-$(pin commit)}
[ -n "$commit" ] || { echo "usage: $0 [<commit> [<repository>]]  (no commit given and none in $pinfile)" >&2; exit 2; }
repo=${2:-${CN_REPO:-$(pin repo)}}
[ -n "$repo" ] || { echo "no repository given (argument, \$CN_REPO or the pin)" >&2; exit 2; }

## A local clone may be given as a Windows path, a WSL path or a relative path.
## Resolve it before changing directory.
case $repo in
  http://*|https://*|git@*|ssh://*|git://*) kind=url ;;
  *)
    kind=local
    if [ ! -e "$repo" ]; then
      if command -v cygpath >/dev/null 2>&1; then repo=$(cygpath -u "$repo")
      elif command -v wslpath >/dev/null 2>&1; then repo=$(wslpath -u "$repo")
      fi
    fi
    [ -d "$repo" ] || { echo "repository not found: $repo" >&2; exit 2; }
    repo=$(cd "$repo" && pwd)
    ;;
esac
## A clone owned by another user (a Windows disk seen from WSL) trips git's ownership check.
git_() { git -c safe.directory='*' "$@"; }

cd "$topic"
mkdir -p env data results
if [ "$kind" = url ]; then
  clone=env/repo
  [ -d "$clone" ] || git_ clone --quiet --bare "$repo" "$clone"
  git_ -C "$clone" fetch --quiet origin "$commit" 2>/dev/null || git_ -C "$clone" fetch --quiet origin || true
else
  clone=$repo
fi
full=$(git_ -C "$clone" rev-parse --verify --quiet "$commit^{commit}") || {
  echo "commit $commit is not in $repo (a commit that is only in a local clone has to be given as that clone)" >&2
  exit 1
}
short=$(printf '%s' "$full" | cut -c1-9)

rm -rf env/src env/rlib env/installed.txt
mkdir -p env/src env/rlib
git_ -C "$clone" archive "$full" | tar -x -C env/src
R CMD INSTALL --library=env/rlib env/src > "results/install_$short.log" 2>&1 || {
  echo "R CMD INSTALL failed, see results/install_$short.log" >&2
  exit 1
}
version=$(sed -n 's/^Version:[[:space:]]*//p' env/src/DESCRIPTION | head -n 1 | tr -d '\r')
{
  echo "commit=$full"
  echo "version=$version"
  echo "source=$repo"
  echo "installed=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > env/installed.txt
echo "installed $full (version $version) into env/rlib (log results/install_$short.log)"
