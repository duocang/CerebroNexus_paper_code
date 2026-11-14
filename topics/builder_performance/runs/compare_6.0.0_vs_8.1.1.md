# cerebronexus-6.0.0_20261114-093648_33150d9 -> cerebronexus-8.1.1_20261114-093648_d79f5d8

Made together: the rounds of A and B met the same machine.

| scenario | metric | A | B | delta | % | rounds | p | B-A per round | change |
|---|---|---|---|---|---|---|---|---|---|
| edit | edit_ms | 270.0 | 30.0 | -240.0 | -88.9 | 5/5 | 0.008 | -270.0 to -240.0 | faster |
| edit | reduce_ms | 200.0 | 30.0 | -170.0 | -85.0 | 5/5 | 0.008 | -170.0 to -170.0 | faster |
| import | import_s | 41.3 | 5.2 | -36.1 | -87.3 | 5/5 | 0.008 | -36.3 to -36.0 | faster |
| build_embedded | import_s | 25.5 | 19.9 | -5.5 | -21.8 | 5/5 | 0.008 | -5.7 to -5.2 | faster |
| build_embedded | freeze_s | 1.2 | 1.4 | 0.2 | +20.8 | 5/5 | 0.008 | 0.2 to 0.3 | slower |
| build_embedded | build_s | 8.4 | 11.7 | 3.2 | +38.5 | 5/5 | 0.008 | 2.7 to 3.4 | slower |
| build_h5 | import_s | 25.8 | 19.9 | -5.9 | -22.9 | 5/5 | 0.008 | -6.2 to -5.7 | faster |
| build_h5 | freeze_s | 1.2 | 1.4 | 0.2 | +20.8 | 5/5 | 0.008 | 0.2 to 0.3 | slower |
| build_h5 | build_s | 62.1 | 19.0 | -43.1 | -69.5 | 5/5 | 0.008 | -43.2 to -42.5 | faster |
| build_h5 | rebuild_s | 58.5 | 8.9 | -49.6 | -84.8 | 5/5 | 0.008 | -50.1 to -49.4 | faster |
| export_h5 | export_s | - | 16.9 | - | - | 0/5 | - | - | - |

Memory, CPU and output size (not judged):

| scenario | metric | A | B |
|---|---|---|---|
| edit | peak_mib | 631 | 578 |
| import | peak_mib | 898 | 799 |
| build_embedded | peak_mib | 11,481 | 7,525 |
| build_h5 | peak_mib | 11,582 | 11,816 |
| export_h5 | peak_mib | - | 11,709 |
| edit | cpu_s | 18 | 7 |
| import | cpu_s | 44 | 8 |
| build_embedded | cpu_s | 37 | 34 |
| build_h5 | cpu_s | 157 | 59 |
| export_h5 | cpu_s | - | 24 |
| build_embedded | out_mib | 377 | 378 |
| build_h5 | out_mib | 2,271 | 2,273 |
| export_h5 | out_mib | - | 2,273 |

Equivalence checks:

- cerebronexus-6.0.0_20261114-093648_33150d9: 5 of 5 passed
- cerebronexus-8.1.1_20261114-093648_d79f5d8: 5 of 5 passed
- the H5 written by A and by B holds the same data (same digest)

