# Proposal: Fix Centerline Label Rounding

**ID:** fix-centerline-label-rounding
**Type:** bugfix
**Status:** completed
**Priority:** medium
**External Issue:** [BFHcharts #63](https://github.com/johanreventlow/BFHcharts/issues/63) (CLOSED)

## Problem Statement

Centerlinje (CL) labels på SPC charts viser "100%" selvom den faktiske centerlinjeværdi er tæt på men ikke præcis 100%. Centerlinjen placeres korrekt visuelt på chartet, men label-teksten rundes fejlagtigt op.

**Eksempel:**
- Faktisk CL-værdi: 98.7%
- Vist label: "100%"
- Forventet label: "98.7%" eller lignende præcis formatering

## Root Cause Analysis

### Ansvar

| Komponent | Ansvar | Involveret? |
|-----------|--------|-------------|
| SPCify | Parameter mapping, data prep | Nej (sender korrekt) |
| BFHcharts | Chart rendering, label formatering | **Ja (root cause)** |

### Teknisk Flow

1. **SPCify** sender `cl` parameter til BFHcharts via `bfh_qic()`
2. **SPCify** normaliserer værdier korrekt (0-100 → 0-1 for procent-charts)
3. **BFHcharts** modtager korrekt værdi men formaterer label forkert

### Verifikation

SPCify's parameter mapping i `R/fct_spc_bfh_service.R`:
```r
# Linje 808-816
if (!is.null(centerline_value)) {
  params$cl <- normalize_scale_for_bfh(
    value = centerline_value,
    chart_type = chart_type,
    param_name = "centerline"
  )
}
```

Værdien sendes korrekt - problemet ligger i BFHcharts' label rendering.

## Solution

### Anbefalet Approach

**Eskalér til BFHcharts** (korrekt arkitektur per CLAUDE.md):
- Opret GitHub issue i `johanreventlow/BFHcharts`
- Vent på fix fra BFHcharts maintainer
- Ingen workaround i SPCify (respekterer package boundaries)

### Rationale

Per SPCify's arkitekturprincipper:
- Label formatering er **BFHcharts' ansvar**
- SPCify er **integration layer**, ikke visualization engine
- Workarounds i SPCify ville bryde arkitekturgrænser

## Acceptance Criteria

- [x] GitHub issue oprettet i BFHcharts repo
- [x] BFHcharts issue indeholder reproduktion steps
- [x] SPCify OpenSpec linker til BFHcharts issue
- [x] Fix released i BFHcharts (deployed in v0.4.0)
- [x] SPCify opdateret til ny BFHcharts version (using v0.4.0)

## Related

- **Parent:** BFHcharts v0.3.0+ visualization API
- **Branch:** N/A (eskaleret til ekstern pakke)
