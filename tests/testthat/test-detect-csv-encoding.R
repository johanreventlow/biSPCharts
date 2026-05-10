# test-detect-csv-encoding.R
# Cycle D H2 (Codex 2026-05-10): regression-tests for detect_csv_encoding()
# helper + upload-flow latin1-fallback.
#
# Pre-fix: handle_csv_upload() kaldte parse_file('csv') uden encoding_hints
# -> defaulter til UTF-8 -> mojibake i danske CSV-headers (Måned, Afdeling)
# fra dansk Excel/Windows-eksport.
#
# Post-fix: detect_csv_encoding() returnerer 'UTF-8' eller 'latin1' baseret
# paa validity-tjek; handle_csv_upload bruger den i parse_file-call.

test_that("detect_csv_encoding returnerer UTF-8 for valid UTF-8 fil", {
  require_internal("detect_csv_encoding", mode = "function")

  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)
  writeLines(c("Maaned;Antal", "Jan;5", "Feb;3"), tmp)

  expect_equal(detect_csv_encoding(tmp), "UTF-8")
})

test_that("detect_csv_encoding returnerer UTF-8 for valid UTF-8 med danske chars", {
  require_internal("detect_csv_encoding", mode = "function")

  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)
  # Skriv UTF-8 med danske chars
  con <- file(tmp, "wb")
  utf8_text <- enc2utf8("Måned;Antal\nJan;5\n")
  writeBin(charToRaw(utf8_text), con)
  close(con)

  expect_equal(detect_csv_encoding(tmp), "UTF-8")
})

test_that("detect_csv_encoding returnerer latin1 for Windows-1252 fil", {
  require_internal("detect_csv_encoding", mode = "function")

  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)
  # Skriv latin1-encoded med danske chars
  con <- file(tmp, "wb")
  latin1_bytes <- iconv("Måned;Antal\nJan;5\n", to = "latin1", toRaw = TRUE)[[1]]
  writeBin(latin1_bytes, con)
  close(con)

  expect_equal(detect_csv_encoding(tmp), "latin1")
})

test_that("detect_csv_encoding haandterer tom fil gracefully", {
  require_internal("detect_csv_encoding", mode = "function")

  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)
  file.create(tmp)

  # Tom fil = ingen invalid bytes -> default UTF-8
  expect_equal(detect_csv_encoding(tmp), "UTF-8")
})

test_that("handle_csv_upload bruger detect_csv_encoding i parse_file-call", {
  require_internal("handle_csv_upload", mode = "function")
  body_text <- paste(deparse(body(handle_csv_upload)), collapse = "\n")

  expect_true(
    grepl("detect_csv_encoding", body_text),
    info = "handle_csv_upload skal kalde detect_csv_encoding for at detektere encoding"
  )
  expect_true(
    grepl("encoding_hints\\s*=\\s*list\\s*\\(\\s*encoding", body_text),
    info = "handle_csv_upload skal pasere encoding_hints med detected encoding til parse_file"
  )
})
