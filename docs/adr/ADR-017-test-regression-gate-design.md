# ADR-017: Test Regression Gate Design

**Status:** Accepted
**Dato:** 2026-04-19
**Relateret:** `openspec/changes/harden-test-suite-regression-gate/` (#228)

---

## Kontekst

biSPCharts er en pre-1.0 Shiny-applikation i aktiv udvikling. Test-suiten har historisk haft ~200 pre-existing failures (sporet i #203 og paraply-issue #239) og ingen blokerende CI-gate. Dette gjorde det muligt at merge røde suite-tilstande til master, hvilket akkumulerede teknisk gæld og flaky tests.

**Identificerede problemer:**

1. **CI kan ikke blokere tests:** `.github/workflows/R-CMD-check.yaml` bruger `--no-tests` + `continue-on-error: true` for testthat-job. Dette er nødvendigt indtil pre-existing failures er løst, men fjerner samtidig regression-beskyttelse.
2. **Tre divergerende loading-mekanismer:** `tests/testthat.R` (test_check), `tests/run_*.R` (source global.R), `devtools::test()` (pkgload). Inkonsistente test-resultater mellem kontekster.
3. **Ingen determinisme-garanti:** 79+ rng-kald uden `set.seed()` producerede flaky tests.
4. **Ingen publish-gate:** `dev/publish_prepare.R` kunne generere manifest.json selv ved rød suite eller lav coverage.
5. **Test-infrastruktur-noise:** Synthetic tests der redefinerede produktionsfunktioner inline, stale mocks uden API-contract-tests, legacy MockAppDriver.

## Beslutning

**Vi implementerer lokale gates (pre-push + publish-prepare) som kompensation for midlertidig CI-fravalg.**

### Arkitektur-lag

1. **Pre-push git-hook (§3.1):** Lokal gate ved `git push`. Kører lintr + testthat. Default `full` mode (~5-10 min), `fast` mode (~2 min) til hurtig iteration. Bypass via `SKIP_PREPUSH=1`.

2. **Determinisme-linter (§3.2):** Custom `seed_rng_linter` fanger `rnorm/runif/sample/...` uden `set.seed()`/`withr::with_seed()` i `test_that`-blok. Registreret i `.lintr` config.

3. **Canonical test-entrypoint (§3.3):** `tests/run_canonical.R` bruger `pkgload::load_all()` — matcher `devtools::test()`. Alle legacy `tests/run_*.R` er tynde wrappers. `dev/publish_prepare.R` bruger samme runner.

4. **Publish-gate (§4.3):** 5-trins pipeline i `dev/publish_prepare.R manifest`:
   1. `lintr::lint_package()` (ERROR blokerer)
   2. Canonical testthat (stop_on_failure=TRUE)
   3. E2E-suite (`tests/e2e/run_e2e.R`, Chrome-gated, retry×2)
   4. `run_coverage_gate()` (hard 80% overall + 95% critical paths)
   5. `rsconnect::writeManifest()` (kun hvis 1-4 grønne)

Struktureret log til `dev/audit-output/publish-gate-<timestamp>.log`.

### Ikke valgt: Aggressiv CI-blokering nu

Vi fjerner ikke `continue-on-error: true` på testthat-jobbet i R-CMD-check.yaml endnu. Rationale:

- Paraply-issue #239 dokumenterer 43 pre-existing fails + 21 errors sporet til 5 satellitter (#235–#238).
- Fjernes `continue-on-error` nu, blokerer CI al PR-merge til master.
- Lokale gates giver ækvivalent beskyttelse for maintainer-workflow indtil #239 er lukket.
- Ved #239-lukning: enkelt-linje-fjernelse aktiverer CI-blokering uden arkitektur-ændring.

## Konsekvenser

### Positive

- **Regression-beskyttelse aktiv nu** via pre-push + publish-gate uden at blokere igangværende arbejde.
- **Determinisme garanteret** via lintr-regel. 79 findings → 0 via 64 `set.seed(42)`-injections.
- **Konsistente test-resultater** mellem lokal udvikling (devtools::test), pre-push, publish-gate og R CMD check — alle bruger canonical runner eller deler pkgload-kontrakt.
- **Graduel coverage-stigning:** `hard_threshold` starter på 80 %, `target_coverage` er 90 %. +5 %-point per release indtil target.

### Negative

- **Bypass-mekanismer skaber risiko:** `SKIP_PREPUSH=1`, `git push --no-verify` kan misbruges. Dokumenteret som midlertidig begrænsning.
- **Publish-gate er lokal, ikke distribueret:** Kræver at maintainer kører `dev/publish_prepare.R` før deploy. Ingen central gate hvis nogen publisher direkte via RStudio Connect UI.
- **E2E-tests er Chrome-afhængige:** Skipper hvis Chrome mangler (forventet på bare CI-agents). Acceptable trade-off for lokal udvikling.

### Neutral

- **Pre-commit hook eksisterer allerede** (lintr + styler på staged R-filer). Pre-push er komplementær, ikke erstatning.
- **`tests/testthat.R` (test_check) bevaret** for R CMD check-kompatibilitet. Canonical er ekstra lag, ikke erstatning.

## Opfølgning

- **Ved #239-lukning:** Fjern `continue-on-error: true` i `.github/workflows/R-CMD-check.yaml` testthat-job. Dokumentér i NEWS.md. Se `openspec/changes/harden-test-suite-regression-gate/tasks.md §1.5.2`.
- **Coverage-baseline:** Første `covr::package_coverage()`-måling bør køres efter #239 (suite-grøn-forudsætning). Tilpas `hard_threshold` baseret på reel baseline.
- **ADR-gennemgang ved 1.0:** Ved pre-1.0 → 1.0-overgang skal pre-push + publish-gate strammes (fjern bypass eller kræv eksplicit admin-token).

## Historik

- **2026-04-19:** ADR oprettet, Fase 1–4 af `harden-test-suite-regression-gate` leveret.
