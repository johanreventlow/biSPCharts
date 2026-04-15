# Analytics & Cookie Consent for biSPCharts

**Dato:** 2026-04-15
**Status:** Approved
**Scope:** Projekt 1 — Tracking + consent + struktureret logging i biSPCharts
**Projekt 2 (fremtidigt):** Quarto analytics-dashboard (separat projekt)

---

## Baggrund

biSPCharts er en SPC-applikation til klinisk kvalitetsarbejde deployed på Posit Connect Cloud. Appen er offentligt tilgængelig (ingen login). Der er behov for indsigt i hvordan brugere anvender appen — trafik, adfærd, feature-brug, fejl og performance.

### Eksisterende infrastruktur

- **shinylogs** er allerede integreret og fanger inputs, outputs, fejl og session-data (JSON-filer i `logs/`)
- **JavaScript-infrastruktur** er solid: localStorage-håndtering, custom Shiny message handlers
- **Ingen** eksisterende analytics, cookies, consent-mekanismer eller third-party tracking
- **CSP** er sat til "strict" i production

### Constraints

- Intet budget til eksterne analytics-platforme
- Ingen ekstern server — kun Posit Connect Cloud
- Appen håndterer kvalitetsdata (procesmål), ikke patientdata
- Fuld GDPR-compliance med cookie-banner kræves

---

## Tilgang

Byg videre på eksisterende shinylogs-infrastruktur (Tilgang A):

- **shinylogs** til server-side adfærdsdata (allerede implementeret, udvides med consent-gate)
- **Custom JavaScript** til klient-side metadata og performance-timing
- **Cookie consent-banner** til GDPR-compliance
- **pins-pakken** til at dele log-data med fremtidigt Quarto analytics-dashboard

Ingen nye eksterne dependencies ud over `pins`.

---

## 1. Cookie Consent Banner

### Brugeroplevelse

Ved første besøg vises en dansk consent-banner nederst på siden:

> "Denne app indsamler anonymiseret brugsstatistik for at forbedre kvaliteten."
>
> **[Acceptér]** **[Afvis]**

### Consent-persistering

Valget gemmes i localStorage med `spc_app_` prefix (eksisterende mønster):

- `spc_app_analytics_consent` — `true` / `false`
- `spc_app_consent_version` — versionsnummer (starter på `1`)
- `spc_app_consent_timestamp` — ISO 8601 tidsstempel

### Hvornår banneret vises

1. **Første besøg** — brugeren har aldrig svaret
2. **Browser-data ryddet** — localStorage er slettet
3. **Consent-version ændret** — `consent_version` i config er bumpet
4. **Efter 12 måneder** — GDPR best practice for periodisk re-consent

### Ændring af valg

En "Cookie-indstillinger" link i app-footeren giver brugeren mulighed for at ændre sit valg til enhver tid.

---

## 2. Hvad der trackes

### 2.1 Trafik-overblik (shinylogs — allerede fanget)

- Session start/slut tidspunkt og varighed
- Antal unikke sessions per dag/uge
- Returning visitors via persistent visitor-ID (se sektion 3)

### 2.2 Feature-brug (shinylogs — allerede fanget)

- Hvilken chart-type vælges (p, c, u, i-chart osv.)
- Om AI-forbedringsforslag bruges
- Om data eksporteres og i hvilket format
- Hvilke kolonner auto-detekteres vs. manuelt vælges
- Om Skift/Frys-funktionerne bruges
- Indhold af tekstfelter (indikatornavn, y-akse-label, datatitel) — giver indsigt i hvilke typer kvalitetsindikatorer der arbejdes med

### 2.3 Wizard-flow analyse (shinylogs input-tracking)

- Hvilke wizard-steps brugeren besøger og i hvilken rækkefølge
- Completion rate (nåede brugeren til chart-rendering?)
- Hvor lang tid per step
- Om brugeren gendanner en session vs. starter ny
- Dead ends — sessions der ender uden chart-rendering

### 2.4 Fejl-tracking (shinylogs — allerede fanget)

- Shiny-fejl med kontekst (hvilken operation fejlede)
- Validerings-fejl (forkert filformat, tomme data osv.)

### 2.5 Performance — klient-side (ny JS-kode)

- Side-indlæsningstid (initial load)
- Tid fra upload-klik til data vises i tabel
- Tid fra "Tegn diagram" til chart er synligt

### 2.6 Indhold & domæne-indsigt (shinylogs + analyse)

- Populære indikatorer (baseret på tekstfelt-indhold)
- Datastørrelser (antal rækker per upload)
- Datakvalitet (andel sessions med valideringsfejl)
- Auto-detection kvalitet (hvor ofte ændrer brugere auto-detekterede kolonner)
- Chart-type per indikator-type

### 2.7 Engagement & retention

- Returning visitor-frekvens (via persistent visitor-ID)
- Session-længde fordeling (hurtige opslag vs. dybe analyser)
- Feature adoption over tid
- Sessioner uden chart-rendering (brugeren gav op)

### 2.8 Kontekst & miljø (ny JS-kode)

- Browser-type og version (user agent)
- OS
- Skærmstørrelse og vinduesstørrelse
- Touch vs. mus
- Sprog og tidzone
- Referrer URL (hvor kommer brugere fra?)

### 2.9 Samarbejde & deling

- Eksport-brug og format
- Referrer-mønstre (deles appen via links?)

### Hvad der IKKE trackes

- Brugeridentitet (appen er offentlig, ingen login)
- IP-adresser
- Uploadede rådata

---

## 3. Persistent Visitor-ID

Ved consent oprettes et anonymt UUID i localStorage:

- `spc_app_visitor_id` — tilfældigt genereret UUID v4
- Sendes med hver session til shinylogs
- Gør det muligt at skelne unikke besøgende fra gentagne sessions

**Kun oprettet ved consent.** Afvises cookies, oprettes intet visitor-ID.

**Begrænsninger:**
- Kun samme browser + samme computer
- Ryddet localStorage = ny "besøgende"
- Ingen kobling til en rigtig person

---

## 4. Datalagring

### Rå data (shinylogs JSON-filer)

```
logs/
  inputs/
    input_YYYY-MM-DD_session-{id}.json
  outputs/
    output_YYYY-MM-DD_session-{id}.json
  errors/
    error_YYYY-MM-DD_session-{id}.json
  sessions/
    session_YYYY-MM-DD_session-{id}.json
```

Klient-side metadata (browser, skærm, visitor-ID, referrer, performance) sendes til R ved session-start via `Shiny.setInputValue()` og logges som del af session-data.

### Log-rotation

- Filer ældre end 90 dage: komprimeres
- Filer ældre end 365 dage: slettes
- Estimeret størrelse: ~5-10 KB per session → ~10 MB/måned ved 50 sessions/dag

### Deling med Quarto dashboard (pins)

Da Posit Connect Cloud isolerer filsystemer mellem apps, bruges `pins`-pakken:

1. biSPCharts aggregerer rå JSON-logs til tidy data.frame
2. Publicerer via `pin_write()` til Connect Cloud
3. Fremtidigt Quarto dashboard læser via `pin_read()`

Aggregering sker ved session-slut via `session$onSessionEnded()` callback.

---

## 5. Consent-gate flow

```
Bruger aabner app
  -> cookie-consent.js checker localStorage for consent
  -> Consent findes og er gyldig?
    -> JA: Send consent + visitor-ID + client metadata til R
           -> R initialiserer shinylogs
           -> analytics-client.js starter performance-maaling
    -> NEJ (aldrig svaret / version aendret / 12 mdr):
           Vis consent-banner
           -> Bruger accepterer?
             -> JA: Gem consent + opret visitor-ID -> same as above
             -> NEJ: Gem afvisning -> send consent:false til R
                    -> R logger KUN at session startede med consent:false
                    -> Ingen shinylogs, ingen tracking
```

---

## 6. Filstruktur og kode-aendringer

### Nye filer

| Fil | Ansvar |
|-----|--------|
| `inst/app/www/cookie-consent.js` | Consent-banner UI, localStorage-haandtering, visitor-ID generering, client metadata indsamling |
| `inst/app/www/cookie-consent.css` | Styling til consent-banneret |
| `inst/app/www/analytics-client.js` | Performance timing (page load, upload, chart render), skaerm/browser metadata, sender til R via `Shiny.setInputValue()` |
| `R/utils_analytics_consent.R` | Server-side consent-haandtering: lyt paa `input$analytics_consent`, gateway for shinylogs initialisering |
| `R/utils_analytics_pins.R` | Log-aggregering og publicering til Connect Cloud via `pins` |
| `R/config_analytics.R` | Consent-version, log-rotation policy, pin-indstillinger, feature flags |

### Aendringer i eksisterende filer

| Fil | Aendring |
|-----|---------|
| `R/utils_server_initialization.R` | shinylogs initialisering flyttes bag consent-gate — kun aktiver hvis `input$analytics_consent == TRUE` |
| `R/ui_app_ui.R` | Tilfoej consent-banner div og "Cookie-indstillinger" link i footer |
| `inst/golem-config.yml` | Ny `analytics:` sektion med consent_version, pin_name, log_retention_days |
| `DESCRIPTION` | Tilfoej `pins` som dependency |

### Filer der IKKE aendres

- shinylogs-konfigurationen aendres ikke — den udvides kun med consent-gate
- Eksisterende JS-filer roeres ikke
- Ingen aendringer i app_state eller event-bus arkitekturen

---

## 7. Fase 2 (fremtidigt, ikke i scope)

Foelgende kan tilfojes naar basis-tracking koerer:

- Copy/paste tracking (JS `copy` event listener)
- Scroll-dybde (JS `IntersectionObserver`)
- Rage clicks (JS klik-taeller med tidsvindue)
- Tid per wizard-step (JS timing mellem step-skift)
- Quarto analytics-dashboard (separat projekt)

---

## Dependencies

- `pins` — ny dependency for log-deling med Connect Cloud
- `shinylogs` — allerede i DESCRIPTION
- Ingen nye eksterne services eller servere

---

## Risici og mitigering

| Risiko | Mitigering |
|--------|------------|
| Consent-banner generer brugere | Diskret placement, husk valg permanent |
| Log-filer fylder for meget | Rotation policy (90d komprimering, 365d sletning), max 10K entries |
| CSP blokerer JS | Alle scripts er lokale (inst/app/www/), ingen eksterne CDN'er |
| pins-publicering fejler | safe_operation() wrapper, log fejl, retry ved naeste session |
| Brugere afviser consent | Logger consent:false for at maale andel, appen fungerer normalt |
