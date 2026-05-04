# Security regression-tests for #449 (zip-bomb guard på Excel-upload)
# og #457 (class_info$primary whitelist i restore_column_class).

test_that("validate_excel_file: zip-bomb guard afviser xlsx over uncompressed-loft (#449)", {
  skip_if_not_installed("writexl")

  # Skab en lille xlsx der ekspanderer til mere end limit. Vi mocker
  # utils::unzip i stedet for at producere en faktisk zip-bomb (det er
  # bevidst ikke noget vi vil have liggende i fixtures).
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)
  writexl::write_xlsx(data.frame(x = 1:3, y = 4:6), tmp)

  limit_mb <- get_max_xlsx_uncompressed_mb()
  bomb_size_bytes <- (limit_mb + 50) * 1024 * 1024

  fake_entries <- data.frame(
    Name = c("xl/worksheets/sheet1.xml"),
    Length = c(bomb_size_bytes),
    Date = Sys.time()
  )

  with_mocked_bindings(
    unzip = function(zipfile, list = FALSE, ...) {
      if (isTRUE(list)) fake_entries else stop("unmocked unzip path")
    },
    .package = "utils",
    code = {
      result <- validate_excel_file(tmp)
      expect_false(result$valid)
      expect_true(any(grepl("for stor efter dekomprimering", result$errors)))
    }
  )
})

test_that("validate_excel_file: normal-sized xlsx passerer zip-bomb guard (#449)", {
  skip_if_not_installed("writexl")

  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)
  writexl::write_xlsx(data.frame(x = 1:5, y = letters[1:5]), tmp)

  result <- validate_excel_file(tmp)
  # Zip-bomb-checket afviser ikke en normal xlsx (resterende validering
  # kan stadig flagge andet, men ikke zip-bomb-fejlen).
  expect_false(any(grepl("for stor efter dekomprimering", result$errors %||% character(0))))
})

test_that("restore_column_class: ukendt primary-type returnerer raw values + warner (#457)", {
  bogus <- list(primary = "system('rm -rf /')")
  values <- c("a", "b", "c")
  expect_warning_or_silent <- function(expr) {
    # log_warn skriver til stderr; vi tester kun returnværdien her.
    suppressMessages(suppressWarnings(expr))
  }
  result <- expect_warning_or_silent(restore_column_class(values, bogus))
  expect_identical(result, values)
})

test_that("restore_column_class: alle whitelisted primary-typer fungerer (#457)", {
  cases <- list(
    list(class_info = list(primary = "integer"), values = c("1", "2", "3"), expected = c(1L, 2L, 3L)),
    list(class_info = list(primary = "numeric"), values = c("1.5", "2.5"), expected = c(1.5, 2.5)),
    list(class_info = list(primary = "double"), values = c("1.5", "2.5"), expected = c(1.5, 2.5)),
    list(class_info = list(primary = "character"), values = 1:3, expected = c("1", "2", "3")),
    list(class_info = list(primary = "logical"), values = c("TRUE", "FALSE"), expected = c(TRUE, FALSE))
  )
  for (case in cases) {
    expect_identical(
      restore_column_class(case$values, case$class_info),
      case$expected
    )
  }
})

test_that("restore_column_class: factor + Date + POSIXct paths bevares (#457)", {
  # Factor
  result_factor <- restore_column_class(
    c("a", "b", "a"),
    list(primary = "factor", is_factor = TRUE, levels = c("a", "b"))
  )
  expect_s3_class(result_factor, "factor")
  expect_equal(levels(result_factor), c("a", "b"))

  # Date (numeric format — days since 1970)
  result_date <- restore_column_class(
    19500,
    list(primary = "Date", is_date = TRUE)
  )
  expect_s3_class(result_date, "Date")

  # POSIXct
  result_posix <- restore_column_class(
    "2026-05-03 10:00:00",
    list(primary = "POSIXct", is_posixct = TRUE, tz = "UTC")
  )
  expect_s3_class(result_posix, "POSIXct")
})
