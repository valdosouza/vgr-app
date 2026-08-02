# Project Architecture

## OVERVIEW
Flutter monorepo in Clean Architecture, mirroring the `setes-app` structure
(`D:\Gestao2027\setes-app`) by explicit product-owner decision. Native pub
workspace (Dart 3.6+), DI/routing with `flutter_modular`, state management
with `bloc`, async return type `Either<Failure, T>` (`dartz`). Flow:
presentation (bloc) → domain (usecase) → data (repository/datasource) → VGR
API (`D:\ProjetoVGR\api`, same structure as setes-api).

## FOLDER STRUCTURE
<folder_structure>
D:\ProjetoVGR\app/
├── pubspec.yaml                  # Workspace root — lists the 4 members below
├── packages/
│   ├── core/                     # Shared infra WITHOUT business UI (ApiClient, auth, session, helpers)
│   ├── vgr_widgets/               # Pure design system — no raw Flutter widget used directly in screens
│   └── vgr_validators/            # Pure validators/masks — mirrors vgr-api/src/shared/validation
└── apps/
    └── mobile/                   # Mobile app (Android/iOS) — the only app for now
        └── lib/app/
            ├── shared/            # Business code used by 2+ modules (promoted from inside a module)
            └── modules/
                ├── home/          # Shell: menu + RouterOutlet
                └── <feature>/     # 1 feature = 1 flutter_modular module (e.g. denuncia, ajuda)
                    ├── <feature>_module.dart   # Binds (DI) + ChildRoute
                    ├── data/
                    │   ├── datasource/         # Talks to core.ApiClient, throws Failure
                    │   └── repository/         # Converts exceptions into Either<Failure,T>
                    ├── domain/
                    │   ├── entity/             # Entities (Equatable), fromJson
                    │   ├── repository/         # Abstract contract (implemented in data/)
                    │   └── usecase/            # One file per operation (getlist, post, put, delete)
                    └── presentation/
                        ├── bloc/               # "Buildable" states (List/Form) + "one-shot" states (ActionSuccess/Failure)
                        └── page/               # Widgets — only read state via BlocConsumer
</folder_structure>

## LAYERS
- **Style** (`packages/vgr_widgets/`): visual tokens and encapsulated `Vgr*` widgets. PROHIBITED: business logic, API calls, `easy_localization`.
- **Components** (`presentation/page/`, `presentation/bloc/`): screens and local UI state. PROHIBITED: calling the API or storage directly — always through `domain/usecase`.
- **Integration** (`domain/`, `data/`): usecases, repositories, datasources, data mapping. The only layer allowed to talk to `packages/core` (`ApiClient`, storage, session).

## MODULES
| Module | Responsibility | Location |
|--------|-----------------|-------------|
| core | ApiClient, Failure, full auth/session (domain+data+presentation), helpers, theme | `packages/core/` |
| vgr_widgets | Design system (`VgrButton`, `VgrCard`, `VgrFormShell`, ...) | `packages/vgr_widgets/` |
| vgr_validators | Shared validators/masks (mirrors the API) | `packages/vgr_validators/` |
| home | Navigation shell (menu + RouterOutlet) | `apps/mobile/lib/app/modules/home/` |
| features/* | One business domain per module (denúncia, ajuda, recompensa — to be defined by `scope-refinement`) | `apps/mobile/lib/app/modules/<feature>/` |

REQUIRED: **A module never imports another module.** Code used by 2+ modules is promoted to `app/shared/` (app-level business code) or to a `package` (infra/design system).

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

## INTEGRATIONS
| External Service / Component | Purpose | Connection / Authentication Method |
|------------------------------|---------|-------------------------------------|
| vgr-api (`D:\ProjetoVGR\api`) | CRUD for reports, matching, rewards | REST/HTTPS via `core.ApiClient`, JWT Bearer (exact shape TBD in `scope-refinement`) |
| Geolocation | Dynamic radius calculation (decision 7 of the plan) | Native plugin (e.g. `geolocator`) — TBD |
| Push notifications | Notify helpers of nearby reports | Out of MVP scope (decision 11 of the plan) |

## REFERENCES

- [**README.md**](../README.md): Documentation navigation index.
- [**TESTS.md**](./TESTS.md): Testing strategies and commands.
- [**setes-app**](D:\Gestao2027\setes-app) and Infra-IA's `ARQUITETURA_MODULOS.md`: source of the pattern mirrored here.
- [**vgr-api ARCHITECTURE.md**](D:\ProjetoVGR\api\docs\adr\ARCHITECTURE.md): server side, same module-to-module symmetry as setes-api/setes-app.
