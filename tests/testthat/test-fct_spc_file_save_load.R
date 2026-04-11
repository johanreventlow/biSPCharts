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
