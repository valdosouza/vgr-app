# Admin Panel

## OVERVIEW
`apps/admin` — Flutter web app for platform administrators (decision 56). Same Clean Architecture as `apps/mobile`, reusing `packages/core`/`vgr_widgets`/`vgr_validators`. Every route requires `Role.admin` via the shared `IdentityBloc`.

## STRUCTURE
```
apps/admin/lib/
├── main.dart                          # runApp(ModularApp(module: AppModule(), child: AppWidget()))
└── app/
    ├── app_module.dart                # binds IdentityBloc/ApiClient; routes: /login, / (→ HomeModule)
    ├── app_widget.dart                # MaterialApp.router via Modular
    ├── modules/auth/                  # LoginPage — redirectTo target for AdminSessionGuard (see auth.md)
    └── modules/home/
        ├── home_module.dart           # routes guarded by AdminSessionGuard; binds MenuBloc
        ├── interface_routes.dart      # central map i18nKey → route (+ /pending fallback)
        └── presentation/
            ├── home_page.dart         # DYNAMIC menu from GET /api/core/menus (decision 71)
            └── pending_page.dart      # placeholder for cataloged screens not built yet
```

`AdminSessionGuard` (`packages/core/lib/src/identity/admin_session_guard.dart`) is a `flutter_modular` `RouteGuard`: `canActivate` returns `identityBloc.state.role == Role.admin`; `redirectTo: '/login'` (changed from `/access-denied` — decision 67, see `auth.md`).

## STATUS
- Task 01 (bootstrap + role gate) — DONE. Verified: non-admin session redirects to `/login` (was `/access-denied` before decision 67); `AdminSessionGuard` unit-tested for both admin and non-admin sessions.
- Task 02 (`RiskTierConfigEntity` + `RiskConfigRepository`) — DONE. Required building the `vgr-api` risk-config endpoint first (API task 22) and two `packages/core` prerequisites that had never been implemented: `Failure` and `ApiClient` (see `network.md`).
- Task 03 (`RiskConfigListPage`) — DONE. `RiskConfigBloc` fetches once and edits rows in place (no re-fetch on edit). Mounted at `/risk-config`, guarded by `AdminSessionGuard`. `ApiClient` base URL is hardcoded to `http://localhost:3000` for now — REQUIRED: revisit once dev/staging/prod configuration is decided.
- Task 04 (`CategoryFormSchemaEntity`, repository, editor page) — DONE (see `category-forms.md`).
- Task 05 (`ResponderApprovalEntity`, repository, approval queue page) — DONE (see `panic-responders.md`). Required building two API prerequisites first (decision 66): task 11 (`Role`/`AnonymityMode`/`UserIdentity`, previously unimplemented) and task 27 (`ResponderPoolMembership` workflow).
- Task 06 (`DualControlAccessRequestEntity` and two-approval progress UI) — DONE (see `dual-control-access.md`). Required two API prerequisites first (decision 66): task 12 (`AccountabilityLogEntry`, previously unimplemented) and task 31 (`DualControlAccessRequest` workflow). Also required adding `ApiClient.post` to `packages/core` — the first admin-side call that needed it.
- Task 07 (`FeeRuleEntity`, repository, monetization config page) — DONE (see `monetization-config.md`). Required API task 32 first, which didn't exist in the API backlog at all until this session. First admin module to import another admin module's binds (`RiskConfigModule`, via flutter_modular's `imports`) to enforce a cross-cutting rule (decision 58) that the API side deliberately left unenforced.

**All 5 admin backlog areas are done** (tasks 01-07 — risk-config, category-forms, panic-responders, dual-control-access, monetization-config).
- Real admin login (decision 67, see `auth.md`) — DONE, replacing the app's earlier stub (no login existed at all before this). `AccessDeniedPage` is deleted; `AdminSessionGuard` now redirects to `/login`. Required new API-side prerequisites (`AdminAccount`, `POST /auth/admin-login`, `scripts/seed-admin.ts`) and a `packages/core` addition (`ApiClient.setToken`, `IdentityState.token`).
  - **Bug found during manual QA and fixed**: `LoginPage` updated `IdentityBloc` on success but never called `Modular.to.navigate('/')` — so after a correct login the URL stayed on `/login` and the form just sat there, looking like the login had silently failed. Fixed with a `BlocConsumer` (was `BlocBuilder`) whose `listener` navigates on `LoginSuccess`. Required hiding `flutter_modular`'s `ModularWatchExtension` in the import (`.read<T>()` is ambiguous between `provider` and `flutter_modular`) once `Modular.to` was introduced in this file.
- `HomePage` menu — DONE, and since phase 3 of the admin-controls plan it is **dynamic**: `MenuBloc` (`packages/core/lib/src/menu/`) loads `GET /api/core/menus` — the tree arrives already filtered by the user's VIEW grants (decision 71), grouped by Admin-managed module or `group_default`. `interface_routes.dart` maps `i18nKey → route` (registering a new screen = 1 map entry + 1 ModularRoute); cataloged screens without a page fall through to `/pending`. Labels translate via `trCatalog` (`menu.interfaces.*` / `menu.groups.*`, DB description as fallback).
- **Per-privilege buttons (`can()`) — DONE** (phase 3): `SessionAccess` (`packages/core/lib/src/menu/session_access.dart`) is fed by every menu load; the action buttons of the 5 screens (edit tier, add field, approve/deny, start/approve request, save fee) render disabled without the matching INSERT/UPDATE grant. Default-deny, UX-only — the API enforces regardless (decision 72). This is the hook that existed but was never wired in setes.
- **Language selector + persisted locale — DONE** (phase 5): `LanguageSelector` (`packages/core/lib/src/preference/`) in the login AppBar (`persist: false` — local switch only, no session yet) and in the Home AppBar (`persist: true` — saves via `PUT /api/core/preferences`); `applyUserLocale` runs on Home entry so the server-saved locale follows the user to any browser. Best-effort: a failed save/fetch never blocks the local switch.
- **Report search + case detail — DONE** (B1 of the moderation front, decisions 158-167, see `report-moderation.md`): `modules/reports` at `/reports` (list) and `/reports/:id` (detail with the embedded P1 freeze block); position degraded by default, exact position only with the `report_exact_position` grant (audited); anonymous reporter/helper never identified on screen.
- **Moderation — DONE** (B2, decisions 162/163/165/167, see `report-moderation.md`): hide/unhide a report and block/unblock a media from the case detail, every act through one catalog-reason form (`other` requires a note), buttons by `reports` UPDATE, bloc re-fetches; list gains a `hidden` filter and mark.
- **Moderation queue — DONE** (B3, decisions 161/165/166, see `report-moderation.md`): `/reports/queue` inside `modules/reports`, registered before `/:id`; server-ordered proactive queue (tier, then media, then oldest) rendered as served, per-row and per-detail "Mark reviewed" under `reports` UPDATE with re-fetch, list gains a `reviewed` filter/mark and a link to the queue; queue reads are not audited, opening a case is.
- **Report statistics — DONE** (B4, decisions 164/165, see `report-moderation.md`): `modules/report-stats` at `/report-stats`, own `report_stats` VIEW interface; counters and per-grouping tables from `GET /api/reports/stats`, every count already floored at k = 5 by the API and rendered as served (`"<5"`), no chart, no map.
- **Admin audit trail — DONE** (B5, decisions 116/158/165/166, see `admin-audit.md`): `modules/admin-audit` at `/admin-audit` (list with facet dropdowns, pagination) and `/admin-audit/:id` (detail with summary as key/value tree and the operator IP under a personal-data caption); own `admin_audit` VIEW interface; read only, reads not audited.
- **Access-control screens — DONE** (phase 4, decisions 70-75): `modules/privileges` (catalog CRUD), `modules/interfaces` (screen CRUD + per-screen privilege checkboxes; own privilege lookup — a module never imports another module), `modules/system-modules` (menu module CRUD with ordered screen links — the CRUD setes never had; selection order = menu order) and `modules/users` (team CRUD per decision 75 + `UserPrivilegesPage`, the matrix screen × privilege; checking anything implies VIEW — rule lives in the API, the page re-fetches to reflect it). All action affordances (FAB/edit/delete) render only with the matching grant; errors surface translated by catalog code (`failureText`, decisions 80/83 — e.g. `SELF_LOCKOUT` when an Admin tries to remove their own access).

Remaining VGR work: `apps/mobile` (28 tasks, not started) — this is where end users actually submit reports/denúncias; the admin panel is configuration/governance only (decision 56), it was never meant to create denúncias. Also the API-side gaps flagged along the way (task 12's SubmitReport/HelpOffer wiring, the RiskTier→shared/ promotion, PaymentIntent's own decision-58 enforcement once task 30 is built).
- `IdentityBloc` is currently bound per-app (in `AppModule`) rather than in a shared `CoreModule` — acceptable for now, flagged as a future consolidation once both apps need more shared bindings.

## REFERENCES

- [**README.md**](../README.md): Documentation navigation index.
- [**ARCHITECTURE.md**](../adr/ARCHITECTURE.md): module/layer conventions this feature follows.
- [**identity.md**](./identity.md): the shared IdentityBloc this feature depends on.
- [**auth.md**](./auth.md): the real login flow, replacing the old `/access-denied` stub.
