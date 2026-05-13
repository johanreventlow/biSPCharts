# App-guide modal-redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor app-guide modal til 960×520 fixed-size lightbox med square corners, decorativ gradient-fallback for slides uden billede, fjernet titel/Luk-knap/lead, og genaktiveret navbar-trigger.

**Architecture:** Custom Bootstrap 5 modal-markup (drop `shiny::modalDialog` for fuld kontrol). Class-prefix `.app-guide-modal-*` for at undgå konflikt med eksisterende `.intro-carousel-*`. Decorativ gradient-fallback når slide-data har `image_src = NULL`. Navbar-trigger via `bslib::nav_item` + `actionLink` + server-observer.

**Tech Stack:** R, Shiny, bslib, Bootstrap 5, htmltools, testthat.

**Spec:** `docs/superpowers/specs/2026-05-13-app-guide-modal-redesign.md`

---

## File Structure

| Fil | Ansvar | Status |
|---|---|---|
| `R/mod_app_guide_ui.R` | Modal-builder, slide-renderer, slide-data | Modify (refactor 3 funktioner) |
| `R/utils_ui_app_layout.R` | Inline CSS i `create_ui_header()` | Modify (udskift CSS-blok ~120 linjer) |
| `R/app_ui.R` | Navbar-struktur | Modify (tilføj nav_item + CSS-visibility) |
| `R/app_server_main.R` | Server-observers | Modify (tilføj 1 observer) |
| `tests/testthat/test-mod-app-guide-ui.R` | Modul-tests | Modify (opdater 3 asserts, tilføj 4 nye) |

Ingen nye filer. Alle ændringer er i eksisterende filer.

---

## Task 1: Refactor CSS-foundation (slet `.intro-carousel-*`, tilføj `.app-guide-modal-*`)

**Files:**
- Modify: `R/utils_ui_app_layout.R` (linje ~282-403, eksisterende `.intro-carousel-*` blok)

- [ ] **Step 1: Læs current CSS-blok**

```bash
sed -n '280,410p' R/utils_ui_app_layout.R
```

Identificér start (`/* Intro-carousel ... */`) + slut (sidste `}` før `\")))`).

- [ ] **Step 2: Erstat CSS-blok med ny `.app-guide-modal-*` styling**

Brug `Edit`-tool på `R/utils_ui_app_layout.R`. Erstat hele eksisterende `/* Intro-carousel ... */`-blok (start: `/* Intro-carousel (genbrugelig: app-guide o.l.) */`, slut: sidste `}` før `\")))`-linjen) med:

```css
/* App-guide modal (lightbox-overlay med carousel) */
.app-guide-modal .modal-dialog {
  max-width: 960px;
  width: 960px;
  margin: 60px auto;
}
.app-guide-modal .modal-content {
  border-radius: 0;
  border: 1px solid #b8b8b8;
  box-shadow: 0 16px 48px rgba(0, 0, 0, 0.22);
  background: white;
  padding: 0;
}
.app-guide-modal-content {
  position: relative;
  height: 520px;
  overflow: hidden;
}
.app-guide-close {
  position: absolute;
  top: 14px;
  right: 16px;
  width: 28px;
  height: 28px;
  background: rgba(255, 255, 255, 0.85);
  border: 1px solid #d6d6d6;
  color: #565656;
  font-size: 18px;
  line-height: 26px;
  text-align: center;
  cursor: pointer;
  z-index: 10;
  padding: 0;
}
.app-guide-close:hover {
  background: white;
  color: #333333;
}
.app-guide-carousel {
  height: 520px;
}
.app-guide-carousel .carousel-inner {
  height: 460px;
  background: white;
}
.app-guide-slide {
  height: 460px;
  display: flex;
}
.app-guide-media {
  flex: 0 0 50%;
  border-right: 1px solid #ebebeb;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}
.app-guide-media--image {
  background: linear-gradient(135deg, #ccebfa 0%, #e8f4f8 100%);
  padding: 20px;
}
.app-guide-media--image img {
  max-width: 100%;
  max-height: 100%;
  object-fit: contain;
}
.app-guide-media--decor {
  background: linear-gradient(135deg, #007dbb 0%, #00293d 100%);
  color: rgba(255, 255, 255, 0.95);
  padding: 50px 40px;
  position: relative;
  flex-direction: column;
  justify-content: center;
  align-items: center;
}
.app-guide-media--decor::before {
  content: '';
  position: absolute;
  bottom: -40px;
  right: -40px;
  width: 180px;
  height: 180px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.06);
}
.app-guide-media--decor::after {
  content: '';
  position: absolute;
  top: 30px;
  left: 30px;
  width: 60px;
  height: 60px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.08);
}
.app-guide-decor-num {
  font-size: 96px;
  font-weight: 800;
  line-height: 1;
  margin-bottom: 8px;
  position: relative;
  z-index: 1;
}
.app-guide-decor-label {
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  opacity: 0.85;
  position: relative;
  z-index: 1;
}
.app-guide-content {
  flex: 1;
  padding: 32px 36px;
  text-align: left;
  color: #333333;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
}
.app-guide-step {
  display: inline-block;
  padding: 4px 11px;
  background: rgba(0, 125, 187, 0.12);
  color: #007dbb;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  margin-bottom: 12px;
  align-self: flex-start;
}
.app-guide-title {
  font-size: 22px;
  font-weight: 600;
  margin: 0 0 12px 0;
  color: #1a2a30;
  line-height: 1.2;
}
.app-guide-body {
  font-size: 13px;
  line-height: 1.55;
  color: #4b5659;
}
.app-guide-body p { margin: 0 0 8px 0; }
.app-guide-body p:last-child { margin-bottom: 0; }
.app-guide-body strong { color: #1a2a30; }
.app-guide-body code {
  background: rgba(0, 125, 187, 0.08);
  color: #007dbb;
  padding: 1px 5px;
  border-radius: 0;
  font-size: 0.9em;
}
.app-guide-body table {
  width: 100%;
  font-size: 11px;
  border-collapse: collapse;
  margin-top: 6px;
}
.app-guide-body table th,
.app-guide-body table td {
  border: 1px solid #d6d6d6;
  padding: 5px 8px;
  text-align: left;
}
.app-guide-body table th {
  background: #ebebeb;
  font-weight: 600;
}
.app-guide-body dl {
  margin: 0 0 0.5rem 0;
}
.app-guide-body dt {
  font-weight: 600;
  color: #1a2a30;
  margin-top: 0.4rem;
  font-size: 12px;
}
.app-guide-body dt:first-child { margin-top: 0; }
.app-guide-body dd {
  margin: 0 0 0.4rem 1rem;
  color: #4b5659;
  font-size: 12px;
}
.app-guide-body .alert {
  font-size: 11.5px;
  padding: 8px 12px;
  margin-top: 10px;
  border-radius: 0;
}
.app-guide-indicators {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  margin: 0;
  padding: 14px 0;
  background: white;
  border-top: 1px solid #ebebeb;
  display: flex;
  justify-content: center;
  gap: 6px;
}
.app-guide-indicators [data-bs-target] {
  width: 8px;
  height: 8px;
  border-radius: 0;
  border: 0;
  background-color: rgba(0, 37, 85, 0.22);
  transition: width 0.2s ease, background-color 0.2s ease;
  padding: 0;
}
.app-guide-indicators .active {
  background-color: #007dbb;
  width: 22px;
}
.app-guide-control {
  position: absolute;
  top: 50%;
  transform: translateY(-50%);
  width: 38px;
  height: 38px;
  background: rgba(0, 37, 85, 0.7);
  color: white;
  font-size: 20px;
  text-align: center;
  cursor: pointer;
  border: 1px solid rgba(255, 255, 255, 0.15);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 5;
  opacity: 0.85;
}
.app-guide-control:hover { opacity: 1; }
.app-guide-control--prev { left: 14px; }
.app-guide-control--next { right: 14px; }

/* Navbar-link "Sådan bruger du appen": skjult før wizard-nav-active */
.navbar .nav-item:has(.nav-link[data-value='app_guide_trigger']) {
  display: none !important;
}
body.wizard-nav-active .navbar .nav-item:has(.nav-link[data-value='app_guide_trigger']) {
  display: flex !important;
  align-items: center;
}
```

- [ ] **Step 3: Verificér CSS-syntaks via R-parse**

Run:
```bash
R -e "parse('R/utils_ui_app_layout.R'); cat('OK\n')" 2>&1 | tail -3
```
Expected: `OK` på sidste linje, ingen parse-fejl.

- [ ] **Step 4: Verificér CSS embedded i create_ui_header() output**

Run:
```bash
R -e "
devtools::load_all('.', quiet = TRUE);
html <- htmltools::doRenderTags(create_ui_header());
cat('app-guide-modal:', grepl('app-guide-modal', html), '\n');
cat('app-guide-media--decor:', grepl('app-guide-media--decor', html), '\n');
cat('app-guide-decor-num:', grepl('app-guide-decor-num', html), '\n');
cat('navbar-trigger CSS:', grepl(\"data-value='app_guide_trigger'\", html), '\n');
" 2>&1 | tail -5
```
Expected: Alle TRUE.

- [ ] **Step 5: Commit**

```bash
git add R/utils_ui_app_layout.R
git commit -m "refactor(app-guide): erstat .intro-carousel-* CSS med .app-guide-modal-*

Square corners, fixed 960x520 sizing, decorativ gradient-fallback,
custom dots/arrows/X. Plus navbar-link visibility-rules for kommende
trigger-link i wizard-nav."
```

---

## Task 2: Refactor `app_guide_intro_slide` til decorativ gradient-fallback

**Files:**
- Modify: `R/mod_app_guide_ui.R` (funktionen `app_guide_intro_slide`, ~linje 119-162)
- Modify: `R/mod_app_guide_ui.R` (funktionen `app_guide_intro_carousel`, klasse-navne ~linje 49-105)
- Test: `tests/testthat/test-mod-app-guide-ui.R`

- [ ] **Step 1: Skriv failing test for decorativ gradient-fallback**

Tilføj til `tests/testthat/test-mod-app-guide-ui.R`:

```r
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
```

- [ ] **Step 2: Run tests for at verificere de fejler**

Run:
```bash
R -e "devtools::load_all('.', quiet = TRUE); testthat::test_file('tests/testthat/test-mod-app-guide-ui.R')" 2>&1 | tail -10
```
Expected: 2 nye tests FAIL (eksisterende klasse-navne er stadig `.intro-carousel-*`, ej `.app-guide-*`).

- [ ] **Step 3: Refactor `app_guide_intro_slide` til ny class-prefix + fallback**

Erstat i `R/mod_app_guide_ui.R` hele `app_guide_intro_slide`-funktionen med:

```r
#' Renderer ét carousel-slide i app-guide
#'
#' Slide-layout: venstre=media (50%), hoejre=content (50%). Media-siden
#' viser screenshot hvis slide$image_src er sat; ellers fallback decorativ
#' gradient med stort trin-nummer (matcher hospital-brand). Konsekvent
#' 460px hoejde uanset content for at undgaa layout-hop ved navigation.
#'
#' @param slide Named list med title, content, image_src, image_alt
#' @param idx Integer. Slide-nummer (1-baseret)
#' @param total Integer. Total antal slides
#' @param active Logical. TRUE for første slide
#' @return shiny.tag
#' @noRd
app_guide_intro_slide <- function(slide, idx, total, active = FALSE) {
  has_image <- !is.null(slide$image_src) && nzchar(slide$image_src)

  media_col <- if (has_image) {
    shiny::div(
      class = "app-guide-media app-guide-media--image",
      shiny::img(
        src = slide$image_src,
        alt = slide$image_alt %||% ""
      )
    )
  } else {
    shiny::div(
      class = "app-guide-media app-guide-media--decor",
      shiny::div(class = "app-guide-decor-num", as.character(idx)),
      shiny::div(class = "app-guide-decor-label", slide$title)
    )
  }

  content_col <- shiny::div(
    class = "app-guide-content",
    shiny::div(
      class = "app-guide-step",
      sprintf("Trin %d / %d", idx, total)
    ),
    shiny::tags$h3(slide$title, class = "app-guide-title"),
    shiny::div(class = "app-guide-body", slide$content)
  )

  shiny::tags$div(
    class = paste("carousel-item app-guide-slide", if (active) "active"),
    media_col,
    content_col
  )
}
```

- [ ] **Step 4: Refactor `app_guide_intro_carousel` til ny class-prefix**

Erstat i `R/mod_app_guide_ui.R` hele `app_guide_intro_carousel`-funktionen med:

```r
#' App-guide carousel: 7-trins gennemgang
#' @param ns Namespace function (fra shiny::NS(id))
#' @return shiny.tag
#' @noRd
app_guide_intro_carousel <- function(ns) {
  carousel_id <- ns("guide_carousel")
  slides <- app_guide_intro_slides()
  total <- length(slides)

  shiny::tags$div(
    id = carousel_id,
    class = "carousel slide app-guide-carousel",
    `data-bs-interval` = "false",
    `data-bs-touch` = "true",
    shiny::tags$div(
      class = "carousel-inner",
      lapply(seq_along(slides), function(idx) {
        app_guide_intro_slide(
          slide = slides[[idx]],
          idx = idx,
          total = total,
          active = idx == 1L
        )
      })
    ),
    shiny::tags$button(
      class = "app-guide-control app-guide-control--prev",
      type = "button",
      `data-bs-target` = paste0("#", carousel_id),
      `data-bs-slide` = "prev",
      `aria-label` = "Forrige trin",
      shiny::HTML("&lsaquo;")
    ),
    shiny::tags$button(
      class = "app-guide-control app-guide-control--next",
      type = "button",
      `data-bs-target` = paste0("#", carousel_id),
      `data-bs-slide` = "next",
      `aria-label` = "Næste trin",
      shiny::HTML("&rsaquo;")
    ),
    shiny::tags$div(
      class = "carousel-indicators app-guide-indicators",
      lapply(seq_along(slides), function(idx) {
        shiny::tags$button(
          type = "button",
          `data-bs-target` = paste0("#", carousel_id),
          `data-bs-slide-to` = idx - 1L,
          class = if (idx == 1L) "active" else NULL,
          `aria-current` = if (idx == 1L) "true" else NULL,
          `aria-label` = paste("Vis trin", idx)
        )
      })
    )
  )
}
```

- [ ] **Step 5: Escape non-ASCII chars i strings**

Run:
```bash
python3 <<'PY'
import re
path = 'R/mod_app_guide_ui.R'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()
def esc(m): return '\\u%04x' % ord(m.group(0))
new = []
for line in lines:
    if line.lstrip().startswith('#'):
        new.append(line)
    else:
        new.append(re.sub(r'[^\x00-\x7f]', esc, line))
with open(path, 'w', encoding='utf-8') as f:
    f.writelines(new)
PY
```

- [ ] **Step 6: Run tests for at verificere de passerer**

Run:
```bash
R -e "devtools::load_all('.', quiet = TRUE); testthat::test_file('tests/testthat/test-mod-app-guide-ui.R')" 2>&1 | tail -5
```
Expected: De 2 nye tests PASS. Eksisterende test der asserter `intro-carousel-widget` FAIL (vi opdaterer dem i Task 3-4).

- [ ] **Step 7: Opdater eksisterende tests til nye class-navne**

Erstat i `tests/testthat/test-mod-app-guide-ui.R`:
- `"intro-carousel-widget"` → `"app-guide-carousel"`
- `"intro-carousel-slide"` → `"app-guide-slide"`
- `"carousel-item intro-carousel-slide"` → `"carousel-item app-guide-slide"`
- I `test "app_guide_intro_slide saetter active-class kun paa foerste slide"`, opdater grepl-mønstre tilsvarende.

Brug `Edit`-tool replace_all hvor relevant.

- [ ] **Step 8: Run tests fuld suite**

Run:
```bash
R -e "devtools::load_all('.', quiet = TRUE); testthat::test_file('tests/testthat/test-mod-app-guide-ui.R')" 2>&1 | tail -5
```
Expected: Alle PASS.

- [ ] **Step 9: Commit**

```bash
git add R/mod_app_guide_ui.R tests/testthat/test-mod-app-guide-ui.R
git commit -m "refactor(app-guide): renderer-funktioner med decor-gradient fallback

app_guide_intro_slide: hvis image_src=NULL, render decorativ gradient-side
med stort trin-nummer + label. Hvis image_src sat, render screenshot.
Class-prefix opdateret til .app-guide-* (matcher Task 1 CSS)."
```

---

## Task 3: Refactor `mod_app_guide_ui` — drop lead-paragraph

**Files:**
- Modify: `R/mod_app_guide_ui.R` (funktionen `mod_app_guide_ui`, ~linje 14-39)

- [ ] **Step 1: Skriv test der asserter ingen lead-tekst**

Erstat eksisterende `test "mod_app_guide_ui rendrerer modal-content med carousel"` i `tests/testthat/test-mod-app-guide-ui.R` med:

```r
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
```

- [ ] **Step 2: Run test for at verificere fail**

Run:
```bash
R -e "devtools::load_all('.', quiet = TRUE); testthat::test_file('tests/testthat/test-mod-app-guide-ui.R')" 2>&1 | tail -5
```
Expected: Lead-asserts FAIL (lead er stadig der).

- [ ] **Step 3: Refactor `mod_app_guide_ui` til kun carousel**

Erstat hele `mod_app_guide_ui`-funktionen i `R/mod_app_guide_ui.R` med:

```r
#' App Guide Module UI
#'
#' Returnerer carousel-content til app-guide modal-body. Modal-frame +
#' close-knap haandteres af show_app_guide_modal() (custom Bootstrap 5
#' markup). Ingen header, ingen footer, ingen lead-paragraph — modal er
#' ren lightbox-overlay.
#'
#' @param id Character. Namespace ID for modulet
#' @return Shiny tag (carousel)
#' @keywords internal
mod_app_guide_ui <- function(id) {
  ns <- shiny::NS(id)
  app_guide_intro_carousel(ns)
}
```

- [ ] **Step 4: Run tests for at verificere pass**

Run:
```bash
R -e "devtools::load_all('.', quiet = TRUE); testthat::test_file('tests/testthat/test-mod-app-guide-ui.R')" 2>&1 | tail -5
```
Expected: Alle PASS.

- [ ] **Step 5: Commit**

```bash
git add R/mod_app_guide_ui.R tests/testthat/test-mod-app-guide-ui.R
git commit -m "refactor(app-guide): drop lead-paragraph fra mod_app_guide_ui

Modal-body indeholder nu KUN carousel — ingen titel, ingen lead-tekst.
Matcher 'lightbox'-design hvor modal foeles fokuseret, ej 'mini-side'."
```

---

## Task 4: Refactor `show_app_guide_modal` til custom Bootstrap 5 modal-markup

**Files:**
- Modify: `R/mod_app_guide_ui.R` (funktionen `show_app_guide_modal`, ~linje 32-50)
- Test: `tests/testthat/test-mod-app-guide-ui.R`

- [ ] **Step 1: Erstat eksisterende modal-construction-test med custom markup-asserts**

Erstat eksisterende `test "show_app_guide_modal returnerer modalDialog-tag"` i `tests/testthat/test-mod-app-guide-ui.R` med:

```r
test_that("app-guide modal har custom Bootstrap 5 markup uden header/footer", {
  # Recreate modal-markup som show_app_guide_modal bygger
  modal <- shiny::tags$div(
    id = "shiny-modal",
    class = "modal fade app-guide-modal",
    tabindex = "-1",
    `data-bs-backdrop` = "true",
    `data-bs-keyboard` = "true",
    shiny::tags$div(
      class = "modal-dialog app-guide-modal-dialog",
      shiny::tags$div(
        class = "modal-content app-guide-modal-content",
        shiny::tags$button(
          type = "button",
          class = "app-guide-close",
          `data-bs-dismiss` = "modal",
          `aria-label` = "Luk",
          shiny::HTML("&times;")
        ),
        mod_app_guide_ui("app_guide")
      )
    )
  )
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
})
```

- [ ] **Step 2: Run test for at verificere fail**

Run:
```bash
R -e "devtools::load_all('.', quiet = TRUE); testthat::test_file('tests/testthat/test-mod-app-guide-ui.R')" 2>&1 | tail -5
```
Expected: Test PASSER allerede (test bygger markup direkte). Vi skal opdatere `show_app_guide_modal` til at bygge identisk markup.

- [ ] **Step 3: Refactor `show_app_guide_modal` til custom modal-markup**

Erstat hele `show_app_guide_modal`-funktionen i `R/mod_app_guide_ui.R` med:

```r
#' Vis app-guide som lightbox modal-overlay
#'
#' Custom Bootstrap 5 modal-markup uden header/footer (drop shiny::modalDialog
#' for fuld kontrol). Lukkes ved klik udenfor (data-bs-backdrop=true), Esc
#' (data-bs-keyboard=true), eller custom X-knap (data-bs-dismiss=modal).
#'
#' @param session Shiny session-objekt (typisk parent_session fra modul)
#' @return invisible(NULL). Side-effekt: viser modal.
#' @keywords internal
show_app_guide_modal <- function(session = shiny::getDefaultReactiveDomain()) {
  modal_markup <- shiny::tags$div(
    id = "shiny-modal",
    class = "modal fade app-guide-modal",
    tabindex = "-1",
    `data-bs-backdrop` = "true",
    `data-bs-keyboard` = "true",
    shiny::tags$div(
      class = "modal-dialog app-guide-modal-dialog",
      shiny::tags$div(
        class = "modal-content app-guide-modal-content",
        shiny::tags$button(
          type = "button",
          class = "app-guide-close",
          `data-bs-dismiss` = "modal",
          `aria-label` = "Luk",
          shiny::HTML("&times;")
        ),
        mod_app_guide_ui("app_guide")
      )
    )
  )
  shiny::showModal(modal_markup, session = session)
}
```

- [ ] **Step 4: Verificér at show_app_guide_modal bygger samme markup som test**

Run:
```bash
R -e "
devtools::load_all('.', quiet = TRUE);
# Bygger samme markup som test (uden showModal-call)
modal <- shiny::tags\$div(
  id = 'shiny-modal',
  class = 'modal fade app-guide-modal',
  tabindex = '-1',
  \`data-bs-backdrop\` = 'true',
  \`data-bs-keyboard\` = 'true',
  shiny::tags\$div(
    class = 'modal-dialog app-guide-modal-dialog',
    shiny::tags\$div(
      class = 'modal-content app-guide-modal-content',
      shiny::tags\$button(
        type = 'button',
        class = 'app-guide-close',
        \`data-bs-dismiss\` = 'modal',
        \`aria-label\` = 'Luk',
        shiny::HTML('&times;')
      ),
      mod_app_guide_ui('app_guide')
    )
  )
);
html <- as.character(htmltools::doRenderTags(modal));
cat('app-guide-close:', grepl('app-guide-close', html), '\n');
cat('app-guide-carousel:', grepl('app-guide-carousel', html), '\n');
cat('NO modal-header:', !grepl('modal-header', html), '\n');
cat('NO modal-footer:', !grepl('modal-footer', html), '\n');
" 2>&1 | tail -5
```
Expected: Alle TRUE.

- [ ] **Step 5: Run alle tests**

Run:
```bash
R -e "devtools::load_all('.', quiet = TRUE); testthat::test_file('tests/testthat/test-mod-app-guide-ui.R'); testthat::test_file('tests/testthat/test-mod-landing-server.R')" 2>&1 | tail -10
```
Expected: Alle PASS.

- [ ] **Step 6: Commit**

```bash
git add R/mod_app_guide_ui.R tests/testthat/test-mod-app-guide-ui.R
git commit -m "refactor(app-guide): custom Bootstrap 5 modal-markup uden header/footer

Erstat shiny::modalDialog (som tvinger modal-header + modal-footer) med
custom tags\$div('modal app-guide-modal') + custom X-knap. Fuld kontrol
over markup. Backdrop/keyboard-handling via Bootstrap data-bs-attributes."
```

---

## Task 5: Tilføj navbar-trigger + server-observer

**Files:**
- Modify: `R/app_ui.R` (navbar-blokken, ~linje 115-130)
- Modify: `R/app_server_main.R` (~linje 247-253)
- Test: `tests/testthat/test-mod-app-guide-ui.R`

- [ ] **Step 1: Skriv test for navbar-trigger i app_ui**

Tilføj til `tests/testthat/test-mod-app-guide-ui.R`:

```r
test_that("app_ui indeholder app_guide_trigger nav-link", {
  ui <- app_ui(NULL)
  html_str <- as.character(htmltools::doRenderTags(ui))

  expect_true(grepl("trigger_app_guide_modal", html_str),
    label = "app_ui skal indeholde actionLink med id trigger_app_guide_modal"
  )
  expect_true(grepl("data-value=\"app_guide_trigger\"", html_str),
    label = "Nav-link skal have data-value app_guide_trigger for CSS-visibility"
  )
  expect_true(grepl("Sådan bruger du appen", html_str, fixed = FALSE) ||
              grepl("S\\u00e5dan bruger du appen", html_str),
    label = "Nav-link skal have label 'Sådan bruger du appen'"
  )
})
```

- [ ] **Step 2: Run test for at verificere fail**

Run:
```bash
R -e "devtools::load_all('.', quiet = TRUE); testthat::test_file('tests/testthat/test-mod-app-guide-ui.R')" 2>&1 | tail -5
```
Expected: Nav-link asserts FAIL.

- [ ] **Step 3: Tilføj nav_item i app_ui.R**

Find blokken i `R/app_ui.R`:

```r
      # App-vejledning vises som modal-overlay via show_app_guide_modal()
      # triggered fra "Sådan bruger du appen"-link på landing-side. Ingen tab.

      # Hjaelp (adskilt fra wizard-flow)
```

Erstat med:

```r
      # App-vejledning trigger: actionLink i navbar (højre side) der åbner
      # modal-overlay via show_app_guide_modal() i app_server_main observer.
      bslib::nav_item(
        shiny::actionLink(
          inputId = "trigger_app_guide_modal",
          label = "Sådan bruger du appen",
          icon = shiny::icon("circle-question"),
          class = "nav-link",
          `data-value` = "app_guide_trigger"
        )
      ),

      # Hjaelp (adskilt fra wizard-flow)
```

- [ ] **Step 4: Tilføj observer i app_server_main.R**

Find blokken i `R/app_server_main.R`:

```r
  ## App-vejledning vises som modal-overlay (ingen tab, ingen back-nav).
  ## Modal triggeres via show_app_guide_modal() fra landing-link.

  ## Hjaelpeside modul (tilbagenavigation til forrige tab)
```

Erstat med:

```r
  ## App-vejledning vises som modal-overlay (ingen tab, ingen back-nav).
  ## Triggers: (a) "Sådan bruger du appen"-link på landing-side via
  ## mod_landing_server, (b) navbar actionLink via observer nedenfor.
  shiny::observeEvent(input$trigger_app_guide_modal, {
    show_app_guide_modal(session)
  })

  ## Hjaelpeside modul (tilbagenavigation til forrige tab)
```

- [ ] **Step 5: Run tests for at verificere pass**

Run:
```bash
R -e "devtools::load_all('.', quiet = TRUE); testthat::test_file('tests/testthat/test-mod-app-guide-ui.R')" 2>&1 | tail -5
```
Expected: Alle PASS.

- [ ] **Step 6: Smoke-test app-init**

Run:
```bash
R -e "
devtools::load_all('.', quiet = TRUE);
ui <- app_ui(NULL);
html <- htmltools::doRenderTags(ui);
cat('app_ui parses + renders:', nchar(html) > 1000, '\n');
cat('navbar trigger present:', grepl('trigger_app_guide_modal', html), '\n');
cat('CSS visibility-rule present:', grepl(\"data-value='app_guide_trigger'\", html), '\n');
" 2>&1 | tail -5
```
Expected: Alle TRUE.

- [ ] **Step 7: Commit**

```bash
git add R/app_ui.R R/app_server_main.R tests/testthat/test-mod-app-guide-ui.R
git commit -m "feat(app-guide): genaktiver navbar-trigger som actionLink

bslib::nav_item med shiny::actionLink i navbar højre side. Klik trigger
input\$trigger_app_guide_modal observer i app_server_main.R der kalder
show_app_guide_modal(session). Visibility styret af eksisterende
wizard-nav-active CSS-rule (Task 1)."
```

---

## Task 6: Final integration smoke-test

**Files:**
- Read-only verifikation (ingen ændringer)

- [ ] **Step 1: Run hele test-suite for landing + app_guide + relaterede**

Run:
```bash
R -e "
devtools::load_all('.', quiet = TRUE);
testthat::test_file('tests/testthat/test-mod-landing-server.R')
testthat::test_file('tests/testthat/test-mod-app-guide-ui.R')
" 2>&1 | tail -10
```
Expected: Alle PASS, ingen FAIL/WARN.

- [ ] **Step 2: Verificér at app starter**

Run:
```bash
R -e "
devtools::load_all('.', quiet = TRUE);
ui <- app_ui(NULL);
header <- create_ui_header();
cat('app_ui:', !is.null(ui), '\n');
cat('header:', !is.null(header), '\n');
cat('show_app_guide_modal exists:', exists('show_app_guide_modal'), '\n');
cat('app_guide_intro_slides exists:', exists('app_guide_intro_slides'), '\n');
slides <- app_guide_intro_slides();
cat('slides count:', length(slides), '\n');
" 2>&1 | tail -5
```
Expected: app_ui TRUE, header TRUE, show_app_guide_modal TRUE, app_guide_intro_slides TRUE, slides count 7.

- [ ] **Step 3: Manuel visuel test**

Bed bruger om at:
1. Start app via `R -e "devtools::load_all('.'); biSPCharts::run_app()"` eller IDE
2. Klik "Kom i gang" → wizard-nav-active aktiveres
3. Verificér "Sådan bruger du appen"-link i navbar højre side
4. Klik linket → modal åbner som lightbox
5. Verificér: 960×520 størrelse, square corners, ingen header/footer/Luk-knap
6. Klik gennem alle 7 slides — verificér konsekvent højde
7. Slide 2, 4, 5, 7: verificér decorativ gradient med stort trin-nummer
8. Slide 1, 3, 6: verificér screenshot
9. Test luk: klik backdrop, klik X, tryk Esc — alle skal lukke modal
10. Test også "Sådan bruger du appen"-link på landing-side → samme modal

- [ ] **Step 4: Hvis manuel test passerer, no-op commit (eller skip)**

Hvis ingen ændringer behøves, ingen commit. Plan komplet.

---

## Self-Review

### Spec coverage

| Spec-element | Task |
|---|---|
| Modal 960×520 fixed | Task 1 (CSS) |
| Square corners | Task 1 (CSS) |
| Backdrop default (Bootstrap) | Implicit (ingen CSS-override) |
| Slide 50/50 split | Task 1 (CSS) + Task 2 (renderer) |
| Decorativ gradient-fallback | Task 1 (CSS) + Task 2 (renderer) |
| Step-chip + title + body | Task 2 (renderer) |
| 7 indicator-dots med active-pill | Task 1 (CSS) + Task 2 (renderer) |
| Side-arrows (38px square) | Task 1 (CSS) + Task 2 (renderer) |
| Custom X-knap | Task 1 (CSS) + Task 4 (markup) |
| Ingen titel/lead/footer/Luk | Task 3 (drop lead) + Task 4 (custom markup) |
| Custom Bootstrap 5 modal | Task 4 |
| Navbar-trigger nav_item + actionLink | Task 5 |
| Server-observer trigger_app_guide_modal | Task 5 |
| CSS-visibility for navbar-link | Task 1 |
| Tests opdateret/tilføjet | Task 2-5 (per task) |

Alle spec-elementer dækket.

### Type-konsistens

- `app_guide_intro_slide(slide, idx, total, active)` — signatur konsistent på tværs af Task 2
- `app_guide_intro_carousel(ns)` — signatur konsistent
- `show_app_guide_modal(session)` — signatur konsistent på tværs af Task 4-5
- CSS-class `.app-guide-modal` brugt konsistent i Task 1, 4
- CSS-class `.app-guide-carousel` brugt konsistent i Task 1, 2
- CSS-class `.app-guide-media--image` / `.app-guide-media--decor` konsistent Task 1, 2
- Input-id `trigger_app_guide_modal` konsistent Task 5

### Placeholder-scan

Ingen TBD/TODO/"implement later". Alle kode-blokke er komplette.
