#!/usr/bin/env bash
set -euo pipefail

cache_url="https://osmzhlab.uni-muenster.de:4949/r-packages"
cache_key="r-packages:Op7Q3XME8az4XNcP1clupGw4ZbuaguBw+sUziweqpTY="

if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    echo "NIX_CONFIG<<EOF"
    printf 'extra-substituters = %s\n' "$cache_url"
    printf 'extra-trusted-public-keys = %s\n' "$cache_key"
    echo "EOF"
  } >> "$GITHUB_ENV"
else
  cat <<EOF
GITHUB_ENV is not set. To use this cache locally, export:
NIX_CONFIG='extra-substituters = $cache_url
extra-trusted-public-keys = $cache_key'
EOF
fi

echo "Configured osmzhlab Attic cache: $cache_url"
