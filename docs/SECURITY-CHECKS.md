# Security checks: scope and interpretation

The root `.github/workflows/security-checks.yml` configures read-only scans on relevant pushes to main, pull requests, manual dispatch, and a weekly Monday schedule. Reports are stored as private Actions artifacts for 14 days. Job failure is retained when a tool reports findings or cannot complete; failures are not silently ignored.

## Configured checks

| Check | Scope | Important limit |
| --- | --- | --- |
| Gitleaks 8.30.1 | Fetched Git history and current checkout, with 180-second limits per scan and a 2 MiB target limit; matched secrets are redacted | Archive expansion is disabled for secret scanning to avoid pathological vendor regression archives. Large targets are skipped. Pattern detection is incomplete; a clean result does not prove absence of credentials. |
| cargo-audit 0.22.2 / RustSec | Every tracked Cargo.lock, inspected from outside the project directory without executing project build scripts | Does not audit vendored C libraries or prove exploitability; warnings and reports require review. |
| ClamAV | Current checkout and archive contents, with refreshed signatures | Signature-based detection; not a malware-free certification. File limit 256 MiB, cumulative archive scan limit 512 MiB; exclusions and errors must be reviewed. |
| pnpm audit (original archive only) | Archived JavaScript workspace lockfile, including development tools | Advisory matches do not prove the Windows executable contains or reaches the vulnerable code. Uses the npm audit service for dependency metadata, not source-code upload. |
| Existing identity tests | Pure-data regression and malformed-input tests for the modified C target-identity parser | Not a full static analysis or a hardware restore test. |

The workflow does not run restore operations or install this project's USB drivers. It does not execute the archived Windows executable. Scanner installation happens on disposable GitHub-hosted runners, not on the owner's Mac or Windows PC. No VirusTotal upload is configured.

## Dependency update proposals

`.github/dependabot.yml` configures weekly Cargo and GitHub Actions updates; the original archive also includes its pnpm workspace. Dependabot only proposes pull requests. It does not merge updates, validate hardware, or justify silently changing the historical source snapshot. Keep the verified archive, manifests, and binary provenance intact; evaluate runtime dependency upgrades separately in maintained source.

Dependabot version-update configuration is distinct from GitHub's repository-level dependency graph, vulnerability alerts, and security-update switches. Their state must be checked separately. Adding these files does not enable paid GitHub Code Security/Secret Protection products or make a private repository public.

## Remaining review

Vendored native C dependency versions and advisories, application logic, Windows driver handling, code signing, and release-binary reproducibility still require their own review. A dependency audit or antivirus pass does not certify any of these. The original archived ZIP is inspected for malware within scanner limits. It is not expanded by the bounded secret scan, and its embedded lockfiles are not independently enumerated for dependency auditing.

For a downloadable release, retain the exact commit, executable SHA-256, scanner/database versions, result links and unresolved findings. Re-run release checks when binaries change. Do not advertise a release as safe solely because a dashboard is green.

See [SECURITY.md](../SECURITY.md) for private reporting and destructive-restore precautions.
