# GitHub Labels Setup for Cross-Repository Coordination

This document describes the GitHub labels required for cross-repository coordination between biSPCharts and BFHcharts.

**Last Updated:** 2025-10-17

---

## Labels for biSPCharts Repository

### Coordination Labels

#### `bfhchart-escalation`
- **Description:** Issue requires changes in BFHcharts package
- **Color:** `#FFA500` (Orange)
- **Usage:** Apply when triaging reveals BFHcharts needs to implement fix/feature
- **Workflow:** Create corresponding BFHcharts issue, cross-link both

#### `bfhchart-blocked`
- **Description:** Waiting for BFHcharts release
- **Color:** `#D73A4A` (Red)
- **Usage:** Applied after escalation when waiting for BFHcharts implementation
- **Workflow:** Update when BFHcharts releases fix, then integrate into biSPCharts

#### `bfhchart-coordinated`
- **Description:** Coordinated development across both repositories
- **Color:** `#0052CC` (Blue)
- **Usage:** For features requiring changes in both biSPCharts and BFHcharts
- **Workflow:** Create coordination plan, assign ownership, schedule releases

#### `facade-layer`
- **Description:** Can be fixed in biSPCharts facade layer
- **Color:** `#0E8A16` (Green)
- **Usage:** After triage determines issue belongs in biSPCharts integration layer
- **Workflow:** Fix in biSPCharts without BFHcharts changes

#### `needs-triage`
- **Description:** Initial assessment needed to determine ownership
- **Color:** `#FBCA04` (Yellow)
- **Usage:** Default label for new issues before escalation decision
- **Workflow:** Review with decision tree, then apply appropriate coordination label

### Existing Standard Labels (to keep)
- `bug` - Fejl der skal rettes
- `enhancement` - Forbedringer og nye features
- `documentation` - Dokumentationsændringer
- `technical-debt` - Refaktorering og code quality
- `performance` - Performance-relaterede issues
- `testing` - Test coverage og test-relaterede opgaver

---

## Labels for BFHcharts Repository (Proposed)

### Coordination Labels

#### `spcify-request`
- **Description:** Feature request from biSPCharts users
- **Color:** `#FFA500` (Orange)
- **Usage:** For all issues escalated from biSPCharts
- **Workflow:** Tag issues with biSPCharts context for prioritization

#### `spcify-coordinated`
- **Description:** Coordinated with biSPCharts development
- **Color:** `#0052CC` (Blue)
- **Usage:** For coordinated feature development
- **Workflow:** Align release timing with biSPCharts

#### `high-priority-integration`
- **Description:** Blocks biSPCharts release
- **Color:** `#D73A4A` (Red)
- **Usage:** Critical issues blocking biSPCharts users
- **Workflow:** Prioritize for hotfix or next release

---

## Creating Labels via GitHub CLI

### biSPCharts Repository

```bash
# Navigate to biSPCharts repository
cd /path/to/biSPCharts

# Create coordination labels
gh label create "bfhchart-escalation" \
  --description "Issue requires changes in BFHcharts package" \
  --color "FFA500"

gh label create "bfhchart-blocked" \
  --description "Waiting for BFHcharts release" \
  --color "D73A4A"

gh label create "bfhchart-coordinated" \
  --description "Coordinated development across both repositories" \
  --color "0052CC"

gh label create "facade-layer" \
  --description "Can be fixed in biSPCharts facade layer" \
  --color "0E8A16"

gh label create "needs-triage" \
  --description "Initial assessment needed to determine ownership" \
  --color "FBCA04"
```

### BFHcharts Repository

```bash
# Navigate to BFHcharts repository
cd /path/to/BFHcharts

# Create coordination labels
gh label create "spcify-request" \
  --description "Feature request from biSPCharts users" \
  --color "FFA500"

gh label create "spcify-coordinated" \
  --description "Coordinated with biSPCharts development" \
  --color "0052CC"

gh label create "high-priority-integration" \
  --description "Blocks biSPCharts release" \
  --color "D73A4A"
```

---

## Creating Labels via GitHub Web UI

### Manual Creation Steps

1. Navigate to repository on GitHub
2. Click "Issues" tab
3. Click "Labels" button
4. Click "New label" button
5. Fill in:
   - **Label name:** (e.g., `bfhchart-escalation`)
   - **Description:** (see descriptions above)
   - **Color:** (use hex codes above)
6. Click "Create label"

---

## Label Workflow Examples

### Example 1: Escalation from biSPCharts to BFHcharts

**Initial state (biSPCharts):**
- Labels: `needs-triage`

**After triage:**
- Labels: `bfhchart-escalation`, `bug`
- Action: Create BFHcharts issue

**BFHcharts issue created:**
- Labels: `spcify-request`, `bug`

**Waiting for BFHcharts release (biSPCharts):**
- Labels: `bfhchart-blocked`, `bug`

**BFHcharts released (biSPCharts):**
- Remove: `bfhchart-blocked`
- Add: `facade-layer` (for integration work)

### Example 2: Coordinated Development

**biSPCharts issue:**
- Labels: `bfhchart-coordinated`, `enhancement`

**BFHcharts issue:**
- Labels: `spcify-coordinated`, `enhancement`

**Both issues reference coordination plan in description**

### Example 3: Critical Bug Blocking Release

**biSPCharts issue:**
- Labels: `bfhchart-escalation`, `bfhchart-blocked`, `bug`

**BFHcharts issue:**
- Labels: `spcify-request`, `high-priority-integration`, `bug`

**Indicates urgency for BFHcharts team**

---

## Label Statistics and Reporting

### Useful GitHub Searches

**biSPCharts: All BFHcharts-related issues**
```
label:bfhchart-escalation OR label:bfhchart-blocked OR label:bfhchart-coordinated
```

**biSPCharts: Blocked by BFHcharts**
```
is:open label:bfhchart-blocked
```

**biSPCharts: Needs triage**
```
is:open label:needs-triage
```

**BFHcharts: biSPCharts requests**
```
is:open label:spcify-request
```

**BFHcharts: High priority for biSPCharts**
```
is:open label:high-priority-integration
```

### Label Metrics

Track coordination health:

```bash
# Count biSPCharts issues blocked by BFHcharts
gh issue list --label "bfhchart-blocked" --state open | wc -l

# Count open BFHcharts requests
gh issue list --label "spcify-request" --state open | wc -l

# Coordinated issues
gh issue list --label "bfhchart-coordinated" --state open | wc -l
```

---

## Maintenance

### Review Cycle

**Quarterly review (January, April, July, October):**
1. Review label usage statistics
2. Check for inconsistent labeling
3. Update label descriptions if needed
4. Clean up stale labels
5. Add new labels if coordination patterns emerge

### Label Cleanup

Remove labels from resolved issues:
```bash
# Remove bfhchart-blocked from closed issues
gh issue list --label "bfhchart-blocked" --state closed --json number \
  | jq -r '.[].number' \
  | xargs -I {} gh issue edit {} --remove-label "bfhchart-blocked"
```

---

## Integration with Issue Templates

The issue template `.github/ISSUE_TEMPLATE/bfhchart-feature-request.md` automatically applies:
- `bfhchart-escalation`
- `enhancement`

When creating issues via template, these labels are pre-selected.

---

## Related Documentation

- **Decision Tree:** `.claude/ISSUE_ESCALATION_DECISION_TREE.md`
- **Coordination Guide:** `docs/CROSS_REPO_COORDINATION.md`
- **CLAUDE.md:** Section 5.3 - External Package Ownership

---

## Appendix: Label Color Palette

Consistent color scheme across repositories:

| Color | Hex Code | Usage |
|-------|----------|-------|
| Orange | `#FFA500` | Escalation/Request |
| Red | `#D73A4A` | Blocked/High Priority |
| Blue | `#0052CC` | Coordination |
| Green | `#0E8A16` | Can Fix (biSPCharts) |
| Yellow | `#FBCA04` | Needs Triage |

---

**Document Version:** 1.0.0
**Next Review:** 2026-01-17
