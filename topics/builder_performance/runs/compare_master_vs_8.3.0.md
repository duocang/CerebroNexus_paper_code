# cerebronexus-8.0.1_20261113-153410_6a67f6f -> cerebronexus-8.3.0_20261113-153410_e927cbf

Made together: the rounds of A and B met the same machine.

| scenario | metric | A | B | delta | % | rounds | p | B-A per round | change |
|---|---|---|---|---|---|---|---|---|---|
| edit | edit_ms | 300.0 | 30.0 | -270.0 | -90.0 | 5/5 | 0.008 | -530.0 to -260.0 | faster |
| edit | reduce_ms | 220.0 | 30.0 | -190.0 | -86.4 | 5/5 | 0.008 | -350.0 to -190.0 | faster |
| import | import_s | 46.2 | 5.6 | -40.6 | -88.0 | 5/5 | 0.008 | -82.2 to -40.5 | faster |
| build_embedded | import_s | 27.4 | 26.8 | -0.6 | -2.2 | 5/5 | 0.421 | -0.7 to 0.8 | not resolved |
| build_embedded | freeze_s | 1.4 | 1.6 | 0.2 | +14.8 | 5/5 | 0.079 | 0.1 to 0.4 | not resolved |
| build_embedded | build_s | 20.6 | 13.3 | -7.4 | -35.6 | 5/5 | 0.008 | -16.8 to -7.2 | faster |
| build_h5 | import_s | 26.9 | 26.9 | 0.1 | +0.3 | 5/5 | 0.548 | -0.2 to 1.6 | not resolved |
| build_h5 | freeze_s | 1.3 | 1.5 | 0.2 | +16.7 | 5/5 | 0.008 | 0.2 to 0.2 | slower |
| build_h5 | build_s | 70.9 | 22.6 | -48.2 | -68.0 | 5/5 | 0.008 | -48.4 to -47.4 | faster |
| build_h5 | rebuild_s | 65.9 | 11.3 | -54.6 | -82.8 | 5/5 | 0.008 | -54.9 to -51.8 | faster |
| export_h5 | export_s | 69.6 | 20.1 | -49.5 | -71.2 | 5/5 | 0.008 | -84.7 to -49.2 | faster |

Memory, CPU and output size (not judged):

| scenario | metric | A | B |
|---|---|---|---|
| edit | peak_mib | 607 | 579 |
| import | peak_mib | 877 | 791 |
| build_embedded | peak_mib | 11,874 | 7,526 |
| build_h5 | peak_mib | 11,157 | 11,816 |
| export_h5 | peak_mib | 11,463 | 11,710 |
| edit | cpu_s | 18 | 7 |
| import | cpu_s | 48 | 8 |
| build_embedded | cpu_s | 50 | 43 |
| build_h5 | cpu_s | 176 | 75 |
| export_h5 | cpu_s | 77 | 28 |
| build_embedded | out_mib | 379 | 378 |
| build_h5 | out_mib | 2,273 | 2,273 |
| export_h5 | out_mib | 2,273 | 2,273 |

Equivalence checks:

- cerebronexus-8.0.1_20261113-153410_6a67f6f: 5 of 5 passed
- cerebronexus-8.3.0_20261113-153410_e927cbf: 5 of 5 passed
- the H5 written by A and by B holds the same data (same digest)

