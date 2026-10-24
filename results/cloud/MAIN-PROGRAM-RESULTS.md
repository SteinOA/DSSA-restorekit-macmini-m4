# Faktisk hovedprogram: skytester bestått

Privat repo: https://github.com/SteinOA/DSSA-restorekit-macmini-m4
Testet full kildekode-/binær-snapshot: `eb971be5c11457e83cb29b132b1d260eb461dd52`.

## Hovedprogrammet på tre separate Windows-maskiner

Kjøring: https://github.com/SteinOA/DSSA-restorekit-macmini-m4/actions/runs/40059588962

Alle tre Windows Server 2022-jobber bestod. De kjørte det faktiske gjennomgåtte hovedprogrammet med `--json check-usb`, ikke en erstatning eller en modell.

SHA-256 kontrollert i alle tre jobber:
`B908AC86D7ECDAA09A16512B19AAD042C8E955F6F76C1D1DE6F9F3A921EAC278`

| Replika | Kontrolltid | Exit-kode | Privat port 27016 borte | Port 27015 uendret |
| --- | ---: | ---: | --- | --- |
| 1 | 0,37 s | 0 | Ja | Ja |
| 2 | 0,31 s | 0 | Ja | Ja |
| 3 | 0,36 s | 0 | Ja | Ja |

Alle returnerte `usb_check_passed`, `firmware_uploaded=false` og `data_erased=false`. Ingen Apple USB-/KIS-enhet var tilkoblet. Kontrollen prøvde lokal tjenestestart, ListDevices-protokoll og avslutning. Sammenligningen av port 27015 betyr at eksisterende tilstand ble beholdt; den krever ikke at Apples tjeneste er installert på sky-maskinen.

Sju operasjonsskript ble i hver replika kun syntakskontrollert med AST-parseren i Windows PowerShell 5.1 og PowerShell 7. Alle seks parser-kjøringer bestod, totalt 42 skript/språkversjon-kontroller. Ingen operasjonsskript ble utført. Observerte versjoner: 5.1.20348.5622 / 5.1.20348.5756 og 7.6.6 / 7.6.8.

## Parser-testene på samme fulle snapshot

Kjøring: https://github.com/SteinOA/DSSA-restorekit-macmini-m4/actions/runs/40059589027

Alle ni jobber bestod på samme commit: Ubuntu 24.04 GCC og Clang med AddressSanitizer/UndefinedBehaviorSanitizer samt Windows Server 2022 MSVC, hver med tre frø. Hver jobb kjørte produksjonsfiksturer og 100 000 deterministiske malformed-input/orakel/canary-tilfeller: 900 000 tilfeller på dette snapshotet.

## Avgrensning

Ingen driverinstallasjon, sertifikat-/nøkkeloperasjon, signaturkontroll, sikkerhetsendring, firmwareopplasting, sletting eller fysisk Mac-gjenoppretting inngikk i skytestene. Dette dokumenterer hovedprogrammets lokale mux-start/protokoll/avslutning og parserens programvareegenskaper. Det beviser ikke kommunikasjon med Mac-en, vellykket gjenoppretting eller oppstart av macOS.

Detaljbevis: `main-github-actions-results.json`, `main-test-evidence.txt` og `full-snapshot-parser-results.json`.
