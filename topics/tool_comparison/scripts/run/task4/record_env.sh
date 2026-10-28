#!/bin/sh
## Versions of everything Task 4 ran with -> results/task4/task4_environment.txt
BV=$(cd "$(dirname "$0")/../../../../builder_validation" && pwd)
## T4_G as in lib.R (recorded runs: /Volumes/bv_cache/g)
G=${T4_G:-$(cd "$(dirname "$0")/../../.." && pwd)/env/g}
{
  echo "Date: $(date -u +%FT%TZ)"
  echo "Host: $(sysctl -n machdep.cpu.brand_string), $(sysctl -n hw.ncpu) CPUs, $(( $(sysctl -n hw.memsize) / 1073741824 )) GB, macOS $(sw_vers -productVersion) ($(uname -m))"
  echo "R: $(R --version | head -1)"
  R_LIBS=$G/rlib Rscript -e 'for (p in c("ShinyCell","iSEE","anndataR","SingleCellExperiment","shiny","shinyhelper","hdf5r","chromote")) cat(sprintf("%-22s %s\n", p, as.character(packageVersion(p))))'
  R_LIBS=$BV/env/rlib Rscript -e 'cat(sprintf("%-22s %s (%s)\n", "CerebroNexus", as.character(packageVersion("CerebroNexus")), find.package("CerebroNexus")))'
  echo "CerebroNexus commit: $(cat $BV/results/environment_33150d9d7.txt 2>/dev/null | sed -n 2p)"
  echo "Python: $($G/py/bin/python --version)"
  VIRTUAL_ENV=$G/py uv pip list 2>/dev/null | grep -i -E "^(cellxgene|vitessce|anndata|scanpy|zarr|numpy|pandas) "
  echo "vitessce JS: $(node -e 'console.log(require("'$G'/vjs/node_modules/vitessce/package.json").version)'), bundled with esbuild $($G/vjs/node_modules/.bin/esbuild --version)"
  echo "Chrome (chromote): $(Rscript -e 'cat(chromote::find_chrome())')"
} > "$(dirname "$0")/../../../results/task4/task4_environment.txt" 2>&1
