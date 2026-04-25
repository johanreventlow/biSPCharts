## ADDED Requirements

### Requirement: Public NAMESPACE SHALL kun indeholde intentional public API

`NAMESPACE` SHALL kun eksportere funktioner der udgør intentional stabil public API-kontrakt. Interne helpers, UI-builders brugt af egen `run_app()`, og intern analytics-pipeline SHALL være markeret `@keywords internal` og ikke eksporteres.

#### Scenario: Audit identificerer intentional exports

- **WHEN** maintainer inspicerer NAMESPACE
- **THEN** hver eksport kan begrundes med spørgsmålet: "Forventes eksterne brugere at kalde dette direkte via `biSPCharts::fn`?"
- **AND** svaret er dokumenteret i ADR "ADR-NNN: Minimal public API surface"

#### Scenario: Intern funktion ved uheld markeret @export

- **WHEN** PR tilføjer `@export` på funktion der ikke er intentional public
- **THEN** review flagger forekomsten
- **AND** funktionen får `@keywords internal` i stedet

### Requirement: Breaking changes i public API SHALL dokumenteres i NEWS.md

Når en eksport fjernes fra NAMESPACE (markeret internal eller slettet), SHALL `NEWS.md` opdateres med `## Breaking changes`-sektion der lister hver ændring + migration-hint. Pre-1.0 MAY indeholde breaking i MINOR, men SHALL altid markeres eksplicit.

#### Scenario: Eksport fjernet

- **GIVEN** PR fjerner `mod_landing_ui` fra exports
- **WHEN** PR-review kører
- **THEN** `NEWS.md`-diff indeholder entry under `## Breaking changes` for kommende version
- **AND** entry-tekst nævner funktionsnavn + migration-hint (fx "intern funktion — kaldes automatisk af run_app()")

### Requirement: Cross-repo downstream SHALL verificeres før export-removal

Før eksport fjernes SHALL maintainer verificere at ingen sibling-pakke (BFHcharts, BFHtheme, BFHllm) bruger den via `biSPCharts::fn`-prefix. Verifikation SHALL dokumenteres i proposal.md under "Downstream-verifikation".

#### Scenario: Sibling-pakke bruger eksport

- **GIVEN** BFHcharts har en `biSPCharts::some_helper()`-kald
- **WHEN** proposal foreslår at fjerne `some_helper` fra exports
- **THEN** proposal beskriver enten (a) at funktionen beholdes som public indtil BFHcharts migrerer, eller (b) sideløbende BFHcharts-PR er åbnet

#### Scenario: Ingen downstream-brug

- **GIVEN** grep i sibling-repos ikke finder `biSPCharts::fn`-kald til eksport
- **THEN** eksport kan fjernes uden sideløbende downstream-arbejde
- **AND** proposal dokumenterer verifikationsresultat
