# Design — Harden Test-Suite Regression Gate

## Context

Jf. proposal.md: CI er fravalgt som blokerende gate (privat repo, ingen
Actions-betaling). Den eksisterende spec `test-infrastructure` definerer én
gate — publish-scriptet. Denne change udvider det til at være en reelt
effektiv regression-gate samtidig med at suitens kvalitet hæves, så gaten
har noget meningsfuldt at håndhæve.

## Decision Drivers

1. **Ingen CI-blocking** → lokale gates er eneste tekniske mekanisme.
2. **Pre-1.0, produktion for klinikere** → stabilitet > feature-velocity.
3. **Eksisterende investering** i testinventar må ikke smides ud; vi
   reparerer og supplerer.
4. **Developer-friction skal være lav** — en pre-push-hook der tager 3
   minutter er acceptabel; 15 minutter er det ikke.
5. **Kompetence-asymmetri:** én aktiv maintainer. Løsningen skal være
   robust mod glemsel, ikke afhængig af manuel disciplin.

## Architectural Decisions

### AD-1 — Publish-gate som primær regressionsgate

**Besluttet:** `dev/publish_prepare.R` forbliver den autoritative pre-deploy
gate og udvides med:
- `devtools::test(stop_on_failure = TRUE)` (allerede på plads)
- `lintr::lint_package()` (allerede på plads)
- **Nyt:** `covr::package_coverage()` med threshold
- **Nyt:** Headless shinytest2-suite (happy paths, 5-10 tests)

**Alternativ:** GitHub Actions med required checks.
**Forkastet fordi:** Kræver betalt plan på privat repo.

**Alternativ 2:** `rsconnect::writeManifest()` wrapper med check.
**Forkastet fordi:** writeManifest er den operation publish-gaten beskytter —
ville være cirkulært.

### AD-2 — Pre-push-hook som "build-level" gate

**Besluttet:** Git `pre-push`-hook installeres via opt-in script
`dev/install_git_hooks.R`. Hook'en:
- Kører `devtools::test()` (hele suiten, <5 min target)
- Kører `lintr::lint_package()` (<30 sek)
- Afviser push hvis enten fejler
- Kan overskrides med `git push --no-verify` (dokumenteret som nødudgang)

**Alternativ:** Pre-commit-hook.
**Forkastet fordi:** For friktionstungt per commit; feature-branch kan have
flere commits in-flight. Push er bedre granularitet.

**Alternativ 2:** Automatisk installering uden opt-in.
**Forkastet fordi:** Git-hooks er per-klon; kan ikke committes med
automatisk-aktivering. Opt-in via `./dev/install_git_hooks.R` respekterer
det.

**Friktionsbudget:** Samlet pre-push-tid skal holdes < 5 min. Hvis suiten
vokser udover det, del i "hurtig pre-push" (unit + lint) og "fuld publish-
gate" (alt + E2E + covr).

### AD-3 — Testgæld-oprydning før kvalitetsudvidelse

**Besluttet:** Fase 1 (sanering) blokker fase 2 (kvalitet). Vi tilføjer
**ikke** nye tests mens der stadig er 66 fejlende.

**Rationale:** Nye tests oven på rød suite er usynlige — udvikleren kan
ikke se om deres nye test faktisk bestod eller kun "passerede sammen med
resten".

**Alternativ:** Parallel arbejde på ryd-op og nye tests.
**Forkastet fordi:** Øger review-byrde og skjuler regressioner i nye tests.

### AD-4 — Headless E2E via chromote, ikke ekstern service

**Besluttet:** shinytest2 med chromote (Chrome headless) kørt lokalt via
publish-gate. Baseline-screenshots committes til `tests/testthat/_snaps/`.

**Alternativ:** BrowserStack/SauceLabs.
**Forkastet fordi:** Ekstern afhængighed, månedsabonnement, overkill for
Dansk-sproget intern app.

**Alternativ 2:** vdiffr + ggplot-snapshot.
**Forkastet fordi:** Fanger ikke reaktiv adfærd (upload → render). Kan
supplere, men erstatter ikke shinytest2.

**Scope-begrænsning:** Max 10 E2E-tests — pligten er happy path + 2-3
kritiske fejlstier, ikke fuld dækning. Snapshot-baselines opdateres kun
eksplicit (`testthat::snapshot_accept()`), aldrig auto.

**Platform:** Publish-gaten kører på maintainer'ens macOS. Chrome detekteres
via `shinytest2::detect_chrome()`; skip med klar fejlbesked hvis ikke
installeret.

### AD-5 — Test-infrastruktur refactor: eksponér observer-handlers

**Besluttet:** Observer-handlers i `R/mod_spc_chart_*.R` og
`R/utils_server_event_listeners.R` ekstraheres som navngivne top-level
funktioner som kan testes uden fuld reactive-kontekst.

**Eksempel:**
```r
# Før (inline i moduleServer):
observeEvent(app_state$events$data_updated, {
  if (app_state$data$updating_table) return()
  update_plot_cache(app_state)
})

# Efter (testbar handler):
handle_data_updated <- function(app_state) {
  if (isolate(app_state$data$updating_table)) return(invisible())
  update_plot_cache(app_state)
}
observeEvent(app_state$events$data_updated, handle_data_updated(app_state))
```

**Alternativ:** Tests bruger `testServer()` udelukkende.
**Forkastet fordi:** testServer() er langsom og vanskelig for ikke-trivielle
chains. Udtrækning giver hurtige unit-tests PLUS testServer-kontrakter, ikke
enten-eller.

**Scope:** Kun kritiske observer-handlers refaktoreres (ikke alle 80).
Kandidat-liste i tasks.md.

### AD-6 — Kanoniske mocks som single source of truth

**Besluttet:** `tests/testthat/helper-mocks.R` indeholder kanoniske mocks
for alle eksterne afhængigheder. Tests bruger `local_mocked_bindings()`
(testthat 3.2+) til at installere dem.

**Afhængigheder at mocke:**
- `BFHllm::bfhllm_spc_suggestion()` og venner
- `BFHcharts::create_spc_chart()` (til tests hvor plot ikke er under test)
- `pins::board_*`, `gert::git_*`
- Gemini API via `httr2::req_perform()`
- `input$local_storage_*`-custom messages

**Alternativ:** Ad-hoc mocks per fil (nuværende tilstand).
**Forkastet fordi:** 6 filer bruger i dag forskellige mock-strategier →
divergerende mock-adfærd, vanskelig vedligehold.

**Kontrakt-verifikation:** Mocks eksporterer deres forventede signatur via
`tools::package_native_routines()`-lignende mekanisme — simpel `formals()`-
sammenligning i en contract-test sikrer mock og real-API ikke drifter.

### AD-7 — Determinisme via enforce-at-lint

**Besluttet:** Custom lintr-regel `seed_rng_linter` der flagger
`rnorm/runif/sample/rpois` uden omsluttende `withr::with_seed()` eller
`set.seed()` i samme `test_that()`-blok.

**Alternativ:** Konvertér alt til hardcoded fixtures.
**Delvist accepteret:** For store test-datasæt lagres som `.rds`-fixtures.
Mindre datasæt (<50 rækker) må beholde rng + seed.

**Alternativ 2:** Global `set.seed()` i `helper.R`.
**Forkastet fordi:** Brudeligt — tests kan køre i forskellig rækkefølge
(testthat parallel) hvilket ændrer seed-state. Per-test seed er det eneste
pålidelige.

### AD-8 — Artefakter ud af aktiv suite

**Besluttet:**
- `tests/testthat/_problems/` → slettes (testthat edition 3-artefakter);
  tilføjes til `.gitignore`.
- `tests/testthat/archived/` → flyttes til `tests/_archive/` (uden for
  testthat-scope). Årsag bevares for historisk reference.
- `tests/testthat/logs/`, `Rplots.pdf` → `.gitignore`.
- 9 stubfiler (audit-kategori `stub`) → slettes; indhold (hvis nogen) flyttes
  til `tasks.md` som TODO for fase 2.

**Alternativ:** Behold alt — "måske bliver det relevant igen".
**Forkastet fordi:** Støj skader udvikleroplevelse mere end den redder.
Git-historik bevarer adgang til slettet kode.

## Data Model / Spec Deltas

Specdeltaer under `specs/test-infrastructure/spec.md` dækker:

- **MODIFIED** `Publish-gate SHALL enforce test-suite success` — udvides med
  covr-threshold og headless E2E.
- **MODIFIED** `Test-suite SHALL være fri for broken-missing-fn-kategorier` —
  udvides til alle audit-kategorier A-F + stubs + TODO Fase 4-skips.
- **ADDED** `Lokal pre-push-gate SHALL verify test suite`.
- **ADDED** `Kritiske module servers SHALL have testServer-baseret dækning`.
- **ADDED** `E2E happy-path-suite SHALL være headless-kørbar lokalt`.
- **ADDED** `Test-data SHALL være deterministisk via seed control`.
- **ADDED** `Syntetiske tests SHALL erstattes med kald til produktionskode`.
- **ADDED** `Legacy test-artefakter SHALL holdes uden for aktiv suite`.
- **ADDED** `Ét canonical test-entrypoint SHALL bruges lokalt og i publish-gate`.
- **ADDED** `Kanoniske mocks SHALL bruges for eksterne afhængigheder`.

## Risk Assessment

| Risiko | Sandsynlighed | Impact | Mitigation |
|---|---|---|---|
| Fase 1 afdækker flere fejl end inventory viser | Mellem | Lav | Accept — bedre at finde dem nu; tasks.md har buffer |
| Pre-push-hook bliver for langsom | Mellem | Mellem | Mål < 5 min; del i fast/slow hvis nødvendigt; --no-verify som nødudgang |
| testServer-refactor kræver moduleServer-API-ændringer | Høj | Mellem | Isolér som egne commits; moduleServer-return-API gøres eksplicit kontrakt |
| Headless E2E flaky pga. timing | Høj | Mellem | Generøse `wait_for_idle`; separat E2E-job med retry × 2 |
| Covr-threshold kræver midlertidig `exclude`-liste | Høj | Lav | Dokumenteres i `tests/coverage.R`; threshold stiger over 3 releases |
| Maintainer glemmer at installere git-hook efter klon | Mellem | Høj | `.Rprofile` tjekker om `.git/hooks/pre-push` er symlink og advarer |
| Sletning af archived/ mister nyttig kode | Lav | Lav | Arkivér i git før sletning; git log blame bevares |

## Open Questions — Afklaret 2026-04-19

Alle oprindelige åbne spørgsmål er truffet i planlægningssession:

1. **Covr-threshold:** Baseline-først (beslutning 7: A). Første publish-
   gate-kørsel registrerer aktuel % i `tests/coverage-baseline.json`.
   Efterfølgende releases må ikke falde; target (80%/95%) nås via +5%
   pr. release, dokumenteret i `NEWS.md`.
2. **Pre-push-hook sprog:** Bash-wrapper + R-script (beslutning 3: B).
   `.githooks/pre-push` er tynd bash der kalder `Rscript
   dev/prepush_check.R`. Genbruger test-driver fra publish-gate.
3. **E2E-suite placering:** `tests/e2e/` separat entrypoint (beslutning
   5: A). Ikke auto-discovered af `devtools::test()`. Kun publish-gate +
   eksplicit `Rscript tests/e2e/run_e2e.R` kører dem.
4. **`tests/integration/` skæbne:** Slet helt (beslutning 6: C). 4
   filer har falsk tryghed; indholdet erstattes af ægte testServer-
   tests i Fase 2.3. `setup-shinytest2.R` flyttes til
   `tests/e2e/helper-shinytest2.R`.
5. **Fase 1 scope:** Fuldt — alle 66 fejlende blokke + alle 92 TODO-
   skips (beslutning 1: A).
6. **Fase 1 → Fase 2 sekvensering:** Delvist overlap (beslutning 2: C).
   2.1 + 2.4 parallel med slutningen af Fase 1; 2.2-2.3 venter.
7. **Friktionsbudget for pre-push:** Adaptiv med timing-log (beslutning
   4: C). Standard = fuld suite; degradering til fast-mode kun hvis
   målinger viser >4 min kørsel.
8. **Syntetic-test-oprydning scope:** Afgrænset til eksporterede og
   `:::`-tilgængelige produktionsfunktioner (beslutning 8: B). Små
   test-lokale data-builders og assertion-helpers respekteres.
9. **Stubs + TODO-skips:** Hybrid (beslutning 9: C). Stubfiler slettes
   ubetinget; `skip("TODO")` kræver `#NNN`-reference; pre-push-hook
   håndhæver det via lintr/grep-check.
10. **Issue-struktur:** Master + 4 sub-issues (beslutning 10: B). Én
    sub per fase; master lukkes når alle sub er lukkede.

## Validation Strategy

Hver fase har eksplicit acceptkriterium i `tasks.md`:

- **Fase 1:** `Rscript dev/audit_tests.R` viser 0 fails, 0 errors; kun
  intentionelle skips tilbage.
- **Fase 2:** Ingen fil i `tests/testthat/` redefinerer en produktions-
  funktion lokalt (audit-check); alle kritiske mod_*_server har ≥1 ægte
  testServer-test.
- **Fase 3:** `./dev/install_git_hooks.R` installerer symlink; push til
  test-branch med rød test afvises; lintr-regel `seed_rng_linter` fanger
  rnorm uden seed.
- **Fase 4:** Publish-gate fejler hvis coverage < threshold eller
  headless E2E fejler; udgivelse til Connect er blokeret.
