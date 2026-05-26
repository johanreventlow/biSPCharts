# test-font-css.R
# Regression-tests for Mari font @font-face CSS + font-family-stack.
# Region H-pattern adopteret 2026-05-26: distinct family-names per vaegt
# (mariregular/maribold/maribook/marilight/mariheavy) via MariOffice-*.ttf.
# Sikrer at:
#   - @font-face deklarerer distinct family-names per vaegt
#   - src peger paa MariOffice-*.ttf (canonical Region H-glyph-data)
#   - brand.yml + config_branding_getters.R bruger Helvetica Neue som
#     fallback (NOT Mari -- undgaar system-Mari shadow)
#   - fallback-stack starter med mariregular ej generisk "Mari"

test_that("create_ui_header() injicerer Region H-pattern @font-face naar BFHchartsAssets findes", {
  skip_if_not_installed("BFHchartsAssets")

  ui_header <- create_ui_header()
  ui_html <- htmltools::doRenderTags(ui_header)

  # Distinct family-names per vaegt (Region H-pattern)
  expect_match(ui_html, "font-family:\\s*mariregular", fixed = FALSE)
  expect_match(ui_html, "font-family:\\s*maribold", fixed = FALSE)
  expect_match(ui_html, "font-family:\\s*maribook", fixed = FALSE)
  expect_match(ui_html, "font-family:\\s*marilight", fixed = FALSE)
  expect_match(ui_html, "font-family:\\s*mariheavy", fixed = FALSE)

  # MariOffice-*.ttf som src (canonical glyph-data fra bispebjerghospital.dk)
  expect_match(ui_html, "bfh_assets/MariOffice-Book\\.ttf", fixed = FALSE)
  expect_match(ui_html, "bfh_assets/MariOffice-Bold\\.ttf", fixed = FALSE)
  expect_match(ui_html, "bfh_assets/MariOffice-Light\\.ttf", fixed = FALSE)
  expect_match(ui_html, "bfh_assets/MariOffice-Heavy\\.ttf", fixed = FALSE)
})

test_that("create_ui_header() bruger IKKE defekt Mari-*.otf eller delt 'Mari' family-name", {
  skip_if_not_installed("BFHchartsAssets")

  ui_header <- create_ui_header()
  ui_html <- htmltools::doRenderTags(ui_header)

  # Regression-guards: ingen reference til defekt Mari-*.otf eller
  # delt "Mari" family-name (PR #517-regression-counter-test).
  expect_false(grepl("bfh_assets/Mari-Book\\.otf", ui_html))
  expect_false(grepl("bfh_assets/Mari-Bold\\.otf", ui_html))
  expect_false(grepl("font-family:\\s*'Mari'", ui_html))
  expect_false(grepl("font-family:\\s*\"Mari\"", ui_html))
})

test_that("brand.yml typography-stack starter med mariregular + bruger Helvetica Neue fallback", {
  config_path <- testthat::test_path("..", "..", "inst", "config", "brand.yml")
  skip_if_not(file.exists(config_path), "brand.yml ikke fundet")

  yaml_content <- yaml::read_yaml(config_path)
  typo <- yaml_content$typography

  expect_true(!is.null(typo$base))
  expect_match(typo$base, "^mariregular,")
  expect_match(typo$base, "Helvetica Neue")

  # Maa IKKE indeholde generisk "Mari" (uden suffix) som ville matche
  # system-installeret Mari Book.otf og introducere PR #517-regression.
  expect_false(grepl("\\bMari\\b(?!regular|bold|book|light|heavy)", typo$base, perl = TRUE))

  expect_true(!is.null(typo$headings$family))
  expect_match(typo$headings$family, "^maribold,")
  expect_match(typo$headings$family, "Helvetica Neue")
})

test_that("config_branding_getters.R font-family-base anvender mariregular + Helvetica Neue", {
  # Vi kan ikke direkte inspicere bslib-themeobjekt-output uden bslib-deps.
  # Verificer i stedet ved at laese kildekoden -- regression-guard mod at
  # nogen genaktiverer "Mari, Arial, ..." stacken.
  source_path <- testthat::test_path("..", "..", "R", "config_branding_getters.R")
  skip_if_not(file.exists(source_path), "config_branding_getters.R ikke fundet")

  src <- readLines(source_path, encoding = "UTF-8")
  src_text <- paste(src, collapse = "\n")

  # Skal indeholde mariregular + maribold + Helvetica Neue
  expect_match(src_text, '"font-family-base"\\s*=\\s*"mariregular,[^"]*Helvetica Neue')
  expect_match(src_text, '"headings-font-family"\\s*=\\s*"maribold,[^"]*Helvetica Neue')

  # Maa IKKE genintroducere bare "Mari, Arial, Helvetica" som primary stack
  expect_false(grepl('"font-family-base"\\s*=\\s*"Mari, Arial', src_text))
  expect_false(grepl('"headings-font-family"\\s*=\\s*"Mari, Arial', src_text))
})

test_that("create_ui_header() emitter tom @font-face-blok hvis BFHchartsAssets mangler", {
  if (requireNamespace("BFHchartsAssets", quietly = TRUE)) {
    skip("BFHchartsAssets installed - cannot test missing-pkg path without unmocking")
  }

  ui_header <- create_ui_header()
  ui_html <- htmltools::doRenderTags(ui_header)

  # Graceful degradation: ingen @font-face injiceres, browser falder til
  # Helvetica Neue/Helvetica/Arial-stack fra brand.yml.
  expect_false(grepl("@font-face\\s*\\{\\s*font-family:\\s*mariregular", ui_html))
})
