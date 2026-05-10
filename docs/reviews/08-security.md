# Cycle H — Security Boundaries

**Status:** Claude review komplet (2026-05-10). Område: input validation, file upload security, path traversal, XSS, code injection, session security, secret leakage.

**Worktree:** `/Users/johanreventlow/R/biSPCharts-reviews` på `review/program-base` (synced med develop @ b565d7e8).

**Outcome:** **No findings.** Forventet under kalibreret threat-model.

---

## Threat-model context

Per memory `project_security_threat_model.md` (2026-05-05):
- biSPCharts håndterer **kvalitetsindikator-data** (Anhøj rules, SPC-statistik over indikatorer som ventetider, infektioner, complications-rates), **IKKE patient-identificerbar information** (PHI/PII)
- Hospital-PCer er domain-joined + auth-gated
- Trussel-vektorer (browser-extensions, shared workstations) begrænsede
- Standard PHI/HIPAA-grade severity overdrevet i denne kontekst

**Default position:** wontfix + dokumentér rationale for biSPCharts-niveau security-flags.

---

## Tidligere DISMISSED findings (skal ikke genåbnes)

Per memory `project_security_findings_dismissed_2026_05_07.md`:

1. **CPR-scan kun på `pdf_description`** (8 andre fields ikke tjekket) — dismissed
2. **Shinylogs lækker free-text export-felter** — dismissed
3. **localStorage ukrypteret kliniske data (#528)** — wontfix efter PR #596 forsøg

Plus tidligere dismissed (Cycle G):
4. **AI-feature ej hidden bag eksplicit feature-flag** — addresseret via Cycle G H_NEW (PR #683)

---

## Review-områder + verifikation

### Auth/secret leakage
- `.Renviron.example` indeholder kun placeholders (verified)
- API keys delegated til BFHllm (ikke direkte `Sys.getenv` exposed i logs/UI)
- `.redact_secrets()` (utils_logging.R:250-263) saniterer field-names matching `(key|token|pat|password|secret|credential)`
- PAT redaction via `redact_pat_in_url()` + `sanitize_session_token()` verificeret

**Result:** Ingen secret-leak fundet.

### Path traversal
- `validate_safe_file_path()` (`R/fct_file_operations.R:61`) check'er upload-paths mod `tempdir()` whitelist
- `sanitize_filename()` (`R/utils_export_filename.R`) regex strips `[^A-Za-z0-9_æøåÆØÅ-]`
- Cycle E NEW3 byte-aware truncation forhindrer filename-overflow

**Result:** Ingen path-traversal fundet.

### Code injection
- **SQL injection:** Ingen DB-layer (R/grep `dbGetQuery`/`dbExecute` returnerer 0 hits)
- **Command injection:** `system2(quarto)`-kald (`R/utils_server_export.R:409` + `R/utils_export_helpers.R:62`) bruger fixed binary names + structured args (no user input)
- **R code injection:** Ingen dynamic-code-evaluation-kald med user input fundet (grep `parse(text=`/`source(text=` → 0 user-input-hits)

**Result:** Ingen code-injection-vektor fundet.

### XSS
- `HTML()`/`shinyjs::runjs()` audit: alle interpolerede værdier er server-controlled (`session$ns(...)`, numeric IDs, hard-coded strings) — IKKE user-input
- `escape_typst_metadata` (Cycle E verified-safe) escaper Typst-markup for export-pipeline

**Result:** Ingen XSS-vektor fundet.

### Session security
- Session-token redaktion verificeret (`tests/testthat/test-security-session-tokens.R`)
- Rate limiting via `RATE_LIMITS$file_upload_seconds` (`R/config_system_config.R:145`) på file uploads
- `cleanup_on_disconnect` (golem-config.yml) aktiveret per default

**Result:** Verified safeguards.

### File upload security
- Extension allowlist: csv/xlsx/xls. **`.xlsm` blokeres** (macro-enabled disallowed)
- MIME validation + size limits via `validate_uploaded_file()`
- ZIP-bomb protection (Cycle C verified) i `R/fct_file_validation.R:158-176`

**Result:** Verified safeguards.

### Network security
- Outbound API-calls (Gemini): delegeret til BFHllm
- HTTPS enforcement: håndteres af Posit Connect / reverse-proxy (per `golem-config.yml`-kommentar)
- Per CLAUDE.md: "HTTPS, CSP og CSRF haandteres af reverse-proxy/Posit Connect, ej app-niveau"

**Result:** Out-of-scope (infrastructure-level).

### Dependency vulnerabilities
- `oysteR`-scan kører ugentligt via `.github/workflows/security-audit.yaml`
- Ingen CRITICAL/HIGH alerts senest dependency-audit

**Result:** Aktivt monitoreret via CI.

---

## Defense-in-depth observations (LOW + DEFER, ikke flagged)

Følgende er observed men IKKE flagged som findings (per threat-model + dismissed-patterns):

1. **`utils_export_ui.R:322`** bruger `sprintf` til at injicere `ns(...)` namespace-IDs i `<script>`-tag — server-controlled values only, ikke user-influenced.
2. **`utils_input_sanitization.R:9-11`** noter at `sanitize_user_input` lever i `utils_export_validation.R` — single source of truth verificeret, ingen duplicate weak implementation.
3. **Excel kolonne-navne** (Cycle C H2): formula-injection potentiale via `=cmd`-prefixed headers. **DEFER** — kalibreret threat-model gør reel risiko meget lav (kræver bevidst manipuleret upload + tredjepart-explicit-edit).

---

## Konsolideret outcome

**Cycle H: 0 findings.**

Dette er forventet outcome efter:
- Cycles A-G har dækket reelle bugs/gaps på tværs af alle moduler
- Tidligere security-reviews (2026-05-07) har dismissed alle PHI-grade findings
- Threat-model er kalibreret + dokumenteret i memory
- Faktiske safeguards (sanitize_filename, validate_safe_file_path, RATE_LIMITS, escape_typst_metadata, redact_secrets, sanitize_session_token) verificeret aktiv

**Anbefaling:** Ingen action. Cycle H markeres komplet uden implementation.

**Læring (Cycle H):**

28. **Empty cycle er valid outcome under kalibreret threat-model.** Memory-baseret threat-model + tidligere dismissed-decisions giver review-agent klar grænse for hvad der er deploy-blokerende. Skip ej-blokerende defensive-fund. Forhindrer cycle-pressure-til-at-fabrikere-findings.
