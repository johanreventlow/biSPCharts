## Fra audit til klassifikations-manifest

Audit-data i JSON er ikke nok for senere refactor-beslutninger. Manifestet
(`dev/audit-output/test-classification.yaml`) er ground truth.

### Workflow

1. **Re-kør audit:**
   ```bash
   Rscript dev/audit_tests.R --timeout=60
   ```

2. **Auto-klassificér** (bevarer `reviewed: true`):
   ```bash
   Rscript dev/classify_tests.R
   ```

3. **Manuel review i YAML:**
   - Verificér `type` (VALID_TYPES: policy-guard, unit, integration, e2e, benchmark, snapshot, fixture-based)
   - Vælg `handling` (VALID_HANDLINGS: keep, fix-in-phase-3, merge-in-phase-2, archive, rewrite, blocked-by-change-1)
   - Skriv `rationale` når handling ≠ keep
   - Sæt `reviewed: true` + reviewer + reviewed_date

4. **Validér:**
   ```bash
   Rscript dev/classify_tests.R --validate
   ```

5. **Render rapport:**
   ```bash
   Rscript dev/classify_tests.R --render-report
   ```

### Dev-tests

Tests for `classify_tests.R` ligger i `dev/tests/` — ikke del af publish-gate.

```bash
Rscript dev/tests/run_tests.R
```
