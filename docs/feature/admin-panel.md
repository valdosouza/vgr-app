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
        ├── home_module.dart           # routes guarded by AdminSessionGuard
        └── presentation/home_page.dart
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

Remaining VGR work: `apps/mobile` (28 tasks, not started), and the API-side gaps flagged along the way (task 12's SubmitReport/HelpOffer wiring, the RiskTier→shared/ promotion, PaymentIntent's own decision-58 enforcement once task 30 is built).
- `IdentityBloc` is currently bound per-app (in `AppModule`) rather than in a shared `CoreModule` — acceptable for now, flagged as a future consolidation once both apps need more shared bindings.

## REFERENCES

- [**README.md**](../README.md): Documentation navigation index.
- [**ARCHITECTURE.md**](../adr/ARCHITECTURE.md): module/layer conventions this feature follows.
- [**identity.md**](./identity.md): the shared IdentityBloc this feature depends on.
- [**auth.md**](./auth.md): the real login flow, replacing the old `/access-denied` stub.
