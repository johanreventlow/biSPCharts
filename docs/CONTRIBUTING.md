# Contributing til biSPCharts

biSPCharts-specifikke konventioner. Globale R-standarder (tidyverse,
testthat, defensive programming) findes i `~/.claude/rules/R_STANDARDS.md`.

---

## roxygen2 Documentation

### Sprog-konvention

- **Funktionsnavne, parameter-navne, technical keywords:** engelsk
- **Beskrivelse, parameter-forklaringer, `@details`:** dansk
- **Eksempler:** kan blande dansk/engelsk naturligt

### biSPCharts `@family` taxonomy

Brug konsistente `@family`-tags for navigerbar dokumentation:

| Family | Anvendelse |
|--------|------------|
| `spc_calculations` | Centrallinjer, kontrolgrænser, Anhøj-rules |
| `data_processing` | Validering, kolonne-detektion, transformation |
| `file_operations` | CSV/Excel upload, parsing, encoding |
| `ui_helpers` | Reaktive helpers, UI-update-services |
| `event_system` | Emit API, observere, prioriteter |

### Template

```r
#' Kort dansk beskrivelse
#'
#' Længere beskrivelse: formål, use cases, side-effects.
#' Marker reaktive afhængigheder eller app_state-mutationer eksplicit.
#'
#' @param col_names Character vector med tilgængelige kolonnenavne
#' @param session Shiny session object (NULL i ikke-Shiny kontekst)
#'
#' @return List med detekterede kolonner og UI sync data
#'
#' @family data_processing
#' @keywords column_detection auto_detection danish_locale
#'
#' @examples
#' \dontrun{
#' kolonner <- c("Dato", "Tæller", "Nævner", "Kommentar")
#' result <- detect_columns_name_only(kolonner, NULL, session)
#' }
```

### Workflow

1. Skriv roxygen ved oprettelse — ikke senere
2. `devtools::document()` efter signatur-ændringer
3. Review NAMESPACE-diff før commit (uventede ændringer = stop-signal)
4. Test `@examples` med `\dontrun{}` for Shiny-afhængige kald

### Coverage-mål

- 100% af eksporterede funktioner
- 100% af `setup_*`-funktioner (app initialization)
- Kritiske interne funktioner (state-management, event-emit, SPC-pipeline)

---

## Brugervendte fejlbeskeder

Tekniske fejl skal mappes til danske, brugervenlige beskeder før visning
i UI. Tekniske detaljer hører i strukturerede logs (`log_error()`), ikke
i `showNotification()`.

```r
user_friendly_error <- function(technical_error) {
  error_mappings <- list(
    "file not found"  = "Filen kunne ikke findes. Tjek filstien.",
    "encoding error"  = "Filen har forkert tegnsæt. Prøv at gemme som UTF-8.",
    "parse error"     = "Filen kan ikke læses. Tjek filformat.",
    "permission denied" = "Manglende adgang til filen.",
    "timeout"         = "Operation tog for lang tid. Prøv igen."
  )

  for (pattern in names(error_mappings)) {
    if (grepl(pattern, technical_error, ignore.case = TRUE)) {
      return(error_mappings[[pattern]])
    }
  }

  "En uventet fejl opstod. Tjek logs for detaljer."
}
```

**Princip:** vis aldrig rå `tryCatch`-fejlbeskeder til brugeren. Log
teknisk detaljer, vis dansk fallback.

---

## Commit-konvention

Conventional Commits (jf. `~/.claude/rules/GIT_WORKFLOW.md`). Ingen
Claude-attribution-footers (eksplicit forbudt i `CLAUDE.md`).

```
feat(scope): kort beskrivelse

Hvorfor, ikke hvordan. Reference: #123
```

---

## Reference

- Global R-stil: `~/.claude/rules/R_STANDARDS.md`
- Shiny-mønstre: `~/.claude/rules/SHINY_STANDARDS.md`
- Arkitektur: `CLAUDE.md` § 2 + `docs/adr/`
- Cross-repo: `docs/CROSS_REPO_COORDINATION.md`
