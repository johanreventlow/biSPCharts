## ADDED Requirements

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
