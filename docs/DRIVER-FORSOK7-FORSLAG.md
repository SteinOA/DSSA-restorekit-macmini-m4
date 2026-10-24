# Forslag til ett forsøk 7 – ikke godkjent eller startet

Dette er en plan til gjennomgang. Brukeren godkjente ett forsøk 6; det er avsluttet. Forsøk 7 krever ny uttrykkelig godkjenning etter at den korrigerte programversjonen og kontrollene er klare. Scriptfiler som inneholder «attempt7» er klargjøring, ikke bevis på kjøring.

## Utgangspunktet er ryddet

[Sluttkontrollen etter forsøk 6](Cleanup-20261024-052841-cc1b4156/result.json) viser at 1905-pakken er fjernet, alle forekomster av sertifikatet er fjernet, den private nøkkelen er borte, og ingen andre driverpakker ble slettet. Apples drivere beholdes. Pakken og de historiske loggene ligger igjen som dokumentasjon, uten aktiv sertifikattillit.

## Avgrensning dersom ett nytt forsøk godkjennes

1. Kontroller den ferdige programversjonen og faste filhasher. Ingen ny privat nøkkel eller nytt sertifikat skal opprettes eller brukes til å signere.
2. Les ut bare det eksisterende offentlige sertifikatet fra den uendrede CAT-filen. Kontroller fingeravtrykket `4AB0DB3E9B0D6D055133E286B3D16F3460FBFB31`. Etter særskilt godkjenning kan akkurat denne offentlige nøkkelen midlertidig gis tillit i `LocalMachine/Root` og `LocalMachine/TrustedPublisher`. Dette er en midlertidig sikkerhetsendring; det legges ikke noe i `CurrentUser/My`.
3. Legg bare `macmini_restore_1905.inf` for `USB\VID_05AC&PID_1905` i driverlageret, med det nye OEM-navnet loggført. Staging skjer før Mac-en kobles til og uten `/install`. Ingen andre pakker eller aktive driverbindinger endres. Normal Windows PnP-tilknytning når samme Mac viser seg, kontrolleres mot forventet originalnavn og hash; den skal ikke erstattes med automatisk tvangsomkobling.
4. Vent på den samme Mac-en i riktig DFU-modus og på den avtalte fysiske USB-porten. Kjør bare ett nytt forsøk. Ingen automatisk ny runde ved feil eller timeout.
5. Bruk Apple-driverne for Port DFU, KIS og Recovery. Bruk den smale WinUSB-pakken bare for denne Mac-ens avsluttende 1905-modus. Den avgrensede USB-tjenesten bruker bare lokal port 27016; Apples prosess på 27015 skal ikke stoppes.
6. Koordinatorens `finally` må kjøre etter at restoreprosessen er slutt, både ved suksess, feil og avbrudd. Fjern bare den nye, hash- og originalnavnkontrollerte pakken. Hvis en frakoblet oppføring blokkerer sletting, skal bare den eksakte, ikke-tilstedeværende Mac1905-oppføringen behandles etter sikkerhetskopi og identitetskontroll. Ingen `/force`, `/uninstall` eller bred enhetsfjerning. Fjern alle forekomster av oppdragets eksakte sertifikat og kontroller at den kjente private nøkkelen fortsatt ikke finnes, uavhengig av pakkefjerningens resultat.
7. Kontroller og loggfør sluttstatus før arbeidet avsluttes, også ved feil og før nattestopp. Ved strømbrudd eller prosesskrasj kan en `finally` ikke garanteres; gjenopptak skal derfor begynne med denne oppryddingskontrollen.

## Uendrede filer og identiteter

- INF SHA256: `96900A82E846BDE1999787C566D8B22DC52D108545B9E76FCAA4DA2F79334E02`.
- CAT SHA256: `6597FB9FC3F12FF4BA5B99154AEEEBA79CFB716A701DAFAB689DDBAE835DD3CB`.
- Mac-ens 1905-serienummer: `00008132-001808291EA2401C`.
- Sertifikatfingeravtrykk: `4AB0DB3E9B0D6D055133E286B3D16F3460FBFB31`.
- Den tidligere private CNG-nøkkelen skal forbli borte: `te-6087c5f9-045d-456f-935e-20cc89e024a0`.

Det skal ikke endres antivirus, nettverk, andre PC-programmer, testsignering, signaturhåndheving eller Secure Boot som del av dette forslaget. Ingen ny tillit eller installasjon er utført av dette dokumentet.
