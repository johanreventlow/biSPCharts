# Manual Testing Checklist: AI Improvement Suggestions

**Feature:** AI-Assisteret Forbedringsmål via Gemini (Epic #69)
**Version:** 1.0
**Test Date:** _____________
**Tester:** _____________

## Prerequisites

- [ ] biSPCharts app running locally (`run_app()`)
- [ ] GOOGLE_API_KEY configured in `.Renviron`
- [ ] Sample CSV data available for upload
- [ ] Internet connection active

## Test Scenarios

### 1. Happy Path - Full Workflow

**Steps:**
1. Start biSPCharts app
2. Upload CSV file with date and numeric columns
3. Navigate to "Analyse" tab
4. Wait for auto-detection to complete
5. Verify SPC chart renders correctly
6. Navigate to "Eksport" tab
7. Select "PDF" format
8. Fill in metadata fields:
   - **Titel:** "Ventetid til operation 2024"
   - **Afdeling:** "Ortopædkirurgi"
   - **Datadefinition:** "Gennemsnitlig ventetid i dage fra henvisning til operation"
9. Click "✨ Generér forslag med AI" button

**Expected:**
- [ ] Button was initially enabled (not disabled)
- [ ] Spinner appears immediately (< 100ms)
- [ ] "Genererer forslag..." text shows
- [ ] Button disabled during generation
- [ ] Suggestion appears in "Forbedringsmål" field after 2-10 seconds
- [ ] Success notification shows: "✓ Forslag genereret..."
- [ ] Suggestion is meaningful Danish text (50-350 chars)
- [ ] Suggestion mentions process variation or target status
- [ ] Button re-enabled after completion

**Actual Result:** ___________________________________

---

### 2. Cache Hit Behavior

**Steps:**
1. Complete "Happy Path" test above
2. Without changing any data or metadata, click AI button again

**Expected:**
- [ ] Second click returns instantly (< 100ms)
- [ ] Exact same suggestion text returned
- [ ] No noticeable delay (cache hit)
- [ ] Success notification still shows

**Actual Result:** ___________________________________

---

### 3. Editable Suggestion

**Steps:**
1. Generate AI suggestion (from Happy Path)
2. Manually edit the generated text in "Forbedringsmål" field
3. Type additional text or modify existing text
4. Click download to generate PDF

**Expected:**
- [ ] Text field remains editable after AI insertion
- [ ] Manual edits are preserved
- [ ] PDF export includes edited text

**Actual Result:** ___________________________________

---

### 4. No SPC Data - Button Disabled

**Steps:**
1. Start fresh biSPCharts session
2. Navigate directly to "Eksport" tab
3. DO NOT upload data or generate chart first
4. Hover over AI button

**Expected:**
- [ ] AI button is disabled (greyed out)
- [ ] Tooltip shows: "Generér først en SPC-graf for at bruge AI-forslag"
- [ ] Clicking button does nothing

**Actual Result:** ___________________________________

---

### 5. Missing API Key - Button Disabled

**Steps:**
1. Unset GOOGLE_API_KEY environment variable
2. Restart R session
3. Start biSPCharts app
4. Upload data and generate chart
5. Navigate to Eksport tab
6. Hover over AI button

**Expected:**
- [ ] AI button is disabled
- [ ] Tooltip shows: "AI-funktionalitet kræver Google API-nøgle. Kontakt administrator."
- [ ] Clicking button does nothing

**Actual Result:** ___________________________________

---

### 6. API Timeout / Network Error

**Steps:**
1. Generate SPC chart with data
2. Disconnect internet (turn off WiFi)
3. Navigate to Eksport tab
4. Fill metadata
5. Click AI button

**Expected:**
- [ ] Spinner shows
- [ ] After timeout (~10 seconds), error notification appears
- [ ] Error message: "Kunne ikke generere forslag. Prøv igen eller skriv manuelt..."
- [ ] Button re-enabled after error
- [ ] App continues working (no crash)

**Actual Result:** ___________________________________

---

### 7. Empty Data Definition

**Steps:**
1. Generate SPC chart
2. Navigate to Eksport
3. Fill "Titel" and "Afdeling"
4. Leave "Datadefinition" field EMPTY
5. Click AI button

**Expected:**
- [ ] AI still generates suggestion (graceful handling)
- [ ] Suggestion may be more generic but still valid
- [ ] No error thrown

**Actual Result:** ___________________________________

---

### 8. Different Chart Types

**Test each chart type:**

**8a. Run Chart**
- [ ] Upload time series data
- [ ] Select "run" chart
- [ ] Generate AI suggestion
- [ ] Verify suggestion mentions "run chart" or natural variation

**8b. P Chart**
- [ ] Upload proportion data (with denominator)
- [ ] Select "p" chart
- [ ] Generate AI suggestion
- [ ] Verify Danish chart type name used

**8c. C Chart**
- [ ] Upload count data
- [ ] Select "c" chart
- [ ] Generate AI suggestion
- [ ] Verify Danish chart type name used

**8d. I Chart**
- [ ] Upload individual measurements
- [ ] Select "i" chart
- [ ] Generate AI suggestion
- [ ] Verify Danish chart type name used

**Actual Results:**
- Run: ___________________________________
- P: ___________________________________
- C: ___________________________________
- I: ___________________________________

---

### 9. Target Value Scenarios

**9a. No Target Value**
- [ ] Generate chart WITHOUT target line
- [ ] Generate AI suggestion
- [ ] Verify suggestion does NOT mention target comparison

**9b. Above Target**
- [ ] Generate chart with centerline > target (e.g., CL=40, target=30)
- [ ] Generate AI suggestion
- [ ] Verify suggestion mentions "over målet"

**9c. Below Target**
- [ ] Generate chart with centerline < target (e.g., CL=25, target=30)
- [ ] Generate AI suggestion
- [ ] Verify suggestion mentions "under målet"

**9d. At Target**
- [ ] Generate chart with centerline ≈ target (within 5%)
- [ ] Generate AI suggestion
- [ ] Verify suggestion mentions "ved målet"

**Actual Results:**
- No target: ___________________________________
- Above: ___________________________________
- Below: ___________________________________
- At: ___________________________________

---

### 10. Performance Test - Multiple Requests

**Steps:**
1. Generate SPC chart
2. Fill metadata
3. Click AI button 5 times in succession (with 10 sec delay between)
4. Vary "Datadefinition" slightly between clicks
5. Time each request

**Expected:**
- [ ] All 5 requests succeed
- [ ] First request takes 2-10 seconds (API call)
- [ ] Subsequent requests with same context are instant (cache hits)
- [ ] No errors or crashes
- [ ] Cache hit rate > 50%

**Actual Results:**
- Request 1: _______ seconds (new)
- Request 2: _______ seconds (cache hit expected)
- Request 3: _______ seconds
- Request 4: _______ seconds
- Request 5: _______ seconds
- Errors: _______

---

### 11. Large Dataset

**Steps:**
1. Upload CSV with 100+ rows
2. Generate SPC chart
3. Fill metadata
4. Click AI button

**Expected:**
- [ ] AI suggestion generates successfully
- [ ] No performance degradation
- [ ] Suggestion quality remains high

**Actual Result:** ___________________________________

---

### 12. Special Characters in Metadata

**Steps:**
1. Generate chart
2. Fill metadata with special characters:
   - Titel: "Ventetid > 30 dage (kritisk)"
   - Datadefinition: "Måling af \"akut\" ventetid"
3. Click AI button

**Expected:**
- [ ] AI handles special characters gracefully
- [ ] No parsing errors
- [ ] Suggestion generates successfully

**Actual Result:** ___________________________________

---

### 13. Long Metadata Inputs

**Steps:**
1. Generate chart
2. Fill "Datadefinition" with 500+ character description
3. Click AI button

**Expected:**
- [ ] AI processes long input
- [ ] Suggestion still respects 350 char limit
- [ ] No truncation errors

**Actual Result:** ___________________________________

---

### 14. Browser Console Errors

**Steps:**
1. Open browser developer console (F12)
2. Perform "Happy Path" test
3. Monitor console for errors

**Expected:**
- [ ] No JavaScript errors
- [ ] No warning messages
- [ ] No network errors (except expected Gemini API call)

**Actual Result:** ___________________________________

---

## Test Summary

**Total Scenarios:** 14
**Passed:** _______
**Failed:** _______
**Blocked:** _______

**Critical Issues Found:**
1. ___________________________________
2. ___________________________________

**Minor Issues Found:**
1. ___________________________________
2. ___________________________________

**Overall Assessment:** ☐ Pass ☐ Fail ☐ Pass with Issues

**Tester Signature:** _______________ **Date:** _______________

---

## Notes for Developers

- Integration tests (`test-integration-ai-gemini.R`) can be run with real API key
- Unit tests run automatically without API key (mocked)
- Performance test scenario (#10) should show cache efficiency
- All UI interactions should be smooth (no freezing during API calls)
