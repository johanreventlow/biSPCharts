# Cycle E — Export Pipeline Correctness + Security

**Status:** Claude review + Codex adversarial reconciled (2026-05-10). Område: PDF/PNG export, Quarto rendering, filename validation, metadata-injection, temp-file management, async/sync flows.

**Codex peer-review konsekvens:** 2 fix-strategier recalibreret (NEW1 + NEW3 begge runtime-broken som først foreslået). Pre-existing EH0/EM1/EM3 confirmed-fixed.

**Worktree:** `/Users/johanreventlow/R/biSPCharts-reviews` på `review/program-base` (synced med develop @ b37721b1).

**Driver:** Cycle A perf-review (2026-05-08) fandt 4 export-findings (EH0/EM1/EM2/EM3) der blev DOKUMENTERET men ikke straks implementeret. Cycle E re-verificerer + leder efter nye correctness/security-bugs.

**Overordnet vurdering:** Pipeline er **gennemgående velhærdet**. Pre-existing fund er enten allerede fixet (3/4) eller downgraded efter empirisk verifikation. Nye fund: 1 MEDIUM + 3 LOW. Ingen kritiske correctness/security-bugs.

---

## Pre-existing Cycle A findings — empirisk verifikation

### ✅ EH0 [VERIFIED FIXED siden Cycle A] — PDF-mode dobbeltgenerering

**Lokation:** `R/mod_export_server.R:486-491` + `R/mod_export_analysis.R:34, 53-56`

**Verifikation:**
- `R/mod_export_server.R:491` — `register_analysis_autogen(session, input, output, pdf_export_plot, app_state)` — autogen modtager nu `pdf_export_plot` (context "export_pdf") i stedet for `export_plot` (context "export_preview"). Linje 486-490 har eksplicit kommentar `#EH0 (Codex 2026-05-08)`.
- `R/mod_export_analysis.R:34` matcher signaturen.
- `R/mod_export_analysis.R:53-56` format-guard sikrer observer slet ikke evaluerer pdf_export_plot på PNG-mode.

**Effekt:** PDF-mode autogen og pdf_preview_image() deler nu samme reactive → cache-hit på anden eval.

**Action:** Ingen — fix dokumenteret + verificeret.

### ✅ EM1 [VERIFIED FIXED siden Cycle A] — Footnote PNG-render uden debounce

**Lokation:** `R/mod_export_server.R:78-85, 229, 234`

**Verifikation:** `debounced_footnote` defineret på top-of-server-scope (linje 82-85) med kommentar `#EM1 (Codex 2026-05-08)`. PNG-renderPlot læser kun debounced reactives:
- Linje 229: `dept_text <- trimws(debounced_dept())`
- Linje 234: `footnote_text <- trimws(debounced_footnote())`

Ingen direkte `input$export_footnote` / `input$export_department` i renderPlot-kroppen.

**Action:** Ingen.

### 🟡 EM2 [VERIFIED still-present, men DOWNGRADED LOW] — Auto-gen-tekst feedback

**Lokation:** `R/mod_export_analysis.R:42-116`

**Empirisk verifikation:** Cycle A's "infinity loop?"-spekulation holder ikke. Autogen observer's eneste non-isolated reactive er `pdf_export_plot()` (linje 62). `updateTextAreaInput` (linje 112) skriver til `input$pdf_improvement` som observeren IKKE depender på → ingen recursion. Eksisterende mitigeringer (`autogen_active`-flag linje 108-111, format-guard linje 53-56, isolate på metadata linje 69-78) lukker reelle feedback-paths.

**Konsekvens (kalibreret):** Idempotency mangler (linje 102-113): hvis `auto_text == current_text` skrives identisk værdi alligevel → ekstra JS-round-trip + `last_auto_analysis`-write retrigger toggle-observer. Ren perf-wart per pdf_export_plot-invalidation, ikke correctness.

**Foreslået fix (valgfrit):**
```r
# Indsæt før app_state$ui$last_auto_analysis <- auto_text (linje 103)
if (identical(auto_text, current_text)) return(invisible(NULL))
```

**Severity:** LOW (perf-wart, ej functional).

### ✅ EM3 [VERIFIED OK — kommentar på plads] — Outer debounce på pdf_preview_image

**Lokation:** `R/mod_export_server.R:437`

**Verifikation:** `}) |> shiny::debounce(millis = DEBOUNCE_DELAYS$metadata_input) # #646: 1500ms — Typst-render dyr, faerre cascades`. Trade-off-kommentar på plads.

**Action:** Ingen — bevidst design, dokumenteret.

---

## Nye fund

### 🟡 NEW1 — Temp-PNG-akkumulation per PDF-preview (MEDIUM, Connect long-session)

**Lokation:** `R/utils_server_export.R:389` (oprettelse) + `R/mod_export_server.R:468` (`deleteFile = FALSE`)

**Symptom:** Hver vellykket PDF-preview kalder `tempfile(fileext = ".png")` udenfor `temp_dir`. PNG-filerne ryddes ikke — hverken i `generate_pdf_preview()` (kun `temp_dir` ryddes på linje 417), af renderImage (`deleteFile = FALSE`), eller af `setup_session_cleanup()` (`R/utils_memory_management.R:14-59` rører ikke tempdir-PNGs).

**Verifikation:** `grep "bfh_preview_|temp.*png" R/utils_memory_management.R` → 0 hits. `deleteFile = FALSE`-kommentar siger "will be cleaned up by R session" — men på Shiny Connect kan sessions vare timer.

**Konsekvens:** På Connect med aktiv editing (debounce 1500ms = ~40 previews/min worst case under typing) akkumuleres PNGs (~300KB/stk) til R-session terminerer. Bounded by session lifetime, ikke unbounded — men kan nemt blive 100MB+ per lang session.

**Codex empirisk verifikation:** Live R-tempdir-simulation akkumulerede 1000 PNG-filer indtil process-cleanup. Bug confirmed.

**Foreslået fix (REVIDERET efter Codex — original Option A var runtime-broken):**

Codex fanget at `generate_pdf_preview(bfh_qic_result, metadata, dpi = 150)` har ej `session` i scope. Min original `session$token`-fix ville fejle med `object 'session' not found`.

**Korrekt Option A (eksplicit parameter):** Pass `preview_path` fra `mod_export_server.R` (hvor session er i scope) til `generate_pdf_preview()`:
```r
# R/utils_server_export.R:389 — change signature
generate_pdf_preview <- function(bfh_qic_result, metadata, dpi = 150,
                                  preview_path = NULL) {
  # ...
  png_path <- preview_path %||% tempfile(fileext = ".png")
  # ...
}

# R/mod_export_server.R caller — add stable per-session path
session_preview_path <- file.path(tempdir(),
  paste0("bfh_preview_session_", session$token, ".png"))
generate_pdf_preview(..., preview_path = session_preview_path)
```

**Korrekt Option B (manage-i-output):** Hold previous-path i `pdf_preview_image()`-reactive, unlink old file efter ny path er ready:
```r
# Inside pdf_preview_image() reactive
if (!is.null(prev_path) && file.exists(prev_path)) unlink(prev_path)
prev_path <<- new_path
```

**Korrekt Option C (cleanup-hook):** Tilføj i `setup_session_cleanup()`:
```r
unlink(list.files(tempdir(), pattern = "^bfh_preview_", full.names = TRUE))
```
Defense-in-depth — clean på session-end.

**Anbefaling:** Option A (eksplicit signature) + Option C (defense). Option B kompliceret pga. reactive-closure-state.

**Test:** Static assertion at `generate_pdf_preview()` ej kalder bare `tempfile(fileext = ".png")`.

**Severity:** MEDIUM — Connect-server-impact, ej crash men resource-footprint (verificeret 1000-fil-akkumulation i Codex-simulation).

---

### 🟢 NEW2 — Temp_dir-leak ved exception inden cleanup (LOW)

**Lokation:** `R/utils_server_export.R:315-417`

**Symptom:** `dir.create(temp_dir)` på linje 316; `unlink(temp_dir, recursive = TRUE)` på linje 417. Hvis `ggsave` (333), `bfh_extract_spc_stats` (352), `bfh_merge_metadata` (355), `bfh_create_typst_document` (372), `inject_template_assets` (386), eller `system2(quarto)` (409) throws → control hopper til `safe_operation`'s fallback-handler → unlink springes over.

**Konsekvens:** Tempdir-leak per failed preview. Bounded af R-session (tempdir slettes på exit). Lav reel impact, men brækker invariant.

**Foreslået fix:** Indsæt `on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)` umiddelbart efter `dir.create` på linje 316.

**Severity:** LOW — defensive cleanup; lav freq + bounded impact.

---

### 🟢 NEW3 — Filename uden længde-cap (LOW, defensiv)

**Lokation:** `R/utils_export_filename.R:57-95` (`generate_export_filename`)

**Symptom:** Title (max 200, `EXPORT_TITLE_MAX_LENGTH`) + department (max 250, `EXPORT_DEPARTMENT_MAX_LENGTH`) + "SPC_" + ".pdf" → potentielt ~460-tegns filnavn. NTFS/ext4 cap på 255 bytes.

**Verifikation:** `grep "MAX_FILENAME|substr.*255" R/` → 0 hits.

**Konsekvens:** Edge case ved ekstreme inputs. Moderne browsere håndterer typisk graceful (truncate på client-side), men PDF kan fejle download på enkelte clients. Ej observeret i praksis.

**Codex empirisk verifikation:** R confirmed: `nchar()` default = chars, ej bytes. **240 `æ` = 480 bytes** (UTF-8 multi-byte). `SPC_` + 240-char-`æ` + `.pdf` = 488 bytes — STADIG over 255-byte cap. Min original fix utilstrækkelig.

**Foreslået fix (REVIDERET efter Codex — byte-aware):**

```r
# R/utils_export_filename.R generate_export_filename()
# Reserve bytes for "SPC_" prefix + ".pdf" extension = 8 bytes
MAX_FILENAME_BYTES <- 250  # konservativ buffer under 255
RESERVED_BYTES <- nchar("SPC_", type = "bytes") + nchar(".pdf", type = "bytes")
max_base_bytes <- MAX_FILENAME_BYTES - RESERVED_BYTES

base_name <- enc2utf8(base_name)
while (nchar(base_name, type = "bytes") > max_base_bytes && nchar(base_name) > 0) {
  base_name <- substr(base_name, 1, nchar(base_name) - 1)
}
```

UTF-8-safe: `substr()` opererer på chars, så vi truncerer character-by-character indtil byte-cap respekteres. Forhindrer split af multi-byte code points.

**Test:** Regression-test med 240-char `æ`-titel + 250-char `ø`-department:
```r
test_that("filename respects 255-byte cap with Danish chars", {
  long_title <- strrep("æ", 200)
  long_dept <- strrep("ø", 250)
  filename <- generate_export_filename(long_title, long_dept, "pdf")
  expect_lte(nchar(filename, type = "bytes"), 255)
})
```

**Severity:** LOW — edge-case defensive (men nu med korrekt fix).

---

### 🟢 NEW4 — AI-suggestion bypasser autogen_active-guard (LOW, design-noteret)

**Lokation:** `R/mod_export_ai.R:287-309` (`handle_ai_suggestion_result`)

**Symptom:** `updateTextAreaInput(session, "pdf_improvement", value = suggestion)` på linje 289 sætter ej `set_autogen_active(app_state, TRUE)` som auto-pathen gør (`R/mod_export_analysis.R:108-111`).

**Vurdering:** Sandsynligvis intentionelt — AI-suggestion er bruger-initieret (knapklik) og BØR gemmes til settings_save. Men: `last_auto_analysis` opdateres ikke, så auto-indikatoren (linje 119-124) viser ej "auto" for den nyligt indsatte AI-tekst, og næste pdf_export_plot-invalidation kan overskrive AI-suggestion med deterministisk auto-tekst.

**Konsekvens:** I dag DOUBLE-MASKERET:
1. AI-feature er hidden via `ai.enabled: false` (Cycle G H_NEW)
2. Eksisterende user-edited-detection (`current_text != prev_auto` → `user_has_edited = TRUE` → no-op) håndterer faktisk AI-suggestion-overskriv korrekt

**Action:** Ingen — adfærd er konsistent med "AI-suggestion = user-input". Note værd hvis flow ændres ved AI-roll-out (Cycle G H0/H3).

**Severity:** LOW — note for fremtid.

---

## VERIFIED SAFE

- **`escape_typst_metadata`** (`R/utils_export_validation.R:357-390`): Comprehensive escape af Typst-markup (`#`, `$`, backtick, `*`, `_`, `[`, `]`, `<`, `>`, `@`, line-leading `=`,`-`,`+`,`/`). Tests i `tests/testthat/test-escape-typst-metadata.R` dækker injection-patterns inkl. `#raw(block: true, "hack")`. Alle metadata-felter bruger funktionen i `R/mod_export_server.R:381-392` + `R/mod_export_download.R:160-165`.
- **Filename path-traversal** (`R/utils_export_filename.R:158`): Regex `[^A-Za-z0-9_æøåÆØÅ-]` strips path separators, null bytes, special chars. Trailing `-` i character class behandles som literal hyphen.
- **Tab-guards (#644)**: Stadig på plads på alle reactives (`mod_export_server.R:97, 154, 182, 341, 444`) + `outputOptions(..., suspendWhenHidden = TRUE)` på `export_preview` (271) og `pdf_preview` (473). `mod_export_analysis.R:47` har samme guard FØR pdf_export_plot evalueres.
- **Quarto capability cache** (`R/utils_export_helpers.R:13-22`): Session-scoped cache via closure. `quarto_available()` wrapper bruger samme cache.
- **PDF size validation** (`R/mod_export_download.R:183-192`): Tjekker `is.null(result) || !file.exists(file)` OG `pdf_size < 512 bytes` for at fange korrupte/incomplete PDFs.
- **PNG dimension validation** (`R/utils_export_validation.R:118-170`): Min/max width 400-4000px, height 300-3000px → max ~50MB PNG. Aspect-ratio validation.
- **shinyjs::runjs ns()-interpolation** (`R/mod_export_ai.R:58-72`): `session$ns()` er server-genereret, ikke user-input → ingen XSS-vektor.

---

## Filer der modificeres ved implementation

| Prio | Fil | Ændring |
|------|-----|---------|
| NEW1 | `R/utils_server_export.R:389` ELLER `R/utils_memory_management.R:14-59` | Rotating-temp-PNG ELLER cleanup-hook |
| NEW2 | `R/utils_server_export.R:316` | `on.exit(unlink(temp_dir), add = TRUE)` |
| NEW3 | `R/utils_export_filename.R:82-83` | `if (nchar(base_name) > 240) substr(...)` |
| NEW4 | (ingen action) | Note for AI-roll-out |
| EM2 | `R/mod_export_analysis.R:103` | Idempotency-check (valgfrit) |

---

## Konsolideret prioritering

| Rank | ID | Område | Forventet gevinst | Risiko |
|------|----|--------|-------------------|--------|
| 1 | NEW1 | Rotating temp-PNG | Eliminér Connect-session-resource-leak | Triviel (1 linje) |
| 2 | NEW2 | on.exit-cleanup | Defensive cleanup invariant | Triviel (1 linje) |
| 3 | NEW3 | Filename-cap | Edge-case browser-compatibility | Triviel |
| 4 | EM2 | Idempotency-check | Perf-wart fix | Triviel |
| — | NEW4, EM3 | Note/no-action | — | — |

---

## Codex adversarial-review konsekvens (2026-05-10)

Verdict: **needs-attention** — pre-existing claims confirmed, men 2 nye-fund-fix-strategier broken:

**Bekræftet:**
- EH0/EM1/EM3: confirmed-fixed siden Cycle A (no re-breakage)
- NEW1: temp-PNG-akkumulation real (Codex simulerede 1000 filer)
- NEW3: filename-cap real (Codex verificerede 240 `æ` = 480 bytes)
- EM2 downgrade til LOW: confirmed (autogen ej recursion-prone)
- NEW2 + NEW4: confirmed

**Recalibreret:**
1. **NEW1 fix-strategi:** Min `session$token`-snippet ville fejle runtime fordi `generate_pdf_preview()` har ej `session` i scope. Korrekt: pass `preview_path`-parameter eksplicit fra `mod_export_server.R` (Option A) + cleanup-hook (Option C).
2. **NEW3 fix-strategi:** `nchar()` default = chars, ej bytes. 240 danish chars = 480 bytes → cap ineffective. Korrekt: `nchar(x, type = "bytes")` + UTF-8-safe truncation loop.

**Læringer:** `nchar()` byte-vs-char trap er klassisk R-fælde for UTF-8-tunge sprog. Filsystem-cap er always bytes.
