# Builder performance: CerebroNexus 8.0.1

Run `cerebronexus-8.0.1_20261113-153410_6a67f6f`: revision `master` (6a67f6fcda05), 5 round(s), 25 session(s), 0 failed.
Contract `builder-perf-v1`. Fixtures: meta60.rds, meta_import.rds, cells100k.rds. Machine: NUIOI, Microsoft Windows 11 专业版 10.0.26300, 12th Gen Intel(R) Core(TM) i9-12900K.
Made together with `cerebronexus-8.3.0_20261113-153410_e927cbf`; this run is the baseline.

Medians over the rounds that finished. Times in milliseconds (`edit_ms`, `reduce_ms`) or seconds (the rest); `peak_mib` is the peak memory of the worker, `out_mib` the size of what it wrote.

| scenario | rounds | ok_rounds | edit_ms | reduce_ms | import_s | freeze_s | build_s | rebuild_s | export_s | cpu_s | peak_mib | out_mib |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| build_embedded | 5 | 5 | - | - | 27.4 | 1.4 | 20.6 | - | - | 50.1 | 11,873.6 | 378.9 |
| build_h5 | 5 | 5 | - | - | 26.9 | 1.3 | 70.9 | 65.9 | - | 176.5 | 11,157.2 | 2,272.8 |
| edit | 5 | 5 | 300 | 220 | - | - | - | - | - | 18.2 | 606.8 | - |
| export_h5 | 5 | 5 | - | - | - | - | - | - | 69.6 | 77.2 | 11,463.3 | 2,272.8 |
| import | 5 | 5 | - | - | 46.2 | - | - | - | - | 48.1 | 877.4 | - |

## Equivalence checks

| check | result | detail |
|---|---|---|
| sidecar_config_change_same_matrix | pass | matrix after a configuration change, offered the earlier sidecar vs offered nothing |
| sidecar_changed_matrix_rewritten | pass | a changed matrix, offered the sidecar of the old one: the result holds the new matrix, not the old |
| sidecar_wrong_md5_rewritten | pass | an offered sidecar whose MD5 does not match: the matrix is written again |
| sidecar_missing_rewritten | pass | an offered sidecar that does not exist: the matrix is written again |
| h5_content_digest | pass | digest eb69662063f42f6b33281a4207ef7808 over 6 datasets |

## Problems

- the CPU canary moved by a factor 1.57 during the run (380, 370, 390, 390, 580, 370 ms)

