# Design: Posit Connect Cloud Deployment

**Dato:** 2026-04-09
**Status:** Godkendt

## Formål

Forbered biSPCharts til deployment på Posit Connect Cloud for peer review blandt kolleger. Inkluderer oprydning af udviklings-artefakter, dependency-håndtering og production-klar app entry point.

## Beslutninger

- **Deployment:** Git-backed fra GitHub, manuel trigger (ikke auto-publish)
- **AI-features:** Udeladt i første deployment (BFHllm valgfri)
- **Repo visibility:** Public midlertidigt (skift til private ved betalt abonnement)
- **Oprydning:** Blanding - fjern det åbenlyst overflødige, behold nyttig dokumentation

## Dependency-kæde

```
Posit Connect Cloud
  └── biSPCharts (GitHub: johanreventlow/biSPCharts)
        └── BFHcharts (GitHub: johanreventlow/BFHcharts, public)
              └── BFHtheme (GitHub: johanreventlow/BFHtheme, public)
```

BFHllm flyttes til Suggests (valgfri). Ragnar ikke nødvendig uden AI.

## Ændringer

### 1. DESCRIPTION

- Flyt `BFHllm (>= 0.1.0)` fra Imports til Suggests
- Tilføj Remotes felt:
  ```
  Remotes:
      johanreventlow/BFHcharts,
      johanreventlow/BFHtheme
  ```

### 2. BFHllm optional (kodeændringer)

Wrap direkte BFHllm-kald med `requireNamespace()` checks:
- `R/utils_bfhllm_integration.R` - initialize_bfhllm()
- `R/fct_ai_improvement_suggestions.R` - wrapper-funktioner

Eksisterende `is_bfhllm_available()` håndterer allerede graceful degradation i UI.

### 3. App entry points

**Ny `app.R` (production):**
```r
library(biSPCharts)
biSPCharts::run_app()
```

**Ny `dev/run_dev.R` (udvikling):**
Nuværende app.R-indhold flyttes hertil (sibling-loading, debug contexts, dev-options).

### 4. Fil-oprydning

**Slet:**
- `candidates_for_deletion/` (tom)
- `todo/` (4 afsluttede planer)
- `logs/` (86 runtime logfiler)
- `docs/archived/` (28 legacy-filer)
- `docs/plans/` (afsluttede designs - ekskl. dette dokument)
- `docs/superpowers/` (7 workflow-artefakter)
- `AGENTS.md` (redundant med CLAUDE.md)
- `CODE_QUALITY_REVIEW.md` (intern review)

**Behold:**
- `README.md`, `NEWS.md`, `CHANGELOG.md`
- `docs/USER_GUIDE.md`, `docs/CONFIGURATION.md`, `docs/DEPLOYMENT.md`
- `docs/adr/` (arkitekturbeslutninger)
- `docs/issues/` (historisk kontekst)

**Udvid `.Rbuildignore`:**
```
^dev$
^docs$
^openspec$
^\.github$
^Makefile$
^_brand\.yml$
^global\.R$
^\.claude$
^\.superpowers$
^todo$
^logs$
^candidates_for_deletion$
^CLAUDE\.md$
^AGENTS\.md$
^CODE_QUALITY_REVIEW\.md$
^GEMINI\.md$
```

### 5. Deployment

- Git-backed deployment fra GitHub
- Manuel trigger fra Connect Cloud UI
- Connect Cloud læser `app.R`, scanner DESCRIPTION, installerer via Remotes
- `GOLEM_CONFIG_ACTIVE` sættes til "production" på Connect Cloud

## Implementeringsrækkefølge

1. Oprydning - slet filer, udvid .Rbuildignore
2. Dependencies - DESCRIPTION ændringer, BFHllm optional
3. App entry points - production app.R, dev/run_dev.R
4. Test lokalt - verificer at appen starter med library(biSPCharts)
5. Commit og push til GitHub
6. Deploy fra Connect Cloud UI

## Fremtidige udvidelser

- Tilføj BFHllm/AI-features når BFHllm er klar til production
- Skift repo til private ved betalt Connect Cloud abonnement
- Overvej auto-publish on push når workflow er stabilt
