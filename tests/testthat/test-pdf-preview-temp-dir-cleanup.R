# test-pdf-preview-temp-dir-cleanup.R
# Cycle E NEW2 (Codex 2026-05-10): regression-tests for exception-safe
# temp_dir-cleanup i generate_pdf_preview().
#
# Pre-fix: explicit unlink(temp_dir) paa happy-path (linje ~417). Hvis
# ggsave/bfh_extract_spc_stats/bfh_create_typst_document/inject_template_
# assets/system2(quarto) throws -> safe_operation fallback uden cleanup
# -> tempdir-leak per failed preview. Bounded af R-session, men braekker
# invariant.
#
# Post-fix: on.exit(unlink(temp_dir), add=TRUE) garantor cleanup uanset
# exit-path.

test_that("generate_pdf_preview() bruger on.exit for temp_dir-cleanup", {
  require_internal("generate_pdf_preview", mode = "function")
  body_text <- paste(deparse(body(generate_pdf_preview)), collapse = "\n")

  expect_true(
    grepl("on\\.exit\\s*\\(\\s*unlink\\s*\\(\\s*temp_dir", body_text),
    info = paste(
      "generate_pdf_preview skal bruge on.exit(unlink(temp_dir, ...))",
      "for at sikre cleanup uanset exception-paths (Cycle E NEW2)."
    )
  )
})

test_that("generate_pdf_preview() har on.exit FOER risikable kald", {
  require_internal("generate_pdf_preview", mode = "function")
  body_text <- paste(deparse(body(generate_pdf_preview)), collapse = "\n")

  on_exit_pos <- regexpr("on\\.exit\\s*\\(\\s*unlink", body_text)
  ggsave_pos <- regexpr("ggsave", body_text)
  system2_pos <- regexpr("system2", body_text)

  if (on_exit_pos[1] > 0 && ggsave_pos[1] > 0) {
    expect_lt(
      on_exit_pos[1], ggsave_pos[1],
      label = "on.exit skal staa FOER ggsave-kald"
    )
  }
  if (on_exit_pos[1] > 0 && system2_pos[1] > 0) {
    expect_lt(
      on_exit_pos[1], system2_pos[1],
      label = "on.exit skal staa FOER system2-kald"
    )
  }
})

test_that("generate_pdf_preview() undgaar double-cleanup (ej explicit unlink i happy-path)", {
  require_internal("generate_pdf_preview", mode = "function")
  body_text <- paste(deparse(body(generate_pdf_preview)), collapse = "\n")

  # Taeller hvor mange unlink(temp_dir, recursive = TRUE)-kald body har.
  # Forventer KUN 1 (i on.exit). Tidligere implementation havde 2 (explicit
  # i happy-path + ingen i fail-path). Nu: 1 (on.exit garantor begge paths).
  unlink_matches <- gregexpr("unlink\\s*\\(\\s*temp_dir", body_text)[[1]]
  unlink_count <- if (unlink_matches[1] == -1) 0 else length(unlink_matches)

  expect_equal(
    unlink_count, 1,
    info = paste(
      "Forventer kun 1 unlink(temp_dir)-kald (i on.exit). Hvis 2:",
      "double-cleanup (harmless men misvisende). Hvis 0: cleanup mangler."
    )
  )
})
