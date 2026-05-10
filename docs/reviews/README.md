# Review-Program 2026-05

Systematisk dual-review-program: Claude (Sonnet/Opus) + Codex (GPT-5) kalibrerer hinanden.

## Process per cycle

1. **Claude review** — subagent-baserede Explore + Plan-agents på området; producerer fund-liste med file:line refs
2. **Codex adversarial-review** — modreview af Claude's plan; verificerer claims empirisk; foreslår alternativer
3. **Reconcile** — Claude kalibrerer plan baseret på Codex's mod-fund; markér dismissed/omskrevet/bekræftet
4. **Output** — markdown-rapport i `docs/reviews/NN-omraade.md` + (hvis behavioral impact) OpenSpec proposal
5. **Bruger godkender** implementation-omfang
6. **Implementer** atomic commits per fund efter VERSIONING_POLICY

## Arbejdsmiljø

- **Worktree:** `/Users/johanreventlow/R/biSPCharts-reviews` på branch `review/program-base`
- **Reviews:** `docs/reviews/` (denne mappe)
- **Implementation-branches:** `review/<NN>-<omraade-slug>` (én per cycle)

## Revideret område-liste (post-konsolidering)

| # | Cycle | Område | Status | Output |
|---|-------|--------|--------|--------|
| 1 | A | Cross-repo wrappers (BFH*-integration) | ✅ Komplet 2026-05-09 | [01-cross-repo-wrappers.md](01-cross-repo-wrappers.md) → PR #664 + #666 |
| 2 | B | Reactive state + persistence (#1+#3 merged) | ✅ Komplet 2026-05-09 | [02-reactive-state-persistence.md](02-reactive-state-persistence.md) → PR #671, #672, #673 + OpenSpec proposal `multi-tab-conflict-detection` |
| 6 | F | Observability + quality gates (#7+#10 merged) | ✅ Komplet 2026-05-09 | [03-observability-gates.md](03-observability-gates.md) → PR #676 (DCF-parse), #677 (lintr+M3), #678 (has_value), #679 (cleanup+Rd-regen) |
| 7 | G | AI/RAG integration | ✅ Komplet 2026-05-10 | [04-ai-rag.md](04-ai-rag.md) → PR #683 (H_NEW eksplicit feature-flag); H0/H3/H2 deferred til AI-roll-out |
| **CHECKPOINT** | — | Re-vurder rækkefølge | — | — |
| 3 | C | Excel I/O (round-trip + multi-sheet) | Pending | — |
| 4 | D | Data validering + dansk parsing | Pending | — |
| 5 | E | Export pipeline correctness + security | Pending — perf-findings EH0/EM1/EM2 fra Cycle A endnu ej impl | — |
| 8 | H | Security boundaries (kalibreret threat-model) | Pending | — |

## Læringer (opdateres per cycle)

### Cycle A (2026-05-09)

1. **Codex empiriske tests trumfer subagent-spekulation.** Mine subagents fandt H3 (logo fallback) og H4 (version-check) som HIGH; Codex kørte live-tests og afviste begge. Mine 4 HIGH → 1 BEKRÆFTET + 1 NYT (Codex-fundet) + 2 dismissed + 1 reconciled-til-policy.

2. **Codex finder ofte reelle fund subagents missede.** H1-NEW (`get_ai_config()` bruger `golem_options` ej `golem_config`) var ikke i nogen af mine 3 subagent-rapporter — Codex's live R-session med `GOLEM_CONFIG_ACTIVE=development` afslørede divergensen.

3. **Dev-tree vs installeret-pakke divergens er reel.** Begge BFHcharts "0.16.1" men forskellige API'er: installeret har `get_plot`, dev har `bfh_get_plot`. Skal verificeres med både `library(pkg)` + source-tree-inspektion.

4. **OpenSpec-validator kræver SHALL/MUST i requirement-body, ej kun header.** Stille fejl indtil eksplicit. Tilføj nøgleord i body-tekst.

5. **Pre-push manifest-gate kræver manuel entry for nye test-filer** (per memory). `classify_tests.R` regenererer fra forældet audit-JSON og dropper entries — TILFØJ MANUELT i `dev/audit-output/test-classification.yaml`.

6. **Atomic commits per fund er afgørende.** Cycle A genererede 9 commits over 2 PRs (#664 + #666). Hver commit reverterbar, hver review separat.

### Cycle A hotfix-trail (post-merge læringer)

Efter merge af #664 + #666 blev develop-CI rød. To hotfix-PRs (#668 + #669) krævet:

7. **Roxygen-doc-rename kræver `devtools::document()`-regen.** Parameter-rename i `R/`-fil opdaterede doc-comment men ej `man/*.Rd`-fil. R CMD check gate (`error-on: warning`) fanger codoc-mismatch som fail. **Procedure-fix:** efter parameter-rename → kør `devtools::document()` + commit `man/`-diff.

8. **Statiske source-fil-tests virker IKKE i R CMD check.** `readLines(test_path("../../R/foo.R"))` virker i `devtools::test()` (source-tree-adgang) men fejler i R CMD check (pakken installeres uden plain `.R`-filer). **Mønster-fix:** brug `deparse(body(fn))`-introspection — virker begge steder. Bonus: kommentarer ekskluderes automatisk (`deparse(body)` bevarer ej comments).

9. **Test-classification-manifest kan duplikere `rationale`-key ved auto-regen.** `classify_tests.R` har bug der tilføjer auto-rationale efter manuel entry → YAML duplicate-key-fejl. **Manuel cleanup:** efter første push-fail, fjern auto-genereret duplikat.

10. **Pre-merge CI ≠ post-merge CI.** PR-validation kører anderledes flag-sæt end develop-push-CI. Specifikt: `gate (tests + warnings)` med `error-on: warning` kører på PR-validation men "skipper" på direct-push. **Konsekvens:** grøn pre-merge ≠ grøn post-merge. Tjek post-merge-CI før næste arbejde.

11. **Branch-merge-konflikter er forventede når flere reviews kører parallelt.** Cycle A's #664 + #666 modificerede begge `R/app_run.R` (initialize_bfhllm + validate_branding_policy) + `dev/audit-output/test-classification.yaml`. Konflikt-resolution = standard merge-flow.

### Cycle B (2026-05-09)

12. **Subagent's "intet kalder X" claims er ofte ufuldstændige — tjek call-graph.** M3 dismissed: subagent missede at `cleanup_expired_queue_updates()` kaldes via `comprehensive_system_cleanup()`. **Procedure-fix:** følg call-graph 2-3 niveauer dyb før påstand om dead code.

13. **Codex empirisk verifikation reframer prio.** Min M2 "counter-nit" → Codex viste reel UX-bug (pre-autodetect render med stale columns). Min H1 "atomic-violation" → Codex fandt at transition kører atomically FØR observer.

14. **CI flaky perf-tests er ofte threshold-too-strict.** Cycle A merge → cycle B start blev forsinket af flaky `<10% overhead`-test på shared CI-runner. Pattern: `skip_on_ci()` + threshold-50% på micro-benchmarks.

15. **Manifest-entries skal verificeres for hver PR.** Cycle A test-classification-manifest blev tilsyneladende re-genereret efter merges → mine cycle A entries forsvandt. Tilføj manuelt for hver ny test-fil.

### Cycle F (2026-05-09)

16. **Codex empiriske grep finder false-confidence-tests.** M3 (test-navigation-no-double-emit.R bryder pattern Cycle B selv lærte om) ville aldrig være fundet uden Codex's `rg`-scan. Mit subagent-review missede pattern under skip_if_not-cover. **Procedure-fix:** Codex som second-pass er essentiel før man stoler på "test-suite enforcer X".

17. **Lintr/grep-distinktion er reel.** Codex argumenterede stærk for lintr over grep: variable-assigned patterns + wrappers gør grep utilstrækkelig. Vores eksisterende test (M3) beviste pointet empirisk — grep ville have misset det.

18. **Fix-snippet code-review er essentiel før commit.** Mit H3-snippet brugte `is.character(x) && nzchar(x)` som ville crashed runtime på multi-item character-vektorer (R-fejl: "the condition has length > 1"). Codex fanget via type-analyse. **Lesson:** kør foreslåede snippets gennem mental type-check FØR commit; bedre: skriv unit-test FØRST.

19. **Off-target Codex-runs har værdi.** Første Cycle F Codex-pass review'ede uventet diff-area (deferred Cycle B `multi-tab-conflict-detection`-spec) men fandt reel bug (`schema_version` vs faktisk `version`-key). Behold output som bonus-fund snarere end re-run-spild.

20. **Documenterede memory-mønstre er ikke nok uden maskinelle gates.** Cycle B introducerede `test-navigation-no-double-emit.R` MED kendskab til readLines-pattern fra PR #669 to timer tidligere. Manuel disciplin failer; lintr-regel ville have blokeret commit. **Procedure-fix:** for gentagne fejl-mønstre, byg automation (lintr/pre-commit-grep/CI-gate) i stedet for at stole på memory + reviews.

21. **Rd-regen drift akkumulerer over cycles.** Cycle F's `devtools::document()` regen'de 5 Rd-filer der havde været stale siden Cycle A+B. Memory-pattern (`feedback_post_merge_ci_gotchas.md` punkt 1) forhindrer ikke drift når flere cycles arbejder parallelt. **Tilføj** til pre-commit: hvis R-fil med roxygen-kommentar staged uden samtidig Rd-fil → blokér eller advarsel.

### Cycle G (2026-05-10)

22. **Bruger-kontekst overrides Codex-severity-claim.** Codex flagged H0 (data_consent missing) som CRITICAL "production AI broken end-to-end". Bruger informerede om hidden UI → severity downgraded til HIGH-blocking-for-re-enable. Empirisk verifikation i UI-koden bekræftede `style="display: none;"` med kommentar "midlertidigt skjult". **Procedure-fix:** spørg om feature-state FØR markering som CRITICAL; tjek UI for hide-modes.

23. **Facade-route kan bypasse audit-boundary.** Min H3-foreslåede facade-route via `generate_improvement_suggestion()` ville have skipped BFHcharts' audit-emission der sker INDE I `bfh_generate_analysis()` AFTER consent-validering. Codex fanget via call-graph-trace. **Lesson:** før refactor til "centralized helper"-pattern, verificer at helper bevarer ALL upstream-contracts (audit, validation, observability).

24. **Default-flag-fix giver false confidence hvis ej enforced.** Min H7-foreslåede 2-linje default-skift fra `enabled = TRUE` til `FALSE` ville have set ud som fail-closed-implementation, men `ai_config$enabled` checkes IKKE i nogen AI-egress-path. Codex fanget. **Lesson:** før config-default-fix, grep efter actual enforcement-points (`grep "config\\$enabled" R/`).

25. **Config-key-shapes mellem pakker kræver eksplicit adapter.** biSPCharts YAML bruger `max_requests_per_minute`, BFHllm forventer `rpm`. Naive forwarding via `do.call(BFHllm::bfhllm_configure, ...)` ville silent-ignore unknown keys. **Lesson:** cross-package-config kræver explicit-mapping + integration-test der inspicerer downstream-config-state via `BFHllm::bfhllm_get_config()`.

26. **"Hidden via CSS" er fragile feature-toggle.** display:none + missing API-key + missing consent = 3-lags by-accident-disable. Bryde 1 lag → re-enable. Eksplicit feature-flag i config + enforcement-check i alle paths = robust single-source-of-truth. Anti-pattern dokumenteret som H_NEW i Cycle G.

27. **Worktree-aware branching: tjek `git branch --show-current` FØR `git add`.** Cycle G impl: jeg `git add`-staged ændringer på master fordi jeg gennemførte editing i main-repo i stedet for worktree. Pre-commit blocked direkte master-commit. Måtte stash → switch-til-feature-branch-i-worktree → pop. **Procedure-fix:** start hver implementation-cycle med `cd <worktree> && git branch --show-current` confirm.

## Process-konstanter

- **Tidssbox:** Max 1 arbejdsdag per cycle. Sprænger → split område.
- **OpenSpec-tærskel:** Kun ved findings med behavioral/architectural impact.
- **Codex-budget:** Én adversarial-review per område. Reconcile via Claude.
- **Memory-update:** Hver cycle's lessons learned → `~/.claude/memory/`
