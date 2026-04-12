## Why

Codex code review identificerede to performance/config-issues:

1. **Viewport emit uden change detection (pkt 2):** `set_viewport_dims()` emitter `visualization_update_needed()` ved hvert kald, selv når dimensioner er uændrede. Funktionen kaldes både fra viewport-observeren og inde i `renderPlot()`, hvilket giver unødige invalidationer, cache-opdateringer og re-renders ved hver resize/render.

2. **Hardcodede upload-thresholds (pkt 10):** Upload-grænser (50 MB filstørrelse, 100.000 linjer, 50.000 rækker) er hardcodet direkte i valideringsstien i `fct_file_operations.R`, mens andre sikkerhedsgrænser allerede er centraliseret i config. Det gør deployment-tuning inkonsistent.

## What Changes

- Tilføj dimensions-sammenligning i `set_viewport_dims()` — emit kun ved reel ændring i width/height
- Fjern `set_viewport_dims()` kald fra renderPlot-stien (viewport-observeren håndterer det allerede)
- Flyt upload-thresholds (filstørrelse, linje- og rækketærskel) til `config_system_config.R` med getter-funktioner
- Opdater `fct_file_operations.R` til at bruge de centraliserede getter-funktioner

## Impact

- Affected specs: spc-visualization (viewport handling)
- Affected code:
  - `R/utils_state_accessors.R` (set_viewport_dims change detection)
  - `R/mod_spc_chart_server.R` (fjern viewport-kald fra renderPlot)
  - `R/mod_spc_chart_observers.R` (viewport observer — verificér)
  - `R/config_system_config.R` (nye upload threshold konstanter)
  - `R/fct_file_operations.R` (brug getter-funktioner)
- Breaking changes: Ingen
- Risk level: Lav — isolerede ændringer med klar verifikation

## Related

- GitHub Issue: #194
