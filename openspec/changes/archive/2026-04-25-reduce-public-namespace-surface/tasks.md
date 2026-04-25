## 1. Inventér nuværende exports

- [x] 1.1 Læs `NAMESPACE` og kategorisér alle 20+ exports:
  - Reelle public API (brugere forventes at kalde direkte)
  - Internals (kaldes af run_app eller mellem moduler)
  - Debug/dev-helpers (kun til udvikling)
- [x] 1.2 Gem kategorisering i `dev/audit-output/namespace-exports-audit.md`

## 2. Downstream-verifikation

- [x] 2.1 Søg efter BFHcharts/BFHtheme/BFHllm-brug af biSPCharts-eksports:
  - `cd ../BFHcharts && grep -rn "biSPCharts::" .`
  - Tilsvarende for BFHtheme, BFHllm
- [x] 2.2 Dokumentér hvilke exports faktisk bruges eksternt — ingen fundet
- [x] 2.3 Ingen external-brug fundet — alle 20 kan sikkert gøres interne

## 3. Tag interne eksports

- [x] 3.1 Find roxygen-header for hver intern eksport
- [x] 3.2 Erstat `#' @export` med `#' @keywords internal` på 20 funktioner
- [x] 3.3 Kør `devtools::document()` → NAMESPACE regenereres til 4 exports
- [x] 3.4 Verificeret: NAMESPACE nu 4 exports (run_app, compute_spc_results_bfh, should_track_analytics, get_analytics_config)

## 4. Migration-sti for nødvendige

- [x] 4.1 Søgt for `biSPCharts::` i R/ og tests/ — kun run_app (public) og triple-colon interne test-kald
- [x] 4.2 Ingen refaktorering nødvendig

## 5. Dokumentation

- [x] 5.1 Opdatét `NEWS.md` med `## Breaking changes` — liste over alle 20 fjernede exports
- [x] 5.2 Bump DESCRIPTION Version: `0.2.0 → 0.3.0`
- [x] 5.3 README.md har ingen "Public API"-sektion — intet at opdatere
- [x] 5.4 Tilføjet `docs/adr/ADR-018-minimal-public-api-surface.md`

## 6. Verifikation

- [x] 6.1 R CMD check: 0 errors | 0 warnings (pre-eksisterende importFrom-warning; ikke ny)
- [x] 6.2 Fuld test-suite: FAIL 0 | PASS 4595 | SKIP 130
- [x] 6.3 BFHcharts/BFHtheme/BFHllm: ingen biSPCharts::-afhængigheder fundet
- [x] 6.4 `openspec validate reduce-public-namespace-surface --strict` — VALID

Tracking: GitHub Issue #324
