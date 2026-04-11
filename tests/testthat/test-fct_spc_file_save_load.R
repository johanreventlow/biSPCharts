test_that("build_spc_excel opretter fil med to ark: Data og Indstillinger", {
  data <- data.frame(dato = as.Date("2024-01-01") + 0:4,
                     vaerdi = c(1.0, 2.0, 3.0, 4.0, 5.0))
  metadata <- list(x_column = "dato", y_column = "vaerdi", chart_type = "p")

  path <- build_spc_excel(data, metadata)

  expect_true(file.exists(path))
  sheets <- readxl::excel_sheets(path)
  expect_true("Data" %in% sheets)
  expect_true("Indstillinger" %in% sheets)
})

test_that("build_spc_excel Data-ark indeholder korrekte rækker og kolonner", {
  data <- data.frame(dato = as.Date("2024-01-01") + 0:4,
                     vaerdi = c(1.0, 2.0, 3.0, 4.0, 5.0))
  metadata <- list(x_column = "dato")

  path <- build_spc_excel(data, metadata)
  result <- readxl::read_excel(path, sheet = "Data")

  expect_equal(nrow(result), 5)
  expect_true("dato" %in% names(result))
  expect_true("vaerdi" %in% names(result))
})

test_that("build_spc_excel Indstillinger-ark indeholder metadata som Felt/Vaerdi", {
  data <- data.frame(x = 1:3, y = 4:6)
  metadata <- list(x_column = "x", y_column = "y", chart_type = "p",
                   indicator_title = "Min titel")

  path <- build_spc_excel(data, metadata)
  settings <- readxl::read_excel(path, sheet = "Indstillinger", skip = 2)

  expect_true("Felt" %in% names(settings))
  expect_true("Vaerdi" %in% names(settings))

  felt_values <- settings$Felt
  expect_true("x_column" %in% felt_values)
  expect_true("indicator_title" %in% felt_values)

  title_row <- settings[settings$Felt == "indicator_title", ]
  expect_equal(title_row$Vaerdi, "Min titel")
})

test_that("build_spc_excel returnerer sti til eksisterende fil", {
  data <- data.frame(x = 1)
  metadata <- list()

  path <- build_spc_excel(data, metadata)

  expect_true(is.character(path))
  expect_true(grepl("\\.xlsx$", path))
  expect_true(file.exists(path))
})

test_that("parse_spc_excel returnerer NULL for fil uden Indstillinger-ark", {
  data <- data.frame(x = 1:3, y = 4:6)
  path <- tempfile(fileext = ".xlsx")
  writexl::write_xlsx(data, path)

  result <- parse_spc_excel(path)
  expect_null(result)
})

test_that("parse_spc_excel returnerer named list med metadata-felter", {
  data <- data.frame(dato = as.Date("2024-01-01") + 0:4,
                     vaerdi = c(1.0, 2.0, 3.0, 4.0, 5.0))
  metadata <- list(
    x_column        = "dato",
    y_column        = "vaerdi",
    chart_type      = "p",
    indicator_title = "Ventetid til operation",
    target_value    = "30",
    y_axis_unit     = "dage"
  )

  path <- build_spc_excel(data, metadata)
  parsed <- parse_spc_excel(path)

  expect_false(is.null(parsed))
  expect_equal(parsed$x_column,        "dato")
  expect_equal(parsed$y_column,        "vaerdi")
  expect_equal(parsed$chart_type,      "p")
  expect_equal(parsed$indicator_title, "Ventetid til operation")
  expect_equal(parsed$target_value,    "30")
  expect_equal(parsed$y_axis_unit,     "dage")
})

test_that("parse_spc_excel round-trip: byg og parse giver identisk metadata", {
  data <- data.frame(x = 1:3)
  metadata <- list(
    x_column           = "x",
    y_column           = "y",
    chart_type         = "c",
    indicator_title    = "Test",
    indicator_description = "Beskrivelse",
    target_value       = "",
    centerline_value   = "",
    y_axis_unit        = "count",
    unit_type          = "select",
    unit_select        = "med",
    unit_custom        = "",
    export_title       = "Eksport titel",
    export_department  = "Afdeling X",
    export_format      = "pdf",
    pdf_description    = "",
    pdf_improvement    = "",
    png_size_preset    = "HD",
    png_dpi            = "300",
    active_tab         = "analyser",
    skift_column       = "",
    frys_column        = "",
    kommentar_column   = "",
    n_column           = ""
  )

  path <- build_spc_excel(data, metadata)
  parsed <- parse_spc_excel(path)

  for (felt in names(metadata)) {
    expect_equal(parsed[[felt]], metadata[[felt]],
      info = paste("Felt mismatch:", felt))
  }
})

test_that("parse_spc_excel returnerer NULL ved korrupt Indstillinger-ark", {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Data")
  openxlsx::writeData(wb, sheet = "Data", x = data.frame(x = 1))
  openxlsx::addWorksheet(wb, "Indstillinger")
  openxlsx::writeData(wb, sheet = "Indstillinger",
    x = data.frame(Besked = "kun kommentar"), startRow = 1, colNames = FALSE)
  path <- tempfile(fileext = ".xlsx")
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)

  result <- parse_spc_excel(path)
  expect_true(is.null(result) || length(result) == 0)
})

# ==============================================================================
# INTEGRATION: full build -> handle_excel_upload -> restore round-trip
# ==============================================================================
#
# Verificerer at en gemt biSPCharts-fil kan uploades igen og at:
#   1. Data havner i app_state$data$current_data
#   2. Kolonne-mappings skrives til app_state$columns$mappings FØR emit
#   3. restoring_session-flag sættes under restore
#   4. emit$data_updated kaldes med "session_restore" kontekst (IKKE file_loaded)
#   5. ui_service$update_form_fields modtager metadata efter onFlushed
#   6. auto_detection_started bliver IKKE kaldt (da mappings allerede gendannes)

test_that("handle_excel_upload round-trip genskaber mappings og trigger session_restore", {
  skip_if_not(exists("handle_excel_upload", mode = "function"))
  skip_if_not(exists("build_spc_excel", mode = "function"))

  # --- Byg en realistisk save-fil ---
  data <- data.frame(
    Dato    = as.Date("2024-01-01") + 0:4,
    Taeller = c(1.0, 2.0, 3.0, 4.0, 5.0),
    Naevner = c(10, 10, 10, 10, 10)
  )
  original_metadata <- list(
    x_column        = "Dato",
    y_column        = "Taeller",
    n_column        = "Naevner",
    chart_type      = "p",
    indicator_title = "Roundtrip-test",
    target_value    = "0.5",
    y_axis_unit     = "percent"
  )
  save_path <- build_spc_excel(data, original_metadata)
  expect_true(file.exists(save_path))

  # --- Mock infrastructure ---
  app_state <- new.env(parent = emptyenv())
  app_state$data <- shiny::reactiveValues(
    current_data = NULL,
    original_data = NULL,
    updating_table = FALSE
  )
  app_state$session <- shiny::reactiveValues(
    restoring_session = FALSE,
    file_uploaded = FALSE
  )
  app_state$columns <- shiny::reactiveValues(
    mappings = shiny::reactiveValues(
      x_column = NULL, y_column = NULL, n_column = NULL,
      skift_column = NULL, frys_column = NULL, kommentar_column = NULL
    ),
    auto_detect = shiny::reactiveValues(completed = FALSE)
  )
  app_state$ui <- shiny::reactiveValues(hide_anhoej_rules = TRUE)

  # Emit-sporing: capture konteksten fra data_updated samt hvilke andre
  # events der blev fyret
  emit_log <- new.env(parent = emptyenv())
  emit_log$data_updated_context <- NULL
  emit_log$auto_detection_started_called <- FALSE
  emit <- list(
    data_updated = function(context = NULL, ...) {
      emit_log$data_updated_context <- context
    },
    navigation_changed = function(...) invisible(NULL),
    auto_detection_started = function(...) {
      emit_log$auto_detection_started_called <- TRUE
    },
    visualization_update_needed = function(...) invisible(NULL)
  )

  # Mock ui_service
  ui_log <- new.env(parent = emptyenv())
  ui_log$received_metadata <- NULL
  ui_service <- list(
    update_form_fields = function(metadata, fields = NULL) {
      ui_log$received_metadata <- metadata
    }
  )

  # Mock session. MockShinySession understøtter ikke sendNotification, så vi
  # stubber showNotification væk for at isolere testen fra Shiny's UI-lag.
  session <- shiny::MockShinySession$new()
  mockery::stub(
    handle_excel_upload,
    "shiny::showNotification",
    function(...) invisible(NULL)
  )

  shiny::isolate({
    handle_excel_upload(save_path, session, app_state, emit, ui_service)
  })

  # --- Verifikationer FØR onFlushed-callbacks ---
  # Data skal være skrevet til app_state
  expect_equal(shiny::isolate(nrow(app_state$data$current_data)), 5)
  expect_true(shiny::isolate(app_state$session$file_uploaded))
  expect_true(shiny::isolate(app_state$columns$auto_detect$completed))

  # Mappings skal være skrevet FØR emit (det er pointen i fixet)
  expect_equal(shiny::isolate(app_state$columns$mappings$x_column), "Dato")
  expect_equal(shiny::isolate(app_state$columns$mappings$y_column), "Taeller")
  expect_equal(shiny::isolate(app_state$columns$mappings$n_column), "Naevner")

  # emit skal have fyret "session_restore" — IKKE "file_loaded"
  expect_equal(emit_log$data_updated_context, "session_restore")
  expect_false(emit_log$auto_detection_started_called,
    info = "auto_detection_started må IKKE kaldes når mappings gendannes")

  # restoring_session skal være TRUE indtil flush-cleanup kører
  expect_true(shiny::isolate(app_state$session$restoring_session))

  # --- Kør onFlushed-callbacks (simulerer Shiny flush) ---
  session$flushReact()

  # Nu skal restore_metadata være kaldt → ui_service har metadata
  expect_false(is.null(ui_log$received_metadata))
  expect_equal(ui_log$received_metadata$x_column, "Dato")
  expect_equal(ui_log$received_metadata$indicator_title, "Roundtrip-test")

  # Og restoring_session skal være ryddet
  expect_false(shiny::isolate(app_state$session$restoring_session))
})

test_that("handle_excel_upload fallback uden metadata triggerer auto-detection", {
  skip_if_not(exists("handle_excel_upload", mode = "function"))

  # Lav en ugyldig "save-fil" hvor Indstillinger-arket eksisterer men er korrupt.
  # parse_spc_excel returnerer NULL for denne, så handle_excel_upload skal
  # falde tilbage til standard data-upload + auto-detection.
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Data")
  openxlsx::writeData(wb, "Data",
    data.frame(Dato = as.Date("2024-01-01") + 0:2, Vaerdi = 1:3))
  openxlsx::addWorksheet(wb, "Indstillinger")
  openxlsx::writeData(wb, "Indstillinger", data.frame(Besked = "kun kommentar"),
    startRow = 1, colNames = FALSE)
  bad_path <- tempfile(fileext = ".xlsx")
  openxlsx::saveWorkbook(wb, bad_path, overwrite = TRUE)

  app_state <- new.env(parent = emptyenv())
  app_state$data <- shiny::reactiveValues(current_data = NULL, original_data = NULL, updating_table = FALSE)
  app_state$session <- shiny::reactiveValues(restoring_session = FALSE, file_uploaded = FALSE)
  app_state$columns <- shiny::reactiveValues(
    mappings = shiny::reactiveValues(),
    auto_detect = shiny::reactiveValues(completed = FALSE)
  )
  app_state$ui <- shiny::reactiveValues(hide_anhoej_rules = TRUE)

  emit_log <- new.env(parent = emptyenv())
  emit_log$data_updated_context <- NULL
  emit <- list(
    data_updated = function(context = NULL, ...) {
      emit_log$data_updated_context <- context
    },
    navigation_changed = function(...) invisible(NULL),
    auto_detection_started = function(...) invisible(NULL),
    visualization_update_needed = function(...) invisible(NULL)
  )

  session <- shiny::MockShinySession$new()
  mockery::stub(
    handle_excel_upload,
    "shiny::showNotification",
    function(...) invisible(NULL)
  )

  shiny::isolate({
    handle_excel_upload(bad_path, session, app_state, emit, ui_service = NULL)
  })

  # Fallback: auto_detect skal NIT være completed, emit skal være file_loaded
  expect_false(shiny::isolate(app_state$columns$auto_detect$completed))
  expect_equal(emit_log$data_updated_context, "file_loaded")
  expect_false(shiny::isolate(app_state$session$restoring_session))
})
