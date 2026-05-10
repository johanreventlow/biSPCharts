## 1. JS-side (UUID + storage-event)

- [ ] 1.1 Generer per-tab UUID via `crypto.randomUUID()` ved page-load
- [ ] 1.2 Inkluder `tab_uuid` + `last_modified` i payload-format
- [ ] 1.3 Tilføj `window.addEventListener('storage', ...)` for cross-tab-detection
- [ ] 1.4 Send `Shiny.setInputValue("multi_tab_conflict_detected", {...})` ved konflikt
- [ ] 1.5 Pre-save-check: læs current localStorage-payload, sammenlign timestamp + UUID

## 2. R-side observer + modal

- [ ] 2.1 Ny observer i `utils_server_server_management.R` på `input$multi_tab_conflict_detected`
- [ ] 2.2 `shinyalert::shinyalert()` modal med to valg ("Behold" / "Overtag")
- [ ] 2.3 Rate-limit modal til 1 per 30s (forhindrer spam ved 3+ tabs)
- [ ] 2.4 Update `R/utils_local_storage.R` med UUID-payload-validation

## 3. Schema-version-migration

- [ ] 3.1 Bump `LOCAL_STORAGE_SCHEMA_VERSION` fra "3.0" til "4.0"
- [ ] 3.2 `migrate_legacy_no_uuid_payload()`: behandl 3.0-payloads som "anonymous tab"
- [ ] 3.3 Hard-reject ved version > 4.0 (forward-incompatible)

## 4. Tests

- [ ] 4.1 Opret `tests/testthat/test-multi-tab-conflict.R`
- [ ] 4.2 Mock storage-event + verificer observer trigger modal
- [ ] 4.3 Test payload-format-validation (UUID + timestamp present)
- [ ] 4.4 Test pre-save-check blokerer ved newer-tab-write
- [ ] 4.5 Test 3.0-til-4.0 migration

## 5. Documentation

- [ ] 5.1 Opdatér ADR-005 med multi-tab-section
- [ ] 5.2 User-guide-note om hvad der sker ved multi-tab-konflikt
- [ ] 5.3 CHANGELOG-entry

## 6. Validering

- [ ] 6.1 Manual test: 2 tabs, edit i begge, verificer konflikt-modal
- [ ] 6.2 Manual test: rate-limit virker ved 3+ tabs
- [ ] 6.3 `openspec validate multi-tab-conflict-detection --strict`
- [ ] 6.4 Fuld test-suite grøn
