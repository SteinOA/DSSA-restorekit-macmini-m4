# Initial security review — 25 October 2026

## Result: review required before a customer release

Security configuration is in place, but the dependency audit has findings. No claim is made that this software is vulnerability-free or malware-free. This review does not change the historically successful executable, source archive, firmware, drivers, or hardware settings.

## Confirmed dependency results

RustSec cargo-audit 0.22.2 completed against all tracked Rust lockfiles:

- Supplier source `engine/Cargo.lock`: **13 advisory matches**, audit exit 1.
- Original archive `source/Cargo.lock`: the same **13 advisory matches**, audit exit 1.
- Original desktop application `source/apps/desktop/src-tauri/Cargo.lock`: **17 advisory matches**, audit exit 1. These overlap with the main lockfile; do not add them together as unique vulnerabilities.
- Dongle boot and firmware lockfiles in both repositories: no vulnerability matches, exit 0; maintenance warnings remain in the reports.

Main-lockfile findings:

| Dependency | Locked version | Advisory matches | Reported patched version covering these matches |
| --- | --- | --- | --- |
| quick-xml | 0.39.4 | RUSTSEC-2026-0194, RUSTSEC-2026-0195 | >=0.41.0 |
| quinn-proto | 0.11.15 | RUSTSEC-2026-0338 through RUSTSEC-2026-0342 | >=0.11.18 |
| rustls | 0.23.41 | RUSTSEC-2026-0285, -0346, -0348, -0349 | >=0.23.46 |
| rustls-webpki | 0.103.13 | RUSTSEC-2026-0382 | >=0.103.16 on the 0.103 line |
| webpki-roots | 1.0.8 | RUSTSEC-2026-0381 | >=1.0.10 |

The desktop lockfile additionally matches webpki-root-certs (RUSTSEC-2026-0383) and zip (RUSTSEC-2026-0367, -0368, -0369). The latter reports a fix in zip >=9.0.0, a major-version change requiring compatibility review.

The original pnpm workspace audit completed and returned **40 advisory entries: 16 high, 19 moderate, 5 low, 0 critical**. Affected package names include esbuild, sharp, postcss, undici, nanoid, devalue, source-map-js and vite. This archived JavaScript workspace is not included in the supplier source package.

These are dependency-version matches. They do not establish runtime reachability, feature activation, exploitation on the tested Mac, or inclusion of each affected component in the archived executable. RustSec also reports maintenance and soundness warnings, which must be reviewed separately.

## Evidence

- [Supplier initial scan run](https://github.com/SteinOA/DSSA-Mac-mini-M4-Restore/actions/runs/40238818262): Rust audit artifact `rust-advisory-results`.
- [Original archive initial scan run](https://github.com/SteinOA/DSSA-restorekit-macmini-m4/actions/runs/40238821068): Rust and JavaScript audit artifacts.
- Artifacts expire after 14 days; retain reports needed for a release decision.

The first ClamAV job failed before scanning because the update daemon held its log lock. This was a scanner setup error, not a malware detection. The workflow has been corrected to stop that disposable runner's updater before refreshing signatures. Its replacement result must be checked separately.

The first full secret scan was slow on bundled regression data. A subsequent configuration bounds runtime and target size and disables archive expansion. Limits are documented in [SECURITY-CHECKS.md](SECURITY-CHECKS.md); no clean secret-scan or malware result is asserted by this initial dependency report.

## Follow-up

1. Keep the verified historical archive intact; do not auto-merge changes merely to make checks green.
2. Review advisory applicability, enabled features, native C library versions, and all maintenance/soundness warnings.
3. Upgrade affected dependencies in maintained evaluation source, rebuild, and run relevant regression and integration tests. Any hardware-validation claim needs a separate physical pilot.
4. Review actual replacement malware/secret-scan results, and repeat checks on the exact binary intended for download, recording SHA-256 and scanner/database versions.
5. Confirm GitHub repository-level dependency alerts separately from the committed Dependabot version-update configuration.

This is an engineering review record, not release approval.
