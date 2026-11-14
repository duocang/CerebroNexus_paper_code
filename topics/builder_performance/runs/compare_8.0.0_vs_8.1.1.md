# cerebronexus-8.0.0_20261114-064947_24bbc02 -> cerebronexus-8.1.1_20261114-064947_d79f5d8

Made together: the rounds of A and B met the same machine.

| scenario | metric | A | B | delta | % | rounds | p | B-A per round | change |
|---|---|---|---|---|---|---|---|---|---|
| edit | edit_ms | 280.0 | 30.0 | -250.0 | -89.3 | 5/5 | 0.008 | -260.0 to -250.0 | faster |
| edit | reduce_ms | 200.0 | 30.0 | -170.0 | -85.0 | 5/5 | 0.008 | -180.0 to -170.0 | faster |
| import | import_s | 45.8 | 5.2 | -40.6 | -88.6 | 5/5 | 0.008 | -46.0 to -36.8 | faster |
| build_embedded | import_s | 20.0 | 20.6 | 0.5 | +2.5 | 5/5 | 0.690 | -0.2 to 1.0 | not resolved |
| build_embedded | freeze_s | 1.3 | 1.5 | 0.2 | +13.1 | 5/5 | 0.008 | 0.1 to 0.2 | slower |
| build_embedded | build_s | 18.7 | 11.8 | -7.0 | -37.3 | 5/5 | 0.008 | -7.4 to -6.8 | faster |
| build_h5 | import_s | 20.1 | 20.0 | -0.1 | -0.3 | 5/5 | 0.794 | -0.2 to 0.2 | not resolved |
| build_h5 | freeze_s | 1.3 | 1.4 | 0.2 | +14.2 | 5/5 | 0.008 | 0.2 to 0.2 | slower |
| build_h5 | build_s | 63.0 | 19.0 | -43.9 | -69.8 | 5/5 | 0.008 | -44.2 to -43.6 | faster |
| build_h5 | rebuild_s | 59.4 | 8.8 | -50.5 | -85.1 | 5/5 | 0.008 | -52.4 to -49.6 | faster |
| export_h5 | export_s | 62.6 | 16.9 | -45.7 | -73.0 | 5/5 | 0.008 | -47.2 to -45.5 | faster |

Memory, CPU and output size (not judged):

| scenario | metric | A | B |
|---|---|---|---|
| edit | peak_mib | 610 | 581 |
| import | peak_mib | 841 | 799 |
| build_embedded | peak_mib | 11,873 | 7,525 |
| build_h5 | peak_mib | 11,150 | 11,816 |
| export_h5 | peak_mib | 11,461 | 11,709 |
| edit | cpu_s | 18 | 7 |
| import | cpu_s | 48 | 7 |
| build_embedded | cpu_s | 42 | 35 |
| build_h5 | cpu_s | 152 | 59 |
| export_h5 | cpu_s | 69 | 24 |
| build_embedded | out_mib | 379 | 378 |
| build_h5 | out_mib | 2,273 | 2,273 |
| export_h5 | out_mib | 2,273 | 2,273 |

Equivalence checks:

- cerebronexus-8.0.0_20261114-064947_24bbc02: 5 of 5 passed
- cerebronexus-8.1.1_20261114-064947_d79f5d8: 5 of 5 passed
- the H5 written by A and by B holds the same data (same digest)

