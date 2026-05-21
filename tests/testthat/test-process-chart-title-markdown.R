# test-process-chart-title-markdown.R
# Regression: process_chart_title() skal bevare markdown-asterisks (`**fed**`)
# saa marquee-parseren (BFHtheme plot.title) kan rendere fed/kursiv. Sprint 3
# XSS-hardening (commit 631e4cd8, 2025-09-30) introducerede sanitize-kald uden
# `*` i allowed_chars, hvilket stripped markdown-syntaksen for plot-titler.

test_that("process_chart_title bevarer markdown-bold asterisks", {
  skip_if_not_installed("shiny")

  title_reactive <- shiny::reactive("**Fed titel**")
  config <- list(y_col = "Vaerdi")

  result <- shiny::isolate(process_chart_title(title_reactive, config))

  expect_true(
    grepl("\\*\\*Fed titel\\*\\*", result, fixed = FALSE),
    info = paste0("Markdown-asterisks skal overleve sanitize. Faktisk: '", result, "'")
  )
})

test_that("process_chart_title stadig stripper farlige HTML-tags", {
  skip_if_not_installed("shiny")

  title_reactive <- shiny::reactive("<script>alert(1)</script> **fed**")
  config <- list(y_col = "Vaerdi")

  result <- shiny::isolate(process_chart_title(title_reactive, config))

  expect_false(grepl("<script>", result, fixed = TRUE),
    info = "HTML-tags skal stadig escapes/strippes"
  )
  expect_true(grepl("\\*\\*fed\\*\\*", result),
    info = "Markdown-bold skal bevares ved siden af HTML-sanitize"
  )
})
