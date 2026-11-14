# Builder performance: CerebroNexus 6.0.0

Run `cerebronexus-6.0.0_20261114-093648_33150d9`: revision `d5ad68c3255d3dbf84b4d108b0cc0e2074925ab3` (33150d9d7a95), 5 round(s), 25 session(s), 5 failed.
Contract `builder-perf-v1`. Fixtures: meta60.rds, meta_import.rds, cells100k.rds. Machine: NUIOI, Microsoft Windows 11 Pro 10.0.26300, 12th Gen Intel(R) Core(TM) i9-12900K.
Made together with `cerebronexus-8.1.1_20261114-093648_d79f5d8`; this run is the baseline.

Medians over the rounds that finished. Times in milliseconds (`edit_ms`, `reduce_ms`) or seconds (the rest); `peak_mib` is the peak memory of the worker, `out_mib` the size of what it wrote.

| scenario | rounds | ok_rounds | edit_ms | reduce_ms | import_s | freeze_s | build_s | rebuild_s | export_s | cpu_s | peak_mib | out_mib |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| build_embedded | 5 | 5 | - | - | 25.5 | 1.2 | 8.4 | - | - | 36.6 | 11,480.5 | 377.2 |
| build_h5 | 5 | 5 | - | - | 25.8 | 1.2 | 62.1 | 58.5 | - | 156.6 | 11,582.5 | 2,270.8 |
| edit | 5 | 5 | 270 | 200 | - | - | - | - | - | 17.6 | 631.1 | - |
| export_h5 | 5 | 0 | - | - | - | - | - | - | - | - | - | - |
| import | 5 | 5 | - | - | 41.3 | - | - | - | - | 43.8 | 897.7 | - |

## Equivalence checks

| check | result | detail |
|---|---|---|
| sidecar_config_change_same_matrix | pass | matrix after a configuration change, offered the earlier sidecar vs offered nothing |
| sidecar_changed_matrix_rewritten | pass | a changed matrix, offered the sidecar of the old one: the result holds the new matrix, not the old |
| sidecar_wrong_md5_rewritten | pass | an offered sidecar whose MD5 does not match: the matrix is written again |
| sidecar_missing_rewritten | pass | an offered sidecar that does not exist: the matrix is written again |
| h5_content_digest | pass | digest eb69662063f42f6b33281a4207ef7808 over 6 datasets |

## Problems

- 5 session(s) failed: their scenarios have fewer rounds (logs/)

