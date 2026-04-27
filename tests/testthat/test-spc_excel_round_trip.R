# Round-trip tests for build_spc_excel + parse_spc_excel.
# Verificér at "SPC-analyse"-arket ikke laekker ind i parse_spc_excel-output
# og at bagudkompatibilitet med 2-ark filer bevares.

test_that("parse_spc_excel ignorerer SPC-analyse-arket", {
  data <- data.frame(x = 1:5, y = c(0.1, 0.2, 0.15, 0.18, 0.12))
  metadata <- list(
    chart_type = "p",
    target_value = "0.15",
    y_axis_unit = "count",
    x_column = "x",
    y_column = "y",
    n_column = "",
    skift_column = "",
    indicator_title = "Test"
  )

  qic_data <- fixture_qic_data_3_parts()
  temp_path <- build_spc_excel(
    data = data, metadata = metadata,
    qic_data = qic_data, original_data = data
  )
  on.exit(unlink(temp_path), add = TRUE)

  # Verifér at filen har 3 ark
  sheets <- readxl::excel_sheets(temp_path)
  expect_setequal(sheets, c("Data", "Indstillinger", "SPC-analyse"))

  # Parse: returneret metadata SHALL kun reflektere Indstillinger-ark
  parsed <- parse_spc_excel(temp_path)
  expect_equal(parsed$chart_type, metadata$chart_type)
  expect_equal(parsed$target_value, metadata$target_value)
  expect_equal(parsed$indicator_title, metadata$indicator_title)
  # Ingen felter fra SPC-analyse-arket SHALL laekke
  expect_false("Charttype" %in% names(parsed)) # Dansk overview-felt
  expect_false("Antal observationer" %in% names(parsed))
  expect_false("Samlet Anhoej-tolkning" %in% names(parsed))
})

test_that("Bagudkompatibilitet: 2-ark Excel uden SPC-analyse parses uden fejl", {
  data <- data.frame(x = 1:3, y = c(1, 2, 3))
  metadata <- list(
    chart_type = "run",
    y_axis_unit = "count",
    indicator_title = "Legacy"
  )

  # qic_data = NULL -> ingen SPC-analyse-ark
  temp_path <- build_spc_excel(data = data, metadata = metadata)
  on.exit(unlink(temp_path), add = TRUE)

  sheets <- readxl::excel_sheets(temp_path)
  expect_setequal(sheets, c("Data", "Indstillinger"))

  parsed <- parse_spc_excel(temp_path)
  expect_equal(parsed$chart_type, "run")
  expect_equal(parsed$indicator_title, "Legacy")
})

test_that("Tomt qic_data resulterer i 2-ark Excel (SPC-analyse springes over)", {
  data <- data.frame(x = 1:3, y = c(1, 2, 3))
  metadata <- list(chart_type = "run", y_axis_unit = "count")

  empty_qic <- data.frame(
    y = numeric(0), cl = numeric(0), part = integer(0),
    runs.signal = logical(0)
  )
  temp_path <- build_spc_excel(
    data = data, metadata = metadata,
    qic_data = empty_qic
  )
  on.exit(unlink(temp_path), add = TRUE)

  sheets <- readxl::excel_sheets(temp_path)
  expect_setequal(sheets, c("Data", "Indstillinger"))
})

test_that("SPC-analyse-ark indeholder forventede sektion-headers", {
  data <- data.frame(x = 1:12, y = runif(12))
  metadata <- list(
    chart_type = "p", y_axis_unit = "count",
    indicator_title = "Test", target_value = "0.05",
    kommentar_column = "Kommentar"
  )
  qic <- fixture_qic_data_3_parts()
  orig <- fixture_original_data_3_parts()

  temp_path <- build_spc_excel(
    data = data, metadata = metadata,
    qic_data = qic, original_data = orig
  )
  on.exit(unlink(temp_path), add = TRUE)

  raw <- suppressMessages(
    readxl::read_excel(temp_path, sheet = "SPC-analyse", col_names = FALSE)
  )
  # Forste kolonne SHALL indeholde de fire sektions-headers
  first_col <- as.character(raw[[1]])
  expect_true(any(first_col == "A. Oversigt"))
  expect_true(any(first_col == "B. Per-part statistik"))
  expect_true(any(first_col == "C. Anhoej-regler per part"))
  expect_true(any(first_col == "D. Special cause-punkter"))
})

test_that("SPC-analyse-ark uden special cause viser besked", {
  data <- data.frame(x = 1:6, y = c(10, 12, 11, 14, 13, 15))
  metadata <- list(chart_type = "run", y_axis_unit = "count")

  qic <- fixture_qic_data_run_chart()
  temp_path <- build_spc_excel(
    data = data, metadata = metadata,
    qic_data = qic, original_data = data
  )
  on.exit(unlink(temp_path), add = TRUE)

  raw <- suppressMessages(
    readxl::read_excel(temp_path, sheet = "SPC-analyse", col_names = FALSE)
  )
  first_col <- as.character(raw[[1]])
  expect_true(any(first_col == "Ingen special cause-punkter detekteret"))
})
