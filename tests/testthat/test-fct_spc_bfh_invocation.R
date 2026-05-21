# test-fct_spc_bfh_invocation.R
# Direct contract tests for the BFHcharts invocation boundary.

minimal_bfh_params <- function() {
  list(
    data = data.frame(Date = as.Date("2024-01-01") + 0:2, Count = c(10, 11, 12)),
    x = "Date",
    y = "Count",
    chart_type = "run"
  )
}

capture_error <- function(expr) {
  tryCatch(
    {
      force(expr)
      NULL
    },
    error = identity
  )
}

test_that("call_bfh_chart rejects null or non-list parameters with typed render error", {
  require_internal("call_bfh_chart", mode = "function")

  expect_error(call_bfh_chart(NULL), class = "spc_render_error")
  expect_error(call_bfh_chart("not a list"), class = "spc_render_error")
})

test_that("call_bfh_chart reports missing required parameters", {
  require_internal("call_bfh_chart", mode = "function")

  err <- capture_error(call_bfh_chart(list(data = data.frame(x = 1), x = "x")))

  expect_s3_class(err, "spc_render_error")
  expect_match(conditionMessage(err), "Missing required parameters")
  expect_equal(err$details$missing_keys, c("y", "chart_type"))
})

test_that("call_bfh_chart filters unsupported fields before BFHcharts invocation", {
  skip_if_not_installed("BFHcharts")
  require_internal("call_bfh_chart", mode = "function")

  captured <- NULL
  params <- c(
    minimal_bfh_params(),
    list(
      n = NULL,
      target_value = 12,
      y_axis_unit = "count",
      width = 10,
      height = 6,
      unsupported_field = "do not pass",
      plot_context = list(width_px = 1200)
    )
  )

  with_mocked_bindings(
    bfh_qic = function(...) {
      captured <<- list(...)
      structure(list(qic_data = data.frame(x = 1), plot = NULL), class = "bfh_qic_result")
    },
    is_bfh_qic_result = function(x) inherits(x, "bfh_qic_result"),
    .package = "BFHcharts",
    code = {
      result <- call_bfh_chart(params)
    }
  )

  expect_s3_class(result, "bfh_qic_result")
  expect_true("target_value" %in% names(captured))
  expect_true("y_axis_unit" %in% names(captured))
  expect_true("width" %in% names(captured))
  expect_false("unsupported_field" %in% names(captured))
  expect_false("plot_context" %in% names(captured))
})

test_that("call_bfh_chart wraps non-spc BFHcharts errors as typed render errors", {
  skip_if_not_installed("BFHcharts")
  require_internal("call_bfh_chart", mode = "function")

  with_mocked_bindings(
    bfh_qic = function(...) stop("low-level BFH failure", call. = FALSE),
    .package = "BFHcharts",
    code = {
      err <- capture_error(call_bfh_chart(minimal_bfh_params()))
    }
  )

  expect_s3_class(err, "spc_render_error")
  expect_match(conditionMessage(err), "BFHcharts rendering fejlede")
  expect_equal(err$details$original_class, "simpleError")
  expect_equal(err$details$chart_type, "run")
})

test_that(".safe_col_class haandterer ugyldige col-references uden crash", {
  require_internal(".safe_col_class", mode = "function")
  df <- data.frame(a = 1:3, b = letters[1:3])

  expect_equal(.safe_col_class(df, "a"), "integer")
  expect_equal(.safe_col_class(df, "b"), class(df$b)[1])
  expect_equal(.safe_col_class(df, NULL), "<NULL>")
  expect_match(.safe_col_class(df, c("a", "b")), "<INVALID_COL_NAME: length=2>")
  expect_match(.safe_col_class(df, rep("a", 24)), "<INVALID_COL_NAME: length=24>")
  expect_match(.safe_col_class(df, "missing"), "<MISSING_COL: missing>")
})

test_that("call_bfh_chart logging ej partial-matcher notes til n via $-operator", {
  skip_if_not_installed("BFHcharts")
  require_internal("call_bfh_chart", mode = "function")

  # Root-cause for cycle 11 COLLAPSE_ERROR: bfh_params indeholder "notes" men
  # IKKE "n". R's $-operator partial-matcher "n" -> "notes" og returnerer
  # notes-vektoren (length nrow), hvilket trigger log_debug-fejl. Fix bruger
  # [["n"]] som er strict (NULL ved manglende key).
  notes_only_params <- c(
    minimal_bfh_params(),
    list(notes = c("", "", "Kompleks patient", "Ny teknik"))
  )

  # Capture log-messages via mocked log_debug
  captured_msgs <- character(0)
  local_mocked_bindings(
    log_debug = function(..., .context = NULL) {
      msg <- paste(..., collapse = " ")
      captured_msgs <<- c(captured_msgs, msg)
      invisible(NULL)
    }
  )

  with_mocked_bindings(
    bfh_qic = function(...) {
      structure(list(qic_data = data.frame(x = 1), plot = NULL),
        class = "bfh_qic_result"
      )
    },
    is_bfh_qic_result = function(x) inherits(x, "bfh_qic_result"),
    .package = "BFHcharts",
    code = {
      result <- call_bfh_chart(notes_only_params)
    }
  )

  expect_s3_class(result, "bfh_qic_result")
  # Verificer at "BFHcharts data types"-log IKKE rapporterer n via partial-match.
  # Pre-fix: log indeholdt "n(,,Kompleks...)=<INVALID_COL_NAME: length=4>".
  # Post-fix: log ender efter y-class uden n-segment.
  data_types_msg <- captured_msgs[grepl("BFHcharts data types", captured_msgs)]
  expect_length(data_types_msg, 1)
  expect_false(grepl("INVALID_COL_NAME", data_types_msg))
  expect_false(grepl("Kompleks patient", data_types_msg))
})

test_that("call_bfh_chart logging survives malformed n parameter (root-cause exposed)", {
  skip_if_not_installed("BFHcharts")
  require_internal("call_bfh_chart", mode = "function")

  # Simulerer opstroems bug: bfh_params$n er en row-vektor (length > 1)
  # i stedet for et single-symbol. Tidligere kastede log_debug-build en
  # tibble subscript-fejl der blev fanget af .safe_collapse og rapporteret
  # som <COLLAPSE_ERROR: ...> — maskerede ægte rendering-fejl.
  malformed_params <- c(
    minimal_bfh_params(),
    list(n = as.character(1:24))
  )

  with_mocked_bindings(
    bfh_qic = function(...) {
      structure(list(qic_data = data.frame(x = 1), plot = NULL),
        class = "bfh_qic_result"
      )
    },
    is_bfh_qic_result = function(x) inherits(x, "bfh_qic_result"),
    .package = "BFHcharts",
    code = {
      # Forventning: ingen crash, logging fanger length-24 og rapporterer
      # <INVALID_COL_NAME: length=24> uden at brake call_bfh_chart-flow.
      result <- call_bfh_chart(malformed_params)
    }
  )

  expect_s3_class(result, "bfh_qic_result")
})
