# test-export-filename-byte-cap.R
# Cycle E NEW3 (Codex 2026-05-10): regression-tests for byte-aware filename-cap.
#
# Pre-fix: generate_export_filename() havde ingen length-cap. Title (max 200)
# + dept (max 250) + prefix + extension kunne naa ~460 chars. Med danske
# karakter (UTF-8 multi-byte) kunne 240 chars = 480 bytes -> over NTFS/ext4
# 255-byte cap.
#
# Post-fix: byte-aware truncation-loop reserverer plads til extension og
# fjerner chars (NOT bytes!) en ad gangen indtil byte-cap respekteres.
# Forhindrer split af multi-byte code points.
#
# Codex empirisk: 240 'æ' = 480 bytes. nchar() default = chars, ikke bytes.
# Korrekt fix kraever nchar(x, type='bytes').

test_that("filename respekterer 255-byte cap med ASCII-only inputs", {
  require_internal("generate_export_filename", mode = "function")

  long_title <- strrep("A", 200)
  long_dept <- strrep("B", 250)
  filename <- generate_export_filename("pdf", long_title, long_dept)

  expect_lte(
    nchar(filename, type = "bytes"), 255L,
    label = "ASCII-only filename byte-count <= 255"
  )
})

test_that("filename respekterer 255-byte cap med danske multi-byte chars", {
  require_internal("generate_export_filename", mode = "function")

  # Codex empirisk: æ = 2 bytes UTF-8. 240 'æ' = 480 bytes.
  long_title <- strrep("æ", 200) # æ x 200 = 400 bytes
  long_dept <- strrep("ø", 250) # ø x 250 = 500 bytes
  filename <- generate_export_filename("pdf", long_title, long_dept)

  expect_lte(
    nchar(filename, type = "bytes"), 255L,
    label = "Danish multi-byte filename byte-count <= 255"
  )
})

test_that("filename bevarer extension efter truncation", {
  require_internal("generate_export_filename", mode = "function")

  long_title <- strrep("æ", 300)
  filename_pdf <- generate_export_filename("pdf", long_title, "")
  filename_png <- generate_export_filename("png", long_title, "")

  expect_true(
    grepl("\\.pdf$", filename_pdf),
    info = "PDF-extension skal bevares efter truncation"
  )
  expect_true(
    grepl("\\.png$", filename_png),
    info = "PNG-extension skal bevares efter truncation"
  )
})

test_that("filename ej braekker korte inputs", {
  require_internal("generate_export_filename", mode = "function")

  short_filename <- generate_export_filename("pdf", "Test", "Afdeling")
  # Forventer noget i stil med "SPC_Afdeling_Test.pdf" -- under cap
  expect_lt(nchar(short_filename, type = "bytes"), 100L)
  expect_true(nchar(short_filename) > nchar(".pdf"),
    info = "Korte inputs skal producere meningsfuldt filename"
  )
})

test_that("body indeholder byte-aware nchar-kald", {
  require_internal("generate_export_filename", mode = "function")
  body_text <- paste(deparse(body(generate_export_filename)), collapse = "\n")

  expect_true(
    grepl("nchar\\([^)]*type\\s*=\\s*[\"']bytes[\"']", body_text),
    info = "generate_export_filename skal bruge nchar(..., type='bytes') for byte-aware cap"
  )
  expect_true(
    grepl("enc2utf8", body_text),
    info = "Skal normalisere encoding via enc2utf8 foer byte-counting"
  )
})
