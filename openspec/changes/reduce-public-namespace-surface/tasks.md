## 1. Inventér nuværende exports

- [ ] 1.1 Læs `NAMESPACE` og kategorisér alle 20+ exports:
  - Reelle public API (brugere forventes at kalde direkte)
  - Internals (kaldes af run_app eller mellem moduler)
  - Debug/dev-helpers (kun til udvikling)
- [ ] 1.2 Gem kategorisering i `dev/audit-output/namespace-exports-audit.md`

## 2. Downstream-verifikation

- [ ] 2.1 Søg efter BFHcharts/BFHtheme/BFHllm-brug af biSPCharts-eksports:
  - `cd ../BFHcharts && grep -rn "biSPCharts::" .`
  - Tilsvarende for BFHtheme, BFHllm
- [ ] 2.2 Dokumentér hvilke exports faktisk bruges eksternt
- [ ] 2.3 Hvis external-brug fundet: beholder dem som public eller plan migration

## 3. Tag interne eksports

- [ ] 3.1 Find roxygen-header for hver intern eksport
- [ ] 3.2 Erstat `#' @export` med `#' @keywords internal` + `#' @noRd` eller behold dokumentation men fjern @export
- [ ] 3.3 Kør `devtools::document()` → NAMESPACE regenereres uden de pågældende exports
- [ ] 3.4 Verificér NAMESPACE-diff matcher forventning

## 4. Migration-sti for nødvendige

- [ ] 4.1 For hver fjernet eksport: verificér ingen intern kaldere bruger pkg-prefix (`biSPCharts::fn`) i stedet for direkte kald
- [ ] 4.2 Hvis fundet: refaktorér til direkte kald (internal-funktioner kan kaldes uden prefix)

## 5. Dokumentation

- [ ] 5.1 Opdatér `NEWS.md` med `## Breaking changes`:
  - Liste over hver fjernet eksport
  - Migration-hint for hver
- [ ] 5.2 Bump DESCRIPTION Version: `0.2.0 → 0.3.0` (pre-1.0 MINOR)
- [ ] 5.3 Opdatér README.md "Public API"-sektion til at reflektere minimalt stable-surface
- [ ] 5.4 Tilføj ADR i `docs/adr/`: "ADR-NNN: Minimal public API surface" med begrundelse

## 6. Verifikation

- [ ] 6.1 Kør `R CMD check` → ingen nye WARNINGs
- [ ] 6.2 Kør fuld test-suite — alle tests skal passere (tests der kalder nu-internal funktioner uden prefix fortsætter med at virke)
- [ ] 6.3 Kør testthat mod BFHcharts/BFHtheme/BFHllm med lokal biSPCharts-install (verificér ingen downstream brand)
- [ ] 6.4 Kør `openspec validate reduce-public-namespace-surface --strict`

Tracking: GitHub Issue #324
