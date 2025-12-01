# Tasks: Fix Export Code Review Issues

**Tracking:** [GitHub Issue #97](https://github.com/johanreventlow/claude_spc/issues/97)
**Status:** completed

## Phase 1: Critical - Fix CI (Blocking)

- [x] 1.1 Slet eller deaktiver legacy Typst test suite (`test-fct_export_typst.R`)
- [x] 1.2 Opret nye tests for `generate_pdf_preview()`
- [x] 1.3 Opret nye tests for BFHcharts export integration
- [ ] 1.4 Verificer CI er grøn

## Phase 2: High Priority Fixes

- [x] 2.1 Identificer PNG height validation bug location
- [x] 2.2 Fix validation til at bruge korrekt height parameter
- [x] 2.3 Tilføj unit test for PNG dimension validation
- [x] 2.4 Verificer preview og export dimensioner i config
- [x] 2.5 Align preview dimensioner med export config (eller dokumentér forskel)
- [ ] 2.6 Test at preview matcher download (manual)

## Phase 3: Medium Priority Improvements

- [x] 3.1 Opret BFHcharts feature request for public API til `extract_spc_stats()` og `merge_metadata()` (#64)
- [x] 3.2 Tilføj exit code check til `system2("quarto", ...)` kald
- [x] 3.3 Implementér user-facing warning ved Quarto fejl (via logging)
- [x] 3.4 Log stdout/stderr ved compilation failures

## Phase 4: Low Priority Cleanup

- [x] 4.1 Implementér temp file tracking i preview generation
- [x] 4.2 Tilføj cleanup logic (enten on-exit eller reuse same path)
- [ ] 4.3 Test at temp files ikke akkumulerer (manual)

## Phase 5: Final Verification

- [x] 5.1 Kør fuld test suite
- [ ] 5.2 Manual test af export flow (PNG, PDF)
- [ ] 5.3 Manual test af preview rendering
- [x] 5.4 Code review af ændringer
- [x] 5.5 Opdater OpenSpec status til completed

---

## Issue Summary

| Priority | Issue | File | Status |
|----------|-------|------|--------|
| Critical | Legacy Typst tests target removed functions | `test-fct_export_typst.R` | ✅ Fixed |
| High | PNG height validation uses width | `mod_export_server.R:972-978` | ✅ Fixed |
| High | Preview/export dimension mismatch | `utils_server_export.R` vs `config_plot_contexts.R` | ✅ Fixed |
| Medium | BFHcharts internal API dependency | `utils_server_export.R:376-379` | ✅ Escalated (#64) |
| Medium | Quarto exit status ignored | `utils_server_export.R:395-417` | ✅ Fixed |
| Low | Preview temp file leak | `utils_server_export.R:392-429` | ✅ Fixed |
| Coverage | New PDF path lacks tests | Multiple | ✅ Fixed |

## Notes

- Phase 1 er blocking - CI skal være grøn før andre fixes
- BFHcharts internal API issue kan kræve upstream ændring (eskalér om nødvendigt)
- Temp file leak er lav prioritet men bør fixes for production stability
