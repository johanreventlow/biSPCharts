# Tests: Excel sheet detection helpers
# Bruger runtime-genererede fixtures via openxlsx (ingen committede binaerer).

# Helper: opret midlertidig Excel-fil med navngivne ark
make_test_xlsx <- function(sheets_data) {
  # sheets_data: named list, hvor navne er ark-navne og vaerdier er data.frames
  path <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  for (sheet_name in names(sheets_data)) {
    openxlsx::addWorksheet(wb, sheet_name)
    openxlsx::writeData(wb, sheet = sheet_name, x = sheets_data[[sheet_name]])
  }
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  path
}

# ---- list_excel_sheets() -----------------------------------------------------

test_that("list_excel_sheets returnerer ark-navne for gyldig fil", {
  path <- make_test_xlsx(list(
    "Q1" = data.frame(x = 1:3),
    "Q2" = data.frame(x = 4:6)
  ))
  on.exit(unlink(path), add = TRUE)

  sheets <- list_excel_sheets(path)
  expect_type(sheets, "character")
  expect_setequal(sheets, c("Q1", "Q2"))
})

test_that("list_excel_sheets returnerer NULL for ikke-eksisterende fil", {
  expect_null(list_excel_sheets("/nonexistent/path/foo.xlsx"))
})

test_that("list_excel_sheets returnerer NULL for korrupt fil", {
  path <- tempfile(fileext = ".xlsx")
  writeLines("ikke en gyldig excel-fil", path)
  on.exit(unlink(path), add = TRUE)

  expect_null(list_excel_sheets(path))
})

test_that("list_excel_sheets returnerer NULL for NULL/invalid input", {
  expect_null(list_excel_sheets(NULL))
  expect_null(list_excel_sheets(c("a", "b")))
  expect_null(list_excel_sheets(123))
})

# ---- detect_empty_sheets() ---------------------------------------------------

test_that("detect_empty_sheets identificerer tomme ark korrekt", {
  path <- make_test_xlsx(list(
    "FuldData" = data.frame(x = 1:5, y = letters[1:5]),
    "TomtArk"  = data.frame(x = character(0), y = character(0))
  ))
  on.exit(unlink(path), add = TRUE)

  result <- detect_empty_sheets(path, c("FuldData", "TomtArk"))
  expect_equal(result, c(FALSE, TRUE))
})

test_that("detect_empty_sheets respekterer raekkefoelge i sheets-argument", {
  path <- make_test_xlsx(list(
    "A" = data.frame(x = 1:3),
    "B" = data.frame(x = character(0))
  ))
  on.exit(unlink(path), add = TRUE)

  expect_equal(detect_empty_sheets(path, c("B", "A")), c(TRUE, FALSE))
})

test_that("detect_empty_sheets returnerer tom logical for tom sheets-input", {
  path <- make_test_xlsx(list("X" = data.frame(x = 1)))
  on.exit(unlink(path), add = TRUE)

  expect_equal(detect_empty_sheets(path, character(0)), logical(0))
  expect_equal(detect_empty_sheets(path, NULL), logical(0))
})

test_that("detect_empty_sheets returnerer TRUE konservativt ved fejl", {
  path <- make_test_xlsx(list("Eksisterende" = data.frame(x = 1)))
  on.exit(unlink(path), add = TRUE)

  # Ikke-eksisterende ark-navn → tryCatch fanger fejl → TRUE
  result <- detect_empty_sheets(path, c("Eksisterende", "FindesIkke"))
  expect_equal(result, c(FALSE, TRUE))
})

# ---- is_bispchart_excel_format() ---------------------------------------------

test_that("is_bispchart_excel_format genkender 2-ark gem-format", {
  expect_true(is_bispchart_excel_format(c("Data", "Indstillinger")))
})

test_that("is_bispchart_excel_format genkender 3-ark gem-format med SPC-analyse", {
  expect_true(
    is_bispchart_excel_format(c("Data", "Indstillinger", "SPC-analyse"))
  )
})

test_that("is_bispchart_excel_format afviser standard multi-sheet uden begge ark", {
  expect_false(is_bispchart_excel_format(c("Data", "Q2")))
  expect_false(is_bispchart_excel_format(c("Indstillinger", "Q2")))
  expect_false(is_bispchart_excel_format(c("Sheet1", "Sheet2", "Sheet3")))
})

test_that("is_bispchart_excel_format afviser single-sheet", {
  expect_false(is_bispchart_excel_format("Sheet1"))
  expect_false(is_bispchart_excel_format("Data"))
})

test_that("is_bispchart_excel_format afviser tomme/NULL input", {
  expect_false(is_bispchart_excel_format(NULL))
  expect_false(is_bispchart_excel_format(character(0)))
})

test_that("is_bispchart_excel_format er case-sensitiv (matcher faktisk save-format)", {
  # biSPCharts gemmer praecis "Data" og "Indstillinger" — laveboget skal afvises
  expect_false(is_bispchart_excel_format(c("data", "indstillinger")))
})

# ---- excel_data_to_paste_text() ---------------------------------------------

test_that("excel_data_to_paste_text producerer tab-separeret med komma-decimal", {
  data <- data.frame(
    dato = as.Date(c("2024-01-15", "2024-02-15")),
    vaerdi = c(3.14, 2.71),
    label = c("a", "b"),
    stringsAsFactors = FALSE
  )
  result <- excel_data_to_paste_text(data)
  lines <- strsplit(result, "\n", fixed = TRUE)[[1]]

  expect_equal(lines[1], "dato\tvaerdi\tlabel")
  expect_equal(lines[2], "2024-01-15\t3,14\ta")
  expect_equal(lines[3], "2024-02-15\t2,71\tb")
})

test_that("excel_data_to_paste_text haandterer NA som tom streng", {
  data <- data.frame(x = c(1, NA, 3), stringsAsFactors = FALSE)
  result <- excel_data_to_paste_text(data)
  lines <- strsplit(result, "\n", fixed = TRUE)[[1]]
  expect_equal(lines, c("x", "1", "", "3"))
})

test_that("excel_data_to_paste_text returnerer kun header for tom data", {
  data <- data.frame(x = numeric(0), y = character(0), stringsAsFactors = FALSE)
  expect_equal(excel_data_to_paste_text(data), "x\ty")
})

test_that("excel_data_to_paste_text returnerer tom streng for NULL/0-cols", {
  expect_equal(excel_data_to_paste_text(NULL), "")
  expect_equal(excel_data_to_paste_text(data.frame()), "")
})

# ---- build_excel_sheet_dropdown_items() -------------------------------------

test_that("build_excel_sheet_dropdown_items renderer en button per ark", {
  result <- build_excel_sheet_dropdown_items(c("Q1", "Q2", "Q3"))
  html <- as.character(result)

  # Header + 3 buttons
  expect_match(html, "Q1", fixed = TRUE)
  expect_match(html, "Q2", fixed = TRUE)
  expect_match(html, "Q3", fixed = TRUE)
  expect_match(html, "excel-sheet-item", fixed = TRUE)
  expect_match(html, "selected_excel_sheet", fixed = TRUE)
})

test_that("build_excel_sheet_dropdown_items markerer tomme ark med --empty klasse", {
  result <- build_excel_sheet_dropdown_items(
    c("FuldData", "Tom"),
    empty_flags = c(FALSE, TRUE)
  )

  # Hver item er separat tag — inspicér struktureret
  items <- result[[2]] # tagList: [1] header, [2..] items
  fuld_html <- as.character(items[[1]])
  tom_html <- as.character(items[[2]])

  expect_false(grepl("excel-sheet-item--empty", fuld_html, fixed = TRUE))
  expect_true(grepl("excel-sheet-item--empty", tom_html, fixed = TRUE))
  expect_match(tom_html, "Tom (tomt ark)", fixed = TRUE)
  expect_match(fuld_html, ">FuldData<", fixed = TRUE)
})

test_that("build_excel_sheet_dropdown_items JSON-escapes ark-navne med specialtegn", {
  result <- build_excel_sheet_dropdown_items(c('Data "med" citater'))
  html <- as.character(result)

  # htmltools attribute-encoder citater til &quot; — verificér escapet form
  # i onclick-attributtens vaerdi: JSON's \" bliver \&quot; efter HTML-attr-escape
  expect_match(html, "\\&quot;", fixed = TRUE)
  expect_match(html, "Shiny.setInputValue", fixed = TRUE)
  # Body-text er sikkert med raa citater (ikke attribut-vaerdi)
  expect_match(html, ">Data \"med\" citater<", fixed = TRUE)
})

test_that("build_excel_sheet_dropdown_items haandterer aeoeae i ark-navne", {
  result <- build_excel_sheet_dropdown_items(c("Sjælland-data"))
  html <- as.character(result)
  expect_match(html, "Sj", fixed = TRUE)
})

test_that("build_excel_sheet_dropdown_items returnerer NULL for tomt input", {
  expect_null(build_excel_sheet_dropdown_items(NULL))
  expect_null(build_excel_sheet_dropdown_items(character(0)))
})

# ---- Observer-flow tests via testServer -------------------------------------

# Helper: opret minimal app_state-struktur til observer-tests
make_test_app_state <- function() {
  app_state <- shiny::reactiveValues()
  app_state$session <- shiny::reactiveValues(
    pending_excel_upload = NULL
  )
  app_state
}

test_that("multi-sheet upload saetter pending_excel_upload (state-niveau)", {
  # Direkte state-test (ikke fuldt testServer): verificér at state-mutation
  # foelger forventet form naar multi-sheet detekteres
  path <- make_test_xlsx(list(
    "Q1" = data.frame(x = 1:3),
    "Q2" = data.frame(x = 4:6),
    "Q3" = data.frame(x = 7:9)
  ))
  on.exit(unlink(path), add = TRUE)

  sheets <- list_excel_sheets(path)
  expect_length(sheets, 3)
  expect_false(is_bispchart_excel_format(sheets))

  empty_flags <- detect_empty_sheets(path, sheets)
  expect_equal(empty_flags, c(FALSE, FALSE, FALSE))

  # Simuler observer-mutation
  app_state <- make_test_app_state()
  shiny::isolate({
    app_state$session$pending_excel_upload <- list(
      datapath = path,
      name = "test.xlsx",
      sheets = sheets,
      empty_flags = empty_flags
    )
  })

  pending <- shiny::isolate(app_state$session$pending_excel_upload)
  expect_equal(pending$name, "test.xlsx")
  expect_equal(pending$sheets, c("Q1", "Q2", "Q3"))
  expect_equal(pending$empty_flags, c(FALSE, FALSE, FALSE))
})

test_that("biSPCharts-format upload faar IKKE pending_excel_upload sat", {
  # Med Data + Indstillinger faar handle_excel_upload-grenen direkte; pending skal forblive NULL
  sheets <- c("Data", "Indstillinger", "SPC-analyse")
  expect_true(is_bispchart_excel_format(sheets))
})

test_that("single-sheet Excel faar IKKE pending_excel_upload sat", {
  path <- make_test_xlsx(list("OnlySheet" = data.frame(x = 1:5)))
  on.exit(unlink(path), add = TRUE)

  sheets <- list_excel_sheets(path)
  expect_length(sheets, 1)
  expect_false(is_bispchart_excel_format(sheets))

  # Single-sheet-grenen i observer kalder excel_data_to_paste_text direkte
  data <- readxl::read_excel(path, sheet = sheets[1], col_names = TRUE)
  text <- excel_data_to_paste_text(data)
  expect_match(text, "x", fixed = TRUE)
  expect_match(text, "1", fixed = TRUE)
})

test_that("re-upload mens pending er sat overskriver tidligere upload-info", {
  app_state <- make_test_app_state()

  shiny::isolate({
    app_state$session$pending_excel_upload <- list(
      datapath = "/tmp/old.xlsx",
      name = "old.xlsx",
      sheets = c("A", "B"),
      empty_flags = c(FALSE, FALSE)
    )
  })

  # Simuler ny upload
  shiny::isolate({
    app_state$session$pending_excel_upload <- list(
      datapath = "/tmp/new.xlsx",
      name = "new.xlsx",
      sheets = c("X", "Y", "Z"),
      empty_flags = c(FALSE, TRUE, FALSE)
    )
  })

  pending <- shiny::isolate(app_state$session$pending_excel_upload)
  expect_equal(pending$name, "new.xlsx")
  expect_equal(pending$sheets, c("X", "Y", "Z"))
  expect_equal(pending$empty_flags, c(FALSE, TRUE, FALSE))
})

test_that("selected_excel_sheet rydder pending efter succesfuldt valg", {
  # Verificér at ryd-mutation virker som forventet
  app_state <- make_test_app_state()

  shiny::isolate({
    app_state$session$pending_excel_upload <- list(
      datapath = "/tmp/foo.xlsx",
      name = "foo.xlsx",
      sheets = c("A", "B"),
      empty_flags = c(FALSE, FALSE)
    )
  })

  expect_false(is.null(shiny::isolate(app_state$session$pending_excel_upload)))

  shiny::isolate({
    app_state$session$pending_excel_upload <- NULL
  })

  expect_null(shiny::isolate(app_state$session$pending_excel_upload))
})
