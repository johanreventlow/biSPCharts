# Design: Auto-genereret analysetekst i SPCify

## Baggrund

BFHddl-pipelinen genererer automatisk en analysetekst for hvert SPC-diagram baseret på regelbaserede formuleringer (serielængde, krydsninger, outliers, stabilitet, target-vurdering). Denne tekst vises i Typst PDF-eksporten over grafen. SPCify mangler denne funktionalitet — feltet "Forbedringsmål" er tomt medmindre brugeren manuelt skriver noget eller klikker AI-knappen.

**Vigtig designbeslutning:** Analyseteksten skal *beskrive* hvad SPC-analysen viser (deskriptivt), ikke *foreslå* forbedringstiltag (preskriptivt). Forbedringsforslag kræver domæneviden som ligger hos brugeren, ikke i systemet.

## Krav

1. **Auto-generering:** Når SPC-resultatet er tilgængeligt, genereres automatisk en dansk analysetekst via `BFHcharts::bfh_generate_analysis(result, use_ai = FALSE)`
2. **Visning i felt:** Teksten indsættes i UI-feltet "Analyse af processen" (omdøbt fra "Forbedringsmål") så brugeren kan se og redigere den
3. **Preview:** Teksten vises i Typst PDF-preview over grafen (eksisterende preview-flow bruger allerede feltets værdi som `metadata$analysis`)
4. **Bruger-override:** Hvis brugeren redigerer feltet manuelt eller bruger AI-knappen, har brugerens tekst forrang — auto-opdatering stopper
5. **Re-trigger ved data-ændring:** Hvis brugeren ændrer data/konfiguration på trin 2 og `analysis_source == "auto"`, opdateres auto-teksten
6. **Tom-felt reset:** Hvis brugeren sletter al tekst fra feltet, skifter `analysis_source` tilbage til `"auto"` og auto-teksten re-genereres

## Design

### Dataflow

```
SPC plot opdateres (trin 2) → brugeren navigerer til trin 3
  → export_plot() trigger → bfh_qic_result tilgængeligt
  → BFHcharts::bfh_generate_analysis(result, use_ai = FALSE)
  → Hvis analysis_source == "auto": updateTextAreaInput → felt opdateres
  → Hvis analysis_source == "user": gør ingenting

Bruger redigerer feltet manuelt
  → analysis_source ← "user"
  → Auto-opdatering stopper

AI-knap klikkes
  → BFHcharts::bfh_generate_analysis(result, use_ai = TRUE)
  → Tekst indsættes i feltet, analysis_source ← "user"

Bruger sletter al tekst
  → analysis_source ← "auto"
  → Auto-tekst re-genereres

Eksport (PDF/preview)
  → metadata$analysis = feltets aktuelle værdi
  → auto_analysis = FALSE
```

### UI-ændringer (mod_export_ui.R)

- Label: "Forbedringsmål:" → "Analyse af processen:"
- Placeholder: "Beskriv hvad SPC-analysen viser, eller lad feltet auto-udfylde baseret på data"
- Ny `text-muted` indikator under feltet: "Auto-genereret analyse — rediger for at tilpasse" (kun synlig når `analysis_source == "auto"`)
- AI-knap tekst uændret: "Generér forslag med AI"

### Server-logik (mod_export_server.R)

**Nye reactiveVals:**
- `analysis_source <- reactiveVal("auto")` — tracker om teksten er auto-genereret eller brugerskrevet
- `updating_programmatically <- reactiveVal(FALSE)` — flag til at skelne programmatiske vs. manuelle ændringer

**Auto-generering observer:**
```r
observeEvent(export_plot(), {
  result <- export_plot()
  req(result$bfh_qic_result)
  if (analysis_source() == "auto") {
    auto_text <- BFHcharts::bfh_generate_analysis(result$bfh_qic_result, use_ai = FALSE)
    updating_programmatically(TRUE)
    updateTextAreaInput(session, "pdf_improvement", value = auto_text)
    updating_programmatically(FALSE)
  }
})
```

**Bruger-detektion observer:**
```r
observeEvent(input$pdf_improvement, {
  if (!updating_programmatically()) {
    if (nchar(trimws(input$pdf_improvement)) == 0) {
      analysis_source("auto")
      # Re-trigger auto-generering
    } else {
      analysis_source("user")
    }
  }
})
```

**AI-knap ændring:** Eksisterende handler skrives om til at kalde `BFHcharts::bfh_generate_analysis(result, use_ai = TRUE)` i stedet for `generate_improvement_suggestion()`. Metadata fra bruger-input (data_definition, chart_title, y_axis_unit, target_value) sendes med. Efter succesfuld generering: `analysis_source("user")`.

**Auto-indikator UI:** `shinyjs::toggle("analysis_auto_indicator", condition = analysis_source() == "auto")` — viser/skjuler teksten "Auto-genereret analyse — rediger for at tilpasse".

### Eksport-integration

Ingen ændringer i selve eksport-kaldet — `input$pdf_improvement` bruges allerede som `metadata$analysis`. Tilføj `auto_analysis = FALSE` eksplicit for klarhed.

### Dead code

Følgende filer/funktioner bliver dead code efter denne ændring og kan fjernes:
- `R/fct_ai_improvement_suggestions.R` — facade der kalder BFHllm for forbedringsforslag
- `R/utils_bfhllm_integration.R` — integration layer for BFHllm-forbedringsforslag

Vurder inden fjernelse: bruges disse af andre funktioner end AI-knappen?

### Fejlhåndtering

- `bfh_generate_analysis()` wrappet i `safe_operation()` — fallback til tomt felt ved fejl
- Logging: `log_debug(.context = "EXPORT_MODULE", ...)` ved auto-generering

## Opfølgning (GitHub Issue)

Opret issue: "Berig AI-kontekst til at matche BFHddl pipeline" med følgende scope:
- Tilføj `department`, `centerline`, `at_target`, `target_direction`, `action_text`, `baseline_analysis` til metadata sendt til `bfh_generate_analysis()`
- Sammenlign med BFHddl's batch-kontekst
- Vurder om BFHddl's kontekst-opbygning kan deles via BFHcharts

## Filer der ændres

| Fil | Ændring |
|-----|---------|
| `R/mod_export_ui.R` | Omdøb label, opdatér placeholder, tilføj auto-indikator |
| `R/mod_export_server.R` | Tilføj analysis_source tracking, auto-generering observer, bruger-detektion, omskriv AI-handler til bfh_generate_analysis |
