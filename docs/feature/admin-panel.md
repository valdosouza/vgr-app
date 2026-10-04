# Admin Panel

## OVERVIEW
`apps/admin` — Flutter **web** app for the internal team (decision 56): governance and
configuration, never report submission. Same workspace and packages as `apps/mobile`
(`packages/core`, `vgr_widgets`, `vgr_validators`); every screen requires a live admin
session (`AdminSessionGuard`, decision 67) and checks the user's grants per button
(`SessionAccess`, decisions 71/72 — UX only, the API decides).

Since the front `AI/docs/plans/plano-painel-modelo-setes.md` (decisions 215–222,
PS0–PS4, closed 2026-10-04) the panel follows the setes-app `apps/web` model: a
persistent shell, one contract to register a screen, a CRUD factory, one feedback bridge
and paged lists. The rules are in `docs/adr/ARCHITECTURE.md` § ADMIN PANEL; adding a
screen is the checklist `docs/adr/ADMIN-SCREENS.md`. This document is the inventory.

## SHELL (decisions 215–218)

- `AppModule` holds the routes outside a session — `/login`, `/recovery-password`,
  `/change-password`, `/two-factor-setup`, `/two-factor-recover` (see `auth.md`) — and
  mounts `HomeModule` at `/`.
- `HomeModule` draws the shell: app bar (`home.title`, `LanguageSelector(persist: true)`,
  `UserBadge` with **Sign out**) + two `VgrNavColumn`s — modules (200 px), screens of the
  selected module (240 px) — beside a `RouterOutlet`; below 850 px (`VgrResponsive`) the
  columns become a `VgrDrawer`. Selection by click, never hover.
- The menu is `GET /api/core/menus`, already filtered by VIEW (71); `MenuBloc` (core,
  singleton of the shell) carries the selection. A menu failure shows error + retry in
  the first column; the outlet keeps working.
- Every screen is a child `ModuleRoute` of the shell; URLs stay at the root (216). Module
  roots end with `/`; plain child routes (`/welcome`, `/pending`, `/legal/rules`) do not —
  flutter_modular 5.0.3 only forgives a MISSING slash. `/welcome` is the outlet content
  after login; a cataloged key without a route falls to `/pending`. On a refresh the shell
  keeps the screen and `interfaceKeyForPath` highlights it.
- **Sign out** (`core/session/logout.dart`): clears the persisted token and "keep me
  signed in", the in-memory token, `SessionAccess` and the identity, then `/login`. The
  badge shows `GET /api/core/me` (name or e-mail) and offers the exit even while that
  call is pending or failed.
- Pages inside the outlet are `VgrPage` (content header), never `VgrScaffold`.

## SCREEN INVENTORY

18 menu screens in 15 modules (`interface_routes.dart`). "Kind" is the column of the
table in `ADMIN-SCREENS.md` §0.

| Menu key | Route | Kind | Paging | Decisions | Doc |
|---|---|---|---|---|---|
| `users` | `/users/` (+ `/users/privileges` matrix) | register | paged, filter name / e-mail | 70, 74, 75, 93 | below |
| `privileges` | `/privileges/` | register | paged, filter identifier | 71 | below |
| `interfaces` | `/interfaces/` | register (privileges checklist) | paged, filter description / key | 71 | below |
| `system_modules` | `/system-modules/` | register (ordered screens checklist) | paged, filter description | 71 | below |
| `legal_jurisdictions` | `/legal/jurisdictions` | workflow list (kill switch) | paged, filter code / name | 103–109 | `legal-policy.md` |
| `legal_capabilities` | `/legal/capabilities` | workflow list (per jurisdiction) | paged, filter capability | 103 | `legal-policy.md` |
| `legal_rules` | `/legal/rules` | register, propose only | paged, text filter | 78, 107, 108 | `legal-policy.md` |
| `panic_responders` | `/panic-responders/` | workflow list (queue) | paged, no filter | 51–52, 190 | `panic-responders.md` |
| `risk_config` | `/risk-config/` | fixed catalog | unpaged (220) | 46 | `risk-config.md` |
| `category_forms` | `/category-forms/` | fixed catalog | unpaged (220) | 47 | `category-forms.md` |
| `monetization_config` | `/monetization-config/` | fixed catalog | unpaged (220) | 39, 58 | `monetization-config.md` |
| `dual_control_access` | `/dual-control-access/` | register, request only | paged, filter legal basis | 45, 93, 223–227 | `dual-control-access.md` |
| `case_freeze` | `/case-freeze/` | flow | — | 141 | `case-freeze.md` |
| `reward_mediation` | `/reward-mediation/` | flow | — | 148–150 | API `docs/feature/reward.md` |
| `reports` | `/reports/` (+ `/reports/:id`, `/reports/queue`) | own routes (deep link, audited read) | paged search and queue | 158–167, 175 | `report-moderation.md` |
| `report_stats` | `/report-stats/` | read only | — (k = 5 floor) | 164, 165 | `report-moderation.md` |
| `admin_audit` | `/admin-audit/` (+ `/admin-audit/:id`) | own routes, read only | paged | 116, 165, 166 | `admin-audit.md` |

### Access control screens (no separate doc)
- **users** — team users (decision 75: the admin sets the initial password, no e-mail
  invitation). Form validated as `userCreateDto` / `userUpdateDto`: name 2..120, e-mail,
  password 12..72 required on create and kept when left empty on edit (the
  "predictable password" rule is the API's — its 422 lands on the field). Deleting
  yourself or revoking your own access is refused (`SELF_LOCKOUT`). Each row offers the
  privilege matrix (`/users/privileges`) with the `user_privileges` grant (93): checking
  any privilege implies VIEW — the API's rule, the page re-fetches to show it. The update
  echoes the user's saved `locale` (the API nulls an absent one).
- **privileges** — the catalog, identifier validated as `privilegeSaveDto` (2..60,
  UPPER_SNAKE_CASE); translated through `menu.privileges.<NAME>`.
- **interfaces** — the screen catalog (`tb_interface`): description 2..120, key 2..60
  lower_snake_case, group, position, the privileges it exposes (checklist fed by the
  privilege catalog, loaded once beside the list). `kind` is carried, never edited.
- **system-modules** — menu modules (the CRUD setes never had): optional key (still
  lower_snake_case when typed), icon, position and the module's screens as an ORDERED
  checklist — the order of checking is the menu order.

## TESTS
`apps/admin/test` — page, bloc and repository tests per module, plus:
`admin_module_wiring_test` (every `interfaceRoutes` entry mounted through the REAL shell),
`home_page_test` (shell), `test/app/shared/` (factory and bridge), and three guards on every
run — design system (133), feedback bridge (221), translation catalogs. Patterns for a
factory screen: `docs/adr/TESTS.md`.

## HISTORY
- Phase 1 (tasks 01–07): role gate, risk-config, category-forms,
  panic-responders, dual-control-access, monetization-config, each needing its API
  prerequisite first (decision 66; e.g. the missing `GET` list endpoints of risk-config
  and category-forms, `ApiClient.post`).
- Real admin login replacing the stub (decision 67), mandatory TOTP and silent renewal
  (112–114, `auth.md`). Bug found then: a correct login stayed on `/login` because the page
  never navigated — fixed with a `BlocConsumer` listener.
- Admin-controls plan: dynamic menu (71), per-privilege buttons (72), language selector
  with server-saved locale, access-control screens (70–75), kind-'R' resources (93).
- Moderation front (B1–B5, 158–167), chat evidence (C3, 175), Legal Gate screens (L3).
- 2026-09-21 — PS1 shell (215–218); found live the same day: five phase-1 routes mounted
  their page without its bloc (ProviderNotFound) — every route now provides its bloc and
  the wiring test walks the real shell.
- 2026-10-04 — PS2 register factory + bridge (217, 221), PS3 every screen on the factory
  or the bridge with paged lists (220) — four screens that fell into an error screen on a
  refused action and the dual-control flow that dropped a request in progress were fixed
  on the way — and PS4 documentation.
- 2026-10-04 — round 18 (223–229): PS4 found the dual-control approver was a typed id
  (one admin could grant alone). DC1 fixed the API (requester and approver from the
  session, one approval by another user); DC2 rebuilt the screen as a register — list,
  request form, approve on the row, disabled on your own request.

## OPEN POINTS
- `category-forms` still appends a placeholder field instead of a field editor, and
  `monetization-config` edits only rows the API already returned (documented gaps of
  phase 1).
- `IdentityBloc` is bound per app (in `AppModule`) rather than in a shared core module.

## REFERENCES
- [**README.md**](../README.md): Documentation navigation index.
- [**ARCHITECTURE.md**](../adr/ARCHITECTURE.md) § ADMIN PANEL — shell, factory, bridge, exceptions.
- [**ADMIN-SCREENS.md**](../adr/ADMIN-SCREENS.md) — checklist to add a screen.
- [**auth.md**](./auth.md) — login, 2FA, session renewal.
- [**identity.md**](./identity.md) — the shared `IdentityBloc`.
