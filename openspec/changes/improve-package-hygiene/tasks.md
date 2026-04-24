## 1. DESCRIPTION og LICENSE

- [x] 1.1 Opret `LICENSE` fil — #290 (CLOSED)
- [x] 1.2 Bump `Depends: R (>= 4.1.0)` — #293 / PR #300
- [x] 1.3 Tilføj `htmltools`, `rlang` til `Imports:` — #293 / PR #300
- [x] 1.4 Tilføj `pkgload` til `Suggests:` — #293 / PR #300
- [x] 1.5 Fjern verificeret ubrugte `Imports:` — #293 / PR #300
- [x] 1.6 Fjern `LazyData: true` — #293 / PR #300
- [x] 1.7 Fjern `VignetteBuilder: knitr` — #293 / PR #300

## 2. NAMESPACE oprydning

- [x] 2.1 Audit R/NAMESPACE vs rod-NAMESPACE — #293 / PR #300
- [x] 2.2 Slet `R/NAMESPACE` — #293 / PR #300
- [x] 2.3 Kør `devtools::document()` — #293 / PR #300
- [x] 2.4 Verificer `devtools::load_all()` fungerer — #293 / PR #300

## 3. log_warn runtime bug

- [x] 3.1–3.5 Fix `log_warn(..., session_id = ...)` bug i rate-limit handler — #291 (CLOSED)

## 4. Artefakt-oprydning

- [x] 4.1–4.6 Fjern artefakter + udvid `.gitignore` — #292 (CLOSED)

## 5. Rd-regenerering

- [x] 5.1–5.4 `devtools::document()`, fix signaturer, commit — #293 / PR #300

## 6. R CMD check gate

- [x] 6.1 `R CMD check --as-cran` kører: 7 WARNINGs tilbage (alle pre-existing/accepterede) — #293
- [x] 6.2 Accepterede NOTEs dokumenteret i `docs/PRE_RELEASE_CHECKLIST.md`
- [x] 6.3 R CMD check-trin tilføjet til `dev/git-hooks/pre-push` (full-mode)
- [x] 6.4 `docs/PRE_RELEASE_CHECKLIST.md` oprettet

## 7. Dokumentation

- [x] 7.2 NEWS.md entry tilføjet under "(development)"

## 8. Verifikation

- [x] 8.1 `devtools::load_all()` kører rent — verificeret #293
- [x] 8.2 `devtools::test()` bestået: 4513 pass, 2 fail (begge pre-existing: #279 BFHcharts-integration, #280 E2E-tests), 0 err, 128 skip — verificeret 2026-04-24
- [ ] 8.3 Shiny-app starter — verificeres manuelt (kræver browser)
- [x] 8.4 R CMD check: 7 WARNINGs (alle kendte og accepterede)

Tracking: GitHub Issue #287
