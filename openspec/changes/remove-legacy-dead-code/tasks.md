## 1. Forberedelse
- [x] 1.1 Kør fuld test-suite som baseline (gem resultat)
- [x] 1.2 Opret feature branch `chore/remove-legacy-dead-code`
- [x] 1.3 Tag snapshot af NAMESPACE (til sammenligning)

## 2. Fase 1: Fjern helt døde filer (10 filer)
- [x] 2.1-2.10 Fjern alle 10 filer (4.855 linjer slettet)
- [x] 2.11 Kør `devtools::document()` og opdater NAMESPACE
- [x] 2.12 Kør test-suite — identisk med baseline
- [x] 2.13 Commit: `chore: fjern 10 helt ubrugte R-filer (~3.300 linjer)`

## 3. Fase 2: Fjern ubrugte funktioner i aktive filer
- [x] 3.1-3.13 Fjern ~100+ ubrugte funktioner fra 22+ filer (7.480 linjer)
- [x] 3.14 Kør `devtools::document()` og opdater NAMESPACE
- [x] 3.15 Kør test-suite — identisk med baseline
- [x] 3.16 Commit: `chore: fjern ~100+ ubrugte funktioner fra aktive filer`

## 4. Fase 3: Fjern duplikater og orphaned events
- [x] 4.1 Fjern duplikerede accessors i `state_management.R`
- [ ] 4.2 Konsolidér `calculate_combined_anhoej_signal` — UDSKUDT (forskellige signaturer, kræver dybere analyse)
- [ ] 4.4 Konsolidér duplikater i performance-filer — UDSKUDT (forskellige signaturer)
- [x] 4.5 Fjern orphaned events + emit-funktioner + validate_date_column
- [x] 4.7 Commit: `chore: fjern duplikerede accessors og orphaned events`

## 5. Fase 4: JS/CSS og statiske assets oprydning
- [x] 5.1-5.6 Alle JS/CSS oprydninger gennemført
- [x] 5.7 Kør test-suite — identisk med baseline
- [x] 5.8 Commit: `chore: fjern ubrugt JS/CSS og orphaned assets`

## 6. Fase 5: Afsluttende oprydning
- [x] 6.1 Fjern `output$data_summary_box` render
- [x] 6.3 Kør fuld test-suite — identisk med baseline (29 filer, 70 passed, 9 pre-eksisterende fejl)
- [x] 6.4 Kør `devtools::document()` — NAMESPACE opdateret
- [x] 6.5 Final commit: `chore: afsluttende oprydning af dead outputs`

## 7. Validering
- [x] 7.1 Test-suite: 29 filer, 70 passed, 9 failed (alle pre-eksisterende)
- [ ] 7.2 Start app manuelt og verificer kernefunktionalitet — **[MANUELT TRIN]**
- [ ] 7.3 Verificer at ingen warnings om manglende funktioner opstår — **[MANUELT TRIN]**

## Resultat
- **12.631 linjer fjernet** på tværs af 241 filer
- 5 commits, ingen nye test-fejl
- 2 duplikat-konsolideringer udskudt (kræver dybere analyse)

Tracking: GitHub Issue #171
