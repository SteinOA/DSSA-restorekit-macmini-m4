# DSSA – Mac mini M4 restore fra Windows

Privat arkiv for en **vellykket gjenoppretting fra Windows** av Mac mini M4 (Mac16,10) med ny tom2TBSSD. Forsøk9 fullførte macOS15.6.1/24G90 med exit0, og brukeren har bekreftet oppstart med bilder av oppsettsassistenten.

## Før Mac-en åpnes: sikkerhetskopi, Aktiveringslås og sletting

**Denne fremgangsmåten er beregnet på å gjenopprette macOS til en tom erstatnings-SSD. Den bevarer ikke data og er ikke et klone- eller dataredningsverktøy. En full DFU-gjenoppretting sletter alle data på SSD-en som er installert i mål-Mac-en. Hvis den gamle SSD-en er installert som mål, slettes også dataene på den. Ta og kontroller sikkerhetskopi før du slår av maskinen og bytter SSD.**

[Leverandørens bruksanvisning](https://expandmacmini.com/pages/diy-guide) advarer om at prosedyren sletter alle data på Mac mini, og at data på den opprinnelige SSD-en vil være utilgjengelige etter byttet og fullført gjenoppretting. Ikke regn med å sette inn den gamle SSD-en igjen som sikkerhetskopi eller for å finne Apple-kontoen etterpå.

Før maskinen åpnes, ber leverandøren eieren kontrollere den nøyaktige e-postadressen til Apple-kontoen og logge ut i Systeminnstillinger. Kontroller selv at du kan logge inn på kontoen. Ikke del passord med leverandøren, i repoet eller i chatten.

[Apple forklarer Aktiveringslås og hvordan den slås av](https://support.apple.com/en-ie/102541): Slå av Finn Mac under Systeminnstillinger → navnet ditt → iCloud → Se alle → Finn Mac, og godkjenn selv når du blir bedt om det. Aktiveringslås er noe annet enn FileVault-diskkryptering. Den lenkede leverandørveiledningen sier ikke at FileVault må slås av. SSD-bytte og dette programmet kan ikke omgå Aktiveringslås.

Gjør disse kontrollene før avslåing og demontering. Denne dokumentasjonsendringen endrer ingen konto-, krypterings- eller sikkerhetsinnstillinger.

Se [resultatet](docs/FORSOK9-RESULTAT.txt) og [kontrollpunktene](results/attempt9-restore-result.json). Den konkrete native Windows-portfeilen er rettet og testet før det vellykkede forsøket; [rettelsen er dokumentert her](docs/NATIVE-PORT-RETTELSE.txt).

PC-oppryddingen er fullført: midlertidig driverpakke, sertifikattillit og privat nøkkel er borte. Apples drivere og tjeneste er beholdt. Windows-beskyttelsen er på. [Fortsettelsesnotatet](docs/FORTSETT-HER-I-KVELD.txt) har eksakt status. Ingen ny restore skal startes.
- `source/`: komplett kildekode fra RestoreKit v0.5.13 med lokale rettelser og innholdet i alle vendor-moduler.
- `archives/source-snapshot.zip`: samme 2 133 kildefiler med nøyaktige opprinnelige byte. Bruk dette arkivet når kontrollsummene i `source-manifest.json` skal sammenlignes; enkelte vendor-moduler har egne Git-regler for linjeskift.
- `patches/`, `provenance.json`, `source-manifest.json`: opprinnelse, endringer, lisenser og kontrollsummer.
- `bin/windows-x64/restorekit.exe`: ferdig Windows-program, SHA256 `B59206BC8E7046FF696A87DF029BD919BCD6659E06E82D11DD940F67126D2F93`.
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

## Diskmåling og ønsket enkel brukerpakke

[Én måleøkt og krav til en veiledet Windows-pakke](docs/STORAGE-TEST-AND-USER-PACKAGE.md) dokumenterer 2 TB-modulen fra Expand Mac mini, resultatene for alle tre disker og testens begrensninger. En enkel nedlastbar brukerpakke med grundig veiledning er et utviklingsmål, ikke en allerede verifisert ettklikksløsning. Andre SSD-moduler er foreløpig ikke testet.
