# test-utils-event-context-handlers.R
# Tests for event context handlers (Phase 5.3, Issue #322)
# Kilde: R/utils_event_context_handlers.R
#
# Tester Strategy Pattern implementationen for context-routing:
#   - classify_update_context(): context → "load"|"table_edit"|"data_change"|"general"|"session_restore"
#   - resolve_column_update_reason(): context → "upload"|"edit"|"session"|"manual"

# ===========================================================================
# classify_update_context — context routing
# ===========================================================================

test_that("classify_update_context eksisterer og er en funktion", {
  expect_true(exists("classify_update_context", mode = "function"))
  expect_type(classify_update_context, "closure")
})

test_that("classify_update_context returnerer 'general' for NULL input", {
  skip_if_not(exists("classify_update_context", mode = "function"))

  expect_equal(classify_update_context(NULL), "general")
  expect_equal(classify_update_context(list(context = NULL)), "general")
  expect_equal(classify_update_context(list()), "general")
})

test_that("classify_update_context returnerer 'table_edit' for table_cells_edited", {
  skip_if_not(exists("classify_update_context", mode = "function"))

  result <- classify_update_context(list(context = "table_cells_edited"))
  expect_equal(result, "table_edit")
})

test_that("classify_update_context returnerer 'session_restore' for session_restore", {
  skip_if_not(exists("classify_update_context", mode = "function"))

  result <- classify_update_context(list(context = "session_restore"))
  expect_equal(result, "session_restore")
})

test_that("classify_update_context returnerer 'load' for upload-relaterede contexts", {
  skip_if_not(exists("classify_update_context", mode = "function"))

  load_contexts <- c("file_upload", "file_loaded", "new_data", "paste_data")

  for (ctx in load_contexts) {
    result <- classify_update_context(list(context = ctx))
    expect_equal(result, "load",
      info = paste("Context", ctx, "skal klassificeres som 'load'")
    )
  }
})

test_that("classify_update_context returnerer 'data_change' for change/edit contexts", {
  skip_if_not(exists("classify_update_context", mode = "function"))

  change_contexts <- c("column_change", "data_edit", "data_modify")

  for (ctx in change_contexts) {
    result <- classify_update_context(list(context = ctx))
    expect_equal(result, "data_change",
      info = paste("Context", ctx, "skal klassificeres som 'data_change'")
    )
  }
})

test_that("classify_update_context returnerer 'general' for ukendte contexts", {
  skip_if_not(exists("classify_update_context", mode = "function"))

  unknown_contexts <- c("unknown_event", "something_random", "xyz")

  for (ctx in unknown_contexts) {
    result <- classify_update_context(list(context = ctx))
    expect_equal(result, "general",
      info = paste("Ukendt context", ctx, "skal falde til 'general'")
    )
  }
})

test_that("classify_update_context udsender warning for ukendt context (#425)", {
  skip_if_not(exists("classify_update_context", mode = "function"))
  skip_if_not(exists("log_warn", mode = "function"))

  # Sikrer at warning udsendes saa nye unknown contexts fanges i logs.
  # Beskytter mod fremtidig regression hvor ny emit-call bruger context-streng
  # der utilsigtet falder til general-grenen (som ej trigger plot-render).
  withr::local_envvar(SPC_LOG_LEVEL = "WARN")

  output <- utils::capture.output(
    res <- classify_update_context(list(context = "calc_refresh"))
  )

  expect_equal(res, "general")
  combined <- paste(output, collapse = " ")
  expect_match(
    combined,
    "calc_refresh",
    info = "Warning skal navngive den ukendte context"
  )
  expect_match(
    combined,
    "EVENT_CONTEXT_HANDLER",
    info = "Warning skal indeholde EVENT_CONTEXT_HANDLER-tag"
  )
})

test_that("classify_update_context udsender IKKE warning for kendte contexts (#425)", {
  skip_if_not(exists("classify_update_context", mode = "function"))
  skip_if_not(exists("log_warn", mode = "function"))

  withr::local_envvar(SPC_LOG_LEVEL = "WARN")

  known_contexts <- c(
    "file_upload", "data_loaded", "paste_data",
    "column_changed", "table_cells_edited", "session_restore"
  )

  for (ctx in known_contexts) {
    output <- utils::capture.output(
      classify_update_context(list(context = ctx))
    )
    combined <- paste(output, collapse = " ")
    expect_false(
      grepl("fald til 'general'", combined, fixed = TRUE),
      info = paste("Kendt context", ctx, "skal IKKE udloese fallback-warning")
    )
  }
})

test_that("classify_update_context returnerer kun gyldige output-værdier", {
  skip_if_not(exists("classify_update_context", mode = "function"))

  valid_outputs <- c("load", "table_edit", "data_change", "general", "session_restore")

  test_inputs <- list(
    NULL,
    list(context = NULL),
    list(context = "file_upload"),
    list(context = "table_cells_edited"),
    list(context = "session_restore"),
    list(context = "column_change"),
    list(context = "xyz_unknown")
  )

  for (input in test_inputs) {
    result <- classify_update_context(input)
    expect_true(result %in% valid_outputs,
      info = paste("classify_update_context skal returnere gyldigt output for", deparse(input))
    )
  }
})

# ===========================================================================
# resolve_column_update_reason — context → reason
# ===========================================================================

test_that("resolve_column_update_reason eksisterer og er en funktion", {
  expect_true(exists("resolve_column_update_reason", mode = "function"))
  expect_type(resolve_column_update_reason, "closure")
})

test_that("resolve_column_update_reason returnerer 'manual' for NULL", {
  skip_if_not(exists("resolve_column_update_reason", mode = "function"))

  expect_equal(resolve_column_update_reason(NULL), "manual")
})

test_that("resolve_column_update_reason returnerer 'edit' for edit-relaterede contexts", {
  skip_if_not(exists("resolve_column_update_reason", mode = "function"))

  edit_contexts <- c("table_cells_edited", "column_change", "data_edit", "data_modify")

  for (ctx in edit_contexts) {
    result <- resolve_column_update_reason(ctx)
    expect_equal(result, "edit",
      info = paste("Context", ctx, "skal give reason 'edit'")
    )
  }
})

test_that("resolve_column_update_reason returnerer 'session' for session contexts", {
  skip_if_not(exists("resolve_column_update_reason", mode = "function"))

  result <- resolve_column_update_reason("session_restore")
  expect_equal(result, "session")
})

test_that("resolve_column_update_reason returnerer 'upload' for load-relaterede contexts", {
  skip_if_not(exists("resolve_column_update_reason", mode = "function"))

  upload_contexts <- c("file_upload", "file_loaded", "new_data")

  for (ctx in upload_contexts) {
    result <- resolve_column_update_reason(ctx)
    expect_equal(result, "upload",
      info = paste("Context", ctx, "skal give reason 'upload'")
    )
  }
})

test_that("resolve_column_update_reason returnerer 'manual' for ukendte contexts", {
  skip_if_not(exists("resolve_column_update_reason", mode = "function"))

  unknown_contexts <- c("unknown_event", "xyz", "something_random")

  for (ctx in unknown_contexts) {
    result <- resolve_column_update_reason(ctx)
    expect_equal(result, "manual",
      info = paste("Ukendt context", ctx, "skal give reason 'manual'")
    )
  }
})

test_that("resolve_column_update_reason returnerer kun gyldige output-værdier", {
  skip_if_not(exists("resolve_column_update_reason", mode = "function"))

  valid_outputs <- c("upload", "edit", "session", "manual")

  test_contexts <- c(
    NULL, "file_upload", "table_cells_edited", "session_restore",
    "column_change", "unknown_xyz"
  )

  for (ctx in test_contexts) {
    result <- resolve_column_update_reason(ctx)
    expect_true(result %in% valid_outputs,
      info = paste("resolve_column_update_reason skal returnere gyldigt output for", deparse(ctx))
    )
  }
})
