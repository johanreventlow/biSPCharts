## MODIFIED Requirements

### Requirement: Viewport Dimension Tracking

The system SHALL track viewport dimensions for responsive chart rendering. Dimension updates SHALL only trigger visualization re-computation when width or height has actually changed, to prevent unnecessary invalidations and cache updates.

#### Scenario: Viewport dimensions unchanged
- **WHEN** set_viewport_dims() is called with dimensions identical to current state
- **THEN** no visualization_update_needed event is emitted
- **AND** no cache invalidation occurs

#### Scenario: Viewport dimensions changed
- **WHEN** set_viewport_dims() is called with different width or height
- **THEN** visualization_update_needed event is emitted
- **AND** chart re-renders with new dimensions

## ADDED Requirements

### Requirement: Centralized Upload Thresholds

The system SHALL define upload validation thresholds (maximum file size, maximum line count, warning row count) as centralized configuration constants with getter functions, rather than hardcoded values in validation logic.

#### Scenario: Upload threshold access
- **WHEN** upload validation checks file size or row count
- **THEN** thresholds are retrieved via getter functions from config_system_config.R
- **AND** no hardcoded numeric literals are used in validation paths
