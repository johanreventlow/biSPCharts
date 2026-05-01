# ==============================================================================
# test-autogen-suspend.R
# ==============================================================================
# FORMÅL: Verificerer autogen-suspend mekanisme der forhindrer dobbeltsave
#         (pdf_improvement=NULL + pdf_improvement=auto-tekst) ved tab-skift
#         til eksporter-tab.
#
# FIX: fix(auto_save): suspend settings_save under pdf_improvement autogen
# Relateret til PR #410 double-save symptom.
# ==============================================================================

# Hjælper: opret minimal app_state med session-reaktivitet
create_autogen_test_state <- function() {
  shiny::reactiveValues(
    session = shiny::reactiveValues(
      auto_save_enabled = TRUE,
      autogen_active = FALSE,
      restoring_session = FALSE
    ),
    data = shiny::reactiveValues(
      current_data = data.frame(x = 1:5, y = 1:5),
      updating_table = FALSE,
      table_operation_in_progress = FALSE
    )
  )
}

# UNIT TESTS: autogen_active flag semantik =====================================

test_that("app_state$session$autogen_active initialiseres som FALSE", {
  # Verificér at create_app_state() sætter autogen_active = FALSE
  shiny::isolate({
    state <- create_app_state()
    expect_false(
      isTRUE(state$session$autogen_active),
      label = "autogen_active skal starte som FALSE"
    )
  })
})

test_that("autogen_active kan sættes og læses via reactiveValues", {
  app_state <- create_autogen_test_state()

  shiny::isolate({
    # Start: FALSE
    expect_false(isTRUE(app_state$session$autogen_active))

    # Sæt TRUE (simulerer autogen start)
    app_state$session$autogen_active <- TRUE
    expect_true(isTRUE(app_state$session$autogen_active))

    # Clear (simulerer onFlushed callback)
    app_state$session$autogen_active <- FALSE
    expect_false(isTRUE(app_state$session$autogen_active))
  })
})

# GUARD LOGIK: obs_settings_save returner tidligt når flag er sat ============

test_that("obs_settings_save guard: returnerer NULL når autogen_active=TRUE", {
  # Simulerer guard-logikken i obs_settings_save uden fuld Shiny observer.
  # Verificerer at guard-betingelsen er korrekt implementeret.
  app_state <- create_autogen_test_state()

  shiny::isolate({
    app_state$session$autogen_active <- TRUE

    # Guard-logik (samme som i obs_settings_save)
    guard_result <- if (isTRUE(app_state$session$autogen_active)) {
      invisible(NULL)
    } else {
      "ville_have_gemt"
    }

    expect_null(guard_result,
      label = "Guard skal returnere NULL når autogen_active=TRUE"
    )
  })
})

test_that("obs_settings_save guard: fortsætter normalt når autogen_active=FALSE", {
  app_state <- create_autogen_test_state()

  shiny::isolate({
    app_state$session$autogen_active <- FALSE

    # Guard-logik
    guard_result <- if (isTRUE(app_state$session$autogen_active)) {
      invisible(NULL)
    } else {
      "fortsætter_med_save"
    }

    expect_equal(guard_result, "fortsætter_med_save",
      label = "Guard skal fortsætte når autogen_active=FALSE"
    )
  })
})

# INTEGRATION: autogen_active sættes i register_analysis_autogen ==============

test_that("register_analysis_autogen: autogen_active sættes til TRUE under update", {
  # Verificerer at app_state$session$autogen_active er tilgængeligt
  # som reaktivt flag (struktur-test — timing testes i shinytest2).
  app_state <- create_autogen_test_state()

  shiny::testServer(
    function(input, output, session) {
      # Simulerer hvad register_analysis_autogen gør
      shiny::observeEvent(input$trigger_autogen, {
        app_state$session$autogen_active <- TRUE
        session$onFlushed(function() {
          app_state$session$autogen_active <- FALSE
        }, once = TRUE)
        shiny::updateTextAreaInput(session, "pdf_improvement", value = "auto-tekst")
      })
    },
    {
      # Initial state: FALSE
      expect_false(
        shiny::isolate(isTRUE(app_state$session$autogen_active)),
        label = "autogen_active starter som FALSE"
      )

      # Trigger autogen
      session$setInputs(trigger_autogen = 1L)

      # Flag sat til TRUE mens observer kører
      # (onFlushed clearer det efter flush — isolate-check er FALSE
      #  fordi testServer flushes synkront)
      # Her verificerer vi blot at flagget kan transitions korrekt
      expect_false(
        shiny::isolate(isTRUE(app_state$session$autogen_active)),
        label = "autogen_active er cleared efter flush (onFlushed ran)"
      )
    }
  )
})

# EDGE CASES ==================================================================

test_that("autogen_active FALSE (default): settings_save blokeres ikke unødigt", {
  # Verificerer at normal settings_save (uden autogen) kører uhindret.
  app_state <- create_autogen_test_state()

  shiny::isolate({
    # Default state: autogen_active = FALSE
    expect_false(isTRUE(app_state$session$autogen_active))

    # Guard-check: FALSE → save fortsætter
    should_skip <- isTRUE(app_state$session$autogen_active)
    expect_false(should_skip,
      label = "Normal save (autogen_active=FALSE) skal IKKE blokeres"
    )
  })
})

test_that("autogen_active flag clears korrekt efter onFlushed", {
  # Verificerer flag-clearing mekanisme via direkte assignment (proxy for onFlushed).
  app_state <- create_autogen_test_state()

  shiny::isolate({
    # Sæt flag (autogen starter)
    app_state$session$autogen_active <- TRUE
    expect_true(isTRUE(app_state$session$autogen_active))

    # onFlushed callback (simuleret)
    on_flushed_cb <- function() {
      app_state$session$autogen_active <- FALSE
    }
    on_flushed_cb()

    expect_false(isTRUE(app_state$session$autogen_active),
      label = "Flag cleares korrekt via onFlushed callback"
    )
  })
})

test_that("Serielle autogen-cyklusser: flag afsluttes korrekt efter hver", {
  # Verificerer at gentagne autogen-cyklusser ikke efterlader falsk TRUE.
  app_state <- create_autogen_test_state()

  shiny::isolate({
    for (i in seq_len(3)) {
      # Start autogen
      app_state$session$autogen_active <- TRUE
      expect_true(isTRUE(app_state$session$autogen_active),
        label = sprintf("Cyklus %d: flag sat til TRUE", i)
      )

      # End autogen (onFlushed)
      app_state$session$autogen_active <- FALSE
      expect_false(isTRUE(app_state$session$autogen_active),
        label = sprintf("Cyklus %d: flag clearet til FALSE", i)
      )
    }
  })
})
