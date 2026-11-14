# Builder performance: CerebroNexus 8.0.0

Run `cerebronexus-8.0.0_20261114-064947_24bbc02`: revision `24bbc029c3dba0df4e6af6f6ab69292bbed471fd` (24bbc029c3db), 5 round(s), 25 session(s), 0 failed.
Contract `builder-perf-v1`. Fixtures: meta60.rds, meta_import.rds, cells100k.rds. Machine: NUIOI, Microsoft Windows 11 Pro 10.0.26300, 12th Gen Intel(R) Core(TM) i9-12900K.
Made together with `cerebronexus-8.1.1_20261114-064947_d79f5d8`; this run is the baseline.

Medians over the rounds that finished. Times in milliseconds (`edit_ms`, `reduce_ms`) or seconds (the rest); `peak_mib` is the peak memory of the worker, `out_mib` the size of what it wrote.

| scenario | rounds | ok_rounds | edit_ms | reduce_ms | import_s | freeze_s | build_s | rebuild_s | export_s | cpu_s | peak_mib | out_mib |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| build_embedded | 5 | 5 | - | - | 20.0 | 1.3 | 18.7 | - | - | 41.6 | 11,873.1 | 378.9 |
| build_h5 | 5 | 5 | - | - | 20.1 | 1.3 | 63.0 | 59.4 | - | 151.9 | 11,150.0 | 2,272.8 |
| edit | 5 | 5 | 280 | 200 | - | - | - | - | - | 17.6 | 610.0 | - |
| export_h5 | 5 | 5 | - | - | - | - | - | - | 62.6 | 69.1 | 11,461.3 | 2,272.8 |
| import | 5 | 5 | - | - | 45.8 | - | - | - | - | 48.4 | 841.1 | - |

## Equivalence checks

| check | result | detail |
|---|---|---|
| sidecar_config_change_same_matrix | pass | matrix after a configuration change, offered the earlier sidecar vs offered nothing |
| sidecar_changed_matrix_rewritten | pass | a changed matrix, offered the sidecar of the old one: the result holds the new matrix, not the old |
| sidecar_wrong_md5_rewritten | pass | an offered sidecar whose MD5 does not match: the matrix is written again |
| sidecar_missing_rewritten | pass | an offered sidecar that does not exist: the matrix is written again |
| h5_content_digest | pass | digest eb69662063f42f6b33281a4207ef7808 over 6 datasets |

