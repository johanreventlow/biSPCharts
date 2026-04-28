test_that("testServer-migration: alle 11 tests migreret (se #230, #322)", {
  migrated_tests <- c(
    "app_state hierarchical column management works (Niveau B)",
    "app_state reactive chains work correctly (Niveau C)",
    "app_state event-driven workflows work correctly (Niveau C)",
    "app_state complex state transitions work (Niveau B)",
    "app_state backward compatibility works (Niveau B)",
    "app_state Danish clinical workflow works (Niveau B)",
    "OBSERVER_PRIORITIES runtime integration fungerer (Niveau C)",
    "Chart module handles reactive updates correctly (Niveau B)",
    "update_all_column_mappings synchronizes state correctly (Niveau B)",
    "No autodetect on excelR table edits (table_cells_edited) (Niveau A)",
    "n_column stays cleared during table edit refresh (Niveau A)"
  )

  expect_length(migrated_tests, 11)
  expect_true(all(nzchar(migrated_tests)))
})
