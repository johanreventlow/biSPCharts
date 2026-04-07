# Manual Test Guide - Task #32 Stream B Completion

**Date:** 2025-10-15
**Purpose:** Manual validation of Shinytest2 integration tests
**Estimated Time:** 15-20 minutes

---

## Prerequisites

**Test Data Files Created:**
- ✓ `tests/manual-test-data/run_i_chart.csv` (Run/I charts)
- ✓ `tests/manual-test-data/p_u_chart.csv` (P/U charts)
- ✓ `tests/manual-test-data/c_chart.csv` (C chart)
- ✓ `tests/manual-test-data/freeze_test.csv` (Freeze line test)
- ✓ `tests/manual-test-data/comment_test.csv` (Comment annotations test)

**Backend Configuration:**
- Default: `use_bfhchart: false` (qicharts2 backend)
- Test with: qicharts2 backend (baseline validation)
- Optional: `use_bfhchart: true` (BFHchart backend - hvis tilgængelig)

---

## How to Launch the App

```bash
# Option 1: Launch from R console
R
> library(biSPCharts)
> run_app()

# Option 2: Launch from command line
Rscript -e "biSPCharts::run_app()"

# Option 3: RStudio
# Open app.R and click "Run App"
```

**Expected:** App launches without errors in browser

---

## Test Suite 1: Chart Type Integration (5 tests)

### Test 1.1: Run Chart

**Objective:** Validate Run chart renders without errors

**Steps:**
1. Launch app
2. Upload `tests/manual-test-data/run_i_chart.csv`
3. Configure:
   - **X-akse (Date):** Dato
   - **Y-akse (Value):** Tæller
   - **Chart Type:** Run chart
4. Click "Opdater graf" / wait for auto-render

**Expected Results:**
- ✓ Chart renders without errors
- ✓ No Shiny error notifications (red boxes)
- ✓ Median center line visible
- ✓ Data points plotted correctly
- ✓ Danish date labels on x-axis

**Result:** ☐ PASS ☐ FAIL

**Notes:** _______________________________________________

---

### Test 1.2: I Chart (Individuals)

**Objective:** Validate I chart renders with control limits

**Steps:**
1. Use same uploaded data (`run_i_chart.csv`)
2. Change **Chart Type:** I chart
3. Click "Opdater graf" / wait for auto-render

**Expected Results:**
- ✓ Chart renders without errors
- ✓ Mean center line visible
- ✓ Upper control limit (UCL) visible
- ✓ Lower control limit (LCL) visible
- ✓ Control limits are dashed lines

**Result:** ☐ PASS ☐ FAIL

**Notes:** _______________________________________________

---

### Test 1.3: P Chart (Proportions)

**Objective:** Validate P chart with numerator/denominator

**Steps:**
1. Upload `tests/manual-test-data/p_u_chart.csv`
2. Configure:
   - **X-akse:** Dato
   - **Y-akse:** Tæller
   - **N (denominator):** Nævner
   - **Chart Type:** P chart
3. Click "Opdater graf"

**Expected Results:**
- ✓ Chart renders without errors
- ✓ Proportion values displayed (0-1 or 0-100%)
- ✓ Variable control limits (hvis Nævner varierer)
- ✓ Center line (overall proportion)

**Result:** ☐ PASS ☐ FAIL

**Notes:** _______________________________________________

---

### Test 1.4: C Chart (Counts)

**Objective:** Validate C chart for count data

**Steps:**
1. Upload `tests/manual-test-data/c_chart.csv`
2. Configure:
   - **X-akse:** Dato
   - **Y-akse:** Tæller
   - **Chart Type:** C chart
3. Click "Opdater graf"

**Expected Results:**
- ✓ Chart renders without errors
- ✓ Count values plotted (integers)
- ✓ Poisson-based control limits visible
- ✓ LCL ≥ 0 (no negative counts)

**Result:** ☐ PASS ☐ FAIL

**Notes:** _______________________________________________

---

### Test 1.5: U Chart (Rates)

**Objective:** Validate U chart with variable denominator

**Steps:**
1. Use uploaded `p_u_chart.csv` data
2. Configure:
   - **X-akse:** Dato
   - **Y-akse:** Tæller
   - **N (denominator):** Nævner
   - **Chart Type:** U chart
3. Click "Opdater graf"

**Expected Results:**
- ✓ Chart renders without errors
- ✓ Rate values displayed
- ✓ Variable control limits (wider for small n)
- ✓ Center line (overall rate)

**Result:** ☐ PASS ☐ FAIL

**Notes:** _______________________________________________

---

## Test Suite 2: Feature Integration (2 tests)

### Test 2.1: Freeze Line Support

**Objective:** Validate freeze period handling

**Steps:**
1. Upload `tests/manual-test-data/freeze_test.csv`
2. Configure:
   - **X-akse:** Dato
   - **Y-akse:** Tæller
   - **Frys kolonne:** Frys
   - **Chart Type:** Run chart
3. Click "Opdater graf"

**Expected Results:**
- ✓ Chart renders without errors
- ✓ Freeze line marker visible (vertical line or shading)
- ✓ Freeze points visible but visually distinct (ghosted/different color)
- ✓ Control limits exclude freeze period
- ✓ No errors in console

**Result:** ☐ PASS ☐ FAIL

**Notes:** _______________________________________________

---

### Test 2.2: Comment Annotations

**Objective:** Validate comment annotations display correctly

**Steps:**
1. Upload `tests/manual-test-data/comment_test.csv`
2. Configure:
   - **X-akse:** Dato
   - **Y-akse:** Tæller
   - **Kommentar kolonne:** Kommentarer
   - **Chart Type:** Run chart
3. Click "Opdater graf"

**Expected Results:**
- ✓ Chart renders without errors
- ✓ Comment "Ændring implementeret" visible near point 4
- ✓ Danish characters (æøå) display correctly
- ✓ Comment readable without overlapping data points
- ✓ No XSS issues (comment is text, not executable code)

**Result:** ☐ PASS ☐ FAIL

**Notes:** _______________________________________________

---

## Test Suite 3: Backend Switching Validation

### Test 3.1: Feature Flag Default (Already Tested)

**Status:** ✅ PASSED (automated test in `test-bfh-module-integration.R`)

**Result:**
- Feature flag defaults to `use_bfhchart: false` ✓
- Supported types: `["run", "i", "p", "c", "u"]` ✓

---

### Test 3.2: Wrapper Function Structure (Already Tested)

**Status:** ✅ PASSED (automated test in `test-bfh-module-integration.R`)

**Result:**
- `generateSPCPlot_with_backend()` exists ✓
- `generateSPCPlot_qicharts2()` exists ✓
- Legacy alias `generateSPCPlot` correct ✓

---

## Optional: BFHchart Backend Testing

**⚠️ This step is OPTIONAL and requires BFHchart package installation**

### Test 4.1: Activate BFHchart Backend

**Steps:**
1. Edit `inst/golem-config.yml`
2. Change:
   ```yaml
   features:
     use_bfhchart: true  # Changed from false
   ```
3. Restart app
4. Repeat Test 1.1 (Run chart)

**Expected Results:**
- ✓ Chart renders without errors
- ✓ Visual output similar to qicharts2
- ✓ No errors in R console
- ✓ Backend wrapper successfully switched

**Result:** ☐ PASS ☐ FAIL ☐ SKIPPED (BFHchart ikke tilgængelig)

**Notes:** _______________________________________________

---

## Test Execution Summary

**Date Tested:** _______________
**Tester:** _______________
**App Version:** 0.1.0

### Results Overview

| Test ID | Test Name | Status | Notes |
|---------|-----------|--------|-------|
| 1.1 | Run Chart | ☐ PASS ☐ FAIL | __________ |
| 1.2 | I Chart | ☐ PASS ☐ FAIL | __________ |
| 1.3 | P Chart | ☐ PASS ☐ FAIL | __________ |
| 1.4 | C Chart | ☐ PASS ☐ FAIL | __________ |
| 1.5 | U Chart | ☐ PASS ☐ FAIL | __________ |
| 2.1 | Freeze Line | ☐ PASS ☐ FAIL | __________ |
| 2.2 | Comments | ☐ PASS ☐ FAIL | __________ |
| 3.1 | Feature Flag | ✅ PASS (automated) | Unit test passed |
| 3.2 | Wrapper Structure | ✅ PASS (automated) | Unit test passed |
| 4.1 | BFHchart Backend | ☐ PASS ☐ FAIL ☐ SKIP | Optional test |

**Overall Result:**
- ☐ ALL TESTS PASSED - Task #32 ready to close
- ☐ MINOR ISSUES - Document and proceed
- ☐ MAJOR FAILURES - Investigate and fix

---

## Troubleshooting

### Issue: App won't launch

**Solutions:**
```bash
# Check package installation
R -e "library(biSPCharts)"

# Reinstall if needed
R -e "devtools::install()"

# Check for errors in global.R
R -e "source('global.R')"
```

### Issue: File upload fails

**Solutions:**
- Verify file encoding is UTF-8
- Check file is valid CSV
- Ensure column names match (Dato, Tæller, etc.)

### Issue: Chart doesn't render

**Solutions:**
- Check R console for errors
- Verify column selections are correct
- Check browser console (F12) for JavaScript errors
- Restart app

### Issue: Danish characters corrupted

**Solutions:**
- Verify file saved with UTF-8 encoding
- Check `fileEncoding = "UTF-8"` in CSV read
- Verify browser locale settings

---

## Next Steps After Testing

### If All Tests Pass:

1. **Document Results:**
   - Fill in test execution summary above
   - Note any observations or minor issues

2. **Update Task #32 Status:**
   - Mark Stream B as 100% complete
   - Update completion documentation

3. **Commit Test Data and Guide:**
   ```bash
   git add tests/manual-test-data/ tests/MANUAL_TEST_GUIDE.md
   git commit -m "test: tilføj manual test guide og data for Task #32 afslutning"
   ```

4. **Close Task #32:**
   - Update task status to COMPLETED
   - Create final summary document

### If Tests Fail:

1. **Document Failures:**
   - Screenshot of error
   - Error messages from R console
   - Browser console errors (if applicable)

2. **Investigate:**
   - Check logs in app
   - Review relevant code sections
   - Run debugger if needed

3. **Fix and Retest:**
   - Make necessary code changes
   - Rerun failed tests
   - Update test results

---

## Contact/Support

**Developer:** Claude Code + Johan Reventlow
**Task Reference:** Task #32 - Shiny Module Integration (Stream B)
**Documentation:** `.claude/epics/bfhcharts-spc-migration/updates/32/`

**Related Files:**
- Test Suite: `tests/testthat/test-bfh-module-integration.R`
- Completion Doc: `.claude/.../task-32-stream-b-completion.md`
- Backend Wrapper: `R/fct_spc_plot_generation.R`

---

**Happy Testing! 🧪📊**
