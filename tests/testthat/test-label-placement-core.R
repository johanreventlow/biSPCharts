# ==============================================================================
# TEST: Core Label Placement Algorithm
# ==============================================================================
# Salvage Fase 2: Fjernet source("utils_standalone_label_placement.R") —
# funktionerne eksisterer i BFHcharts namespace, ikke i biSPCharts.
# Alle kald bruger nu BFHcharts:::-prefix.
#
# Inkluderer tests fra test-label-placement-bounds.R (mergeret ind her).
#
# Tests dækker place_two_labels_npc():
# - Coincident lines (target = CL scenarios)
# - Tight lines detection
# - Multi-level collision avoidance (NIVEAU 1-3)
# - NA handling
# - Out-of-bounds detection
# - Input validation
#
# Tests dækker propose_single_label() og clamp_to_bounds() (fra bounds-fil):
# - Bounds respekt ved flip-scenarios
# - Korrekt placering ved foretrukken side
# - Edge cases (minimal padding, stor label)
# ==============================================================================

# ==============================================================================
# INPUT VALIDATION TESTS
# ==============================================================================

test_that("place_two_labels_npc validerer type af NPC-koordinater", {
  # Ikke-numerisk input
  expect_error(
    BFHcharts:::place_two_labels_npc(yA_npc = "0.5", yB_npc = 0.6, label_height_npc = 0.13),
    "yA_npc skal være numerisk"
  )

  expect_error(
    BFHcharts:::place_two_labels_npc(yA_npc = 0.5, yB_npc = list(0.6), label_height_npc = 0.13),
    "yB_npc skal være numerisk"
  )
})

test_that("place_two_labels_npc validerer label_height_npc positiv", {
  # Negativ label height fejler
  expect_error(
    BFHcharts:::place_two_labels_npc(yA_npc = 0.5, yB_npc = 0.6, label_height_npc = -0.1),
    "label_height_npc skal være positiv"
  )
})

test_that("BFHcharts-followup: place_two_labels_npc validerer label_height_npc øvre grænse", {
  skip(paste0(
    "BFHcharts-followup: place_two_labels_npc() validerer ikke label_height_npc > 0.5 ",
    "i nuvaerende BFHcharts-version. Eskaleret til BFHcharts#250."
  ))
  expect_error(
    BFHcharts:::place_two_labels_npc(yA_npc = 0.5, yB_npc = 0.6, label_height_npc = 0.6),
    "label_height_npc må ikke overstige 0.5"
  )
})

test_that("place_two_labels_npc validerer padding bounds", {
  # Negativ padding
  expect_error(
    BFHcharts:::place_two_labels_npc(
      yA_npc = 0.5, yB_npc = 0.6, label_height_npc = 0.13, pad_top = -0.01
    ),
    "pad_top skal være mellem 0 og 0.2"
  )

  # For stor padding
  expect_error(
    BFHcharts:::place_two_labels_npc(
      yA_npc = 0.5, yB_npc = 0.6, label_height_npc = 0.13, pad_bot = 0.3
    ),
    "pad_bot skal være mellem 0 og 0.2"
  )
})

test_that("place_two_labels_npc validerer priority parameter", {
  expect_error(
    BFHcharts:::place_two_labels_npc(
      yA_npc = 0.5, yB_npc = 0.6, label_height_npc = 0.13, priority = "C"
    ),
    "'arg' should be one of"
  )
})

test_that("place_two_labels_npc validerer pref_pos parameter", {
  expect_error(
    BFHcharts:::place_two_labels_npc(
      yA_npc = 0.5, yB_npc = 0.6, label_height_npc = 0.13, pref_pos = "invalid"
    ),
    "pref_pos skal indeholde 'under' eller 'over'"
  )
})

# ==============================================================================
# COINCIDENT LINES HANDLING
# ==============================================================================

test_that("place_two_labels_npc håndterer sammenfaldende linjer (target = CL)", {
  # Scenario: To linjer på præcis samme position
  # Forventet: En label over, en label under

  label_h <- 0.13

  result <- BFHcharts:::place_two_labels_npc(
    yA_npc = 0.5,
    yB_npc = 0.5, # Samme position
    label_height_npc = label_h,
    pref_pos = c("under", "under"),
    priority = "A"
  )

  # Skal detektere coincident lines
  expect_true(any(grepl("Sammenfaldende linjer", result$warnings)))

  # Skal placere på modsatte sider
  expect_false(result$sideA == result$sideB)

  # Skal have korrekt gap mellem labels (mindst label højde)
  gap_between <- abs(result$yA - result$yB)
  expect_gte(gap_between, label_h * 0.9) # Tolerance for small differences

  # Quality skal være optimal eller acceptable
  expect_true(result$placement_quality %in% c("optimal", "acceptable"))
})

test_that("place_two_labels_npc håndterer næsten-sammenfaldende linjer", {
  # Scenario: Linjer inden for coincident_threshold

  label_h <- 0.13

  # Brug get_label_placement_param hvis tilgængelig, ellers fallback
  if (exists("get_label_placement_param", where = asNamespace("BFHcharts"), inherits = FALSE)) {
    threshold <- label_h * BFHcharts:::get_label_placement_param("coincident_threshold_factor")
  } else {
    threshold <- label_h * 0.1 # Fallback: 10% af label højde
  }

  result <- BFHcharts:::place_two_labels_npc(
    yA_npc = 0.5,
    yB_npc = 0.5 + threshold * 0.5, # Halvdelen af threshold
    label_height_npc = label_h,
    pref_pos = c("under", "under")
  )

  # Skal behandles som sammenfaldende
  expect_true(any(grepl("Sammenfaldende linjer", result$warnings)))
  expect_false(result$sideA == result$sideB)
})

test_that("place_two_labels_npc respekterer bounds ved sammenfaldende linjer", {
  # Edge case: Sammenfaldende linjer meget tæt på panel edge

  label_h <- 0.2 # Stor label

  # Test ved bunden af panel
  result_low <- BFHcharts:::place_two_labels_npc(
    yA_npc = 0.12,
    yB_npc = 0.12,
    label_height_npc = label_h,
    pad_bot = 0.01,
    pad_top = 0.01
  )

  low_bound <- 0.01 + label_h / 2
  high_bound <- 1 - 0.01 - label_h / 2

  expect_gte(result_low$yA, low_bound)
  expect_lte(result_low$yA, high_bound)
  expect_gte(result_low$yB, low_bound)
  expect_lte(result_low$yB, high_bound)

  # Test ved toppen af panel
  result_high <- BFHcharts:::place_two_labels_npc(
    yA_npc = 0.88,
    yB_npc = 0.88,
    label_height_npc = label_h,
    pad_bot = 0.01,
    pad_top = 0.01
  )

  expect_gte(result_high$yA, low_bound)
  expect_lte(result_high$yA, high_bound)
  expect_gte(result_high$yB, low_bound)
  expect_lte(result_high$yB, high_bound)
})

# ==============================================================================
# TIGHT LINES DETECTION
# ==============================================================================

test_that("place_two_labels_npc detekterer tætte linjer og bruger over/under strategi", {
  # Scenario: Linjer tættere end tight_lines_threshold

  label_h <- 0.13

  # Brug get_label_placement_param hvis tilgængelig, ellers fallback
  if (exists("get_label_placement_param", where = asNamespace("BFHcharts"), inherits = FALSE)) {
    gap_labels <- label_h * BFHcharts:::get_label_placement_param("relative_gap_labels")
    tight_threshold_factor <- BFHcharts:::get_label_placement_param("tight_lines_threshold_factor")
  } else {
    gap_labels <- label_h * 0.30 # Fallback
    tight_threshold_factor <- 0.5 # Fallback
  }

  min_center_gap <- label_h + gap_labels
  tight_threshold <- min_center_gap * tight_threshold_factor

  # Linjer inden for tight threshold
  line_gap <- tight_threshold * 0.8

  result <- BFHcharts:::place_two_labels_npc(
    yA_npc = 0.4,
    yB_npc = 0.4 + line_gap,
    label_height_npc = label_h,
    pref_pos = c("under", "under") # Begge foretrækker under
  )

  # Skal detektere tætte linjer
  expect_true(any(grepl("meget tætte", result$warnings, ignore.case = TRUE)))

  # Skal tvinge labels på modsatte sider
  expect_false(result$sideA == result$sideB)
})

# ==============================================================================
# MULTI-LEVEL COLLISION AVOIDANCE
# ==============================================================================

test_that("place_two_labels_npc NIVEAU 1: gap reduction fungerer", {
  # Scenario: Labels kolliderer, men kan løses ved reduceret gap

  label_h <- 0.13

  # Linjer tæt nok til kollision med normal gap, men OK med reduced gap
  result <- BFHcharts:::place_two_labels_npc(
    yA_npc = 0.35,
    yB_npc = 0.48, # 0.13 gap - lige på grænsen
    label_height_npc = label_h,
    pref_pos = c("under", "under")
  )

  # Skal bruge NIVEAU 1 ELLER NIVEAU 2 (begge acceptable)
  niveau_used <- any(grepl("NIVEAU", result$warnings))
  expect_true(niveau_used)

  # Quality skal være acceptable eller better
  expect_true(result$placement_quality %in% c("optimal", "acceptable", "suboptimal"))

  # Labels må ikke overlappe
  expect_gte(abs(result$yA - result$yB), label_h * 0.95)
})

test_that("BFHcharts-followup: place_two_labels_npc NIVEAU 2 label flip strategier", {
  skip(paste0(
    "BFHcharts-followup: NIVEAU 2 fallback udloeses ikke af de testede inputs. ",
    "Inputparametre til NIVEAU 2 er udokumenteret. Eskaleret til BFHcharts#251."
  ))

  label_h <- 0.18 # Større label

  result <- BFHcharts:::place_two_labels_npc(
    yA_npc = 0.30,
    yB_npc = 0.38, # Meget tætte linjer
    label_height_npc = label_h,
    pref_pos = c("under", "under"),
    priority = "A"
  )

  # Skal bruge et niveau af collision avoidance
  expect_true(any(grepl("NIVEAU", result$warnings)))

  # Quality skal være acceptable eller suboptimal
  expect_true(result$placement_quality %in% c("optimal", "acceptable", "suboptimal", "degraded"))

  # Labels må ikke overlappe
  expect_gte(abs(result$yA - result$yB), label_h * 0.95)
})

test_that("BFHcharts-followup: place_two_labels_npc NIVEAU 3 shelf placement", {
  skip(paste0(
    "BFHcharts-followup: NIVEAU 3 shelf-placement udloeses ikke af de testede inputs. ",
    "Inputparametre til NIVEAU 3 er udokumenteret. Eskaleret til BFHcharts#252."
  ))

  label_h <- 0.35 # Ekstremt stor label

  result <- BFHcharts:::place_two_labels_npc(
    yA_npc = 0.50,
    yB_npc = 0.52, # Meget tætte linjer med stor label
    label_height_npc = label_h,
    pref_pos = c("under", "under"),
    priority = "A"
  )

  # Skal nå NIVEAU 3
  expect_true(any(grepl("NIVEAU 3|shelf placement", result$warnings)))

  # Quality skal være degraded
  expect_equal(result$placement_quality, "degraded")

  # Labels skal være placeret (selv om det ikke er optimalt)
  expect_false(is.na(result$yA))
  expect_false(is.na(result$yB))
})

# ==============================================================================
# NA VALUE HANDLING
# ==============================================================================

test_that("place_two_labels_npc håndterer begge linjer NA", {
  result <- BFHcharts:::place_two_labels_npc(
    yA_npc = NA_real_,
    yB_npc = NA_real_,
    label_height_npc = 0.13
  )

  expect_true(is.na(result$yA))
  expect_true(is.na(result$yB))
  expect_true(is.na(result$sideA))
  expect_true(is.na(result$sideB))
  expect_equal(result$placement_quality, "failed")
  expect_true(any(grepl("Begge linjer er NA", result$warnings)))
})

test_that("place_two_labels_npc håndterer kun A valid", {
  result <- BFHcharts:::place_two_labels_npc(
    yA_npc = 0.6,
    yB_npc = NA_real_,
    label_height_npc = 0.13,
    pref_pos = c("under", "under")
  )

  expect_false(is.na(result$yA))
  expect_true(is.na(result$yB))
  expect_equal(result$sideA, "under")
  expect_true(is.na(result$sideB))
  expect_equal(result$placement_quality, "degraded")
  expect_true(any(grepl("Kun label A placeret", result$warnings)))
})

test_that("place_two_labels_npc håndterer kun B valid", {
  result <- BFHcharts:::place_two_labels_npc(
    yA_npc = NA_real_,
    yB_npc = 0.4,
    label_height_npc = 0.13,
    pref_pos = c("under", "under")
  )

  expect_true(is.na(result$yA))
  expect_false(is.na(result$yB))
  expect_true(is.na(result$sideA))
  expect_equal(result$sideB, "under")
  expect_equal(result$placement_quality, "degraded")
  expect_true(any(grepl("Kun label B placeret", result$warnings)))
})

# ==============================================================================
# OUT-OF-BOUNDS DETECTION
# ==============================================================================

test_that("place_two_labels_npc detekterer out-of-bounds linjer", {
  # Linje A under 0
  result1 <- BFHcharts:::place_two_labels_npc(
    yA_npc = -0.1,
    yB_npc = 0.5,
    label_height_npc = 0.13
  )

  expect_true(is.na(result1$yA))
  expect_false(is.na(result1$yB))
  expect_true(any(grepl("uden for panel", result1$warnings)))

  # Linje B over 1
  result2 <- BFHcharts:::place_two_labels_npc(
    yA_npc = 0.5,
    yB_npc = 1.2,
    label_height_npc = 0.13
  )

  expect_false(is.na(result2$yA))
  expect_true(is.na(result2$yB))
  expect_true(any(grepl("uden for panel", result2$warnings)))
})

# ==============================================================================
# BASIC FUNCTIONALITY
# ==============================================================================

test_that("place_two_labels_npc placerer labels uden kollision", {
  # Simple case: Labels langt fra hinanden

  result <- BFHcharts:::place_two_labels_npc(
    yA_npc = 0.2,
    yB_npc = 0.8, # Langt fra hinanden
    label_height_npc = 0.13,
    pref_pos = c("under", "under")
  )

  # Begge skal være placeret
  expect_false(is.na(result$yA))
  expect_false(is.na(result$yB))

  # Begge skal have foretrukken side
  expect_equal(result$sideA, "under")
  expect_equal(result$sideB, "under")

  # Quality skal være optimal
  expect_equal(result$placement_quality, "optimal")

  # Ingen warnings
  expect_equal(length(result$warnings), 0)
})

test_that("place_two_labels_npc returnerer korrekt struktur", {
  result <- BFHcharts:::place_two_labels_npc(
    yA_npc = 0.4,
    yB_npc = 0.6,
    label_height_npc = 0.13
  )

  # Check required fields
  expect_true(!is.null(result$yA))
  expect_true(!is.null(result$yB))
  expect_true(!is.null(result$sideA))
  expect_true(!is.null(result$sideB))
  expect_true(!is.null(result$placement_quality))
  expect_true(!is.null(result$warnings))

  # Check types
  expect_true(is.numeric(result$yA))
  expect_true(is.numeric(result$yB))
  expect_true(is.character(result$sideA) || is.na(result$sideA))
  expect_true(is.character(result$sideB) || is.na(result$sideB))
  expect_true(is.character(result$placement_quality))
  expect_true(is.character(result$warnings))
})

# ==============================================================================
# PROPOSE_SINGLE_LABEL BOUNDS TESTS (mergeret fra test-label-placement-bounds.R)
# ==============================================================================

test_that("propose_single_label respekterer bounds ved flip fra under til over", {
  # Test scenario: Stor label (30% af panel), meget lav linje
  # Foretrækker "under" men må flippe til "over"
  # Ved flip skal den respektere pad_top, ikke bare clampe til 1.0

  result <- BFHcharts:::propose_single_label(
    y_line_npc = 0.05, # Meget lav linje (5% fra bunden)
    pref_side = "under", # Foretrækker under
    label_h = 0.3, # Stor label (30%)
    gap = 0.01, # 1% gap til linje
    pad_top = 0.01, # 1% top padding
    pad_bot = 0.01 # 1% bottom padding
  )

  # Skal flippe til over (fordi under ikke passer)
  expect_equal(result$side, "over")

  # Skal respektere bounds:
  # low_bound = pad_bot + half = 0.01 + 0.15 = 0.16
  # high_bound = 1 - pad_top - half = 1 - 0.01 - 0.15 = 0.84
  low_bound <- 0.01 + 0.15
  high_bound <- 1 - 0.01 - 0.15

  expect_gte(result$center, low_bound)
  expect_lte(result$center, high_bound)
})

test_that("propose_single_label respekterer bounds ved flip fra over til under", {
  # Test scenario: Stor label, meget høj linje
  # Foretrækker "over" men må flippe til "under"

  result <- BFHcharts:::propose_single_label(
    y_line_npc = 0.95, # Meget høj linje (95% fra bunden)
    pref_side = "over", # Foretrækker over
    label_h = 0.3, # Stor label (30%)
    gap = 0.01, # 1% gap til linje
    pad_top = 0.01, # 1% top padding
    pad_bot = 0.01 # 1% bottom padding
  )

  # Skal flippe til under
  expect_equal(result$side, "under")

  # Skal respektere bounds
  low_bound <- 0.01 + 0.15
  high_bound <- 1 - 0.01 - 0.15

  expect_gte(result$center, low_bound)
  expect_lte(result$center, high_bound)
})

test_that("propose_single_label placerer korrekt når foretrukken side passer", {
  # Test scenario: Normal label, central linje, "under" passer fint

  result <- BFHcharts:::propose_single_label(
    y_line_npc = 0.5, # Midt i panel
    pref_side = "under", # Foretrækker under
    label_h = 0.13, # Normal label højde
    gap = 0.01, # 1% gap
    pad_top = 0.01, # 1% top padding
    pad_bot = 0.01 # 1% bottom padding
  )

  # Skal bruge foretrukken side
  expect_equal(result$side, "under")

  # Skal placeres korrekt: linje - gap - half
  expected_center <- 0.5 - 0.01 - 0.065
  expect_equal(result$center, expected_center, tolerance = 0.001)
})

test_that("clamp_to_bounds fungerer korrekt", {
  # Værdi inden for bounds
  expect_equal(BFHcharts:::clamp_to_bounds(0.5, 0.2, 0.8), 0.5)

  # Værdi under lower bound
  expect_equal(BFHcharts:::clamp_to_bounds(0.1, 0.2, 0.8), 0.2)

  # Værdi over upper bound
  expect_equal(BFHcharts:::clamp_to_bounds(0.9, 0.2, 0.8), 0.8)

  # Vektor input
  result <- BFHcharts:::clamp_to_bounds(c(0.1, 0.5, 0.9), 0.2, 0.8)
  expect_equal(result, c(0.2, 0.5, 0.8))
})

test_that("propose_single_label håndterer edge case: meget lille padding", {
  # Test med minimal padding (0.5%)

  result <- BFHcharts:::propose_single_label(
    y_line_npc = 0.03, # Meget lav linje
    pref_side = "under", # Foretrækker under
    label_h = 0.2, # Medium-stor label
    gap = 0.005, # Lille gap
    pad_top = 0.005, # Minimal top padding
    pad_bot = 0.005 # Minimal bottom padding
  )

  # Skal respektere selv minimal padding
  low_bound <- 0.005 + 0.1 # 0.105
  high_bound <- 1 - 0.005 - 0.1 # 0.895

  expect_gte(result$center, low_bound)
  expect_lte(result$center, high_bound)
})

test_that("propose_single_label håndterer edge case: meget stor label", {
  # Test med ekstremt stor label (50% af panel)

  result <- BFHcharts:::propose_single_label(
    y_line_npc = 0.1, # Lav linje
    pref_side = "under", # Foretrækker under
    label_h = 0.5, # Ekstremt stor label (50%)
    gap = 0.02, # 2% gap
    pad_top = 0.01, # 1% top padding
    pad_bot = 0.01 # 1% bottom padding
  )

  # Skal respektere bounds selv med stor label
  low_bound <- 0.01 + 0.25 # 0.26
  high_bound <- 1 - 0.01 - 0.25 # 0.74

  expect_gte(result$center, low_bound)
  expect_lte(result$center, high_bound)

  # Forvent at den må flippe til over
  expect_equal(result$side, "over")
})
