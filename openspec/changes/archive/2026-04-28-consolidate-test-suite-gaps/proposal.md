## Why

Reviews (Claude + Codex, 2026-04-24) fandt test-suiten stor men støjende og fragmenteret: 544 skip-referencer (Codex), 137 svage assertions (`expect_true(TRUE)`, `expect_no_error` uden opfølgning — Claude), 10+ duplicate stubs der peger på issue #230 testServer-migration, og mange `skip_on_ci()` der betyder E2E-tests aldrig kører i CI. Samtidigt mangler dedikerede testfiler for kritiske komponenter: `state_management.R`, `app_server_main.R`, `utils_event_context_handlers.R`. Desuden findes test-duplikation: `test-logging-*.R` (4 filer), `test-e2e-*.R` (2 filer), `test-critical-fixes-*.R` (3 filer), `test-cache-*.R` (3 filer). Samlet resultat: test-suite har høj overhead uden tilsvarende real dækning.

## What Changes

- **Afslut testServer-migration (issue #230)**: implementér testServer-flow for mod_spc_chart_server, mod_export_server, mod_landing_server (eller eksplicit dokumentér hvilke dele ikke kan migreres og hvorfor).
- **Konsolidér test-duplikater**:
  - Merge `test-logging-{debug-cat,precedence,standardization,system}.R` → `test-logging.R`
  - Merge `test-e2e-{workflows,user-workflows}.R` → `test-e2e-workflows.R`
  - Merge `test-critical-fixes-{integration,regression,security}.R` → behold kun hvis reel forskel i fokus, ellers konsolidér
  - Merge `test-cache-{collision-fix,data-signature-bugs,invalidation-sprint3}.R` → `test-cache.R`
- **Erstat 137 placeholder-tests** (`expect_true(TRUE)`, ubeskyttet `expect_no_error`): enten (a) skriv reel assertion, (b) slet testen, (c) `skip("TODO: #<issue>")` med eksplicit hentvisning til åbent issue.
- **Tilføj tests for kritiske filer uden dækning**:
  - `tests/testthat/test-state-management.R` — event-emit/observer-trigger-matrix, state-init, reset
  - `tests/testthat/test-app-server-main.R` — initialisering, session-setup, cleanup
  - `tests/testthat/test-utils-event-context-handlers.R` — routing-regler per context
- **Full testServer-flow for mod_spc_chart_server**: upload → kolonnevalg → chart-type → render → eksport.
- **Dependency-integritetstest**: `tests/testthat/test-dependency-guards.R` (afhænger af `fix-dependency-namespace-guards`).
- **Anhøj-regression-test**: `tests/testthat/test-derive-anhoej-results.R` (afhænger af `extract-anhoej-derivation-pure`).
- **Audit-rapport** i CI der rapporterer dækning-delta: `dev/audit_tests.R` udvides til at tælle assertions per fil og rapportere de fem filer med flest skips.

## Impact

- **Affected specs**: `test-infrastructure` (ADDED requirements)
- **Affected code**:
  - Modificerede/slettede testfiler: ~15-20 testfiler i `tests/testthat/`
  - Nye testfiler: `test-state-management.R`, `test-app-server-main.R`, `test-utils-event-context-handlers.R`, `test-spc-chart-full-flow.R`
  - `dev/audit_tests.R` (udvid)
- **Afhængighed**: Parallel eller efter `harden-ci-quality-gates` (skip-inventory-gate) og `fix-dependency-namespace-guards` (require_qicharts2 til dep-test).
- **Risks**:
  - Test-merge kan skjule dækning-huller hvis ikke gjort omhyggeligt — kør coverage før/efter
  - testServer-migration kan afsløre bugs der tidligere var skjult af skip — forventet, adresseres som separate issues
- **Non-breaking for brugere**: Test-only.

## Related

- GitHub Issue: #322 (paraply); ser også #230 (testServer-migration)
- Review-rapport: Claude K5 + Codex 2. Testbasen er stor men støjende
