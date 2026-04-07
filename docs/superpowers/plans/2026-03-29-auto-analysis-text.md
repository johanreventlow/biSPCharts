# Auto-genereret Analysetekst Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Auto-generér regelbaseret SPC-analysetekst i eksport-modulet, med bruger-override og AI-forbedring via BFHcharts.

**Architecture:** Eksport-modulet (`mod_export_server.R`) får en `analysis_source` reactiveVal der tracker om teksten er auto-genereret eller brugerskrevet. Når `export_plot()` trigger og `analysis_source == "auto"`, genereres tekst via `BFHcharts::bfh_generate_analysis()`. AI-knappen omskrives til at kalde samme funktion med `use_ai = TRUE`.

**Tech Stack:** BFHcharts (`bfh_generate_analysis`), Shiny reactiveVal, shinyjs

---

### Task 1: UI — Omdøb felt og tilføj auto-indikator

**Files:**
- Modify: `R/mod_export_ui.R:166-201`

- [ ] **Step 1: Omdøb "Forbedringsmål" label og placeholder**

I `R/mod_export_ui.R` linje 168-176, erstat:

```r
            shiny::textAreaInput(
              ns("pdf_improvement"),
              "Forbedringsmål:",
              value = "",
              placeholder = "Angiv mål for forbedring eller ønsket udvikling",
              width = "100%",
              rows = 4,
              resize = "vertical"
            ),
```

med:

```r
            shiny::textAreaInput(
              ns("pdf_improvement"),
              "Analyse af processen:",
              value = "",
              placeholder = "Beskriv hvad SPC-analysen viser, eller lad feltet auto-udfylde baseret på data",
              width = "100%",
              rows = 4,
              resize = "vertical"
            ),
```

- [ ] **Step 2: Tilføj auto-indikator under feltet**

I `R/mod_export_ui.R`, lige efter `shiny::tags$small(class = "text-muted", sprintf("Maksimalt %d karakterer", EXPORT_DESCRIPTION_MAX_LENGTH))` (linje 177-179) for pdf_improvement-feltet, tilføj:

```r
            shiny::div(
              id = ns("analysis_auto_indicator"),
              class = "text-muted",
              style = "font-size: 0.8rem; font-style: italic; margin-top: 4px;",
              shiny::icon("magic"),
              " Auto-genereret analyse — rediger for at tilpasse"
            ),
```

- [ ] **Step 3: Opdatér AI-knap hjælpetekst**

I `R/mod_export_ui.R` linje 195-199, erstat:

```r
              shiny::icon("info-circle"),
              " AI kan hjælpe dig med at formulere forbedringsmål baseret på din SPC-analyse. Forslaget kan redigeres efter behov."
```

med:

```r
              shiny::icon("info-circle"),
              " AI kan hjælpe med at formulere en mere detaljeret analyse af processen. Teksten kan redigeres efter behov."
```

- [ ] **Step 4: Verificér at R kan parse filen**

Kør: `R --no-save -e "parse('R/mod_export_ui.R'); cat('OK\n')"`
Forventet: `OK`

- [ ] **Step 5: Commit**

```bash
git add R/mod_export_ui.R
git commit -m "feat(export): omdøb Forbedringsmål til Analyse af processen"
```

---

### Task 2: Server — analysis_source tracking og auto-generering

**Files:**
- Modify: `R/mod_export_server.R:212-218` (efter Tilbage-knap handler)

- [ ] **Step 1: Tilføj reactiveVals efter module initialization**

I `R/mod_export_server.R`, lige efter Tilbage-knap handleren (ca. linje 225), tilføj:

```r
    # ANALYSIS AUTO-GENERATION =================================================

    # Track kilde for analysetekst: "auto" (regelbaseret) eller "user" (manuelt/AI)
    analysis_source <- shiny::reactiveVal("auto")

    # Flag til at skelne programmatiske opdateringer fra bruger-input
    updating_analysis_programmatically <- shiny::reactiveVal(FALSE)
```

- [ ] **Step 2: Tilføj auto-generering observer**

Lige efter de nye reactiveVals, tilføj:

```r
    # Auto-generer analysetekst når SPC-resultat er tilgængeligt
    shiny::observeEvent(export_plot(), {
      result <- export_plot()
      if (is.null(result) || is.null(result$bfh_qic_result)) {
        return()
      }

      # Kun opdatér feltet hvis brugeren ikke har skrevet noget selv
      if (analysis_source() != "auto") {
        return()
      }

      auto_text <- safe_operation(
        operation_name = "Auto-generate analysis text",
        code = {
          BFHcharts::bfh_generate_analysis(result$bfh_qic_result, use_ai = FALSE)
        },
        fallback = function(e) {
          log_warn(
            .context = "EXPORT_MODULE",
            message = "Auto-analysis generation failed",
            details = list(error = e$message)
          )
          NULL
        },
        error_type = "processing"
      )

      if (!is.null(auto_text) && nchar(auto_text) > 0) {
        updating_analysis_programmatically(TRUE)
        shiny::updateTextAreaInput(session, "pdf_improvement", value = auto_text)
        updating_analysis_programmatically(FALSE)

        log_debug(
          .context = "EXPORT_MODULE",
          message = "Auto-analysis text inserted",
          details = list(text_length = nchar(auto_text))
        )
      }
    }, priority = OBSERVER_PRIORITIES$LOW)
```

- [ ] **Step 3: Tilføj bruger-detektion observer**

Lige efter auto-generering observeren:

```r
    # Detektér om brugeren redigerer analysefeltet manuelt
    shiny::observeEvent(input$pdf_improvement, {
      # Ignorér programmatiske opdateringer
      if (updating_analysis_programmatically()) {
        return()
      }

      current_text <- input$pdf_improvement %||% ""

      if (nchar(trimws(current_text)) == 0) {
        # Bruger har slettet al tekst → re-aktiver auto-generering
        analysis_source("auto")
        log_debug("Analysis source reset to auto (field cleared)", .context = "EXPORT_MODULE")
      } else {
        # Bruger har skrevet noget → stop auto-opdatering
        if (analysis_source() != "user") {
          analysis_source("user")
          log_debug("Analysis source changed to user (manual edit)", .context = "EXPORT_MODULE")
        }
      }
    }, ignoreInit = TRUE)
```

- [ ] **Step 4: Tilføj auto-indikator toggle**

Lige efter bruger-detektion observeren:

```r
    # Vis/skjul auto-indikator baseret på analysis_source
    shiny::observe({
      if (analysis_source() == "auto") {
        shinyjs::show("analysis_auto_indicator")
      } else {
        shinyjs::hide("analysis_auto_indicator")
      }
    })
```

- [ ] **Step 5: Verificér at R kan parse filen**

Kør: `R --no-save -e "parse('R/mod_export_server.R'); cat('OK\n')"`
Forventet: `OK`

- [ ] **Step 6: Commit**

```bash
git add R/mod_export_server.R
git commit -m "feat(export): auto-generer analysetekst via bfh_generate_analysis"
```

---

### Task 3: Omskriv AI-knap handler

**Files:**
- Modify: `R/mod_export_server.R:281-501` (eksisterende AI handler)

- [ ] **Step 1: Erstat generate_improvement_suggestion() med bfh_generate_analysis()**

I den eksisterende `observeEvent(input$ai_generate_suggestion, ...)` handler (linje 281-501), erstat linje 434-450:

```r
        # Generate suggestion
        log_info(
          .context = "EXPORT_MODULE",
          message = "About to call generate_improvement_suggestion()",
          details = list(
            session_valid = !is.null(session),
            spc_result_valid = !is.null(spc_result),
            context_valid = !is.null(context)
          )
        )

        suggestion <- generate_improvement_suggestion(
          spc_result = spc_result,
          context = context,
          session = session,
          max_chars = 350
        )
```

med:

```r
        # Generate AI-enhanced analysis via BFHcharts
        log_info(
          .context = "EXPORT_MODULE",
          message = "About to call bfh_generate_analysis(use_ai = TRUE)"
        )

        # Byg metadata til bfh_generate_analysis
        analysis_metadata <- list(
          data_definition = context$data_definition,
          target = context$target_value,
          chart_title = context$chart_title
        )

        suggestion <- safe_operation(
          operation_name = "AI analysis generation",
          code = {
            shiny::req(spc_result$bfh_qic_result)
            BFHcharts::bfh_generate_analysis(
              spc_result$bfh_qic_result,
              metadata = analysis_metadata,
              use_ai = TRUE,
              max_chars = 375
            )
          },
          fallback = function(e) {
            log_error(
              .context = "EXPORT_MODULE",
              message = "AI analysis generation failed",
              details = list(error = e$message)
            )
            NULL
          },
          error_type = "processing"
        )
```

- [ ] **Step 2: Tilføj analysis_source("user") efter succesfuld AI-generering**

I same handler, efter linje 469 (`shiny::updateTextAreaInput(session, "pdf_improvement", value = suggestion)`), tilføj:

```r
          # Marker som bruger-tekst — AI-genereret tekst har forrang over auto
          updating_analysis_programmatically(TRUE)
          shiny::updateTextAreaInput(session, "pdf_improvement", value = suggestion)
          updating_analysis_programmatically(FALSE)
          analysis_source("user")
```

Og fjern den eksisterende `shiny::updateTextAreaInput(session, "pdf_improvement", value = suggestion)` linje (den er nu erstattet i blokken ovenfor).

- [ ] **Step 3: Opdatér log-beskeder og notifikationer**

Erstat linje 452-458:
```r
        log_info(
          .context = "EXPORT_MODULE",
          message = "generate_improvement_suggestion() returned",
          details = list(
            is_null = is.null(suggestion),
            length = if (!is.null(suggestion)) nchar(suggestion) else NA
          )
        )
```

med:

```r
        log_info(
          .context = "EXPORT_MODULE",
          message = "bfh_generate_analysis(use_ai=TRUE) returned",
          details = list(
            is_null = is.null(suggestion),
            length = if (!is.null(suggestion)) nchar(suggestion) else NA
          )
        )
```

Erstat fejl-notifikation (linje 484-485):
```r
            "Kunne ikke generere AI-forslag. Tjek internetforbindelse og prøv igen, eller skriv forbedringsmålet manuelt.",
```

med:

```r
            "Kunne ikke generere AI-analyse. Tjek internetforbindelse og prøv igen, eller skriv analysen manuelt.",
```

Erstat loading-tekst (linje 297):
```r
            " Genererer forslag..."
```

med:

```r
            " Genererer analyse..."
```

- [ ] **Step 4: Verificér at R kan parse filen**

Kør: `R --no-save -e "parse('R/mod_export_server.R'); cat('OK\n')"`
Forventet: `OK`

- [ ] **Step 5: Commit**

```bash
git add R/mod_export_server.R
git commit -m "feat(export): omskriv AI-knap til bfh_generate_analysis(use_ai=TRUE)"
```

---

### Task 4: Eksport-integration — tilføj auto_analysis flag

**Files:**
- Modify: `R/mod_export_server.R:892-897`

- [ ] **Step 1: Tilføj auto_analysis = FALSE til bfh_export_pdf()**

I `R/mod_export_server.R` linje 892-897, erstat:

```r
              result <- BFHcharts::bfh_export_pdf(
                x = pdf_plot_result$bfh_qic_result,
                output = file,
                metadata = metadata,
                template = "bfh-diagram"
              )
```

med:

```r
              result <- BFHcharts::bfh_export_pdf(
                x = pdf_plot_result$bfh_qic_result,
                output = file,
                metadata = metadata,
                template = "bfh-diagram",
                auto_analysis = FALSE
              )
```

- [ ] **Step 2: Commit**

```bash
git add R/mod_export_server.R
git commit -m "fix(export): eksplicit auto_analysis=FALSE i bfh_export_pdf"
```

---

### Task 5: Oprydning — fjern context-variabel der ikke længere bruges

**Files:**
- Modify: `R/mod_export_server.R:416-421`

- [ ] **Step 1: Fjern ubrugt context-opbygning i AI-handleren**

Kontekst-variablen `context` (linje 416-421) bruges stadig til `analysis_metadata` i Task 3. Verificér at `context$data_definition`, `context$chart_title` og `context$target_value` stadig refereres. Hvis ja, behold som den er.

Tjek også om `context$y_axis_unit` stadig bruges efter Task 3-ændringerne. Hvis ikke, fjern den fra context-listen.

- [ ] **Step 2: Commit (hvis ændringer)**

```bash
git add R/mod_export_server.R
git commit -m "refactor(export): fjern ubrugt y_axis_unit fra AI context"
```

---

### Task 6: Opret GitHub issue for BFHddl-kontekst berigelse

- [ ] **Step 1: Opret issue**

```bash
gh issue create \
  --title "feat: berig AI-kontekst til at matche BFHddl pipeline" \
  --body "## Baggrund
bfh_generate_analysis() accepterer metadata med felter som data_definition og target.
BFHddl-pipelinen sender en langt rigere kontekst (at_target, target_direction,
action_text, baseline_analysis, centerline, department).

## Opgave
- Tilføj department, centerline, at_target, target_direction til metadata
  sendt til bfh_generate_analysis() fra biSPCharts
- Sammenlign med BFHddl pipeline.R linje 1109-1196
- Vurder om kontekst-opbygningen kan deles via BFHcharts

## Kontekst
- Design spec: docs/superpowers/specs/2026-03-29-auto-analysis-text-design.md
- Relateret: #174 (dead code cleanup)"
```

- [ ] **Step 2: Commit plan og spec**

```bash
git add docs/superpowers/specs/2026-03-29-auto-analysis-text-design.md docs/superpowers/plans/2026-03-29-auto-analysis-text.md
git commit -m "docs: tilføj design spec og plan for auto-analysetekst"
```
