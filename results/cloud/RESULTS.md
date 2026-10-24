# Cloud tests: completed successfully

Private repository: https://github.com/SteinOA/DSSA-restorekit-macmini-m4
Passing run: https://github.com/SteinOA/DSSA-restorekit-macmini-m4/actions/runs/40058880706
Tested commit: c4ac1863698b2cb415758d96605a10775b6f3e71

All nine independent jobs passed:
- Ubuntu 24.04 GCC: seeds104729,130363,155921, AddressSanitizer+UndefinedBehaviorSanitizer.
- Ubuntu 24.04 Clang: same three seeds and sanitizers.
- Windows2022 MSVC: same three seeds.

Each job ran the copied production regression fixtures and100,000 deterministic malformed-input/oracle/canary cases. Total900,000 randomized cases across passing jobs. Exact production parser SHA256:6501025dbbe35620b7e90165b3565d8eee2d101647e020af800e1387be4e060b.

The first run caught Windows checkout line-ending changes in source-provenance verification. Repository attributes now preserve exact source bytes; all provenance checks and tests passed in the corrected run.

Scope: pure-data parser regression, malformed-input memory safety, independent authorization oracle and output-buffer canaries. No hardware, USB, drivers, certificates, keys, firmware or physical Mac restoration were used. These results do not establish physical restore success or macOS boot.
