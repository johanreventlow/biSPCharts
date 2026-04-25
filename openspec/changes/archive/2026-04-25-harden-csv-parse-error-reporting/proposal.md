## Why

Reviews (Claude + Codex, 2026-04-24) identificerede et mønster i `R/fct_file_operations.R:478-524` hvor CSV-parsing forsøger tre strategier (`read_csv2`, `read_delim` auto-detect, `read_csv`) og sluger hver fejl med `error = function(e) NULL`. Hvis alle tre fejler, ser brugeren kun en generisk "Kunne ikke parse CSV"-besked uden kontekst om hvilke delimiters/encodings der faktisk blev prøvet og hvorfor de fejlede. Det gør support-cases langsomme og maskerer ægte bugs. Bredere audit fandt 16 instanser af `error = function(e) NULL`-pattern i R/ — nogle legitime (defensive session-token-læsning), andre maskerer bugs (fx analytics-consent, app-initialization). Der mangler et konsistent princip for "accept-failure-silently" vs "log-but-continue" vs "fail-loudly".

## What Changes

- Opret nyt capability `error-handling` der kodificerer principperne for fejlhåndtering.
- Indfør `try_with_diagnostics()`-helper i `R/utils_error_handling.R`: tager en liste af attempts (named), returnerer første succesful result + opsamlet error-log hvis alle fejler.
- Refaktorér CSV-fallback i `fct_file_operations.R:478-524` til at bruge `try_with_diagnostics()` med opsamlet fejllog. Ved total-fail SHALL brugeren se dansk besked der nævner (a) hvilke strategier blev prøvet, (b) hvad hver fejl sagde (truncated), (c) hint om encoding/delimiter.
- Audit alle 16 `error = function(e) NULL`-forekomster: for hver enten (a) tilføj `log_debug(conditionMessage(e), .context = ...)` ved siden af, (b) erstat med `try_with_diagnostics()`, eller (c) dokumentér eksplicit med kommentar hvorfor silent-fail er korrekt (fx "tom streng forventet ved session-token-læsning før init").
- Etablér regel: `safe_operation()` må kun bruges på ikke-essentiel kode (UI-refresh, analytics-emit). Aldrig omkring core-data-processing eller validation.
- Tilføj lint-check: nye `error = function(e) NULL` uden medfølgende `log_debug`-kald eller `# nolint`-kommentar fejler CI.

## Impact

- **Affected specs**: Nyt capability `error-handling` (ADDED)
- **Affected code**:
  - `R/utils_error_handling.R` (ny `try_with_diagnostics()` + regler for `safe_operation()`)
  - `R/fct_file_operations.R:478-524` (CSV-fallback refaktor)
  - 16 forekomster af `error = function(e) NULL` i forskellige filer (audit + log-eller-dokumentér)
  - Eventuel ny `.lintr`-regel
- **Risks**:
  - `try_with_diagnostics()`-API skal være kompatibel med eksisterende `safe_operation()`-pattern — designbeslutning dokumenteres i design.md
  - Nye fejlbeskeder synligere for brugere — verificér dansk oversættelse + UX
- **Non-breaking for brugere**: Fejlbeskeder bliver mere informative, ikke færre.

## Related

- GitHub Issue: #317
- Review-rapport: Claude + Codex 2026-04-24
