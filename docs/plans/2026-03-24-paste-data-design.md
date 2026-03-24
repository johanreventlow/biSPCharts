# Paste Data Upload Design

## Formaal

Tilfoej paste-felt til upload-siden (trin 1) saa brugere kan indsaette data direkte fra Excel eller CSV uden at uploade en fil. Inspireret af Datawrapper's step 1.

## Layout: To kolonner

### Venstre kolonne (~4 cols) — Handlinger

Card med tre knapper stablet vertikalt:

| Knap | Stil | Ikon | Handling |
|------|------|------|----------|
| Upload datafil | Primary | file-arrow-up | Aabner fil-upload modal (eksisterende) |
| Start ny session | Secondary/outline | rotate | Nulstiller app (eksisterende) |
| Proev med eksempeldata | Link/tertiary | flask | Indlaeser sample SPC-datasaet |

### Hoejre kolonne (~8 cols) — Paste-felt

- Stor `textAreaInput` (~15 raekker hoej)
- Forudfyldt med sample-data (ikke placeholder — synlig data brugeren kan bruge eller overskrive)
- "Indlaes data" knap under feltet (primary)
- Hjaelpetekst: "Indsaet data fra Excel eller CSV — kolonner adskilles automatisk"

## Sample-data (forudfyldt i textArea)

```
Dato;Vaerdi;Kommentar
2024-01-01;42;
2024-02-01;38;
2024-03-01;45;Ny procedure
2024-04-01;41;
2024-05-01;39;
2024-06-01;44;
```

## "Proev med eksempeldata"

Indlaeser et stoerre, klinisk relevant datasaet (fx 24 maaneders infektionsrater) direkte i app_state. Springer paste-feltet over og navigerer til trin 2.

## Parsing-logik (server-side)

Naar brugeren klikker "Indlaes data":

1. `readr::read_delim()` med `delim = NULL` (auto-detect: tab, semikolon, komma) og `locale = readr::locale(decimal_mark = ",")`
2. Fallback: proev eksplicit tab -> semikolon -> komma hvis auto-detect fejler
3. Valider: mindst 2 kolonner og 1 raekke
4. Indlaes i app_state via eksisterende `emit$data_updated()` flow
5. Ved fejl: vis dansk fejlbesked i notification

## Afgraensning

- Ingen client-side parsing (alt sker i R)
- Ingen separator-dropdown (auto-detect haandterer tab, semikolon, komma)
- Ingen drag-and-drop
- Ingen external link/Google Sheets integration
