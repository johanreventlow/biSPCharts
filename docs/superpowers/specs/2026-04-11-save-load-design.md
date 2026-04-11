# Design: Fil-baseret gem og indlæs af data og indstillinger

**Dato:** 2026-04-11
**Status:** Godkendt

---

## Kontekst

biSPCharts har allerede en autosave-funktion der gemmer data og indstillinger til browserens localStorage (session-persistens, Issue #193). Det er en convenience-funktion, men den er browser- og maskin-specifik.

Brugerne har behov for en **portabel sikkerhedskopi** — en fil de kan gemme lokalt, åbne på en anden computer, og dele med kolleger. Excel er det rette format fordi målgruppen (kliniske brugere) er fortrolige med det og kan redigere data i hånden.

---

## Filformat

### Excel med to ark

**Ark 1: "Data"**
- Præcis de kolonner og rækker brugeren har uploadet
- Korrekte datatyper bevares (dato-kolonner skrives som Excel-datoer via `openxlsx`)
- Kan åbnes og redigeres frit i Excel

**Ark 2: "Indstillinger"**
- To kolonner: `Felt` og `Værdi`
- Første celle indeholder forklarende tekst på dansk:
  *"Dette ark bruges af biSPCharts til at gendanne dine indstillinger. Du kan redigere værdierne, men undgå at slette arket."*
- Rækker svarer præcis til hvad `collect_metadata()` returnerer:
  - Kolonnemappings: `x_column`, `y_column`, `n_column`, `skift_column`, `frys_column`, `kommentar_column`
  - Diagramindstillinger: `chart_type`, `target_value`, `centerline_value`
  - Enhed: `y_axis_unit`, `unit_type`, `unit_select`, `unit_custom`
  - Titler: `indicator_title`, `indicator_description`
  - Export-felter: `export_title`, `export_department`, `export_format`, `pdf_description`, `pdf_improvement`, `png_size_preset`, `png_dpi`
  - Navigation: `active_tab`

**Filnavn:**
- Foreslås automatisk som `[indicator_title]_biSPCharts.xlsx`
- Fallback til `data_biSPCharts.xlsx` hvis titel er tom
- Specialtegn (æ, ø, å, mellemrum) normaliseres så filnavnet er gyldigt på alle OS

---

## UI-placering

### Gem-knap i wizard-navigation

Knappen placeres i wizard-footeren mellem "Tilbage" og "Fortsæt":

```
[ ← Tilbage ]   [ 💾 Gem til fil ]   [ Fortsæt → ]
```

- Synlig på **alle trin** (brugeren kan gemme tidligt i processen)
- **Deaktiveret** (grå) hvis ingen data er uploadet
- **Aktiv** så snart data eksisterer
- Download sker direkte via Shiny's `downloadHandler` — ingen modal, ingen ekstra klik

### Upload-flow (trin 1)

Det eksisterende upload-felt accepterer uændret alle Excel-filer. Detektion sker på server-siden:

```
Bruger uploader fil
        ↓
Har filen et "Indstillinger"-ark?
    ├── NEJ → Normal upload-flow (som i dag)
    └── JA  → biSPCharts-gemt fil:
                Indlæs "Data"-arket som data.frame
                Parse "Indstillinger"-ark → metadata-liste
                Kald restore_metadata() → udfylder trin 2 og 3
                Navigér til trin 2 (analyser)
```

En diskret hjælpetekst tilføjes under upload-feltet:
> *"Upload en datafil (CSV/Excel) eller en tidligere gemt biSPCharts-fil."*

---

## Teknisk arkitektur

### Nye filer

**`R/fct_spc_file_save_load.R`**
- `build_spc_excel(data, metadata)` — bygger to-ark Excel-objekt med `openxlsx`, returnerer midlertidig fil-sti til `downloadHandler`
- `parse_spc_excel(file_path)` — læser "Indstillinger"-arket, returnerer named list med samme struktur som `collect_metadata()`

### Ændrede filer

| Fil | Ændring |
|-----|---------|
| `R/ui_app_ui.R` (linje ~313) | Tilføj download-knap i wizard-footer mellem "Tilbage" og "Fortsæt" |
| `R/mod_spc_chart_server.R` | `downloadHandler` der kalder `build_spc_excel()` med `collect_metadata()` og `app_state$data$current_data` |
| `R/fct_file_operations.R` | Upload-handler detekterer "Indstillinger"-ark og kalder `parse_spc_excel()` + eksisterende `restore_metadata()` |
| `DESCRIPTION` | Tilføj `openxlsx` til Imports (hvis ikke allerede til stede) |

### Genbrug af eksisterende kode

- `collect_metadata()` — kilde til alle indstillinger ved gem
- `restore_metadata()` — genopretter felter i trin 2 og 3 ved indlæsning
- Session-persistens-logikken ændres ikke

### Dependencies

- `openxlsx` — skriv Excel med to ark og cellekommentarer
- `readxl` — læs Excel ved upload (sandsynligvis allerede i DESCRIPTION)

---

## Fejlhåndtering

### Upload af gemt fil

| Situation | Håndtering |
|-----------|------------|
| "Indstillinger"-ark korrupt/ufuldstændig | Data indlæses normalt; dansk advarsel: *"Filen indeholder indstillinger, men de kunne ikke indlæses. Data er indlæst normalt."* |
| Kolonner i "Data" matcher ikke gemte mappings | `restore_metadata()` sætter mappings til `""`, auto-detektion kører normalt |
| Fil er ikke en gyldig Excel-fil | Eksisterende fejlhåndtering i upload-handler fanger dette |

### Gem

| Situation | Håndtering |
|-----------|------------|
| Ingen data | Knap er deaktiveret — ingen fejlhåndtering nødvendig |
| `openxlsx`-fejl | Dansk notifikation: *"Filen kunne ikke oprettes. Prøv igen."* |

---

## Hvad gemmes ikke

- Selve plottet (genberegnes ved indlæsning)
- Export-forhåndsvisning
- Browser-specifik state (aktiv session, auto-save status)

---

## Succeskriterier

1. Bruger kan klikke "Gem til fil" på ethvert trin og downloade en `.xlsx`-fil
2. Brugeren kan uploade filen på en anden computer og se alle indstillinger genoprettet i trin 2 og 3
3. Filen kan åbnes i Excel og data kan redigeres i hånden
4. Normal upload-flow er uændret for filer uden "Indstillinger"-ark
5. Knap er deaktiveret uden data og aktiv med data
