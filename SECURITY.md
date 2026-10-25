# Security Policy

## Project status and supported versions

This repository documents Windows-based Mac mini M4 restore tooling, not a generally validated consumer release. Reports are reviewed against the current `main` commit; older snapshots have no promised maintenance period. There is no guaranteed response or remediation deadline.

One physical restore was verified on a Mac mini M4 (Mac16,10) with an Expand Mac mini 2 TB replacement module. This does not constitute a security audit, malware certification, or validation of other hardware combinations.

## Reporting a vulnerability

Contact Stein Aune / DSSA privately through the existing email or contact channel used to arrange your repository access. Request a private reporting channel before sending exploit details if you do not already have one. A dedicated public security mailbox has not been designated.

Do not post sensitive reports in public issues, pull requests, or third-party forums. GitHub's private vulnerability reporting feature must not be assumed to be enabled. Repository access is limited, but repository issues are visible to other collaborators and are not a confidential reporting channel.

Include the affected commit or file, Windows version, relevant device and driver versions, expected and actual behavior, impact, and minimal reproduction steps. Redact passwords, tokens, signing material, serial numbers, ECIDs, personal paths, and personal data. Do not upload firmware images or memory dumps unless requested through an agreed secure channel.

Reports about upstream components will be assessed for applicability and, where appropriate, coordinated with the upstream maintainers. Please coordinate disclosure with the maintainer while a report is assessed; this request does not alter the software licenses.

## Malware detections and safe evaluation

If antivirus or Windows security software reports a detection, stop execution, retain the detection name and SHA-256 hash, and report it privately. A detection must not be dismissed as a false positive without investigation. Do not disable antivirus, SmartScreen, signature checks, or other operating-system protections to run this package.

Restore operations can erase the target Mac. Use a backed-up test machine and verify the target identity before starting. Firmware must come from an authorized Apple source. Apple firmware and private signing keys must not be committed. The original historical archive includes a public driver-signing certificate in its CAT package; that is not a private key or evidence of current Windows trust.

## Assurance and licensing boundaries

This policy describes reporting and evaluation practices. The Security checks workflow configures RustSec lockfile audits, redacted Gitleaks history/file scans, and ClamAV file/archive scanning; the original archive additionally audits its pnpm lockfile. Dependabot configuration proposes dependency updates without automatically merging them. Configuration alone is not evidence that scans have run or passed. Reports and actual workflow conclusions are the evidence. Any future release must state its actual checks and limitations separately.

Security policy, repository privacy, and copyright attribution do not impose a resale ban or replace the applicable Apache, GPL, LGPL, BSD, or other third-party license terms. See `NOTICE`, `LICENSE`, and `engine/NOTICE`.
