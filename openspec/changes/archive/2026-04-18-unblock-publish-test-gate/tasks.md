# Implementation Tasks: Unblock Publish Test-Gate

**Estimeret total:** 6-7 timer. Kan udføres i én fokus-session eller to halve dage.

**Afhængighed:** `feat/test-audit-203` merges først (audit-rapport + script bør være på master). Change 1 implementeres på ny branch `feat/unblock-publish-203` fra master.

---

## Phase 1: Forberedelse (~30 min)

- [ ] 1.1 Bekræft at `feat/test-audit-203` er merged til master
  - [ ] Tjek: `git log master --oneline | grep -E '(audit|#203)'`
  - [ ] Hvis ikke merged: afvent merge eller merge først

- [ ] 1.2 Opret branch `feat/unblock-publish-203` fra master
  ```
  git checkout master && git pull origin master
  git checkout -b feat/unblock-publish-203
  ```

- [ ] 1.3 Verificér baseline ved at køre audit
  ```
  Rscript dev/audit_tests.R --filter='test-(panel-height-cache|plot-diff|utils_validation_guards|validation-guards)' --timeout=60
  ```
  - [ ] Forventet output: 4 filer, alle `broken-missing-fn`
  - [ ] Gem stderr-snippets til reference under forensics

- [ ] 1.4 Læs audit-rapportens `broken-missing-fn`-sektion og notér alle 17 manglende funktioner i en arbejdsliste

---

## Phase 2: Git-forensics pr. manglende funktion (~3 t)

Udfør `git log --all --source --follow -S '<fn>' -- 'R/*.R'` (og sibling-pakker hvis relevant) for hver funktion. Timebox: **10 min pr. funktion maks**. Dokumentér beslutningen i en midlertidig `FORENSICS_NOTES.md` (slettes før merge).

### Validation guards (6 funktioner)

- [ ] 2.1 `validate_column_exists`
- [ ] 2.2 `validate_config_value`
- [ ] 2.3 `validate_data_or_return`
- [ ] 2.4 `validate_function_exists`
- [ ] 2.5 `validate_state_transition`
- [ ] 2.6 `value_or_default`

For hver: søg om funktionen eksisterer under nyt navn (fx `check_column_exists`), er konsolideret til `validate_input()`, eller er fjernet. Notér beslutning: OMDØB / SLET / SKIP / REFAKTOR.

### Plot-diff (6 funktioner)

- [ ] 2.7 `apply_metadata_update`
- [ ] 2.8 `create_plot_state_snapshot`
- [ ] 2.9 Øvrige plot-diff-funktioner (identificér præcise navne fra audit-rapport)

For disse: check særligt om de er migreret til `BFHcharts`-pakken (plot-diff-funktionalitet er BFHcharts-ansvar jf. CLAUDE.md).

### Panel-height (1 funktion)

- [ ] 2.10 `clear_panel_height_cache`

### Validation guards overlap (~2 funktioner)

- [ ] 2.11 Identificér overlappende funktioner i `test-validation-guards.R` vs. `test-utils_validation_guards.R` og bekræft de har samme beslutning

- [ ] 2.12 **Checkpoint:** Alle 17 funktioner har en dokumenteret handling (OMDØB / SLET / SKIP / REFAKTOR). Hvis uklart efter timebox → SKIP med TODO.

---

## Phase 3: Fix pr. testfil (~2 t)

Udfør fixes fil-for-fil. Én commit pr. fil (atomisk).

### 3a: `test-panel-height-cache.R` (~15 min)

- [ ] 3.1 Anvend beslutning fra Phase 2.10
- [ ] 3.2 Kør filen isoleret: `Rscript -e "pkgload::load_all(); testthat::test_file('tests/testthat/test-panel-height-cache.R')"`
  - [ ] Forventet: PASS eller acceptable SKIP
- [ ] 3.3 Commit:
  ```
  git add tests/testthat/test-panel-height-cache.R
  git commit -m "fix(tests): reparér test-panel-height-cache efter forensics (#203)"
  ```

### 3b: `test-plot-diff.R` (~45 min)

- [ ] 3.4 Anvend beslutninger fra Phase 2.7-2.9
- [ ] 3.5 Bemærk særligt: plot-diff-funktionalitet ejer af BFHcharts — hvis migreret, brug `BFHcharts::<fn>` eller slet test hvis funktionalitet er erstattet
- [ ] 3.6 Kør filen isoleret, verificér pass/skip
- [ ] 3.7 Commit:
  ```
  git add tests/testthat/test-plot-diff.R
  git commit -m "fix(tests): reparér test-plot-diff efter forensics (#203)"
  ```

### 3c: `test-utils_validation_guards.R` + `test-validation-guards.R` (~45 min)

- [ ] 3.8 Beslut om filerne skal merges til én canonical-fil (2.11-analysen)
  - [ ] Hvis fuld overlap: merge til `test-utils_validation_guards.R`, slet `test-validation-guards.R`
  - [ ] Hvis delvist overlap: behold separat men dedup overlappende tests
- [ ] 3.9 Anvend beslutninger fra Phase 2.1-2.6
- [ ] 3.10 Kør begge filer isoleret, verificér pass/skip
- [ ] 3.11 Commit(s):
  ```
  git add tests/testthat/test-utils_validation_guards.R tests/testthat/test-validation-guards.R
  git commit -m "fix(tests): reparér validation-guards testfiler efter forensics (#203)"
  ```

- [ ] 3.12 **Checkpoint:** Kør audit-delvis-kørsel igen:
  ```
  Rscript dev/audit_tests.R --filter='test-(panel-height-cache|plot-diff|utils_validation_guards|validation-guards)' --timeout=60
  ```
  - [ ] Forventet: 0 `broken-missing-fn` blandt de 4 filer (kategori kan være `green`, `green-partial`, eller i enkelte tilfælde `skipped-all` hvis mange tests er skipped)

---

## Phase 4: Reaktivér publish-gate (~30 min)

- [ ] 4.1 Fjern `--skip-tests`-flag fra `dev/publish_prepare.R`
  - [ ] Slet linje 11 (usage-kommentar)
  - [ ] Slet `skip_tests`-parameter og guards (linjer 252, 263, 265)
  - [ ] Slet fra usage-fejl (linje 297) og args-parsing (linje 301, 310)
  - [ ] Kør: `Rscript dev/publish_prepare.R --help` → check ingen spor af flaget

- [ ] 4.2 Fjern dokumentation af flag fra `.claude/commands/publish-to-connect.md`
  - [ ] Slet linjer 59 og 62 (inkl. omkringliggende kontekst der refererer til flaget)

- [ ] 4.3 Fuld audit-kørsel (alle 124 filer)
  ```
  Rscript dev/audit_tests.R --timeout=60 2>&1 | tee dev/audit-output/audit-run-post-fix.log
  ```
  - [ ] Forventet: `broken-missing-fn = 0`
  - [ ] Kategorifordeling ellers stabil (mulig stigning i `skipped-all` hvis flere tests blev skipped)

- [ ] 4.4 Kør `devtools::test(stop_on_failure = TRUE)` direkte
  ```
  Rscript -e "devtools::test(stop_on_failure = TRUE)"
  ```
  - [ ] **Forventet udfald 1 (Option A):** Fails pga. green-partial — accepter og dokumentér i Phase 5. Markér `--skip-tests` som nødvendigt indtil Change 2.
  - [ ] **Forventet udfald 2 (Option B):** Fails er få (<10) — midlertidigt `skip()`-wrap dem med TODO-marker, genkør

- [ ] 4.5 Beslut Option A eller B baseret på 4.4-output. Dokumentér valget i Phase 5.

---

## Phase 5: Dokumentation (~30 min)

- [ ] 5.1 Tilføj entry til `NEWS.md` jf. versioning-policy §C
  - [ ] Sektion: "Bug fixes" og/eller "Interne ændringer"
  - [ ] Liste over tests fjernet/omdøbt/skippet (pr. funktion)
  - [ ] Reference til #203
  - [ ] Note om hvorvidt Option A eller B blev valgt

- [ ] 5.2 Opret ADR hvis arkitektur-beslutninger blev truffet
  - [ ] Typiske kandidater: "Funktion X blev konsolideret til Y i commit Z", "plot-diff migreret til BFHcharts-sibling"
  - [ ] Placering: `docs/adr/ADR-NNN-title.md`
  - [ ] Brug ADR-template fra `DEVELOPMENT_PHILOSOPHY.md`

- [ ] 5.3 Slet midlertidig `FORENSICS_NOTES.md` (arbejdsfil fra Phase 2)

---

## Phase 6: Verifikation og cleanup (~30 min)

- [ ] 6.1 Endelig audit-verifikation
  ```
  Rscript dev/audit_tests.R --timeout=60
  ```
  - [ ] `broken-missing-fn = 0` bekræftet
  - [ ] Kategorier ellers stabile ift. baseline (se `dev/audit-output/audit-run.log` fra audit-branchen)

- [ ] 6.2 Kør publish-prepare uden flag
  ```
  Rscript dev/publish_prepare.R manifest
  ```
  - [ ] Option A-scenario: fejler forventeligt på green-partial → note det, men scriptet fejler renset, ikke på manglende funktioner
  - [ ] Option B-scenario: kører grønt

- [ ] 6.3 Kør lintr på ændrede test-filer
  ```
  Rscript -e "lintr::lint('tests/testthat/test-panel-height-cache.R'); lintr::lint('tests/testthat/test-plot-diff.R'); lintr::lint('tests/testthat/test-utils_validation_guards.R')"
  ```

- [ ] 6.4 Commit endelige ændringer
  ```
  git add NEWS.md docs/adr/
  git commit -m "docs(tests): NEWS + ADR for test-gate reaktivering (#203)"
  ```

- [ ] 6.5 **Phase 6 completion check:**
  - [ ] Alle 4 broken filer er fixed
  - [ ] `--skip-tests`-flag helt fjernet
  - [ ] NEWS opdateret
  - [ ] ADR skrevet hvis relevant
  - [ ] Audit-rerun viser broken-missing-fn = 0

---

## Phase 7: PR og merge (~afventer godkendelse)

- [ ] 7.1 Push branch
  ```
  git push -u origin feat/unblock-publish-203
  ```
  - [ ] **VENT PÅ EKSPLICIT MAINTAINER-GODKENDELSE FØR PUSH**

- [ ] 7.2 Opret PR via GitHub web (eller `gh pr create` hvis tilgængeligt)
  - [ ] Titel: `fix: unblock publish test-gate (#203)`
  - [ ] Body refererer: issue #203, audit-rapport, OpenSpec change-id

- [ ] 7.3 Merge til master efter review
  - [ ] **VENT PÅ MAINTAINER-GODKENDELSE**

- [ ] 7.4 Arkivér OpenSpec change
  ```
  openspec archive unblock-publish-test-gate --yes
  ```

- [ ] 7.5 Opdatér tracking issue (#203) med status
  - [ ] Note: Change 1 (unblock-publish) complete
  - [ ] Næste: Brainstorm Change 2 (refactor-test-suite)

---

## Overall Completion Criteria

- [ ] Alle 17 manglende funktioner har dokumenteret handling
- [ ] Alle 4 `broken-missing-fn`-filer reparerede
- [ ] `broken-missing-fn = 0` efter post-fix audit
- [ ] `--skip-tests`-flag fuldstændigt fjernet fra kodebase og dokumentation
- [ ] NEWS.md opdateret med detaljeret log af ændringer
- [ ] Ingen ny `broken-*`-kategori-filer skabt
- [ ] OpenSpec change arkiveret

---

## Timeline (suggestion)

```
Day 1 morning:  Phase 1 + Phase 2 (forensics)         3.5 t
Day 1 afternoon: Phase 3 (fixes)                       2.0 t
Day 2 morning:  Phase 4 + 5 + 6 (gate + docs + verify) 1.5 t
Day 2 later:    Phase 7 (PR + merge)                   afventer review
─────────────────────────────────────────────────────────
TOTAL:                                                  ~6-7 t
```
