# test-infrastructure Spec Delta — harden-test-suite-regression-gate

## MODIFIED Requirements

### Requirement: Publish-gate SHALL enforce test-suite success

The system SHALL køre den samlede lokale kvalitets-pipeline i
`dev/publish_prepare.R` `manifest`-fasen (invoked af
`/publish-to-connect` slash-kommandoen) før `rsconnect::writeManifest()`.
Pipeline'en SHALL køre i rækkefølge og afbryde ved første fejl:

1. `lintr::lint_package()` — ingen nye findings
2. `devtools::test(stop_on_failure = TRUE)` via canonical entrypoint
   (jf. requirement "Ét canonical test-entrypoint")
3. Headless shinytest2 E2E-suite (jf. requirement "E2E happy-path-suite")
4. `covr::package_coverage()` med threshold-check (jf. requirement
   "Coverage-threshold")
5. `rsconnect::writeManifest()`

Manifest-generering SHALL blokeres hvis trin 1–4 fejler.

#### Scenario: Fuld pipeline passerer

- **GIVEN** `master` er op-to-date og alle trin 1–4 passerer
- **WHEN** maintainer kører `Rscript dev/publish_prepare.R manifest`
- **THEN** pipeline'en logger grøn status for hvert trin
- **AND** `manifest.json` opdateres
- **AND** exit code er 0

#### Scenario: Coverage under threshold

- **GIVEN** testsuiten er grøn men samlet coverage er < 80 %
- **WHEN** maintainer kører `Rscript dev/publish_prepare.R manifest`
- **THEN** covr-trinnet stopper med klar fejlbesked
- **AND** manifest.json genereres IKKE
- **AND** HTML-rapport `coverage/index.html` peger på under-dækkede filer

#### Scenario: E2E-test fejler efter retry

- **GIVEN** testsuiten og coverage passerer
- **AND** et headless E2E-test fejler to gange i træk (retry × 2)
- **WHEN** maintainer kører `Rscript dev/publish_prepare.R manifest`
- **THEN** E2E-trinnet stopper med snapshot-diff i log
- **AND** manifest.json genereres IKKE

#### Scenario: Chrome ikke installeret

- **GIVEN** maintainer's miljø har ikke Chrome/chromote tilgængeligt
- **WHEN** maintainer kører `Rscript dev/publish_prepare.R manifest`
- **THEN** E2E-trinnet skippes med advarsel (ikke fejl)
- **AND** pipeline'en fortsætter til covr-trinnet
- **AND** log'en indeholder klar besked om at E2E blev skippet

### Requirement: Test-suite SHALL være fri for stale og syntetiske tests

Test-suiten SHALL ikke indeholde:

- Tests der kalder R-funktioner som ikke længere eksisterer i pakkens
  namespace (audit-kategori `broken-missing-fn`)
- Tests der refererer forældede konstanter eller objekter
  (audit-kategori `broken-missing-obj`)
- Tests med `testthat` 2.x-API'er (fx `info`-argument i `expect_gt/lt/eq`)
- Tests der tilgår reactive values uden Shiny-scope
- Tests der refererer det gamle pakkenavn `claudespc`
- Stubfiler uden reel assert-indhold (audit-kategori `stub`)
- Permanente `skip("TODO ...")`-kald uden issue-reference
- Lokale redefinitioner af produktionsfunktioner inde i testfiler

Efter denne change's Fase 1–2 SHALL audit-scriptet
(`Rscript dev/audit_tests.R`) returnere 0 i alle de ovennævnte kategorier.

#### Scenario: Audit efter Fase 1 viser 0 broken-missing-fn

- **GIVEN** Fase 1 (#203 PR A1-F1 + stub-sletning) er merged
- **WHEN** maintainer kører `Rscript dev/audit_tests.R --timeout=120`
- **THEN** JSON-rapporten viser
  `summary["broken-missing-fn"]` enten fraværende eller `0`
- **AND** samme gælder for `broken-missing-obj`, `testthat-2x-api`,
  `reactive-context`, `claudespc-rename`
- **AND** ingen fil er kategoriseret som `stub`

#### Scenario: Audit efter Fase 2 viser 0 syntetiske tests

- **GIVEN** Fase 2 (syntetisk-test-oprydning) er merged
- **WHEN** maintainer kører audit-scriptet med
  `--check-synthetic-tests=TRUE`
- **THEN** rapporten viser 0 filer hvor en R-funktionsdefinition findes
  inde i en `test_that()`-blok som også testes direkte

#### Scenario: Alle TODO-skips har issue-reference

- **GIVEN** Fase 1.2 er afsluttet
- **WHEN** `grep -rn 'skip(\"TODO' tests/testthat/` køres
- **THEN** hvert fundet `skip("TODO ...")` indeholder en reference til et
  åbent GitHub-issue (fx `skip("TODO: se issue #247")`)
- **AND** ingen `skip("TODO Fase 4 (#203-followup)")` tilbage

## ADDED Requirements

### Requirement: Lokal pre-push-gate SHALL verificere test-suite

The system SHALL inkludere en installérbar git `pre-push`-hook der afviser
push til remote hvis enten `devtools::test()` eller
`lintr::lint_package()` fejler. Hook'en installeres opt-in via
`dev/install_git_hooks.R`, som opretter symlink fra
`.git/hooks/pre-push` til `dev/git-hooks/pre-push`.

`.Rprofile` (projekt-niveau) SHALL logge advarsel ved R-start hvis symlink
ikke er installeret.

Total pre-push-runtime SHALL være < 5 min på standard maintainer-hardware.
Hvis suiten vokser ud over det, SHALL hook'en tilbyde et
`BISPC_PREPUSH_FAST=1` flag der kun kører unit-tests + lint.

`--no-verify` forbliver tilgængelig som nødudgang og dokumenteres i
`CLAUDE.md` §6.

#### Scenario: Push med rød test afvises

- **GIVEN** maintainer har installeret pre-push-hook
- **AND** en test i suiten fejler lokalt
- **WHEN** maintainer kører `git push origin feat/min-branch`
- **THEN** hook'en kører `devtools::test()` og logger fejlen
- **AND** push afvises (exit 1)
- **AND** remote modtager ikke commits

#### Scenario: Push passerer når suite er grøn

- **GIVEN** pre-push-hook er installeret
- **AND** hele testsuiten og lintr passerer
- **WHEN** maintainer kører `git push origin feat/min-branch`
- **THEN** hook'en kører pipeline og logger grøn status
- **AND** push gennemføres til remote

#### Scenario: Advarsel ved manglende hook

- **GIVEN** maintainer har klonet projektet uden at installere hooks
- **WHEN** R startes i projekt-directoriet (`.Rprofile` loader)
- **THEN** konsollen viser besked om at køre
  `./dev/install_git_hooks.R`
- **AND** beskeden forklarer hvad hook'en beskytter mod

#### Scenario: Nødudgang via --no-verify

- **GIVEN** pre-push-hook er installeret
- **AND** maintainer har legitim grund til at omgå gate (fx WIP-branch
  der ikke er klar til review)
- **WHEN** maintainer kører `git push --no-verify origin wip/eksperiment`
- **THEN** hook'en skippes
- **AND** log'en (`.git/bispc-prepush.log`) registrerer bypass med
  timestamp og brancenavn

### Requirement: Kritiske module-servere SHALL have testServer-baseret dækning

Hver kritisk Shiny moduleServer-funktion SHALL have mindst én
`shiny::testServer()`-baseret test der verificerer et eller flere af
følgende:

- Reaktiv kæde fra input/event til outputs (happy path)
- Guard-flag respekteres ved samtidige events
- Fejlsti returnerer kontrolleret state (null/empty data)
- Debounce-adfærd (flere hurtige events → ét output-render)

Kritiske modulservere i scope for denne requirement:

- `visualizationModuleServer` (`R/mod_spc_chart_server.R`)
- `mod_export_server` (`R/mod_export_server.R`)
- `mod_landing_server` (`R/mod_landing_server.R`)
- Event-listeners i `R/utils_server_event_listeners.R` (via
  testServer-wrapper der simulerer `setup_event_listeners()`)

#### Scenario: visualizationModuleServer dækker data_updated-kæden

- **GIVEN** testsuiten indeholder
  `tests/testthat/test-mod-spc-chart-testserver.R`
- **WHEN** maintainer kører filen
- **THEN** mindst ét `test_that()`-blok sætter
  `app_state$events$data_updated <- <initial> + 1L` via `session$flushReact()`
- **AND** verificerer at `output$plot_object` er populeret med et
  ggplot-objekt
- **AND** verificerer at `anhoej_results` er udfyldt

#### Scenario: Guard-flag respekteres

- **GIVEN** en testServer-test sætter
  `app_state$visualization$cache_updating <- TRUE`
- **WHEN** `app_state$events$visualization_update_needed` trigges
- **THEN** observer-kæden skipper uden at skrive til
  `app_state$visualization$module_cached_data`
- **AND** testen verificerer at guard-flaget forblev `TRUE`

### Requirement: E2E happy-path-suite SHALL være headless-kørbar

Test-suiten SHALL inkludere en headless shinytest2-baseret E2E-suite med
5–10 navngivne happy-path og kritiske fejlsti-tests, kørbar via
`chromote` headless. Suiten placeres i `tests/e2e/` med separat
entrypoint (ikke discovered af default `testthat::test_dir()`).

Screenshot-baselines SHALL committes til `tests/testthat/_snaps/e2e-*/`.
Baselines opdateres kun eksplicit via `testthat::snapshot_accept()`,
aldrig auto.

Obligatoriske scenarier:

- Upload CSV → autodetect → p-chart rendres → eksportér PNG
- Upload CSV → autodetect → run-chart rendres → eksportér PDF
- Upload CSV → vælg kolonner manuelt → i-chart rendres
- Session-restore efter schema-migration (localStorage) → plot genopstår
- Upload CSV med tom dato-kolonne → dansk fejlbesked vises
- Wizard-gate blokerer export før data er loaded

#### Scenario: E2E-suite kører via publish-gate

- **GIVEN** Chrome er installeret
- **AND** publish-gate starter
- **WHEN** trin 3 (E2E-suite) kører
- **THEN** alle 5–10 tests gennemføres eller skippes eksplicit
- **AND** fejl logges med skærmbillede-diff til
  `dev/audit-output/e2e-<timestamp>/`

#### Scenario: Snapshot-baseline skal opdateres eksplicit

- **GIVEN** et plot har ændret visuelt udseende legitimt
- **AND** maintainer har verificeret at ændringen er intentionel
- **WHEN** maintainer kører `testthat::snapshot_accept("e2e-p-chart")`
- **THEN** baseline-screenshots opdateres
- **AND** commit indeholder både kode-ændring og snapshot-opdatering

### Requirement: Test-data SHALL være deterministisk via seed control

Testsuiten SHALL sikre determinisme ved at kræve at alle
`rnorm/runif/sample/rpois/rexp/rbinom`-kald i `tests/testthat/` og
`tests/e2e/` er omsluttet af `withr::with_seed(N, ...)` eller indledes
med `set.seed(N)` inden for samme `test_that()`-blok.

Test-data større end 50 rækker SHALL lagres som `.rds`-fixtures i
`tests/testthat/fixtures/` snarere end genereres via rng.

Determinisme håndhæves via custom lintr-regel `seed_rng_linter` der
flagger rng-kald uden seed-kontrol.

#### Scenario: Lintr fanger rng uden seed

- **GIVEN** en ny testfil indeholder `rnorm(20)` uden `set.seed()` eller
  `withr::with_seed()`
- **WHEN** `lintr::lint_package()` kører
- **THEN** findings-listen indeholder en advarsel for det pågældende kald
- **AND** pre-push-hook fejler

#### Scenario: Store fixtures lagres som .rds

- **GIVEN** en test kræver et datasæt med 200 rækker
- **WHEN** maintainer skriver testen
- **THEN** datasættet genereres én gang via
  `tests/testthat/fixtures/build_<scenario>.R`
- **AND** committes som `fixtures/<scenario>.rds`
- **AND** testen indlæser via `readRDS(test_path("fixtures/<scenario>.rds"))`

### Requirement: Ét canonical test-entrypoint SHALL bruges lokalt og i publish-gate

Test-suiten SHALL køres via ét canonical entrypoint der bruges identisk af:

- Lokal udvikler-workflow (`devtools::test()` eller `testthat::test_dir()`)
- Pre-push-hook
- Publish-gate (`dev/publish_prepare.R`)

Historiske divergerende entrypoints (`tests/run_unit_tests.R`,
`tests/run_integration_tests.R`, `tests/run_all_tests.R` med
`source("global.R")`) SHALL konsolideres til tynde wrappers omkring
canonical entrypoint med tag-filtrering (`unit`, `performance`,
`integration`, `e2e`).

#### Scenario: Identisk resultat lokalt og i publish-gate

- **GIVEN** suiten er grøn lokalt via `devtools::test()`
- **WHEN** samme branch kører gennem `dev/publish_prepare.R manifest`
- **THEN** testresultatet (pass/fail-fordeling) er identisk
- **AND** load-path er identisk (samme `pkgload::load_all()`-strategi)

#### Scenario: Tag-filtrering via wrapper

- **GIVEN** maintainer vil kun køre unit-tests
- **WHEN** maintainer kører `Rscript tests/run_unit_tests.R`
- **THEN** wrapper kalder canonical entrypoint med
  `filter = "^test-(?!performance|e2e)"`
- **AND** performance- og e2e-tests skippes

### Requirement: Kanoniske mocks SHALL bruges for eksterne afhængigheder

Testsuiten SHALL mocke alle eksterne afhængigheder (BFHllm, BFHcharts
hvor ikke under test, pins, gert, Gemini API, localStorage JS-bro) via
kanoniske implementationer i `tests/testthat/helper-mocks.R`.

Tests SHALL installere mocks via `testthat::local_mocked_bindings()`
(testthat 3.2+), ikke via ad-hoc `mockery::stub()` eller manuel
funktionsoverskrivning.

Hver kanonisk mock SHALL have en contract-test der verificerer at
`formals()` på mocken matcher den rigtige API — fejl i contract-test
tvinger mock-opdatering når real-API ændres.

#### Scenario: Mock-signatur matcher real API

- **GIVEN** `BFHllm::bfhllm_spc_suggestion()` får ny parameter
- **AND** `helper-mocks.R` ikke er opdateret
- **WHEN** `devtools::test()` kører
- **THEN** contract-testen for mocken fejler med besked om
  signatur-mismatch
- **AND** maintainer tvinges til at opdatere mocken før andre tests kan
  passere

#### Scenario: Ny test bruger local_mocked_bindings

- **GIVEN** maintainer skriver en ny test der skal mocke Gemini-API'et
- **WHEN** testen forfattes
- **THEN** den kalder `testthat::local_mocked_bindings(req_perform =
  bispc_mock_gemini_ok, .package = "httr2")`
- **AND** bruger IKKE `mockery::stub()` eller manuel
  `assignInNamespace`

### Requirement: Legacy test-artefakter SHALL holdes uden for aktiv suite

Følgende artefakter SHALL ikke være i testthat's auto-discovery-sti
(`tests/testthat/`):

- `tests/testthat/_problems/` — slettes helt (testthat-edition-3
  fejl-snippets); tilføjes til `.gitignore`
- `tests/testthat/archived/` — flyttes til `tests/_archive/` (uden for
  testthat-scope)
- `tests/testthat/logs/`, `tests/testthat/Rplots.pdf` — `.gitignore`
- 9 stub-filer (audit-kategori `stub`) — slettes; eventuelt restindhold
  flyttes til `tasks.md` som fase 2-TODOs

#### Scenario: _problems er ikke committed

- **GIVEN** alle faser er merged
- **WHEN** maintainer kører `git status` efter en testkørsel
- **THEN** `tests/testthat/_problems/` er tom eller fraværende
- **AND** `.gitignore` indeholder mønsteret `tests/testthat/_problems/`

#### Scenario: archived er ikke auto-discovered

- **GIVEN** alle faser er merged
- **WHEN** `testthat::test_dir("tests/testthat")` kører
- **THEN** ingen filer under `tests/_archive/` sources eller køres
- **AND** rapporten viser kun aktive tests
