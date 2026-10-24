# DSSA – Mac mini M4 restore fra Windows

Privat arkiv for arbeidet med en Mac mini M4 (Mac16,10) med tom intern 2 TB SSD. **macOS er ennå ikke installert.** Neste fysiske forsøk er utsatt til brukeren kommer tilbake i kveld.

Start med [fortsettelsesnotatet](docs/FORTSETT-HER-I-KVELD.txt). Program, kildekode, rettelser, kontrollskript og testresultater er bevart, slik at vi kan fortsette fra denne tilstanden.

- `source/`: komplett kildekode fra RestoreKit v0.5.13 med lokale rettelser og innholdet i alle vendor-moduler.
- `archives/source-snapshot.zip`: samme 2 133 kildefiler med nøyaktige opprinnelige byte. Bruk dette arkivet når kontrollsummene i `source-manifest.json` skal sammenlignes; enkelte vendor-moduler har egne Git-regler for linjeskift.
- `patches/`, `provenance.json`, `source-manifest.json`: opprinnelse, endringer, lisenser og kontrollsummer.
- `bin/windows-x64/restorekit.exe`: ferdig Windows-program, SHA256 `B908AC86D7ECDAA09A16512B19AAD042C8E955F6F76C1D1DE6F9F3A921EAC278`.
- `ops/`: klargjorte skript for ett overvåket forsøk og etterfølgende opprydding. De forutsetter den eksisterende lokale arbeidsmappens oppsett; ikke kjør dem direkte fra et nytt Git-klone uten å lese notatet.
- `driver/pid1905/`: kun den avgrensede INF/CAT-pakken for siste restore-modus. CAT inneholder det eksisterende offentlige signeringssertifikatet. Ingen privat signeringsnøkkel er bevart eller lastet opp. Historisk signaturkontroll betyr ikke at sertifikatet nå er betrodd på PC-en.
- `results/`: programtesten, oppryddingsbevis og faktiske GitHub Actions-resultater.
- `history/`: eldre skript som dokumentasjon, lagret som tekst; de skal ikke kjøres.

Etter forsøk 6 ble oppdragets sertifikat, private nøkkel og nye driverpakke bekreftet borte. Windows-beskyttelsen er på. Senere midlertidig tillit/driverklargjøring må følge den avtalte godkjenningen og ryddes bort etter forsøket, også ved feil. Ikke bruk den opprinnelige brede `setup-driver`-kommandoen.

Firmwarefilen er allerede bevart lokalt. IPSW, lokale sertifikatlagre, private nøkler, innloggingsopplysninger og rå PC-inventarer lastes ikke opp. Dette repoet starter ingen installasjon automatisk.

## What cloud tests establish

The exact production identity parser and existing regression fixtures are tested on Ubuntu 24.04 (GCC and Clang, AddressSanitizer/UndefinedBehaviorSanitizer) and Windows Server 2022 (MSVC). Three independent replicas use distinct deterministic seeds, each testing 100,000 bounded malformed-input cases against an independent identity oracle and output-buffer canaries.

These are pure-data software tests. They access no USB devices, drivers, certificate stores, firmware or Mac hardware. Passing tests does **not** establish that a physical Mac restoration succeeds, that a Windows driver works, or that macOS boots. No physical restore is scheduled by this repository.

`source-provenance.json` records SHA-256 hashes of the copied production header and original fixtures. Cloud workflow access is read-only (`contents: read`), with a ten-minute limit per job and no repository secrets.

The archived driver CAT contains a public signing certificate, not its private key or any Windows trust store. Do not commit firmware IPSWs, private keys, credentials, local trust-store exports or raw PC inventories. Public release/publication is not authorized.
