# Tests: dependency guards og namespace-hygiejne

project_root <- normalizePath(file.path("..", ".."), winslash = "/", mustWork = TRUE)
r_files <- list.files(file.path(project_root, "R"), pattern = "[.]R$", full.names = TRUE)

# --- Task 1.3: require_qicharts2 / require_optional_package ---

test_that("require_optional_package kaster spc_dependency_error for ukendt pakke", {
  err <- tryCatch(
    require_optional_package("biSPCharts_definitely_nonexistent_xyz123", "test formål"),
    error = function(e) e
  )
  expect_s3_class(err, "spc_dependency_error")
  expect_s3_class(err, "spc_error")
  expect_s3_class(err, "error")
  expect_match(conditionMessage(err), "biSPCharts_definitely_nonexistent_xyz123")
  expect_match(conditionMessage(err), "test formål")
})

test_that("require_qicharts2 returnerer invisible NULL når qicharts2 er installeret", {
  skip_if_not_installed("qicharts2")
  result <- require_qicharts2()
  expect_null(result)
})

test_that("require_optional_package returnerer invisible NULL for installeret pakke", {
  result <- require_optional_package("utils", "test")
  expect_null(result)
})

# --- Task 3.4: ingen BFHcharts:::-kald i R/ ---

test_that("ingen BFHcharts:::-kald i R/ (triple-colon forbudt)", {
  offending <- character(0)
  for (f in r_files) {
    lines <- readLines(f, warn = FALSE)
    code_lines <- lines[!grepl("^\\s*#", lines)]
    matches <- grep("BFHcharts:::", code_lines, value = TRUE, fixed = TRUE)
    if (length(matches) > 0) {
      offending <- c(offending, sprintf("%s: %s", basename(f), trimws(matches)))
    }
  }
  if (length(offending) > 0) {
    fail(paste0(
      "BFHcharts:::-kald fundet (brug BFHcharts:: i stedet):\n",
      paste(offending, collapse = "\n")
    ))
  }
  expect_true(TRUE)
})
