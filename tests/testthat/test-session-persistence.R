# test-session-persistence.R
# ==============================================================================
# REGRESSION TEST SUITE: Session Persistence via Browser localStorage
# ==============================================================================
#
# FORMÅL: Dokumentere og beskytte mod kendte bugs i auto-save/auto-restore
#         flowet (Issue #193, OpenSpec change add-session-persistence-autosave).
#
# STRUKTUR:
#   1. JSON single-encoding regression (double-encoding bug)
#   2. autoSaveAppState scope bug (disable on failure)
#   3. Class preservation roundtrip (numeric, character, Date, POSIXct,
#      integer, factor, logical)
#   4. collect_metadata / restore_metadata roundtrip
#   5. Bounds checking (DoS protection)
#   6. Feature flag respect
#
# STATUS: Skrevet FØR fixes i Fase 2-4. Tests der er markeret "Kræver fix"
# forventes at fejle på master indtil de fixes.
#
# Reference: openspec/changes/add-session-persistence-autosave/
# ==============================================================================

library(testthat)
library(shiny)

# HELPER: Mock session der fanger sendCustomMessage kald ====================
create_mock_capture_session <- function() {
  captured <- new.env(parent = emptyenv())
  captured$messages <- list()

  mock_session <- shiny::MockShinySession$new()

  # Override sendCustomMessage to capture calls
  mock_session$sendCustomMessage <- function(type, message) {
    captured$messages <- append(captured$messages, list(list(
      type = type,
      message = message
    )))
    invisible(NULL)
  }

  list(
    session = mock_session,
    captured = captured
  )
}

# HELPER: Minimal app_state med session sub-structure =======================
create_test_app_state <- function(auto_save_enabled = TRUE) {
  app_state <- new.env(parent = emptyenv())
  app_state$session <- shiny::reactiveValues(
    auto_save_enabled = auto_save_enabled,
    restoring_session = FALSE,
    last_save_time = NULL,
    file_uploaded = FALSE
  )
  app_state$data <- shiny::reactiveValues(
    current_data = NULL,
    original_data = NULL,
    updating_table = FALSE,
    table_operation_in_progress = FALSE
  )
  app_state
}

# ==============================================================================
# SECTION 1: JSON Single-Encoding Regression
# ==============================================================================

test_that("saveDataLocally sends single-encoded JSON on R side", {
  skip_if_not(exists("saveDataLocally", mode = "function"),
    "saveDataLocally not available")

  mock <- create_mock_capture_session()
  test_data <- data.frame(
    x = c(1, 2, 3),
    y = c(10, 20, 30),
    stringsAsFactors = FALSE
  )
  metadata <- list(
    x_column = "x",
    y_column = "y",
    chart_type = "run"
  )

  saveDataLocally(mock$session, test_data, metadata)

  expect_length(mock$captured$messages, 1)
  msg <- mock$captured$messages[[1]]
  expect_equal(msg$type, "saveAppState")
  expect_equal(msg$message$key, "current_session")

  # REGRESSION: message$data SKAL være en JSON-string der kan parses med
  # én enkelt fromJSON() kald. Hvis double-encoding rammer, vil første parse
  # returnere en string (den inderste encoded JSON), og vi skal fromJSON igen.
  json_data <- msg$message$data
  expect_true(is.character(json_data) || inherits(json_data, "json"))

  parsed_once <- jsonlite::fromJSON(as.character(json_data), simplifyVector = TRUE)

  # Efter ÉN parse skal vi have en list med "data", "metadata", "timestamp"
  expect_true(is.list(parsed_once),
    info = "Efter én fromJSON() skal resultatet være en list, ikke en string")
  expect_true("metadata" %in% names(parsed_once),
    info = "metadata skal være tilgængelig efter første parse")
  expect_true("timestamp" %in% names(parsed_once),
    info = "timestamp skal være tilgængelig efter første parse")

  # Metadata felter skal være direkte tilgængelige
  expect_equal(parsed_once$metadata$x_column, "x")
  expect_equal(parsed_once$metadata$y_column, "y")
  expect_equal(parsed_once$metadata$chart_type, "run")
})

test_that("local-storage.js saveAppState does NOT double-encode (static check)", {
  # REGRESSION: Browser-side must not call JSON.stringify() on message.data
  # because R's jsonlite::toJSON() already produces a JSON string. Double
  # encoding results in escaped strings that parse incorrectly.
  js_file <- file.path("..", "..", "inst", "app", "www", "local-storage.js")
  skip_if_not(file.exists(js_file), "local-storage.js not found")

  js_content <- readLines(js_file, warn = FALSE)
  js_text <- paste(js_content, collapse = "\n")

  # Find the saveAppState function block
  save_fn_match <- regmatches(
    js_text,
    regexpr("window\\.saveAppState\\s*=\\s*function[^}]+\\}", js_text)
  )

  expect_length(save_fn_match, 1)

  # Post-fix: saveAppState must not call JSON.stringify on its data parameter
  expect_false(
    grepl("JSON\\.stringify\\s*\\(\\s*data\\s*\\)", save_fn_match),
    info = paste0(
      "saveAppState must not call JSON.stringify(data) — R sends ",
      "pre-serialized JSON. Found: ", save_fn_match
    )
  )
})

test_that("local-storage.js loadAppState still parses JSON once (static check)", {
  js_file <- file.path("..", "..", "inst", "app", "www", "local-storage.js")
  skip_if_not(file.exists(js_file), "local-storage.js not found")

  js_text <- paste(readLines(js_file, warn = FALSE), collapse = "\n")

  load_fn_match <- regmatches(
    js_text,
    regexpr("window\\.loadAppState\\s*=\\s*function[^}]+\\}[^}]*\\}", js_text)
  )

  expect_length(load_fn_match, 1)
  expect_true(
    grepl("JSON\\.parse", load_fn_match),
    info = "loadAppState must still call JSON.parse() to deserialize stored data"
  )
})

# ==============================================================================
# SECTION 2: autoSaveAppState scope bug (disable on failure)
# ==============================================================================

test_that("autoSaveAppState accepts app_state parameter and disables auto-save on failure", {
  skip_if_not(exists("autoSaveAppState", mode = "function"),
    "autoSaveAppState not available")

  # Check signature has app_state parameter (post-fix)
  fn_args <- names(formals(autoSaveAppState))
  expect_true("app_state" %in% fn_args,
    info = "autoSaveAppState SKAL acceptere app_state som parameter (Fase 2)")

  # Create state with failing save scenario
  app_state <- create_test_app_state(auto_save_enabled = TRUE)
  expect_true(isolate(app_state$session$auto_save_enabled))

  # Mock session whose sendCustomMessage triggers an error
  failing_session <- shiny::MockShinySession$new()
  failing_session$sendCustomMessage <- function(type, message) {
    stop("Simulated localStorage quota error")
  }

  test_data <- data.frame(x = 1:5, y = 6:10)
  metadata <- list(x_column = "x", y_column = "y", chart_type = "run")

  # Call with explicit app_state
  result <- tryCatch(
    autoSaveAppState(failing_session, test_data, metadata, app_state = app_state),
    error = function(e) e
  )

  # Auto-save SKAL være disabled efter fejl
  expect_false(isolate(app_state$session$auto_save_enabled),
    info = "auto_save_enabled skal være FALSE efter save-fejl")
})

test_that("autoSaveAppState skips when auto_save_enabled is FALSE", {
  skip_if_not(exists("autoSaveAppState", mode = "function"),
    "autoSaveAppState not available")
  skip_if_not("app_state" %in% names(formals(autoSaveAppState)),
    "autoSaveAppState has no app_state parameter yet")

  app_state <- create_test_app_state(auto_save_enabled = FALSE)
  mock <- create_mock_capture_session()

  test_data <- data.frame(x = 1:3, y = 4:6)
  metadata <- list(x_column = "x", y_column = "y")

  autoSaveAppState(mock$session, test_data, metadata, app_state = app_state)

  # Ingen sendCustomMessage kald skal være foretaget
  expect_length(mock$captured$messages, 0)
})

# ==============================================================================
# SECTION 3: Class Preservation Roundtrip
# ==============================================================================

# HELPER: Simuler roundtrip via ekstraktion → JSON → parsing → rekonstruktion
# NB: jsonlite serialiserer R NA til JSON null, som parses tilbage til R NULL
# i list-elementer. Vi skal eksplicit konvertere NULL → NA før rekonstruktion.
simulate_roundtrip <- function(data) {
  skip_if_not(exists("extract_class_info", mode = "function"),
    "extract_class_info not yet implemented (Fase 3)")
  skip_if_not(exists("restore_column_class", mode = "function"),
    "restore_column_class not yet implemented (Fase 3)")

  class_info <- extract_class_info(data)

  # Serialize values (same as saveDataLocally)
  data_to_save <- list(
    values = lapply(data, as.vector),
    col_names = colnames(data),
    nrows = nrow(data),
    ncols = ncol(data),
    class_info = class_info
  )

  # JSON roundtrip (same pipeline as real app)
  json_str <- jsonlite::toJSON(data_to_save, auto_unbox = TRUE, digits = NA, na = "null")
  reloaded <- jsonlite::fromJSON(json_str, simplifyVector = FALSE)

  # Rekonstruer data.frame
  reconstructed <- data.frame(
    matrix(nrow = reloaded$nrows, ncol = reloaded$ncols),
    stringsAsFactors = FALSE
  )
  names(reconstructed) <- unlist(reloaded$col_names)

  # Helper: konverter list med NULLs til vector med NAs (bevar længde)
  # NB: vapply kan ikke bruges her da FUN.VALUE kræver en fast type, men
  # kolonner kan være numeric/character/integer — brug lapply + unlist i stedet
  list_to_vector_with_na <- function(lst) {
    cleaned <- lapply(lst, function(x) if (is.null(x)) NA else x)
    unlist(cleaned, use.names = FALSE)
  }

  for (i in seq_along(reloaded$values)) {
    col_name <- names(reconstructed)[i]
    raw_values <- list_to_vector_with_na(reloaded$values[[i]])
    reconstructed[[i]] <- restore_column_class(
      raw_values,
      class_info = reloaded$class_info[[col_name]]
    )
  }

  reconstructed
}

test_that("Roundtrip preserves numeric columns", {
  original <- data.frame(
    a = c(1.5, 2.7, 3.14, NA, 0),
    stringsAsFactors = FALSE
  )
  result <- simulate_roundtrip(original)

  expect_true(is.numeric(result$a))
  expect_equal(result$a, original$a, tolerance = 1e-10)
})

test_that("Roundtrip preserves character columns", {
  original <- data.frame(
    s = c("abc", "æøå", "", NA_character_, "med mellemrum"),
    stringsAsFactors = FALSE
  )
  result <- simulate_roundtrip(original)

  expect_true(is.character(result$s))
  expect_equal(result$s, original$s)
})

test_that("Roundtrip preserves logical columns", {
  original <- data.frame(
    flag = c(TRUE, FALSE, NA, TRUE, FALSE),
    stringsAsFactors = FALSE
  )
  result <- simulate_roundtrip(original)

  expect_true(is.logical(result$flag))
  expect_equal(result$flag, original$flag)
})

test_that("Roundtrip preserves Date columns (Fase 3)", {
  original <- data.frame(
    dato = as.Date(c("2026-01-15", "2026-02-28", "2026-03-31", NA)),
    stringsAsFactors = FALSE
  )
  result <- simulate_roundtrip(original)

  expect_true(inherits(result$dato, "Date"),
    info = "Dato-kolonne skal bevare Date-klasse efter roundtrip")
  expect_equal(result$dato, original$dato)
})

test_that("Roundtrip preserves POSIXct columns with timezone (Fase 3)", {
  original <- data.frame(
    ts = as.POSIXct(c("2026-01-15 10:30:00", "2026-02-28 15:45:00"),
      tz = "Europe/Copenhagen"),
    stringsAsFactors = FALSE
  )
  result <- simulate_roundtrip(original)

  expect_true(inherits(result$ts, "POSIXct"),
    info = "Timestamp-kolonne skal bevare POSIXct-klasse efter roundtrip")
  expect_equal(attr(result$ts, "tzone"), "Europe/Copenhagen",
    info = "Tidszone-attribut skal bevares")
  expect_equal(result$ts, original$ts)
})

test_that("Roundtrip preserves integer columns (Fase 3)", {
  original <- data.frame(
    n = c(1L, 2L, 3L, NA_integer_, 42L),
    stringsAsFactors = FALSE
  )
  result <- simulate_roundtrip(original)

  expect_true(is.integer(result$n),
    info = "Integer-kolonne skal IKKE konverteres til numeric")
  expect_equal(result$n, original$n)
})

test_that("Roundtrip preserves factor columns with levels (Fase 3)", {
  original <- data.frame(
    kat = factor(c("Low", "High", "Medium", "Low"),
      levels = c("Low", "Medium", "High")),
    stringsAsFactors = FALSE
  )
  result <- simulate_roundtrip(original)

  expect_true(is.factor(result$kat),
    info = "Factor-kolonne skal bevare factor-klasse efter roundtrip")
  expect_equal(levels(result$kat), c("Low", "Medium", "High"),
    info = "Levels skal bevare rækkefølge")
  expect_equal(as.character(result$kat), as.character(original$kat))
})

# ==============================================================================
# SECTION 4: Metadata Roundtrip
# ==============================================================================

test_that("collect_metadata captures all form fields including active_tab", {
  skip_if_not(exists("collect_metadata", mode = "function"),
    "collect_metadata not available")

  mock_input <- list(
    x_column = "Dato",
    y_column = "T\u00e6ller",
    n_column = "N\u00e6vner",
    skift_column = "Skift",
    frys_column = "Frys",
    kommentar_column = "Kommentar",
    chart_type = "pp",
    target_value = "0.95",
    centerline_value = "0.90",
    y_axis_unit = "percent",
    indicator_title = "Patientfremm\u00f8de",
    indicator_description = "Procent m\u00f8dt ud af tilkaldte",
    main_navbar = "analyser"
  )

  # shiny::isolate wrapper in collect_metadata requires a reactive context —
  # we simulate by passing mock_input directly
  metadata <- isolate(collect_metadata(mock_input))

  expect_equal(metadata$x_column, "Dato")
  expect_equal(metadata$y_column, "T\u00e6ller")
  expect_equal(metadata$n_column, "N\u00e6vner")
  expect_equal(metadata$skift_column, "Skift")
  expect_equal(metadata$frys_column, "Frys")
  expect_equal(metadata$kommentar_column, "Kommentar")
  expect_equal(metadata$chart_type, "pp")
  expect_equal(metadata$target_value, "0.95")
  expect_equal(metadata$centerline_value, "0.90")
  expect_equal(metadata$y_axis_unit, "percent")
  expect_equal(metadata$indicator_title, "Patientfremm\u00f8de")
  expect_equal(metadata$indicator_description, "Procent m\u00f8dt ud af tilkaldte")
  expect_equal(metadata$active_tab, "analyser")
})

test_that("collect_metadata falls back to 'analyser' when main_navbar is NULL", {
  skip_if_not(exists("collect_metadata", mode = "function"),
    "collect_metadata not available")

  mock_input <- list(
    x_column = "",
    y_column = "",
    n_column = "",
    skift_column = "",
    frys_column = "",
    kommentar_column = "",
    chart_type = "run",
    target_value = NULL,
    centerline_value = NULL,
    y_axis_unit = NULL,
    indicator_title = NULL,
    indicator_description = NULL,
    main_navbar = NULL
  )

  metadata <- isolate(collect_metadata(mock_input))
  expect_equal(metadata$active_tab, "analyser",
    info = "active_tab skal defaulte til 'analyser' ved NULL (ikke 'start')")
})

test_that("collect_metadata handles empty/NULL fields gracefully", {
  skip_if_not(exists("collect_metadata", mode = "function"),
    "collect_metadata not available")

  mock_input <- list(
    x_column = NULL,
    y_column = "",
    n_column = "n",
    skift_column = NULL,
    frys_column = "",
    kommentar_column = "k",
    chart_type = "run",
    target_value = NULL,
    centerline_value = "",
    y_axis_unit = NULL
  )

  metadata <- isolate(collect_metadata(mock_input))

  expect_equal(metadata$x_column, "")
  expect_equal(metadata$y_column, "")
  expect_equal(metadata$n_column, "n")
  expect_equal(metadata$skift_column, "")
  expect_equal(metadata$frys_column, "")
  expect_equal(metadata$kommentar_column, "k")
  expect_equal(metadata$chart_type, "run")
  expect_equal(metadata$y_axis_unit, "count")  # Default fallback
})

# ==============================================================================
# SECTION 5: Bounds Checking (DoS Protection)
# ==============================================================================

test_that("Restore rejects payloads exceeding row limit", {
  skip("Restore bounds-check kræver integration test — dækkes i Fase 3 tasks")
  # Denne test placeres som placeholder og aktiveres når restore-logikken
  # er refaktoreret til en testbar helper-funktion i Fase 3.
})

test_that("Save skips oversized datasets", {
  skip_if_not(exists("autoSaveAppState", mode = "function"),
    "autoSaveAppState not available")
  skip_if_not("app_state" %in% names(formals(autoSaveAppState)),
    "autoSaveAppState has no app_state parameter yet")

  app_state <- create_test_app_state(auto_save_enabled = TRUE)
  mock <- create_mock_capture_session()

  # Lav et datasæt der overstiger 1 MB grænsen
  # ~100k rækker × 10 kolonner × ~10 bytes ≈ 10 MB
  large_data <- as.data.frame(
    matrix(rnorm(100000 * 10), nrow = 100000, ncol = 10)
  )

  metadata <- list(x_column = "V1", y_column = "V2")

  # Mock showNotification — MockShinySession supports ikke sendNotification
  notifications <- list()
  mockery::stub(
    autoSaveAppState,
    "shiny::showNotification",
    function(ui, type = NULL, duration = NULL, ...) {
      notifications[[length(notifications) + 1]] <<- list(
        ui = ui, type = type, duration = duration
      )
      invisible(NULL)
    }
  )

  autoSaveAppState(mock$session, large_data, metadata, app_state = app_state)

  # Ingen save skal være foretaget (data for stort)
  expect_length(mock$captured$messages, 0)
  # auto_save_enabled forbliver TRUE (fejl ikke persistent)
  expect_true(isolate(app_state$session$auto_save_enabled))
})

# ==============================================================================
# SECTION 6: Version Check
# ==============================================================================

test_that("Feature flag getters return sensible defaults", {
  skip_if_not(exists("get_auto_save_enabled", mode = "function"),
    "get_auto_save_enabled not available")
  skip_if_not(exists("get_save_interval_ms", mode = "function"),
    "get_save_interval_ms not available")
  skip_if_not(exists("get_settings_save_interval_ms", mode = "function"),
    "get_settings_save_interval_ms not available")

  # Default-værdier skal være sensible når pakke-miljø er tomt
  expect_true(is.logical(get_auto_save_enabled()))
  expect_true(is.numeric(get_save_interval_ms()))
  expect_true(is.numeric(get_settings_save_interval_ms()))
  expect_gt(get_save_interval_ms(), 0)
  expect_gt(get_settings_save_interval_ms(), 0)
})

test_that("get_session_config returns list with all required fields", {
  skip_if_not(exists("get_session_config", mode = "function"),
    "get_session_config not available")

  cfg <- get_session_config()
  expect_type(cfg, "list")
  expect_true(all(c("auto_save_enabled", "auto_restore_session",
    "save_interval_ms", "settings_save_interval_ms") %in% names(cfg)))
  expect_true(is.logical(cfg$auto_save_enabled))
  expect_true(is.logical(cfg$auto_restore_session))
  expect_true(is.numeric(cfg$save_interval_ms))
})

test_that("determine_auto_restore_setting is removed (single source of truth)", {
  # Issue #193: determine_auto_restore_setting blev slettet for at undgå
  # parallelle config-paths. Feature flag læses nu kun fra golem-config.yml
  expect_false(exists("determine_auto_restore_setting", mode = "function"),
    info = "determine_auto_restore_setting skal være slettet (Fase 4)")
})

test_that("saveDataLocally payload uses current version tag", {
  skip_if_not(exists("saveDataLocally", mode = "function"),
    "saveDataLocally not available")

  mock <- create_mock_capture_session()
  test_data <- data.frame(a = 1:3, b = 4:6)

  saveDataLocally(mock$session, test_data, metadata = NULL)

  expect_length(mock$captured$messages, 1)
  json_str <- as.character(mock$captured$messages[[1]]$message$data)
  parsed <- jsonlite::fromJSON(json_str, simplifyVector = TRUE)

  expect_true("version" %in% names(parsed))
  # Schema versioner: "1.2" (legacy), "2.0" (Fase 3), "3.0" (time-yaxis Fase 2b).
  # Test accepterer alle kendte versioner for robusthed mod fremtidige bumps.
  expect_true(parsed$version %in% c("1.2", "2.0", "3.0"),
    info = paste("Unknown payload version:", parsed$version))
})
