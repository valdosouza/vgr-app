# Adding a screen to the admin panel — checklist

> The panel's counterpart of setes-app's `ARQUITETURA_MODULOS.md` (decision
> 15 — same model, VGR's own rules on top). Written after PS4 of
> `AI/docs/plans/plano-painel-modelo-setes.md` (decisions 215–222). Follow it
> top to bottom; every step names the test or guard that catches a miss.

## 0. Pick the kind of screen first

| The screen… | Build it with | Example |
|---|---|---|
| creates / edits / deletes rows of one resource | **`RegisterScreen<T, D>`** + a `RegisterBloc` alias (list ↔ form on one route, decision 217) | `privileges`, `users`, `interfaces`, `system-modules` |
| only ADDS rows (the resource is versioned, never edited) | `RegisterScreen(openRows: false)` + a `RegisterBloc` **subclass** for the row actions | Legal Gate rules |
| lists rows the operator ACTS on, without a form | **`PagedListScreen<T, B>`** + a `PagedListBloc` subclass; row actions through `act()` | Legal Gate jurisdictions, responder queue |
| edits a small FIXED catalog (5–10 rows, decision 220 keeps it unpaged) | own bloc + `VgrPage`; outcomes through the bridge | `risk-config`, `category-forms`, `monetization-config` |
| runs a multi-step flow on one record | own bloc + `VgrPage`; outcomes through the bridge | `dual-control-access`, `case-freeze`, `reward-mediation` |
| needs a deep link per record, or audits every read | own routes (`/:id`) — the registered exception to 217 | `reports`, `admin-audit` |

When in doubt, it is the first row: most panel screens are registers.

## 1. API first (decision 66)

The panel never gets ahead of the API: a screen without its endpoint is a
`/pending` placeholder, not a mock.

1. **Catalog the screen** in a migration (`api/src/migrations/sql/NNN_*.sql`,
   model: `042_admin_audit_screen.sql`):
   - `tb_interface` row — `i18n_key` in `lower_snake_case` (the key the menu,
     the API guard and the app's route map share), `group_default` (menu
     group), `kind 'T'` (a screen; `'R'` is a sub-resource such as
     `user_privileges`, decision 93), `position`;
   - `tb_interface_has_privilege` — the privileges the screen exposes
     (VIEW always; INSERT / UPDATE / DELETE as the screen needs);
   - bootstrap grant to the de-facto administrators (UPDATE on `users`),
     the same block every screen migration carries.
2. **Key constant** in `api/src/shared/acl/privileges.ts` (`InterfaceKeys`).
3. **Every route** behind `requirePrivilege(InterfaceKeys.X, Privileges.Y)`
   (decision 110: an endpoint is born with it).
4. **A list that grows is paged** (decision 220): `pagedQueryDto` +
   `pagedOrPlain` (`shared/http/paged-query.ts`) — `page`/`pageSize`/`filter`
   optional, the unpaged form kept for lookups.
5. **Errors by catalog code** (decisions 80/83) — English message, the `code`
   is what the panel translates; validation through `parseBody` / `parseQuery`
   (422 with `fields[]`).
6. API tests (`*.routes.spec`, `*.list.spec`) and the spec amendment
   (`docs/specs/vgr/004-api-test-scenarios.md`) when the contract is new.

## 2. Module skeleton

`apps/admin/lib/app/modules/<kebab-name>/` — one screen = one flutter_modular
module; a module never imports another module (shared code goes to
`app/shared/`).

```
<kebab-name>/
├── <snake_name>_module.dart          # route(s): provides the bloc(s), AdminSessionGuard
├── data/<x>_repository_impl.dart     # ApiClient → Either<Failure, T>
├── domain/
│   ├── entity/<x>_entity.dart        # Equatable + fromJson; the draft class (toJson) beside it
│   └── repository/<x>_repository.dart
└── presentation/
    ├── bloc/<x>_bloc.dart            # alias / subclass of the factory's bloc
    └── page/<x>_page.dart
```

The panel has no `usecase/` layer: blocs talk to the repository contract
(for registers, `RegisterRepository<T, D>` is that contract). The mobile app
keeps one usecase per operation — see ARCHITECTURE.md.

## 3. Domain and data

- **Entity**: immutable, `Equatable`, `fromJson` that tolerates what the API
  omits.
- **Draft** (registers): what the form saves, with `toJson` mirroring the
  API DTO — never the whole entity (a password goes in, never comes back).
- **Repository contract**: `implements RegisterRepository<Entity, Draft>`
  (+ the lookups the form offers, e.g. `listPrivilegeOptions()`).
- **Repository impl**: `list(PagedQuery query)` →
  `GET /api/<x>?${query.toQueryString()}` → `PagedResult.fromJson(...)`;
  every `on Failure catch (f) => Left(f)`. Lookups use the unpaged form of
  the list.

## 4. Presentation

- **Bloc**: `typedef XBloc = RegisterBloc<XEntity, XDraft>;` — an alias, so
  the route's provider and `RegisterScreen`'s lookup are one type. A screen
  with row actions subclasses (`RegisterBloc` or `PagedListBloc`), declares
  its actions as `RegisterEvent` subclasses and runs them through `act()`.
- **Page**: `RegisterScreen<XEntity, XDraft>(...)` with
  - `screen: CurrentInterface('<i18n_key>')` — "new" by INSERT, save by
    INSERT/UPDATE, delete by DELETE, read-only without UPDATE;
  - `rowBuilder` → `RegisterRow` (title, subtitle, leading icon, trailing or
    `subtitleWidget` for row controls);
  - `fields` — `RegisterTextField` / `RegisterFlagField` /
    `RegisterChoiceField` / `RegisterChecklistField`, named exactly like the
    API body fields (server `fields[]` land by name), validators from
    `vgr_validators` mirroring the DTO's Zod rules (decision 154 — add the
    mirror there, with its test, when it is missing);
  - `draftOf` — trims what the API trims, never a password.
- **Never** a raw Flutter widget (decision 133 — `design_system_guard_test`)
  and **never** a dialog or a snack bar of its own (decision 221 —
  `feedback_bridge_guard_test`): outcomes go through
  `showSuccessFeedback` / `showFailureFeedback` / `showValidationFeedback` /
  `askDecision`, which the factory already calls.

## 5. Register the screen in the shell

1. `modules/home/interface_routes.dart`: `'<i18n_key>': '/<kebab-name>/'` — a
   module root ENDS with `/` (flutter_modular 5.0.3 only forgives a missing
   slash; plain child routes have none).
2. `modules/home/home_module.dart`: `ModuleRoute('/<kebab-name>', module:
   XModule())` among the shell's `children` (decision 216 — URLs stay at the
   root).
3. The module's `ChildRoute('/')` **provides the bloc** (`BlocProvider<XBloc>`,
   plus `MultiBlocProvider` for lookups) and repeats
   `AdminSessionGuard(Modular.get<IdentityBloc>())`.

## 6. Translations

- `assets/translations/en-US.json` and `pt-BR.json` carry EXACTLY the same
  keys (`translations_catalog_test`); no key declared twice in an object.
- `menu.interfaces.<i18n_key>` (menu label), the screen's own block (title,
  field labels, `newTitle` / `editTitle`), `menu.privileges.<NAME>` for a new
  privilege. Error texts come from `core.errors.<CODE>` /
  `core.fieldErrors.<CODE>` — add the code there, never a per-screen copy.

## 7. Tests (TDD — TESTS.md)

- Repository: the exact paged query string, the envelope mapping, `Left` on
  a `Failure`.
- Page through `pumpLocalized` (real catalogs): list and privileges (no
  "new" without INSERT, read-only without UPDATE), one validation pendency,
  a server field error anchored, delete only after `askDecision`, a refused
  action through the bridge with the list kept.
- `admin_module_wiring_test` covers the route automatically once it is in
  `interfaceRoutes` — a screen missing there is the bug it exists for.
- The three guards run on every `flutter test` of the app: design system
  (133), feedback bridge (221), translation catalogs.

## 8. Docs

- `docs/feature/<name>.md` (what the screen does, decisions, contract) and
  its line in `docs/README.md`.
- `docs/feature/admin-panel.md` — the screen in the inventory.
