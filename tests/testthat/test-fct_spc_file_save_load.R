test_that("build_spc_excel opretter fil med to ark: Data og Indstillinger", {
  data <- data.frame(dato = as.Date("2024-01-01") + 0:4,
                     vaerdi = c(1.0, 2.0, 3.0, 4.0, 5.0))
  metadata <- list(x_column = "dato", y_column = "vaerdi", chart_type = "p")

  path <- build_spc_excel(data, metadata)

  expect_true(file.exists(path))
  sheets <- readxl::excel_sheets(path)
  expect_true("Data" %in% sheets)
  expect_true("Indstillinger" %in% sheets)
})

test_that("build_spc_excel Data-ark indeholder korrekte rækker og kolonner", {
  data <- data.frame(dato = as.Date("2024-01-01") + 0:4,
                     vaerdi = c(1.0, 2.0, 3.0, 4.0, 5.0))
  metadata <- list(x_column = "dato")

  path <- build_spc_excel(data, metadata)
  result <- readxl::read_excel(path, sheet = "Data")

  expect_equal(nrow(result), 5)
  expect_true("dato" %in% names(result))
  expect_true("vaerdi" %in% names(result))
})

test_that("build_spc_excel Indstillinger-ark indeholder metadata som Felt/Vaerdi", {
  data <- data.frame(x = 1:3, y = 4:6)
  metadata <- list(x_column = "x", y_column = "y", chart_type = "p",
                   indicator_title = "Min titel")

  path <- build_spc_excel(data, metadata)
  settings <- readxl::read_excel(path, sheet = "Indstillinger", skip = 2)

  expect_true("Felt" %in% names(settings))
  expect_true("Vaerdi" %in% names(settings))

  felt_values <- settings$Felt
  expect_true("x_column" %in% felt_values)
  expect_true("indicator_title" %in% felt_values)

  title_row <- settings[settings$Felt == "indicator_title", ]
  expect_equal(title_row$Vaerdi, "Min titel")
})

test_that("build_spc_excel returnerer sti til eksisterende fil", {
  data <- data.frame(x = 1)
  metadata <- list()

  path <- build_spc_excel(data, metadata)

  expect_true(is.character(path))
  expect_true(grepl("\\.xlsx$", path))
  expect_true(file.exists(path))
})

test_that("parse_spc_excel returnerer NULL for fil uden Indstillinger-ark", {
  data <- data.frame(x = 1:3, y = 4:6)
  path <- tempfile(fileext = ".xlsx")
  writexl::write_xlsx(data, path)

  result <- parse_spc_excel(path)
  expect_null(result)
})

test_that("parse_spc_excel returnerer named list med metadata-felter", {
  data <- data.frame(dato = as.Date("2024-01-01") + 0:4,
                     vaerdi = c(1.0, 2.0, 3.0, 4.0, 5.0))
  metadata <- list(
    x_column        = "dato",
    y_column        = "vaerdi",
    chart_type      = "p",
    indicator_title = "Ventetid til operation",
    target_value    = "30",
    y_axis_unit     = "dage"
  )

  path <- build_spc_excel(data, metadata)
  parsed <- parse_spc_excel(path)

  expect_false(is.null(parsed))
  expect_equal(parsed$x_column,        "dato")
  expect_equal(parsed$y_column,        "vaerdi")
  expect_equal(parsed$chart_type,      "p")
  expect_equal(parsed$indicator_title, "Ventetid til operation")
  expect_equal(parsed$target_value,    "30")
  expect_equal(parsed$y_axis_unit,     "dage")
})

test_that("parse_spc_excel round-trip: byg og parse giver identisk metadata", {
  data <- data.frame(x = 1:3)
  metadata <- list(
    x_column           = "x",
    y_column           = "y",
    chart_type         = "c",
    indicator_title    = "Test",
    indicator_description = "Beskrivelse",
    target_value       = "",
    centerline_value   = "",
    y_axis_unit        = "count",
    unit_type          = "select",
    unit_select        = "med",
    unit_custom        = "",
    export_title       = "Eksport titel",
    export_department  = "Afdeling X",
    export_format      = "pdf",
    pdf_description    = "",
    pdf_improvement    = "",
    png_size_preset    = "HD",
    png_dpi            = "300",
    active_tab         = "analyser",
    skift_column       = "",
    frys_column        = "",
    kommentar_column   = "",
    n_column           = ""
  )

  path <- build_spc_excel(data, metadata)
  parsed <- parse_spc_excel(path)

  for (felt in names(metadata)) {
    expect_equal(parsed[[felt]], metadata[[felt]],
      info = paste("Felt mismatch:", felt))
  }
})

test_that("parse_spc_excel returnerer NULL ved korrupt Indstillinger-ark", {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Data")
  openxlsx::writeData(wb, sheet = "Data", x = data.frame(x = 1))
  openxlsx::addWorksheet(wb, "Indstillinger")
  openxlsx::writeData(wb, sheet = "Indstillinger",
    x = data.frame(Besked = "kun kommentar"), startRow = 1, colNames = FALSE)
  path <- tempfile(fileext = ".xlsx")
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)

  result <- parse_spc_excel(path)
  expect_true(is.null(result) || length(result) == 0)
})
