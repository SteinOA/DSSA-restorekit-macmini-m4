# DSSA – Mac mini M4 gjenopprettet fra Windows

**Vellykket gjenoppretting uten en ekstra Mac.** Dette repoet dokumenterer hvordan en Mac mini M4 (2024, Mac16,10) med en ny, tom 2 TB SSD ble gjenopprettet fra en Windows x64-PC. Mac-en startet deretter i macOS-oppsettsassistenten, og oppstarten ble bekreftet med bilder.

Forsøk 9 fullførte gjenopprettingen av macOS 15.6.1 (24G90) med avslutningskode 0. Her er kildekoden, de lokale rettelsene og resultatene fra arbeidet samlet.

Resultatet gjelder den konkrete maskinen og programversjonen som ble brukt. Den arkiverte programversjonen er låst til denne enhetens identitet; andre Mac-maskiner er ikke verifisert av DSSA. Arkivet inneholder enhetsspesifikke opplysninger fra forsøket.

**Sikkerhetsgjennomgang gjenstår:** Skanningene fant kjente sårbarhetsvarsler i avhengigheter. Se [faktiske resultater og gjenstående arbeid](docs/SECURITY-REVIEW-2026-10-25.md) før en ny brukerpakke bygges eller deles.

## Slik ble det gjort

Se [den tekniske fremgangsmåten](docs/FREMGANGSMATE.md) for forberedelser, bygging, maskintilpasning, driveroppsett, DFU, overvåket gjenoppretting og opprydding.

For videre arbeid på en utgave som velger målmaskin per kjøring, se også [DSSA-Mac-mini-M4-Restore](https://github.com/SteinOA/DSSA-Mac-mini-M4-Restore). Det repoet inneholder den generaliserte utviklingsutgaven; dette arkivet dokumenterer det fysisk vellykkede forsøket.

## Før Mac-en åpnes: sikkerhetskopi, Aktiveringslås og sletting

**Denne fremgangsmåten er beregnet på å gjenopprette macOS til en tom erstatnings-SSD. Den bevarer ikke data og er ikke et klone- eller dataredningsverktøy. En full DFU-gjenoppretting sletter alle data på SSD-en som er installert i mål-Mac-en. Hvis den gamle SSD-en er installert som mål, slettes også dataene på den. Ta og kontroller sikkerhetskopi før du slår av maskinen og bytter SSD.**

[Leverandørens bruksanvisning](https://expandmacmini.com/pages/diy-guide) advarer om at prosedyren sletter alle data på Mac mini, og at data på den opprinnelige SSD-en vil være utilgjengelige etter byttet og fullført gjenoppretting. Ikke regn med å sette inn den gamle SSD-en igjen som sikkerhetskopi eller for å finne Apple-kontoen etterpå.

Før maskinen åpnes, ber leverandøren eieren kontrollere den nøyaktige e-postadressen til Apple-kontoen og logge ut i Systeminnstillinger. Kontroller selv at du kan logge inn på kontoen. Ikke del passord eller legg dem i repoet.

[Apple forklarer Aktiveringslås og hvordan den slås av](https://support.apple.com/en-ie/102541): Slå av Finn Mac under Systeminnstillinger → navnet ditt → iCloud → Se alle → Finn Mac, og godkjenn selv når du blir bedt om det. Aktiveringslås er noe annet enn FileVault-diskkryptering. Den lenkede leverandørveiledningen sier ikke at FileVault må slås av. SSD-bytte og dette programmet kan ikke omgå Aktiveringslås.

Gjør disse kontrollene før avslåing og demontering.

Se [resultatet](docs/FORSOK9-RESULTAT.txt) og [kontrollpunktene](results/attempt9-restore-result.json). Den konkrete native Windows-portfeilen er rettet og testet før det vellykkede forsøket; [rettelsen er dokumentert her](docs/NATIVE-PORT-RETTELSE.txt).

Etter det vellykkede forsøket ble den midlertidige driverpakken, sertifikattilliten og den private nøkkelen fjernet. Apples drivere og tjeneste ble beholdt, og Windows-beskyttelsen var på. Detaljene er bevart i [arbeidsnotatet fra forsøket](docs/FORTSETT-HER-I-KVELD.txt).

## Innhold i repoet

- `source/`: komplett kildekode fra RestoreKit v0.5.13 med lokale rettelser og innholdet i alle vendor-moduler.
- `archives/source-snapshot.zip`: samme 2 133 kildefiler med nøyaktige opprinnelige byte. Bruk dette arkivet når kontrollsummene i `source-manifest.json` skal sammenlignes; enkelte vendor-moduler har egne Git-regler for linjeskift.
- `patches/`, `provenance.json`, `source-manifest.json`: opprinnelse, endringer, lisenser og kontrollsummer.
- `bin/windows-x64/restorekit.exe`: ferdig Windows-program, SHA256 `B59206BC8E7046FF696A87DF029BD919BCD6659E06E82D11DD940F67126D2F93`.
- `ops/`: klargjorte skript for ett overvåket forsøk og etterfølgende opprydding. De er tilpasset det opprinnelige lokale oppsettet og er ikke generelle installasjonsskript for en ny kloning av repoet.
- `driver/pid1905/`: kun den avgrensede INF/CAT-pakken for siste restore-modus. CAT inneholder det eksisterende offentlige signeringssertifikatet. Ingen privat signeringsnøkkel er bevart eller lastet opp. Historisk signaturkontroll betyr ikke at sertifikatet nå er betrodd på PC-en.
- `results/`: programtesten, oppryddingsbevis og faktiske GitHub Actions-resultater.
- `history/`: eldre skript som dokumentasjon, lagret som tekst; de skal ikke kjøres.

Midlertidige drivere og sertifikattillit krever opprydding etter bruk, også ved feil. Ikke bruk den opprinnelige brede `setup-driver`-kommandoen.

Firmware (IPSW), private nøkler, innloggingsopplysninger og lokale sertifikatlagre inngår ikke i distribusjonen.

## Hva de automatiske testene viser

Identitetsparseren og regresjonstestene er testet på Ubuntu 24.04 med GCC og Clang, inkludert AddressSanitizer og UndefinedBehaviorSanitizer, og på Windows Server 2022 med MSVC. Tre separate testkjøringer bruker ulike deterministiske startverdier og tester 100 000 tilfeller med ugyldige inndata hver.

Dette er programvaretester uten tilgang til USB-enheter, drivere, sertifikatlagre, firmware eller Mac-maskinvare. De kontrollerer parserens oppførsel og minnehåndtering. Den fysiske gjenopprettingen er dokumentert separat i resultatene fra forsøk 9.

`source-provenance.json` inneholder SHA-256-kontrollsummer for den kopierte produksjonsheaderen og de opprinnelige testdataene. Testarbeidsflytene har lesetilgang (`contents: read`), en grense på ti minutter per jobb og bruker ingen repository secrets.

## Diskmåling og ønsket enkel brukerpakke

[Én måleøkt og krav til en veiledet Windows-pakke](docs/STORAGE-TEST-AND-USER-PACKAGE.md) dokumenterer 2 TB-modulen fra Expand Mac mini, resultatene for alle tre disker og testens begrensninger. En enkel nedlastbar brukerpakke med grundig veiledning er et utviklingsmål, ikke en allerede verifisert ettklikksløsning. Andre SSD-moduler er foreløpig ikke testet.

## Sikkerhet og automatiske kontroller

Se [sikkerhetspolicyen](SECURITY.md) for privat rapportering og [kontrollenes omfang og begrensninger](docs/SECURITY-CHECKS.md). Faktiske resultater ligger under [GitHub Actions](https://github.com/SteinOA/DSSA-restorekit-macmini-m4/actions). En konfigurert kontroll er ikke det samme som en bestått kontroll. Avhengighetsoppdateringer foreslås i pull requests; de flettes ikke automatisk inn i dette historiske arkivet.
