# App-guide modal-redesign

**Status:** Approved (2026-05-13)
**Forrige iteration:** `R/mod_app_guide_ui.R` + `show_app_guide_modal()` (commit df7be652) — Shiny modalDialog med titel/footer/variabel-højde-pain points.

## Problem

Den nuværende modal-implementation har 3 UX-problemer som bruger har identificeret:

1. **Føles "indlejret i hvid side"** — Shiny modalDialog renderer modal-header med titel ("Sådan bruger du appen") og lead-tekst. Det får modal til at fremstå som en mini-side frem for et fokuseret overlay.
2. **"Luk"-knap i footer** — overflødig CTA. Bruger lukker via klik udenfor, Esc eller X.
3. **Variabel slide-højde** — modal-højde tilpasser sig per slide-content (kort tekst → lille modal, tabel → stor modal). Skaber visuelt "hop" når bruger navigerer mellem slides.

## Mål

Modal som ren lightbox-overlay: fokuseret, konsekvent, klinisk-professionel, matcher app's øvrige visuelle udtryk (square corners, hospital-blå, Mari/Arial typografi).

## Design-spec

### Modal-frame

| Property | Value |
|---|---|
| Bredde | 960px (custom, mellem Bootstrap lg=800 og xl=1140) |
| Højde | 520px fixed (40px dots + 460px slide + 20px buffer) |
| Border-radius | 0px (square corners, matcher app-stil) |
| Border | 1px solid #b8b8b8 (ui_grey_soft) |
| Box-shadow | 0 16px 48px rgba(0,0,0,0.22) |
| Background | white |

### Backdrop

| Property | Value |
|---|---|
| Color | rgba(0, 30, 60, 0.6) — mørk hospital-blå tinge |
| Behavior | Klik udenfor lukker modal (`easyClose = TRUE` semantik) |

### Slide-layout: 50/50 split

Hver slide er 460px høj og delt i to kolonner (50/50):

**Venstre kolonne (50%):**
- **Hvis billede:** linear-gradient(135deg, #ccebfa 0%, #e8f4f8 100%) baggrund + screenshot centreret (object-fit: contain)
- **Hvis NULL/mangler:** linear-gradient(135deg, #007dbb 0%, #00293d 100%) + stort trin-nummer (96px font-weight 800) + label "Trin X" (12px uppercase letter-spacing 0.14em opacity 0.85). Decorativ cirkel-overlays (rgba white 0.06 + 0.08).

**Højre kolonne (50%):**
- Padding: 32px 36px
- Step-chip: "Trin X / 7" pill (4px 11px padding, rgba(0,125,187,0.12) bg, #007dbb tekst, 10px font-weight 700 letter-spacing 0.08em uppercase, square corners)
- Title: 22px font-weight 600 color #1a2a30 line-height 1.2 margin-bottom 12px
- Body: 13px line-height 1.55 color #4b5659. Indeholder rich Shiny tags (paragraphs, dl, table, alerts).
- Tabel-styling: 11px font-size, 1px ui_grey_soft border, ui_grey_light header bg
- Alert-styling: subtle background, 1px border, 8px 12px padding, 11.5px font-size

### Navigation

**Indicator dots (bunden):**
- 7 dots, 8x8px, square corners (0px)
- Inactive: rgba(0, 37, 85, 0.22)
- Active: #007dbb, 22x8px (pill der strækker)
- Container: 16px padding top+bottom, white bg, 1px ebebeb border-top
- Klikbare for direct navigation

**Pile (sidearrows):**
- Position: absolute, top 50% transform translateY(-50%)
- 38x38px square (matcher modal-frame square corners)
- Background: rgba(0, 37, 85, 0.7)
- Color: white, font-size 20px
- 1px solid rgba(255,255,255,0.15) border
- Position: prev=left:14px, next=right:14px
- Klik triggerer Bootstrap carousel slide-event

**Close-knap:**
- Custom X øverst-højre
- 28x28px square, top:14px right:16px
- Background: rgba(255,255,255,0.85), 1px solid #d6d6d6
- Color: #565656, font-size 18px
- Klikker triggerer `removeModal()`

### Hvad fjernes vs. nuværende

| Element | Nuværende | Nyt |
|---|---|---|
| Modal-header med titel | "Sådan bruger du appen" h4 | FJERNET |
| Modal-footer "Luk"-knap | `modalButton("Luk")` | FJERNET |
| Bootstrap default X-knap | I modal-header | ERSTATTET med custom X |
| Lead-tekst | "biSPCharts hjælper dig fra data..." | FJERNET |
| Slide-højde | Variabel (auto) | Fixed 460px |
| Border-radius | 16-24px | 0px |

## Implementation-strategi

### Fil-ændringer

| Fil | Ændring |
|---|---|
| `R/mod_app_guide_ui.R` | Refactor `mod_app_guide_ui()`: returner KUN carousel (drop `lead`-paragraph). Refactor `show_app_guide_modal()`: byg custom modal-markup via `tags$div(class="modal app-guide-modal", ...)` + `showModal()`, ej `modalDialog()` (som tvinger header/footer-struktur). Tilføj custom X-knap. |
| `R/utils_ui_app_layout.R` | Slet/erstat eksisterende `.intro-carousel-*` CSS-blok. Tilføj ny CSS-blok `.app-guide-modal-*` med 960×520 fixed sizing, square corners, decorativ gradient-fallback, custom dots/arrows/X. |
| `tests/testthat/test-mod-app-guide-ui.R` | Opdater asserts: drop "Sådan bruger du appen"-titel-assert (intet h1 længere). Tilføj asserts for custom X-knap, fixed højde-class, square-corners-class. |

### Custom modal-implementation

Brug Bootstrap 5 modal-markup direkte i stedet for `shiny::modalDialog()`:

```r
show_app_guide_modal <- function(session = shiny::getDefaultReactiveDomain()) {
  shiny::showModal(
    shiny::tags$div(
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
    ),
    session = session
  )
}
```

Dette giver fuld kontrol over markup uden Shiny modalDialog's header/footer-tvang.

### CSS-struktur (i `utils_ui_app_layout.R` `create_ui_header()`)

Tilføj ny class-prefix `.app-guide-*` for at undgå konflikter med eksisterende `.intro-carousel-*`. Behold `.intro-carousel-*` hvis senere genbrug på andre sider; alternativt fjern hvis kun app-guide bruger det.

```css
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
}
.app-guide-modal-content {
  position: relative;
  height: 520px;
  overflow: hidden;
}
.app-guide-close { ... }
.app-guide-slide { height: 460px; ... }
.app-guide-media--image { background: linear-gradient(135deg, #ccebfa, #e8f4f8); }
.app-guide-media--decor { background: linear-gradient(135deg, #007dbb, #00293d); ... }
.app-guide-decor-num { font-size: 96px; ... }
/* ... osv. */
```

### Backdrop

Bootstrap default `.modal-backdrop.show` er rgba(0,0,0,0.5). Behold default —
hospital-blå tinge er nice-to-have, ej must-have, og global override kan
påvirke andre modals i appen (cookie-consent, kolonne-mapping, navigation-guard).
Hvis det ønskes senere, tilføj `body.app-guide-modal-open .modal-backdrop`
override via JS-class-toggle ved show/hide.

## Tests

Opdaterede asserts:
1. `mod_app_guide_ui()` returnerer carousel-content uden h1/lead
2. `show_app_guide_modal()` rendrerer modal med class `app-guide-modal`
3. Modal indeholder custom `.app-guide-close` X-knap
4. Modal-content har class `.app-guide-modal-content` med fixed højde
5. Slides har konsekvent `.app-guide-slide` class med fixed højde
6. Decorativ fallback rendrerer når `image_src = NULL` (med `.app-guide-media--decor` + trin-nummer)
7. Image-side rendrerer når `image_src` er sat (med `.app-guide-media--image`)
8. 7 slides + 7 indicators bevares fra eksisterende implementation
9. Bootstrap 5-attrs (`data-bs-target`, `data-bs-slide-to`, `data-bs-dismiss`) korrekt sat

## Out-of-scope

- Animation mellem slides ud over Bootstrap default fade
- Auto-rotation (eksplicit deaktiveret via `data-bs-interval=false`)
- Touch-swipe customization (Bootstrap default touch-handling)
- Hospital-color CSS-token-interpolation via `get_hospital_colors()` — bevares hardcoded i CSS-blok (matcher eksisterende `utils_ui_app_layout.R`-konvention; kan refactores senere som separat task)
- Persistent "Vis ikke igen"-toggle eller progress-tracking
- Screenshots til de 4 manglende slides (bruger laver dem separat — fallback gradient håndterer indtil da)
