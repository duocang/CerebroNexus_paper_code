# Builder performance: CerebroNexus 8.3.0

Run `cerebronexus-8.3.0_20261113-162717_e927cbf_base`: revision `e927cbf180fb1a50cf783245ab580e83a1334764` (e927cbf180fb), 5 round(s), 25 session(s), 0 failed.
Contract `builder-perf-v1`. Fixtures: meta60.rds, meta_import.rds, cells100k.rds. Machine: NUIOI, Microsoft Windows 11 Pro 10.0.26300, 12th Gen Intel(R) Core(TM) i9-12900K.
Made together with `cerebronexus-8.3.0_20261113-162717_e927cbf`; this run is the baseline.

Medians over the rounds that finished. Times in milliseconds (`edit_ms`, `reduce_ms`) or seconds (the rest); `peak_mib` is the peak memory of the worker, `out_mib` the size of what it wrote.

| scenario | rounds | ok_rounds | edit_ms | reduce_ms | import_s | freeze_s | build_s | rebuild_s | export_s | cpu_s | peak_mib | out_mib |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| build_embedded | 5 | 5 | - | - | 26.6 | 1.5 | 13.2 | - | - | 42.2 | 7,525.8 | 378.2 |
| build_h5 | 5 | 5 | - | - | 26.4 | 1.5 | 22.8 | 11.6 | - | 75.4 | 11,815.6 | 2,272.8 |
| edit | 5 | 5 | 40 | 30 | - | - | - | - | - | 7.2 | 583.3 | - |
| export_h5 | 5 | 5 | - | - | - | - | - | - | 20 | 28.1 | 11,709.4 | 2,272.8 |
| import | 5 | 5 | - | - | 5.5 | - | - | - | - | 7.8 | 790.9 | - |

## Equivalence checks

| check | result | detail |
|---|---|---|
| sidecar_config_change_same_matrix | pass | matrix after a configuration change, offered the earlier sidecar vs offered nothing |
| sidecar_changed_matrix_rewritten | pass | a changed matrix, offered the sidecar of the old one: the result holds the new matrix, not the old |
| sidecar_wrong_md5_rewritten | pass | an offered sidecar whose MD5 does not match: the matrix is written again |
| sidecar_missing_rewritten | pass | an offered sidecar that does not exist: the matrix is written again |
| h5_content_digest | pass | digest eb69662063f42f6b33281a4207ef7808 over 6 datasets |

