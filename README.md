# Mac mini M4 Windows restore research and tests

Private repository for the specifically authorized Mac mini M4 restoration work. Initial contents are a narrow, source-backed cloud test suite. Additional reviewed source, patches and handoff material will follow.

## What cloud tests establish

The exact production identity parser and existing regression fixtures are tested on Ubuntu 24.04 (GCC and Clang, AddressSanitizer/UndefinedBehaviorSanitizer) and Windows Server 2022 (MSVC). Three independent replicas use distinct deterministic seeds, each testing 100,000 bounded malformed-input cases against an independent identity oracle and output-buffer canaries.

These are pure-data software tests. They access no USB devices, drivers, certificate stores, firmware or Mac hardware. Passing tests does **not** establish that a physical Mac restoration succeeds, that a Windows driver works, or that macOS boots. No physical restore is scheduled by this repository.

`source-provenance.json` records SHA-256 hashes of the copied production header and original fixtures. Cloud workflow access is read-only (`contents: read`), with a ten-minute limit per job and no repository secrets.

Do not commit firmware IPSWs, certificates, private keys, credentials, local account information or raw PC logs. Public release/publication is not authorized.
