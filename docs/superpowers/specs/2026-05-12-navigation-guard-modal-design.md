# Design: Navigation Guard Modal

**Dato:** 2026-05-12
**Branch:** `feat/navigation-guard-modal`
**Status:** Design — awaiting user review

---

## 1. Formål

Når brugeren har data indlæst og befinder sig på trin 2 (Analyser) eller
trin 3 (Eksport), skal app advare før destruktiv navigation tilbage til
trin 1 (Upload) / forside. Modal giver mulighed for at downloade
data + indstillinger som Excel-kopi inden session nulstilles.

Forhindrer utilsigtet datatab ved klik på logo, Upload-tab, "Tilbage"-knap
eller browser tab-close/refresh.

---

## 2. Kontekst

biSPCharts wizard har fire navigerbare tabs styret af `bslib::navbar`:

| Tab | ID | Indhold |
|------|-----|---------|
| Forside | `start` | Landing-side (`mod_landing_ui`), titel skjult |
| Trin 1 | `upload` | Fil-upload + paste-data |
| Trin 2 | `analyser` | SPC-analyse, kolonne-mapping, plot |
| Trin 3 | `eksporter` | Eksport (PDF/PNG/Excel) |

Logo navigerer til `start` (forside), Upload-tab navigerer til `upload`
(trin 1). Begge er destruktive når brugeren er på trin 2/3 med data.

Eksisterende infrastruktur (jf. exploration):

- **Event-bus:** `R/state_management.R:393` (`create_emit_api`),
  bl.a. `emit$navigation_changed()`, `emit$session_reset()`
- **Reset-funktion:** `R/utils_server_server_management.R:560`
  (`reset_to_empty_session`)
- **Download-handler:** `R/utils_server_wizard_gates.R:189-196`
  (`output$download_spc_file` via `spc_save_content` → `build_spc_excel`)
- **Modal-pattern:** `shiny::modalDialog` brugt i
  `utils_server_column_management.R:132`,
  `utils_server_server_management.R:677` (clear_confirmed)
- **Wizard-nav JS:** `inst/app/www/wizard-nav.js:173-178`
  (logo `#logo_home_link`)
- **Back-knap:** `R/utils_server_wizard_gates.R:199-204`
  (`input$back_to_upload`)

---

## 3. Designbeslutninger (afklaret med bruger)

| Beslutning | Valg | Begrundelse |
|------------|------|-------------|
| Trigger-betingelse | Kun hvis `app_state$data$current_data` er ikke-NULL | Undgår friktion ved tom session |
| Trigger-events | Logo (→`start`) + Upload-tab (→`upload`) + Back-knap (→`upload`) + `beforeunload` | Dækker alle exit-paths |
| Modal-layout | 2 knapper (Annullér / Nulstil) + checkbox "Download kopi først" | Færre primær-knapper, eksplicit opt-in for download |
| Checkbox default | `value = FALSE` | Default = "bare nulstil"; download er opt-in |
| Arkitektur-pattern | Centraliseret event-bus-guard (Approach A) | Matcher ADR-003 unified event architecture |
| Download-mekanisme | In-memory Excel-blob via `session$sendCustomMessage` | Undgår race mellem `downloadHandler` (HTTP GET) og `reset_to_empty_session` |
| beforeunload-scope | Kun browser tab-close/refresh, ikke in-app navigation | JS skelner via internt nav-flag |

---

## 4. Arkitektur

```
User-klik (logo→start / upload-tab→upload / back-knap→upload)
    │
    ▼
emit$navigation_requested(target)           ← R/state_management.R (ny event)
                                               target ∈ {"start","upload"}
    │
    ▼
setup_navigation_guard_listener()           ← R/utils_server_navigation_guard.R (NY)
    │
    ├─ is.null(app_state$data$current_data)? ─YES─▶ direct nav (bslib::nav_select)
    │
    └─ NO ─▶ app_state$navigation$guard_pending_target ← target
            showModal(navigation_guard_modal)
                │
                ├─ "Annullér"           ─▶ removeModal() + clear pending_target
                ├─ "Nulstil" (DL=FALSE) ─▶ reset_to_empty_session() + nav_select(target)
                └─ "Nulstil" (DL=TRUE)  ─▶ build_spc_excel_blob() → sendCustomMessage("download_blob")
                                          → reset_to_empty_session() + nav_select(target)
```

**beforeunload** = separat JS-hook med browser-native dialog
(ikke Shiny modal — `beforeunload` kører før Shiny kan rendre noget).

---

## 5. Komponenter

### 5.1 Nye filer

**`R/utils_server_navigation_guard.R`** — primær feature-fil

```r
#' Setup navigation guard listener
#'
#' Lytter på emit$navigation_requested() og viser modal hvis data findes.
setup_navigation_guard_listener <- function(app_state, emit, session) {
  observeEvent(app_state$events$navigation_requested,
    ignoreInit = TRUE,
    priority = OBSERVER_PRIORITIES$HIGH, {

    target <- app_state$navigation$guard_pending_target

    # Race-guard: ignorer hvis modal allerede vist
    if (!is.null(app_state$navigation$guard_modal_open) &&
        isTRUE(app_state$navigation$guard_modal_open)) {
      return(invisible(NULL))
    }

    if (is.null(app_state$data$current_data)) {
      # Tom session — direct nav
      bslib::nav_select("main_navbar", target)
      app_state$navigation$guard_pending_target <- NULL
      return(invisible(NULL))
    }

    app_state$navigation$guard_modal_open <- TRUE
    showModal(navigation_guard_modal())
  })

  # Modal-action observers
  observeEvent(input$nav_guard_confirm, {
    handle_nav_guard_confirm(app_state, emit, session, input)
  })

  observeEvent(input$nav_guard_cancel, {
    removeModal()
    app_state$navigation$guard_pending_target <- NULL
    app_state$navigation$guard_modal_open <- FALSE
  })
}

#' Build modal-dialog UI
navigation_guard_modal <- function() {
  modalDialog(
    title = "Forlad arbejde og start forfra?",
    tagList(
      tags$p("Du har data + indstillinger på arbejdsbordet."),
      tags$p(
        "Vil du starte forfra uden gemte ændringer?",
        " Du kan ikke fortryde denne handling."
      ),
      checkboxInput(
        "nav_guard_download",
        "Download kopi af data + indstillinger først",
        value = FALSE
      )
    ),
    footer = tagList(
      actionButton("nav_guard_cancel", "Annullér"),
      actionButton(
        "nav_guard_confirm",
        "Nulstil",
        class = "btn btn-danger"
      )
    ),
    size = "m",
    easyClose = FALSE,
    fade = TRUE
  )
}

#' Handle confirm-action (with/without download)
handle_nav_guard_confirm <- function(app_state, emit, session, input) {
  target <- app_state$navigation$guard_pending_target
  download_first <- isTRUE(input$nav_guard_download)

  safe_operation(
    "Navigation guard confirm",
    {
      if (download_first) {
        blob <- build_spc_excel_blob(app_state)
        session$sendCustomMessage(
          "download_blob",
          list(
            filename = generate_spc_filename(app_state),
            data_b64 = base64enc::base64encode(blob),
            mime_type = paste0(
              "application/vnd.openxmlformats-officedocument.",
              "spreadsheetml.sheet"
            )
          )
        )
      }

      reset_to_empty_session(app_state, emit, session)
      bslib::nav_select("main_navbar", target)
      removeModal()

      app_state$navigation$guard_pending_target <- NULL
      app_state$navigation$guard_modal_open <- FALSE
    },
    fallback = {
      showNotification(
        "Kunne ikke nulstille — prøv igen",
        type = "error",
        duration = 5
      )
      removeModal()
      app_state$navigation$guard_pending_target <- NULL
      app_state$navigation$guard_modal_open <- FALSE
    },
    session = session
  )
}

#' Generate Excel-blob fra current state (in-memory, no tempfile)
build_spc_excel_blob <- function(app_state) {
  # Bruger eksisterende build_spc_excel() (fct_spc_file_save_load.R)
  # men returnerer raw bytes i stedet for at skrive til fil
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  build_spc_excel(
    data = app_state$data$current_data,
    settings = collect_current_settings(app_state),
    output_path = tmp
  )

  readBin(tmp, what = "raw", n = file.info(tmp)$size)
}
```

**`tests/testthat/test-navigation-guard.R`**

Test-cases (se §8 Testing).

### 5.2 Ændrede filer

| Fil | Ændring | Linjer (estimat) |
|-----|---------|------------------|
| `R/state_management.R` | Tilføj `emit$navigation_requested(target)` + `app_state$navigation` substate (`guard_pending_target`, `guard_modal_open`, `guard_has_data_flag`) | +30 |
| `R/utils_server_events_navigation.R` | Kald `setup_navigation_guard_listener(app_state, emit, session)` ved session-start | +5 |
| `R/utils_server_wizard_gates.R:199-204` | Refactor `input$back_to_upload`: erstat direkte `nav_select` med `emit$navigation_requested("upload")` | ~5 lines modified |
| `R/app_server.R` | Registrer setup-funktion (hvis ikke gjort via events_navigation.R) | +2 |
| `R/app_ui.R:87-92` | Tilføj `data-nav-guard="true"` til Upload `nav_panel` så JS kan intercepte click | +1 |
| `inst/app/www/wizard-nav.js` | Logo-intercept + tab-intercept + beforeunload-hook + download_blob-handler | +50 |

### 5.3 JS-ændringer (`inst/app/www/wizard-nav.js`)

```javascript
// Global flag for in-app navigation (bypass beforeunload)
let inAppNavigating = false;

// Intercept logo-klik
document.addEventListener('click', (e) => {
  const logo = e.target.closest('#logo_home_link');
  if (!logo) return;

  const currentStep = getCurrentStep();  // helper
  const hasData = Shiny.shinyapp.$inputValues['nav_guard_has_data'] === true;

  if ((currentStep === '2' || currentStep === '3') && hasData) {
    e.preventDefault();
    e.stopPropagation();
    Shiny.setInputValue('nav_guard_trigger', {
      source: 'logo',
      target: 'start',  // logo → forside, ikke upload
      timestamp: Date.now()  // force re-trigger
    });
  }
  // Hvis trin 1 eller ingen data: lad default action køre (start-tab.click())
});

// Intercept Upload-tab-klik
document.addEventListener('click', (e) => {
  const tab = e.target.closest('[data-value="upload"]');
  if (!tab) return;

  const currentStep = getCurrentStep();
  const hasData = Shiny.shinyapp.$inputValues['nav_guard_has_data'] === true;

  if ((currentStep === '2' || currentStep === '3') && hasData) {
    e.preventDefault();
    e.stopPropagation();
    Shiny.setInputValue('nav_guard_trigger', {
      source: 'tab',
      target: 'upload',
      timestamp: Date.now()
    });
  }
});

// beforeunload — kun tab-close/refresh, ikke in-app nav
window.addEventListener('beforeunload', (e) => {
  if (inAppNavigating) return;
  const hasData = Shiny.shinyapp.$inputValues['nav_guard_has_data'] === true;
  if (hasData) {
    e.preventDefault();
    e.returnValue = '';  // browsere viser native prompt
  }
});

// Set inAppNavigating flag før nav-confirm (clear via setTimeout efter nav)
Shiny.addCustomMessageHandler('set_in_app_navigating', (val) => {
  inAppNavigating = !!val;
});

// Download-blob handler (download før reset)
Shiny.addCustomMessageHandler('download_blob', (msg) => {
  const blob = base64ToBlob(msg.data_b64, msg.mime_type);
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = msg.filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 1000);
});

function base64ToBlob(b64, mimeType) {
  const bytes = atob(b64);
  const arr = new Uint8Array(bytes.length);
  for (let i = 0; i < bytes.length; i++) arr[i] = bytes.charCodeAt(i);
  return new Blob([arr], { type: mimeType });
}

function getCurrentStep() {
  const activeTab = document.querySelector('#main_navbar .nav-link.active');
  return stepMap[activeTab?.getAttribute('data-value')] ?? '1';
}
```

**Server pusher `nav_guard_has_data`-flag** når `current_data` ændres:

```r
# I R/state_management.R eller observer der watcher current_data
observe({
  has_data <- !is.null(app_state$data$current_data) &&
              nrow(app_state$data$current_data) > 0
  session$sendCustomMessage(
    "nav_guard_has_data_update",
    list(value = has_data)
  )
})
```

JS-side opdaterer `Shiny.shinyapp.$inputValues['nav_guard_has_data']`
via en `addCustomMessageHandler`.

---

## 6. Data-flow

### 6.1 Tom session (current_data = NULL)

```
User klik logo (trin 2)
  → JS: hasData=false → lad default action køre
  → Logo-default routerer til start-tab (eksisterende adfærd)
  → Ingen modal, ingen state-ændring
```

### 6.2 Data findes, bruger annullerer

```
User klik logo (trin 2, data findes)
  → JS: hasData=true → preventDefault + setInputValue("nav_guard_trigger")
  → R: emit$navigation_requested("upload")
  → app_state$navigation$guard_pending_target = "upload"
  → app_state$navigation$guard_modal_open = TRUE
  → showModal()
  → User klik "Annullér"
  → input$nav_guard_cancel → removeModal() + clear flags
  → Bruger forbliver på trin 2, data intact
```

### 6.3 Data findes, bruger nulstiller uden download

```
User klik logo → ... → modal vist
  → User klik "Nulstil" (checkbox=FALSE)
  → handle_nav_guard_confirm():
      → safe_operation():
          → reset_to_empty_session(app_state, emit, session)
              → clearDataLocally(session)
              → app_state$data$current_data ← NULL
              → app_state$columns$auto_detect$completed ← FALSE
              → emit$data_updated("new_session")
              → emit$navigation_changed()
              → emit$session_reset()
          → sendCustomMessage("set_in_app_navigating", TRUE)
          → bslib::nav_select("main_navbar", "upload")
          → removeModal()
          → clear pending_target + guard_modal_open
      → setTimeout 500ms: sendCustomMessage("set_in_app_navigating", FALSE)
```

### 6.4 Data findes, bruger nulstiller MED download

```
User klik logo → ... → modal vist
  → User tikker checkbox + klik "Nulstil"
  → handle_nav_guard_confirm():
      → safe_operation():
          → blob ← build_spc_excel_blob(app_state)
          → sendCustomMessage("download_blob", { filename, data_b64, mime })
              → JS: createObjectURL + <a download>.click()
              → Browser gemmer fil
          → reset_to_empty_session() (som §6.3)
          → nav_select("upload")
          → removeModal()
      → fallback: hvis build_spc_excel_blob fejler →
        notification "Kunne ikke nulstille" + cleanup
```

### 6.5 Browser tab-close (beforeunload)

```
User klikker x på tab (data findes på trin 2)
  → beforeunload event
  → JS: inAppNavigating=false + hasData=true
  → e.preventDefault() + e.returnValue=''
  → Browser viser native "Forlad side?"-prompt
  → User bekræfter → tab lukker (state mistes — som forventet)
  → User annullerer → forbliver på siden
```

---

## 7. Error handling

| Scenario | Håndtering |
|----------|------------|
| `build_spc_excel_blob` fejler | `safe_operation` fallback → notification "Kunne ikke nulstille" + cleanup modal-flags, behold state |
| `reset_to_empty_session` fejler | `safe_operation` fallback (allerede implementeret) → notification + log_error |
| Modal dismiss (Esc/baggrund) | `easyClose=FALSE` blokerer; kun knap-actions afslutter |
| Race: ny nav-event mens modal vises | `guard_modal_open=TRUE` guard → ignorerer ny emit |
| Download-blob > 50 MB | Base64-encoding inflater ~33%; for 50 MB datasæt = ~66 MB message. Acceptable. For større filer: fallback til `downloadHandler` + delay-reset (out of scope MVP) |
| JS-message ikke modtaget | Tab-close midt under download → state allerede reset server-side; bruger mister fil men ikke værre end normal tab-close. Log warning |
| `nav_guard_has_data` flag desynkroniseret | Server pusher ved hver `current_data`-ændring; ved usynkronisering åbnes modal "for meget" (acceptabelt fallback) ikke "for lidt" |

---

## 8. Testing

### 8.1 Unit tests (`tests/testthat/test-navigation-guard.R`)

```r
test_that("emit$navigation_requested triggrer direct nav når data er NULL", {
  app_state <- create_test_app_state(current_data = NULL)
  emit <- create_emit_api(app_state)
  session <- create_test_session()

  setup_navigation_guard_listener(app_state, emit, session)

  isolate({
    emit$navigation_requested("upload")
  })

  expect_null(app_state$navigation$guard_pending_target)
  expect_false(isTRUE(app_state$navigation$guard_modal_open))
})

test_that("emit$navigation_requested viser modal når data findes", {
  app_state <- create_test_app_state(
    current_data = data.frame(x = 1:5, y = 6:10)
  )
  # ... mock showModal ...

  isolate({
    emit$navigation_requested("upload")
  })

  expect_equal(app_state$navigation$guard_pending_target, "upload")
  expect_true(app_state$navigation$guard_modal_open)
})

test_that("handle_nav_guard_confirm uden download nulstiller state", {
  # Setup state med data
  # Mock input$nav_guard_download = FALSE
  # Kald handle_nav_guard_confirm
  # Assert: current_data = NULL, columns$auto_detect$completed = FALSE
})

test_that("handle_nav_guard_confirm med download sender blob før reset", {
  # Setup state med data
  # Mock input$nav_guard_download = TRUE
  # Mock session$sendCustomMessage
  # Assert: sendCustomMessage kaldt med "download_blob" + data_b64
  # Assert: current_data = NULL (reset sket EFTER send)
})

test_that("nav_guard_cancel rydder pending_target uden state-ændring", {
  # ...
})

test_that("ny navigation_requested ignoreres mens modal open", {
  # Setup: guard_modal_open = TRUE
  # Emit ny request
  # Assert: pending_target uændret
})

test_that("build_spc_excel_blob returnerer raw bytes med XLSX-magic", {
  app_state <- create_test_app_state_with_data()
  blob <- build_spc_excel_blob(app_state)
  expect_type(blob, "raw")
  expect_true(length(blob) > 0)
  # XLSX = ZIP = magic bytes 0x50 0x4B 0x03 0x04
  expect_equal(blob[1:4], as.raw(c(0x50, 0x4B, 0x03, 0x04)))
})
```

### 8.2 Integration tests

- `emit$navigation_requested` → guard_pending_target opdateres → observer fires
- Event-bus chain: navigation_requested → modal → confirm → session_reset → navigation_changed

### 8.3 shinytest2 (i `tests/manual/`)

Per [[feedback_shinytest2_upload_flow]]: upload-flow kræver nav til upload-tab
+ klik load_paste_data, ikke `app$upload_file` direkte. Drop
`expect_screenshot`.

```r
test_that("Navigation guard modal vises ved logo-klik på trin 2", {
  app <- AppDriver$new()
  # ... upload data via paste-flow ...
  app$click("nav_to_analyser")  # forward til trin 2
  app$click("logo_home_link")
  app$wait_for_idle()
  expect_true(app$get_html(".modal") != "")
  app$click("nav_guard_cancel")
  expect_equal(app$get_value(input = "main_navbar"), "analyser")
})
```

### 8.4 Edge cases

- Tom session på trin 1 → klik logo → ingen modal (currentStep!=2,3)
- Upload-tab klik fra trin 1 → ingen modal
- Data findes men `nrow == 0` → behandl som tom (ingen modal)
- Race: hurtig dobbeltklik på logo → guard_modal_open blokerer 2. emit

---

## 9. Out of scope (YAGNI)

Per bruger-instruktion "hold scope minimal":

- ❌ "Husk valg denne session"-checkbox (modal vises hver gang)
- ❌ Visuel indikator (prik/asterisk) på nav-elementer
- ❌ Auto-restore-prompt ved app-load (separat eksisterende localStorage-flow)
- ❌ Dirty-flag tracking (kun "data findes?", ikke "data ændret?")

---

## 10. Risici og mitigationer

| Risiko | Sandsynlighed | Impact | Mitigation |
|--------|---------------|--------|------------|
| Base64-blob overhead på store datasæt | Lav (typisk <10 MB) | Browser memory-spike | Dokumentér 50 MB soft-limit; fallback ikke implementeret i MVP |
| `nav_guard_has_data` flag desynkroniseret | Lav | Modal vises "for meget" | Acceptabel fail-safe — beskytter data |
| Eksisterende JS i `wizard-nav.js` konflikter | Medium | Logo-klik fejler | Test grundigt; event.stopPropagation styrer |
| `beforeunload` blokerer udvikler-refresh | Høj (under dev) | Friktion | Kun i prod; `inst/golem-config.yml` gate hvis nødvendigt |
| `easyClose=FALSE` frustrerer brugere | Lav | UX-irritation | Knap "Annullér" tydeligt placeret |

---

## 11. Filer (oversigt)

**Nye:**
- `R/utils_server_navigation_guard.R` (~150 linjer)
- `tests/testthat/test-navigation-guard.R` (~120 linjer)

**Ændrede:**
- `R/state_management.R` (+30 linjer: emit + substate)
- `R/utils_server_events_navigation.R` (+5 linjer: setup-kald)
- `R/utils_server_wizard_gates.R` (~5 linjer refactor)
- `R/app_server.R` (+2 linjer registrering)
- `R/app_ui.R` (+1 linje data-attribut)
- `inst/app/www/wizard-nav.js` (+50 linjer)

**Estimeret total:** ~360 nye linjer kode + tests

---

## 12. Implementeringsrækkefølge

1. **State + emit-API** (`state_management.R`) — fundament
2. **Guard-listener** (`utils_server_navigation_guard.R`) — kernelogik
3. **Modal + action observers** — UI-flow
4. **Refactor back-knap** (`utils_server_wizard_gates.R`) — første trigger
5. **JS-intercept logo + tab** (`wizard-nav.js`) — øvrige triggers
6. **Download-blob mekanisme** — server + JS
7. **`beforeunload`-hook** — sidste trigger
8. **Unit tests** — hver layer
9. **Integration + shinytest2** — end-to-end

Hver fase: tests grønne før næste.

---

## 13. Referencer

- ADR-003: Unified event architecture (`docs/adr/ADR-003-unified-event-architecture.md`)
- ADR-004: Hierarchical app state (`docs/adr/ADR-004-hierarchical-app-state.md`)
- ADR-006: Hybrid anti-race strategy (`docs/adr/ADR-006-hybrid-anti-race-strategy.md`)
- ADR-005: Session persistence (`docs/adr/ADR-005-session-persistence-localstorage.md`)
- Eksisterende reset: `R/utils_server_server_management.R:560`
- Eksisterende download: `R/utils_server_wizard_gates.R:111-187`
- Eksisterende modal-pattern: `R/utils_server_server_management.R:677`
