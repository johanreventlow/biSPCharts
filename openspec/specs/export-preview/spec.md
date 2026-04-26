# export-preview Specification

## Purpose
TBD - created by archiving change harden-export-quarto-capability. Update Purpose after archive.
## Requirements
### Requirement: Eksport-pipeline SHALL verificere Quarto-capability før kørsel

Før `system2("quarto", ...)`-kald SHALL pakken kalde `check_quarto_capability()` der verificerer (a) Quarto-binær findes i PATH, (b) version er ≥ 1.3, (c) Typst-format understøttes. Hvis capability-check fejler, SHALL eksport afbrydes med dansk brugerbesked i stedet for at crashe på `system2`-fejl.

#### Scenario: Quarto ikke installeret

- **GIVEN** deployment-miljø uden Quarto i PATH
- **WHEN** bruger trigger eksport
- **THEN** `check_quarto_capability()` returnerer `available = FALSE`
- **AND** brugeren ser besked: "Preview kræver Quarto 1.3+. Denne Shiny-installation har: ikke installeret. Kontakt administrator."
- **AND** ingen `system2`-kald forsøges
- **AND** struktureret log-entry med capability-rapport skrives

#### Scenario: Quarto version for lav

- **GIVEN** Quarto 1.2 er installeret (før Typst-support)
- **WHEN** capability-check kører
- **THEN** `available = TRUE` men `typst_supported = FALSE`
- **AND** brugeren ser specifik besked om version-mismatch
- **AND** eksport afbrydes gracefully

#### Scenario: Fuld capability

- **GIVEN** Quarto ≥ 1.3 er installeret
- **WHEN** capability-check kører
- **THEN** `available = TRUE`, `typst_supported = TRUE`
- **AND** eksport fortsætter normalt

### Requirement: Eksport-input SHALL valideres før system2-kald

Alle user-kontrollerede argumenter til `system2()` i eksport-path (dpi, format, output-path) SHALL valideres eksplicit før kaldet. `dpi` SHALL være numeric i range `[72, 600]`. Format SHALL være i whitelist `c("png", "pdf")`. Output-path SHALL normaliseres og verificeres at være inden for tempdir eller tiltænkt output-directory.

#### Scenario: dpi out-of-range

- **GIVEN** bruger specificerer `dpi = 10000` (teknisk muligt via modificeret klient)
- **WHEN** eksport-validering kører
- **THEN** typed `export_input_error` kastes
- **AND** fejlbesked siger "DPI skal være mellem 72 og 600"
- **AND** ingen system2-kald forsøges

### Requirement: Eksport SHALL ikke blokere Shiny UI

Eksport-operationer der tager > 500ms SHALL køres asynkront (via `promises::future_promise()` eller ækvivalent) så Shiny-main-thread fortsat kan processe events. UI SHALL vise progress-indikator under eksport.

#### Scenario: Stor PDF-eksport

- **GIVEN** bruger trigger eksport af plot med mange datapunkter + høj DPI
- **WHEN** eksport kører
- **THEN** UI viser progress-indikator ("Eksporterer PDF...")
- **AND** bruger kan interagere med øvrige UI-elementer
- **AND** ved færdig: resultat tilbydes som download + progress-indikator fjernes

#### Scenario: Eksport fejler mid-run

- **GIVEN** async-eksport er igangsat
- **WHEN** Quarto returnerer non-zero exit
- **THEN** promise afvises med typed `export_render_error`
- **AND** brugeren ser dansk fejl-besked med Quarto's stderr-output (truncated)

### Requirement: Smoke-test SHALL validere end-to-end eksport i CI

Nightly CI-workflow `export-smoke-test.yaml` SHALL installere Quarto + Typst og køre end-to-end eksport-preview mod en test-fixture. Resultatet (PNG) SHALL verificeres at (a) eksistere, (b) have forventede dimensioner, (c) ikke være blank (basic pixel-histogram check).

#### Scenario: Nightly smoke-test passerer

- **WHEN** nightly trigger eksekverer workflow
- **AND** Quarto-installation + eksport lykkes + output-PNG har > 0 non-white pixels
- **THEN** workflow passerer
- **AND** output-PNG uploades som artifact for manuel review

#### Scenario: Nightly smoke-test fejler

- **WHEN** eksport fejler eller output er blank
- **THEN** workflow fejler
- **AND** GitHub issue oprettes automatisk med label `export-regression`
- **AND** issue-body indeholder Quarto-version, workflow-log og eventuel stderr

