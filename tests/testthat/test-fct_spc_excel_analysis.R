# Tests for sektion-builders i fct_spc_excel_analysis.R
# Daekker scenarios fra openspec/changes/.../specs/excel-spc-analysis-sheet/spec.md.
#
# Fixture-helpers er defineret i tests/testthat/helper-spc-excel-analysis-fixtures.R
# (loades automatisk af testthat).

# build_overview_section -------------------------------------------------------

test_that("build_overview_section returnerer 2-kolonne data.frame med faste felter", {
  qic <- fixture_qic_data_3_parts()
  meta <- fixture_metadata_3_parts()
  anhoej <- derive_anhoej_per_part(qic)

  result <- build_overview_section(
    qic_data = qic,
    metadata = meta,
    anhoej_per_part = anhoej,
    y_axis_unit = "count",
    freeze_position = NULL,
    computed_at = as.POSIXct("2024-06-01 12:00:00", tz = "UTC"),
    pkg_versions = list(biSPCharts = "0.2.0", BFHcharts = "0.9.0")
  )
  expect_s3_class(result, "data.frame")
  expect_equal(names(result), c("Felt", "Vaerdi"))
  expect_true("Charttype" %in% result$Felt)
  expect_true("Antal observationer" %in% result$Felt)
  expect_true("Antal parts" %in% result$Felt)
  expect_true("Out-of-control raekker" %in% result$Felt)
  expect_true("Samlet Anhoej-tolkning" %in% result$Felt)
})

test_that("build_overview_section angiver charttype paa dansk", {
  qic <- fixture_qic_data_3_parts()
  meta <- fixture_metadata_3_parts()
  result <- build_overview_section(qic, meta, derive_anhoej_per_part(qic))
  ct <- result$Vaerdi[result$Felt == "Charttype"]
  expect_equal(ct, "P-kort")
})

test_that("build_overview_section samler ooc-raekker som komma-separeret tekst", {
  qic <- fixture_qic_data_3_parts()
  # Forvent ooc-rakker i part 3: y[11] = 0.15 > ucl[11] = 0.10 -> raekke 11
  meta <- fixture_metadata_3_parts()
  result <- build_overview_section(qic, meta, derive_anhoej_per_part(qic))
  ooc <- result$Vaerdi[result$Felt == "Out-of-control raekker"]
  expect_match(ooc, "11")
})

test_that("build_overview_section haandterer freeze-position med baseline-summary", {
  qic <- fixture_qic_data_3_parts()
  meta <- fixture_metadata_3_parts()
  result <- build_overview_section(
    qic, meta, derive_anhoej_per_part(qic),
    freeze_position = 4L
  )
  freeze <- result$Vaerdi[result$Felt == "Freeze-baseline (CL/UCL/LCL ved freeze)"]
  expect_match(freeze, "CL=")
  expect_match(freeze, "UCL=")

  frozen_row <- result$Vaerdi[result$Felt == "Frozen til raekke"]
  expect_equal(frozen_row, "4")
})

test_that("build_overview_section angiver dansk Anhoej-tolkning baseret paa parts", {
  qic <- fixture_qic_data_3_parts()
  meta <- fixture_metadata_3_parts()
  result <- build_overview_section(qic, meta, derive_anhoej_per_part(qic))
  tolkning <- result$Vaerdi[result$Felt == "Samlet Anhoej-tolkning"]
  # Mindst part 1 har runs_signal = TRUE
  expect_match(tolkning, "Særskilt")
})

# build_per_part_section -------------------------------------------------------

test_that("build_per_part_section har en raekke per part", {
  qic <- fixture_qic_data_3_parts()
  result <- build_per_part_section(qic, y_axis_unit = "count")
  expect_equal(nrow(result), 3L)
  expect_equal(result$Part, c(1L, 2L, 3L))
})

test_that("build_per_part_section har CL/UCL/LCL-kolonner med qic-konvention i parens", {
  qic <- fixture_qic_data_3_parts()
  result <- build_per_part_section(qic, y_axis_unit = "count")
  cols <- names(result)
  expect_true(any(grepl("^Centrallinje \\(cl", cols)))
  expect_true(any(grepl("^Oevre graense \\(ucl", cols)))
  expect_true(any(grepl("^Nedre graense \\(lcl", cols)))
})

test_that("build_per_part_section konverterer tids-y-akse til UI-enhed", {
  qic <- fixture_qic_data_time_hours()
  result <- build_per_part_section(qic, y_axis_unit = "time_hours")
  cl_col <- grep("^Centrallinje", names(result), value = TRUE)
  expect_match(cl_col, "timer")
  # CL = 150 minutter = 2.5 timer
  expect_equal(result[[cl_col]][1], 2.5, tolerance = 1e-6)
})

test_that("build_per_part_section returnerer tom data.frame for tomt qic_data", {
  empty <- data.frame(
    y = numeric(0), cl = numeric(0), ucl = numeric(0), lcl = numeric(0),
    part = integer(0), runs.signal = logical(0)
  )
  result <- build_per_part_section(empty)
  expect_equal(nrow(result), 0L)
})

test_that("build_per_part_section behandler manglende part-kolonne som single part", {
  qic <- fixture_qic_data_run_chart()
  result <- build_per_part_section(qic, y_axis_unit = "count")
  expect_equal(nrow(result), 1L)
  expect_equal(result$Part, 1L)
})

test_that("build_per_part_section udfylder phase-navn hvis givet", {
  qic <- fixture_qic_data_3_parts()
  result <- build_per_part_section(
    qic,
    y_axis_unit = "count",
    phase_names = c("Baseline", "Intervention", "Opfoelgning")
  )
  expect_equal(result$`Phase-navn`, c("Baseline", "Intervention", "Opfoelgning"))
})

test_that("build_per_part_section beregner Mean og Median per part", {
  qic <- fixture_qic_data_3_parts()
  result <- build_per_part_section(qic, y_axis_unit = "count")
  mean_col <- grep("^Mean", names(result), value = TRUE)[1]
  median_col <- grep("^Median", names(result), value = TRUE)[1]
  # Part 1 y: 0.08, 0.09, 0.10, 0.11 -> mean = 0.095
  expect_equal(result[[mean_col]][1], 0.095, tolerance = 1e-6)
  expect_equal(result[[median_col]][1], 0.095, tolerance = 1e-6)
})

test_that("build_per_part_section beregner target-Delta hvis target sat", {
  qic <- fixture_qic_data_3_parts()
  result <- build_per_part_section(
    qic,
    y_axis_unit = "count", target_value = "0.05"
  )
  delta_col <- grep("^Delta til CL", names(result), value = TRUE)[1]
  # Part 1: target=0.05, CL=0.045 -> Delta = 0.005
  expect_equal(result[[delta_col]][1], 0.005, tolerance = 1e-6)
})

# build_anhoej_section ---------------------------------------------------------

test_that("build_anhoej_section har korrekte kolonner og en raekke per part", {
  qic <- fixture_qic_data_3_parts()
  anhoej <- derive_anhoej_per_part(qic)
  result <- build_anhoej_section(anhoej)
  expect_equal(nrow(result), 3L)
  expected_cols <- c(
    "Part",
    "Laengste serie (longest_run)",
    "Maks tilladt (longest_run_max)",
    "Antal kryds (n_crossings)",
    "Min kraevet (n_crossings_min)",
    "Runs-signal", "Crossings-signal", "Samlet signal", "Dansk tolkning"
  )
  expect_equal(names(result), expected_cols)
})

test_that("build_anhoej_section reflekterer per-part signaler", {
  qic <- fixture_qic_data_3_parts()
  anhoej <- derive_anhoej_per_part(qic)
  result <- build_anhoej_section(anhoej)
  # Part 1: runs_signal = TRUE
  expect_equal(result$`Runs-signal`[1], "JA")
  # Part 2: stabil
  expect_equal(result$`Runs-signal`[2], "NEJ")
  expect_equal(result$`Crossings-signal`[2], "NEJ")
})

test_that("build_anhoej_section haandterer tomt input", {
  result <- build_anhoej_section(list())
  expect_equal(nrow(result), 0L)
  expect_true("Part" %in% names(result))
})

# build_special_cause_section --------------------------------------------------

test_that("build_special_cause_section inkluderer ooc og runs.signal-raekker", {
  qic <- fixture_qic_data_3_parts()
  orig <- fixture_original_data_3_parts()
  result <- build_special_cause_section(
    qic_data = qic,
    original_data = orig,
    y_axis_unit = "count",
    x_column = "Dato",
    kommentar_column = "Kommentar",
    n_column = "Patienter"
  )
  # Part 1 raekke 1-4 har runs.signal = TRUE; raekke 11 har ooc.
  expect_true(all(c(1L, 2L, 3L, 4L, 11L) %in% result$Raekke))
})

test_that("build_special_cause_section returnerer tom data.frame uden ooc/runs", {
  qic <- fixture_qic_data_run_chart()
  result <- build_special_cause_section(qic, y_axis_unit = "count")
  expect_equal(nrow(result), 0L)
})

test_that("build_special_cause_section udfylder Notes og Naevner fra original_data", {
  qic <- fixture_qic_data_3_parts()
  orig <- fixture_original_data_3_parts()
  result <- build_special_cause_section(
    qic_data = qic, original_data = orig,
    kommentar_column = "Kommentar", n_column = "Patienter"
  )
  # Raekke 3 i part 1 har "Personalemangel"
  row3 <- result[result$Raekke == 3L, ]
  expect_equal(row3$Notes, "Personalemangel")
  expect_equal(row3$`Naevner (n)`, 100)
})

test_that("build_special_cause_section markerer Out-of-limits og Runs-signal korrekt", {
  qic <- fixture_qic_data_3_parts()
  result <- build_special_cause_section(qic, y_axis_unit = "count")
  # Raekke 1-4 (part 1): runs.signal = TRUE, ikke ooc
  row1 <- result[result$Raekke == 1L, ]
  expect_equal(row1$`Runs-signal`, "JA")
  expect_equal(row1$`Out-of-limits`, "NEJ")
  # Raekke 11 (part 3): ooc
  row11 <- result[result$Raekke == 11L, ]
  expect_equal(row11$`Out-of-limits`, "JA")
})

# build_spc_analysis_sheet (orkestrator) --------------------------------------

test_that("build_spc_analysis_sheet returnerer named list med fire sektioner", {
  qic <- fixture_qic_data_3_parts()
  meta <- fixture_metadata_3_parts()
  orig <- fixture_original_data_3_parts()
  result <- build_spc_analysis_sheet(qic, meta, orig)
  expect_type(result, "list")
  expect_setequal(
    names(result),
    c("overview", "per_part", "anhoej", "special_cause")
  )
  expect_s3_class(result$overview, "data.frame")
  expect_s3_class(result$per_part, "data.frame")
  expect_s3_class(result$anhoej, "data.frame")
  expect_s3_class(result$special_cause, "data.frame")
})

test_that("build_spc_analysis_sheet returnerer NULL for tomt qic_data", {
  empty <- data.frame(
    y = numeric(0), cl = numeric(0), ucl = numeric(0), lcl = numeric(0),
    part = integer(0), runs.signal = logical(0)
  )
  expect_null(build_spc_analysis_sheet(empty, list()))
})

test_that("build_spc_analysis_sheet returnerer NULL for ikke-data.frame input", {
  expect_null(build_spc_analysis_sheet(NULL, list()))
  expect_null(build_spc_analysis_sheet("not a df", list()))
})

test_that("build_spc_analysis_sheet honors options-overrides", {
  qic <- fixture_qic_data_3_parts()
  meta <- fixture_metadata_3_parts()
  result <- build_spc_analysis_sheet(
    qic, meta,
    options = list(
      y_axis_unit = "count",
      phase_names = c("A", "B", "C"),
      pkg_versions = list(biSPCharts = "9.9.9")
    )
  )
  expect_equal(result$per_part$`Phase-navn`, c("A", "B", "C"))
  expect_match(
    result$overview$Vaerdi[result$overview$Felt == "biSPCharts-version"],
    "9.9.9"
  )
})

# Run-chart specifik ----------------------------------------------------------

test_that("Run-chart: UCL/LCL-celler i sektion B er NA (tomme)", {
  qic <- fixture_qic_data_run_chart()
  result <- build_per_part_section(qic, y_axis_unit = "count")
  ucl_col <- grep("^Oevre graense", names(result), value = TRUE)[1]
  lcl_col <- grep("^Nedre graense", names(result), value = TRUE)[1]
  expect_true(is.na(result[[ucl_col]][1]))
  expect_true(is.na(result[[lcl_col]][1]))
})

# Pure: ingen Shiny / app_state ----------------------------------------------

test_that("alle builders koerer uden Shiny-runtime", {
  # Fixture-input + ingen reactive context
  qic <- fixture_qic_data_3_parts()
  meta <- fixture_metadata_3_parts()
  expect_silent({
    build_overview_section(qic, meta, derive_anhoej_per_part(qic))
    build_per_part_section(qic, y_axis_unit = "count")
    build_anhoej_section(derive_anhoej_per_part(qic))
    build_special_cause_section(qic)
  })
})
