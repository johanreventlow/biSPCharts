## ADDED Requirements

### Requirement: Automatic Session Data Persistence

The application SHALL automatically persist the user's current session state (data + metadata) to browser `localStorage` after any meaningful change, without requiring user intervention.

**Scope of persisted state:**
- Raw data frame (values + column classes)
- Column mappings: `x_column`, `y_column`, `n_column`, `skift_column`, `frys_column`, `kommentar_column`
- UI selections: `chart_type`, `target_value`, `centerline_value`, `y_axis_unit`
- Form fields: `indicator_title`, `indicator_description`, `unit_type`, `unit_select`, `unit_custom`
- Metadata: `timestamp`, `version`

**Trigger:**
- Debounced 2 seconds after data changes (via `get_save_interval_ms()`)
- Debounced 1 second after settings changes (`settings_save_interval_ms`)

**Feature flag:** `auto_save_enabled` in `inst/golem-config.yml` (default `true`)

#### Scenario: User uploads data and configures chart
- **WHEN** a user uploads a CSV/XLSX file and sets column mappings
- **THEN** within 2 seconds, the complete session state is saved to `localStorage` under key `spc_app_current_session`
- **AND** the browser `localStorage` entry contains valid JSON with `version = "2.0"`

#### Scenario: User modifies target value
- **WHEN** a user edits the target value input field
- **THEN** within 1 second, the updated settings are persisted
- **AND** the raw data is NOT re-transmitted (settings-only save)

#### Scenario: Auto-save is disabled via config
- **WHEN** `auto_save_enabled` is set to `false` in `golem-config.yml`
- **THEN** no auto-save observers are created during app initialization
- **AND** no `saveAppState` custom messages are sent to the browser

### Requirement: Automatic Session Restore

The application SHALL automatically restore a previously saved session from browser `localStorage` when the app loads, if `auto_restore_session` is enabled and valid saved data exists.

**Restore order (critical for correct state):**
1. Set guard flags (`restoring_session = TRUE`, `updating_table = TRUE`, `auto_save_enabled = FALSE`)
2. Restore metadata / UI form fields via `restore_metadata()` + `ui_service`
3. Reconstruct data.frame with full class preservation
4. Set `app_state$data$current_data` and `app_state$data$original_data`
5. Set completion flags (`file_uploaded = TRUE`, `auto_detect$completed = TRUE`)
6. Emit `data_updated` event with context `"session_restore"`
7. Reset guard flags via `on.exit()` cleanup

**Feature flag:** `auto_restore_session` in `inst/golem-config.yml`

#### Scenario: App loads with existing saved session
- **WHEN** the app loads and `window.hasAppState('current_session')` returns `true`
- **AND** `auto_restore_session` is `true`
- **THEN** the previously saved data and metadata are restored
- **AND** a notification is shown: `"Tidligere session automatisk genindlæst: N datapunkter fra DD-MM-YYYY HH:MM"`
- **AND** the SPC chart renders with the correct column mapping on first render (no "empty mapping" intermediate state)

#### Scenario: Metadata restore precedes data event
- **WHEN** the auto-restore observer processes saved state
- **THEN** `restore_metadata()` is called before `emit$data_updated()`
- **AND** downstream listeners (auto-detect, chart render) see the correct column mapping when `data_updated` fires

#### Scenario: Incompatible saved version detected
- **WHEN** the saved payload has `version != "2.0"`
- **THEN** the saved data is cleared via `clearDataLocally()`
- **AND** no restore is performed
- **AND** no user notification is shown (silent migration)

#### Scenario: Auto-restore disabled via config
- **WHEN** `auto_restore_session` is `false`
- **AND** valid saved state exists in `localStorage`
- **THEN** the saved state is NOT loaded automatically
- **AND** the app starts with empty session data

### Requirement: Data Type Preservation Across Roundtrip

The session persistence layer SHALL preserve R data types across the JSON roundtrip to `localStorage` and back, including types that require explicit metadata for reconstruction.

**Supported types:**
- `numeric` (double-precision float)
- `integer`
- `character`
- `logical`
- `Date`
- `POSIXct` with timezone attribute
- `factor` with levels

**Implementation:**
- `saveDataLocally()` extracts per-column class metadata via `extract_class_info()` helper
- `class_info` list contains: `primary`, `is_date`, `is_posixct`, `is_factor`, `levels`, `tz`
- Restore logic uses `restore_column_class()` helper to reconstruct correct R type

#### Scenario: Roundtrip preserves Date columns
- **WHEN** a data.frame contains a `Date` column with values like `as.Date("2026-01-15")`
- **AND** the session is saved and restored
- **THEN** the reconstructed column satisfies `inherits(reconstructed_col, "Date")`
- **AND** the values match the original exactly

#### Scenario: Roundtrip preserves POSIXct with timezone
- **WHEN** a data.frame contains a `POSIXct` column with `tz = "Europe/Copenhagen"`
- **AND** the session is saved and restored
- **THEN** `attr(reconstructed_col, "tzone") == "Europe/Copenhagen"`
- **AND** the values match the original exactly

#### Scenario: Roundtrip preserves factor with levels
- **WHEN** a data.frame contains a `factor` column with levels `c("Low", "Medium", "High")`
- **AND** the session is saved and restored
- **THEN** `levels(reconstructed_col) == c("Low", "Medium", "High")` in the original order
- **AND** the factor values match the original

#### Scenario: Roundtrip preserves integer type
- **WHEN** a data.frame contains an `integer` column (not `numeric`)
- **AND** the session is saved and restored
- **THEN** `is.integer(reconstructed_col) == TRUE`
- **AND** the column is NOT silently converted to `numeric`

### Requirement: Single JSON Encoding

The session persistence layer SHALL use single JSON encoding — R's `jsonlite::toJSON()` is the sole serializer, and JavaScript MUST NOT apply additional `JSON.stringify()` before storing in `localStorage`.

**Rationale:** Double-encoding produces escaped strings that cannot be correctly parsed on roundtrip, leading to silent data loss.

#### Scenario: Data is written with single encoding
- **WHEN** `saveDataLocally()` sends data via `session$sendCustomMessage()`
- **AND** the JavaScript `saveAppState` handler receives the message
- **THEN** the handler calls `localStorage.setItem(key, message.data)` WITHOUT additional `JSON.stringify`
- **AND** the stored value can be parsed with a single `JSON.parse()` call

#### Scenario: Data is read with single decoding
- **WHEN** `loadAppState()` retrieves a stored session
- **THEN** it calls `JSON.parse()` exactly once
- **AND** returns a structured JavaScript object (not a string)
- **AND** `Shiny.setInputValue("auto_restore_data", parsedObject)` transfers a list to R (not a character scalar)

### Requirement: Robust Error Handling with JS → R Feedback Channel

The session persistence layer SHALL communicate save success/failure from the browser back to R via a dedicated Shiny input, enabling graceful degradation on quota errors or other browser-side failures.

**Feedback mechanism:**
- JavaScript handler sets `Shiny.setInputValue("local_storage_save_result", { success, timestamp, key })` after every save attempt
- R-side observer reacts to failure by disabling auto-save and showing a Danish notification

#### Scenario: localStorage quota exceeded
- **WHEN** `localStorage.setItem()` throws `QuotaExceededError`
- **THEN** the JavaScript handler catches the error and returns `false`
- **AND** sends `local_storage_save_result` with `success: false`
- **AND** the R observer sets `app_state$session$auto_save_enabled <- FALSE`
- **AND** a Danish notification is shown: `"Browseren kan ikke gemme mere data (lokal lagerplads fuld). Automatisk lagring er deaktiveret for denne session."`
- **AND** the application continues to function normally (no crash, data still in memory)

#### Scenario: Successful save updates last_save_time
- **WHEN** `localStorage.setItem()` succeeds
- **THEN** `local_storage_save_result` is sent with `success: true`
- **AND** the R observer updates `app_state$session$last_save_time <- Sys.time()`
- **AND** the status display shows "Indstillinger gemt · N s siden"

#### Scenario: autoSaveAppState disables auto-save on failure
- **WHEN** `autoSaveAppState()` is called with a valid `app_state` parameter
- **AND** the underlying `saveDataLocally()` call returns `FALSE`
- **THEN** `app_state$session$auto_save_enabled` is set to `FALSE`
- **AND** subsequent auto-save triggers skip the save operation

### Requirement: Bounded Payload Size for DoS Protection

The session restore logic SHALL validate payload dimensions before reconstructing the data.frame to prevent memory exhaustion attacks.

**Limits:**
- `max_rows = 1e6` (1 million)
- `max_cols = 1000`
- `max_cells = 1e7` (10 million)
- Save-side limit: `object.size(current_data) < 1000000` (1 MB)

#### Scenario: Oversized payload rejected on restore
- **WHEN** a saved payload claims `nrows = 2e6`
- **THEN** the restore logic rejects the payload with an error
- **AND** no data.frame reconstruction is attempted
- **AND** the error is logged with context `SESSION_RESTORE`

#### Scenario: Oversized data skipped on save
- **WHEN** the current data.frame exceeds 1 MB
- **THEN** `autoSaveAppState()` skips the save
- **AND** a Danish notification is shown: `"Datasættet er for stort til automatisk lagring. Brug Download-knappen for at gemme manuelt."`
- **AND** `auto_save_enabled` remains `TRUE` (may succeed on smaller subsequent datasets)

### Requirement: Event-Driven Auto-Restore Initialization

The auto-restore mechanism SHALL wait for the Shiny session to be fully initialized before attempting to load saved data, using the `shiny:sessioninitialized` event instead of arbitrary timeouts.

**Rationale:** `setTimeout(500)` is a guess that can be too early (observer not yet registered, silent drop) or unnecessarily delayed.

#### Scenario: Restore fires after Shiny is ready
- **WHEN** the browser loads the app and `shiny:sessioninitialized` fires
- **AND** `hasAppState('current_session')` returns `true`
- **THEN** `Shiny.setInputValue('auto_restore_data', data, {priority: 'event'})` is called
- **AND** the R `observeEvent(input$auto_restore_data, ...)` handler receives the data

#### Scenario: No restore if no saved data
- **WHEN** `shiny:sessioninitialized` fires
- **AND** `hasAppState('current_session')` returns `false`
- **THEN** no `setInputValue` call is made
- **AND** the app starts with empty session state

### Requirement: Single Source of Truth for Feature Flags

The feature flag system SHALL read all session persistence settings from `inst/golem-config.yml` via `convert_profile_to_legacy_config()`. Parallel hardcoded paths MUST NOT exist.

**Config structure:**
```yaml
session:
  auto_save_enabled: true
  auto_restore_session: true
  save_interval_ms: 2000
  settings_save_interval_ms: 1000
```

**Access pattern:**
- `get_auto_save_enabled()` — returns `TRUE`/`FALSE`
- `get_auto_restore_enabled()` — returns `TRUE`/`FALSE`
- `get_save_interval_ms()` — returns integer milliseconds

#### Scenario: YAML change propagates to getters
- **WHEN** `auto_save_enabled` is set to `false` in `golem-config.yml`
- **AND** the app is restarted
- **THEN** `get_auto_save_enabled()` returns `FALSE`
- **AND** no auto-save observers are created

#### Scenario: No hardcoded determine_auto_restore_setting path
- **WHEN** the codebase is inspected for `determine_auto_restore_setting`
- **THEN** the function does not exist
- **AND** no hardcoded TRUE/FALSE returns based on `is_prod_mode()`/`is_dev_mode()` are present

### Requirement: Diskret Save Status Display

The application SHALL show a subtle status indicator in the wizard toolbar showing when the session was last saved, providing passive feedback without UI clutter.

**Display logic:**
- `last_save_time` is NULL → show nothing
- `last_save_time` within 60 seconds → "Indstillinger gemt · N s siden"
- `last_save_time` within 60 minutes → "Indstillinger gemt · N min siden"
- `last_save_time` older → "Indstillinger gemt · tidligere"
- `auto_save_enabled == FALSE` → "Automatisk lagring deaktiveret"

#### Scenario: Status updates after save
- **WHEN** a save completes successfully
- **AND** `last_save_time` is updated to current time
- **THEN** the status display shows "Indstillinger gemt · 0 s siden"
- **AND** the display auto-refreshes as time passes (reactive)

#### Scenario: Status hidden before first save
- **WHEN** the user has just opened the app and not made any changes
- **AND** `last_save_time` is NULL
- **THEN** the status display area is empty (no placeholder text)

#### Scenario: Status shows disabled state after quota error
- **WHEN** `auto_save_enabled` transitions to FALSE due to a quota error
- **THEN** the status display shows "Automatisk lagring deaktiveret"
