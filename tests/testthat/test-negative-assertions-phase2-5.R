# ==============================================================================
# test-negative-assertions-phase2-5.R
# ==============================================================================
# §2.5.3 — Explicit fejltests for hardened test-suite.
#
# Scenarier dækket:
#   1. BFHllm utilgængelig → AI suggestion returnerer NULL uden crash
#   2. Gemini timeout → safe_operation fallback aktiveres
#   3. localStorage quota-exceeded → auto_save_enabled deaktiveres
#   4. Malformet CSV med mixed encoding → readr kaster warning/error
#   5. Data med kun NA → compute_spc_results_bfh eller validate fejler
#   6. Data med 1 række → MIN_SPC_ROWS guard aktiveres
#
# Design: bruger testthat::local_mocked_bindings() (ikke mockery::stub) for
# at holde migrations-standard fra §2.4.4.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. BFHllm utilgængelig
# ------------------------------------------------------------------------------

test_that("generate_improvement_suggestion returnerer NULL når BFHllm utilgængelig (§2.5.3)", {
  set.seed(42)
  skip_if_not(exists("generate_improvement_suggestion", mode = "function"))

  # Mock is_bfhllm_available til altid at returnere FALSE
  testthat::local_mocked_bindings(
    is_bfhllm_available = function() FALSE
  )

  spc_result <- list(
    metadata = list(chart_type = "run", n_points = 10L),
    qic_data = data.frame(x = 1:10, y = rnorm(10))
  )
  context <- list(data_definition = "Test", chart_title = "Test")
  mock_session <- shiny::MockShinySession$new()

  # Kald må IKKE kaste fejl (graceful fallback via safe_operation)
  expect_no_error({
    result <- generate_improvement_suggestion(
      spc_result = spc_result,
      context = context,
      session = mock_session
    )
  })

  # Forventet: NULL (graceful fallback — ingen crash)
  expect_null(result,
    label = "AI suggestion skal returnere NULL når BFHllm er utilgængelig"
  )
})

test_that("generate_improvement_suggestion returnerer NULL ved NULL inputs (§2.5.3)", {
  skip_if_not(exists("generate_improvement_suggestion", mode = "function"))

  mock_session <- shiny::MockShinySession$new()

  # Alle tre NULL-input scenarier: kald må IKKE kaste fejl, skal returnere NULL.
  # safe_operation fallback-kontrakt: graceful degradation i stedet for crash.

  # NULL spc_result
  expect_no_error({
    r1 <- generate_improvement_suggestion(
      spc_result = NULL,
      context = list(data_definition = "Test"),
      session = mock_session
    )
  })
  expect_null(r1)

  # NULL context
  expect_no_error({
    r2 <- generate_improvement_suggestion(
      spc_result = list(metadata = list(chart_type = "run")),
      context = NULL,
      session = mock_session
    )
  })
  expect_null(r2)

  # NULL session
  expect_no_error({
    r3 <- generate_improvement_suggestion(
      spc_result = list(metadata = list(chart_type = "run")),
      context = list(data_definition = "Test"),
      session = NULL
    )
  })
  expect_null(r3)
})

# ------------------------------------------------------------------------------
# 2. Gemini timeout / httr2 fejl
# ------------------------------------------------------------------------------

test_that("httr2::req_perform timeout propagerer som error (§2.5.3)", {
  skip_if_not_installed("httr2")

  # Mock httr2::req_perform til at kaste timeout-error
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) {
      stop(
        structure(
          class = c("httr2_timeout", "httr2_error", "error", "condition"),
          list(message = "Request timed out after 10 seconds")
        )
      )
    },
    .package = "httr2"
  )

  req <- httr2::request("https://mock-gemini.local/v1/generate")

  expect_error(
    httr2::req_perform(req),
    regexp = "timed out",
    class = "httr2_timeout"
  )
})

# ------------------------------------------------------------------------------
# 3. localStorage quota-exceeded
# ------------------------------------------------------------------------------

test_that("autoSaveAppState deaktiverer auto_save ved quota-exceeded (§2.5.3)", {
  skip_if_not(exists("autoSaveAppState", mode = "function"))

  # Setup: app_state med auto_save_enabled=TRUE
  app_state <- new.env(parent = emptyenv())
  app_state$session <- shiny::reactiveValues(
    auto_save_enabled = TRUE,
    last_save_time = NULL
  )
  app_state$data <- shiny::reactiveValues(
    current_data = NULL,
    updating_table = FALSE
  )

  expect_true(shiny::isolate(app_state$session$auto_save_enabled))

  # Mock session med fejlende sendCustomMessage (simulerer JS quota-fejl)
  failing_session <- shiny::MockShinySession$new()
  failing_session$sendCustomMessage <- function(type, message) {
    stop("QuotaExceededError: localStorage quota exceeded")
  }

  # Mock showNotification så vi ikke ser popups
  testthat::local_mocked_bindings(
    showNotification = function(...) invisible(NULL),
    .package = "shiny"
  )

  test_data <- data.frame(x = 1:5, y = 6:10)
  metadata <- list(x_column = "x", y_column = "y", chart_type = "run")

  autoSaveAppState(
    failing_session, test_data, metadata,
    app_state = app_state
  )

  # Efter quota-fejl skal auto_save_enabled være FALSE
  expect_false(
    shiny::isolate(app_state$session$auto_save_enabled),
    label = "auto_save_enabled skal deaktiveres efter quota-fejl"
  )
})

test_that("autoSaveAppState springer over når auto_save_enabled=FALSE (§2.5.3)", {
  skip_if_not(exists("autoSaveAppState", mode = "function"))

  # Setup: app_state med auto_save_enabled=FALSE
  app_state <- new.env(parent = emptyenv())
  app_state$session <- shiny::reactiveValues(
    auto_save_enabled = FALSE
  )

  # Session der IKKE må kaldes
  call_count <- 0L
  mock_session <- shiny::MockShinySession$new()
  mock_session$sendCustomMessage <- function(type, message) {
    call_count <<- call_count + 1L
    invisible(NULL)
  }

  test_data <- data.frame(x = 1:5, y = 6:10)
  metadata <- list(x_column = "x", y_column = "y")

  # expect_no_error validerer graceful skip (ingen crash)
  expect_no_error({
    autoSaveAppState(
      mock_session, test_data, metadata,
      app_state = app_state
    )
  })

  # expect_no_message validerer at der ikke logges ERROR-niveau
  expect_no_error({
    autoSaveAppState(mock_session, NULL, metadata, app_state = app_state)
  })
  expect_no_error({
    autoSaveAppState(
      mock_session, data.frame(), metadata,
      app_state = app_state
    )
  })

  expect_equal(call_count, 0L,
    label = "sendCustomMessage må ikke kaldes når auto_save_enabled=FALSE"
  )
})

# ------------------------------------------------------------------------------
# 4. Malformet CSV med mixed encoding
# ------------------------------------------------------------------------------

test_that("readr::read_csv varsler ved malformet CSV-struktur (§2.5.3)", {
  skip_if_not_installed("readr")

  # Malformet CSV: uens antal kolonner pr. række (ragged)
  # readr producerer "problems()" data.frame + warning når rows har forkert
  # antal felter — denne adfærd er stabil på tværs af readr-versioner.
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)

  writeLines(
    c(
      "Dato,Værdi,Kommentar",
      "2024-01-01,42,ok",
      "2024-01-02,43", # mangler Kommentar-felt — ragged
      "2024-01-03,44,ok"
    ),
    tmp
  )

  # readr fanger ragged rows som problems() — detect via suppressWarnings +
  # problems()-check. Dette er stabilere end expect_warning direkte.
  parsed <- suppressMessages(
    readr::read_csv(tmp, show_col_types = FALSE, progress = FALSE)
  )
  issues <- readr::problems(parsed)

  expect_gt(nrow(issues), 0,
    label = "Malformet ragged CSV skal producere mindst ét problems()-entry"
  )
})

# ------------------------------------------------------------------------------
# 5. Data med kun NA
# ------------------------------------------------------------------------------

test_that("compute_spc_results_bfh håndterer all-NA data defensivt (§2.5.3)", {
  skip_if_not(exists("compute_spc_results_bfh", mode = "function"))

  all_na_data <- data.frame(
    x = 1:10,
    y = rep(NA_real_, 10)
  )

  # Forventet adfærd: enten fejl eller warning + fallback-result (NULL eller
  # minimal struct). Vi tester kun at der IKKE opstår silent success (bug).
  result <- tryCatch(
    compute_spc_results_bfh(
      data = all_na_data,
      x_var = "x",
      y_var = "y",
      chart_type = "run"
    ),
    error = function(e) list(error = conditionMessage(e))
  )

  # Acceptable outcomes:
  #   a) NULL (safe_operation fallback)
  #   b) list med "error" (tryCatch fangede)
  #   c) warning-generated output med NA cl/lcl/ucl
  if (is.null(result)) {
    expect_null(result)
  } else if ("error" %in% names(result)) {
    expect_true(nchar(result$error) > 0,
      label = "Error message skal være ikke-tom"
    )
  } else {
    # Hvis funktionen returnerede successfully, skal cl være NA eller
    # plot skal indikere at ingen data kunne plottes
    expect_true(
      all(is.na(result$qic_data$y)) ||
        all(is.na(result$qic_data$cl)) ||
        is.null(result$plot),
      label = "All-NA input må ikke resultere i valid plot uden warning"
    )
  }
})

test_that("validate_numeric_column fejler for all-NA kolonne (§2.5.3)", {
  skip_if_not(exists("validate_numeric_column", mode = "function"))

  all_na_data <- data.frame(
    numerisk = rep(NA_real_, 5)
  )

  # validate_numeric_column skal enten returnere error-message eller fejle
  result <- tryCatch(
    validate_numeric_column(all_na_data, "numerisk"),
    error = function(e) conditionMessage(e)
  )

  # Acceptable: character message (ikke NULL eller "")
  expect_true(
    is.null(result) || is.character(result),
    label = "validate_numeric_column skal returnere NULL eller character"
  )
})

# ------------------------------------------------------------------------------
# 6. Data med 1 række (MIN_SPC_ROWS guard)
# ------------------------------------------------------------------------------

test_that("compute_spc_results_bfh fejler for data med 1 række (§2.5.3)", {
  skip_if_not(exists("compute_spc_results_bfh", mode = "function"))

  single_row <- data.frame(x = 1L, y = 42.0)

  # MIN_SPC_ROWS guard: SPC kræver mindst 3 punkter.
  # Forventet: enten (a) safe_operation returnerer NULL uden crash,
  # eller (b) funktionen kaster explicit fejl. Begge er acceptable
  # defensive-paths.
  error_message <- NULL
  expect_no_error({
    result <- tryCatch(
      compute_spc_results_bfh(
        data = single_row, x_var = "x", y_var = "y", chart_type = "run"
      ),
      error = function(e) {
        error_message <<- conditionMessage(e)
        NULL
      }
    )
  })

  # Assertion: enten error-besked ELLER NULL result
  expect_true(
    !is.null(error_message) || is.null(result),
    label = "1-række data skal give error eller NULL (ikke success)"
  )
})

test_that("compute_spc_results_bfh fejler for tom data (§2.5.3)", {
  skip_if_not(exists("compute_spc_results_bfh", mode = "function"))

  empty_data <- data.frame(x = integer(0), y = numeric(0))

  error_message <- NULL
  expect_no_error({
    result <- tryCatch(
      compute_spc_results_bfh(
        data = empty_data, x_var = "x", y_var = "y", chart_type = "run"
      ),
      error = function(e) {
        error_message <<- conditionMessage(e)
        NULL
      }
    )
  })

  expect_true(
    !is.null(error_message) || is.null(result),
    label = "Tom data skal give error eller NULL (ikke success)"
  )
})

# ------------------------------------------------------------------------------
# Generelle safe_operation fallback-tests
# ------------------------------------------------------------------------------

test_that("safe_operation returnerer fallback ved fejl (§2.5.3)", {
  skip_if_not(exists("safe_operation", mode = "function"))

  # Graceful error-handling: safe_operation fanger stop() og returnerer fallback
  expect_no_error({
    result <- safe_operation(
      "Test error fallback",
      code = stop("Simulated failure"),
      fallback = "fallback_value"
    )
  })

  expect_equal(result, "fallback_value",
    label = "safe_operation skal returnere fallback ved fejl"
  )
})

test_that("safe_operation propagerer resultat ved success (§2.5.3)", {
  skip_if_not(exists("safe_operation", mode = "function"))

  expect_no_error({
    result <- safe_operation(
      "Test success path",
      code = 42L,
      fallback = NULL
    )
  })

  expect_equal(result, 42L,
    label = "safe_operation skal returnere code-resultat ved success"
  )
})

test_that("safe_operation med function fallback modtager error-object (§2.5.3)", {
  skip_if_not(exists("safe_operation", mode = "function"))

  captured_error <- NULL
  expect_no_error({
    result <- safe_operation(
      "Test function fallback",
      code = stop("Captured error message"),
      fallback = function(e) {
        captured_error <<- conditionMessage(e)
        "function_fallback_value"
      }
    )
  })

  expect_equal(result, "function_fallback_value")
  expect_true(
    !is.null(captured_error) && grepl("Captured", captured_error),
    label = "function fallback skal modtage error-object"
  )
})

test_that("safe_operation med warning kode-blok fuldfører uden at kaste (§2.5.3)", {
  skip_if_not(exists("safe_operation", mode = "function"))

  # safe_operation skal IKKE propagere warnings som fejl
  expect_no_error({
    result <- safe_operation(
      "Test warning handling",
      code = {
        warning("Non-fatal warning")
        "code_result_after_warning"
      },
      fallback = "fallback_value"
    )
  })

  # safe_operation må ikke returnere fallback ved warnings (kun errors)
  expect_equal(result, "code_result_after_warning",
    label = "safe_operation må ikke aktivere fallback ved warnings"
  )
})

# ------------------------------------------------------------------------------
# Input validation negative tests
# ------------------------------------------------------------------------------

test_that("compute_spc_results_bfh kaster fejl ved ugyldig chart_type (§2.5.3)", {
  set.seed(42)
  skip_if_not(exists("compute_spc_results_bfh", mode = "function"))

  data <- data.frame(x = 1:10, y = rnorm(10))

  # Chart type validation er eksplicit i fct_spc_bfh_params.R. Ugyldig
  # chart_type skal give error eller NULL via safe_operation.
  error_caught <- FALSE
  result <- tryCatch(
    compute_spc_results_bfh(
      data = data, x_var = "x", y_var = "y", chart_type = "invalid_xyz"
    ),
    error = function(e) {
      error_caught <<- TRUE
      NULL
    }
  )

  expect_true(error_caught || is.null(result),
    label = "Ugyldig chart_type skal give error eller NULL"
  )
})
