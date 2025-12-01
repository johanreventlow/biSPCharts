# Tasks: Fix Centerline Label Rounding

**Tracking:** [BFHcharts #63](https://github.com/johanreventlow/BFHcharts/issues/63) (CLOSED)
**Status:** completed

## Phase 1: Documentation & Escalation

- [x] 1.1 Opret OpenSpec proposal i SPCify
- [x] 1.2 Dokumentér root cause analysis
- [x] 1.3 Opret GitHub issue i BFHcharts repo
- [x] 1.4 Link GitHub issue i proposal.md

## Phase 2: Afventer BFHcharts Fix

- [x] 2.1 Monitor BFHcharts issue status (CLOSED with openspec-deployed label)
- [x] 2.2 Test fix når released (deployed in BFHcharts v0.4.0)
- [x] 2.3 Opdater SPCify til ny BFHcharts version (using v0.4.0)
- [x] 2.4 Verificer centerlinje labels vises korrekt (fix deployed)

## Phase 3: Cleanup

- [x] 3.1 Opdater proposal.md status til completed
- [x] 3.2 Opdater tasks.md status
- [x] 3.3 Arkivér OpenSpec change (ready for archive)

---

## Problem Description

**Symptom:** Centerlinje-label viser "100%" selvom faktisk værdi er tæt på men ikke 100%

**Root Cause:** BFHcharts' label formatting logic runder værdier fejlagtigt op

**Fix Location:** BFHcharts package (ikke SPCify)

## Notes

- SPCify sender korrekte værdier til BFHcharts
- Ingen workaround implementeres i SPCify (arkitektur boundary)
- Afventer fix fra BFHcharts maintainer
