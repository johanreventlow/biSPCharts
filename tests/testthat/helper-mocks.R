# ==============================================================================
# helper-mocks.R
# ==============================================================================
# §2.4.1 — Kanoniske mocks for tunge eksterne dependencies.
#
# Alle mocks har samme formals() som den reelle API — kontrakttest i
# test-helper-mocks-contracts.R fanger drift ved API-ændringer.
#
# Brug med testthat::local_mocked_bindings():
#
#   test_that("feature works", {
#     testthat::local_mocked_bindings(
#       bfhllm_spc_suggestion = mock_bfhllm_spc_suggestion,
#       .package = "BFHllm"
#     )
#     # ... test ...
#   })
#
# ==============================================================================

# ------------------------------------------------------------------------------
# BFHllm mocks
# ------------------------------------------------------------------------------

#' Mock for BFHllm::bfhllm_spc_suggestion
#'
#' Returnerer fast, kort suggestion-tekst uden LLM-kald.
#' formals() matcher BFHllm::bfhllm_spc_suggestion (version 0.1.1+).
mock_bfhllm_spc_suggestion <- function(spc_result, context, min_chars = 300,
                                       max_chars = 375, use_rag = TRUE,
                                       cache = NULL, ...) {
  paste0(
    "Mock AI-forslag: Processen viser stabilitet inden for kontrolgrænserne. ",
    "Overvej at fortsætte nuværende praksis og overvåge udviklingen. ",
    "Dette mock-output har formålet at teste integration uden LLM-kald."
  )
}

# ------------------------------------------------------------------------------
# BFHcharts mocks
# ------------------------------------------------------------------------------

#' Mock for BFHcharts::bfh_qic
#'
#' Returnerer minimal bfh_qic_result-struktur uden ggplot-rendering.
#' formals() matcher den installerede BFHcharts::bfh_qic-version.
#'
#' Kontrakt-paritet med BFHcharts >= 0.15.0 (#490):
#' - $qic_data (ej $data) — laesest af `transform_bfh_output()`
#' - $summary med decomposed signal-kolonner (anhoej_signal, runs_signal,
#'   crossings_signal, centerlinje) — erstatter legacy
#'   summary$loebelaengde_signal
#' - $config med y_axis_unit
#' - S3-class "bfh_qic_result" saa S3-dispatch virker
#' - Anhoej-rule-kolonner i qic_data (anhoej.signal, runs.signal,
#'   sigma.signal, n.crossings, n.crossings.min, longest.run,
#'   longest.run.max) — alle NA-defaults; tests kan overrides via
#'   constructor-parametre.
mock_bfh_qic <- function(data, x, y, n = NULL, chart_type = "run",
                         y_axis_unit = NULL, chart_title = NULL,
                         target_value = NULL, target_text = NULL,
                         notes = NULL, part = NULL, freeze = NULL,
                         exclude = NULL, cl = NULL, multiply = NULL,
                         agg.fun = "mean", base_size = 12,
                         width = NULL, height = NULL, units = "in",
                         dpi = 96, plot_margin = NULL,
                         ylab = NULL, xlab = NULL,
                         subtitle = NULL, caption = NULL,
                         return.data = FALSE, print.summary = FALSE,
                         language = "da") {
  n_rows <- nrow(data)
  cl_value <- if (!is.null(cl)) {
    cl
  } else {
    mean(as.numeric(data[[y]]), na.rm = TRUE)
  }

  qic_data <- data.frame(
    x = seq_len(n_rows),
    y = as.numeric(data[[y]]),
    cl = rep(cl_value, n_rows),
    lcl = rep(NA_real_, n_rows),
    ucl = rep(NA_real_, n_rows),
    # Anhoej-rule-kolonner (BFHcharts 0.15.0 contract)
    anhoej.signal = rep(FALSE, n_rows),
    runs.signal = rep(FALSE, n_rows),
    sigma.signal = rep(FALSE, n_rows),
    n.crossings = rep(NA_real_, n_rows),
    n.crossings.min = rep(NA_real_, n_rows),
    longest.run = rep(NA_real_, n_rows),
    longest.run.max = rep(NA_real_, n_rows),
    part = if (!is.null(part) && part %in% names(data)) {
      as.factor(data[[part]])
    } else {
      factor(rep(1L, n_rows))
    }
  )

  # signal-kolonne aliaserer anhoej.signal saa downstream-kald
  # (transform_bfh_output) er glade ved enten `signal` eller `anhoej.signal`.
  qic_data$signal <- qic_data$anhoej.signal

  # Summary per part — decomposed signaler matcher BFHcharts 0.15.0
  parts_levels <- levels(qic_data$part)
  summary_df <- data.frame(
    part = parts_levels,
    centerlinje = rep(cl_value, length(parts_levels)),
    runs_signal = rep(FALSE, length(parts_levels)),
    crossings_signal = rep(FALSE, length(parts_levels)),
    anhoej_signal = rep(FALSE, length(parts_levels))
  )

  result <- list(
    plot = ggplot2::ggplot(data.frame(x = 1:3, y = 1:3)) +
      ggplot2::geom_point(ggplot2::aes(x = x, y = y)) +
      ggplot2::labs(title = chart_title %||% "Mock SPC Chart"),
    qic_data = qic_data,
    summary = summary_df,
    config = list(
      y_axis_unit = y_axis_unit,
      chart_type = chart_type,
      chart_title = chart_title
    )
  )
  class(result) <- "bfh_qic_result"
  result
}

if (requireNamespace("BFHcharts", quietly = TRUE)) {
  # Drop mock-formals that real bfh_qic no longer exposes, so the
  # contract-test (`expect_setequal(mock_args, real_args)`) survives upstream
  # API trimming without per-arg test changes. Mock body never references
  # these legacy args, so removing them is safe.
  real_bfh_qic_args <- names(formals(BFHcharts::bfh_qic))
  mock_bfh_qic_formals <- formals(mock_bfh_qic)
  legacy_args <- setdiff(names(mock_bfh_qic_formals), real_bfh_qic_args)
  for (arg in legacy_args) {
    mock_bfh_qic_formals[[arg]] <- NULL
  }
  if (length(legacy_args) > 0) {
    formals(mock_bfh_qic) <- mock_bfh_qic_formals
  }
  rm(real_bfh_qic_args, mock_bfh_qic_formals, legacy_args)
}

# ------------------------------------------------------------------------------
# pins mocks
# ------------------------------------------------------------------------------

#' Mock for pins::board_connect
#'
#' Returnerer minimal board-liste uden netværkskald.
#' formals() matcher pins::board_connect (pins 1.4.1+).
mock_board_connect <- function(auth = c("auto", "manual", "envvar"),
                               server = NULL, account = NULL, key = NULL,
                               cache = NULL, name = "connect",
                               versioned = TRUE, use_cache_on_failure = FALSE) {
  structure(
    list(
      name = name,
      url = server %||% "https://mock-connect.local",
      auth = match.arg(auth),
      is_mock = TRUE
    ),
    class = c("pins_board_connect", "pins_board")
  )
}

# ------------------------------------------------------------------------------
# gert mocks
# ------------------------------------------------------------------------------

#' Mock for gert::git_clone
#'
#' Returnerer path uden faktisk git-clone.
#' formals() matcher gert::git_clone (gert 2.1.5+).
mock_git_clone <- function(url, path = NULL, branch = NULL, password = NULL,
                           ssh_key = NULL, bare = FALSE, mirror = FALSE,
                           verbose = interactive()) {
  path <- path %||% tempfile("mock-clone-")
  if (!dir.exists(path)) dir.create(path, recursive = TRUE)
  invisible(path)
}

#' Mock for gert::git_commit
#'
#' Returnerer fast commit-hash uden git-operation.
#' formals() matcher gert::git_commit (gert 2.1.5+).
mock_git_commit <- function(message, author = NULL, committer = NULL,
                            repo = ".") {
  # Fast fake commit-hash til reproducerbare tests
  "mock000000000000000000000000000000000000"
}

# ------------------------------------------------------------------------------
# httr2 / Gemini mocks
# ------------------------------------------------------------------------------

#' Mock for httr2::req_perform
#'
#' Returnerer succesfuld mock-response uden netværkskald.
#' formals() matcher httr2::req_perform (httr2 1.2.1+).
mock_req_perform <- function(req, path = NULL, verbosity = NULL, mock = NULL,
                             error_call = rlang::caller_env()) {
  # Minimal mock-response-struktur
  structure(
    list(
      url = "https://mock-gemini.local/v1/generate",
      status_code = 200L,
      headers = list("content-type" = "application/json"),
      body = charToRaw(
        '{"candidates":[{"content":{"parts":[{"text":"Mock Gemini response"}]}}]}'
      ),
      is_mock = TRUE
    ),
    class = "httr2_response"
  )
}

# ------------------------------------------------------------------------------
# Shiny input$local_storage_* message mocks
# ------------------------------------------------------------------------------

#' Mock local_storage_peek_result for testServer
#'
#' Returnerer struktur matchende inst/app/www/local-storage.js format.
#' Bruges i testServer via session$setInputs(local_storage_peek_result = ...).
mock_local_storage_peek_result <- function(has_payload = FALSE,
                                           timestamp = NULL,
                                           nrows = NULL, ncols = NULL,
                                           schema_version = "2.0") {
  result <- list(
    has_payload = has_payload,
    schema_version = schema_version
  )
  if (has_payload) {
    result$timestamp <- timestamp %||% format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    result$nrows <- nrows %||% 10L
    result$ncols <- ncols %||% 3L
  }
  result
}

#' Mock local_storage_save_result for testServer
#'
#' Simulerer saveDataLocally success/failure response fra JS.
mock_local_storage_save_result <- function(success = TRUE,
                                           error_type = NULL,
                                           message = NULL) {
  list(
    success = success,
    error_type = error_type %||% if (success) NULL else "QuotaExceededError",
    message = message %||% if (success) "Saved" else "localStorage quota exceeded",
    timestamp = as.numeric(Sys.time()) * 1000
  )
}
