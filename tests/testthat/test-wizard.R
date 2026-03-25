# test-wizard.R
# ==============================================================================
# TEST SUITE: Wizard navigation, gates og paste-data
# ==============================================================================
#
# FORMÅL: Dedikerede tests for wizard-specifik funktionalitet
# FOKUS: handle_paste_data parsing, gate-logik, sample data, edge cases
#
# ==============================================================================

library(testthat)
library(shiny)
library(readr)

# HELPERS ======================================================================

# Loekker package-sti, project-root, og test_path for at finde inst-filer
resolve_inst_path <- function(...) {
  rel <- file.path(...)
  p <- system.file(..., package = "SPCify")
  if (p != "" && file.exists(p)) {
    return(p)
  }
  if (file.exists(file.path("inst", rel))) {
    return(file.path("inst", rel))
  }
  alt <- file.path(testthat::test_path(), "..", "..", "inst", rel)
  if (file.exists(alt)) {
    return(alt)
  }
  file.path("inst", rel) # fallback, lad testen skippe
}

# ==============================================================================
# 1. handle_paste_data() — PARSING TESTS
# ==============================================================================
# handle_paste_data() kræver Shiny-context (showNotification, isolate, emit).
# Tester parsing-logikken direkte via readr
# for at verificere separator-detection.

describe("Paste data parsing (separator auto-detection)", {
  it("parser tab-separeret data korrekt", {
    text <- "Dato\tVaerdi\n2024-01-01\t10\n2024-02-01\t15\n2024-03-01\t20"
    data <- readr::read_delim(
      I(text),
      delim = NULL,
      locale = readr::locale(decimal_mark = ",", grouping_mark = "."),
      show_col_types = FALSE, trim_ws = TRUE
    )
    expect_equal(nrow(data), 3)
    expect_equal(ncol(data), 2)
    expect_true("Dato" %in% names(data))
    expect_true("Vaerdi" %in% names(data))
  })

  it("parser semikolon-separeret data (dansk CSV)", {
    text <- "Dato;Vaerdi\n2024-01-01;10,5\n2024-02-01;15,3\n2024-03-01;20,1"
    data <- readr::read_delim(
      I(text),
      delim = NULL,
      locale = readr::locale(decimal_mark = ",", grouping_mark = "."),
      show_col_types = FALSE, trim_ws = TRUE
    )
    expect_equal(nrow(data), 3)
    expect_equal(ncol(data), 2)
  })

  it("parser komma-separeret data (international CSV)", {
    text <- "Date,Value\n2024-01-01,10\n2024-02-01,15\n2024-03-01,20"
    data <- readr::read_delim(
      I(text),
      delim = NULL,
      locale = readr::locale(decimal_mark = ",", grouping_mark = "."),
      show_col_types = FALSE, trim_ws = TRUE
    )
    expect_equal(nrow(data), 3)
    expect_true("Date" %in% names(data))
  })

  it("fallback til eksplicit separator naar auto-detect fejler", {
    # Tekst som readr maske ikke auto-detecter
    text <- "A\tB\n1\t2\n3\t4"
    result <- NULL
    for (sep in c("\t", ";", ",")) {
      parsed <- tryCatch(
        readr::read_delim(
          I(text),
          delim = sep,
          locale = readr::locale(decimal_mark = ",", grouping_mark = "."),
          show_col_types = FALSE, trim_ws = TRUE
        ),
        error = function(e) NULL
      )
      if (!is.null(parsed) && ncol(parsed) >= 2) {
        result <- parsed
        break
      }
    }
    expect_false(is.null(result))
    expect_equal(ncol(result), 2)
  })

  it("haandterer danske tegn (æøå) i kolonnenavne", {
    text <- "Måned\tVærdi\n2024-01\t10\n2024-02\t15"
    data <- readr::read_delim(
      I(text),
      delim = NULL,
      locale = readr::locale(decimal_mark = ",", grouping_mark = "."),
      show_col_types = FALSE, trim_ws = TRUE
    )
    expect_equal(nrow(data), 2)
    expect_equal(ncol(data), 2)
  })

  it("haandterer store datasets (200 raekker)", {
    dates <- seq(as.Date("2020-01-01"), by = "month", length.out = 200)
    values <- round(runif(200, 5, 50), 1)
    lines <- c("Dato\tVaerdi", paste(dates, values, sep = "\t"))
    text <- paste(lines, collapse = "\n")

    data <- readr::read_delim(
      I(text),
      delim = NULL,
      locale = readr::locale(decimal_mark = ",", grouping_mark = "."),
      show_col_types = FALSE, trim_ws = TRUE
    )
    expect_equal(nrow(data), 200)
    expect_equal(ncol(data), 2)
  })
})

# ==============================================================================
# 2. handle_paste_data() — VALIDATION EDGE CASES
# ==============================================================================

describe("Paste data input validering", {
  it("enkelt kolonne fejler auto-detect eller giver ncol < 2", {
    text <- "Vaerdi\n10\n15\n20"
    # readr kan ikke gaette separator for enkelt kolonne -> error
    # handle_paste_data fanger dette via tryCatch og fallback-loop
    data <- tryCatch(
      readr::read_delim(
        I(text),
        delim = NULL,
        locale = readr::locale(decimal_mark = ",", grouping_mark = "."),
        show_col_types = FALSE, trim_ws = TRUE
      ),
      error = function(e) NULL
    )
    # Enten NULL (auto-detect fejl) eller ncol < 2
    expect_true(is.null(data) || ncol(data) < 2)
  })

  it("data med kun header (0 raekker) afvises", {
    text <- "Dato\tVaerdi"
    data <- readr::read_delim(
      I(text),
      delim = NULL,
      locale = readr::locale(decimal_mark = ",", grouping_mark = "."),
      show_col_types = FALSE, trim_ws = TRUE
    )
    expect_equal(nrow(data), 0)
  })
})

# ==============================================================================
# 3. WIZARD GATE-LOGIK TESTS
# ==============================================================================

describe("Wizard gate-logik (setup_wizard_gates)", {
  it("gate funktioner eksisterer og er callable", {
    expect_true(is.function(setup_wizard_gates))
    expect_true(is.function(setup_paste_data_observers))
    # Verificér forventede parametre
    gate_args <- names(formals(setup_wizard_gates))
    expect_true("input" %in% gate_args)
    expect_true("app_state" %in% gate_args)
    expect_true("session" %in% gate_args)
  })

  it("paste_data_observers kræver input, app_state, session, emit", {
    paste_args <- names(formals(setup_paste_data_observers))
    expect_true("input" %in% paste_args)
    expect_true("app_state" %in% paste_args)
    expect_true("session" %in% paste_args)
    expect_true("emit" %in% paste_args)
  })
})

# ==============================================================================
# 4. APP STATE WIZARD-RELATEREDE FELTER
# ==============================================================================

describe("App state wizard-felter", {
  it("create_app_state inkluderer visualization state", {
    app_state <- create_app_state()
    # visualization sub-state bruges til gate 3 (plot_ready)
    expect_false(is.null(app_state$visualization))
  })

  it("create_app_state inkluderer events for wizard gates", {
    app_state <- create_app_state()
    # data_updated event bruges til gate 2
    expect_equal(
      shiny::isolate(app_state$events$data_updated), 0L
    )
    # navigation_changed event bruges af paste-data
    expect_equal(
      shiny::isolate(app_state$events$navigation_changed), 0L
    )
  })

  it("create_app_state initialiserer data som NULL", {
    app_state <- create_app_state()
    expect_null(shiny::isolate(app_state$data$current_data))
    expect_null(shiny::isolate(app_state$data$original_data))
  })

  it("set_current_data opdaterer app_state korrekt", {
    app_state <- create_app_state()
    test_data <- data.frame(x = 1:5, y = 6:10)
    set_current_data(app_state, test_data)
    result <- shiny::isolate(app_state$data$current_data)
    expect_equal(nrow(result), 5)
    expect_equal(names(result), c("x", "y"))
  })

  it("emit API kan oprettes fra app_state", {
    app_state <- create_app_state()
    emit <- create_emit_api(app_state)

    expect_true(is.function(emit$data_updated))
    expect_true(is.function(emit$navigation_changed))

    # Emit data_updated og verificér event tæller stiger
    old_val <- shiny::isolate(app_state$events$data_updated)
    emit$data_updated(context = "test")
    new_val <- shiny::isolate(app_state$events$data_updated)
    expect_equal(new_val, old_val + 1L)
  })
})

# ==============================================================================
# 5. SAMPLE DATA TESTS
# ==============================================================================

describe("Sample SPC datasaet", {
  sample_path <- resolve_inst_path("extdata", "sample_spc_data.csv")

  it("sample fil eksisterer", {
    expect_true(file.exists(sample_path))
  })

  it("sample data har mindst 2 kolonner og 10 raekker", {
    skip_if(!file.exists(sample_path), "Sample data ikke tilgaengelig")
    text <- paste(readLines(sample_path, warn = FALSE, encoding = "UTF-8"),
      collapse = "\n"
    )
    data <- readr::read_delim(
      I(text),
      delim = NULL,
      locale = readr::locale(decimal_mark = ",", grouping_mark = "."),
      show_col_types = FALSE, trim_ws = TRUE
    )
    expect_true(ncol(data) >= 2)
    expect_true(nrow(data) >= 10)
  })

  it("sample data kan parses med semikolon-separator", {
    skip_if(!file.exists(sample_path), "Sample data ikke tilgaengelig")
    # sample_spc_data.csv er csv2 format (semikolon)
    data <- readr::read_csv2(sample_path, show_col_types = FALSE)
    expect_true(ncol(data) >= 2)
    expect_true(nrow(data) >= 10)
  })
})

# ==============================================================================
# 6. WIZARD-NAV.JS STRUKTUR TESTS
# ==============================================================================

describe("wizard-nav.js", {
  js_path <- resolve_inst_path("app", "www", "wizard-nav.js")

  it("wizard-nav.js eksisterer", {
    expect_true(file.exists(js_path))
  })

  it("indeholder lock/unlock message handlers", {
    skip_if(!file.exists(js_path))
    content <- paste(readLines(js_path, warn = FALSE), collapse = "\n")
    expect_true(grepl("wizard-lock-step", content))
    expect_true(grepl("wizard-unlock-step", content))
  })

  it("indeholder pending message koe for race condition prevention", {
    skip_if(!file.exists(js_path))
    content <- paste(readLines(js_path, warn = FALSE), collapse = "\n")
    expect_true(grepl("pendingMessages", content))
    expect_true(grepl("wizardReady", content))
  })

  it("indeholder step mapping for alle 3 trin", {
    skip_if(!file.exists(js_path))
    content <- paste(readLines(js_path, warn = FALSE), collapse = "\n")
    expect_true(grepl("upload", content))
    expect_true(grepl("analyser", content))
    expect_true(grepl("eksporter", content))
  })
})

# ==============================================================================
# 7. MODAL CLOSE EVENT (shiny-handlers.js)
# ==============================================================================

describe("Modal close JS handler", {
  js_path <- resolve_inst_path("app", "www", "shiny-handlers.js")

  it("shiny-handlers.js eksisterer (modal handler fjernet i #171)", {
    # modal_closed_event handleren blev fjernet i #171 (dead code oprydning).
    # Hvis den genimplementeres (se #50), opdater denne test.
    skip_if(!file.exists(js_path))
    content <- paste(readLines(js_path, warn = FALSE), collapse = "\n")
    expect_true(nchar(content) > 0)
  })
})
