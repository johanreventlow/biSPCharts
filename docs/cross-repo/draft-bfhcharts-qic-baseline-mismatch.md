# Draft: BFHcharts sibling-issue — qicharts2 baseline mismatch (5 tests)

**Status:** Draft til BFHcharts-issue-oprettelse.
**Kontekst:** Genereret under §1.2.2 Kat F behandling i `harden-test-suite-regression-gate` (#228). GitHub MCP tools var ikke tilgængelige da draftet blev lavet — maintainer skal oprette issue i `BFHcharts` repoet manuelt.

## Brug

Kopiér sektionen "Issue body" nedenfor ind i et nyt issue på BFHcharts-repoet med titel:

> BFHcharts: cl/ucl/lcl/signal mismatch mod qicharts2 baseline (5 tests i biSPCharts)

Anvend template `.github/ISSUE_TEMPLATE/bfhchart-feature-request.md` i biSPCharts som udgangspunkt.

Når BFHcharts-issue er oprettet (antages `BFHcharts#NN`), opdatér de 5 skip-beskeder i biSPCharts fra den nuværende:

```
skip("BFHcharts-followup — se docs/cross-repo/draft-bfhcharts-qic-baseline-mismatch.md")
```

til:

```
skip("BFHcharts-followup — se BFHcharts#NN (qicharts2 baseline mismatch)")
```

---

## Issue body

### biSPCharts Context

**Use case i biSPCharts:** Regression-tests mod `qicharts2::qic()`-baselines for at sikre at BFHcharts-facaden producerer identiske statistiske værdier (cl, ucl, lcl, Anhøj signals) som qicharts2. Dette er biSPCharts' hybrid-arkitektur-kontrakt: BFHcharts er rendering-engine, qicharts2 er Anhøj-rules-autoritet.

**Affected biSPCharts feature:** Run chart + P-chart + Xbar/S chart statistik. Berører kvalitetskliniske dashboards hvor små afvigelser på centerlinje eller control limits kan ændre fortolkningen af en proces-stabilitet.

### Current workaround

5 tests er markeret `skip("BFHcharts-followup — ...")` i biSPCharts. Anhøj-rules-metadata hentes stadig fra `qicharts2::qic()` direkte via `extract_anhoej_metadata()` (hybrid-arkitektur), så UI-value-boxes er korrekte, men BFHcharts' egne beregninger afviger fra qicharts2 baseline.

### Impact på biSPCharts users

**Severity:** Medium — påvirker ikke UI-værdier direkte (Anhøj bruger qicharts2), men hvis BFHcharts' rendering af control-linjer divergerer fra qicharts2's numeriske værdier, kan brugere opleve visuel inkonsistens mellem (a) chart-linjer og (b) rapporterede statistik-værdier.

**Berørte chart-typer:** run, p, xbar, s.

---

### Problem statement

5 regression-tests i biSPCharts afdækker at BFHcharts-facaden `compute_spc_results_bfh()` returnerer `metadata$cl`, `metadata$ucl`, `metadata$lcl` og Anhøj signals der ikke matcher qicharts2 baseline for samme input-data.

### Specifikke afvigelser

| Test | Chart-type | Afvigelse | Kilde |
|---|---|---|---|
| Run chart freeze period | run | `cl` mismatch ved freeze_var | `tests/testthat/test-spc-regression-bfh-vs-qic.R:L210` |
| Xbar subgroup means | xbar | `ucl`/`lcl` mismatch | `L591` |
| S chart | s | `ucl`/`lcl`/`cl` mismatch | `L672` |
| Baseline run-basic | run | `cl` mismatch | `tests/testthat/test-spc-bfh-service.R:L691` |
| Baseline p-anhoej | p | signal mismatch mod qicharts2 Anhøj baseline | `L718` |

Alle 5 bruger `tests/testthat/fixtures/qic-baseline/*.rds` som er genereret fra `qicharts2::qic(..., return.data = TRUE)`.

### Mulige rod-årsager

1. **Freeze-variable-håndtering:** BFHcharts `freeze_var` kan have forskellig semantik end qicharts2's `freeze`-parameter (one-sided vs. two-sided freeze).
2. **Subgroup statistics for xbar/s:** BFHcharts beregner muligvis subgroup-means/SD med anden formel (fx `mean()` vs. weighted mean, eller Bessel-korrektion for SD).
3. **Anhøj-rules (p-anhoej):** BFHcharts implementerer måske en delvis Anhøj-rules-logik der afviger fra qicharts2's. biSPCharts bruger `extract_anhoej_metadata()` fra qicharts2 direkte, men BFHcharts-regression-tests tester BFHcharts' egen signal-detection.

### Forventet behavior

BFHcharts' `compute_spc_results_bfh()` output (eller equivalent API) bør returnere `metadata$cl`, `ucl`, `lcl`, og signal-detection værdier identiske med qicharts2's for alle standard SPC chart-typer.

### Acceptance criteria

- [ ] BFHcharts regression-suite mod qicharts2-baseline tilføjet (for at opfange divergens intern i BFHcharts)
- [ ] Rod-årsag for hver af de 5 divergenser identificeret
- [ ] Fix leveret (enten i BFHcharts eller som dokumenteret bevidst API-divergens)
- [ ] biSPCharts bumpes til ny BFHcharts-version og tests un-skippes

### Reference

- biSPCharts skip-inventory: `docs/test-suite-inventory-203.md`
- biSPCharts openspec change: `openspec/changes/harden-test-suite-regression-gate/` §1.2.2 Kat F
- biSPCharts parent issue: #229 (Fase 1 saneringsbunden)
- Relateret: biSPCharts #216 (andre tests afventer BFHcharts)
- CLAUDE.md §4 — BFHcharts/qicharts2 hybrid-arkitektur

---

## Note om #216

Eksisterende biSPCharts-issue #216 dækker andre BFHcharts-awaiting tests (`place_two_labels_npc`, NIVEAU 2/3 fallback). Dette nye issue-draft er **separat** da det dækker statistiske beregnings-afvigelser, ikke label-placement-validation.
