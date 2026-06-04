# biSPCharts

> Statistical Process Control (SPC) til klinisk kvalitetsarbejde — en Shiny-applikation med dansk interface, udviklet til Bispebjerg & Frederiksberg Hospital.

biSPCharts lader klinikere uploade kvalitetsdata, konfigurere SPC-grafer og
eksportere resultater til kvalitetsmøder og arkivering — uden at data forlader
den lokale maskine. Appen er bygget på [Golem](https://thinkr-open.github.io/golem/)
og bruger søsterpakken **BFHcharts** som rendering-engine.

---

## For brugere

### Hvad kan appen?

- **SPC-diagrammer:** Seriediagram (Run), I-kort, P-kort, U-kort og C-kort med
  automatisk beregning af centrallinje og kontrolgrænser.
- **Anhøj-regler:** Serielængde, antal kryds og special cause-signaler markeres
  automatisk (beregnet via `qicharts2`).
- **Auto-detektion:** Kolonner (x-akse, tæller, nævner) matches automatisk ud
  fra navne og dataindhold.
- **Dansk dataformat:** Komma-decimaler, danske datoformater og æøå håndteres
  korrekt ved import.
- **Import:** CSV og Excel (multi-ark med ark-vælger), samt indsæt-fra-udklipsholder.
- **Eksport:** Excel med 3 ark (data + indstillinger round-trip + SPC-analyse).
- **Y-akse-grænser:** Fastsæt nedre og/eller øvre grænse på y-aksen (enhedsbevidst,
  fx 0–100 % på en procent-akse).
- **Session-persistens:** Data og indstillinger gemmes automatisk i browseren og
  gendannes ved næste besøg.
- **AI-forbedringsmål (valgfri):** Kontekst-bevidste forbedringsforslag på dansk
  via Google Gemini. Kræver opsætning — se [docs/AI_INTEGRATION.md](docs/AI_INTEGRATION.md).

### Typisk arbejdsgang

1. Upload CSV/Excel eller indsæt data fra udklipsholder.
2. Bekræft/justér kolonne-mapping (auto-detektion foreslår).
3. Vælg diagramtype og generér grafen.
4. Justér indstillinger (titel, enhed, mål, y-akse-grænser).
5. Eksportér til Excel til kvalitetsmøde eller arkiv.

Detaljeret brugervejledning: **[docs/USER_GUIDE.md](docs/USER_GUIDE.md)**.

---

## Quick start

Appen distribueres som en R-pakke. Søsterpakkerne installeres via `Remotes`
(kræver `GITHUB_PAT` for de private repos — se DESCRIPTION).

```r
# Installér pakke + dependencies
devtools::install_github("johanreventlow/biSPCharts")

# Kør appen (produktion — pakke-loading)
library(biSPCharts)
run_app()                       # standard
run_app(port = 3838)            # custom port
run_app(log_level = "DEBUG")    # verbose logging
```

**Udvikling med source-loading** (langsommere boot, fuld debug-instrumentering):

```r
options(spc.debug.source_loading = TRUE)
source("global.R")
run_app(port = 4040)
```

**Miljø-specifik kørsel** via `GOLEM_CONFIG_ACTIVE` (`development` /
`production` / `testing` — defineret i `inst/golem-config.yml`):

```bash
GOLEM_CONFIG_ACTIVE=development R -e "library(biSPCharts); run_app()"
```

Boot-strategi og startup-kontrakt: **[docs/STARTUP_CONTRACT.md](docs/STARTUP_CONTRACT.md)**.

---

## For udviklere

### Arkitektur i korte træk

**Hybrid rendering-arkitektur** — bevidst og permanent:

| Komponent | Ansvar | Pakke |
|-----------|--------|-------|
| Plot-rendering, theming | Al graf-generering | **BFHcharts** (`Imports`) |
| Anhøj-regler | Serielængde, kryds, special cause | **qicharts2** (`Suggests`, guarded) |
| Branding | Hospital-farver, fonts, logo | **BFHtheme** / **BFHchartsAssets** |
| AI/LLM/RAG | Forbedringsmål, knowledge store | **BFHllm** (`Suggests`, valgfri) |

biSPCharts er **integrationslag + forretningslogik + knowledge-kuration** —
ikke en rendering-motor. Funktionalitet, der hører til en søsterpakke (target
lines, font-fallback, embeddings osv.), implementeres dér, ikke her.

**SPC-pipeline (facade):** `compute_spc_results_bfh()` orkestrerer
`validate → prepare → resolve_axes → build_args → execute → decorate` med
S3-typede fejl (`spc_error`-hierarki). Entry point: `R/fct_spc_bfh_facade.R`.

**Event-drevet state:** Centraliseret event-bus (ingen ad-hoc reactiveVal-triggers)
+ hierarkisk `app_state` (`events` / `data` / `columns` / `session` ...).

```r
emit$data_updated(context = "upload")          # emit

observeEvent(app_state$events$data_updated,    # listen
  ignoreInit = TRUE, priority = OBSERVER_PRIORITIES$HIGH, {
  handle_data_update()
})
```

Filer: `global.R` (events), `R/state_management.R` (state),
`R/utils_server_event_listeners.R` (listeners). Beslutningsgrundlag:
**[docs/adr/](docs/adr/)** (bl.a. ADR-003 event-arkitektur, ADR-004 app_state,
ADR-006 anti-race, ADR-015 BFHcharts-migrering).

### Projektstruktur (Golem, flad `/R/`)

```
R/
├── app_*.R              # core app (server, ui, run)
├── mod_*.R              # Shiny-moduler
├── fct_spc_*.R          # SPC-pipeline (facade, validate, prepare, execute, decorate)
├── fct_*.R              # øvrig forretningslogik (file I/O, Excel)
├── utils_server_*.R     # server-utilities (event listeners, persistens)
├── utils_ui_*.R         # UI-utilities
├── config_*.R           # konfiguration (chart types, priorities, branding)
└── state_management.R   # centraliseret state
```

### Test & CI

```bash
make test            # testthat-suite
make check           # R CMD check (via devtools)
make coverage        # coverage-rapport (også: coverage-html, coverage-simple)
make lint            # lintr
```

```r
# Enkelt test
testthat::test_file("tests/testthat/test-<navn>.R")
```

CI kører bl.a. `R-CMD-check`, `testthat`, `coverage`, `lint`,
`validate-manifest`, `security-audit` og (nightly) `shinytest2` — se
`.github/workflows/`. Coverage-mål: kritiske paths 100 %, samlet ≥ 90 %.

**Pre-push gate** (lintr + manifest-validering + regressionstests):

```bash
Rscript dev/install_git_hooks.R     # installér hooks
# Modes: PREPUSH_MODE=fast|full, RUN_SHINYTEST2=1, SKIP_PREPUSH=1
```

### Konfiguration

| Område | Kilde |
|--------|-------|
| Miljø (dev/prod/test) | `inst/golem-config.yml` |
| Environment-variabler | [docs/ENVIRONMENT_VARIABLES.md](docs/ENVIRONMENT_VARIABLES.md) |
| App-konfiguration | [docs/CONFIGURATION.md](docs/CONFIGURATION.md) |
| Logging | `SPC_LOG_LEVEL` (DEBUG/INFO/WARN/ERROR), [docs/LOGGING_GUIDE.md](docs/LOGGING_GUIDE.md) |

CSV-import bruger som standard ISO-8859-1-encoding (Windows-kompatibilitet)
med komma som decimal-separator; konfigureres i `R/config_system_config.R`.

### Bidrag

Branch-konvention: `feat/` `fix/` `refactor/` `docs/` `test/` `chore/`.
Alle `fix/feat/test/chore`-PR'er targeter **`develop`** (master modtager kun
`develop → master` release-PR'er). Dansk Conventional Commits.

Fuld guide: **[docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)**.
Cross-repo-koordinering med søsterpakkerne: **[docs/CROSS_REPO_COORDINATION.md](docs/CROSS_REPO_COORDINATION.md)**.

---

## Dokumentation

| Emne | Fil |
|------|-----|
| Udviklings-guide (autoritativ) | [CLAUDE.md](CLAUDE.md) |
| Brugervejledning | [docs/USER_GUIDE.md](docs/USER_GUIDE.md) |
| AI / Gemini / RAG | [docs/AI_INTEGRATION.md](docs/AI_INTEGRATION.md) |
| Deployment (Posit Connect Cloud) | [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) |
| Konfiguration | [docs/CONFIGURATION.md](docs/CONFIGURATION.md) |
| Analytics & privacy (DPIA) | [docs/ANALYTICS_PRIVACY.md](docs/ANALYTICS_PRIVACY.md) |
| Arkitektur-beslutninger | [docs/adr/](docs/adr/) |
| Changelog | [NEWS.md](NEWS.md) |

## Licens

MIT — se [LICENSE](LICENSE).

## Support

Fejl og forbedringsforslag: [GitHub Issues](https://github.com/johanreventlow/biSPCharts/issues).
