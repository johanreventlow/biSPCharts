## ADDED Requirements

### Requirement: localStorage-payload SHALL inkludere tab-UUID og timestamp

Hver `saveAppState()`-payload SHALL inkludere `tab_uuid` (per-tab unique identifier genereret ved page-load via `crypto.randomUUID()`) og `last_modified` (epoch-ms timestamp). Bruges til konflikt-detektion mellem parallelle tabs der deler samme localStorage-key.

#### Scenario: Tab-UUID genereres unikt per tab

- **GIVEN** bruger åbner ny tab af biSPCharts
- **WHEN** JS-init kører
- **THEN** `window.SPC_TAB_UUID` SHALL sættes via `crypto.randomUUID()`
- **AND** UUID SHALL persistere kun i den tab's lifetime (ej localStorage)

#### Scenario: Payload-format indeholder UUID + timestamp

- **GIVEN** bruger trigger save (manual eller auto-save)
- **WHEN** `saveAppState()` skriver til localStorage
- **THEN** payload-JSON SHALL indeholde `tab_uuid` + `last_modified`
- **AND** `last_modified` SHALL være `Date.now()` (epoch-ms)

### Requirement: Multi-tab-konflikt SHALL detekteres og rapporteres til R

JS SHALL lytte til `window.storage`-event for at detektere skriv fra anden tab. Ved konflikt (other-tab-UUID ≠ current OG other-tab-`last_modified` > current-session-`loaded_at`) SHALL JS notificere R-side via `Shiny.setInputValue("multi_tab_conflict_detected", ...)`.

#### Scenario: Storage-event fra anden tab triggerer R-side notification

- **GIVEN** bruger har 2 tabs af biSPCharts åbne (Tab A + Tab B)
- **WHEN** Tab B skriver til localStorage
- **THEN** Tab A's `window.storage`-event SHALL fyre
- **AND** Tab A SHALL kalde `Shiny.setInputValue("multi_tab_conflict_detected", {tab_uuid: ..., last_modified: ...})`
- **AND** R-side observer SHALL vise konflikt-modal til bruger

#### Scenario: Pre-save-check blokerer overskriv af nyere data

- **GIVEN** Tab A loaded session ved T=0; Tab B skrev til localStorage ved T=10
- **WHEN** Tab A trigger save ved T=20
- **THEN** Pre-save-check SHALL detektere `localStorage.last_modified > Tab_A.loaded_at`
- **AND** save SHALL blokeres
- **AND** konflikt-modal SHALL vises med valg ("Behold mit arbejde" / "Overtag")

### Requirement: Schema-version SHALL bumpes til 4.0 ved payload-format-skift

`LOCAL_STORAGE_SCHEMA_VERSION` SHALL bumpes fra "3.0" til "4.0" pga. ny payload-format med UUID + timestamp. Migration fra 3.0 SHALL behandle legacy-payloads som "anonymous tab" (én warning, derefter normal funktion).

#### Scenario: 3.0-payload migration

- **GIVEN** localStorage indeholder payload med `schema_version: "3.0"` (uden UUID/timestamp)
- **WHEN** Tab loader payload
- **THEN** `migrate_legacy_no_uuid_payload()` SHALL injicere `tab_uuid: "legacy-anonymous"` + `last_modified: Date.now()`
- **AND** vise én-gangs-warning til bruger ("Session migreret fra ældre version")
- **AND** næste save SHALL bruge 4.0-format

#### Scenario: Forward-incompatible version hard-rejected

- **GIVEN** localStorage indeholder `schema_version: "5.0"` (fremtidig)
- **WHEN** Tab loader payload
- **THEN** payload SHALL hard-rejectes
- **AND** localStorage SHALL clear-en
- **AND** bruger SHALL se notification ("Inkompatibel session-version, starter frisk")
