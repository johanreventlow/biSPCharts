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

  expect_true(grepl("carousel-item app-guide-slide active", active_html),
    label = "Foerste slide skal have active-class"
  )
  expect_false(grepl("carousel-item app-guide-slide active", inactive_html),
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

test_that("mod_app_guide_ui returnerer kun carousel uden lead/titel", {
  ui <- mod_app_guide_ui("guide")
  html_str <- as.character(htmltools::doRenderTags(ui))

  expect_true(grepl("guide-guide_carousel", html_str),
    label = "Skal indeholde carousel med ns-praefixet ID"
  )
  expect_true(grepl("app-guide-carousel", html_str),
    label = "Skal indeholde app-guide-carousel class"
  )
  # Lead-tekst er fjernet — carousel er eneste content
  expect_false(grepl("syv trin", html_str),
    label = "Lead-tekst om syv trin skal vaere fjernet"
  )
  expect_false(grepl("biSPCharts hj", html_str, fixed = TRUE),
    label = "Lead-tekst skal vaere fjernet"
  )
})

test_that("app-guide modal har custom Bootstrap 5 markup uden header/footer", {
  # Test paa REEL production-output via build_app_guide_modal_markup()
  # i stedet for at recreate markup inline (forhindrer drift)
  modal <- build_app_guide_modal_markup()
  html_str <- as.character(htmltools::doRenderTags(modal))

  # Custom modal-class
  expect_true(grepl("app-guide-modal", html_str),
    label = "Modal skal have app-guide-modal class"
  )
  # Custom X-knap
  expect_true(grepl("app-guide-close", html_str),
    label = "Modal skal have custom close-knap"
  )
  expect_true(grepl("data-bs-dismiss=\"modal\"", html_str),
    label = "Close-knap skal have Bootstrap dismiss-attribut"
  )
  # INGEN modal-header, INGEN modal-footer
  expect_false(grepl("modal-header", html_str),
    label = "Modal maa IKKE have Bootstrap modal-header"
  )
  expect_false(grepl("modal-footer", html_str),
    label = "Modal maa IKKE have Bootstrap modal-footer"
  )
  expect_false(grepl(">Luk<", html_str),
    label = "Ingen 'Luk'-knap i footer"
  )
  # Carousel embedded
  expect_true(grepl("app-guide-carousel", html_str),
    label = "Modal-body skal indeholde carousel"
  )
  # KRITISK: Bootstrap init-script skal vaere til stede ellers vises modal aldrig
  expect_true(grepl("new bootstrap.Modal", html_str, fixed = TRUE),
    label = "Modal skal indeholde Bootstrap-init-script (ellers aabnes modal aldrig)"
  )
  # Esc-handling parity: bade data-keyboard og data-bs-keyboard
  expect_true(grepl("data-keyboard=\"true\"", html_str, fixed = TRUE),
    label = "Modal skal have data-keyboard for Shiny modal.ts Esc-handler"
  )
})

test_that("app_guide_intro_slide renderer decorativ gradient naar image_src er NULL", {
  slide_no_image <- list(
    title = "Test uden billede",
    image_src = NULL,
    image_alt = NULL,
    content = shiny::tags$p("Body content")
  )
  out <- app_guide_intro_slide(slide_no_image, idx = 2L, total = 7L, active = FALSE)
  html <- as.character(htmltools::doRenderTags(out))

  expect_true(grepl("app-guide-media--decor", html),
    label = "Slide uden billede skal bruge decor-class"
  )
  expect_true(grepl("app-guide-decor-num", html),
    label = "Decor-side skal indeholde stort trin-nummer"
  )
  expect_true(grepl(">2<", html),
    label = "Decor-num skal vise idx (2)"
  )
  expect_false(grepl("app-guide-media--image", html),
    label = "Slide uden billede maa IKKE bruge image-class"
  )
})

test_that("app_guide_intro_slide renderer image-side naar image_src er sat", {
  slide_with_image <- list(
    title = "Test med billede",
    image_src = "www/help/06a-trin1-upload.png",
    image_alt = "Alt text",
    content = shiny::tags$p("Body")
  )
  out <- app_guide_intro_slide(slide_with_image, idx = 1L, total = 7L, active = TRUE)
  html <- as.character(htmltools::doRenderTags(out))

  expect_true(grepl("app-guide-media--image", html),
    label = "Slide med billede skal bruge image-class"
  )
  expect_true(grepl("06a-trin1-upload.png", html),
    label = "Image src skal vaere i HTML"
  )
  expect_false(grepl("app-guide-media--decor", html),
    label = "Slide med billede maa IKKE bruge decor-class"
  )
})
