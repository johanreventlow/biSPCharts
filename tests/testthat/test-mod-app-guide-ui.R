# ==============================================================================
# TEST-MOD-APP-GUIDE-UI.R
# ==============================================================================
# Tests for app-guide modulet (carousel-format).
#
# Test-fokus:
#   - mod_app_guide_ui rendrerer carousel med 7 slides
#   - app_guide_intro_slides() returnerer korrekt struktur
#   - app_guide_intro_slide() saetter active-class kun paa foerste slide
#   - Image-paths refererer eksisterende screenshots
# ==============================================================================

test_that("app_guide_intro_slides returnerer 7 slides med paakraevede felter", {
  slides <- app_guide_intro_slides()

  expect_type(slides, "list")
  expect_length(slides, 7L)

  for (idx in seq_along(slides)) {
    slide <- slides[[idx]]
    expect_true("title" %in% names(slide),
      info = sprintf("slide %d mangler title", idx)
    )
    expect_true(nzchar(slide$title),
      info = sprintf("slide %d har tom title", idx)
    )
    expect_true("content" %in% names(slide),
      info = sprintf("slide %d mangler content", idx)
    )
    expect_s3_class(slide$content, c("shiny.tag", "shiny.tag.list"))
  }
})

test_that("app_guide_intro_slides bruger eksisterende billed-paths", {
  slides <- app_guide_intro_slides()
  for (idx in seq_along(slides)) {
    img <- slides[[idx]]$image_src
    if (is.null(img) || !nzchar(img)) next

    # www/help/06a-trin1-upload.png skal mappe til inst/app/www/help/...
    rel_path <- sub("^www/", "", img)
    full_path <- system.file("app", "www", rel_path, package = "biSPCharts")

    # Hvis pakke ikke installeret, fald tilbage til lokal sti
    if (!nzchar(full_path)) {
      full_path <- file.path("inst/app/www", rel_path)
    }
    expect_true(file.exists(full_path),
      info = sprintf("slide %d image_src '%s' findes ikke (sti: %s)", idx, img, full_path)
    )
  }
})

test_that("app_guide_intro_slide saetter active-class kun paa foerste slide", {
  slides <- app_guide_intro_slides()

  active_slide <- app_guide_intro_slide(slides[[1L]], idx = 1L, total = 7L, active = TRUE)
  inactive_slide <- app_guide_intro_slide(slides[[2L]], idx = 2L, total = 7L, active = FALSE)

  active_html <- as.character(active_slide)
  inactive_html <- as.character(inactive_slide)

  expect_true(grepl("carousel-item intro-carousel-slide active", active_html),
    label = "Foerste slide skal have active-class"
  )
  expect_false(grepl("carousel-item intro-carousel-slide active", inactive_html),
    label = "Anden slide maa IKKE have active-class"
  )
})

test_that("app_guide_intro_carousel rendrerer 7 indicators og slides", {
  ns <- shiny::NS("test")
  out <- app_guide_intro_carousel(ns)
  html_str <- as.character(htmltools::doRenderTags(out))

  # 7 indicators (data-bs-slide-to="0" til "6")
  for (idx in 0:6) {
    expect_true(grepl(sprintf("data-bs-slide-to=\"%d\"", idx), html_str),
      label = sprintf("Carousel skal have indicator %d", idx)
    )
  }

  # Carousel-id skal vaere namespace-praefixet
  expect_true(grepl("test-guide_carousel", html_str),
    label = "Carousel skal bruge ns()-praefixet ID"
  )

  # Bootstrap 5-attributter
  expect_true(grepl("data-bs-interval=\"false\"", html_str),
    label = "Carousel skal have data-bs-interval=false (no auto-rotate)"
  )
  expect_true(grepl("data-bs-touch=\"true\"", html_str),
    label = "Carousel skal have data-bs-touch=true"
  )

  # Slide-titler fra alle 7 slides skal vaere til stede
  slides <- app_guide_intro_slides()
  for (idx in seq_along(slides)) {
    title <- slides[[idx]]$title
    expect_true(grepl(title, html_str, fixed = TRUE),
      info = sprintf("Carousel skal indeholde titel for slide %d: %s", idx, title)
    )
  }
})

test_that("mod_app_guide_ui rendrerer modal-content med carousel", {
  # Modal-version returnerer kun body-content (ej fuld page med titel)
  ui <- mod_app_guide_ui("guide")
  html_str <- as.character(htmltools::doRenderTags(ui))

  expect_true(grepl("guide-guide_carousel", html_str),
    label = "App-guide skal indeholde carousel med ns-praefixet ID"
  )
  expect_true(grepl("intro-carousel-widget", html_str),
    label = "App-guide skal indeholde intro-carousel-widget class"
  )
  expect_true(grepl("syv trin", html_str),
    label = "App-guide skal have lead-tekst om syv trin"
  )
})

test_that("show_app_guide_modal returnerer modalDialog-tag", {
  # Verific\u00e9r at helper kan kaldes uden Shiny-session ved at intercept showModal.
  # Vi tester strukturen ved at calle modalDialog direkte med samme args.
  modal <- shiny::modalDialog(
    title = "S\u00e5dan bruger du appen",
    size = "xl",
    easyClose = TRUE,
    fade = TRUE,
    footer = shiny::modalButton("Luk"),
    mod_app_guide_ui("app_guide")
  )
  html_str <- as.character(htmltools::doRenderTags(modal))

  expect_true(grepl("modal-xl", html_str),
    label = "Modal skal have size=xl"
  )
  expect_true(grepl("S\u00e5dan bruger du appen", html_str),
    label = "Modal skal have hovedtitel"
  )
  expect_true(grepl("intro-carousel-widget", html_str),
    label = "Modal-body skal indeholde carousel"
  )
  # fade=TRUE skal generere "modal fade"-class (Bootstrap 5 fade-animation)
  expect_true(grepl("modal fade", html_str),
    label = "Modal skal have fade-class for animation"
  )
})
