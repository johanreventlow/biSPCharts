# test-navigation-no-double-emit.R
# Cycle B M2 (Codex 2026-05-09): regression-test for double-emit
# navigation_changed fra file-load-paths.
#
# Pre-fix: fct_file_operations.R emitter baade data_updated("file_loaded")
# OG direct emit$navigation_changed() umiddelbart efter. Det forarsagede
# pre-autodetect render med stale columns + andet render efter UI-sync
# (visible glitch).
#
# Post-fix: kun data_updated emit; cascade fyrer navigation_changed via
# auto_detection_completed -> ui_sync_completed.
#
# Cycle F M3 (Codex 2026-05-09): Konverteret fra readLines(test_path(...))
# til body()-introspection. Tidligere version brugte source-tree-read med
# skip_if_not-cover -> silent-skip i R CMD check, false confidence i CI.
# body()-introspection virker BAADE i devtools::test og R CMD check.

# Hjaelper: serialise function-body til string for grep-baseret pattern-check
body_text <- function(fn) {
  paste(deparse(body(fn)), collapse = "\n")
}

# Fanger kontekstuel double-emit: navigation_changed-kald i kort afstand
# (max ~200 tegn) efter et data_updated-kald i samme function-body.
# Emitter altid expect_true paa fundet data_updated-pattern saa testthat
# ej rapporterer "empty test" naar nav_pos er tom.
check_no_navigation_after_data_updated <- function(fn_text, fn_name) {
  data_pos <- gregexpr("emit\\$data_updated", fn_text)[[1]]
  nav_pos <- gregexpr("emit\\$navigation_changed", fn_text)[[1]]
  expect_true(
    data_pos[1] != -1,
    info = sprintf("Function '%s' forventet at indeholde emit$data_updated", fn_name)
  )
  if (nav_pos[1] == -1) {
    expect_true(TRUE,
      info = sprintf("Function '%s': ingen navigation_changed-emits (OK)", fn_name)
    )
    return(invisible(TRUE))
  }
  for (du_pos in data_pos) {
    nearby <- nav_pos[nav_pos > du_pos & nav_pos < du_pos + 200]
    expect_length(
      nearby, 0,
      info = sprintf(
        paste(
          "Function '%s' emitter data_updated paa pos %d med nearby",
          "navigation_changed paa pos(er) %s (double-emit-pattern).",
          "Cycle B M2: cascade fyrer navigation via ui_sync_completed."
        ),
        fn_name, du_pos, paste(nearby, collapse = ", ")
      )
    )
  }
  invisible(TRUE)
}

test_that("handle_excel_upload har ikke direct emit$navigation_changed efter data_updated", {
  require_internal("handle_excel_upload", mode = "function")
  check_no_navigation_after_data_updated(
    body_text(handle_excel_upload), "handle_excel_upload"
  )
})

test_that("handle_csv_upload har ikke direct emit$navigation_changed efter data_updated", {
  require_internal("handle_csv_upload", mode = "function")
  check_no_navigation_after_data_updated(
    body_text(handle_csv_upload), "handle_csv_upload"
  )
})

test_that("handle_paste_data har ikke direct emit$navigation_changed efter data_updated", {
  require_internal("handle_paste_data", mode = "function")
  check_no_navigation_after_data_updated(
    body_text(handle_paste_data), "handle_paste_data"
  )
})

test_that("file-load contexts (file_loaded, session_file_loaded, paste_data) er klassificeret korrekt", {
  # Verificer at classify_update_context routes load-contexts til 'load'-class
  # som handle_load_context derefter trigger autodetect_started -> cascade
  require_internal("classify_update_context", mode = "function")

  load_contexts <- c("file_loaded", "session_file_loaded", "paste_data")
  for (ctx in load_contexts) {
    result <- classify_update_context(list(context = ctx))
    expect_equal(
      result, "load",
      info = sprintf(
        paste(
          "Context '%s' burde route til 'load'-class.",
          "Hvis nej, cascade kan miste navigation_changed."
        ),
        ctx
      )
    )
  }
})
