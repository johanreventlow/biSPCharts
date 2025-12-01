# Tasks: Fix Centerline Label Rounding

**Tracking:** [BFHcharts #63](https://github.com/johanreventlow/BFHcharts/issues/63)
**Status:** escalated

## Phase 1: Documentation & Escalation

- [x] 1.1 Opret OpenSpec proposal i SPCify
- [x] 1.2 Dokumentér root cause analysis
- [x] 1.3 Opret GitHub issue i BFHcharts repo
- [x] 1.4 Link GitHub issue i proposal.md

## Phase 2: Afventer BFHcharts Fix

- [ ] 2.1 Monitor BFHcharts issue status
- [ ] 2.2 Test fix når released
- [ ] 2.3 Opdater SPCify til ny BFHcharts version
- [ ] 2.4 Verificer centerlinje labels vises korrekt

## Phase 3: Cleanup

- [ ] 3.1 Opdater proposal.md status til completed
- [ ] 3.2 Opdater tasks.md status
- [ ] 3.3 Arkivér OpenSpec change

---

## Problem Description

**Symptom:** Centerlinje-label viser "100%" selvom faktisk værdi er tæt på men ikke 100%

**Root Cause:** BFHcharts' label formatting logic runder værdier fejlagtigt op

**Fix Location:** BFHcharts package (ikke SPCify)

## Notes

- SPCify sender korrekte værdier til BFHcharts
- Ingen workaround implementeres i SPCify (arkitektur boundary)
- Afventer fix fra BFHcharts maintainer
