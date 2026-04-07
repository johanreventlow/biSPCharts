# Project Context

## Purpose

**biSPCharts** is a production-grade Shiny application for Statistical Process Control (SPC) analysis, developed for clinical quality improvement work at Bispebjerg og Frederiksberg Hospital in Copenhagen, Denmark.

**Goals:**
- Enable clinicians to create and interpret SPC charts (run charts, control charts) for quality monitoring
- Provide AI-powered improvement suggestions using RAG-enhanced LLM context
- Ensure stability, reliability, and ease of use in a healthcare setting
- Support Danish language for all user-facing text
- Maintain industrial-standard code quality with TDD, centralized state management, and robust error handling

## Tech Stack

**Core Framework:**
- R 4.x
- Shiny (Golem framework for production apps)
- Centraliseret `app_state` (reactiveValues) som single source of truth

**Visualization & SPC:**
- BFHcharts - SPC chart rendering and visualization (hospital-maintained)
- BFHtheme - Hospital branding, themes, fonts (hospital-maintained)
- qicharts2 - Anhøj rules calculation (special cause detection)

**AI/LLM Integration:**
- Ragnar - RAG knowledge store framework (tidyverse-style, hospital-maintained)
- Gemini API - LLM provider for AI improvement suggestions
- DuckDB - Vector store backend (via Ragnar)

**Development Tools:**
- testthat - Unit and integration testing
- devtools - Package development workflow
- mockery - Test mocking
- microbenchmark - Performance testing
- shinytest2 - UI regression og snapshot tests
- lintr + styler - Linting og formattering
- renv - Dependency lock og reproducible builds
- openspec CLI - Spec management og change tracking

**Configuration & Environment:**
- Golem options styres via `GOLEM_CONFIG_ACTIVE` (`dev`, `test`, `prod`)
- Standard: dev/test = `test_mode_auto_load = TRUE`, prod = `FALSE`
- `options(spc.debug.source_loading = TRUE)` til udvidet fejlsøgning i udvikling
- Secrets håndteres via `.Renviron`/env vars (`GOOGLE_API_KEY`, `GEMINI_API_KEY`)
- `ensure_module_loaded()` til lazy loading af tunge moduler

## Project Conventions

### Code Style

**Language:**
- Code (functions, variables): English
- Comments: Danish
- UI text: Danish
- Error messages: Danish, user-friendly

**Naming Conventions:**
- Functions: `snake_case` (e.g., `generate_ai_improvement_suggestion`)
- Modules: `mod_<name>_ui()` and `mod_<name>_server()` (Golem convention)
- Utils: `utils_<domain>.R` (e.g., `utils_ragnar_integration.R`)
- Factories: `fct_<name>.R` (e.g., `fct_ai_improvement_suggestions.R`)
- Config: `config_<domain>.R` (e.g., `config_observer_priorities.R`)

**File Organization:**
- `R/` - Application code
- `tests/testthat/` - Automated tests
- `tests/manual/` - Manual verification scripts (external APIs)
- `inst/` - Installation files (knowledge base, config)
- `data-raw/` - Data processing scripts (RAG store build)
- `docs/` - Documentation

### Observability & Error Handling

- Brug `safe_operation()` til alle kritiske stateændringer og sideeffects
- Struktureret logging via `log_debug()`, `log_info()`, `log_warn()`, `log_error()`
- Alle log-kald kræver `component`-label (fx `[APP_SERVER]`) og relevante `details`
- Fejl håndteres via `log_error(..., show_user = TRUE/FALSE)` afhængigt af brugerfeedback
- Ingen direkte `cat()` eller `print()` i produktion – log eller UI-feedback i stedet
- Graceful degradation: fallback-scenarier for eksterne services (Ragnar, Gemini)
- Guard conditions: tidlig exit når afhængigheder ikke er klar (`req()`, `validate()`)

### Architecture Patterns

**Unified Event Architecture:**
- Centralized event bus: `app_state$events` (reactiveValues in global.R)
- Emit API: `emit$data_updated()`, `emit$auto_detection_completed()`, etc.
- Emitters defineres i `create_emit_api()`, lyttere samles i `setup_event_listeners()`
- Event listeners: `observeEvent()` with explicit priorities
- No direct reactive dependencies across modules

**Hierarchical App State:**
```r
app_state$events         # Event triggers (integers, increment to fire)
app_state$data           # current_data, original_data, file_info
app_state$columns        # auto_detect, mappings, ui_sync
app_state$session        # Session state
```
Administreres centralt i `R/state_management.R`

**BFHcharts + qicharts2 Hybrid:**
- BFHcharts: Primary chart rendering, theming, visual output
- qicharts2: Anhøj rules calculation, special cause metadata
- No direct qicharts2 plotting (use BFHcharts exclusively)

**RAG-Enhanced AI:**
- Knowledge retrieval before LLM calls
- Graceful degradation (continue without RAG if retrieval fails)
- Session-based caching to reduce API calls

**Defensiv state management:**
- Guard-funktioner forhindrer race conditions (`app_state$data$updating_table`, `auto_detect$in_progress`)
- Atomiske opdateringer via `safe_operation()` omkring state og UI-opdateringer
- `OBSERVERS` prioriteres via `OBSERVER_PRIORITIES`, undgå cirkulære triggere
- Input debouncing (standard 800ms) på hyppige UI-events

### Development Workflow

- Test-driven development (TDD) er obligatorisk – skriv tests før implementation
- Brug `tests/testthat/` til automatiserede enheder og integration, `tests/manual/` til API-verifikation
- Kør `R -e "library(biSPCharts); testthat::test_dir('tests/testthat')"` før commit
- Performance verificeres med `microbenchmark` og `profvis` ved behov
- `lintr::lint_package()` og `styler::style_pkg()` for code quality
- Ved større ændringer: udarbejd OpenSpec change proposal og kør `openspec validate --strict`
- Følg pre-commit tjeklisten (tests, manuel funktionstest, logging, error handling, performance, dokumentation, package loading, lintr)

### Testing Strategy

**Coverage Targets:**
- 100% of critical paths (data load, plot generation, state sync)
- ≥90% overall coverage
- All edge cases (null, empty datasets, errors, large files)

**Test Categories:**
- **Automated (CI/CD):** Unit tests, integration tests (`tests/testthat/`)
- **Manual:** External API verification (`tests/manual/verify_rag.R`)

**Mocking:**
- Use `mockery::stub()` for external dependencies (API calls, file I/O)
- Never use deprecated `with_mock()` (testthat legacy)

**Test Commands:**
```r
# All tests
R -e "library(biSPCharts); testthat::test_dir('tests/testthat')"

# Specific test
R -e "source('global.R'); testthat::test_file('tests/testthat/test-*.R')"
```

### Git Workflow

**Branching Strategy:**
- `master` - Production-ready code
- `feat/<name>` - New features
- `fix/<name>` - Bug fixes
- `docs/<name>` - Documentation updates

**Commit Conventions:**
- Format: `type(scope): kort handle-orienteret beskrivelse`
- Body: Fritekst på dansk med rationale, testresultater og eventuelle bullet points
- Reference relaterede issues i brødteksten (`Fixes #123`)
- Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`
- Scope er valgfrit, brug lowercase (`feat(server): ...`)
- **NO Claude attribution footers** (critical constraint)

**Workflow:**
1. Create feature branch from master
2. Implement with tests
3. Commit når tests består og referer GitHub issue
4. Stop efter commit med mindre bruger beder om push/PR
5. Merge til master kræver eksplicit godkendelse

## Domain Context

**Statistical Process Control (SPC):**
- **Serieplot** = SPC chart (run chart, control chart)
- **Centrallinje** = Center line (median or mean)
- **Kontrolgrænser** = Control limits (3-sigma bounds)
- **Anhøj rules** = Special cause detection rules (Anhøj methodology)

**Chart Types:**
- Run charts (median-based)
- Control charts: I, MR, Xbar, S, P, P', U, U', C, G, T charts
- Danish → English mapping via `config_chart_types.R`

**Healthcare Context:**
- Clinical quality improvement use case
- Hospital branding required (BFH colors, fonts, logo)
- Data sensitivity (no PHI/PII in knowledge base or logs)
- User base: Clinicians (not statisticians)

**SPC Knowledge Base:**
- Location: `inst/spc_knowledge/`
- Content: SPC methodology, Anhøj rules interpretations, chart selection guidance
- Format: Markdown files (chunked for RAG)

## Important Constraints

### External Package Ownership (CRITICAL)

**DO NOT implement functionality in biSPCharts that belongs in external packages:**

- **BFHcharts** - Chart rendering, SPC visualization, target lines, freezing
- **BFHtheme** - Hospital branding, themes, fonts, colors
- **Ragnar** - RAG store operations, embeddings, retrieval algorithms, chunking

**Process for external package features:**
1. Identify missing functionality in external package
2. Document need (issue, ADR, docs)
3. Inform maintainer (feature request)
4. Temporary workaround in biSPCharts IF critical (mark clearly)
5. Remove workaround when available in external package

### Git Constraints (CRITICAL)

**NEVER:**
1. Merge to master/main without explicit approval
2. Push to remote without user request
3. Add Claude attribution footers to commits:
   - ❌ "🤖 Generated with [Claude Code]"
   - ❌ "Co-Authored-By: Claude <noreply@anthropic.com>"

### Configuration Immutability

**DO NOT modify without approval:**
- `brand.yml` - Hospital branding configuration
- `NAMESPACE` - Use `devtools::document()` instead
- Breaking changes without major version bump

### Quality & Testing (CRITICAL)

- Test-first udvikling (TDD) er påkrævet for alle ændringer
- Ingen code changes uden tilsvarende automatiserede tests og opdateret dækning
- Brug `safe_operation()` og struktureret logging ved nye workflow-kæder
- Kør komplette `testthat`-suites og `lintr` før commit; dokumenter resultater i commit body
- Performance-regressioner skal begrundes og måles (microbenchmark/profvis)

### Performance Targets

- Startup time: <100ms (production mode via `library(biSPCharts)`)
- Chart rendering: <500ms for typical dataset (<10k points)
- RAG query: <100ms retrieval time

## External Dependencies

### Hospital-Maintained Packages

**BFHcharts** (maintainer: Johan Reventlow)
- Purpose: SPC chart rendering and visualization
- API: `create_spc_chart()`, `add_target_line()`, etc.
- Constraints: Full maintainer control, escalate chart rendering issues

**BFHtheme** (maintainer: Johan Reventlow)
- Purpose: Hospital branding (colors, fonts, themes)
- API: `theme_bfh()`, `scale_color_bfh()`, etc.
- Constraints: Full maintainer control, escalate styling issues

**Ragnar** (maintainer: Johan Reventlow)
- Purpose: RAG knowledge store framework
- API: `ragnar_store()`, `ragnar_retrieve()`, `ragnar_store_ingest()`, etc.
- Constraints: Full maintainer control, escalate RAG infrastructure issues

### External APIs

**Gemini API (Google)**
- Purpose: LLM provider for AI improvement suggestions
- Authentication: `GOOGLE_API_KEY` environment variable
- Fallback: `GOOGLE_API_KEY` → `GEMINI_API_KEY` (automatic runtime)
- Cost: API calls (embeddings + generation)
- Caching: Session-based to reduce costs

### External SPC Package

**qicharts2** (Jacob Anhøj)
- Purpose: Anhøj rules calculation (special cause detection)
- Usage: Metadata extraction ONLY (not for plotting)
- Constraints: Read-only, no modifications to qicharts2 logic

### Development Tools

**GitHub API** (via `gh` CLI)
- Purpose: Issue tracking, PR management
- Authentication: GitHub token
- Usage: `gh issue create`, `gh pr create`

**Gemini CLI** (optional)
- Purpose: Large codebase analysis
- Usage: Cross-module architecture verification, pattern detection

## GitHub Integration

### OpenSpec + GitHub Issues

biSPCharts uses a **complementary approach** where OpenSpec changes are tracked via both `tasks.md` files (source of truth for implementation details) and GitHub issues (high-level tracking and visibility).

**Rationale:**
- Preserves OpenSpec workflow (offline-first, structured validation)
- Gains GitHub visibility (project boards, search, notifications, cross-references)
- Fits biSPCharts's mandatory GitHub issue tracking (CLAUDE.md requirement)
- Enables automation via slash commands

### Label System

**OpenSpec-specific labels:**
- `openspec-proposal` - Change in proposal phase (yellow)
- `openspec-implementing` - Change being implemented (blue)
- `openspec-deployed` - Change archived/deployed (green)

**Type labels (existing):**
- `enhancement`, `bug`, `documentation`, `technical-debt`, `performance`, `testing`

**Coordination labels (existing):**
- `bfhchart-escalation`, `bfhchart-blocked`, `bfhchart-coordinated` (cross-repo coordination)

### Automated Workflow

**Stage 1: Proposal** (`/openspec:proposal`)
```bash
# Automatically creates GitHub issue with:
gh issue create --title "[OpenSpec] add-feature" \
  --body "$(cat openspec/changes/add-feature/proposal.md)" \
  --label "openspec-proposal,enhancement"

# Issue reference added to proposal.md:
## Related
- GitHub Issue: #142
```

**Stage 2: Implementation** (`/openspec:apply`)
```bash
# Updates issue label and adds comment:
gh issue edit 142 --add-label "openspec-implementing" --remove-label "openspec-proposal"
gh issue comment 142 --body "Implementation started"
```

**Stage 3: Archive** (`/openspec:archive`)
```bash
# Updates label, closes issue with timestamp:
gh issue edit 142 --add-label "openspec-deployed" --remove-label "openspec-implementing"
gh issue close 142 --comment "Deployed via openspec archive on $(date +%Y-%m-%d)"
```

### Linking Pattern

**In proposal.md:**
```markdown
## Why
[Problem description]

## What Changes
- [Change list]

## Impact
- Affected specs: [capabilities]
- Affected code: [files]

## Related
- GitHub Issue: #142
```

**In tasks.md:**
```markdown
## 1. Implementation
- [ ] 1.1 Create schema (see #142)
- [ ] 1.2 Write tests (see #142)
- [ ] 1.3 Deploy (see #142)

Tracking: GitHub Issue #142
```

### Manual Operations

If automatic GitHub integration fails or needs manual intervention:

```bash
# Create issue manually
gh issue create --title "[OpenSpec] add-feature" \
  --body "$(cat openspec/changes/add-feature/proposal.md)" \
  --label "openspec-proposal,enhancement"

# Update labels manually during implementation
gh issue edit 142 --add-label "openspec-implementing" --remove-label "openspec-proposal"

# Close manually after deployment
gh issue close 142 --comment "Deployed via openspec archive on 2025-11-02"
```

### Best Practices

**Do:**
- ✅ Create GitHub issue for every OpenSpec change (automatic via `/openspec:proposal`)
- ✅ Reference issue in commit messages (`fixes #142`, `relates to #142`)
- ✅ Keep tasks.md as source of truth for implementation details
- ✅ Use GitHub issue for discussions and stakeholder visibility
- ✅ Update issue labels as workflow progresses (automatic via slash commands)

**Don't:**
- ❌ Skip GitHub issue creation (breaks biSPCharts tracking requirement)
- ❌ Update tasks.md via GitHub (tasks.md is authoritative, sync is one-way)
- ❌ Close issues before archiving change (use `/openspec:archive` workflow)
- ❌ Use GitHub issues for implementation checklists (that's tasks.md's role)

### Cross-Repository Coordination

When OpenSpec changes affect external packages (BFHcharts, BFHtheme, Ragnar):

1. Create OpenSpec proposal with GitHub issue in biSPCharts repo
2. If external package changes needed:
   - Create separate issue in external repo using `.github/ISSUE_TEMPLATE/bfhchart-feature-request.md`
   - Add coordination labels (`bfhchart-escalation`, `bfhchart-coordinated`)
   - Cross-reference issues: `Blocked by BFHcharts#45` in biSPCharts issue
3. Track both issues lifecycle independently
4. Archive biSPCharts change only after external dependencies deployed

See `docs/CROSS_REPO_COORDINATION.md` for detailed coordination workflow.
