# test-infrastructure Specification

## Purpose
TBD - created by archiving change unblock-publish-test-gate. Update Purpose after archive.
## Requirements
### Requirement: Publish-gate SHALL enforce test-suite success

The system SHALL køre `devtools::test(stop_on_failure = TRUE)` som
publish-gate før `rsconnect::writeManifest()` i `dev/publish_prepare.R
manifest`-fasen (invoked af `/publish-to-connect` slash-kommandoen).
Manifest-generering SHALL blokeres hvis tests fejler.

#### Scenario: Tests består

- **GIVEN** `feat/unblock-publish-203` er merged til master
- **AND** alle tests i `tests/testthat/` kører grønt
- **WHEN** maintainer kører `Rscript dev/publish_prepare.R manifest`
- **THEN** scriptet kører tests til ende og returnerer exit 0
- **AND** `rsconnect::writeManifest()` udføres
- **AND** `manifest.json` opdateres

#### Scenario: Tests fejler

- **GIVEN** `feat/unblock-publish-203` er merged til master
- **AND** en eller flere tests i `tests/testthat/` fejler
- **WHEN** maintainer kører `Rscript dev/publish_prepare.R manifest`
- **THEN** scriptet stopper med exit 1 efter test-fasen
- **AND** `manifest.json` genereres IKKE
- **AND** maintainer får klar fejlmeddelelse om hvilken test der fejlede

### Requirement: Test-suite SHALL være fri for broken-missing-fn-kategorier

Efter Change 1 SHALL ingen testfil i `tests/testthat/` henvise til
R-funktioner som ikke længere eksisterer i pakkens namespace. Dette verificeres
via audit-scriptet (`dev/audit_tests.R`) der returnerer `broken-missing-fn = 0`
i kategorifordelingen.

#### Scenario: Audit post-fix viser ingen broken-missing-fn

- **GIVEN** Change 1 er fuldt implementeret
- **WHEN** maintainer kører `Rscript dev/audit_tests.R --timeout=60`
- **THEN** JSON-rapporten (`dev/audit-output/test-audit.json`) viser
  `summary.broken-missing-fn` er enten fraværende eller `0`
- **AND** Markdown-rapporten (`docs/superpowers/specs/2026-04-17-test-audit-report.md`)
  viser ingen filer under sektionen `## Kategori: broken-missing-fn`

#### Scenario: Forældede funktions-kald håndteres eksplicit

- **GIVEN** en testfil kalder en funktion der blev fjernet fra `R/`
- **WHEN** maintaineren udfører Change 1 Phase 2 (git-forensics)
- **THEN** én af følgende handlinger anvendes:
  - Funktionen findes under nyt navn → testen opdateres med nyt navn
  - Funktionen er slettet uden erstatning → `test_that`-blokken slettes
  - Funktionen er refaktoreret → testens kald opdateres til ny signatur
  - Fund uklart efter 10 min research → testen wrappes i `skip("TODO: #203 follow-up")`
- **AND** valget logges i `NEWS.md`-entry for denne change

### Requirement: Skip-tests-flag SHALL fjernes fra publish-script

The system SHALL ikke indeholde noget `--skip-tests`-flag eller tilsvarende
bypass-mekanisme i `dev/publish_prepare.R` eller tilhørende dokumentation.
Det midlertidige flag introduceret i commit 20b4724 SHALL fjernes fuldstændigt
fra kodebase og dokumentation som del af Change 1.

#### Scenario: Flag fjernet fra publish-script

- **GIVEN** Change 1 er fuldt implementeret
- **WHEN** maintainer kører `grep -n "skip.tests\|skip_tests" dev/publish_prepare.R`
- **THEN** kommandoen returnerer ingen matches
- **AND** `Rscript dev/publish_prepare.R --help` nævner ikke noget `--skip-tests`-flag

#### Scenario: Flag fjernet fra slash-command-dokumentation

- **GIVEN** Change 1 er fuldt implementeret
- **WHEN** maintainer læser `.claude/commands/publish-to-connect.md`
- **THEN** dokumentet nævner ikke `--skip-tests`-flaget
- **AND** dokumentet nævner ikke instruktioner om at springe tests over

### Requirement: Ændringer SHALL dokumenteres i NEWS.md

Alle tests som bliver fjernet, omdøbt eller skippede som del af Change 1 SHALL
dokumenteres i `NEWS.md` jf. versioning-policy §C.

#### Scenario: NEWS-entry indeholder detaljeret log

- **GIVEN** Change 1 har fjernet/omdøbt/skippede tests
- **WHEN** maintainer læser `NEWS.md`-entry for versionen der indeholder Change 1
- **THEN** entry'et indeholder en sektion med liste over alle berørte tests
- **AND** for hver test: navn, fil, handling (fjernet/omdøbt/skipped), og kort rationale
- **AND** entry'et krydsreferer #203

### Requirement: Residual-fails SHALL håndteres eksplicit via Option A eller B

The system SHALL dokumentere eksplicit valg mellem Option A og Option B hvis
post-fix-verifikation viser at `devtools::test(stop_on_failure = TRUE)` stadig
fejler pga. green-partial-fails (som tilhører Change 2). Maintaineren SHALL
træffe én af to beslutninger og dokumentere den i `NEWS.md`:

- **Option A:** Accept publish-gate fejler på green-partial — `--skip-tests`
  forbliver *fjernet*, men Change 2 er påkrævet for fuld reaktivering
- **Option B:** Midlertidig `skip()`-wrapping af <10 restfails — publish-gate
  passerer, men gælden flyttes til Change 2

#### Scenario: Option A valgt

- **GIVEN** post-fix-audit viser betydeligt antal green-partial fails (>10)
- **WHEN** maintaineren afslutter Phase 4
- **THEN** NEWS.md-entry dokumenterer at Option A blev valgt
- **AND** Change 2 er tydeligt mærket som påkrævet for endelig publish-gate-reaktivering

#### Scenario: Option B valgt

- **GIVEN** post-fix-audit viser få restfails (<10)
- **WHEN** maintaineren afslutter Phase 4
- **THEN** de <10 fails er midlertidigt wrapet i `skip("TODO: #203 Change 2")`
- **AND** NEWS.md-entry lister alle skipped tests
- **AND** Change 2 adresserer disse som prioriteret arbejdspunkt

### Requirement: CI SHALL køre fuld testthat-suite på develop + master

GitHub Actions workflow `testthat.yaml` SHALL triggeres på både `push` og `pull_request` mod branches `master` og `develop`. Test-suiten SHALL køres med `devtools::test(stop_on_failure = TRUE)` eller ækvivalent.

#### Scenario: PR mod develop

- **GIVEN** en udvikler åbner PR mod `develop`-branch
- **WHEN** GitHub Actions starter
- **THEN** `testthat.yaml`-workflow kører
- **AND** alle tests i `tests/testthat/` eksekveres
- **AND** PR blokeres hvis nogen test fejler

#### Scenario: Direkte push til develop

- **WHEN** et push sker til `develop`-branch
- **THEN** `testthat.yaml`-workflow kører og rapporterer status som commit-check

### Requirement: Release-gate SHALL køre tarball R CMD check med warnings blocking

Et dedikeret CI-job SHALL køre `R CMD build .` efterfulgt af `R CMD check <tarball> --as-cran` ved PRs mod `master` og ved push af release-tags matchende `v*`. Dette job SHALL bruge `error-on: '"warning"'`, så WARNINGs blokerer PR/release.

#### Scenario: PR mod master med WARNING

- **GIVEN** en PR mod `master` indeholder kode der udløser en WARNING i `R CMD check --as-cran`
- **WHEN** release-gate-workflow kører
- **THEN** workflowet fejler
- **AND** PR kan ikke merges før WARNING er løst eller eksplicit accepteret via spec-amendment

#### Scenario: Release-tag v0.3.0

- **GIVEN** maintainer pusher tag `v0.3.0`
- **WHEN** release-gate-workflow kører
- **THEN** tarball bygges og checkes
- **AND** hvis check fejler, bliver tag markeret som fejlet release i workflow-status

### Requirement: Skip-inventory SHALL rapporteres og gates på TODO-tilvækst

CI SHALL køre et skip-inventory-script der kategoriserer alle `skip(...)`-kald i `tests/testthat/*.R` i tre kategorier: `environment` (legitime miljø-skips via `skip_on_ci`, `skip_if_not_installed` m.fl.), `todo` (kommentarer eller `#<issue>`-referencer der indikerer midlertidig skip), `permanent` (ingen markør — skal manuelt klassificeres). CI SHALL fejle PR hvis `todo`-antal øges uden eksplicit PR-label `allow-skip-increase`.

#### Scenario: PR tilføjer ny TODO-skip uden label

- **GIVEN** en PR tilføjer `skip("TODO: #999 follow-up")` i en test
- **WHEN** skip-inventory-step kører
- **THEN** step rapporterer `todo_skips_delta = +1`
- **AND** workflow fejler
- **AND** PR-commenten indeholder: "Denne PR øger TODO-skip-antal uden label 'allow-skip-increase'. Enten implementér eller begrund eksplicit."

#### Scenario: PR fjerner TODO-skip ved at implementere

- **GIVEN** en PR fjerner `skip("TODO: #230 testServer-migration")` og erstatter med reel test
- **WHEN** skip-inventory-step kører
- **THEN** step rapporterer `todo_skips_delta = -1`
- **AND** workflow passerer
- **AND** PR-commenten viser positiv delta

### Requirement: Shinytest2 gates som nightly opt-in

Shinytest2-tests SHALL køre i et separat CI-job (`.github/workflows/shinytest2.yaml`) der trigger på (a) schedule nightly og (b) `workflow_dispatch`. De SHALL NOT køre på hver PR pga. miljøfølsomhed (browser-versionering, font-rendering). Pinned Chrome-version SHALL bruges.

#### Scenario: Nightly shinytest2-run

- **WHEN** nightly-schedule trigger workflow
- **THEN** Chrome installeres med eksplicit version-pin
- **AND** alle tests med `RUN_SHINYTEST2=1` eksekveres
- **AND** screenshots + snapshot-diffs uploades som artifacts
- **AND** hvis nogen test fejler, oprettes automatisk et GitHub issue med label `shinytest2-regression`

#### Scenario: On-demand shinytest2 via workflow_dispatch

- **WHEN** maintainer manuelt trigger `shinytest2.yaml` via GitHub UI med branch-valg
- **THEN** workflowet kører på valgt branch
- **AND** resultatet vises i workflow-status uden at blokere PRs

### Requirement: Kritiske filer SHALL have dedikerede testfiler

Hver af følgende kernekomponenter SHALL have mindst én dedikeret testfil i `tests/testthat/`:
- `R/state_management.R` → `test-state-management.R`
- `R/app_server_main.R` → `test-app-server-main.R`
- `R/utils_event_context_handlers.R` → `test-utils-event-context-handlers.R`
- `R/mod_spc_chart_server.R` (full flow) → `test-spc-chart-full-flow.R`

#### Scenario: Audit finder manglende testfil

- **WHEN** statisk audit kører `ls R/<file>.R` og `ls tests/testthat/test-<file>.R`
- **AND** testfilen mangler for en kernekomponent
- **THEN** audit fejler
- **AND** en ny testfil SHALL oprettes eller eksplicit dispensation dokumenteres i `tests/testthat/README.md`

#### Scenario: Full-flow-test for chart-module

- **GIVEN** `tests/testthat/test-spc-chart-full-flow.R` eksekveres
- **WHEN** testen simulerer upload → kolonnevalg → chart-type → render → eksport
- **THEN** alle stadier lykkes eller rapporterer klar fejl
- **AND** testen bruger `testServer()` for Shiny-reactive-context

### Requirement: Ingen placeholder-tests i testsuite

Testsuite SHALL ikke indeholde `test_that`-blokke hvor eneste assertion er `expect_true(TRUE)`, `expect_equal(1, 1)`, eller `expect_no_error()` uden opfølgende assertions. Placeholder-tests SHALL enten erstattes med reelle assertions, slettes, eller konverteres til eksplicit `skip("TODO: #<issue>")` med åbent issue-reference.

#### Scenario: Audit finder placeholder

- **WHEN** `grep -rn "expect_true(TRUE)\|expect_equal(1, 1)" tests/testthat/` kører
- **THEN** resultatet er tomt (0 matches)

#### Scenario: `expect_no_error` uden opfølgning

- **WHEN** lint-check finder `expect_no_error({...})` uden efterfølgende `expect_*`-assertions i samme `test_that`-blok
- **THEN** lint flagger forekomsten
- **AND** PR fejler hvis nye forekomster introduceres uden `# nolint`

### Requirement: Test-duplikater SHALL konsolideres efter emne

Testfiler der tester samme capability eller samme bug-kategori SHALL konsolideres til én fil med klart scope. Duplikatet `test-<emne>-<variant>.R` × N er NOT tilladt medmindre hver variant tester en distinkt concern dokumenteret i filens header-kommentar.

#### Scenario: Logging-tests konsolideret

- **WHEN** en udvikler søger efter logging-tests
- **THEN** de findes primært i `test-logging.R`
- **AND** gamle filer `test-logging-debug-cat.R`, `test-logging-precedence.R`, `test-logging-standardization.R`, `test-logging-system.R` er enten (a) slettet (indhold flyttet til `test-logging.R`), eller (b) har klart distinkt scope dokumenteret i header

#### Scenario: Coverage-regression-check

- **GIVEN** en PR konsoliderer test-filer
- **WHEN** CI kører coverage-measurement
- **THEN** pakken-coverage er ≥ baseline fra før konsolidering
- **AND** hvis coverage falder, skal PR-beskrivelsen redegøre for hvilke tests blev fjernet og hvorfor

### Requirement: Assertion-density SHALL rapporteres per fil

CI audit-rapport SHALL rapportere assertion-density (antal `expect_*`-kald / antal `test_that`-blokke) per testfil. Filer med density < 2.0 SHALL flagges som low-quality kandidater for review.

#### Scenario: Audit output

- **WHEN** `dev/audit_tests.R` kører
- **THEN** JSON-output indeholder `assertion_density`-felt per fil
- **AND** markdown-rapport lister top 5 laveste density-filer som "needs review"

