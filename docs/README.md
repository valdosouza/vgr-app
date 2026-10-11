# Project Documentation

Index of project technical documentation for the **VGR apps** (mobile and admin panel). Use the links below to navigate the available documents.

## Documentation Index
**RULE:** Only reference documents located in `./docs/adr/` or `./docs/feature/`. No other folders are permitted. Always validate that referenced files exist in one of these directories before finalizing the document.

| Document | Description | Reading |
|----------|-------------|----------|
| [**ARCHITECTURE.md**](./adr/ARCHITECTURE.md) | Architecture, folder organization, and code patterns for the project. | **Mandatory** |
| [**DESIGN-SYSTEM.md**](./adr/DESIGN-SYSTEM.md) | No raw Flutter widget in a screen — everything encapsulated as `Vgr*` (decision 133). | **Mandatory before writing any screen** |
| [**TESTS.md**](./adr/TESTS.md) | Testing strategies, patterns, and execution commands. | **Mandatory** |
| [**ADMIN-SCREENS.md**](./adr/ADMIN-SCREENS.md) | Checklist to add a screen to the admin panel — API catalog row, module, factory, shell registration, translations, tests (decisions 215–222). | **Mandatory before adding a panel screen** |
| [**auth.md**](./feature/auth.md) | Panel login, mandatory TOTP enrollment, silent session renewal, 451 view (decisions 73, 112-117). | Optional |
| [**identity.md**](./feature/identity.md) | Shared Role/AnonymityMode state (`packages/core`), consumed by mobile and admin. | Optional |
| [**admin-panel.md**](./feature/admin-panel.md) | The admin panel: shell, inventory of its 18 screens, access-control screens, open points (decisions 56, 215–222). | Optional |
| [**release.md**](./feature/release.md) | Building the panel and the app for an environment (`API_URL`, `GOOGLE_SERVER_CLIENT_ID`) and Android release signing with an external upload key, failing closed (decisions 242, 246). | **Mandatory before a release build** |
| [**network.md**](./feature/network.md) | Shared `ApiClient`/`Failure` (`packages/core`), used by every repository. | Optional |
| [**validators.md**](./feature/validators.md) | `vgr_validators`: format validators mirroring the API's Zod rules and input masks (decisions 153–157). | Optional |
| [**risk-config.md**](./feature/risk-config.md) | Admin editor for each Category's RiskTier (decision 46). | Optional |
| [**category-forms.md**](./feature/category-forms.md) | Admin editor for per-Category detail-field schema (decision 47). | Optional |
| [**monetization-config.md**](./feature/monetization-config.md) | Admin editor for fee rules and allowed payment modes, high-tier peer-to-peer veto (decisions 39, 58). | Optional |
| [**panic-responders.md**](./feature/panic-responders.md) | Admin queue approving / denying authorized-responder requests (decisions 51-52, 190). | Optional |
| [**dual-control-access.md**](./feature/dual-control-access.md) | Admin two-person gate for decryption access (decisions 45, 223–227): request list, request form, approve on the row by ANOTHER user — both people from the session. | Optional |
| [**app-auth.md**](./feature/app-auth.md) | Mobile sign-up / login / e-mail verification / Google (decisions 119, 122-124, 151-152). | Optional |
| [**reward-onboarding.md**](./feature/reward-onboarding.md) | Mobile registration of a helper as a reward recipient. | Optional |
| [**direction-sightings.md**](./feature/direction-sightings.md) | Mobile direction sighting on a report (DS2, decisions 200-207). | Optional |
| [**report-form.md**](./feature/report-form.md) | Mobile report submission with offline queue and per-photo EXIF choice (A1). | Optional |
| [**report-feed.md**](./feature/report-feed.md) | Nearby feed (home) and server-resolved report detail (A2). | Optional |
| [**help-offer.md**](./feature/help-offer.md) | Offering help on a report, self-dealing guard, anonymous notice (A3). | Optional |
| [**chat.md**](./feature/chat.md) | Masked reporter ↔ helper chat: cursor polling, offline-queued sends, anti-contact mirror (C2, decisions 54, 168-177). | Optional |
| [**rating.md**](./feature/rating.md) | Mobile helper rating: owner-only close, per-offer star control on a resolved case, "my reputation" (RT2, decisions 48, 178-189). | Optional |
| [**panic.md**](./feature/panic.md) | Mobile panic button: cold trigger, responder alerts inbox, responder-authorization request (PP2, decisions 51, 62, 65, 190-199). | Optional |
| [**case-freeze.md**](./feature/case-freeze.md) | Panel screen to freeze/unfreeze a case under dual control (P1). | Optional |
| [**report-moderation.md**](./feature/report-moderation.md) | Panel report search + case detail with embedded freeze (B1, decisions 158-167); chat evidence on the detail (C3, decision 175). | Optional |
| [**admin-audit.md**](./feature/admin-audit.md) | Panel screen for the append-only admin audit trail, read only (B5, decisions 116, 158, 165, 166). | Optional |
| [**legal-policy.md**](./feature/legal-policy.md) | Legal Gate admin screens: jurisdictions kill switch, capability verdicts, versioned rules (L3). | Optional |

## Recommended Reading Order

1. **adr/ARCHITECTURE.md** — technical foundation and project organization.
2. **adr/DESIGN-SYSTEM.md** — the widget rule; read it before touching any screen.
3. **adr/TESTS.md** — code validation and quality.
4. Additional documents in adr/ or feature/ folders as needed for the task.
