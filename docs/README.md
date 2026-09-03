# Project Documentation

Index of project technical documentation for **VGR Mobile App**. Use the links below to navigate the available documents.

## Documentation Index
**RULE:** Only reference documents located in `./docs/adr/` or `./docs/feature/`. No other folders are permitted. Always validate that referenced files exist in one of these directories before finalizing the document.

| Document | Description | Reading |
|----------|-------------|----------|
| [**ARCHITECTURE.md**](./adr/ARCHITECTURE.md) | Architecture, folder organization, and code patterns for the project. | **Mandatory** |
| [**DESIGN-SYSTEM.md**](./adr/DESIGN-SYSTEM.md) | No raw Flutter widget in a screen — everything encapsulated as `Vgr*` (decision 133). | **Mandatory before writing any screen** |
| [**TESTS.md**](./adr/TESTS.md) | Testing strategies, patterns, and execution commands. | **Mandatory** |
| [**auth.md**](./feature/auth.md) | Panel login, mandatory TOTP enrollment, silent session renewal, 451 view (decisions 73, 112-117). | Optional |
| [**identity.md**](./feature/identity.md) | Shared Role/AnonymityMode state (`packages/core`), consumed by mobile and admin. | Optional |
| [**admin-panel.md**](./feature/admin-panel.md) | `apps/admin` structure and role-gating (decision 56). | Optional |
| [**network.md**](./feature/network.md) | Shared `ApiClient`/`Failure` (`packages/core`), used by every repository. | Optional |
| [**category-forms.md**](./feature/category-forms.md) | Admin editor for per-Category detail-field schema (decision 47). | Optional |
| [**report-form.md**](./feature/report-form.md) | Mobile report submission with offline queue and per-photo EXIF choice (A1). | Optional |
| [**report-feed.md**](./feature/report-feed.md) | Nearby feed (home) and server-resolved report detail (A2). | Optional |
| [**help-offer.md**](./feature/help-offer.md) | Offering help on a report, self-dealing guard, anonymous notice (A3). | Optional |
| [**case-freeze.md**](./feature/case-freeze.md) | Panel screen to freeze/unfreeze a case under dual control (P1). | Optional |
| [**report-moderation.md**](./feature/report-moderation.md) | Panel report search + case detail with embedded freeze (B1, decisions 158-167). | Optional |
| [**admin-audit.md**](./feature/admin-audit.md) | Panel screen for the append-only admin audit trail, read only (B5, decisions 116, 158, 165, 166). | Optional |
| [**legal-policy.md**](./feature/legal-policy.md) | Legal Gate admin screens: jurisdictions kill switch, capability verdicts, versioned rules (L3). | Optional |

## Recommended Reading Order

1. **adr/ARCHITECTURE.md** — technical foundation and project organization.
2. **adr/DESIGN-SYSTEM.md** — the widget rule; read it before touching any screen.
3. **adr/TESTS.md** — code validation and quality.
4. Additional documents in adr/ or feature/ folders as needed for the task.
