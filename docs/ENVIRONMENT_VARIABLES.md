# Environment Variables — biSPCharts

Centraliseret oversigt over alle env-vars brugt af biSPCharts.
Alle læses via `safe_getenv()` med typed coercion + dokumenteret default.

## Konventioner

- **Altid** `safe_getenv("VAR_NAME", default, type)` — ikke rå `Sys.getenv()`
- Type: `"character"` | `"logical"` | `"numeric"`
- Lokal udvikling: definér i `.Renviron` (git-ignored)
- Production: definér i RStudio Connect → Content → Vars

```r
# Eksempel — tilføj til .Renviron
GOLEM_CONFIG_ACTIVE=development
SPC_LOG_LEVEL=DEBUG
GOOGLE_API_KEY=AIzaSy...
```

---

## Kerne — forventes sat i produktionsmiljø

| Variable | Type | Default | Beskrivelse | Defineret i |
|----------|------|---------|-------------|-------------|
| `GOLEM_CONFIG_ACTIVE` | character | `"default"` | Aktivt golem-config-profil. Gyldige værdier: `default` / `development` / `production` / `testing`. Sættes automatisk af `configure_app_environment()` ved boot; `"production"` i prod, `"development"` lokalt. | `R/app_run.R`, `R/golem_utils.R` |

---

## Optional — Logging

| Variable | Type | Default | Beskrivelse | Defineret i |
|----------|------|---------|-------------|-------------|
| `SPC_LOG_LEVEL` | character | `"INFO"` (fallback) | Log-level: `DEBUG` / `INFO` / `WARN` / `ERROR`. Prioritet: env-var → YAML (`inst/golem-config.yml` `logging.level`) → code-fallback (`ERROR` i prod, `DEBUG` i dev, `INFO` ukendt miljø). Env-var har højeste prioritet og overrider YAML. | `R/utils_logging.R`, `R/app_run.R`, `R/app_runtime_config.R` |
| `SHINY_DEBUG_MODE` | logical | `FALSE` | Aktivér TRACE-level logging i advanced debug-systemet. Kun `TRUE` enabler TRACE-output; INFO og derover vises altid uanset denne flag. | `R/utils_advanced_debug.R`, `R/app_runtime_config.R` |
| `SPC_DEBUG_MODE` | logical | `FALSE` | App-niveau debug-mode. Trigger lazy-loading af `utils_advanced_debug.R` + initialiserer debug-historik (max 1000 entries) ved server-boot. | `R/app_server_main.R`, `R/utils_lazy_loading.R` |
| `SPC_SOURCE_LOADING` | character | `"FALSE"` | Verbose source-loading logs. Sat til `"FALSE"` = package-mode (library-loaded); til stede og `!= "FALSE"` = source-mode (debug). Cache-generator skelner package-mode fra source-mode via denne var. | `R/utils_cache_generators.R` |

---

## Optional — Test / boot

| Variable | Type | Default | Beskrivelse | Defineret i |
|----------|------|---------|-------------|-------------|
| `TEST_MODE_AUTO_LOAD` | character | `""` | Auto-load testdata ved boot. Hvis sat (non-tom), konverteres til `logical` og styrer test-mode. Overrides af golem-config's `test_mode` hvis den er sat. | `R/app_runtime_config.R`, `R/utils_cache_generators.R` |

---

## Optional — Analytics (shinylogs)

Prioritetsrækkefølge for analytics-aktivering:
`BISPC_DISABLE_ANALYTICS` (øverst) → golem-config `analytics.shinylogs_enabled` → `ENABLE_SHINYLOGS` (legacy, lavest).

Begge flag (`BISPC_DISABLE_ANALYTICS`, `ENABLE_SHINYLOGS`) accepterer case-insensitiv string-matching: `TRUE` / `1` / `YES` / `ON`.

| Variable | Type | Default | Beskrivelse | Defineret i |
|----------|------|---------|-------------|-------------|
| `BISPC_DISABLE_ANALYTICS` | character | `""` | Kill-switch til shinylogs-analytics. Sat til `TRUE` / `1` / `YES` / `ON` deaktiverer analytics uanset øvrige config. Tom streng = analytics er ikke tvunget fra. | `R/utils_shinylogs_config.R` |
| `ENABLE_SHINYLOGS` | character | `"TRUE"` | Legacy master-switch for shinylogs. Tages kun i brug hvis `BISPC_DISABLE_ANALYTICS` er tom OG golem-config ikke leverer `analytics.shinylogs_enabled`. | `R/utils_shinylogs_config.R` |

---

## Optional — Analytics pins / GitHub-sync

Bruges til at synkronisere shinylogs-data til et eksternt analytics-repo.
Alle tre (`GITHUB_PAT`, `PIN_REPO_URL`, `PIN_REPO_BRANCH`) skal sættes for at GitHub-sync er aktiv.
Alternativt: `CONNECT_SERVER` aktiverer pins-board via RStudio Connect.

| Variable | Type | Default | Beskrivelse | Defineret i |
|----------|------|---------|-------------|-------------|
| `GITHUB_PAT` | character | `""` | Personal Access Token til GitHub. Kræves til (a) GitHub-sync af analytics-logs via `gert` og (b) installation af BFHchartsAssets (privat repo) på Connect Cloud. Hvis tom: sync deaktiveres gracefully. | `R/utils_analytics_github.R`, `R/utils_analytics_pins.R` |
| `PIN_REPO_URL` | character | `""` | HTTPS-URL til analytics-repo (fx `https://github.com/org/analytics-repo.git`). Kræves sammen med `GITHUB_PAT` for GitHub-sync. | `R/utils_analytics_github.R`, `R/utils_analytics_pins.R` |
| `PIN_REPO_BRANCH` | character | `"main"` | Branch i analytics-repo som logs pushes til. Fallback `"main"` hvis tom. | `R/utils_analytics_github.R` |
| `CONNECT_SERVER` | character | `""` | RStudio Connect server-URL. Aktiverer `pins::board_connect()` som alternativ til GitHub-sync. Kun brugt hvis GitHub-sync ikke er konfigureret. | `R/utils_analytics_pins.R` |

---

## Optional — AI/LLM (BFHllm)

`GOOGLE_API_KEY` og `GEMINI_API_KEY` læses direkte af **BFHllm-pakken**,
ikke af biSPCharts selv. biSPCharts kræver blot at én af dem er sat i
miljøet så BFHllm kan autentificere mod Gemini API.

| Variable | Type | Default | Beskrivelse | Defineret i |
|----------|------|---------|-------------|-------------|
| `GOOGLE_API_KEY` | character | (ingen) | Gemini API-nøgle — foretrukket nøglenavn. Sættes i `.Renviron` lokalt; via Connect Vars i produktion. Påkrævet for AI-forbedringsforslagsfunktionen og RAG-knowledge-store. | `tests/manual/` (reference); læses af BFHllm |
| `GEMINI_API_KEY` | character | (ingen) | Alias for Gemini API-nøgle. BFHllm faldbacker til `GOOGLE_API_KEY` → `GEMINI_API_KEY` i nævnte rækkefølge. | `tests/manual/` (reference); læses af BFHllm |

---

## Legacy / intern

| Variable | Type | Default | Beskrivelse | Defineret i |
|----------|------|---------|-------------|-------------|
| `R_CONFIG_ACTIVE` | character | `""` | Golem/config-pakkes standard env-var. Mappes til `GOLEM_CONFIG_ACTIVE` for bagudkompatibilitet. Brug `GOLEM_CONFIG_ACTIVE` fremadrettet. | `R/golem_utils.R` |

---

## Validering ved boot

`validate_configuration()` køres ved boot (kaldt fra `run_app()`) efter
`configure_app_environment()`. Validerer:

1. `GOLEM_CONFIG_ACTIVE` er én af `default` / `development` / `production` / `testing`
2. Range-check på runtime-konstanter:
   - `DEBOUNCE_DELAYS` — 0–60 000 ms
   - `OPERATION_TIMEOUTS` — 0–600 000 ms

Ved ugyldige værdier signaleres en typed `bisp_config_error`-condition
(arver fra `bisp_error`), som fanger boot-fejl tidligt og giver
struktureret fejlmelding.

**Implementering:** `R/app_run.R::validate_configuration()`

---

## Lokal udvikling — `.Renviron` template

```bash
# Kopiér relevante linjer til .Renviron (git-ignored)
# Minimum for lokal kørsel:
GOLEM_CONFIG_ACTIVE=development
SPC_LOG_LEVEL=DEBUG

# For AI-features (BFHllm):
GOOGLE_API_KEY=AIzaSy-din-noegle-her

# For analytics-sync (valgfrit):
# GITHUB_PAT=ghp_din-pat-her
# PIN_REPO_URL=https://github.com/org/analytics-repo.git
# PIN_REPO_BRANCH=main
```

---

## Sikkerhed

- Secrets (API-nøgler, tokens, PAT) må **aldrig** committes til kodebasen
- `.Renviron` og `.env` er git-ignored — brug dem lokalt
- Production-secrets sættes via RStudio Connect Vars-UI eller Docker `env_file`
- Se `~/.claude/rules/SECURITY_BEST_PRACTICES.md` for fuld policy
