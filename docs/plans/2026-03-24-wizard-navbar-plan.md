# Wizard Navbar Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Omdanne navbar til nummereret wizard-flow med progressive unlock gates.

**Architecture:** Bygger på eksisterende bslib::page_navbar() med CSS for nummercirkler, et lille JS-fil for lock/unlock, og server-side gate-logik via sendCustomMessage.

**Tech Stack:** bslib, shinyjs, custom CSS + JS

---

### Task 1: Tilføj wizard-nav.js

**Files:**
- Create: `inst/app/www/wizard-nav.js`

**Step 1: Opret JS-filen**

```javascript
// wizard-nav.js — Wizard navigation lock/unlock logic
(function() {
  // Lock a wizard step (prevent clicking)
  Shiny.addCustomMessageHandler('wizard-lock-step', function(step) {
    var links = document.querySelectorAll('[data-step="' + step + '"]');
    links.forEach(function(link) {
      link.classList.add('wizard-locked');
    });
  });

  // Unlock a wizard step (allow clicking)
  Shiny.addCustomMessageHandler('wizard-unlock-step', function(step) {
    var links = document.querySelectorAll('[data-step="' + step + '"]');
    links.forEach(function(link) {
      link.classList.remove('wizard-locked');
    });
  });

  // Intercept clicks on locked tabs
  document.addEventListener('click', function(e) {
    var navLink = e.target.closest('.wizard-locked');
    if (navLink) {
      e.preventDefault();
      e.stopImmediatePropagation();
    }
  }, true);
})();
```

**Step 2: Commit**

```bash
git add inst/app/www/wizard-nav.js
git commit -m "feat(wizard): tilfoej wizard-nav.js for lock/unlock logik"
```

---

### Task 2: Tilføj wizard CSS og JS-loading i create_ui_header()

**Files:**
- Modify: `R/ui_app_ui.R` — `create_ui_header()` funktion

**Step 1: Tilføj JS-script tag i create_ui_header()**

I `create_ui_header()`, efter linjen `shiny::tags$script(src = "shiny-handlers.js"),` tilføj:

```r
shiny::tags$script(src = "wizard-nav.js"),
```

**Step 2: Tilføj wizard CSS i samme funktion**

I inline CSS-blokken (inde i `shiny::tags$style(htmltools::HTML(paste0("...")))`), tilføj dette CSS:

```css
/* Wizard nummererede trin */
.navbar-nav .nav-link[data-step]::before {
  content: attr(data-step);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 24px;
  height: 24px;
  border-radius: 50%;
  border: 2px solid currentColor;
  font-size: 12px;
  font-weight: 700;
  margin-right: 6px;
  flex-shrink: 0;
}

/* Aktiv tab: filled cirkel */
.navbar-nav .nav-link.active[data-step]::before {
  background-color: #375a7f;
  color: white;
  border-color: #375a7f;
}

/* Locked tab styling */
.navbar-nav .nav-link.wizard-locked {
  opacity: 0.4 !important;
  cursor: not-allowed !important;
  pointer-events: auto !important;
}

.navbar-nav .nav-link.wizard-locked:hover {
  opacity: 0.4 !important;
}
```

**Step 3: Commit**

```bash
git add R/ui_app_ui.R
git commit -m "feat(wizard): tilfoej wizard CSS og JS-loading i header"
```

---

### Task 3: Tilføj data-step attributter og navbar id i app_ui.R

**Files:**
- Modify: `R/app_ui.R` — `app_ui()` funktion

**Step 1: Tilføj id til page_navbar**

Ændre `bslib::page_navbar(` til at inkludere `id = "main_navbar"`:

```r
bslib::page_navbar(
  id = "main_navbar",
  title = shiny::tagList(
```

**Step 2: Tilføj data-step attributter til nav_panels**

Wrap hvert `bslib::nav_panel()` med `shiny::tagAppendAttributes()`:

Upload (trin 1):
```r
bslib::nav_panel(
  title = "Upload",
  icon = shiny::icon("upload"),
  value = "upload",
  create_ui_upload_page()
) |> shiny::tagAppendAttributes(`data-step` = "1", .cssSelector = "a.nav-link")
```

Analysér (trin 2):
```r
bslib::nav_panel(
  title = "Analysér",
  icon = shiny::icon("chart-line"),
  value = "analyser",
  create_ui_main_content()
) |> shiny::tagAppendAttributes(`data-step` = "2", .cssSelector = "a.nav-link")
```

Eksportér (trin 3):
```r
bslib::nav_panel(
  title = "Eksportér",
  icon = shiny::icon("file-export"),
  value = "eksporter",
  mod_export_ui("export")
) |> shiny::tagAppendAttributes(`data-step` = "3", .cssSelector = "a.nav-link")
```

**Step 3: Commit**

```bash
git add R/app_ui.R
git commit -m "feat(wizard): tilfoej navbar id og data-step attributter"
```

---

### Task 4: Tilføj server-side wizard gate-logik

**Files:**
- Modify: `R/app_server_main.R` eller `R/utils_server_event_listeners.R` — tilføj wizard observers

**Step 1: Find korrekt placering**

Gate-logikken skal tilføjes i `setup_event_listeners()` i `R/utils_server_event_listeners.R`, efter de eksisterende observers.

**Step 2: Tilføj wizard gate observers**

Tilføj i bunden af `setup_event_listeners()` (eller som ny funktion `setup_wizard_gates()` kaldt derfra):

```r
# === WIZARD NAVIGATION GATES ===

# Lock trin 2+3 ved startup
session$sendCustomMessage("wizard-lock-step", 2)
session$sendCustomMessage("wizard-lock-step", 3)

# Gate: Data loaded -> unlock trin 2
observeEvent(app_state$events$data_updated, ignoreInit = TRUE,
  priority = OBSERVER_PRIORITIES$UI_SYNC, {
  has_data <- !is.null(shiny::isolate(app_state$data$current_data))
  if (has_data) {
    session$sendCustomMessage("wizard-unlock-step", 2)
    # Auto-navigér til Analysér efter upload
    bslib::nav_select("main_navbar", selected = "analyser", session = session)
  } else {
    # Data fjernet (ny session) -> lock trin 2+3
    session$sendCustomMessage("wizard-lock-step", 2)
    session$sendCustomMessage("wizard-lock-step", 3)
    bslib::nav_select("main_navbar", selected = "upload", session = session)
  }
})

# Gate: Plot renderet -> unlock trin 3
observe({
  plot_ready <- app_state$visualization$plot_ready
  if (isTRUE(plot_ready)) {
    session$sendCustomMessage("wizard-unlock-step", 3)
  } else {
    session$sendCustomMessage("wizard-lock-step", 3)
  }
})
```

**Step 3: Commit**

```bash
git add R/utils_server_event_listeners.R
git commit -m "feat(wizard): tilfoej server-side gate-logik for wizard navigation"
```

---

### Task 5: Test manuelt og verificer

**Step 1: Start app**

```r
source("app.R")
```

**Step 2: Verificer wizard behavior**

Tjekliste:
- [ ] Trin 1 (Upload) er altid tilgængeligt og aktivt ved start
- [ ] Trin 2 (Analysér) er grå/locked ved start
- [ ] Trin 3 (Eksportér) er grå/locked ved start
- [ ] Klik på locked tabs gør ingenting
- [ ] Numre (1, 2, 3) vises som cirkler foran tab-tekst
- [ ] Aktiv tab har filled cirkel
- [ ] Upload data -> trin 2 unlockes automatisk
- [ ] App navigerer automatisk til trin 2 efter upload
- [ ] Trin 3 unlockes når SPC-diagram renderes
- [ ] "Start ny session" -> trin 2+3 lockes, navigerer til trin 1
- [ ] Fra trin 3 kan man frit gå tilbage til trin 1 eller 2

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat(wizard): komplet wizard navbar med progressive unlock"
```

---

### Opsummering

| Task | Beskrivelse | Filer |
|------|-------------|-------|
| 1 | wizard-nav.js | Ny: inst/app/www/wizard-nav.js |
| 2 | CSS + JS-loading | Modify: R/ui_app_ui.R |
| 3 | data-step attributter + navbar id | Modify: R/app_ui.R |
| 4 | Server-side gate-logik | Modify: R/utils_server_event_listeners.R |
| 5 | Manuel test og verificering | Ingen filer |
