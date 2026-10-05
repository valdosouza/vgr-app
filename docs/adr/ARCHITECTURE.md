# Project Architecture

## OVERVIEW
Flutter monorepo in Clean Architecture, mirroring the `setes-app` structure
(`D:\Gestao2027\setes-app`) by explicit product-owner decision. Native pub
workspace (Dart 3.6+), DI/routing with `flutter_modular`, state management
with `bloc`, async return type `Either<Failure, T>` (`dartz`). Flow:
presentation (bloc) → domain (usecase) → data (repository/datasource) → VGR
API (`D:\ProjetoVGR\api`, same structure as setes-api).

Two apps share this same workspace/packages (decision 56): `apps/mobile`
(citizen-facing — Android/iOS) and `apps/admin` (internal team — **web
only**, same pattern as setes-app's `apps/web`). Both consume the same
vgr-api, but `apps/admin` talks to administrative endpoints protected by
distinct roles (see decision 45 — dual control).

## FOLDER STRUCTURE
<folder_structure>
D:\ProjetoVGR\app/
├── pubspec.yaml                  # Workspace root — lists the 4 members below
├── packages/
│   ├── core/                     # Shared infra WITHOUT business UI (ApiClient, auth, session, helpers)
│   ├── vgr_widgets/               # Pure design system — no raw Flutter widget used directly in screens
│   └── vgr_validators/            # Pure validators/masks — mirrors vgr-api/src/shared/validation
└── apps/
    ├── mobile/                   # Citizen-facing app (Android/iOS) — reporters and helpers
    │   └── lib/app/
    │       ├── shared/            # Business code used by 2+ modules (promoted from inside a module)
    │       └── modules/
    │           ├── home/          # Shell: menu + RouterOutlet
    │           └── <feature>/     # 1 feature = 1 flutter_modular module (e.g. denuncia, ajuda)
    │               ├── <feature>_module.dart   # Binds (DI) + ChildRoute
    │               ├── data/
    │               │   ├── datasource/         # Talks to core.ApiClient, throws Failure
    │               │   └── repository/         # Converts exceptions into Either<Failure,T>
    │               ├── domain/
    │               │   ├── entity/             # Entities (Equatable), fromJson
    │               │   ├── repository/         # Abstract contract (implemented in data/)
    │               │   └── usecase/            # One file per operation (getlist, post, put, delete)
    │               └── presentation/
    │                   ├── bloc/               # "Buildable" states (List/Form) + "one-shot" states (ActionSuccess/Failure)
    │                   └── page/               # Widgets — only read state via BlocConsumer
    └── admin/                    # Administrative panel, Flutter WEB only (decision 56)
        └── lib/app/
            ├── app_module.dart           # auth routes (/login, 2FA…) + the shell at '/'
            ├── shared/                   # Panel code used by 2+ modules (PS2/PS3)
            │   ├── register/             # The CRUD factory + the paged-list half (decisions 217/220)
            │   ├── feedback/             # The ONE feedback bridge (decision 221)
            │   └── session/              # CurrentInterface — privileges of the screen being drawn
            └── modules/                  # 1 screen = 1 flutter_modular module (no usecase layer — see ADMIN PANEL)
                ├── home/                 # The shell: app bar + two menu columns + RouterOutlet (215)
                ├── auth/                 # Login, mandatory TOTP enrollment, recovery (outside the shell)
                ├── privileges/  users/  interfaces/  system-modules/      # access control — registers
                ├── legal-policy/         # Legal Gate: jurisdictions, capabilities, rules (paged workflow lists)
                ├── risk-config/  category-forms/  monetization-config/    # fixed catalogs (unpaged, 220)
                ├── panic-responders/     # authorized-responder queue (paged workflow list)
                ├── dual-control-access/  # decision 45 gate: register, request only (227)
                ├── case-freeze/  reward-mediation/                        # flows
                └── reports/  report-stats/  admin-audit/                  # moderation, statistics, audit trail
</folder_structure>

## LAYERS
- **Style** (`packages/vgr_widgets/`): visual tokens and encapsulated `Vgr*` widgets. PROHIBITED: business logic, API calls, `easy_localization`.
- **Components** (`presentation/page/`, `presentation/bloc/`): screens and local UI state. PROHIBITED: calling the API or storage directly — always through `domain/usecase` (mobile) or the repository contract (admin panel, which has no usecase layer — see ADMIN PANEL).
- **Integration** (`domain/`, `data/`): usecases, repositories, datasources, data mapping. The only layer allowed to talk to `packages/core` (`ApiClient`, storage, session).

## MODULES
| Module | Responsibility | Location |
|--------|-----------------|-------------|
| core | ApiClient, Failure, full auth/session (domain+data+presentation), helpers, theme | `packages/core/` |
| vgr_widgets | Design system (`VgrButton`, `VgrCard`, `VgrFormShell`, ...) | `packages/vgr_widgets/` |
| vgr_validators | Shared validators/masks (mirrors the API) | `packages/vgr_validators/` |
| home | Navigation shell (menu + RouterOutlet) | `apps/mobile/lib/app/modules/home/` |
| admin/home | The admin SHELL (decision 215): app bar + two menu columns + `RouterOutlet`; every panel screen is a child `ModuleRoute` of `/` (decision 216 — URLs stay at the root). Registering a screen = 1 entry in `interface_routes.dart` + 1 `ModuleRoute` in `home_module.dart` | `apps/admin/lib/app/modules/home/` |
| admin/shared | Panel code used by 2+ modules: `register/` — the CRUD factory and its paged-list half; `feedback/` — the one feedback bridge; `session/` — `CurrentInterface` (see ADMIN PANEL below) | `apps/admin/lib/app/shared/` |
| features/* | One business domain per module (denúncia, ajuda, recompensa — to be defined by `scope-refinement`) | `apps/mobile/lib/app/modules/<feature>/` |
| admin/* | One panel screen per module (15 modules, 18 menu screens today — the inventory is in `feature/admin-panel.md`; how to add one: `ADMIN-SCREENS.md`) | `apps/admin/lib/app/modules/<module>/` |

REQUIRED: **A module never imports another module.** Code used by 2+ modules is promoted to `app/shared/` (app-level business code) or to a `package` (infra/design system).

## ADMIN PANEL (decisions 215–222, plano-painel-modelo-setes.md)
The setes-app `apps/web` model, applied to VGR (decision 15). How to add a
screen, step by step: [ADMIN-SCREENS.md](./ADMIN-SCREENS.md).

### Shell (215/216/218)
`AppModule` keeps the routes OUTSIDE a session (`/login`, `/two-factor-*`,
password recovery) and mounts `HomeModule` at `/`. `HomeModule` IS the shell:
`VgrScaffold` app bar (language, user badge with **Sign out**) + two
`VgrNavColumn`s (modules 200 px, screens of the selected module 240 px) +
`RouterOutlet`; below 850 px (`VgrResponsive`) the columns become a
`VgrDrawer`. The menu is `GET /api/core/menus`, already filtered by VIEW
(71); `MenuBloc` holds the selection. Every screen is a child `ModuleRoute`
of the shell, so URLs stay at the root (`/users/`, `/reports/`). Pages inside
the outlet are `VgrPage` (content header), never `VgrScaffold`.

### Registering a screen (setes' contract, kept)
One `tb_interface` row in the API + one entry in `interface_routes.dart`
(`i18n_key → '/route/'`) + one `ModuleRoute` among the shell's children. A
cataloged key without a route falls to `/pending`. The route provides the
screen's bloc(s) and repeats `AdminSessionGuard`.

### The register factory (`shared/register/`, 217/220)
A CRUD screen is `RegisterScreen<T, D>` plus configuration (title,
`CurrentInterface`, row builder, fields, draft builder). The module keeps its
entity, a draft, a repository implementing `RegisterRepository<T, D>` (paged
`list(PagedQuery)` + create / update / delete) and declares its bloc as an
ALIAS — `typedef PrivilegeBloc = RegisterBloc<PrivilegeEntity, PrivilegeDraft>`
— so the provider and the screen's lookup are one type.

- List ↔ form by STATE on one `ChildRoute('/')`: buildable `RegisterView`s
  (`RegisterListLoading/Loaded/Error`, `RegisterFormState`) and one-shot
  `RegisterSignal`s (`RegisterActionSuccess/Failure`); the bloc always
  re-emits a view after a signal. The bloc remembers the query and the last
  page: "back" returns to exactly what was there, a save or a delete refreshes
  that page (and lands on the real last page when the last row went away).
- Paged by default (220): `PagedResult<T>` / `PagedQuery` in `core`
  (mirrors the API's `pagedQueryDto`); the filter is sent on Enter only; a
  new filter or page size goes back to page 1. One pager: `VgrPagingBar`.
- Form (`RegisterFormPage` in a `VgrFormShell`): Tab order = declaration
  order, Enter advances and submits from the last field, ONE validation
  pendency at a time (dialog + focus, never the whole form painted red),
  server `fields[]` anchored on the field of the same name. Field kinds:
  text, flag, choice, checklist (`ordered` = click order); `visibleWhen`
  hides a field for some values (it is then neither validated nor focused).
  Small catalogs a form picks from load once beside the list
  (`RegisterLookupCubit<O>`).
- Privileges (`CurrentInterface`): "new" by INSERT, save by INSERT/UPDATE,
  delete by DELETE; without UPDATE a row opens read-only. Delete only after
  `askDecision`. UX only — the API decides (72).

### Workflow lists (the factory's list half, PS3)
Screens that are lists the operator ACTS on, not CRUDs (Legal Gate kill
switch, the responder queue), use `PagedListBloc<T>` + `PagedListScreen<T, B>`
alone: the module's bloc implements `fetch(query)`, declares its row actions
as `RegisterEvent` subclasses and runs them through `act()` — signal to the
bridge, then a QUIET reload (the server's answer replaces the rows, no
spinner). A register that is only ADDED to (versioned Legal Gate rules)
subclasses `RegisterBloc`, is provided under the base type and keeps rows
closed (`openRows: false`). `RegisterBloc` itself extends `PagedListBloc`.

### Feedback bridge (`shared/feedback/`, 221)
The only way a screen talks back: `showSuccessFeedback` (transient),
`showFailureFeedback` (severity from the `Failure`: no status or 5xx → dialog
to acknowledge; 4xx → transient message; always translated by code, 80/83),
`showValidationFeedback` (the one pendency), `askDecision` (yes / no
[/ cancel]; dismissal is the cautious answer). `feedback_bridge_guard_test`
fails the build on any `showVgr*` / `showDialog` / `ScaffoldMessenger`
outside it. Screens with their own blocs (fixed catalogs, flows, report
detail) hand action outcomes to the bridge from a listener; a load or lookup
error stays as screen state.

### Exceptions and deviations, on purpose
- `reports` (`/:id`, `/queue`) and `admin-audit` (`/:id`) keep their own
  routes — deep link per record and an audited read per case (217).
- Fixed catalogs (`risk-config`, `category-forms`, `monetization-config`)
  stay unpaged (220).
- `monetization-config` imports `risk-config`'s repository code (and binds
  its own instance) to apply the peer-to-peer veto of decision 58 — the one
  module-to-module import of the panel, kept because the veto needs the
  tiers and the API enforces the same rule anyway.
- `CurrentInterface` is passed by key, not a global written by navigation
  (setes): the shell's `MenuBloc` owns the selection and a global goes stale
  on refresh / deep link. Page titles stay their own translation keys instead
  of travelling as route `arguments`.
- **No usecase layer in the panel**: blocs call the repository contract
  (for registers, `RegisterRepository<T, D>`); the one-usecase-per-operation
  rule below holds for `apps/mobile`. This predates the factory and is now
  the documented shape of the panel, not an oversight to copy elsewhere.
- Setes' ERP engines (configurable fields, interface configuration, theme /
  logo per institution) are out (219).

## PATTERNS
<code_patterns>
# REQUIRED: immutable entity with fromJson (domain/entity)
class DenunciaEntity extends Equatable {
  final int id; final String categoria; final String? objeto;
  const DenunciaEntity({required this.id, required this.categoria, this.objeto});
  factory DenunciaEntity.fromJson(Map<String, dynamic> j) =>
      DenunciaEntity(id: (j['id'] as num).toInt(), categoria: j['categoria'], objeto: j['objeto']);
  @override List<Object?> get props => [id, categoria, objeto];
}

# REQUIRED: 1 usecase per operation (domain/usecase)
class DenunciaGetlist {
  final DenunciaRepository repository;
  DenunciaGetlist(this.repository);
  Future<Either<Failure, List<DenunciaEntity>>> call(String filter) => repository.getList(filter);
}

# REQUIRED: repository converts exceptions into Either (data/repository)
Future<Either<Failure, T>> guard<T>(Future<T> Function() run) async {
  try { return Right(await run()); }
  on Failure catch (f) { return Left(f); }
  catch (e) { return Left(Failure(message: e.toString())); }
}

# REQUIRED: page only reads state via BlocConsumer (presentation/page)
class DenunciaListPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocConsumer<DenunciaBloc, DenunciaState>(
    buildWhen: (p, c) => c is DenunciaListState,
    listenWhen: (p, c) => c is DenunciaActionSuccess || c is DenunciaActionFailure,
    builder: (context, state) => ...,
    listener: (context, state) => ...,
  );
}

# FORBIDDEN: calling the API directly inside a presentation widget
class DenunciaListPage extends StatelessWidget {
  Widget build(BuildContext context) {
    http.get(Uri.parse('...'));  // PROHIBITED — must live in data/datasource
    return ListView(...);
  }
}
</code_patterns>

## INTERNATIONALIZATION
REQUIRED: All source code, identifiers, and comments in English (project-wide standard).
REQUIRED: User-facing strings go through `easy_localization` — no hardcoded UI text in widgets.
REQUIRED: English (`en-US`) is the source/fallback locale; `pt-BR` is the first translated locale (`apps/mobile/assets/translations/`).
PROHIBITED: Hardcoded natural-language strings inside `presentation/` — always a translation key.
REQUIRED: Each app's `AppWidget` wraps its `MaterialApp.router` in core's `LocaleRefresh`: `.tr()` without a context does not subscribe a widget to the locale, so without it a language switch repainted only the selector and left the open screen in the old language (browser test of 2026-10-04).
REQUIRED: Timestamps from the API (UTC, ISO 8601 with `Z`) are shown through `formatLocalDateTime` / `formatLocalDate` (`packages/core/lib/src/format/local_time.dart`) — the device's local time, `yyyy-MM-dd HH:mm` (decision 232). PROHIBITED: cutting the ISO string on a screen (it showed UTC — 3 h ahead in Brazil).

## INTEGRATIONS
| External Service / Component | Purpose | Connection / Authentication Method |
|------------------------------|---------|-------------------------------------|
| vgr-api (`D:\ProjetoVGR\api`) | CRUD for reports, matching, rewards | REST/HTTPS via `core.ApiClient`, JWT Bearer (exact shape TBD in `scope-refinement`) |
| Geolocation | Dynamic radius calculation (decision 7 of the plan) | Native plugin (e.g. `geolocator`) — TBD |
| Push notifications | Notify helpers of nearby reports | Out of MVP scope (decision 11 of the plan) |

## REFERENCES

- [**README.md**](../README.md): Documentation navigation index.
- [**TESTS.md**](./TESTS.md): Testing strategies and commands.
- [**ADMIN-SCREENS.md**](./ADMIN-SCREENS.md): checklist to add a screen to the admin panel.
- [**setes-app**](D:\Gestao2027\setes-app) and Infra-IA's `ARQUITETURA_MODULOS.md`: source of the pattern mirrored here.
- [**vgr-api ARCHITECTURE.md**](D:\ProjetoVGR\api\docs\adr\ARCHITECTURE.md): server side, same module-to-module symmetry as setes-api/setes-app.
