# Design: Startside / Landing Page

## Baggrund

biSPCharts starter i dag direkte på Upload-trinnet. Der mangler en velkomstside der introducerer appen og giver brugeren en tydelig indgang til arbejdsflowet.

## Krav

1. **Startsiden** er det første brugeren ser ved app-start
2. **Navbar-trin** (Upload, Analysér, Eksportér, Lær om SPC) er skjulte mens brugeren er på startsiden
3. **"Kom i gang"-knap** viser navbar-trin og navigerer til Upload
4. **Logo-klik** i headeren navigerer tilbage til startsiden og skjuler trinene igen
5. **Indhold:** Logo, velkomsttekst, 3 feature-highlights, CTA-knap
6. **Altid vist** ved app-start (ingen localStorage-præference)

## Navigation og flow

```
App starter → Startside (navbar-trin skjulte)
  → "Kom i gang" → navbar-trin synlige, navigér til Upload
  → Logo-klik → navbar-trin skjulte, navigér til startside
```

## Indhold

### Centralt på siden
- Hospitalets logo (stort, centreret)
- Overskrift: "Velkommen til biSPCharts"
- Undertekst: Kort beskrivelse af appens formål (1-2 sætninger om SPC og klinisk kvalitetsarbejde)

### Feature-highlights (3 kort i række)
| Ikon | Titel | Tekst |
|------|-------|-------|
| upload | Upload data | Upload CSV/Excel eller indsæt direkte fra regneark |
| chart-line | Analysér med SPC | Seriediagrammer og kontroldiagrammer med automatisk signaldetektion |
| file-export | Eksportér rapporter | Professionelle PDF-rapporter med automatisk analysetekst |

### Call-to-action
- Primær knap: "Kom i gang" (btn-primary, stor)

## Teknisk implementation

### Navbar-trin skjul/vis
- Ved app-start: skjul alle nav-items undtagen startsiden via JS/shinyjs
- "Kom i gang": vis nav-items, navigér til Upload
- Logo-klik: skjul nav-items, navigér til startside
- Brug `shinyjs::runjs()` til at toggle visibility på navbar-links via CSS class eller display

### Logo-klik
- Wrap logo-img i `tags$a` med id, brug `shinyjs::onclick()` til at håndtere klik
- Alternativ: JavaScript click handler via `tags$script`

## Filer der ændres/oprettes

| Fil | Handling |
|-----|---------|
| `R/mod_landing_ui.R` | Opret: Landing page UI modul |
| `R/mod_landing_server.R` | Opret: Server med "Kom i gang" handler og logo-klik |
| `R/app_ui.R` | Ændre: Tilføj landing page som første nav_panel, gør logo klikbart |
| `R/app_server_main.R` | Ændre: Initialiser landing modul, skjul navbar-trin ved start |
