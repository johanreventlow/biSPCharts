# Review #01 — Cross-Repo Wrappers (BFH-integration)

**Dato:** 2026-05-09
**Reviewer:** Claude (Sonnet/Opus) — 3 paralleled Explore-agents + Codex (GPT-5) adversarial-review
**Status:** Reconciled efter Codex peer-review

## Scope

Cross-repo integration mellem biSPCharts og sibling-pakker:
- BFHcharts (SPC rendering)
- BFHtheme (branding)
- BFHllm (AI/LLM)
- BFHchartsAssets (proprietære fonts/logoer)

Trigger: PR #660 fixede `BFHcharts::get_plot()`-kald der fejlede mod **dev-loaded BFHcharts** (source-tree har `bfh_get_plot`, installeret 0.16.1 har stadig `get_plot`). Begge version "0.16.1" men forskellige API-overflader — dev-tree er release-kandidat for næste version.

**Verificeret empirisk:**
- Installeret BFHcharts 0.16.1: `get_plot` exported (TRUE), `bfh_get_plot` (FALSE)
- Dev BFHcharts 0.16.1 (NEWS markeret "development"): `bfh_get_plot` exported

PR #660 fix (`result$plot` direkte access) virker mod begge — undgår API-version-afhængighed. Mål for review: find lignende latente API-mismatches + brittle integration-patterns.

## Reconciled findings (efter Codex peer-review)

### 🔴 HIGH — verificerede produktions-kritiske

#### H1 — `initialize_bfhllm()` defineret men aldrig kaldt ✅ BEKRÆFTET (Codex empirisk verificeret)
**Lokation:** `R/utils_bfhllm_integration.R:157-174` (definition)
**Symptom:** Funktion defineret med config-injektion (model, timeout, max_response_chars), men intet kalder den i `run_app.R`, `zzz.R`, eller modul-init.

**Codex empirisk verifikation:**
- BFHllm defaults: `model = gemini-3.1-flash-lite-preview`, `timeout_seconds = 120`
- biSPCharts config (`golem-config.yml`): `gemini-2.5-flash-lite`, timeout `10s` (prod) / `15s` (dev)
- `generate_bfhllm_suggestion()` passer kun `max_chars`, RAG, og cache per kald → model + timeout forbliver ellmer/BFHllm-defaults

**Konsekvens:** PRODUKTION kører AI-calls med 12× længere timeout end konfigureret + forkert model-version. Cost/latency/quality påvirket silent uden konfig-spor.

**Fix:**
- Tilføj `initialize_bfhllm(get_ai_config())` efter `configure_app_environment()` i `run_app()`
- Tilføj startup/integration-test der asserter `BFHllm::bfhllm_get_config()` reflekterer biSPCharts's aktive config
- Ofte koblet til H1-NEW (se nedenfor) — fix begge sammen

#### H1-NEW — `get_ai_config()` læser ikke YAML-profile aktivt ✨ NYT FUND (Codex)
**Lokation:** `R/utils_bfhllm_integration.R:21-46`
**Symptom:** `get_ai_config()` bruger `golem::get_golem_options("ai")` som læser runtime-options (sat ved `run_app(options = ...)`). Andre helpers (`get_session_config()`) bruger `get_golem_config("ai")` som læser YAML-profile.

**Codex empirisk verifikation:**
- `GOLEM_CONFIG_ACTIVE=development` → `get_golem_config("ai")$timeout_seconds` returnerer `15`
- Samme env: `get_ai_config()$timeout_seconds` returnerer `10` (default fra fallback)
- Profil-specifikke YAML-overrides ignoreres

**Konsekvens:** Selv hvis H1 fixes, vil profile-specifik AI-config (dev 15s vs prod 10s) ignoreres. Begge skal fixes for at AI-config virker korrekt.

**Fix:** Skift `get_ai_config()` + `get_rag_config()` til `get_golem_config("ai")`-pattern. Match `get_session_config()`-mønsteret. Tilføj profile-override-tests.

### 🟡 MEDIUM — brittle patterns (post-Codex-reconcile)

#### M2 — S3-dispatch sårbar mod class-rename (uændret)
**Lokation:** `R/utils_server_export.R:348` (`bfh_extract_spc_stats.bfh_qic_result`)
**Symptom:** S3-method dispatcher på class `bfh_qic_result`. Hvis BFHcharts omdøber class → silent fallback til default method.
**Fix:** Doc-comment + overvej runtime-class-check ved breaking-change-prone API.

#### M3 — PDF-export-error-check insufficient (uændret)
**Lokation:** `R/mod_export_download.R:178`
**Symptom:** Tjekker kun `is.null(result) || !file.exists(file)`. Korrupt fil med eksisterende non-NULL return → success-message vises.
**Fix:** Eksplicit return-code-check eller fil-størrelse-sanity.

#### M4 — `brand.yml` cached forever (uændret)
**Lokation:** `R/config_branding_getters.R:60-108`
**Vurdering:** Lav prio (dev-friction kun).

#### M5 — FONT_FALLBACK warning supprimeret i CI (uændret)
**Lokation:** `tests/testthat/test-context-aware-plots.R:138-142`
**Vurdering:** Koordinerings-issue mod BFHcharts upstream. Behold som dokumentation.

#### M6 — Font-registration multi-session contamination (uændret)
**Lokation:** `R/zzz.R:218–225`
**Vurdering:** Connect Cloud-relevant, on-prem irrelevant.

### ❌ DISMISSED efter Codex-verifikation

#### H3 (logo fallback validation) — DISMISSED
**Hvorfor:** Codex tjekkede `inst/app/www/BISPCHARTS.png` — eksisterer faktisk i tree. Min subagents antagelse om manglende fil var spekulativ.

#### H4 (version-check 0.14.0 → 0.16.1) — DISMISSED
**Hvorfor:** Min reasoning byggede på antagelse om get_plot-rename i installeret 0.16.1. Codex's empiriske test viser:
- Installeret BFHcharts 0.16.1: `get_plot` exported (stadig)
- DESCRIPTION-krav `>= 0.16.1` er ikke krænket af min PR #660 fix

Re-vurder kun hvis biSPCharts faktisk bruger 0.16.1-only API'er. **Aktion:** ingen ændring til zzz.R:229 før konkret 0.16.1-API påvist.

#### H2 (BFHchartsAssets validation) — RECONCILED → POLICY-DECISION
**Hvorfor:** Codex's analyse: manifest inkluderer pakken; soft-fail er bevidst design. Ej proven runtime-break, men product-policy-spørgsmål om hvorvidt prod skal fejle hard ved missing branding.
**Aktion:** Afventer brugers product-decision. Kan implementeres som golem-config-flag (`require_branded_assets: TRUE` i prod-profile).

#### M1 (requireNamespace guards på BFHcharts-core) — DISMISSED
**Hvorfor:** Codex bekræfter min egen vurdering: BFHcharts er i Imports: → R CMD INSTALL garanterer availability. Defense-in-depth uberettiget overengineering.

### 🟢 LOW — dokumentations-drift

#### L1 — `CROSS_REPO_COORDINATION.md` mangler API-rename-eksempel (justeret)
**Lokation:** `docs/CROSS_REPO_COORDINATION.md`
**Justering:** Eksemplet skal være præcist: dev-tree vs installeret API-divergens (ikke "rename efter version-bump"). Real lesson: source-tree's NEWS.md kan dokumentere "(development)" breaking changes der ikke er i installeret tagged release.

#### M2 — S3-dispatch sårbar mod class-rename
**Lokation:** `R/utils_server_export.R:348` (`bfh_extract_spc_stats.bfh_qic_result`)
**Symptom:** S3-method dispatcher på class `bfh_qic_result`. Hvis BFHcharts omdøber class → silent fallback til default method → forkert struktur.
**Fix:** Tilføj kommentar der dokumenterer dependency. Overvej runtime-check af class-navn ved breaking-change-prone API-surfaces.

#### M3 — PDF-export-error-check insufficient
**Lokation:** `R/mod_export_download.R:178`
**Symptom:** Tjekker kun `is.null(result) || !file.exists(file)`. Hvis BFHcharts returnerer non-NULL men korrupt fil → success-message vises men fil er incomplete.
**Fix:** Eksplicit return-code-check eller fil-størrelse-sanity-check.

#### M4 — `brand.yml` cached forever, ingen reload
**Lokation:** `R/config_branding_getters.R:60-108`
**Symptom:** Indlæst én gang i `.onLoad`, gemt i package-env. Disk-ændringer i session er usynlige.
**Konsekvens:** Dev-team der tester branding-ændringer skal restarte app.
**Fix (lav prio):** Optional file-change-watcher i dev-mode.

#### M5 — FONT_FALLBACK warning supprimeret i CI
**Lokation:** `tests/testthat/test-context-aware-plots.R:138-142`, `test-spc-plot-generation-comprehensive.R:398-400`
**Symptom:** `suppressWarnings(generateSPCPlot(...))` skjuler BFHcharts FONT_FALLBACK warning når CI mangler proprietære fonts. Upstream BFHcharts-issue tracket men ikke løst.
**Konsekvens:** Reelle font-config-issues i prod kan være skjult bag samme suppression.
**Fix:** Koordinér med BFHcharts: konvertér warning() → message() i upstream. Ej-blokerende for biSPCharts.

#### M6 — Font-registration side-effects på multi-session
**Lokation:** `R/zzz.R:218–225`
**Symptom:** Font-registration sker via `.onLoad()` — system-wide, ej session-isoleret. På Posit Connect Cloud (multi-user) kan to sessioner med forskellige `GITHUB_PAT`-konfigurationer interferere.
**Vurdering:** Affecter Connect Cloud (multi-user), ej hospital on-prem (single-user). Lavere prio givet biSPCharts's deployment-pattern.

### 🟢 LOW — dokumentations-drift

#### L1 — `CROSS_REPO_COORDINATION.md` mangler API-rename-eksempel
**Lokation:** `docs/CROSS_REPO_COORDINATION.md` (sidst opdateret 2025-10-17)
**Fix:** Tilføj sektion "Common API Renames" med `get_plot` → `bfh_get_plot`-eksempel som template for fremtidige cross-repo coordineringer.

## Hvad er ALLEREDE solidt (verificeret)

✅ Alle aktive `BFHcharts::*`-kald (13 stk) eksisterer i NAMESPACE 0.16.1 — ingen flere `get_plot`-style mismatches.
✅ Alle `BFHllm::*`-kald (4 stk) korrekt guarded med `requireNamespace()`.
✅ Mock-contracts (`mock_bfh_qic`, `mock_bfhllm_spc_suggestion`) auto-tilpasser sig upstream-API-trim via `formals()`-introspection.
✅ AI suggestion-pipeline har komplet error-handling: `safe_operation` + tryCatch i flere lag.
✅ ExtendedTask-async + sync fallback for AI-calls — non-blocking Shiny session.
✅ CPR-pattern-blocker FØR LLM-kald (PII-protection).
✅ Ingen API-key-leakage i logs (delegeret til ellmer).
✅ BFHtheme NEWS gennemgået — ingen breaking changes der rammer biSPCharts.

## Filer der skal modificeres (post-reconcile)

| Fund | Fil | Linje | Type | Prio |
|------|-----|-------|------|------|
| H1 | `R/app_run.R` (eller zzz.R) | efter `configure_app_environment()` | Init-call | KRITISK |
| H1-NEW | `R/utils_bfhllm_integration.R:21-46` | get_ai_config + get_rag_config refactor | Edit | KRITISK |
| H1+H1-NEW | `tests/testthat/` | ny integration-test | Add | KRITISK |
| H2 | `inst/golem-config.yml` (prod-profile) | `require_branded_assets: TRUE` | Add | POLICY |
| H2 | `R/zzz.R` (cond. på flag) | hard-fail hvis missing | Edit | POLICY |
| M2 | `R/utils_server_export.R:348` | Doc-comment | Edit | LAV |
| M3 | `R/mod_export_download.R:178` | Strengthen check | Edit | MEDIUM |
| L1 | `docs/CROSS_REPO_COORDINATION.md` | Tilføj sektion (dev vs installeret) | Edit | LAV |

## Læringer fra cycle A

1. **Codex empiriske tests trumfer subagent-spekulation.** Mine subagents antog logo-fil mangler (H3) og get_plot-rename (H4) — Codex testede direkte og afviste begge.
2. **Dev-tree vs installeret-pakke divergens er reel.** Begge "0.16.1" men forskellige API-overflader. Skal verificeres med både `library(pkg)` + source-tree-inspektion.
3. **Subagent's "high"-vurderinger må kalibreres.** Codex's mod-review reducerede mine 4 HIGH til 1 BEKRÆFTET HIGH (H1) + 1 NYT HIGH (H1-NEW) + 2 dismissed + 1 reconciled-til-policy.
4. **Reelt nye fund kommer ofte fra Codex.** H1-NEW (get_ai_config bug) var ikke i mine 3 subagent-rapporter — Codex's live R-session afslørede det.

## Implementations-anbefaling

**OpenSpec-tærskel vurdering:**
- H1 + H1-NEW kombineret = **arkitektonisk ændring** (AI-config-pipeline). Forslag: én OpenSpec-proposal "fix-bfhllm-config-injection" der dækker begge.
- M2, M3 = direkte commits (defensive coding, ej behavioral)
- H2 = AFVENTER bruger-policy-decision (require_branded_assets)
- L1 = direkte commit (docs)

**Implementation-rækkefølge:**
1. OpenSpec-proposal: bfhllm-config-injection (H1+H1-NEW) — KRITISK
2. Direkte commit: M2 + M3 + L1 (én PR, kode-hygiejne)
3. Bruger-decision: H2-policy (require_branded_assets)

## Næste skridt

✅ **Cycle A komplet.** Afventer bruger-godkendelse til implementation.
