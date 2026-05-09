## Why

Cycle A cross-repo wrapper-review (docs/reviews/01-cross-repo-wrappers.md) identificerede to koblede fejl i BFHllm-integrationen, verificeret empirisk af Codex peer-review:

1. **`initialize_bfhllm()` defineret men aldrig kaldt** — funktion tager `get_ai_config()` og kalder `BFHllm::bfhllm_configure()`, men intet sted i `run_app.R`, `zzz.R` eller modul-init kalder den. BFHllm bruger derfor sine egne defaults (`gemini-3.1-flash-lite-preview`, `timeout_seconds = 120`) i stedet for biSPCharts's konfigurerede værdier (`gemini-2.5-flash-lite`, `10s` prod / `15s` dev).

2. **`get_ai_config()` læser ikke YAML-profile aktivt** — bruger `golem::get_golem_options("ai")` som kun returnerer runtime-options sat ved `run_app(options = ...)`. Andre helpers (`get_session_config()`) bruger `get_golem_config("ai")` som læser den aktive YAML-profile. Med `GOLEM_CONFIG_ACTIVE=development` returnerer `get_golem_config("ai")$timeout_seconds` korrekt 15 — men `get_ai_config()` returnerer fortsat default 10.

**Konsekvens i produktion:** AI-calls kører med 12× længere timeout end konfigureret + forkert model-version. Selv hvis #1 fixes uden #2, vil profile-specifikke YAML-overrides ignoreres. Begge skal fixes sammen.

## What Changes

### Code changes
- Refactor `get_ai_config()` + `get_rag_config()` (`R/utils_bfhllm_integration.R:21-46`) til at bruge `get_golem_config("ai")` mønsteret som `get_session_config()`
- Tilføj kald til `initialize_bfhllm(get_ai_config())` i `run_app()` (efter `configure_app_environment()`)
- Sikre `initialize_bfhllm()` håndterer både `prod` og `dev`-profile-overrides korrekt

### Test changes
- Opret `tests/testthat/test-bfhllm-config-injection.R` med:
  - Test at `get_ai_config()` returnerer profile-specifikke værdier under `GOLEM_CONFIG_ACTIVE=development` vs `production`
  - Integration-test der starter app i dev-profile og asserter `BFHllm::bfhllm_get_config()$timeout_seconds == 15`
  - Same for prod-profile (timeout 10)

### Documentation
- Opdatér `docs/AI_INTEGRATION.md` med eksplicit init-flow + profile-override-sektion

## Impact

- **Affected specs:** `ai-integration` (NEW capability)
- **Affected code:**
  - Modificeret: `R/utils_bfhllm_integration.R` (get_ai_config, get_rag_config refactor)
  - Modificeret: `R/app_run.R` (eller `R/zzz.R` — wherever configure_app_environment lives)
  - Ny: `tests/testthat/test-bfhllm-config-injection.R`
  - Modificeret: `docs/AI_INTEGRATION.md`

- **Behavioral impact:**
  - PRODUKTION: AI-timeout reduceres fra 120s (BFHllm-default) til 10s (config) — bruger får hurtigere fejl-feedback
  - PRODUKTION: AI-model skifter fra `gemini-3.1-flash-lite-preview` til `gemini-2.5-flash-lite` (cost/quality-implikation — verificer med stakeholder)
  - DEVELOPMENT: AI-timeout reduceres fra 120s til 15s

- **Risk:** model-skift kan ændre AI-output-kvalitet. Anbefales: kør et før/efter sample af AI-suggestions for at validere kvalitets-paritet før prod-deploy.

## Related

- Review-rapport: `docs/reviews/01-cross-repo-wrappers.md` (cycle A)
- Codex empirisk verifikation: live R-session med `GOLEM_CONFIG_ACTIVE=development` viste config-divergens
