# ==============================================================================
# test-mod_report_bug.R
# ==============================================================================
# Smoke-tests for "Rapporter fejl"-modul:
#   - UI returnerer shiny.tag-objekt
#   - mailto-URL er korrekt encoded (subject + body inkl. dansk æøå)
#   - Tilbage-link er til stede
# ==============================================================================

test_that("build_bug_report_mailto returnerer korrekt formateret URL", {
  url <- build_bug_report_mailto()

  expect_type(url, "character")
  expect_length(url, 1L)
  expect_match(url, "^mailto:", fixed = FALSE)
  expect_match(url, SUPPORT_EMAIL, fixed = TRUE)
  expect_match(url, "subject=", fixed = TRUE)
  expect_match(url, "body=", fixed = TRUE)
})

test_that("build_bug_report_mailto URL-encoder danske tegn korrekt", {
  url <- build_bug_report_mailto(
    subject = "Test æøå",
    body = "Hej Dataenhed,\nÆØÅ test"
  )

  # æ -> %C3%A6 (UTF-8 to-byte sekvens, %-encoded)
  expect_match(url, "%C3%A6", fixed = TRUE)
  # Linjeskift -> %0A
  expect_match(url, "%0A", fixed = TRUE)
})

test_that("build_bug_report_mailto rejecterer ugyldige inputs", {
  expect_error(build_bug_report_mailto(to = ""))
  expect_error(build_bug_report_mailto(to = c("a", "b")))
  expect_error(build_bug_report_mailto(subject = NA_character_))
})

test_that("SUPPORT_EMAIL_BODY indeholder ikke-tekniske skabelon-afsnit", {
  expect_match(SUPPORT_EMAIL_BODY, "Hej Dataenhed,", fixed = TRUE)
  expect_match(SUPPORT_EMAIL_BODY, "Hvad skete der?", fixed = TRUE)
  expect_match(SUPPORT_EMAIL_BODY, "Hvad lavede du, da det skete?", fixed = TRUE)
  expect_match(SUPPORT_EMAIL_BODY, "Hvad havde du forventet?", fixed = TRUE)
  expect_match(SUPPORT_EMAIL_BODY, "Vedhæft gerne:", fixed = TRUE)
  expect_match(SUPPORT_EMAIL_BODY, "data og indstillinger", fixed = TRUE)
  expect_match(SUPPORT_EMAIL_BODY, "graf", fixed = TRUE)
  expect_match(SUPPORT_EMAIL_BODY, "skærmbillede", fixed = TRUE)
})

test_that("mod_report_bug_ui returnerer shiny.tag-objekt", {
  ui <- mod_report_bug_ui("test_id")

  expect_s3_class(ui, "shiny.tag")
})

test_that("mod_report_bug_ui indeholder mailto-link med korrekt modtager", {
  ui <- mod_report_bug_ui("test_id")
  html <- as.character(ui)

  # Mailto-prefix + modtager skal vaere i renderet HTML
  expect_match(html, "mailto:", fixed = TRUE)
  expect_match(html, SUPPORT_EMAIL, fixed = TRUE)
})

test_that("mod_report_bug_ui indeholder tilbage-link og bug-ikon", {
  ui <- mod_report_bug_ui("test_id")
  html <- as.character(ui)

  # Tilbage-link rendres via help_back_link()
  expect_match(html, "test_id-go_back", fixed = TRUE)
  # Mailto-knap har envelope-ikon
  expect_match(html, "fa-envelope", fixed = TRUE)
})
