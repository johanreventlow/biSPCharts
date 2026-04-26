## 1. Namespace-guards for qicharts2

- [x] 1.1 Tilføj `require_qicharts2()`-helper i `R/utils_error_handling.R` der kaster `spc_dependency_error` med klasse-struktur `c("spc_dependency_error", "spc_error", "error", "condition")` og dansk fejlbesked
- [x] 1.2 Udfør `grep -rn "qicharts2::" R/` og wrap alle 24 kald i `require_qicharts2(); qicharts2::...`-pattern eller centralisér via wrapper-funktion
- [x] 1.3 Tilføj test `tests/testthat/test-dependency-guards.R` der verificerer at (a) `require_qicharts2()` kaster typed error hvis pakken mockes bort, (b) alle `qicharts2::`-kald i R/ har forudgående guard (statisk lint-check)

## 2. BFHllm Suggests + Remotes

- [x] 2.1 Tilføj `BFHllm (>= 0.1.1)` til `Suggests:` i DESCRIPTION
- [x] 2.2 Tilføj `johanreventlow/BFHllm@v0.1.1` til `Remotes:`
- [x] 2.3 Opdater `Config/Notes:` — fjern "midlertidigt fjernet"-tekst og beskriv BFHllm som optional graceful-degraded feature
- [x] 2.4 Verificér alle 4 `requireNamespace("BFHllm", quietly = TRUE)`-guards i `R/utils_bfhllm_integration.R` fungerer (integrationstest)

## 3. Fjern BFHcharts:::-kald

- [x] 3.1 Identificér alle `BFHcharts:::`-forekomster: `grep -rn "BFHcharts:::" R/`
- [x] 3.2 Tjek om BFHcharts har public API for Typst-document-generation. `bfh_create_typst_document` er exporteret via `BFHcharts::` — ingen BFHcharts-issue nødvendig
- [x] 3.3 Erstat `BFHcharts:::bfh_create_typst_document()` i `R/utils_server_export.R:333` med `BFHcharts::bfh_create_typst_document()`
- [x] 3.4 Tilføj test der asserter at ingen `BFHcharts:::`-kald findes i R/ (lint-baseret test)

## 4. Flyt optional-analytics til Suggests

- [x] 4.1 Verificér at `gert`, `pins`, `shinylogs`, `curl` er guarded med `requireNamespace()` alle steder de bruges. Tilføjet manglende guard i `utils_shinylogs_config.R:initialize_shinylogs_tracking()`
- [x] 4.2 Flyt fra `Imports:` til `Suggests:` i DESCRIPTION
- [ ] 4.3 Tilføj integrationstest der verificerer at app starter uden disse pakker installeret (kræver isoleret miljø — defer til CI)

## 5. Version-bounds + maintainer-email

- [x] 5.1 Tilføj `excelR (>= 0.4.0)` og `digest (>= 0.6.30)` lower-bounds i DESCRIPTION
- [x] 5.2 Ret `noreply@example.com` → `johan@reventlow.dk` i `Authors@R` + `Maintainer:`-felt
- [x] 5.3 Kør `devtools::check()` og verificér at ingen WARNINGs er opstået fra ændringerne. Full test-suite: FAIL 0 | PASS 4587

## 6. Opstarts-rapport

- [x] 6.1 Tilføj `.onAttach`-hook i `R/zzz.R` der logger optional-feature-status: BFHllm (available/missing), qicharts2 (available/missing), Quarto (Sys.which check)
- [x] 6.2 Log via `packageStartupMessage()` (ikke startup-message spam ved attach)
- [x] 6.3 Verificeret via `pkgload::load_all('.')` — output: "biSPCharts optional features: BFHllm=ikke installeret, qicharts2=tilgængelig, Quarto=tilgængelig"

## 7. Dokumentation + validering

- [x] 7.1 Opdater `NEWS.md` med sektion `## Breaking changes` (pre-1.0 MINOR) — flytning af pakker til Suggests
- [x] 7.2 Opdater `CLAUDE.md` BFHllm-sektion til at matche ny dependency-status (v0.1.1, Suggests)
- [x] 7.3 Kør `openspec validate fix-dependency-namespace-guards --strict` — VALID
- [x] 7.4 Kør fuld test-suite + `R CMD check` — FAIL 0 | PASS 4587

Tracking: GitHub Issue #314
