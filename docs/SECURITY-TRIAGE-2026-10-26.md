# Sikkerhetsavklaring — 26. oktober 2026

Dette repoet er et privat historisk arkiv for den opprinnelige, vellykkede gjenopprettingen. Historiske programfiler, kildekode, låsefiler og bevis er ikke oppdatert av denne avklaringen.

## Bekreftet status

[Sikkerhetskjøring 40339294657](https://github.com/SteinOA/DSSA-restorekit-macmini-m4/actions/runs/40339294657) fullførte 26. oktober:

- Gitleaks-søk etter hemmeligheter i historikk og filer: bestått innen de dokumenterte grensene.
- ClamAV-filskanning: bestått innen de dokumenterte grensene.
- RustSec: 13 sårbarhetstreff i `source/Cargo.lock`, 17 i `source/apps/desktop/src-tauri/Cargo.lock`. Treffene overlapper; de skal ikke summeres som 30 unike sårbarheter.
- De to separate dongle-låsefilene: ingen sårbarhetstreff, men vedlikeholdsvarsler.
- JavaScript-revisjon: feilet. Rapporten 25. oktober registrerte 40 varseloppføringer (16 høye, 19 moderate, 5 lave); dette er ikke en ny opptelling av dagens JavaScript-artifakt.

Rust-rapportene inneholder også Tokio-varselet om usikker Unix AsyncFd-bruk (RUSTSEC-2026-0386) og vedlikeholdsvarsler. Låsefiltreff alene beviser ikke at funksjonen finnes eller kan utnyttes i den historiske Windows-programfilen. De gir heller ikke grunnlag for å friskmelde den.

## Hvor rettelsene gjøres

Den vedlikeholdte, rensede leverandørkoden ligger i [DSSA-Mac-mini-M4-Restore](https://github.com/SteinOA/DSSA-Mac-mini-M4-Restore). [PR #3](https://github.com/SteinOA/DSSA-Mac-mini-M4-Restore/pull/3) oppdaterer de berørte Rust-avhengighetene og dokumenterer relevans, tester og gjenværende grenser. Desktop-applikasjonen og dens JavaScript-avhengigheter inngår ikke i leverandørpakken.

Oppdateringer i leverandørkoden endrer ikke dette arkivets programfil eller sikkerhetsstatus. Arkivets røde avhengighetskontroller beholdes som synlige funn; ingen varsel-ID-er ignoreres for å gjøre kontrollene grønne.

## Beslutning før deling

Behold dette arkivet privat. Bruk den vedlikeholdte leverandørkoden som utgangspunkt for eventuell offentlig eksperimentell kildekode. Ikke tilby arkivets gamle programfil som en sikkerhetsoppdatert nedlasting. En ny kundepakke krever separat gjennomgang av native biblioteker og driveroppsett, skanning av selve sluttproduktet og fysisk validering av den generaliserte versjonen. Ingen offentliggjøring eller utgivelse er utført eller godkjent gjennom denne avklaringen.
