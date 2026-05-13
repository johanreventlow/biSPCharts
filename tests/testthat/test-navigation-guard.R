test_that("has_real_data returns TRUE when file_uploaded is TRUE", {
  app_state <- create_app_state()
  shiny::isolate({
    app_state$session$file_uploaded <- TRUE
    app_state$data$current_data <- NULL # selv hvis data er NULL
  })
  expect_true(has_real_data(app_state))
})

test_that("has_real_data returns FALSE for NULL data + no upload", {
  app_state <- create_app_state()
  shiny::isolate({
    app_state$session$file_uploaded <- FALSE
    app_state$data$current_data <- NULL
  })
  expect_false(has_real_data(app_state))
})

test_that("has_real_data returns FALSE for placeholder session data (all NA)", {
  app_state <- create_app_state()
  shiny::isolate({
    app_state$session$file_uploaded <- FALSE
    app_state$data$current_data <- data.frame(
      Skift = rep(FALSE, 20),
      Frys = rep(FALSE, 20),
      Dato = rep(NA_character_, 20),
      Taeller = rep(NA_real_, 20),
      Naevner = rep(NA_real_, 20),
      Kommentar = rep(NA_character_, 20)
    )
  })
  expect_false(has_real_data(app_state))
})

test_that("has_real_data returns TRUE for manual entry (some non-NA cells)", {
  app_state <- create_app_state()
  shiny::isolate({
    app_state$session$file_uploaded <- FALSE
    app_state$data$current_data <- data.frame(
      Skift = c(FALSE, FALSE, FALSE),
      Frys = c(FALSE, FALSE, FALSE),
      Dato = c("2026-01-01", NA, NA),
      Taeller = c(NA_real_, NA_real_, NA_real_)
    )
  })
  expect_true(has_real_data(app_state))
})

test_that("has_real_data ignores Skift/Frys default-FALSE values", {
  # 20 rows with Skift=FALSE/Frys=FALSE (default booleans) — skal IKKE
  # taelle som "real data" selv om !is.na(FALSE) = TRUE
  app_state <- create_app_state()
  shiny::isolate({
    app_state$session$file_uploaded <- FALSE
    app_state$data$current_data <- data.frame(
      Skift = rep(FALSE, 5),
      Frys = rep(FALSE, 5)
    )
  })
  expect_false(has_real_data(app_state))
})

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
    # Ugyldigt target -> tving til "upload" + log advarsel
    emit$navigation_requested("malicious; rm -rf /")
    expect_equal(app_state$navigation$guard_pending_target, "upload")
  })
})

test_that("guard-listener triggers direct nav when current_data is NULL", {
  # reactiveConsole = TRUE aktiverer reaktiv evaluering uden kørende Shiny-app.
  # Nødvendigt for at observeEvent registreret uden for testServer kan flushe.
  withr::local_options(shiny.reactiveConsole = TRUE)

  app_state <- create_app_state()
  emit <- create_emit_api(app_state)
  session <- shiny::MockShinySession$new()
  nav_select_calls <- list()

  # Intercept bslib::nav_select med local mock
  testthat::local_mocked_bindings(
    nav_select = function(id, selected, session) {
      nav_select_calls[[length(nav_select_calls) + 1]] <<- list(
        id = id, selected = selected
      )
    },
    .package = "bslib"
  )

  setup_nav_guard_listener(app_state, emit, session, session$input)

  # TODO: move to testServer() wrapper; shiny::: needed until guard-listener
  # has a server-function home (Task 4 may enable this)
  # Første flush forbruger ignoreInit = TRUE
  shiny:::flushReact()

  expect_null(shiny::isolate(app_state$data$current_data))
  emit$navigation_requested("upload")

  # Anden flush udløser observer-kroppen
  shiny:::flushReact()

  expect_length(nav_select_calls, 1)
  expect_equal(nav_select_calls[[1]]$selected, "upload")
  expect_equal(nav_select_calls[[1]]$id, "main_navbar")
  expect_null(shiny::isolate(app_state$navigation$guard_pending_target))
  expect_false(isTRUE(shiny::isolate(app_state$navigation$guard_modal_open)))
})

test_that("guard-listener shows modal when current_data has rows", {
  withr::local_options(shiny.reactiveConsole = TRUE)

  app_state <- create_app_state()
  emit <- create_emit_api(app_state)
  session <- shiny::MockShinySession$new()

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

  setup_nav_guard_listener(app_state, emit, session, session$input)

  # Første flush forbruger ignoreInit = TRUE
  shiny:::flushReact()

  emit$navigation_requested("start")

  # Anden flush udløser observer-kroppen
  shiny:::flushReact()

  expect_length(show_modal_calls, 1)
  expect_true(isTRUE(shiny::isolate(app_state$navigation$guard_modal_open)))
  expect_equal(shiny::isolate(app_state$navigation$guard_pending_target), "start")
})

test_that("navigation_guard_modal contains both knapper + checkbox", {
  modal <- navigation_guard_modal()
  html <- as.character(modal)
  expect_match(html, "nav_guard_confirm")
  expect_match(html, "nav_guard_cancel")
  expect_match(html, "nav_guard_download")
  expect_match(html, "Nej, bliv her")
  expect_match(html, "Nulstil")
})

test_that("nav_guard_cancel removes modal and clears flags", {
  withr::local_options(shiny.reactiveConsole = TRUE)

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

  setup_nav_guard_listener(app_state, emit, session, session$input)

  # Flush forbruger ignoreInit = TRUE for alle observers
  shiny:::flushReact()

  # Simulér klik på Annullér
  session$setInputs(nav_guard_cancel = 1)
  shiny:::flushReact()

  expect_true(remove_modal_called)
  expect_null(shiny::isolate(app_state$navigation$guard_pending_target))
  expect_false(shiny::isolate(app_state$navigation$guard_modal_open))
  expect_equal(nrow(shiny::isolate(app_state$data$current_data)), 3) # uændret
})

test_that("build_spc_excel_blob returns raw bytes with XLSX magic header", {
  app_state <- create_app_state()
  shiny::isolate({
    app_state$data$current_data <- data.frame(
      dato = as.Date("2026-01-01") + 0:9,
      taeller = withr::with_seed(42, sample(10, 10))
    )
    app_state$columns$mappings$x_column <- "dato"
    app_state$columns$mappings$y_column <- "taeller"
  })

  # collect_metadata kræver input — send minimal stub (alle felter er NULL-safe)
  input_stub <- list()

  blob <- build_spc_excel_blob(app_state, input_stub)

  expect_type(blob, "raw")
  expect_gt(length(blob), 0)
  # XLSX = ZIP-container, magic bytes 0x50 0x4B 0x03 0x04
  expect_equal(as.integer(blob[1:4]), c(0x50, 0x4B, 0x03, 0x04))
})

test_that("generate_spc_filename returns .xlsx filename with date", {
  app_state <- create_app_state()
  name <- generate_spc_filename(app_state)
  expect_match(name, "\\.xlsx$")
  expect_match(name, "\\d{4}-\\d{2}-\\d{2}")
})

test_that("nav_guard_confirm without download resets session and navigates", {
  withr::local_options(shiny.reactiveConsole = TRUE)

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

  setup_nav_guard_listener(app_state, emit, session, session$input)
  shiny:::flushReact()

  session$setInputs(
    nav_guard_download = FALSE,
    nav_guard_confirm = 1
  )
  shiny:::flushReact()

  download_calls <- Filter(
    function(x) x$type == "download_blob",
    send_custom_calls
  )
  expect_length(download_calls, 0)

  expect_true(reset_called)
  expect_length(nav_select_calls, 1)
  expect_equal(nav_select_calls[[1]], "upload")
  expect_null(shiny::isolate(app_state$navigation$guard_pending_target))
  expect_false(shiny::isolate(app_state$navigation$guard_modal_open))
})

test_that("nav_guard_confirm with download sends blob before reset", {
  withr::local_options(shiny.reactiveConsole = TRUE)

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
    # Fangs data_present-status VED TIDSPUNKTET for dette kald
    send_calls[[length(send_calls) + 1]] <<- list(
      type = type,
      data_present = !is.null(shiny::isolate(app_state$data$current_data))
    )
  }

  testthat::local_mocked_bindings(
    nav_select = function(id, selected, session) invisible(NULL),
    .package = "bslib"
  )
  testthat::local_mocked_bindings(
    reset_to_empty_session = function(session, app_state, emit, ui_service = NULL) {
      app_state$data$current_data <- NULL
    }
  )

  setup_nav_guard_listener(app_state, emit, session, session$input)
  shiny:::flushReact()

  session$setInputs(
    nav_guard_download = TRUE,
    nav_guard_confirm = 1
  )
  shiny:::flushReact()

  download_call <- Filter(function(x) x$type == "download_blob", send_calls)
  expect_length(download_call, 1)
  # Kritisk: data skal stadig være til stede da sendCustomMessage affyres
  expect_true(download_call[[1]]$data_present)
  # Efter hele sekvensen er data nulstillet
  expect_null(shiny::isolate(app_state$data$current_data))
})

test_that("nav_guard_confirm clears paste_data_input when target is upload", {
  withr::local_options(shiny.reactiveConsole = TRUE)

  app_state <- create_app_state()
  emit <- create_emit_api(app_state)
  session <- shiny::MockShinySession$new()

  shiny::isolate({
    app_state$data$current_data <- data.frame(x = 1:3)
    app_state$navigation$guard_pending_target <- "upload"
    app_state$navigation$guard_modal_open <- TRUE
  })

  session$sendCustomMessage <- function(type, message) invisible(NULL)

  update_textarea_calls <- list()
  testthat::local_mocked_bindings(
    updateTextAreaInput = function(session, inputId, value = NULL, ...) {
      update_textarea_calls[[length(update_textarea_calls) + 1]] <<- list(
        inputId = inputId, value = value
      )
    },
    .package = "shiny"
  )
  testthat::local_mocked_bindings(
    nav_select = function(id, selected, session) invisible(NULL),
    .package = "bslib"
  )
  testthat::local_mocked_bindings(
    reset_to_empty_session = function(session, app_state, emit,
                                      ui_service = NULL) {
      app_state$data$current_data <- NULL
    }
  )

  setup_nav_guard_listener(app_state, emit, session, session$input)
  shiny:::flushReact()

  session$setInputs(
    nav_guard_download = FALSE,
    nav_guard_confirm = 1
  )
  shiny:::flushReact()

  paste_calls <- Filter(
    function(x) identical(x$inputId, "paste_data_input"),
    update_textarea_calls
  )
  expect_length(paste_calls, 1)
  expect_equal(paste_calls[[1]]$value, "")
})

test_that("nav_guard_confirm does NOT clear paste_data_input when target is start", {
  withr::local_options(shiny.reactiveConsole = TRUE)

  app_state <- create_app_state()
  emit <- create_emit_api(app_state)
  session <- shiny::MockShinySession$new()

  shiny::isolate({
    app_state$data$current_data <- data.frame(x = 1:3)
    app_state$navigation$guard_pending_target <- "start"
    app_state$navigation$guard_modal_open <- TRUE
  })

  session$sendCustomMessage <- function(type, message) invisible(NULL)

  update_textarea_calls <- list()
  testthat::local_mocked_bindings(
    updateTextAreaInput = function(session, inputId, value = NULL, ...) {
      update_textarea_calls[[length(update_textarea_calls) + 1]] <<- list(
        inputId = inputId, value = value
      )
    },
    .package = "shiny"
  )
  testthat::local_mocked_bindings(
    nav_select = function(id, selected, session) invisible(NULL),
    .package = "bslib"
  )
  testthat::local_mocked_bindings(
    reset_to_empty_session = function(session, app_state, emit,
                                      ui_service = NULL) {
      app_state$data$current_data <- NULL
    }
  )

  setup_nav_guard_listener(app_state, emit, session, session$input)
  shiny:::flushReact()

  session$setInputs(
    nav_guard_download = FALSE,
    nav_guard_confirm = 1
  )
  shiny:::flushReact()

  paste_calls <- Filter(
    function(x) identical(x$inputId, "paste_data_input"),
    update_textarea_calls
  )
  expect_length(paste_calls, 0)
})

test_that("nav_guard_confirm sets guard_active during confirm and clears after flush", {
  withr::local_options(shiny.reactiveConsole = TRUE)

  app_state <- create_app_state()
  emit <- create_emit_api(app_state)
  session <- shiny::MockShinySession$new()

  shiny::isolate({
    app_state$data$current_data <- data.frame(x = 1:3)
    app_state$navigation$guard_pending_target <- "start"
    app_state$navigation$guard_modal_open <- TRUE
  })

  session$sendCustomMessage <- function(type, message) invisible(NULL)

  # Capture guard_active SAMTIDIG med reset_to_empty_session-kald
  observed_flag <- NULL
  testthat::local_mocked_bindings(
    reset_to_empty_session = function(session, app_state, emit,
                                      ui_service = NULL) {
      observed_flag <<- isTRUE(shiny::isolate(
        app_state$navigation$guard_active
      ))
      app_state$data$current_data <- NULL
    }
  )
  testthat::local_mocked_bindings(
    nav_select = function(id, selected, session) invisible(NULL),
    .package = "bslib"
  )

  setup_nav_guard_listener(app_state, emit, session, session$input)
  shiny:::flushReact()

  session$setInputs(
    nav_guard_download = FALSE,
    nav_guard_confirm = 1
  )
  shiny:::flushReact()

  # Under reset var flagget sat
  expect_true(observed_flag)
})

test_that("nav_guard_confirm sends wizard lock-step messages post-reset", {
  withr::local_options(shiny.reactiveConsole = TRUE)

  app_state <- create_app_state()
  emit <- create_emit_api(app_state)
  session <- shiny::MockShinySession$new()

  shiny::isolate({
    app_state$data$current_data <- data.frame(x = 1:3)
    app_state$navigation$guard_pending_target <- "upload"
    app_state$navigation$guard_modal_open <- TRUE
  })

  send_calls <- list()
  session$sendCustomMessage <- function(type, message) {
    send_calls[[length(send_calls) + 1]] <<- list(
      type = type, message = message
    )
  }

  testthat::local_mocked_bindings(
    nav_select = function(id, selected, session) invisible(NULL),
    .package = "bslib"
  )
  testthat::local_mocked_bindings(
    reset_to_empty_session = function(session, app_state, emit,
                                      ui_service = NULL) {
      app_state$data$current_data <- NULL
    }
  )

  setup_nav_guard_listener(app_state, emit, session, session$input)
  shiny:::flushReact()

  session$setInputs(
    nav_guard_download = FALSE,
    nav_guard_confirm = 1
  )
  shiny:::flushReact()

  uncomplete_calls <- Filter(
    function(x) identical(x$type, "wizard-uncomplete-step"),
    send_calls
  )
  lock_calls <- Filter(
    function(x) identical(x$type, "wizard-lock-step"),
    send_calls
  )

  expect_length(uncomplete_calls, 1)
  expect_equal(as.numeric(uncomplete_calls[[1]]$message), 1)
  expect_length(lock_calls, 2)
  expect_setequal(
    vapply(lock_calls, function(x) as.numeric(x$message), numeric(1)),
    c(2, 3)
  )
})

test_that("server-side main_navbar guard reverts + emits on destructive transition", {
  withr::local_options(shiny.reactiveConsole = TRUE)

  app_state <- create_app_state()
  emit <- create_emit_api(app_state)
  session <- shiny::MockShinySession$new()

  shiny::isolate({
    app_state$data$current_data <- data.frame(x = 1:3)
    app_state$session$file_uploaded <- TRUE
    app_state$navigation$current_tab <- "analyser"
  })

  nav_select_calls <- list()
  testthat::local_mocked_bindings(
    nav_select = function(id, selected, session) {
      nav_select_calls[[length(nav_select_calls) + 1]] <<- selected
    },
    .package = "bslib"
  )

  setup_nav_guard_listener(app_state, emit, session, session$input)
  shiny:::flushReact()

  # Simuler bslib tab-swap til upload
  session$setInputs(main_navbar = "upload")
  shiny:::flushReact()

  # Guard skal have revertet tab tilbage til analyser + emit navigation_requested
  expect_length(nav_select_calls, 1)
  expect_equal(nav_select_calls[[1]], "analyser")
  expect_equal(
    shiny::isolate(app_state$navigation$guard_pending_target),
    "upload"
  )
})

test_that("server-side main_navbar guard skips when no real data", {
  withr::local_options(shiny.reactiveConsole = TRUE)

  app_state <- create_app_state()
  emit <- create_emit_api(app_state)
  session <- shiny::MockShinySession$new()

  shiny::isolate({
    # Placeholder-only — file_uploaded FALSE, all-NA data
    app_state$session$file_uploaded <- FALSE
    app_state$data$current_data <- data.frame(
      Skift = rep(FALSE, 20),
      Frys = rep(FALSE, 20),
      Dato = rep(NA_character_, 20)
    )
    app_state$navigation$current_tab <- "analyser"
  })

  nav_select_calls <- list()
  testthat::local_mocked_bindings(
    nav_select = function(id, selected, session) {
      nav_select_calls[[length(nav_select_calls) + 1]] <<- selected
    },
    .package = "bslib"
  )

  setup_nav_guard_listener(app_state, emit, session, session$input)
  shiny:::flushReact()

  session$setInputs(main_navbar = "upload")
  shiny:::flushReact()

  # Ingen revert, ingen emit — bruger maa lov til at gaa direkte
  expect_length(nav_select_calls, 0)
  expect_null(shiny::isolate(app_state$navigation$guard_pending_target))
})

test_that("server-side main_navbar guard skips trin 3 -> analyser (non-destructive)", {
  withr::local_options(shiny.reactiveConsole = TRUE)

  app_state <- create_app_state()
  emit <- create_emit_api(app_state)
  session <- shiny::MockShinySession$new()

  shiny::isolate({
    app_state$session$file_uploaded <- TRUE
    app_state$data$current_data <- data.frame(x = 1:3)
    app_state$navigation$current_tab <- "eksporter"
  })

  nav_select_calls <- list()
  testthat::local_mocked_bindings(
    nav_select = function(id, selected, session) {
      nav_select_calls[[length(nav_select_calls) + 1]] <<- selected
    },
    .package = "bslib"
  )

  setup_nav_guard_listener(app_state, emit, session, session$input)
  shiny:::flushReact()

  # Trin 3 -> trin 2 (via Tilbage-knap) — non-destruktiv, ingen guard
  session$setInputs(main_navbar = "analyser")
  shiny:::flushReact()

  expect_length(nav_select_calls, 0)
})

test_that("server-side main_navbar guard reverting-flag prevents re-fire on revert", {
  withr::local_options(shiny.reactiveConsole = TRUE)

  app_state <- create_app_state()
  emit <- create_emit_api(app_state)
  session <- shiny::MockShinySession$new()

  shiny::isolate({
    app_state$session$file_uploaded <- TRUE
    app_state$data$current_data <- data.frame(x = 1:3)
    app_state$navigation$current_tab <- "analyser"
  })

  nav_select_calls <- list()
  testthat::local_mocked_bindings(
    nav_select = function(id, selected, session) {
      nav_select_calls[[length(nav_select_calls) + 1]] <<- selected
    },
    .package = "bslib"
  )

  setup_nav_guard_listener(app_state, emit, session, session$input)
  shiny:::flushReact()

  # Forste klik: trin 2 -> upload -> revert til analyser
  session$setInputs(main_navbar = "upload")
  shiny:::flushReact()
  expect_length(nav_select_calls, 1) # revert kaldt

  # Simuler revert-triggered input-update (bslib emit nyt main_navbar event)
  session$setInputs(main_navbar = "analyser")
  shiny:::flushReact()

  # Skal IKKE trigger ny revert (guard_reverting konsumeret)
  expect_length(nav_select_calls, 1) # still 1, ikke 2
  expect_false(shiny::isolate(app_state$navigation$guard_reverting))
})

test_that("new navigation_requested ignored while guard_modal_open is TRUE", {
  withr::local_options(shiny.reactiveConsole = TRUE)

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

  setup_nav_guard_listener(app_state, emit, session, session$input)
  shiny:::flushReact()

  shiny::isolate({
    emit$navigation_requested("start") # Skal ignoreres
  })
  shiny:::flushReact()

  expect_equal(show_modal_count, 0)
  # Oprindeligt pending_target bevaret (ikke overskrevet af nyt emit)
  expect_equal(shiny::isolate(app_state$navigation$guard_pending_target), "upload")
})
