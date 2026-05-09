## 1. Refactor config-helpers

- [ ] 1.1 Skift `get_ai_config()` (`R/utils_bfhllm_integration.R:21-46`) til at bruge `get_golem_config("ai")` mønsteret
- [ ] 1.2 Skift `get_rag_config()` (samme fil) til samme mønster
- [ ] 1.3 Bevar fallback-defaults for tests/CI uden golem-context
- [ ] 1.4 Roxygen-update: dokumentér profile-override-pattern

## 2. Wire `initialize_bfhllm()` i app-startup

- [ ] 2.1 Identificér korrekt hook-point (efter `configure_app_environment()`)
- [ ] 2.2 Tilføj `initialize_bfhllm(get_ai_config())`-kald
- [ ] 2.3 Wrap i `tryCatch` så missing BFHllm ikke crasher app
- [ ] 2.4 Log structured info ved success/failure

## 3. Tests

- [ ] 3.1 Opret `tests/testthat/test-bfhllm-config-injection.R`
- [ ] 3.2 Test `get_ai_config()` med `GOLEM_CONFIG_ACTIVE=development` returnerer timeout=15
- [ ] 3.3 Test `get_ai_config()` med `GOLEM_CONFIG_ACTIVE=production` returnerer timeout=10
- [ ] 3.4 Integration-test: start app i dev-profile, asserter `BFHllm::bfhllm_get_config()$timeout_seconds == 15`
- [ ] 3.5 Same for prod-profile

## 4. Documentation

- [ ] 4.1 Opdatér `docs/AI_INTEGRATION.md` med init-flow-diagram
- [ ] 4.2 Tilføj profile-override-sektion med eksempel
- [ ] 4.3 Opdatér `R/utils_bfhllm_integration.R`-roxygen til at referere init-pattern

## 5. Validering

- [ ] 5.1 Fuld test-suite grøn
- [ ] 5.2 Manuel test: `source('dev/run_dev.R')` → tjek `[BFHLLM] config applied`-log
- [ ] 5.3 `openspec validate fix-bfhllm-config-injection --strict` ✓ valid
- [ ] 5.4 Stakeholder-godkendelse af model-skift (gemini-3.1 → gemini-2.5) før prod-merge
