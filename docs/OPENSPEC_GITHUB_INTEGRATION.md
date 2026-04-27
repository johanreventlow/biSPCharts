# OpenSpec ↔ GitHub Issues Integration

Beskriver hvordan biSPCharts kobler OpenSpec change-proposals til GitHub Issues for sporbarhed, projekt-boards og cross-references.

> Pruned ud af `openspec/config.yaml` 2026-04-27 for at minimere context-injection per artifact-prompt. Slash-kommandoerne (`/opsx:propose`, `/opsx:apply`, `/opsx:archive`) kender workflowet — denne fil er reference for manuelle indgreb og rationale.

---

## Rationale

biSPCharts bruger en **komplementær tilgang** hvor OpenSpec-changes spores via:
- `tasks.md` — single source of truth for implementations-detaljer
- GitHub Issues — high-level tracking, projekt-boards, search, notifikationer

**Hvorfor begge:**
- Bevarer OpenSpec-workflow (offline-first, struktureret validering)
- Gevinst: GitHub-synlighed (boards, search, notifikationer, cross-references)
- Matcher CLAUDE.md-kravet om obligatorisk GitHub issue-tracking
- Aktiverer automation via slash-kommandoer

---

## Label System

**OpenSpec-specifikke labels:**
- `openspec-proposal` — change i proposal-fase (gul)
- `openspec-implementing` — change under implementation (blå)
- `openspec-deployed` — change arkiveret/deployet (grøn)

**Type-labels (eksisterende):** `enhancement`, `bug`, `documentation`, `technical-debt`, `performance`, `testing`

**Coordination-labels:** `bfhchart-escalation`, `bfhchart-blocked`, `bfhchart-coordinated` (cross-repo)

Label-setup: se `docs/GITHUB_LABELS_SETUP.md`.

---

## Automated Workflow

### Stage 1: Proposal (`/opsx:propose`)

```bash
gh issue create --title "[OpenSpec] add-feature" \
  --body "$(cat openspec/changes/add-feature/proposal.md)" \
  --label "openspec-proposal,enhancement"
```

Issue-reference tilføjes automatisk i `proposal.md`:

```markdown
## Related
- GitHub Issue: #142
```

### Stage 2: Implementation (`/opsx:apply`)

```bash
gh issue edit 142 --add-label "openspec-implementing" --remove-label "openspec-proposal"
gh issue comment 142 --body "Implementation started"
```

### Stage 3: Archive (`/opsx:archive`)

```bash
gh issue edit 142 --add-label "openspec-deployed" --remove-label "openspec-implementing"
gh issue close 142 --comment "Deployed via openspec archive on $(date +%Y-%m-%d)"
```

---

## Linking Pattern

**I `proposal.md`:**

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

**I `tasks.md`:**

```markdown
## 1. Implementation
- [ ] 1.1 Create schema (see #142)
- [ ] 1.2 Write tests (see #142)
- [ ] 1.3 Deploy (see #142)

Tracking: GitHub Issue #142
```

---

## Manual Operations

Hvis automatik fejler eller manuel intervention er nødvendig:

```bash
# Opret issue
gh issue create --title "[OpenSpec] add-feature" \
  --body "$(cat openspec/changes/add-feature/proposal.md)" \
  --label "openspec-proposal,enhancement"

# Opdater label under implementation
gh issue edit 142 --add-label "openspec-implementing" --remove-label "openspec-proposal"

# Luk efter deploy
gh issue close 142 --comment "Deployed via openspec archive on 2025-11-02"
```

---

## Best Practices

**Do:**
- Opret GitHub-issue for hver OpenSpec-change (automatisk via `/opsx:propose`)
- Reference issue i commits (`fixes #142`, `relates to #142`)
- Hold `tasks.md` som autoritativ kilde til implementation
- Brug GitHub-issue til diskussion og stakeholder-synlighed
- Opdater labels løbende (automatisk via slash-kommandoer)

**Don't:**
- Spring ikke GitHub-issue over (bryder biSPCharts tracking-krav)
- Opdater ikke `tasks.md` via GitHub (sync er one-way)
- Luk ikke issues før archive (brug `/opsx:archive`-flow)
- Brug ikke GitHub-issues til implementations-checklister (det er `tasks.md`-rolle)

---

## Cross-Repository Coordination

Når en OpenSpec-change påvirker eksterne pakker (BFHcharts, BFHtheme, Ragnar, BFHllm):

1. Opret OpenSpec-proposal med GitHub-issue i biSPCharts-repo
2. Hvis ekstern pakke skal ændres:
   - Opret separat issue i ekstern repo via `.github/ISSUE_TEMPLATE/bfhchart-feature-request.md`
   - Tilføj coordination-labels (`bfhchart-escalation`, `bfhchart-coordinated`)
   - Cross-reference: `Blocked by BFHcharts#45` i biSPCharts-issue
3. Spor begge issues' livscyklus uafhængigt
4. Arkivér biSPCharts-change KUN efter eksterne dependencies er deployet

Detaljeret workflow: `docs/CROSS_REPO_COORDINATION.md`.
