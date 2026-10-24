# Historisk driverpakke: Mac mini Restore 1905

**Status etter forsøk 6: Den midlertidige 1905-pakken er fjernet. Alle forekomster av oppdragets sertifikat og tillit er fjernet, og den private nøkkelen finnes ikke. Sluttkontrollen er godkjent.**

Pakken beholdes bare som dokumentasjon. Den skal ikke installeres eller få sertifikattillit gjenopprettet uten ny uttrykkelig godkjenning. Oppføringen «Valid» i det opprinnelige manifestet er et historisk kontrollresultat fra før oppryddingen, ikke bekreftelse på gjeldende tillit.

## Kontrollert historikk etter forsøk 6

Forsøk 6 ble avsluttet uten at macOS-installasjonen var fullført. Sertifikatoppryddingen fjernet tillit og bekreftet at den private nøkkelen ikke fantes. Første normale pakkefjerning ble blokkert av en frakoblet enhetsoppføring som fortsatt brukte pakken. Bare den eksakte Mac-oppføringen `USB\VID_05AC&PID_1905\00008132-001808291EA2401C` ble deretter fjernet, og vanlig pakkefjerning lykkes uten `/force` eller `/uninstall`.

Dokumentasjon:

- [Staging for forsøk 6](Temporary-20261024-051827/result.json): bare den avtalte pakken ble lagt til; ingen privat nøkkel ble gjenskapt.
- [Endelig godkjent opprydding](Cleanup-20261024-052841-cc1b4156/result.json): `Success: true`, ingen gjenværende 1905-pakke, ingen sertifikater, ingen privat nøkkel og ingen uventet slettede driverpakker.
- [Windows' bekreftelse på pakkefjerning](Cleanup-20261024-052841-cc1b4156/driver-removal.txt).

Et foreslått [forsøk 7](FORSOK7-FORSLAG.md) er en ny handling og er ikke godkjent eller startet. Godkjenningen av ett forsøk 6 gjelder ikke videre forsøk.

## Hva den gjelder

INF-filen matcher bare `USB\VID_05AC&PID_1905`, Mac-ens siste USB-modus under gjenoppretting. Den inneholder ingen ekstra SYS-driver. Den ber Windows bruke den innebygde Microsoft-driveren `winusb.sys`.

Apples drivere beholdes for Port DFU, KIS og Recovery. Den brede, tidligere RestoreKit-pakken er fjernet og skal ikke gjeninstalleres.

Se `pakke/macmini_restore_1905.inf`, `pakke/macmini_restore_1905.cat` og `package-manifest.json`. INF SHA256: `96900A82E846BDE1999787C566D8B22DC52D108545B9E76FCAA4DA2F79334E02`.

## Signering og tillit etter opprydding

CAT-filen ble signert med et lokalt, selvsignert RestoreKit-sertifikat. Pakken er ikke signert eller godkjent av Apple eller Microsoft. Historisk signeringssertifikat:

- Navn: `CN=RestoreKit WinUSB`
- Fingeravtrykk: `4AB0DB3E9B0D6D055133E286B3D16F3460FBFB31`
- Sertifikatets opprinnelige utløpsdato: 24. oktober 2027. Dette innebærer ikke at sertifikatet fortsatt er installert eller betrodd.

Sertifikatet er nå fjernet fra alle relevante bruker- og maskinlagre, inkludert rot- og utgiverlagrene. Den tilhørende private signeringsnøkkelen er også fjernet. Den tidligere brede RestoreKit-driverpakken er fjernet. Den nye, smale 1905-pakken ble etter uttrykkelig godkjenning lagt i driverlageret for forsøk 6 og fikk navnet `oem288.inf`. Etter forsøket ble den frakoblede, eksakte Mac-oppføringen fjernet, og deretter ble bare denne pakken slettet. OEM-nummeret var gjenbrukt og identifiserte ikke den gamle brede pakken.

Signatur- og katalogkontrollen «Valid» ble utført før sertifikatoppryddingen. Ingen ny signatur- eller kjedekontroll er kjørt etter oppryddingen, for å unngå at slike kontroller fyller sertifikatbufferen igjen. Det opprinnelige manifestet beholdes uendret som historisk dokumentasjon.

Det skal ikke brukes testsignering, deaktivering av signaturkontroll eller endring av Secure Boot. Et nytt behov for sertifikater eller tillit krever ny uttrykkelig godkjenning. Brukerens krav er at eventuelle midlertidige oppdragssertifikater og private nøkler ryddes bort etter forsøk, både ved feil og ved vellykket gjenoppretting, før arbeidet avsluttes for natten.

## Mulig vei uten eget sertifikat – ikke utført

Microsoft beskriver en manuell metode i Enhetsbehandling: velg «La meg velge» og deretter den innebygde «WinUsb Device» under USB-enheter. Metoden trenger ingen egen INF eller selvsignert tillit. Den krever også en grensesnitt-GUID under den eksakte enhetens `Device Parameters`, og deretter ny tilkobling til samme fysiske port.

Dette er foreløpig et forslag. Det er ikke verifisert at det riktige valget tilbys for denne Mac-en, og ingen slik binding eller registerendring er utført. Mac-ens observerte PID 1905 oppga ikke `USB\MS_COMP_WINUSB`, så automatisk matching mot standarddriveren er ikke bekreftet. Endring av driverbinding eller enhetsregister krever egen uttrykkelig godkjenning.

Kilde: [Microsoft: WinUSB installation](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/winusb-installation).

## USB-tjenesten

Tjenesten kjører som en tråd inne i restoreprogrammet, ikke som en ny permanent Windows-tjeneste. Den lytter bare på `127.0.0.1:27016`, med eksklusiv binding til denne lokale porten. Apples eksisterende prosess på port 27015 beholdes.

USB-tilgangen i denne Windows-utgaven er begrenset til PID 1905 og serienummer `00008132-001808291EA2401C`. Identiteten kontrolleres før USB-modus/configurasjon endres. Ingen firmware lastes opp av testkommandoen `check-usb`.

Tjenesten skal avsluttes med restoreprogrammet. Etter kjøring skal det kontrolleres at prosessen er avsluttet og port 27016 ikke lenger lytter. En socket-test før installasjon bekrefter oppstart, protokollsvar og avslutning; den bekrefter ikke full dataoverføring til Mac-en.

## Logg og tilbakeføring

Den gamle installasjonsplanen gjelder ikke som godkjenning til å installere denne historiske pakken. Før en eventuell senere, særskilt godkjent installasjon skal driverlisten og Apples driverkontrollsummer loggføres. Kun denne eksakte pakken skal legges til, og det nye publiserte OEM-navnet skal registreres for senere fjerning. Den signerte pakken som vises her beholdes som kopi. Ingen andre driverpakker skal fjernes.
