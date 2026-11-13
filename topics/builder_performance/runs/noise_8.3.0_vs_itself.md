# cerebronexus-8.3.0_20261113-162717_e927cbf_base -> cerebronexus-8.3.0_20261113-162717_e927cbf

Both runs are of the same revision: every difference below is noise.

Made together: the rounds of A and B met the same machine.

| scenario | metric | A | B | delta | % | rounds | p | B-A per round | change |
|---|---|---|---|---|---|---|---|---|---|
| edit | edit_ms | 40.0 | 30.0 | -10.0 | -25.0 | 5/5 | 0.524 | -10.0 to 0.0 | not resolved |
| edit | reduce_ms | 30.0 | 30.0 | 0.0 | +0.0 | 5/5 | 0.444 | 0.0 to 10.0 | not resolved |
| import | import_s | 5.5 | 5.4 | -0.1 | -2.0 | 5/5 | 0.841 | -0.1 to 0.1 | not resolved |
| build_embedded | import_s | 26.6 | 26.4 | -0.1 | -0.5 | 5/5 | 0.508 | -0.1 to 0.1 | not resolved |
| build_embedded | freeze_s | 1.5 | 1.6 | 0.0 | +2.6 | 5/5 | 0.222 | -0.1 to 0.1 | not resolved |
| build_embedded | build_s | 13.2 | 13.2 | 0.0 | -0.1 | 5/5 | 1.000 | -0.2 to 4.8 | not resolved |
| build_h5 | import_s | 26.4 | 26.5 | 0.1 | +0.4 | 5/5 | 0.460 | -1.2 to 0.9 | not resolved |
| build_h5 | freeze_s | 1.5 | 1.6 | 0.0 | +1.3 | 5/5 | 0.952 | 0.0 to 0.1 | not resolved |
| build_h5 | build_s | 22.8 | 23.1 | 0.3 | +1.3 | 5/5 | 0.841 | -14.5 to 0.4 | not resolved |
| build_h5 | rebuild_s | 11.6 | 11.2 | -0.5 | -4.1 | 5/5 | 0.143 | -1.8 to 0.0 | not resolved |
| export_h5 | export_s | 20.0 | 20.0 | 0.0 | -0.1 | 5/5 | 0.548 | -0.2 to 0.8 | not resolved |

Memory, CPU and output size (not judged):

| scenario | metric | A | B |
|---|---|---|---|
| edit | peak_mib | 583 | 579 |
| import | peak_mib | 791 | 791 |
| build_embedded | peak_mib | 7,526 | 7,526 |
| build_h5 | peak_mib | 11,816 | 11,816 |
| export_h5 | peak_mib | 11,709 | 11,709 |
| edit | cpu_s | 7 | 7 |
| import | cpu_s | 8 | 8 |
| build_embedded | cpu_s | 42 | 42 |
| build_h5 | cpu_s | 75 | 76 |
| export_h5 | cpu_s | 28 | 28 |
| build_embedded | out_mib | 378 | 378 |
| build_h5 | out_mib | 2,273 | 2,273 |
| export_h5 | out_mib | 2,273 | 2,273 |

Equivalence checks:

- cerebronexus-8.3.0_20261113-162717_e927cbf_base: 5 of 5 passed
- cerebronexus-8.3.0_20261113-162717_e927cbf: 5 of 5 passed
- the H5 written by A and by B holds the same data (same digest)

Noise of this machine (one revision against itself): medians differ by 25.0 % at most, 1.3 % typically; 0 of 11 rows resolve a difference.

