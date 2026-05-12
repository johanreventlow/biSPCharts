# Navigation Guard Modal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show modal-dialog warning user before destructive navigation (logo→start, Upload-tab→upload, back-knap→upload, browser tab-close) from trin 2/3 when `app_state$data$current_data` is non-NULL. Optional Excel-blob download (data + indstillinger) before session reset.

**Architecture:** Centralized event-bus-guard (Approach A from spec). New `emit$navigation_requested(target)` event + `setup_navigation_guard_listener()` checks state and either navigates directly (no data) or opens `modalDialog`. Confirm-action uses in-memory Excel-blob via `session$sendCustomMessage` to avoid race between `downloadHandler` (HTTP GET) and `reset_to_empty_session`.

**Tech Stack:** Shiny + Golem + bslib navbar, `safe_operation()` for error handling, base64enc for blob encoding, vanilla JS in `inst/app/www/wizard-nav.js`.

**Spec:** `docs/superpowers/specs/2026-05-12-navigation-guard-modal-design.md`

---

## File Structure

**New files:**
- `R/utils_server_navigation_guard.R` — guard-listener, modal, action-observers, blob-builder
- `tests/testthat/test-navigation-guard.R` — unit + integration tests

**Modified files:**
- `R/state_management.R` — add event + substate + emit
- `R/utils_server_events_navigation.R` — register setup-call
- `R/utils_server_wizard_gates.R` — refactor `input$back_to_upload`
- `R/app_server.R` — register has_data observer (or via events_navigation.R)
- `inst/app/www/wizard-nav.js` — intercepts + blob-handler + beforeunload

**Dependencies:** `base64enc` package — verify in `DESCRIPTION` Imports (or add).

---

## Task 1: Add `navigation_requested` event + `navigation` substate

**Files:**
- Modify: `R/state_management.R:65-102` (events init)
- Modify: `R/state_management.R` after `app_state$session <- ...` block

- [ ] **Step 1: Add `navigation_requested = 0L` to events reactiveValues**

In `R/state_management.R`, find the `app_state$events <- shiny::reactiveValues(...)` block (line ~65). Locate the navigation section near `navigation_changed = 0L,` and add:

```r
    navigation_changed = 0L,
    navigation_requested = 0L,  # Guard-trigger from logo/upload-tab/back-knap
```

- [ ] **Step 2: Add `app_state$navigation` substate after `app_state$session` block**

In `R/state_management.R`, after the `app_state$session <- shiny::reactiveValues(...)` block closes, add:

```r
  # Navigation guard substate
  app_state$navigation <- shiny::reactiveValues(
    guard_pending_target = NULL,    # Target tab name ("start" | "upload")
    guard_modal_open = FALSE,       # TRUE while modal vises (race-guard)
    guard_has_data_flag = FALSE     # Cached for JS-side gating
  )
```

- [ ] **Step 3: Commit**

```bash
git add R/state_management.R
git commit -m "feat(state): add navigation_requested event + navigation substate

Foundation for navigation guard modal. Adds event-counter and
substate fields (pending_target, modal_open, has_data_flag) used
by setup_navigation_guard_listener.

Refs: docs/superpowers/specs/2026-05-12-navigation-guard-modal-design.md"
```

---

## Task 2: Add `emit$navigation_requested(target)` to emit-API

**Files:**
- Modify: `R/state_management.R:456-460` (after `navigation_changed` emit)
- Test: `tests/testthat/test-navigation-guard.R` (new file)

- [ ] **Step 1: Write failing test for emit function**

Create `tests/testthat/test-navigation-guard.R`:

```r
test_that("emit$navigation_requested increments event counter and stores target", {
  app_state <- create_app_state()
  emit <- create_emit_api(app_state)

  shiny::isolate({
    counter_before <- app_state$events$navigation_requested
    emit$navigation_requested("upload")

    expect_equal(
      app_state$events$navigation_requested,
      counter_before + 1L
    )
    expect_equal(app_state$navigation$guard_pending_target, "upload")
  })
})

test_that("emit$navigation_requested validates target argument", {
  app_state <- create_app_state()
  emit <- create_emit_api(app_state)

  shiny::isolate({
    # Invalid target -> coerce to "upload" + log warning
    emit$navigation_requested("malicious; rm -rf /")
    expect_true(
      app_state$navigation$guard_pending_target %in% c("upload", "start")
    )
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `R -e "library(biSPCharts); testthat::test_file('tests/testthat/test-navigation-guard.R')"`
Expected: FAIL — `emit$navigation_requested` does not exist.

- [ ] **Step 3: Add emit-function**

In `R/state_management.R`, after the `navigation_changed = function() {...}` block (line ~460), add:

```r
    # Navigation guard trigger (logo/upload-tab/back-knap intercept)
    navigation_requested = function(target) {
      shiny::isolate({
        # INPUT VALIDATION: target must be one of allowed tab-values
        allowed_targets <- c("start", "upload")
        if (!is.character(target) || length(target) != 1 ||
            !target %in% allowed_targets) {
          if (exists("log_warn", mode = "function")) {
            log_warn(
              paste("Invalid target in emit$navigation_requested:", target),
              .context = "EMIT_API"
            )
          }
          target <- "upload"  # Safe fallback
        }

        app_state$navigation$guard_pending_target <- target
        app_state$events$navigation_requested <-
          app_state$events$navigation_requested + 1L
      })
    },
```

- [ ] **Step 4: Run test to verify it passes**

Run: `R -e "library(biSPCharts); testthat::test_file('tests/testthat/test-navigation-guard.R')"`
Expected: PASS — both tests green.

- [ ] **Step 5: Commit**

```bash
git add R/state_management.R tests/testthat/test-navigation-guard.R
git commit -m "feat(state): add emit\$navigation_requested(target) to emit API

Validates target against allowed tab-values ('start', 'upload') with
fallback to 'upload'. Stores target in
app_state\$navigation\$guard_pending_target and increments event-counter
for downstream guard-listener.

Refs: docs/superpowers/specs/2026-05-12-navigation-guard-modal-design.md"
```

---

## Task 3: Guard-listener skeleton + empty-session path

**Files:**
- Create: `R/utils_server_navigation_guard.R`
- Test: `tests/testthat/test-navigation-guard.R`

- [ ] **Step 1: Write failing test for empty-session direct-nav**

Append to `tests/testthat/test-navigation-guard.R`:

```r
test_that("guard-listener triggers direct nav when current_data is NULL", {
  app_state <- create_app_state()
  emit <- create_emit_api(app_state)

  # Mock session with sendCustomMessage capture
  session <- shiny::MockShinySession$new()
  nav_select_calls <- list()

  # Override bslib::nav_select via local mock (simplest: use with_mock)
  testthat::local_mocked_bindings(
    nav_select = function(id, selected, session) {
      nav_select_calls[[length(nav_select_calls) + 1]] <<- list(
        id = id, selected = selected
      )
    },
    .package = "bslib"
  )

  setup_navigation_guard_listener(app_state, emit, session)

  shiny::isolate({
    expect_null(app_state$data$current_data)
    emit$navigation_requested("upload")
  })

  # Flush reactive context to trigger observer
  session$flushReact()

  expect_length(nav_select_calls, 1)
  expect_equal(nav_select_calls[[1]]$selected, "upload")
  expect_null(app_state$navigation$guard_pending_target)
  expect_false(isTRUE(app_state$navigation$guard_modal_open))
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `R -e "library(biSPCharts); testthat::test_file('tests/testthat/test-navigation-guard.R')"`
Expected: FAIL — `setup_navigation_guard_listener` not defined.

- [ ] **Step 3: Create `R/utils_server_navigation_guard.R` with skeleton**

```r
# utils_server_navigation_guard.R
#
# Navigation guard for trin 2/3 -> trin 1/forside.
# Vises modal hvis app_state$data$current_data findes; ellers direct nav.
#
# Spec: docs/superpowers/specs/2026-05-12-navigation-guard-modal-design.md

#' Setup navigation guard listener
#'
#' Lytter på `emit$navigation_requested()`. Hvis data findes, vises modal
#' med valgmulighed for download + reset. Hvis ikke, navigeres direkte.
#'
#' @param app_state Hierarchical reactiveValues (environment)
#' @param emit Emit-API fra create_emit_api()
#' @param session Shiny session
#' @return Invisibly NULL (side-effect: registers observers)
#' @keywords internal
#' @noRd
setup_navigation_guard_listener <- function(app_state, emit, session) {

  # Primary listener — fires when emit$navigation_requested() called
  shiny::observeEvent(
    app_state$events$navigation_requested,
    ignoreInit = TRUE,
    priority = OBSERVER_PRIORITIES$STATE_MANAGEMENT,
    {
      target <- shiny::isolate(app_state$navigation$guard_pending_target)

      # Race-guard: ignore if modal already open
      if (isTRUE(shiny::isolate(app_state$navigation$guard_modal_open))) {
        return(invisible(NULL))
      }

      data_present <- !is.null(shiny::isolate(app_state$data$current_data)) &&
        nrow(shiny::isolate(app_state$data$current_data)) > 0

      if (!data_present) {
        # Empty session — direct navigation
        bslib::nav_select(
          id = "main_navbar",
          selected = target,
          session = session
        )
        app_state$navigation$guard_pending_target <- NULL
        return(invisible(NULL))
      }

      # Data present — show modal (implemented in Task 4)
      app_state$navigation$guard_modal_open <- TRUE
      shiny::showModal(navigation_guard_modal(), session = session)
    }
  )

  invisible(NULL)
}
```

Also add stub for `navigation_guard_modal` (returns minimal modalDialog to satisfy reference; full implementation Task 4):

```r
#' Build navigation guard modal-dialog (stub — fleshed out in Task 4)
#' @keywords internal
#' @noRd
navigation_guard_modal <- function() {
  shiny::modalDialog(
    title = "Forlad arbejde og start forfra?",
    "Stub", footer = NULL, easyClose = FALSE
  )
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `R -e "library(biSPCharts); testthat::test_file('tests/testthat/test-navigation-guard.R')"`
Expected: PASS — empty-session path navigates directly.

- [ ] **Step 5: Commit**

```bash
git add R/utils_server_navigation_guard.R tests/testthat/test-navigation-guard.R
git commit -m "feat(navigation): add guard-listener with empty-session direct-nav path

Skeleton of setup_navigation_guard_listener. When data is NULL/empty,
bypasses modal and routes nav_select directly to target tab. Modal-
path stubbed; full implementation in subsequent tasks.

Refs: docs/superpowers/specs/2026-05-12-navigation-guard-modal-design.md"
```

---

## Task 4: Modal UI + data-present path

**Files:**
- Modify: `R/utils_server_navigation_guard.R` (flesh out modal)
- Test: `tests/testthat/test-navigation-guard.R`

- [ ] **Step 1: Write failing test for data-present modal-show**

Append to `tests/testthat/test-navigation-guard.R`:

```r
test_that("guard-listener shows modal when current_data has rows", {
  app_state <- create_app_state()
  emit <- create_emit_api(app_state)
  session <- shiny::MockShinySession$new()

  # Inject test data
  shiny::isolate({
    app_state$data$current_data <- data.frame(x = 1:5, y = 6:10)
  })

  show_modal_calls <- list()
  testthat::local_mocked_bindings(
    showModal = function(ui, session = NULL) {
      show_modal_calls[[length(show_modal_calls) + 1]] <<- ui
    },
    .package = "shiny"
  )

  setup_navigation_guard_listener(app_state, emit, session)

  shiny::isolate({
    emit$navigation_requested("start")
  })
  session$flushReact()

  expect_length(show_modal_calls, 1)
  expect_true(isTRUE(app_state$navigation$guard_modal_open))
  expect_equal(app_state$navigation$guard_pending_target, "start")
})

test_that("navigation_guard_modal contains both knapper + checkbox", {
  modal <- navigation_guard_modal()
  html <- as.character(modal)
  expect_match(html, "nav_guard_confirm")
  expect_match(html, "nav_guard_cancel")
  expect_match(html, "nav_guard_download")
  expect_match(html, "Annull")  # "Annullér"
  expect_match(html, "Nulstil")
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `R -e "library(biSPCharts); testthat::test_file('tests/testthat/test-navigation-guard.R')"`
Expected: FAIL — modal is stub, missing IDs.

- [ ] **Step 3: Replace stub with full modal-implementation**

In `R/utils_server_navigation_guard.R`, replace the `navigation_guard_modal` stub:

```r
#' Build navigation guard modal-dialog
#'
#' Vises når brugeren forsøger destruktiv navigation fra trin 2/3.
#' 2 knapper (Annullér / Nulstil) + checkbox til download-opt-in.
#'
#' @return shiny::modalDialog
#' @keywords internal
#' @noRd
navigation_guard_modal <- function() {
  shiny::modalDialog(
    title = "Forlad arbejde og start forfra?",
    shiny::tagList(
      shiny::tags$p("Du har data + indstillinger på arbejdsbordet."),
      shiny::tags$p(
        "Vil du starte forfra uden gemte ændringer?",
        " Du kan ikke fortryde denne handling."
      ),
      shiny::checkboxInput(
        inputId = "nav_guard_download",
        label = "Download kopi af data + indstillinger først",
        value = FALSE
      )
    ),
    footer = shiny::tagList(
      shiny::actionButton(
        inputId = "nav_guard_cancel",
        label = "Annullér"
      ),
      shiny::actionButton(
        inputId = "nav_guard_confirm",
        label = "Nulstil",
        class = "btn btn-danger"
      )
    ),
    size = "m",
    easyClose = FALSE,
    fade = TRUE
  )
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `R -e "library(biSPCharts); testthat::test_file('tests/testthat/test-navigation-guard.R')"`
Expected: PASS — modal shown when data present, modal contains all required IDs.

- [ ] **Step 5: Commit**

```bash
git add R/utils_server_navigation_guard.R tests/testthat/test-navigation-guard.R
git commit -m "feat(navigation): implement modal UI for guard-dialog

Modal includes warning text, opt-in download checkbox (default FALSE),
Annullér + Nulstil knapper. easyClose=FALSE forces explicit choice.

Refs: docs/superpowers/specs/2026-05-12-navigation-guard-modal-design.md"
```

---

## Task 5: Cancel-action observer

**Files:**
- Modify: `R/utils_server_navigation_guard.R` (add observer inside setup function)
- Test: `tests/testthat/test-navigation-guard.R`

- [ ] **Step 1: Write failing test for cancel**

Append to `tests/testthat/test-navigation-guard.R`:

```r
test_that("nav_guard_cancel removes modal and clears flags", {
  app_state <- create_app_state()
  emit <- create_emit_api(app_state)
  session <- shiny::MockShinySession$new()

  shiny::isolate({
    app_state$data$current_data <- data.frame(x = 1:3)
    app_state$navigation$guard_pending_target <- "upload"
    app_state$navigation$guard_modal_open <- TRUE
  })

  remove_modal_called <- FALSE
  testthat::local_mocked_bindings(
    removeModal = function(session = NULL) {
      remove_modal_called <<- TRUE
    },
    .package = "shiny"
  )

  setup_navigation_guard_listener(app_state, emit, session)

  # Simulate user clicking cancel
  session$setInputs(nav_guard_cancel = 1)
  session$flushReact()

  expect_true(remove_modal_called)
  expect_null(app_state$navigation$guard_pending_target)
  expect_false(app_state$navigation$guard_modal_open)
  # State unchanged
  expect_equal(nrow(app_state$data$current_data), 3)
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `R -e "library(biSPCharts); testthat::test_file('tests/testthat/test-navigation-guard.R')"`
Expected: FAIL — `nav_guard_cancel` observer not registered.

- [ ] **Step 3: Add cancel-observer to `setup_navigation_guard_listener`**

In `R/utils_server_navigation_guard.R`, inside `setup_navigation_guard_listener` (after the primary observeEvent block), add:

```r
  # Cancel action — close modal, restore state
  shiny::observeEvent(
    session$input$nav_guard_cancel,
    ignoreInit = TRUE,
    priority = OBSERVER_PRIORITIES$STATE_MANAGEMENT,
    {
      shiny::removeModal(session = session)
      app_state$navigation$guard_pending_target <- NULL
      app_state$navigation$guard_modal_open <- FALSE
    }
  )
```

**Note on `session$input$nav_guard_cancel`:** Standard Shiny pattern is to receive `input` as a parameter. Since `setup_navigation_guard_listener` is called from `app_server.R` where `input` is in scope, refactor the function signature:

```r
setup_navigation_guard_listener <- function(app_state, emit, session, input) {
  # ... existing primary observer ...

  shiny::observeEvent(
    input$nav_guard_cancel,
    ignoreInit = TRUE,
    priority = OBSERVER_PRIORITIES$STATE_MANAGEMENT,
    {
      shiny::removeModal(session = session)
      app_state$navigation$guard_pending_target <- NULL
      app_state$navigation$guard_modal_open <- FALSE
    }
  )

  invisible(NULL)
}
```

Update earlier tests calling `setup_navigation_guard_listener(app_state, emit, session)` to pass `session$input` as 4th arg:

```r
setup_navigation_guard_listener(app_state, emit, session, session$input)
```

- [ ] **Step 4: Run all tests to verify pass**

Run: `R -e "library(biSPCharts); testthat::test_file('tests/testthat/test-navigation-guard.R')"`
Expected: PASS — all tests green including new cancel-test.

- [ ] **Step 5: Commit**

```bash
git add R/utils_server_navigation_guard.R tests/testthat/test-navigation-guard.R
git commit -m "feat(navigation): add nav_guard_cancel action observer

Cancel action removes modal, clears guard_pending_target and
guard_modal_open flag. Data state untouched. Function signature
updated to accept input parameter for Shiny observer binding.

Refs: docs/superpowers/specs/2026-05-12-navigation-guard-modal-design.md"
```

---

## Task 6: Confirm-action observer (no download)

**Files:**
- Modify: `R/utils_server_navigation_guard.R`
- Test: `tests/testthat/test-navigation-guard.R`

- [ ] **Step 1: Write failing test**

Append to `tests/testthat/test-navigation-guard.R`:

```r
test_that("nav_guard_confirm without download resets session and navigates", {
  app_state <- create_app_state()
  emit <- create_emit_api(app_state)
  session <- shiny::MockShinySession$new()

  shiny::isolate({
    app_state$data$current_data <- data.frame(x = 1:3)
    app_state$columns$auto_detect$completed <- TRUE
    app_state$navigation$guard_pending_target <- "upload"
    app_state$navigation$guard_modal_open <- TRUE
  })

  send_custom_calls <- list()
  session$sendCustomMessage <- function(type, message) {
    send_custom_calls[[length(send_custom_calls) + 1]] <<- list(
      type = type, message = message
    )
  }

  nav_select_calls <- list()
  testthat::local_mocked_bindings(
    nav_select = function(id, selected, session) {
      nav_select_calls[[length(nav_select_calls) + 1]] <<- selected
    },
    .package = "bslib"
  )

  reset_called <- FALSE
  testthat::local_mocked_bindings(
    reset_to_empty_session = function(session, app_state, emit, ui_service = NULL) {
      reset_called <<- TRUE
      app_state$data$current_data <- NULL
      app_state$columns$auto_detect$completed <- FALSE
    }
  )

  setup_navigation_guard_listener(app_state, emit, session, session$input)

  session$setInputs(
    nav_guard_download = FALSE,
    nav_guard_confirm = 1
  )
  session$flushReact()

  # No download_blob message sent
  download_calls <- Filter(
    function(x) x$type == "download_blob",
    send_custom_calls
  )
  expect_length(download_calls, 0)

  expect_true(reset_called)
  expect_length(nav_select_calls, 1)
  expect_equal(nav_select_calls[[1]], "upload")
  expect_null(app_state$navigation$guard_pending_target)
  expect_false(app_state$navigation$guard_modal_open)
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `R -e "library(biSPCharts); testthat::test_file('tests/testthat/test-navigation-guard.R')"`
Expected: FAIL — confirm-observer not registered.

- [ ] **Step 3: Add confirm-observer + handler function**

In `R/utils_server_navigation_guard.R`, add the handler-function (top of file or after `navigation_guard_modal`):

```r
#' Handle nav_guard_confirm action
#'
#' Hvis input$nav_guard_download er TRUE: bygger Excel-blob fra state,
#' sender til browser via sendCustomMessage("download_blob"), så reset.
#' Hvis FALSE: reset direkte. Begge paths kalder reset_to_empty_session
#' + nav_select til pending_target.
#'
#' @keywords internal
#' @noRd
handle_nav_guard_confirm <- function(app_state, emit, session, input) {
  target <- shiny::isolate(app_state$navigation$guard_pending_target)
  download_first <- isTRUE(input$nav_guard_download)

  safe_operation(
    "Navigation guard confirm",
    code = {
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

      reset_to_empty_session(session, app_state, emit)

      # Signal JS to skip beforeunload for in-app nav
      session$sendCustomMessage(
        "set_in_app_navigating",
        list(value = TRUE)
      )

      bslib::nav_select(
        id = "main_navbar",
        selected = target,
        session = session
      )
      shiny::removeModal(session = session)

      app_state$navigation$guard_pending_target <- NULL
      app_state$navigation$guard_modal_open <- FALSE

      # Clear in_app_navigating flag after small delay (JS side timeout)
      session$sendCustomMessage(
        "schedule_clear_in_app_navigating",
        list(delay_ms = 500)
      )
    },
    fallback = {
      shiny::showNotification(
        "Kunne ikke nulstille — prøv igen",
        type = "error", duration = 5
      )
      shiny::removeModal(session = session)
      app_state$navigation$guard_pending_target <- NULL
      app_state$navigation$guard_modal_open <- FALSE
    }
  )
}
```

Add observer in `setup_navigation_guard_listener`:

```r
  # Confirm action — download (opt-in) + reset + navigate
  shiny::observeEvent(
    input$nav_guard_confirm,
    ignoreInit = TRUE,
    priority = OBSERVER_PRIORITIES$STATE_MANAGEMENT,
    {
      handle_nav_guard_confirm(app_state, emit, session, input)
    }
  )
```

For this task, `build_spc_excel_blob` and `generate_spc_filename` are only referenced in the download-branch — Task 7 will implement them. To keep Task 6 green when `download_first = FALSE`, the branch is guarded by `if (download_first)`, so undefined references are not executed.

- [ ] **Step 4: Run test to verify it passes**

Run: `R -e "library(biSPCharts); testthat::test_file('tests/testthat/test-navigation-guard.R')"`
Expected: PASS — confirm without download resets and navigates.

- [ ] **Step 5: Commit**

```bash
git add R/utils_server_navigation_guard.R tests/testthat/test-navigation-guard.R
git commit -m "feat(navigation): add nav_guard_confirm observer (no-download path)

handle_nav_guard_confirm orchestrates reset_to_empty_session +
bslib::nav_select to pending_target. Download-branch stubbed via
if-guard; full blob-build in Task 7. Wraps in safe_operation with
fallback notification on error.

Refs: docs/superpowers/specs/2026-05-12-navigation-guard-modal-design.md"
```

---

## Task 7: `build_spc_excel_blob` + filename helper

**Files:**
- Modify: `R/utils_server_navigation_guard.R`
- Test: `tests/testthat/test-navigation-guard.R`
- Verify: `R/fct_spc_file_save_load.R` (existing `build_spc_excel` signature)

- [ ] **Step 1: Inspect existing `build_spc_excel` signature**

Run: `grep -n "build_spc_excel\b" R/fct_spc_file_save_load.R | head -5`

Then read the function definition. Note its signature — the blob-builder must call it correctly. Typical signature:

```r
build_spc_excel(data, settings, output_path)
```

Adjust the implementation below if the actual signature differs (e.g., uses `app_state` directly, or has different arg names). The blob-builder must produce a tempfile, then read it back as raw bytes.

Also locate the existing filename-generator: typically `spc_save_filename` (used in `R/utils_server_wizard_gates.R:189-196`). Reuse it if possible.

- [ ] **Step 2: Write failing test for blob-builder**

Append to `tests/testthat/test-navigation-guard.R`:

```r
test_that("build_spc_excel_blob returns raw bytes with XLSX magic header", {
  app_state <- create_app_state()
  shiny::isolate({
    app_state$data$current_data <- data.frame(
      dato = as.Date("2026-01-01") + 0:9,
      taeller = sample(10, 10)
    )
    app_state$columns$mappings$x_column <- "dato"
    app_state$columns$mappings$y_column <- "taeller"
  })

  blob <- build_spc_excel_blob(app_state)

  expect_type(blob, "raw")
  expect_gt(length(blob), 0)
  # XLSX = ZIP container, magic bytes 0x50 0x4B 0x03 0x04
  expect_equal(as.integer(blob[1:4]), c(0x50, 0x4B, 0x03, 0x04))
})

test_that("generate_spc_filename returns .xlsx filename with date", {
  app_state <- create_app_state()
  name <- generate_spc_filename(app_state)
  expect_match(name, "\\.xlsx$")
  expect_match(name, "\\d{4}-\\d{2}-\\d{2}")
})
```

- [ ] **Step 3: Run test to verify it fails**

Run: `R -e "library(biSPCharts); testthat::test_file('tests/testthat/test-navigation-guard.R')"`
Expected: FAIL — `build_spc_excel_blob` not defined.

- [ ] **Step 4: Implement blob-builder + filename helper**

Append to `R/utils_server_navigation_guard.R`:

```r
#' Build in-memory Excel-blob fra current app_state
#'
#' Genbruger eksisterende build_spc_excel() (3-ark: Data + Indstillinger +
#' SPC-analyse) via tempfile + readBin. Tempfile slettes via on.exit.
#'
#' @param app_state Hierarchical reactiveValues
#' @return Raw bytes — XLSX file content
#' @keywords internal
#' @noRd
build_spc_excel_blob <- function(app_state) {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  # Call existing builder (see R/fct_spc_file_save_load.R)
  # Pass app_state directly if signature requires it; otherwise pass
  # data + settings extracted from state. Adjust to match actual sig.
  build_spc_excel(
    app_state = app_state,
    output_path = tmp
  )

  readBin(tmp, what = "raw", n = file.info(tmp)$size)
}

#' Generate user-facing filename for nav-guard download
#'
#' Format: "spc-data_YYYY-MM-DD_HHMMSS.xlsx"
#'
#' @param app_state Hierarchical reactiveValues (currently unused, reserved
#'   for future file_info.name)
#' @return Character — filename
#' @keywords internal
#' @noRd
generate_spc_filename <- function(app_state) {
  ts <- format(Sys.time(), "%Y-%m-%d_%H%M%S")
  paste0("spc-data_", ts, ".xlsx")
}
```

**If actual `build_spc_excel` signature differs from `(app_state, output_path)`:** Adjust the call site. Read `R/fct_spc_file_save_load.R` to find the canonical signature, then call accordingly. Common patterns:

```r
# Variant: separate data + settings args
build_spc_excel(
  data = shiny::isolate(app_state$data$current_data),
  settings = collect_current_settings(app_state),
  output_path = tmp
)
```

- [ ] **Step 5: Run test to verify it passes**

Run: `R -e "library(biSPCharts); testthat::test_file('tests/testthat/test-navigation-guard.R')"`
Expected: PASS — blob is XLSX raw bytes, filename matches pattern.

- [ ] **Step 6: Commit**

```bash
git add R/utils_server_navigation_guard.R tests/testthat/test-navigation-guard.R
git commit -m "feat(navigation): add build_spc_excel_blob + generate_spc_filename

In-memory Excel-blob via tempfile + readBin. Reuses existing
build_spc_excel() (3-ark Data + Indstillinger + SPC-analyse) to avoid
duplicating file-build logic. Filename includes timestamp for
uniqueness.

Refs: docs/superpowers/specs/2026-05-12-navigation-guard-modal-design.md"
```

---

## Task 8: Confirm-with-download integration test

**Files:**
- Test only: `tests/testthat/test-navigation-guard.R`

- [ ] **Step 1: Write failing test for download-branch**

Append to `tests/testthat/test-navigation-guard.R`:

```r
test_that("nav_guard_confirm with download sends blob before reset", {
  app_state <- create_app_state()
  emit <- create_emit_api(app_state)
  session <- shiny::MockShinySession$new()

  shiny::isolate({
    app_state$data$current_data <- data.frame(x = 1:3, y = 4:6)
    app_state$navigation$guard_pending_target <- "start"
    app_state$navigation$guard_modal_open <- TRUE
  })

  send_calls <- list()
  session$sendCustomMessage <- function(type, message) {
    # Capture order
    send_calls[[length(send_calls) + 1]] <<- list(
      type = type,
      data_present = !is.null(shiny::isolate(app_state$data$current_data))
    )
  }

  testthat::local_mocked_bindings(
    nav_select = function(id, selected, session) {
      invisible(NULL)
    },
    .package = "bslib"
  )
  testthat::local_mocked_bindings(
    reset_to_empty_session = function(session, app_state, emit, ...) {
      app_state$data$current_data <- NULL
    }
  )

  setup_navigation_guard_listener(app_state, emit, session, session$input)

  session$setInputs(
    nav_guard_download = TRUE,
    nav_guard_confirm = 1
  )
  session$flushReact()

  download_call <- Filter(
    function(x) x$type == "download_blob",
    send_calls
  )
  expect_length(download_call, 1)
  # Critical: data must still be present when sendCustomMessage fires
  expect_true(download_call[[1]]$data_present)
  # After full sequence, data is reset
  expect_null(app_state$data$current_data)
})
```

- [ ] **Step 2: Run test**

Run: `R -e "library(biSPCharts); testthat::test_file('tests/testthat/test-navigation-guard.R')"`
Expected: PASS — implementation from Task 6 + Task 7 already supports download-branch. If FAIL, debug the order of operations in `handle_nav_guard_confirm`.

- [ ] **Step 3: Commit**

```bash
git add tests/testthat/test-navigation-guard.R
git commit -m "test(navigation): verify download-branch sends blob before state reset

Critical race-condition test: build_spc_excel_blob must read from
current_data BEFORE reset_to_empty_session zeroes it. Test asserts
ordering via sendCustomMessage capture.

Refs: docs/superpowers/specs/2026-05-12-navigation-guard-modal-design.md"
```

---

## Task 9: Race-guard test (modal-open blocks new emits)

**Files:**
- Test only: `tests/testthat/test-navigation-guard.R`

- [ ] **Step 1: Write race-guard test**

Append to `tests/testthat/test-navigation-guard.R`:

```r
test_that("new navigation_requested ignored while guard_modal_open is TRUE", {
  app_state <- create_app_state()
  emit <- create_emit_api(app_state)
  session <- shiny::MockShinySession$new()

  shiny::isolate({
    app_state$data$current_data <- data.frame(x = 1:3)
    app_state$navigation$guard_pending_target <- "upload"
    app_state$navigation$guard_modal_open <- TRUE
  })

  show_modal_count <- 0
  testthat::local_mocked_bindings(
    showModal = function(ui, session = NULL) {
      show_modal_count <<- show_modal_count + 1
    },
    .package = "shiny"
  )

  setup_navigation_guard_listener(app_state, emit, session, session$input)

  shiny::isolate({
    emit$navigation_requested("start")  # Should be ignored
  })
  session$flushReact()

  expect_equal(show_modal_count, 0)
  # Original pending_target preserved (not overwritten by new emit)
  expect_equal(app_state$navigation$guard_pending_target, "upload")
})
```

Wait — `emit$navigation_requested` *does* overwrite `guard_pending_target` (per Task 2 implementation). For race-guard to preserve original target, the emit-function should also check `guard_modal_open`:

- [ ] **Step 2: Update emit-function to no-op when modal open**

In `R/state_management.R`, update `emit$navigation_requested`:

```r
    navigation_requested = function(target) {
      shiny::isolate({
        # Race-guard: ignore if modal already open (preserve pending_target)
        if (isTRUE(app_state$navigation$guard_modal_open)) {
          return(invisible(NULL))
        }

        # ... existing validation + assignment ...
        allowed_targets <- c("start", "upload")
        if (!is.character(target) || length(target) != 1 ||
            !target %in% allowed_targets) {
          # ... fallback as before ...
          target <- "upload"
        }

        app_state$navigation$guard_pending_target <- target
        app_state$events$navigation_requested <-
          app_state$events$navigation_requested + 1L
      })
    },
```

- [ ] **Step 3: Run all tests**

Run: `R -e "library(biSPCharts); testthat::test_file('tests/testthat/test-navigation-guard.R')"`
Expected: PASS — race-guard fires before target-overwrite.

- [ ] **Step 4: Commit**

```bash
git add R/state_management.R tests/testthat/test-navigation-guard.R
git commit -m "fix(navigation): no-op emit when guard modal already open

Race-guard moved from listener into emit-function for stronger
guarantee: rapid double-click on logo cannot overwrite pending_target
mid-flow. Listener still has its own guard for defense-in-depth.

Refs: docs/superpowers/specs/2026-05-12-navigation-guard-modal-design.md"
```

---

## Task 10: Refactor `input$back_to_upload` to use emit

**Files:**
- Modify: `R/utils_server_wizard_gates.R:198-204`

- [ ] **Step 1: Locate current `input$back_to_upload` observer**

Run: `grep -n "back_to_upload" R/utils_server_wizard_gates.R`

The observer at lines 199-204 currently calls `bslib::nav_select("main_navbar", selected = "upload", ...)` directly.

- [ ] **Step 2: Replace direct nav_select with emit**

Replace lines 199-204 in `R/utils_server_wizard_gates.R`:

```r
  # Tilbage-knap: Trin 2 -> Trin 1 (via navigation guard)
  shiny::observeEvent(input$back_to_upload,
    priority = OBSERVER_PRIORITIES$STATUS_UPDATES,
    {
      emit$navigation_requested("upload")
    }
  )
```

**Verify `emit` is in scope** at this location. Read the enclosing function signature in `utils_server_wizard_gates.R`. If `emit` is not passed in, add it to the function signature and update callers.

- [ ] **Step 3: Manual smoke test**

Run app:

```r
R -e "library(biSPCharts); biSPCharts::run_app()"
```

Manual steps:
1. Upload CSV (or paste data) → land on trin 2
2. Click "Tilbage" knap
3. With data present: expect modal
4. Click Annullér → still on trin 2

If modal does not appear, check:
- `setup_navigation_guard_listener` registered (next task)
- `emit` is the correct emit-API instance

- [ ] **Step 4: Commit**

```bash
git add R/utils_server_wizard_gates.R
git commit -m "refactor(navigation): route back-knap through navigation guard

input\$back_to_upload now emits navigation_requested(\"upload\") instead
of calling bslib::nav_select directly. Modal will block destructive
nav when data is present.

Refs: docs/superpowers/specs/2026-05-12-navigation-guard-modal-design.md"
```

---

## Task 11: Register `setup_navigation_guard_listener` in app_server

**Files:**
- Modify: `R/app_server.R` (or `R/utils_server_events_navigation.R`)

- [ ] **Step 1: Locate session-startup registration site**

Run: `grep -n "setup_event_listeners\|setup_.*_listener" R/app_server.R R/utils_server_events_navigation.R | head -10`

Identify where other listeners are registered (typically in `app_server` after emit-API is created, or in a `setup_event_listeners()` helper called from `app_server`).

- [ ] **Step 2: Add registration call**

In the appropriate location (likely `R/app_server.R` after `emit <- create_emit_api(app_state)` or inside `setup_event_listeners()`):

```r
  # Navigation guard (logo/upload-tab/back-knap intercept)
  setup_navigation_guard_listener(
    app_state = app_state,
    emit = emit,
    session = session,
    input = input
  )
```

- [ ] **Step 3: Run pre-push smoke check**

Run: `R -e "library(biSPCharts); devtools::load_all(); message('OK')"`
Expected: No errors — function found and callable.

- [ ] **Step 4: Manual app-smoke**

```r
R -e "library(biSPCharts); biSPCharts::run_app()"
```

Manual:
1. Upload data → trin 2
2. Click "Tilbage" → expect modal
3. Annullér → modal closes
4. Click "Tilbage" again → modal again
5. Nulstil (checkbox FALSE) → returns to trin 1, data cleared

- [ ] **Step 5: Commit**

```bash
git add R/app_server.R
git commit -m "feat(navigation): register guard-listener in app_server session-init

Connects setup_navigation_guard_listener to live Shiny session. Back-
knap on trin 2 now shows guard modal when data is present.

Refs: docs/superpowers/specs/2026-05-12-navigation-guard-modal-design.md"
```

---

## Task 12: JS — has_data flag synchronization (server → client)

**Files:**
- Modify: `R/utils_server_navigation_guard.R` (add observer)
- Modify: `inst/app/www/wizard-nav.js` (add handler)

- [ ] **Step 1: Add server-side observer pushing flag**

Inside `setup_navigation_guard_listener` in `R/utils_server_navigation_guard.R`, after existing observers, add:

```r
  # Push has_data-flag to JS on every current_data change
  shiny::observe({
    has_data <- !is.null(app_state$data$current_data) &&
      nrow(app_state$data$current_data) > 0
    app_state$navigation$guard_has_data_flag <- has_data
    session$sendCustomMessage(
      type = "nav_guard_has_data_update",
      message = list(value = has_data)
    )
  })
```

- [ ] **Step 2: Add JS-handler for flag update**

In `inst/app/www/wizard-nav.js`, near top of `$(document).ready` (or wherever other `addCustomMessageHandler` calls live, e.g. line 161-170), add:

```javascript
  // Navigation guard: track has-data flag for client-side gating
  var navGuardHasData = false;

  if (typeof Shiny !== 'undefined' && Shiny.addCustomMessageHandler) {
    Shiny.addCustomMessageHandler('nav_guard_has_data_update', function(msg) {
      navGuardHasData = !!(msg && msg.value);
    });
  }
```

Expose helper for read-back (used in later tasks):

```javascript
  function navGuardShouldIntercept() {
    var currentStep = getCurrentStep();
    return navGuardHasData && (currentStep === '2' || currentStep === '3');
  }

  function getCurrentStep() {
    var activeTab = document.querySelector('#main_navbar .nav-link.active');
    var val = activeTab ? activeTab.getAttribute('data-value') : null;
    var stepMap = { 'upload': '1', 'analyser': '2', 'eksporter': '3' };
    return stepMap[val] || (val === 'start' ? '0' : '1');
  }
```

**Note:** `stepMap` may already exist (per exploration `wizard-nav.js:6`). Reuse if defined; otherwise add locally.

- [ ] **Step 3: Manual verify**

Reload app, open browser devtools console, run:
```javascript
navGuardHasData  // Expect false initially
```
Upload data, re-check:
```javascript
navGuardHasData  // Expect true
```

- [ ] **Step 4: Commit**

```bash
git add R/utils_server_navigation_guard.R inst/app/www/wizard-nav.js
git commit -m "feat(navigation): sync has_data flag from server to JS

Server pushes nav_guard_has_data_update on every current_data change.
JS caches in navGuardHasData for client-side gating of logo/tab
intercepts. Required for JS-only triggers (logo, tab-click,
beforeunload) to decide whether to intercept.

Refs: docs/superpowers/specs/2026-05-12-navigation-guard-modal-design.md"
```

---

## Task 13: JS — Logo intercept

**Files:**
- Modify: `inst/app/www/wizard-nav.js:172-178`

- [ ] **Step 1: Replace existing logo-click handler**

In `inst/app/www/wizard-nav.js`, locate the existing logo handler (line 172-178):

```javascript
  // Logo-klik: navigér til startside og skjul wizard-trin
  $(document).on('click', '#logo_home_link', function(e) {
    e.preventDefault();
    document.body.classList.remove('wizard-nav-active');
    var startLink = document.querySelector('.navbar .nav-link[data-value="start"]');
    if (startLink) startLink.click();
  });
```

Replace with guarded version:

```javascript
  // Logo-klik: navigér til startside (med guard hvis data på trin 2/3)
  $(document).on('click', '#logo_home_link', function(e) {
    e.preventDefault();

    if (navGuardShouldIntercept()) {
      // Route through Shiny server-side guard
      Shiny.setInputValue('nav_guard_trigger', {
        source: 'logo',
        target: 'start',
        timestamp: Date.now()  // forces re-trigger on rapid clicks
      }, { priority: 'event' });
      return;
    }

    // Default: direct nav to start
    document.body.classList.remove('wizard-nav-active');
    var startLink = document.querySelector('.navbar .nav-link[data-value="start"]');
    if (startLink) startLink.click();
  });
```

- [ ] **Step 2: Add server-side observer for `nav_guard_trigger`**

In `R/utils_server_navigation_guard.R`, inside `setup_navigation_guard_listener`, add:

```r
  # Server-side relay: JS-trigger -> emit
  shiny::observeEvent(
    input$nav_guard_trigger,
    ignoreInit = TRUE,
    priority = OBSERVER_PRIORITIES$STATE_MANAGEMENT,
    {
      trigger <- input$nav_guard_trigger
      if (!is.list(trigger) || is.null(trigger$target)) {
        return(invisible(NULL))
      }
      emit$navigation_requested(trigger$target)
    }
  )
```

- [ ] **Step 3: Manual test**

```r
R -e "library(biSPCharts); biSPCharts::run_app()"
```

Manual:
1. Upload data → trin 2
2. Click BFH-logo (top-left)
3. Expect modal (target = forside/start)
4. Annullér → still on trin 2
5. Click logo again, Nulstil → land on start-tab, data cleared

- [ ] **Step 4: Commit**

```bash
git add inst/app/www/wizard-nav.js R/utils_server_navigation_guard.R
git commit -m "feat(navigation): intercept logo-klik on trin 2/3 when data present

JS checks navGuardHasData + currentStep. If intercept: sends
nav_guard_trigger to server, which relays to emit\$navigation_requested.
Otherwise default behaviour (click start-tab) runs.

Refs: docs/superpowers/specs/2026-05-12-navigation-guard-modal-design.md"
```

---

## Task 14: JS — Upload-tab intercept

**Files:**
- Modify: `inst/app/www/wizard-nav.js`

- [ ] **Step 1: Add Upload-tab click interceptor**

In `inst/app/www/wizard-nav.js`, near other click-handlers (after logo-handler), add:

```javascript
  // Upload-tab-klik: intercept hvis trin 2/3 + data
  $(document).on('click', '#main_navbar .nav-link[data-value="upload"]',
    function(e) {
      if (!navGuardShouldIntercept()) {
        return;  // Let default bslib tab-switch run
      }
      e.preventDefault();
      e.stopPropagation();
      Shiny.setInputValue('nav_guard_trigger', {
        source: 'tab',
        target: 'upload',
        timestamp: Date.now()
      }, { priority: 'event' });
    }
  );
```

**Note:** Selector `#main_navbar .nav-link[data-value="upload"]` depends on bslib rendering data-value attribute on nav-links. If bslib does not auto-add it, the existing `wizard-nav.js` may need to add it (check exploration — `app_ui.R:84` comment says JS adds `data-step` attributes).

If `data-value` is not present on rendered links, use alternative selector: `.navbar .nav-link[href="#upload"]` or inspect via devtools to find correct attribute.

- [ ] **Step 2: Manual test**

```r
R -e "library(biSPCharts); biSPCharts::run_app()"
```

Manual:
1. Upload data → trin 2
2. Click "Upload" tab in navbar
3. Expect modal (target = upload)
4. Nulstil → land on trin 1, data cleared

- [ ] **Step 3: Commit**

```bash
git add inst/app/www/wizard-nav.js
git commit -m "feat(navigation): intercept Upload-tab klik on trin 2/3 when data present

JS handler captures clicks on navbar Upload nav-link, routes through
server-side guard when data present + currentStep is 2 or 3.

Refs: docs/superpowers/specs/2026-05-12-navigation-guard-modal-design.md"
```

---

## Task 15: JS — Download-blob handler

**Files:**
- Modify: `inst/app/www/wizard-nav.js`

- [ ] **Step 1: Add base64 → Blob → download helper**

In `inst/app/www/wizard-nav.js`, near `addCustomMessageHandler` block (after `nav_guard_has_data_update`), add:

```javascript
  function base64ToBlob(b64, mimeType) {
    var bytes = atob(b64);
    var arr = new Uint8Array(bytes.length);
    for (var i = 0; i < bytes.length; i++) {
      arr[i] = bytes.charCodeAt(i);
    }
    return new Blob([arr], { type: mimeType });
  }

  if (typeof Shiny !== 'undefined' && Shiny.addCustomMessageHandler) {
    Shiny.addCustomMessageHandler('download_blob', function(msg) {
      if (!msg || !msg.data_b64) return;
      try {
        var blob = base64ToBlob(msg.data_b64, msg.mime_type ||
          'application/octet-stream');
        var url = URL.createObjectURL(blob);
        var a = document.createElement('a');
        a.href = url;
        a.download = msg.filename || 'spc-data.xlsx';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        setTimeout(function() { URL.revokeObjectURL(url); }, 1000);
      } catch (err) {
        console.error('download_blob error:', err);
      }
    });
  }
```

- [ ] **Step 2: Manual test**

```r
R -e "library(biSPCharts); biSPCharts::run_app()"
```

Manual:
1. Upload data → trin 2
2. Click "Tilbage" → modal
3. Tick "Download kopi af data + indstillinger først"
4. Click Nulstil
5. Expect: browser downloads `spc-data_YYYY-MM-DD_HHMMSS.xlsx` AND lands on trin 1 with empty state
6. Open Excel-file → verify 3 sheets (Data + Indstillinger + SPC-analyse)

- [ ] **Step 3: Commit**

```bash
git add inst/app/www/wizard-nav.js
git commit -m "feat(navigation): JS handler for download_blob custom message

Receives base64-encoded Excel-blob from server, converts to Blob via
Uint8Array, triggers download via dynamic anchor element with
URL.createObjectURL. Synchronous from user perspective; server-side
reset proceeds immediately after sendCustomMessage returns.

Refs: docs/superpowers/specs/2026-05-12-navigation-guard-modal-design.md"
```

---

## Task 16: JS — beforeunload + in-app-navigating flag

**Files:**
- Modify: `inst/app/www/wizard-nav.js`

- [ ] **Step 1: Add beforeunload handler + in-app-navigating flag**

In `inst/app/www/wizard-nav.js`, add at top-level inside DOM-ready block:

```javascript
  // Browser tab-close / refresh guard
  var inAppNavigating = false;

  window.addEventListener('beforeunload', function(e) {
    if (inAppNavigating) return;
    if (navGuardHasData) {
      e.preventDefault();
      e.returnValue = '';  // Browsere viser native prompt
    }
  });

  if (typeof Shiny !== 'undefined' && Shiny.addCustomMessageHandler) {
    Shiny.addCustomMessageHandler('set_in_app_navigating', function(msg) {
      inAppNavigating = !!(msg && msg.value);
    });

    Shiny.addCustomMessageHandler('schedule_clear_in_app_navigating',
      function(msg) {
        var delay = (msg && msg.delay_ms) || 500;
        setTimeout(function() { inAppNavigating = false; }, delay);
      }
    );
  }
```

- [ ] **Step 2: Manual test**

```r
R -e "library(biSPCharts); biSPCharts::run_app()"
```

Manual A — tab-close guard:
1. Upload data → trin 2
2. Try to close tab (Cmd+W) or refresh (Cmd+R)
3. Expect browser native dialog: "Reload site? Changes you made may not be saved."
4. Click Cancel → still on trin 2 with data

Manual B — in-app nav bypass:
1. Upload data → trin 2
2. Click "Tilbage" → modal → Nulstil
3. Expect: lander on trin 1 WITHOUT extra beforeunload-prompt (suppressed by in_app_navigating flag during 500ms window)

- [ ] **Step 3: Commit**

```bash
git add inst/app/www/wizard-nav.js
git commit -m "feat(navigation): beforeunload guard + in-app-navigating bypass

window.beforeunload triggers browser-native prompt when data is
present AND user navigates away (tab-close, refresh, external link).
In-app navigation via guard-modal sets inAppNavigating=true server-
side to suppress browser prompt during reset+nav flow.

Refs: docs/superpowers/specs/2026-05-12-navigation-guard-modal-design.md"
```

---

## Task 17: Pre-push gate + full test suite

**Files:**
- All modified files
- Verify: `DESCRIPTION` Imports include `base64enc`

- [ ] **Step 1: Verify base64enc dependency**

Run: `grep -n "base64enc" DESCRIPTION`

If absent, add to Imports section:

```
Imports:
    ...,
    base64enc,
    ...
```

Then run: `R -e "devtools::document()"` to refresh.

- [ ] **Step 2: Run lintr on modified files**

Run:
```bash
R -e "lintr::lint('R/utils_server_navigation_guard.R')"
R -e "lintr::lint('R/state_management.R')"
R -e "lintr::lint('R/utils_server_wizard_gates.R')"
```

Fix all warnings.

- [ ] **Step 3: Run styler**

Run: `R -e "styler::style_file(c('R/utils_server_navigation_guard.R', 'R/state_management.R', 'R/utils_server_wizard_gates.R'))"`

- [ ] **Step 4: Run full navigation-guard test file**

Run: `R -e "library(biSPCharts); testthat::test_file('tests/testthat/test-navigation-guard.R')"`
Expected: all PASS.

- [ ] **Step 5: Run R CMD check (subset relevant)**

Run: `R -e "devtools::check_man()"`
Expected: no errors on roxygen docs.

- [ ] **Step 6: Manual end-to-end smoke test**

```r
R -e "library(biSPCharts); biSPCharts::run_app()"
```

Run full matrix:

| Test | Steps | Expected |
|------|-------|----------|
| Empty session + logo | Klik logo på trin 1 | Direct nav til start, ingen modal |
| Empty session + Upload-tab | Trin 1 → klik Upload-tab | Ingen modal |
| Trin 2 + logo + Annullér | Upload data, klik logo, Annullér | Modal vist, derefter trin 2 intact |
| Trin 2 + logo + Nulstil (no DL) | Upload, klik logo, Nulstil | start-tab, data tom |
| Trin 2 + logo + Nulstil (DL) | Upload, klik logo, tick DL, Nulstil | XLSX downloadet + start-tab + data tom |
| Trin 2 + back-knap | Upload, klik Tilbage | Modal vist |
| Trin 3 + Upload-tab | Naviger til trin 3, klik Upload-tab | Modal vist |
| Trin 2 + tab-close | Upload, prøv Cmd+W | Browser native prompt |

Document any failures and fix before commit.

- [ ] **Step 7: Commit (if DESCRIPTION/lint-fixes only)**

```bash
git add DESCRIPTION R/utils_server_navigation_guard.R \
        R/state_management.R R/utils_server_wizard_gates.R
git commit -m "chore(navigation): add base64enc to Imports + lint/style fixes

base64enc required for navigation guard download-blob feature.
Lint + styler applied to modified files.

Refs: docs/superpowers/specs/2026-05-12-navigation-guard-modal-design.md"
```

---

## Task 18: shinytest2 manual integration test

**Files:**
- Create: `tests/manual/test-navigation-guard.R`

- [ ] **Step 1: Write shinytest2 integration test**

Create `tests/manual/test-navigation-guard.R`:

```r
# Manual shinytest2 — kør lokalt, ej i CI
# Per [[feedback_shinytest2_upload_flow]]: upload-flow kræver paste +
# load_paste_data, ikke app$upload_file.

library(shinytest2)
library(testthat)

test_that("Navigation guard modal vises på trin 2 ved logo-klik", {
  app <- AppDriver$new(
    name = "nav-guard-logo",
    timeout = 20000,
    height = 900, width = 1400
  )
  on.exit(app$stop(), add = TRUE)

  # Naviger til upload-tab + paste data
  app$click(selector = '#main_navbar .nav-link[data-value="upload"]')
  app$wait_for_idle()

  paste_data <- "dato\ttaeller\n2026-01-01\t10\n2026-01-02\t12\n"
  app$set_inputs(paste_textarea = paste_data)
  app$click("load_paste_data")
  app$wait_for_idle(timeout = 5000)

  # Naviger til trin 2 (auto-advance eller manuel)
  app$wait_for_value(input = "main_navbar", ignore = list("upload"))

  expect_equal(app$get_value(input = "main_navbar"), "analyser")

  # Klik logo
  app$click(selector = "#logo_home_link")
  app$wait_for_idle()

  # Expect modal
  modal_html <- app$get_html(".modal-dialog")
  expect_true(grepl("Forlad arbejde", modal_html))
  expect_true(grepl("nav_guard_confirm", modal_html))

  # Annullér
  app$click("nav_guard_cancel")
  app$wait_for_idle()
  expect_equal(app$get_value(input = "main_navbar"), "analyser")
})

test_that("Navigation guard Nulstil (no DL) reset session", {
  app <- AppDriver$new(
    name = "nav-guard-reset",
    timeout = 20000
  )
  on.exit(app$stop(), add = TRUE)

  app$click(selector = '#main_navbar .nav-link[data-value="upload"]')
  app$wait_for_idle()
  app$set_inputs(paste_textarea = "dato\ttaeller\n2026-01-01\t10\n")
  app$click("load_paste_data")
  app$wait_for_idle(timeout = 5000)

  # Auto-advance til trin 2
  app$wait_for_value(input = "main_navbar", ignore = list("upload"))

  # Klik back-knap
  app$click("back_to_upload")
  app$wait_for_idle()

  # Confirm reset uden download
  app$set_inputs(nav_guard_download = FALSE)
  app$click("nav_guard_confirm")
  app$wait_for_idle(timeout = 3000)

  expect_equal(app$get_value(input = "main_navbar"), "upload")
})
```

- [ ] **Step 2: Run manual test**

Run: `R -e "testthat::test_file('tests/manual/test-navigation-guard.R')"`
Expected: PASS — modal vises og reset virker.

Document any flakiness — manual tests are excluded from CI.

- [ ] **Step 3: Commit**

```bash
git add tests/manual/test-navigation-guard.R
git commit -m "test(navigation): add shinytest2 manual test for guard modal

Tests two paths: logo-klik shows modal + annullér preserves state,
back-knap + Nulstil resets to trin 1. Per project convention manual
tests use paste-data flow (ikke upload_file) and run locally only.

Refs: docs/superpowers/specs/2026-05-12-navigation-guard-modal-design.md"
```

---

## Task 19: Update NEWS.md + open draft PR

**Files:**
- Modify: `NEWS.md`

- [ ] **Step 1: Add NEWS-entry**

Add to top of `NEWS.md` (above existing top entry):

```markdown
# biSPCharts X.Y.Z

## Nye features
* Navigations-guard på trin 2/3: brugere får nu en modal-advarsel før de forlader deres arbejde via logo, Upload-tab eller "Tilbage"-knappen. Modalen tilbyder valgfri download af data + indstillinger som Excel-fil inden session nulstilles. Browser-tab-close advares også via native dialog. (PR-nummer indsættes ved merge)

```

Bump `Version:` field in `DESCRIPTION` per `~/.claude/rules/VERSIONING_POLICY.md` — `feat:` commits → MINOR bump pre-1.0.

- [ ] **Step 2: Run pre-release checklist**

```bash
R -e "devtools::test()"
R -e "devtools::check()"
```

All green expected (or only documented NOTEs).

- [ ] **Step 3: Push branch + open draft PR to develop**

```bash
git push -u origin feat/navigation-guard-modal

gh pr create --draft --base develop \
  --title "feat(navigation): guard modal on trin 2/3 destructive navigation" \
  --body "$(cat <<'EOF'
## Summary
- Modal warns user when navigating away from trin 2/3 with data loaded
- Triggers: logo (→start), Upload-tab (→upload), Tilbage-knap, browser tab-close
- Modal includes opt-in checkbox for downloading data + indstillinger as Excel before reset
- In-memory Excel-blob via sendCustomMessage avoids race between downloadHandler and reset_to_empty_session

## Design
See `docs/superpowers/specs/2026-05-12-navigation-guard-modal-design.md`

## Test plan
- [ ] Empty session: logo + Upload-tab → direct nav, no modal
- [ ] Trin 2 with data: logo → modal → Annullér → state intact
- [ ] Trin 2 with data: logo → Nulstil (no DL) → start-tab + empty state
- [ ] Trin 2 with data: logo → Nulstil + DL → XLSX downloaded + start-tab + empty state
- [ ] Trin 2: Tilbage-knap → modal
- [ ] Trin 3: Upload-tab → modal
- [ ] Browser tab-close on trin 2 with data → native prompt
- [ ] In-app nav via guard does NOT trigger beforeunload-prompt

## Files
- New: `R/utils_server_navigation_guard.R`, `tests/testthat/test-navigation-guard.R`, `tests/manual/test-navigation-guard.R`
- Modified: `R/state_management.R`, `R/utils_server_events_navigation.R`, `R/utils_server_wizard_gates.R`, `R/app_server.R`, `inst/app/www/wizard-nav.js`, `NEWS.md`, `DESCRIPTION`
EOF
)"
```

- [ ] **Step 4: Final commit (NEWS + version bump)**

```bash
git add NEWS.md DESCRIPTION
git commit -m "chore(release): bump version + NEWS for navigation guard modal

Refs: docs/superpowers/specs/2026-05-12-navigation-guard-modal-design.md"
git push
```

---

## Self-Review Checklist

After implementing all tasks:

- [ ] **Spec coverage** — every spec section §1-§11 maps to one or more tasks (§1 covered by all; §2 covered by Tasks 1-2; §3-§4 by all; §5 by Tasks 3-7, 10-16; §6 by Tasks 3-9, 12-16; §7 by Task 6 (safe_operation); §8 by Tasks 2-9 + 18; §9 confirmed YAGNI; §10 risks acknowledged in Task 17 manual test; §11 file-list matches Task file-map)
- [ ] **Placeholder scan** — no TBD/TODO; all code shown inline; all function names consistent (`build_spc_excel_blob`, `handle_nav_guard_confirm`, `setup_navigation_guard_listener`, `generate_spc_filename`, `navigation_guard_modal`, `emit$navigation_requested`)
- [ ] **Type consistency** — `setup_navigation_guard_listener(app_state, emit, session, input)` signature consistent across Tasks 3-13; `emit$navigation_requested(target)` with target ∈ {"start", "upload"} consistent
- [ ] **Risks acknowledged** — base64-blob size limit, JS-conflict risk, beforeunload dev-friction (per spec §10) addressed in Task 17 manual test matrix
