# test-observer-leak-overwrite-487.R
# Regression-test for #487: register_observer + observer_manager.add destruerer
# eksisterende observer ved navne-overwrite. Foer fix forblev overskrevne
# observers aktive i Shiny's reactive graph (zombie-observers) — registry
# rummede kun nyeste, saa session-cleanup ramte dem ikke.

# Mock-observer der raporterer destroy-kald via flag i parent-env.
make_mock_observer <- function(env, key) {
  env[[key]] <- FALSE
  list(
    destroy = function() env[[key]] <- TRUE
  )
}

test_that("observer_manager.add destruerer eksisterende observer ved navne-overwrite (#487)", {
  mgr <- observer_manager()
  state <- new.env()

  obs1 <- make_mock_observer(state, "obs1_destroyed")
  obs2 <- make_mock_observer(state, "obs2_destroyed")

  mgr$add(obs1, name = "shared_name")
  expect_false(state$obs1_destroyed)

  mgr$add(obs2, name = "shared_name") # Overwrite — skal destruere obs1
  expect_true(state$obs1_destroyed,
    info = "obs1 skal vaere destroyed naar obs2 overskriver samme navn"
  )
  expect_false(state$obs2_destroyed,
    info = "obs2 (nye observer) maa ikke destrueres umiddelbart efter add"
  )

  # Cleanup_all destruerer kun obs2 (nyeste)
  mgr$cleanup_all()
  expect_true(state$obs2_destroyed)
})

test_that("observer_manager.add tilfoejer uden destroy hvis navn er nyt (#487)", {
  mgr <- observer_manager()
  state <- new.env()

  obs1 <- make_mock_observer(state, "obs1_destroyed")
  mgr$add(obs1, name = "name_a")
  expect_false(state$obs1_destroyed)
  expect_equal(mgr$count(), 1)
})

test_that("observer_manager.add tolererer eksisterende observer uden destroy-method (#487)", {
  mgr <- observer_manager()
  bad_observer <- list(value = 1) # Ingen $destroy
  good_observer <- shiny::observe({})

  mgr$add(bad_observer, name = "x")
  expect_silent(mgr$add(good_observer, name = "x"))
  good_observer$destroy()
})

test_that("observer_manager.add fanger destroy-fejl uden at crashe (#487)", {
  mgr <- observer_manager()
  failing_obs <- list(destroy = function() stop("simuleret fejl"))
  next_obs <- shiny::observe({})

  mgr$add(failing_obs, name = "x")

  # log_warn forventes; mgr$add maa ikke kaste
  expect_no_error(mgr$add(next_obs, name = "x"))
  next_obs$destroy()
})
