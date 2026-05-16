# test-export-effective-analysis.R
# Regression-tests for cycle 11 H1 (Codex peer-review 2026-05-16):
# compute_effective_analysis_text() vaelger mellem bruger-redigeret tekst
# og auto-genereret analyse-tekst. Eliminerer dobbelt preview-render-bug
# hvor pdf_preview_image lyttede direkte paa debounced input.

test_that("compute_effective_analysis_text returner auto_text naar user_text er tom", {
  expect_identical(compute_effective_analysis_text("", "Auto-tekst"), "Auto-tekst")
  expect_identical(compute_effective_analysis_text(NULL, "Auto-tekst"), "Auto-tekst")
  expect_identical(compute_effective_analysis_text("   ", "Auto-tekst"), "Auto-tekst")
})

test_that("compute_effective_analysis_text returnerer auto_text naar user_text matcher", {
  # Foreliggende-state: bruger har ikke redigeret (input matcher auto).
  # Preview boer bruge auto-tekst (deterministisk fra server-state).
  expect_identical(
    compute_effective_analysis_text("Auto-tekst", "Auto-tekst"),
    "Auto-tekst"
  )
  # Trim-tolerance: trailing whitespace fra klient-side regnes som no-edit.
  expect_identical(
    compute_effective_analysis_text("Auto-tekst   ", "Auto-tekst"),
    "Auto-tekst"
  )
  expect_identical(
    compute_effective_analysis_text("  Auto-tekst", "  Auto-tekst"),
    "  Auto-tekst"
  )
})

test_that("compute_effective_analysis_text returnerer user_text naar bruger har redigeret", {
  # Bruger har redigeret pdf_improvement-feltet. Preview boer bruge bruger-tekst.
  expect_identical(
    compute_effective_analysis_text("Manuel rettelse", "Auto-tekst"),
    "Manuel rettelse"
  )
})

test_that("compute_effective_analysis_text handterer begge NULL/empty graceful", {
  expect_identical(compute_effective_analysis_text(NULL, NULL), "")
  expect_identical(compute_effective_analysis_text("", ""), "")
  expect_identical(compute_effective_analysis_text(NULL, ""), "")
  expect_identical(compute_effective_analysis_text("", NULL), "")
})

test_that("compute_effective_analysis_text dispatcher korrekt mellem user/auto efter tab-skift-flow", {
  # Simulér tab-skift-flow:
  # T0: tab-skift, auto-tekst endnu ej genereret
  state_t0 <- list(user = "", auto = "")
  expect_identical(
    compute_effective_analysis_text(state_t0$user, state_t0$auto),
    ""
  )

  # T1: autogen-observer satte last_auto_analysis. user-input endnu tom.
  state_t1 <- list(user = "", auto = "Processen udviser ustabilitet...")
  expect_identical(
    compute_effective_analysis_text(state_t1$user, state_t1$auto),
    "Processen udviser ustabilitet..."
  )

  # T2: klient-roundtrip lander input-update (samme som auto).
  state_t2 <- list(
    user = "Processen udviser ustabilitet...",
    auto = "Processen udviser ustabilitet..."
  )
  expect_identical(
    compute_effective_analysis_text(state_t2$user, state_t2$auto),
    "Processen udviser ustabilitet..."
  )

  # T3: bruger redigerer manuelt.
  state_t3 <- list(
    user = "Min egen tolkning af mønstret",
    auto = "Processen udviser ustabilitet..."
  )
  expect_identical(
    compute_effective_analysis_text(state_t3$user, state_t3$auto),
    "Min egen tolkning af mønstret"
  )
})
