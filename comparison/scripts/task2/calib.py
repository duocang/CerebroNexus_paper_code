"""Data -> pixel calibration for Task 2 (PROTOCOL 6, region route).

When a plot library does not expose its axis objects, the affine map from embedding coordinates to page pixels is fitted
to a screenshot of the plot: start from the bounding box of the drawn dots, then search small offsets/scales that maximise the
fraction of cells whose predicted pixel lies on a dot. That fraction is the recorded fit quality; a good fit is > 0.97.
"""
import io
import numpy as np
from PIL import Image


def ink_mask(png, exclude=None, thr=15):
    """True where a pixel differs from the modal (background) colour. exclude = [(x0, y0, x1, y1), ...] in element pixels."""
    a = np.asarray(Image.open(io.BytesIO(png)).convert("RGB")).astype(np.int32)
    flat = (a[..., 0] << 16) | (a[..., 1] << 8) | a[..., 2]
    vals, counts = np.unique(flat, return_counts=True)
    bg = vals[counts.argmax()]
    bgc = np.array([(bg >> 16) & 255, (bg >> 8) & 255, bg & 255])
    m = np.sqrt(((a - bgc) ** 2).sum(-1)) > thr
    for (x0, y0, x1, y1) in exclude or []:
        m[int(y0):int(y1), int(x0):int(x1)] = False
    return m


def _dilate(m, r=1):
    out = m.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            out |= np.roll(np.roll(m, dy, 0), dx, 1)
    return out


def hit_fraction(mask_d, px, py):
    h, w = mask_d.shape
    ix = np.round(px).astype(int)
    iy = np.round(py).astype(int)
    ok = (ix >= 0) & (ix < w) & (iy >= 0) & (iy < h)
    hits = np.zeros(len(px), bool)
    hits[ok] = mask_d[iy[ok], ix[ok]]
    return hits.mean()


def _disk(r):
    n = int(np.ceil(r))
    yy, xx = np.mgrid[-n:n + 1, -n:n + 1]
    return (xx ** 2 + yy ** 2) <= r * r + 0.25


def _render(shape, px, py, disk):
    from scipy.ndimage import binary_dilation
    h, w = shape
    img = np.zeros(shape, bool)
    ix, iy = np.round(px).astype(int), np.round(py).astype(int)
    ok = (ix >= 0) & (ix < w) & (iy >= 0) & (iy < h)
    img[iy[ok], ix[ok]] = True
    return binary_dilation(img, structure=disk)


def _iou(mask, shape, px, py, disk):
    r = _render(shape, px, py, disk)
    inter = (r & mask).sum()
    return inter / max(1, (r | mask).sum())


def fit_both(png, xy, exclude=None, dot_radius=3, thr=15):
    """Fit both y orientations and keep the better one. Objective: IoU between the actual ink mask and a mask rendered by
    stamping a dot of the given radius at each predicted cell position (sensitive to shifts also inside dense clusters)."""
    m = ink_mask(png, exclude, thr)
    shape = m.shape
    ys, xs = np.nonzero(m)
    x0, x1, y0, y1 = xs.min() + dot_radius, xs.max() - dot_radius, ys.min() + dot_radius, ys.max() - dot_radius
    xmin, xmax, ymin, ymax = xy[:, 0].min(), xy[:, 0].max(), xy[:, 1].min(), xy[:, 1].max()
    res = []
    for flip in (False, True):
        ax = (x1 - x0) / (xmax - xmin)
        ay = (y1 - y0) / (ymax - ymin) * (1 if flip else -1)
        cur = [ax, x0 - ax * xmin, ay, (y0 - ay * ymin) if flip else (y1 - ay * ymin)]
        best_r, best_q, best_cur = dot_radius, -1, cur
        for r in (dot_radius - 1, dot_radius - 0.5, dot_radius, dot_radius + 0.5):
            disk = _disk(r)
            f = lambda c: _iou(m, shape, c[0] * xy[:, 0] + c[1], c[2] * xy[:, 1] + c[3], disk)
            c = list(cur); q = f(c)
            # coordinate descent: scale in x/y (relative), offsets in px; step sizes shrink
            for rel, off in ((0.02, 6.0), (0.005, 2.0), (0.0015, 0.7), (0.0005, 0.25)):
                improved = True
                while improved:
                    improved = False
                    for i in (0, 1, 2, 3):
                        for sgn in (-1, 1):
                            t = list(c)
                            t[i] = c[i] * (1 + sgn * rel) if i in (0, 2) else c[i] + sgn * off
                            qq = f(t)
                            if qq > q + 1e-6:
                                q, c, improved = qq, t, True
            if q > best_q:
                best_q, best_cur, best_r = q, c, r
        px, py = best_cur[0] * xy[:, 0] + best_cur[1], best_cur[2] * xy[:, 1] + best_cur[3]
        res.append(dict(ax=best_cur[0], bx=best_cur[1], ay=best_cur[2], by=best_cur[3], quality=float(best_q), y_flipped=flip,
                        dot_radius=best_r, quality_dilated=float(hit_fraction(_dilate(m, 1), px, py))))
    return max(res, key=lambda r: r["quality"])


def to_pixels(f, xy):
    return np.column_stack([f["ax"] * xy[:, 0] + f["bx"], f["ay"] * xy[:, 1] + f["by"]])


def convex_hull(points):
    pts = sorted(map(tuple, np.asarray(points)))
    if len(pts) <= 2:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lo = []
    for p in pts:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0:
            lo.pop()
        lo.append(p)
    up = []
    for p in reversed(pts):
        while len(up) >= 2 and cross(up[-2], up[-1], p) <= 0:
            up.pop()
        up.append(p)
    return lo[:-1] + up[:-1]


MARGIN_PX = 4.0   # the selection shape encloses whole dots (radius ~3 px) and absorbs ~1 px of calibration error; see Deviations D8


def expanded_hull(points, margin=MARGIN_PX, n_angles=16):
    """Convex hull of the target dots, each dot grown by `margin` pixels."""
    pts = np.asarray(points, float)
    ang = np.linspace(0, 2 * np.pi, n_angles, endpoint=False)
    grown = np.concatenate([pts + margin * np.array([np.cos(a), np.sin(a)]) for a in ang])
    return convex_hull(grown)


def expanded_bbox(points, margin=MARGIN_PX):
    pts = np.asarray(points, float)
    x0, y0 = pts.min(0) - margin
    x1, y1 = pts.max(0) + margin
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
