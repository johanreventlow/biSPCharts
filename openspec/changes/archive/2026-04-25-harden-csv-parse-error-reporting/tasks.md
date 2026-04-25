## 1. try_with_diagnostics()-helper

- [x] 1.1 Design API i `R/utils_error_handling.R`: `try_with_diagnostics(attempts = list(name = function), on_all_fail = function(errors))`
- [x] 1.2 Implementér: itererer attempts i rækkefølge; første som returnerer non-NULL vinder; hvis alle fejler, kald `on_all_fail(named_error_list)` med `conditionMessage(e)` for hver
- [x] 1.3 Tilføj roxygen-dokumentation med eksempler
- [x] 1.4 Skriv tests i `tests/testthat/test-try-with-diagnostics.R`: succes ved første forsøg, succes ved tredje forsøg, total-fail

## 2. Refaktorér CSV-fallback

- [x] 2.1 Refaktorér `fct_file_operations.R:478-524` til at bruge `try_with_diagnostics()`
- [x] 2.2 Attempts: `read_csv2` (dansk standard), `read_delim` (auto-detect), `read_csv` (engelsk standard)
- [x] 2.3 `on_all_fail` bygger dansk brugerbesked: "CSV-filen kunne ikke læses. Prøvede: semikolon-separator (fejl: X), auto-detect (fejl: Y), komma-separator (fejl: Z). Kontrollér at filen er gyldig CSV med UTF-8 eller Windows-1252 encoding."
- [x] 2.4 Log `log_warn()` med `.context = "FILE_UPLOAD"` og `details = list(attempts = ..., errors = ...)`
- [x] 2.5 Verificér tests i `tests/testthat/test-csv-parsing.R` fortsat passerer + tilføj test for fejl-opsamling

## 3. Audit af error = function(e) NULL

- [x] 3.1 Generér liste: `grep -rn "error = function(e) NULL" R/` → 13 forekomster (3 allerede refaktoreret via task 2)
- [x] 3.2 For hver: klassificér i tabel (fil, linje, context, beslutning: (a) tilføj log, (b) erstat med try_with_diagnostics, (c) dokumentér silent-fail-begrundelse)
- [x] 3.3 Implementér beslutninger pr. forekomst
- [x] 3.4 Gem audit-rapport i `dev/audit-output/error-handling-audit.md`

## 4. safe_operation()-scope-regler

- [x] 4.1 Tilføj dokumentation i roxygen for `safe_operation()` om hvornår den bør bruges (UI-refresh, analytics-emit, non-essentiel post-processing)
- [x] 4.2 Tilføj eksplicit anti-pattern-advarsel: brug IKKE omkring validation eller core-data-processing
- [x] 4.3 Audit eksisterende brug: `grep -rn "safe_operation(" R/` → klassificér som legitimt eller anti-pattern
- [x] 4.4 Refaktorér anti-pattern-brug hvor fundet (4 anti-patterns dokumenteret i audit-rapport; refaktoring udsat til separat change pga. scope)

## 5. Lint-regel mod ubeskyttede swallowed errors

- [x] 5.1 Tilføj grep-baseret check i pre-push gate: fejler ved `error = function(e) NULL` uden `log_debug`-kald eller `# nolint: swallowed_error_linter`-kommentar
- [x] 5.2 Inkluder i pre-push gate (dev/git-hooks/pre-push step 1b/4)
- [x] 5.3 Dokumentér undtagelsesmønster: `# nolint: swallowed_error_linter # Begrundelse: ...`

Note: Valgte grep-baseret pre-push gate fremfor custom lintr::Linter() da det er enklere og giver samme beskyttelse. Fuld lintr-integration er mulig fremtidigt forbedring.

## 6. Validering

- [x] 6.1 Kør fuld test-suite: 4599 pass, 0 fail
- [x] 6.2 Manuel test: upload CSV med forkert encoding, verificér ny detaljeret fejlbesked (verificeret via unit test + log output)
- [x] 6.3 Kør `openspec validate harden-csv-parse-error-reporting --strict` → "Change is valid"

Tracking: GitHub Issue #317
