# Implementation Tasks: migrate-to-bfhcharts-public-api

Tracking: GitHub Issue #98

## Phase 1: Dependency Update

- [ ] 1.1 Update BFHcharts version requirement in DESCRIPTION
  - Change from `BFHcharts (>= 0.3.6)` to `BFHcharts (>= 0.4.0)`
  - **File:** `DESCRIPTION`
  - **Validation:** Version requirement updated

## Phase 2: Code Migration

- [ ] 2.1 Update extract_spc_stats call
  - Replace `BFHcharts:::extract_spc_stats()` with `BFHcharts::bfh_extract_spc_stats()`
  - **File:** `R/utils_server_export.R:376`
  - **Validation:** Function call updated, no `:::` accessor

- [ ] 2.2 Update merge_metadata call
  - Replace `BFHcharts:::merge_metadata()` with `BFHcharts::bfh_merge_metadata()`
  - **File:** `R/utils_server_export.R:379`
  - **Validation:** Function call updated, no `:::` accessor

## Phase 3: Testing

- [ ] 3.1 Test PDF export with new API
  - Generate PDF from SPC chart
  - Verify PDF creation succeeds
  - Verify SPC statistics appear in PDF
  - Verify metadata appears correctly
  - **Validation:** PDF export works without errors

- [ ] 3.2 Run full test suite
  - Execute: `devtools::test()`
  - Verify: No regressions
  - **Validation:** All tests pass

## Phase 4: Quality Checks

- [ ] 4.1 Run R CMD check
  - Execute: `devtools::check()`
  - Verify: No new errors/warnings
  - **Validation:** Clean check output

- [ ] 4.2 Code review for `:::` usage
  - Search: `BFHcharts:::` in codebase
  - Verify: No remaining `:::` accessor usage
  - **Command:** `grep -r "BFHcharts:::" R/`
  - **Validation:** No matches found

## Phase 5: Documentation

- [ ] 5.1 Update NEWS.md
  - Add entry under bug fixes or improvements
  - Document: "Migrated to BFHcharts public API (requires BFHcharts >= 0.4.0)"
  - Reference GitHub issue #97
  - **File:** `NEWS.md`
  - **Validation:** Entry follows existing format

- [ ] 5.2 Commit changes
  - Commit message: `fix: migrate to BFHcharts public API (#97)`
  - Include all modified files
  - **Validation:** Git status clean, commit message follows conventions

## Phase 6: Deployment

- [ ] 6.1 Deploy BFHcharts 0.4.0 (if not already deployed)
  - Verify: BFHcharts 0.4.0 is available
  - **Validation:** `library(BFHcharts)` loads v0.4.0

- [ ] 6.2 Restart Shiny app
  - Reload: SPCify application
  - Verify: App starts without errors
  - **Validation:** No startup errors

- [ ] 6.3 Integration test in production
  - Test: Generate PDF from live SPC chart
  - Verify: PDF generation works
  - Verify: Metadata and stats correct
  - **Validation:** Production PDF export functional

- [ ] 6.4 Update GitHub issue #97
  - Add label: `openspec-deployed`
  - Close with comment referencing commit
  - **Validation:** Issue closed and labeled

- [ ] 6.5 Archive OpenSpec change
  - Execute: `openspec archive migrate-to-bfhcharts-public-api --yes`
  - **Validation:** Change moved to archive

## Dependencies

**Sequential dependencies:**
- Phase 1 → Phase 2 (dependency must be updated before using new API)
- Phase 2 → Phase 3 (code must be changed before testing)
- Phase 3 → Phase 4 (tests must pass before quality checks)
- Phase 4 → Phase 5 (quality verified before documentation)
- Phase 5 → Phase 6 (changes committed before deployment)
- Phase 6.1 must complete before 6.2-6.5 (BFHcharts must be deployed first)

**No parallel work:** All phases are sequential.

## Validation Criteria

**Phase 1 complete when:**
- DESCRIPTION requires `BFHcharts (>= 0.4.0)`

**Phase 2 complete when:**
- No `BFHcharts:::` accessor usage in codebase
- All calls use `BFHcharts::bfh_*` pattern

**Phase 3 complete when:**
- PDF export generates successfully
- All tests pass

**Phase 4 complete when:**
- `devtools::check()` shows no new errors/warnings
- No `:::` usage found in code review

**Phase 5 complete when:**
- NEWS.md updated
- Changes committed

**Phase 6 complete when:**
- BFHcharts 0.4.0 deployed
- SPCify app restarted successfully
- Production PDF export verified
- GitHub issue closed
- OpenSpec change archived

## Risk Mitigation

**Risk:** BFHcharts 0.4.0 not deployed before SPCify deployment
- **Mitigation:** Phase 6.1 checks for BFHcharts availability
- **Fallback:** Delay SPCify deployment until BFHcharts ready

**Risk:** API behavior differs from internal functions
- **Mitigation:** BFHcharts internal functions delegate to public API (identical behavior)
- **Validation:** Phase 3 testing verifies identical output

**Risk:** Missing error handling in public API
- **Mitigation:** BFHcharts public API has comprehensive validation
- **Benefit:** Better error messages than internal functions

## Notes

- **No breaking changes** - purely internal refactoring
- **No UI changes** - users won't notice any difference
- **Improved stability** - semantic versioning guarantees
- **Better errors** - public API has parameter validation
