# Manual shinytest2 — kør lokalt, ej i CI
# Per feedback_shinytest2_upload_flow: upload-flow kræver paste +
# load_paste_data, ikke app$upload_file.

library(shinytest2)
library(testthat)

test_that("Navigation guard modal vises på trin 2 ved logo-klik", {
  app <- AppDriver$new(
    name = "nav-guard-logo",
    timeout = 20000,
    height = 900, width = 1400
  )
  on.exit(app$stop(), add = TRUE)

  # Naviger til upload-tab + paste data
  app$click(selector = '#main_navbar .nav-link[data-value="upload"]')
  app$wait_for_idle()

  paste_data <- "dato\ttaeller\n2026-01-01\t10\n2026-01-02\t12\n"
  app$set_inputs(paste_textarea = paste_data)
  app$click("load_paste_data")
  app$wait_for_idle(timeout = 5000)

  # Naviger til trin 2 (auto-advance eller manuel)
  app$wait_for_value(input = "main_navbar", ignore = list("upload"))

  expect_equal(app$get_value(input = "main_navbar"), "analyser")

  # Klik logo
  app$click(selector = "#logo_home_link")
  app$wait_for_idle()

  # Expect modal
  modal_html <- app$get_html(".modal-dialog")
  expect_true(grepl("Forlad arbejde", modal_html))
  expect_true(grepl("nav_guard_confirm", modal_html))

  # Annullér
  app$click("nav_guard_cancel")
  app$wait_for_idle()
  expect_equal(app$get_value(input = "main_navbar"), "analyser")
})

test_that("Navigation guard Nulstil (no DL) reset session", {
  app <- AppDriver$new(
    name = "nav-guard-reset",
    timeout = 20000
  )
  on.exit(app$stop(), add = TRUE)

  app$click(selector = '#main_navbar .nav-link[data-value="upload"]')
  app$wait_for_idle()
  app$set_inputs(paste_textarea = "dato\ttaeller\n2026-01-01\t10\n")
  app$click("load_paste_data")
  app$wait_for_idle(timeout = 5000)

  # Auto-advance til trin 2
  app$wait_for_value(input = "main_navbar", ignore = list("upload"))

  # Klik back-knap
  app$click("back_to_upload")
  app$wait_for_idle()

  # Confirm reset uden download
  app$set_inputs(nav_guard_download = FALSE)
  app$click("nav_guard_confirm")
  app$wait_for_idle(timeout = 3000)

  expect_equal(app$get_value(input = "main_navbar"), "upload")
})
