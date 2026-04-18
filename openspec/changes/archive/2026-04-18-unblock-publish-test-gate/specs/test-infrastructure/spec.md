# Capability: test-infrastructure

## ADDED Requirements

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
