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

test_that("fct_file_operations.R indeholder ikke direct emit$navigation_changed efter data_updated", {
  source_file <- testthat::test_path("..", "..", "R", "fct_file_operations.R")
  skip_if_not(file.exists(source_file), "fct_file_operations.R ikke fundet")

  source_lines <- readLines(source_file, warn = FALSE)

  # Find alle linjer med data_updated-emit + navigation_changed-emit
  data_updated_lines <- grep("emit\\$data_updated", source_lines)
  nav_changed_lines <- grep("emit\\$navigation_changed", source_lines)

  # Ingen navigation_changed maa fyre INDEN for 5 linjer efter data_updated
  # (det indikerer double-emit-pattern hvor cascade haandterer navigation)
  for (du_line in data_updated_lines) {
    nearby_nav <- nav_changed_lines[
      nav_changed_lines > du_line & nav_changed_lines <= du_line + 5
    ]
    msg <- sprintf(
      "Linje %d emitter data_updated; linje(r) %s emitter navigation_changed kort efter (double-emit-pattern). Cycle B M2: cascade fyrer navigation via ui_sync_completed.",
      du_line,
      paste(nearby_nav, collapse = ", ")
    )
    expect(length(nearby_nav) == 0, failure_message = msg)
  }
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
        "Context '%s' burde route til 'load'-class. Hvis nej, cascade kan miste navigation_changed.",
        ctx
      )
    )
  }
})
