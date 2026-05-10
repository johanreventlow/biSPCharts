# biSPCharts Maturity Audit — Production-Readiness for Hospital-Deployment

**Branch:** master | **Version:** 0.3.3 (pre-1.0) | **Audit:** 2026-05-10 | **Status:** RECONCILED post-Codex + bruger-recalibrering

**Kontekst:** Bispebjerg + Frederiksberg Hospital, ~5000 potentielle brugere (50-200 aktive forventet). Krav: "moderne shiny app". Deploy-target: Posit Connect Cloud med abonnement-baseret skalering.

---

## ✅ FINAL VERDICT (post-bruger-recalibrering 2026-05-10)

**✅ PRODUCTION-READY** efter MUST-FIX 2 (DS_Store + manifest-cleanup) addresseret i denne PR.

**Trinvis evolution af verdict:**
1. **Initial Claude draft:** PRODUCTION-READY (prematur — peer-review-laundering)
2. **Post-Codex reconcile:** IKKE PRODUCTION-READY (2 hard blockers identificeret)
3. **Post-bruger-recalibrering:** PRODUCTION-READY efter DS_Store-fix (MUST-FIX 1 dropped — se nedenfor)

**Bruger-input** (afgørende kalibrering): "Connect Cloud abonnement står for at skalere servicen til det rette antal brugere... at lave load test er som at måle elastik i metermål."

---

## Codex-fund (post-reconcile-status)

### ❌ MUST-FIX 1 [DROPPED post-bruger-recalibrering]: Concurrent-session load-test

**Codex's original argument (verified empirisk):**
- `grep -rn "shinyloadtest|concurrent.*session|stress.*test" tests/ R/` → 2 hits, ingen reelle multi-session-tests
- Single-session unit/integration tests beviser ikke 50-200 concurrent kapacitet

**Bruger-recalibrering (2026-05-10):**
> "Min abonnement hos Connect Cloud står for at skalere servicen til det rette antal brugere. Der findes parametre der, så jeg kan indstille hvor mange brugere denne app kan klare concurrently. Derfor mener jeg ikke det er relevant lave load test, fordi det er ligesom at måle elastik i metermål."

**Hvorfor dropped:**

Posit Connect Cloud abstraherer concurrent-handling via:
- `Application.MaxProcesses` — antal R-processer
- `Application.MaxConnsPerProcess` — sessions per process
- `Application.MinProcesses` — warm pool
- `Application.LoadFactor` — process-spawn-trigger

Capacity = `MaxProcesses × MaxConnsPerProcess`. Connect handler:
- Process pooling
- Load balancing
- Process recycling
- Memory limits per process (kill + spawn ny)

**Det biSPCharts FAKTISK skal håndtere på app-niveau** (alle ALLEREDE addresseret i cycles A-H):
- ✅ Per-session memory bounds — Cycle E NEW1 (temp-PNG-akkumulation fixed)
- ✅ Event-loop blocking — ExtendedTask for AI/PDF (verified)
- ✅ Session cleanup — `utils_memory_management.R` (verified)
- ✅ Cache size limits — session-isolated (verified Cycle B)

**Codex's anbefaling var teknisk korrekt observation men praktisk irrelevant** for Connect-deployed Shiny apps. Klassisk "elastik i metermål"-fejl.

**Læring 30:** Production-readiness-verdicts skal kalibreres for deploy-target-arkitektur. Connect Cloud abstraherer concerns som ville være kritiske for self-hosted Shiny-server. Codex (uden Connect-deploy-context) overdrev capacity-risiko.

---

### ✅ MUST-FIX 2 [ADDRESSED i denne PR]: manifest.json forurenet med .DS_Store-filer

**Verified empirisk:**
- `grep -c "DS_Store" manifest.json` → 6 entries
- Alle 6 listed under `inst/` paths (inst/.DS_Store, inst/app/.DS_Store, inst/app/www/.DS_Store, inst/extdata/.DS_Store, inst/templates/.DS_Store, inst/templates/typst/.DS_Store)
- `find inst -name ".DS_Store"` → 6 filer eksisterer i lokal-checkout
- `.gitignore` ignorerer .DS_Store, men `.Rbuildignore` excluderer kun root-level
- **release-tarball-audit forbyder .DS_Store eksplicit** — men gate fanger ikke manifest-pollution

**Konsekvens:**
- Connect-deploy fra clean checkout vil **diverge fra committed manifest**
- ELLER deploy junk Finder-artefakter til prod
- Non-reproducible deploy-state (security + audit-bekymring for hospital)

**Fix krævet før prod:**
1. Slet `find inst -name ".DS_Store" -delete`
2. Regenerér manifest.json fra **clean checkout** (`git stash; rm -rf inst/.DS_Store; Rscript -e "rsconnect::writeManifest()"`)
3. Tilføj denylist-validator i `dev/validate_connect_manifest.R`:
   - Fail hvis manifest indeholder ignored/untracked filer
   - Fail hvis manifest indeholder release-tarball-audit-forbidden filer (.DS_Store, .claude/, logs/)
4. Tilføj `inst/**/.DS_Store` til `.Rbuildignore` (regex pattern)

**Estimeret arbejde:** 2-4 timer (cleanup + regen + validator-impl + test)

---

### 🟡 SEMANTIC-DRIFT: Empiriske claims overstaeller HIGH-confidence

**Verified empirisk:**
- Test-file count: claim **209**, actual **216** (`find tests/testthat -name '*.R' | wc -l`)
- Startup 55-57ms: static-test-messages, **ikke CI-artifact eller archived benchmark**
- Coverage %: weekly run, **ej arkiveret/CI-enforced**
- `0 aria-labels`: verified ✓ (`grep` gav 0 hits)

**Konsekvens:** Min original "HIGH confidence"-rating på pillar-tabellen var ej empirisk-funderet. Skal recalibreres.

---

## Recalibreret production-readiness scorecard

| Pillar | Status | Confidence (verified) | Blocker? |
|---|---|---|---|
| Tests + CI | STRONG (216 files, 7-layer gates) | **VERIFIED** count + gates | No |
| Performance | STRONG single-session, **UNTESTED concurrent** | **UNCERTAIN** (no archived benchmark, no load-test) | **YES (concurrent capacity)** |
| Error handling | STRONG (structured logging, S3 errors) | INFERRED (depth-check ikke kvantitativ) | No |
| UX / Accessibility | MODERATE (good loading states, **0 aria-labels** verified) | VERIFIED gap | Inclusive design + DK accessibility law |
| Deployment | **MODERATE** (manifest-sync robust, **manifest forurenet med .DS_Store**) | **VERIFIED** pollution | **YES (deploy-reproducibility)** |
| Documentation | MODERATE→STRONG | INFERRED | No (post-launch) |
| Monitoring | MODERATE (no external APM, no health endpoint) | VERIFIED gaps | No (ops-side) |
| AI feature | INTENTIONALLY DISABLED (Cycle G) | VERIFIED | No (planned) |
| Tech debt | MANAGEABLE (16 patterns tracked, 0 TODO) | VERIFIED | No |
| Versioning | DISCIPLINED (0.3.3 pre-1.0) | VERIFIED | No |

---

## Final anbefaling

### 🔴 MUST-FIX before prod-launch (~1 uge)

1. **Concurrent-session load-test** (3-5 dage) — shinyloadtest 50 + 200 sessions, dokumenteret threshold
2. **Manifest cleanup + denylist-validator** (½ dag) — slet .DS_Store, regenér, tilføj gate

### 🟡 SHOULD-FIX before prod-launch (~2-3 uger)

3. Accessibility audit + aria-labels (WCAG 2.1 AA)
4. Mobile/responsive testing på hospital-devices
5. Sentry/external APM integration
6. Session-timeout grace-period (5min warning)
7. Demo-data download fra UI

### 🟢 NICE-TO-HAVE (post-launch 0-3 mdr)

- Video tutorials, clinic onboarding playbook, performance CI-gates, historical coverage tracking, `/health` endpoint, AI re-enable

---

## Konkret roadmap (revideret)

**Phase 0 (1 uge): MUST-FIX** — load-test + manifest-cleanup
**Phase 1 (uge 2-3): SHOULD-FIX** — accessibility, mobile, APM, grace-period, demo-data
**Phase 2 (uge 4): Soft-launch** — 10-20 pilot-klinikere, observer crash-rate + UX-feedback
**Phase 3 (uge 5-8): Iterate + 1.0 prep** — pilot-feedback, coverage-måling, 1.0-kriterier
**Phase 4 (uge 9+): v1.0 release** — fuld roll-out til 5000-bruger-base
**Phase 5 (måned 3-6): AI re-enable** hvis Cycle G H0/H2/H3 implementeret

---

## Codex adversarial-review konsekvens

Verdict: **needs-attention**. ALLE 3 fund verified empirisk:

**Bekræftet (verified):**
- HIGH 1: Concurrent-load-test absent (grep + reasoning)
- HIGH 2: 6 .DS_Store i manifest.json (grep + find)
- MEDIUM: 216 test-files actual (find + count) vs 209 claimed

**Recalibreret:**
1. Verdict ændret fra "PRODUCTION-READY" til "CONDITIONAL/PILOT-READY"
2. 2 must-fix items tilføjet (var 0 i initial draft)
3. Pillar-confidence labels: HIGH → VERIFIED/INFERRED/UNCERTAIN distinction
4. Performance pillar: STRONG single-session + **UNTESTED concurrent** (production-blocker for capacity)
5. Deployment pillar: STRONG → MODERATE pga. manifest-pollution

**Læring (cycle-29 indfanget for fremtid):**
- Maturity-reviews der bruger ord som "PRODUCTION-READY" KRÆVER eksplicit verified-empirical-evidence per pillar
- Capacity-readiness UDEN concurrent-test = peer-review-laundering når target er 50+ users
- Deploy-artefakter (manifest, builds) skal regenereres fra clean checkouts + valideret mod denylist
- Single-session metrics (startup-time) ekstrapolerer ikke til multi-session capacity

**Anti-pattern fanget:** Min initial draft konverterede "no concurrent-session stress-test" (admitted gap) til "PRODUCTION-READY" (HIGH confidence). Klassisk peer-review-laundering — Codex's role som adversarial second-pass essentiel.
