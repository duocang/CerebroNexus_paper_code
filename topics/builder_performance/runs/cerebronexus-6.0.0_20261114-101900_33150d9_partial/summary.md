# Builder performance: CerebroNexus 6.0.0

Run `cerebronexus-6.0.0_20261114-101900_33150d9_partial`: revision `d5ad68c3255d3dbf84b4d108b0cc0e2074925ab3` (33150d9d7a95), 5 round(s), 5 session(s), 0 failed.
Contract `builder-perf-v1`. Fixtures: cells100k.rds. Machine: NUIOI, Microsoft Windows 11 Pro 10.0.26300, 12th Gen Intel(R) Core(TM) i9-12900K.
Made together with `cerebronexus-8.1.1_20261114-101900_d79f5d8_partial`; this run is the baseline.

Medians over the rounds that finished. Times in milliseconds (`edit_ms`, `reduce_ms`) or seconds (the rest); `peak_mib` is the peak memory of the worker, `out_mib` the size of what it wrote.

| scenario | rounds | ok_rounds | edit_ms | reduce_ms | import_s | freeze_s | build_s | rebuild_s | export_s | cpu_s | peak_mib | out_mib |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| export_h5 | 5 | 5 | - | - | - | - | - | - | 56.8 | 63.6 | 11,475.2 | 2,270.8 |

