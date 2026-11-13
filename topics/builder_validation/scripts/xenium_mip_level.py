"""Read one pyramid level of the Xenium morphology MIP (OME-TIFF) without RBioFormats.

Used by 00_prepare_inputs.R when RBioFormats (Java) is not installed. Picks the same
level as the R code: the smallest level whose long edge is at least MIN_EDGE pixels.

Usage: python3 xenium_mip_level.py <morphology_mip.ome.tif> <out.bin> [min_edge]
Writes the level as little-endian uint16, row by row (C order), to <out.bin> and prints
one JSON line: {"level": <1-based>, "width": W, "height": H, "full_width": FW, "full_height": FH}.
Needs: tifffile, imagecodecs, numpy.
"""
import json
import sys

import numpy as np
import tifffile

path, out = sys.argv[1], sys.argv[2]
min_edge = int(sys.argv[3]) if len(sys.argv) > 3 else 1400
with tifffile.TiffFile(path) as tif:
    levels = tif.series[0].levels
    shapes = [lv.shape[-2:] for lv in levels]  # (height, width)
    pick = 0
    for i, (h, w) in enumerate(shapes):
        if max(h, w) >= min_edge:
            pick = i
    arr = np.asarray(levels[pick].asarray())
    if arr.ndim > 2:
        arr = arr.reshape(-1, *arr.shape[-2:])[0]
    arr.astype("<u2").tofile(out)
    print(json.dumps({
        "level": pick + 1,
        "width": int(shapes[pick][1]), "height": int(shapes[pick][0]),
        "full_width": int(shapes[0][1]), "full_height": int(shapes[0][0]),
    }))
