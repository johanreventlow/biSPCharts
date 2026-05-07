# Architecture Decision Records (ADRs)

Dette directory indeholder Architecture Decision Records (ADRs) for biSPCharts projektet.

## Hvad er en ADR?

En ADR dokumenterer en signifikant arkitektonisk beslutning taget i projektet, inklusiv:
- **Kontekst**: Hvilken situation/problem førte til beslutningen?
- **Beslutning**: Hvad blev besluttet?
- **Konsekvenser**: Hvilke fordele, ulemper og trade-offs følger af beslutningen?
- **Rationale**: Hvorfor er denne løsning bedre end alternativer?

## Hvorfor ADRs?

ADRs hjælper med at:
- **Dokumentere "hvorfor"**: Ikke bare "hvad" men "hvorfor" beslutninger blev truffet
- **Onboarding**: Nye udviklere kan forstå projektets arkitektoniske evolution
- **Undgå regression**: Forhindrer at "løste" problemer genintroduceres
- **Knowledge preservation**: Bevarer institutional knowledge når teammedlemmer skifter

## ADR Naming Convention

```
ADR-XXX-beskrivende-titel.md
```

Hvor:
- `XXX` er et 3-cifret sekventielt nummer (001, 002, 003...)
- `beskrivende-titel` er en kort, hyphen-separated beskrivelse
- `.md` er Markdown format

**Eksempler:**
- `ADR-001-pure-bfhcharts-workflow.md`
- `ADR-002-ui-sync-throttle-250ms.md`

## ADR Template

Brug følgende template til nye ADRs:

```markdown
# ADR-XXX: [Navn på beslutning]

## Status
Proposed / Accepted / Deprecated / Superseded by ADR-YYY

## Kontekst
Beskriv baggrunden. Hvilket problem løses? Hvilke constraints eksisterer?
Hvad var situationen før beslutningen?

## Beslutning
Forklar den arkitektoniske beslutning. Hvad blev valgt? Hvordan fungerer det?

## Konsekvenser

### Fordele
- Hvad opnås med denne beslutning?
- Hvilke problemer løses?

### Ulemper
- Hvilke trade-offs accepteres?
- Hvilke begrænsninger introduceres?

### Mitigations
- Hvordan mitigeres ulemper?
- Hvilke fallback-strategier findes?

## Relaterede Beslutninger
- Link til andre ADRs der påvirkes eller påvirker denne
- Link til relevante dokumenter (SPRINT plans, REMEDIATION plans, etc.)

## Implementation Notes
Eventuelle tekniske detaljer, kode-eksempler, eller implementation guidance.

## Referencer
- Links til eksterne kilder
- Dokumentation
- Research papers
- Best practice guides

## Dato
[ÅÅÅÅ-MM-DD]
```

## Hvordan Bruges ADRs?

### Hvornår skal du lave en ADR?

Lav en ADR når du:
- Træffer en beslutning der påvirker systemarkitektur
- Vælger mellem flere tekniske alternativer med trade-offs
- Implementerer et non-obvious pattern eller workaround
- Afviser en "obvious" løsning af gode grunde
- Ændrer en eksisterende arkitektonisk beslutning

**Eksempler fra biSPCharts:**
- Hvorfor bruge pure BFHcharts workflow? → ADR-001
- Hvorfor throttle UI sync på 250ms? → ADR-002

### Hvornår skal du IKKE lave en ADR?

Lav IKKE en ADR for:
- Bug fixes uden arkitektoniske implikationer
- Simple refactorings
- Kode cleanup
- Trivielle implementationsdetaljer
- Åbenlyse best practices

### ADR Lifecycle

```
Proposed → Accepted → (Deprecated) → (Superseded)
    ↑                        ↓
    └────── Rejected ────────┘
```

**Status meanings:**
- **Proposed**: Under overvejelse, ikke implementeret endnu
- **Accepted**: Implementeret og aktiv
- **Deprecated**: Ikke længere anbefalet, men stadig i kodebasen
- **Superseded**: Erstattet af en nyere ADR
- **Rejected**: Foreslået men ikke implementeret

### Opdatering af ADRs

ADRs er **immutable** efter accept:
- Lav IKKE om i eksisterende ADRs
- Hvis beslutning ændres: Lav ny ADR der supersedes den gamle
- Opdater `Status` i gammel ADR til `Superseded by ADR-XXX`

**Eksempel:**
```markdown
# ADR-001: Original beslutning

## Status
~~Accepted~~ **Superseded by ADR-042** - 2025-12-15

[... original content forbliver uændret ...]
```

## Eksisterende ADRs

| ADR | Titel | Status | Dato |
|-----|-------|--------|------|
| [ADR-001](./ADR-001-pure-bfhcharts-workflow.md) | Pure BFHcharts Workflow for SPC Calculation | Accepted | 2025-10-10 |
| [ADR-002](./ADR-002-ui-sync-throttle-250ms.md) | UI Sync Throttle 250ms | Accepted | 2025-10-10 |
| [ADR-003](./ADR-003-unified-event-architecture.md) | Unified Event Architecture | Accepted (retroaktiv) | 2026-05-07 |
| [ADR-004](./ADR-004-hierarchical-app-state.md) | Hierarchical app_state with reactiveValues | Accepted (retroaktiv) | 2026-05-07 |
| [ADR-005](./ADR-005-session-persistence-localstorage.md) | Session Persistence via Browser localStorage | Accepted (retroaktiv) | 2026-05-07 |
| [ADR-006](./ADR-006-hybrid-anti-race-strategy.md) | Hybrid Anti-Race Strategy (5-Layer) | Accepted (retroaktiv) | 2026-05-07 |
| [ADR-014](./ADR-014-deprecate-optimized-event-pipeline.md) | Deprecate Optimized Event Pipeline | Accepted | — |
| [ADR-015](./ADR-015-bfhchart-migrering.md) | BFHcharts Migration (Hybrid Architecture) | Accepted | — |
| [ADR-016](./ADR-016-gemini-integration.md) | Gemini AI Integration | Accepted | — |
| [ADR-017](./ADR-017-test-regression-gate-design.md) | Test Regression Gate Design | Accepted | — |
| [ADR-018](./ADR-018-minimal-public-api-surface.md) | Minimal Public API Surface | Accepted | — |
| [ADR-019](./ADR-019-production-entrypoint-and-pkgload-boundary.md) | Production Entrypoint and pkgload Boundary | Accepted | — |

### Nummereringsgap: ADR-007..ADR-013

ADR-numrene 007-013 er **ikke allokerede** og forbliver reserveret.
De fire mest load-bearing retroaktive beslutninger er nu dokumenteret
som ADR-003..ADR-006 (issue #531):

- ADR-003 — Unified Event Architecture (event-bus + emit + prioriterede observers)
- ADR-004 — Hierarchical app_state med reactiveValues
- ADR-005 — Session Persistence via Browser localStorage (issue #193)
- ADR-006 — Hybrid Anti-Race Strategy (5-Layer race-prevention)

Hvis yderligere historiske beslutninger identificeres, kan de tildeles
numre i 007-013-spannet. Nye fremad-rettede ADRs nummereres fra ADR-020+
for at bevare visuel adskillelse fra det reserverede gap.

## Søgning i ADRs

For at finde ADRs relateret til et specifikt emne:

```bash
# Søg i alle ADRs
grep -r "throttle" docs/adr/

# Find ADRs om performance
grep -r "performance" docs/adr/

# Find ADRs der supersedes andre
grep -r "Superseded" docs/adr/
```

## Integration med Development Workflow

ADRs integrerer med development workflow:

1. **Under planning**: Identificér arkitektoniske beslutninger i SPRINT plans
2. **Under implementation**: Dokumentér non-obvious beslutninger i ADRs
3. **Under code review**: Referér til relevante ADRs for kontekst
4. **Under onboarding**: Læs ADRs for at forstå "hvorfor"

**Git commits bør referere til ADRs:**
```
feat(performance): Implementer shared data signatures (ADR-002)

Centraliseret signature system reducerer redundant hashing.
Se ADR-002 for rationale og performance gains.
```

## Yderligere Læsning

- [Michael Nygard's ADR documentation](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [ADR GitHub organization](https://adr.github.io/)
- [Architecture Decision Records: When to Use Them](https://www.thoughtworks.com/en-us/insights/blog/architecture/architecture-decision-records-when-to-use-them)

---

**Maintained by**: biSPCharts Development Team
**Last updated**: 2026-05-07
