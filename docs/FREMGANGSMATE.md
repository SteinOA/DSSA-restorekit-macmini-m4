# Teknisk fremgangsmåte: Mac mini M4 fra Windows

Denne veiledningen beskriver fremgangsmåten som ga en vellykket gjenoppretting 24. oktober 2026, og hva en teknisk bruker må tilpasse for å prøve den på sin egen maskin. Resultatet var macOS 15.6.1 (24G90) på en Mac mini M4 (Mac16,10) med en ny, tom 2 TB-modul fra Expand Mac mini. Ingen ekstra Mac ble brukt.

**Full Restore sletter innholdet på målmaskinens installerte SSD.** Dette er en teknisk veiledning basert på ett dokumentert oppsett. Den medfølgende EXE-filen og skriptene er maskinspesifikke; en annen Mac krever tilpasning og ny bygging.

## 1. Før SSD-bytte: sikkerhetskopi og Apple-konto

Ta en sikkerhetskopi som du har kontrollert at du kan lese. Kontroller at du kjenner Apple-kontoen og kan logge inn. Slå av Finn Mac før demontering når du har tilgang til macOS: Systeminnstillinger → navnet ditt → iCloud → Se alle → Finn Mac.

**Aktiveringslås er knyttet til Mac-en og Apple-kontoen, ikke bare SSD-en.** SSD-bytte eller Restore omgår ikke låsen. Hvis Mac-en allerede er demontert eller ikke starter, følg Apples fremgangsmåte for egen enhet. Veiledningen krever ikke at Apple-passord legges inn i RestoreKit.

FileVault er en annen funksjon: den beskytter tilgangen til diskens data. Ikke forveksle den med Aktiveringslås eller anta at det er nødvendig å dekryptere den gamle SSD-en for å installere macOS på en tom erstatningsmodul.

Kilder: [Apple om Aktiveringslås](https://support.apple.com/en-gb/102541), [Apple om FileVault](https://support.apple.com/guide/mac-help/turn-off-filevault-on-mac-mchlp2560/mac). Følg [modulleverandørens demonterings- og monteringsveiledning](https://expandmacmini.com/pages/diy-guide). Vanlige PC-NVMe-disker er ikke automatisk kompatible med Mac-ens modulplass.

## 2. Skaff kildekode, verktøy og firmware

Bruk Windows x64, administratorrettigheter for driveroppsett og en USB-C-datakabel direkte mellom PC-en og Mac-ens DFU-port. Sett av plass til kildekode, bygging, IPSW og utpakkede firmwarefiler.

Klon repoet til en kort sti, for eksempel:

```powershell
git clone https://github.com/SteinOA/DSSA-restorekit-macmini-m4.git C:\src\dssa-restorekit
Set-Location C:\src\dssa-restorekit
```

Les [BUILD.md](../BUILD.md) for MSYS2 UCRT64, GNU-host Rust og nødvendige byggverktøy. Vendor-koden i `source/` inneholder lokale endringer; ikke erstatt den med nye submoduler. `archives/source-snapshot.zip` og `source-manifest.json` dokumenterer den opprinnelige kildekopien.

Firmwarefilen som ble brukt, var `UniversalMac_15.6.1_24G90_Restore.ipsw`. [Firmwaremetadata](firmware-metadata.json) inneholder Apples nedlastingsadresse, filstørrelse og kontrollsummer. Feltet `signed: true` er historisk og bekrefter ikke dagens signeringsstatus. En annen macOS-versjon er ikke automatisk validert av dette forsøket.

Kontroller nedlastingen i PowerShell:

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath 'C:\sti\til\UniversalMac_15.6.1_24G90_Restore.ipsw'
```

Registrert SHA-256: `3d87686b691ac765eb6a6b3082b2334e2af9710096a00432dd519af89ff2ea78`.
Registrert størrelse: 16 814 137 790 byte. Ikke fortsett ved avvik.

## 3. Tilpass målmaskinen og lokale stier

Den ferdige `bin/windows-x64/restorekit.exe` er referanseprogrammet fra forsøket. Det godtar én bestemt restore-identitet. Å endre bare `--ecid` gjør det ikke brukbart på en annen Mac.

| Sted | Tilpasning som må gjennomgås |
| --- | --- |
| `source/crates/restorekit-sys/vendor/usbmuxd/src/restore_identity.h` | `rk_authorized_restore_serial` inneholder tillatt restore-serienummer. Bind til din kontrollerte målmaskin; ikke erstatt sjekken med «godta alle». |
| `ops/restore-apple-attempt9.ps1` | ECID, modellkontroll, CPID/BDID, fysisk USB-plassering, Apple-driveres OEM-navn/kontrollsummer, programsti og firmwaresti. |
| `ops/run-single-attempt9.ps1` | Programsti, prosessgjenkjenning med ECID og eksakt frakoblet enhets-ID brukt ved opprydding. |
| `ops/mac1905-temporary-common.ps1` og øvrige driver-/oppryddingsskript | Pakkesti, sertifikat/pakkeidentitet, beskyttede Apple-drivere og eksakte enhetsoppføringer. |

DFU-ECID, restore-serienummer og Windows-enhetssti er ulike verdier. Ikke utled én av de andre uten verifikasjon. De må innhentes og kontrolleres for den faktiske maskinen og USB-modusen. Arkivet har ikke en automatisk funksjon som samler og konfigurerer alle disse verdiene for en ny Mac.

Skriptene forventer blant annet programmet under `ops/restorekit-source/target/...`, firmware under `ops/firmware/` og driverpakken under `outputs/Mac1905-driver/pakke/`. Repoets eksport har kildekode under `source/` og driverpakken under `driver/pid1905/`. Tilpass stiene konsekvent i din arbeidskopi.

Søk gjennom kildekode og skript etter de gamle identitetsverdiene før bygging. Oppdater relevante testdata slik at riktig identitet godtas og feil identitet fortsatt avvises. La de historiske resultatfilene stå som dokumentasjon av det opprinnelige forsøket.

## 4. Bygg og kontroller programmet

Følg byggekommandoene i [BUILD.md](../BUILD.md) i MSYS2 UCRT64. Bruk et rent byggemiljø; gamle native biblioteker kan ellers gjenbrukes. `--offline` forutsetter at Rust-avhengighetene allerede finnes i lokal cache.

To egenskaper er sentrale i denne løsningen:

- DFU, Recovery og KIS bruker Apples native Windows-drivere.
- Siste restore-modus, PID 1905, bruker en separat lokal mux på `127.0.0.1:27016`. Apples tjeneste på port 27015 beholdes.

[Portrettelsen](NATIVE-PORT-RETTELSE.txt) forklarer hvorfor den faktiske C-klienten må bruke port 27016, og hvorfor en separat Rust-socket-test ikke var tilstrekkelig.

Kjør identitets-/regresjonstestene fra BUILD.md. Kontroller deretter CLI og mux i separate prosesser, med programstien fra ditt bygg:

```powershell
& $restoreExe --help
& $restoreExe check-usb
```

Her må `$restoreExe` først settes til den fulle stien til ditt nybygde program. `check-usb` laster ikke opp firmware eller sletter disken, men kan initialisere USB-konfigurasjon/grensesnitt hvis den godkjente PID1905-enheten er tilkoblet. Bestått kontroll beviser ikke en full gjenoppretting.

Registrer SHA-256 for ditt bygg. Det vil ikke nødvendigvis ha samme kontrollsum som det arkiverte programmet. Et uavhengig rent bygg og gjenoppretting på en annen Mac er ikke dokumentert i dette arkivet.

## 5. Klargjør driverne før gjenopprettingen

Det vellykkede forsøket beholdt Apples drivere og Apple Devices-tjenesten. Den opprinnelige brede `setup-driver`-kommandoen ble ikke brukt.

Den avgrensede INF/CAT-pakken i [driver/pid1905](../driver/pid1905/) matcher bare `USB\VID_05AC&PID_1905` og bruker Windows' innebygde `winusb.sys`. Pakken er lokalt signert, ikke godkjent av Apple eller Microsoft.

Slik var rekkefølgen i forsøket:

1. Registrer eksisterende drivere, Apple-driveres kontrollsummer og sertifikatstatus.
2. Klargjør den smale PID1905-pakken mens Apple USB-enheter er frakoblet.
3. Legg pakkens kontrollerte offentlige sertifikat midlertidig i `LocalMachine/Root` og `LocalMachine/TrustedPublisher`, og legg INF-pakken i driverlageret.
4. Registrer det faktiske publiserte OEM-navnet for senere opprydding.
5. Kontroller at Apples drivere er uendret.

Implementasjonen finnes i [prepare-mac1905-temporary.ps1](../ops/prepare-mac1905-temporary.ps1) og [fellesfunksjonene](../ops/mac1905-temporary-common.ps1). Uten bryteren `-ApplyAfterUserApproval` inspiserer forberedelsesskriptet pakken; med bryteren endrer det systemet. Les og tilpass skriptene før bruk.

Dette innebærer faktisk sertifikattillit på PC-en. Den historiske private nøkkelen er ikke med. Endrer du INF-filen, gjelder ikke den gamle CAT-signaturen for den endrede filen. Verken avslått signaturkontroll, testsignering eller avslått antivirus inngikk i det vellykkede forsøket.

## 6. Koble til og sett Mac-en i DFU

Bruk riktig DFU-port for modellen, se [Apples portoversikt via DFU-veiledningen](https://support.apple.com/en-us/108900). Koble datakabelen direkte til PC-en og fjern øvrige USB-enheter fra Mac-en.

For stasjonær Mac: koble fra strøm, hold strømknappen inne, koble strømmen til igjen og fortsett å holde knappen i opptil ti sekunder. Skjermen forblir svart i DFU. Apples veiledning bruker en annen Mac og Finder; i dette prosjektet kontrolleres gjenkjenningen fra Windows:

```powershell
& $restoreExe --json list
```

Kontroller at nøyaktig én målmaskin vises, med riktig modell, ECID og `dfu`-modus. Ved avvik: rett kabel, port, driver eller identitetsoppsett før firmware sendes. Ikke fjern kontrollene for å komme videre.

## 7. Kjør én overvåket gjenoppretting

[Koordinatoren](../ops/run-single-attempt9.ps1) håndterte klargjøring, DFU-venting, én kjøring og opprydding. [Supervisoren](../ops/restore-apple-attempt9.ps1) kontrollerte målmaskin, drivere, programhash, Apple-tjeneste og ledig privat port før start.

Etter tilpasning bruker koordinatoren argumentene:

```text
run-single-attempt9.ps1 -ExpectedHash <SHA256-for-ditt-bygg> -ExpectedAppleMuxHash <SHA256-for-kontrollert-Apple-prosess>
```

Ikke kopier kontrollsummen for Apple-prosessen fra en annen PC. Den skal tilhøre den kontrollerte installasjonen på din PC.

Den underliggende restore-kommandoen hadde denne formen:

```text
restorekit.exe --verbose restore --ipsw "<IPSW-sti>" --ecid <målmaskinens-ECID> --yes --cache-dir "<cachemappe>"
```

**Dette er den slettende kommandoen. `--yes` forhåndsbekrefter handlingen.** Eksemplet viser hva supervisoren startet; det erstatter ikke kontrollene eller oppryddingen rundt kjøringen.

Hold PC-en våken og strøm/kabel tilkoblet. Bevar standardutdata, feillogg og supervisorlogg. Ikke bytt driver under kjøringen eller start parallelle restore-prosesser. Koordinatoren må vente på at den faktiske restore-prosessen er ferdig før den fjerner driver eller tillit, også hvis overvåkingen feiler.

## 8. Bekreft resultat og rydd opp

I det dokumenterte forsøket var resultatet avslutningskode 0, «Restore Finished», 133 fullførte kontrollpunkter med resultat 0 og deretter synlig macOS-oppsettsassistent. Tiden var 10 minutter og 55 sekunder; det er et historisk resultat, ikke en tidsfrist for andre forsøk.

Etter at restore-prosessen har avsluttet:

1. Kontroller at privat port 27016 ikke lenger lytter og at Apples tjeneste på 27015 er beholdt.
2. Fjern bare den midlertidige pakken og sertifikattilliten som dette forsøket la til.
3. Hvis en frakoblet enhetsoppføring hindrer pakkefjerning, bekreft eksakt identitet og at den ikke er til stede. Ikke slett andre enheter eller drivere.
4. Kontroller sluttstatus også etter feil. En feilet restore skal ikke automatisk starte på nytt.
5. Fullfør macOS-oppsettet og bekreft oppstart og lagringskapasitet.

Se [oppryddingsskriptet](../ops/cleanup-mac1905-temporary.ps1), [sluttresultatet](FORSOK9-RESULTAT.txt) og [maskinlesbare kontrollpunkter](../results/attempt9-restore-result.json). Eldre forslag og arbeidsnotater beskriver status på tidspunktet de ble skrevet, ikke nødvendigvis sluttresultatet.

## Videre arbeid: en Windows-veiviser

De manuelle instruksjonene kan bli skjermbilder i en veiviser:

| Trinn brukeren ser | Kontroll programmet bør utføre |
| --- | --- |
| Sikkerhetskopi og Apple-konto | Be om bekreftelse; ikke påstå at Aktiveringslås er kontrollert hvis status ikke kan leses. |
| Koble til Mac-en | Finn enhet og vis modell/identitet for bekreftelse. |
| Klargjør firmware og driver | Kontroller filintegritet og dokumenter nødvendige systemendringer. |
| Hold inne strømknappen og koble til strøm | Vent på riktig DFU-enhet og vis når den er funnet. |
| Bekreft sletting og start | Bind kjøringen til valgt maskin; blokker feil eller tvetydig mål. |
| Gjenoppretting pågår | Vis milepæler, logg og relevante feilmeldinger. |
| Ferdig og oppryddet | Verifiser prosess- og driveropprydding, og be brukeren bekrefte macOS-oppstart. |

Dette er en plan for brukergrensesnitt og automatisering av den dokumenterte arbeidsflyten, ikke funksjoner som allerede finnes i arkivet. Veiviseren skal ikke samle Apple-passord eller omgå Aktiveringslås.
