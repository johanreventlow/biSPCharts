# Follow-up: GitHub issue mangler

**Status:** OpenSpec change valideret (`openspec validate --strict` OK) og committet, men GitHub tracking-issue er ikke oprettet pga. `gh auth` problem i Claude-session 2026-04-17.

## Når `gh` virker igen

Kør:

```bash
gh issue create \
  --title "[OpenSpec] unblock-publish-test-gate" \
  --body-file openspec/changes/unblock-publish-test-gate/proposal.md \
  --label "openspec-proposal,bug"
```

## Alternativ: manuel via GitHub web

1. Gå til https://github.com/johanreventlow/biSPCharts/issues/new
2. Titel: `[OpenSpec] unblock-publish-test-gate`
3. Body: copy-paste indhold af `openspec/changes/unblock-publish-test-gate/proposal.md`
4. Labels: `openspec-proposal`, `bug`
5. Link til issue #203 i en kommentar

## Efter oprettelse

Opdatér `proposal.md`'s `## Related`-sektion med issue-nummeret og commit ændringen:

```bash
# Tilføj: "- **OpenSpec tracking issue:** #NNN"
git commit -m "docs(openspec): link unblock-publish-test-gate to issue #NNN"
```

## Slet denne fil

Efter issue er oprettet og linket, slet `FOLLOW_UP.md` — den har opfyldt sit formål.
