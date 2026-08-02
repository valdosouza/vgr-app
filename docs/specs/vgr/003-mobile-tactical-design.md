# Tactical Design — mobile
**Domain:** vgr | **Project:** mobile

> Frontend architecture: Flutter Clean Architecture per `docs/adr/ARCHITECTURE.md` — one `flutter_modular` module per feature, each with `domain/` (entity, repository contract, usecase), `data/` (datasource, repository impl), `presentation/` (bloc, page). Style layer lives in `packages/vgr_widgets`. DDD constructs below map onto this shape; they do not replace it.

## Section 1 — Main Structure

| Element | Layer / Type | Invariants / Tech Rules | 4-line Snippet |
|---|---|---|---|
| vgr_widgets design tokens | Style | Shared spacing/color/typography tokens, no business logic | *see below* |
| ReportFormPage, ReportDetailPage | Components | Report submission and detail screens; no direct API calls | *see below* |
| NearbyReportsFeedPage | Components | Paginated list, infinite scroll or page control (decision 21) | *see below* |
| HelpOfferFormPage | Components | HelpType picker; disabled if current user is the Report's own reporter (decision 20) | *see below* |
| DirectionSightingBloc | Integration | Emits sighting-logged one-shot state synchronously (decision 22) | *see below* |
| RewardBloc | Integration | Only renders allocation controls to the Reporter (decision 30) | *see below* |
| IdentityBloc (in `packages/core`) | Integration | Holds current Role/AnonymityMode; shared across all feature modules | *see below* |
| LoginPage (in `packages/core`) | Components | Google/Apple/Facebook sign-in buttons (decision 31); no email/password form in MVP | *see below* |
| OfflineQueueService (in `packages/core`) | Integration | Persists pending Report/Sighting writes locally (decision 28) | *see below* |

```dart
// design tokens — packages/vgr_widgets/lib/src/theme/vgr_tokens.dart
class VgrTokens {
  static const spacingMd = 16.0; static const colorPrimary = Color(0xFF1A1A2E);
}
```
```dart
// presentation/bloc — NearbyReportsFeedBloc
class NearbyReportsFeedBloc extends Bloc<FeedEvent, FeedState> {
  // paginated fetch via ListNearbyReportsUsecase, ordering: recency | relevance
}
```
```dart
// presentation/page — HelpOfferFormPage
class HelpOfferFormPage extends StatelessWidget {
  final int reportId; // form disabled if reportId.reporterId == currentUserId
}
```
```dart
// packages/core — IdentityBloc
class IdentityBloc extends Bloc<IdentityEvent, IdentityState> {
  // holds Role + AnonymityMode, read by every feature module
}
```

## Section 2 — Types / Interfaces

| Name | Layer | Rules | 4-line Snippet |
|---|---|---|---|
| ReportEntity | domain/entity (report module) | Mirrors API Report; category XOR freeTag | *see below* |
| HelpOfferEntity | domain/entity (help_offer module) | HelpType is a closed enum, not free text | *see below* |
| DirectionEstimateEntity | domain/entity (direction_sighting module) | probabilityByDirection sums to 1.0 | *see below* |
| RewardEntity | domain/entity (reward module) | Holds only opaque reportId reference, never category/tags | *see below* |
| IdentityState | presentation/bloc (core) | One of: Anonymous, Reporter, Helper, Police *(Police unreachable pre-validation, decision 12)* | *see below* |
| NearbyReportsFeedState | presentation/bloc (help_matching module) | Buildable: Loading/Loaded(paginated)/Empty/Error | *see below* |

```dart
class ReportEntity extends Equatable {
  final int id; final String? category; final String? freeTag;
  const ReportEntity({required this.id, this.category, this.freeTag});
}
```
```dart
class DirectionEstimateEntity extends Equatable {
  final int reportId; final Map<String, double> probabilityByDirection;
  const DirectionEstimateEntity({required this.reportId, required this.probabilityByDirection});
}
```
```dart
class RewardEntity extends Equatable {
  final int id; final int reportId; final RewardOfferType offer; // opaque reportId only
  const RewardEntity({required this.id, required this.reportId, required this.offer});
}
```
```dart
sealed class NearbyReportsFeedState {}
class FeedLoaded extends NearbyReportsFeedState { final List<ReportEntity> page; final bool hasMore; }
```

## Section 3 — Usecases / Blocs

| Operation / Hook | Responsibility | Coordinates / Subscriptions | 4-line Snippet |
|---|---|---|---|
| SubmitReportUsecase | Sends a new Report to the API, falls back to OfflineQueueService if offline | ReportRepository, OfflineQueueService | *see below* |
| ListNearbyReportsUsecase | Fetches a paginated, ordered feed within the Dynamic Radius | ReportRepository, IdentityBloc (for role-based filtering) | *see below* |
| SubmitHelpOfferUsecase | Registers a HelpOffer, blocked client-side for self-dealing (decision 20) | HelpOfferRepository, IdentityBloc | *see below* |
| LogDirectionSightingUsecase | Posts a Sighting synchronously, awaits reconciled estimate | DirectionSightingRepository | *see below* |
| OfferRewardUsecase / AllocateRewardUsecase | Reporter-only actions gated by IdentityBloc.currentUser == report.reporterId; OfferRewardUsecase additionally requires the Reporter to be registered, not anonymous (decision 33) | RewardRepository, IdentityBloc | *see below* |
| AuthenticateWithProviderUsecase | Signs in via Google/Apple/Facebook SDK and stores the resulting session (decision 31) | IdentityBloc, core.ApiClient | *see below* |
| OfflineQueueService.flush | Dispatches queued writes once connectivity returns | ReportRepository, DirectionSightingRepository | *see below* |

```dart
class SubmitReportUsecase {
  Future<Either<Failure, int>> call(ReportInput input) async {
    // if offline: OfflineQueueService.enqueue(input); return Right(pendingLocalId)
  }
}
```
```dart
class SubmitHelpOfferUsecase {
  Future<Either<Failure, int>> call(int reportId, HelpType type) {
    // guard: if reportId.reporterId == identity.currentUserId → Left(SelfDealingFailure)
  }
}
```
```dart
class LogDirectionSightingUsecase {
  Future<Either<Failure, DirectionEstimateEntity>> call(int reportId, Direction dir) =>
    repository.logSighting(reportId, dir); // synchronous — no fire-and-forget
}
```

## Section 4 — Events / Actions

| Event / Action Name | Trigger | Minimum Payload | Consumers |
|---|---|---|---|
| ReportSubmissionQueuedOffline | SubmitReportUsecase detects no connectivity | `{ localDraftId }` | ReportFormPage (shows "queued" banner) |
| FeedPageRequested | User scrolls NearbyReportsFeedPage / changes ordering | `{ page, orderBy }` | NearbyReportsFeedBloc |
| HelpOfferBlockedSelfDealing | SubmitHelpOfferUsecase rejects self-candidacy | `{ reportId }` | HelpOfferFormPage (disables submit, shows message) |
| DirectionSightingLogged | LogDirectionSightingUsecase resolves | `{ reportId, updatedEstimate }` | DirectionEstimateWidget (re-renders probability bar) |
| RewardAllocationSubmitted | RewardBloc.allocate() called by Reporter | `{ rewardId, claimIds[] }` | RewardBloc (one-shot ActionSuccess/ActionFailure) |
| RewardOfferBlockedAnonymousReporter | OfferRewardUsecase rejects an anonymous Reporter (decision 33) | `{ reportId }` | RewardBloc (prompts registration/login before offering) |
| ProviderLoginCompleted | AuthenticateWithProviderUsecase resolves | `{ provider, userId }` | IdentityBloc (updates Role/AnonymityMode) |

## Section 5 — Data Access Interfaces

| Resource / Adapter | Methods / Actions | Return Types / Expected State |
|---|---|---|
| ReportRepository | submit, getById, listNearby(position, page, orderBy) | `Either<Failure,int>`, `Either<Failure,ReportEntity>`, `Either<Failure,List<ReportEntity>>` |
| HelpOfferRepository | submit, listByReport | `Either<Failure,int>`, `Either<Failure,List<HelpOfferEntity>>` |
| DirectionSightingRepository | logSighting | `Either<Failure,DirectionEstimateEntity>` |
| RewardRepository | offer, allocate, getByReport | `Either<Failure,int>`, `Either<Failure,void>`, `Either<Failure,RewardEntity>` |
| OfflineQueueService (packages/core) | enqueue, flush, pendingCount | `void`, `Future<void>`, `int` |

```dart
abstract class ReportRepository {
  Future<Either<Failure, List<ReportEntity>>> listNearby(GeoPosition pos, int page, FeedOrder order);
  Future<Either<Failure, int>> submit(ReportInput input);
}
```

## Section 6 — Ordered Development Tasks

```json
[
  { "id": "01", "title": "Set up VGR design tokens in vgr_widgets", "description": "Defines base styling variables (spacing, color, typography) shared by all feature modules.", "scope": ["packages/vgr_widgets/lib/src/theme/vgr_tokens.dart"], "acceptance": ["All tokens defined and documented", "No hardcoded style values in any subsequent widget"], "depends_on": null },
  { "id": "02", "title": "Implement core VgrButton, VgrCard, VgrFormShell widgets", "description": "Builds the minimal design-system widget set the first feature screens need.", "scope": ["packages/vgr_widgets/lib/src/widgets/vgr_button.dart", "packages/vgr_widgets/lib/src/widgets/vgr_card.dart", "packages/vgr_widgets/lib/src/widgets/vgr_form_shell.dart"], "acceptance": ["Widgets render with VgrTokens only, no raw Flutter Material widgets used directly by feature pages"], "depends_on": "01" },
  { "id": "03", "title": "Implement ReportEntity and ReportRepository contract", "description": "Creates the domain entity and abstract repository for the report feature module.", "scope": ["apps/mobile/lib/app/modules/report/domain/entity/report_entity.dart", "apps/mobile/lib/app/modules/report/domain/repository/report_repository.dart"], "acceptance": ["ReportEntity enforces category XOR freeTag at construction"], "depends_on": null },
  { "id": "04", "title": "Implement ReportDatasource and ReportRepositoryImpl", "description": "Wires the report module's data layer against core.ApiClient, including offline fallback.", "scope": ["apps/mobile/lib/app/modules/report/data/datasource/report_datasource.dart", "apps/mobile/lib/app/modules/report/data/repository/report_repository_impl.dart"], "acceptance": ["submit() enqueues to OfflineQueueService when the client is offline"], "depends_on": "03" },
  { "id": "05", "title": "Implement SubmitReportUsecase and ReportBloc", "description": "Coordinates report submission with buildable/one-shot bloc states.", "scope": ["apps/mobile/lib/app/modules/report/domain/usecase/submit_report_usecase.dart", "apps/mobile/lib/app/modules/report/presentation/bloc/report_bloc.dart"], "acceptance": ["Emits a queued-offline one-shot state when submission is deferred"], "depends_on": "04" },
  { "id": "06", "title": "Implement ReportFormPage and report_module.dart", "description": "Builds the submission screen and wires flutter_modular DI/routes for the report module.", "scope": ["apps/mobile/lib/app/modules/report/presentation/page/report_form_page.dart", "apps/mobile/lib/app/modules/report/report_module.dart"], "acceptance": ["Form submits via ReportBloc only, no direct ApiClient call in the widget"], "depends_on": "05" },
  { "id": "07", "title": "Implement ListNearbyReportsUsecase and NearbyReportsFeedBloc with pagination", "description": "Adds paginated, recency/relevance-ordered fetching to the report module.", "scope": ["apps/mobile/lib/app/modules/report/domain/usecase/list_nearby_reports_usecase.dart", "apps/mobile/lib/app/modules/report/presentation/bloc/nearby_reports_feed_bloc.dart"], "acceptance": ["Requesting the next page appends without duplicating existing entries"], "depends_on": "06" },
  { "id": "08", "title": "Implement NearbyReportsFeedPage", "description": "Builds the paginated feed screen consuming NearbyReportsFeedBloc.", "scope": ["apps/mobile/lib/app/modules/report/presentation/page/nearby_reports_feed_page.dart"], "acceptance": ["Shows Loading/Loaded/Empty/Error states distinctly"], "depends_on": "07" },
  { "id": "09", "title": "Implement HelpOfferEntity, repository contract, and self-dealing guard", "description": "Creates the help_offer module's domain layer, blocking self-candidacy client-side.", "scope": ["apps/mobile/lib/app/modules/help_offer/domain/entity/help_offer_entity.dart", "apps/mobile/lib/app/modules/help_offer/domain/repository/help_offer_repository.dart", "apps/mobile/lib/app/modules/help_offer/domain/usecase/submit_help_offer_usecase.dart"], "acceptance": ["Usecase returns a SelfDealingFailure when helperId equals the report's reporterId"], "depends_on": "03" },
  { "id": "10", "title": "Implement help_offer data layer, bloc, and HelpOfferFormPage", "description": "Completes the help_offer module end to end.", "scope": ["apps/mobile/lib/app/modules/help_offer/data/", "apps/mobile/lib/app/modules/help_offer/presentation/", "apps/mobile/lib/app/modules/help_offer/help_offer_module.dart"], "acceptance": ["Submit button is disabled (not just rejected) when current user is the report's reporter"], "depends_on": "09" },
  { "id": "11", "title": "Implement DirectionEstimateEntity and synchronous LogDirectionSightingUsecase", "description": "Creates the direction_sighting module's domain layer with synchronous submission.", "scope": ["apps/mobile/lib/app/modules/direction_sighting/domain/", "apps/mobile/lib/app/modules/direction_sighting/data/", "apps/mobile/lib/app/modules/direction_sighting/direction_sighting_module.dart"], "acceptance": ["UI awaits the reconciled DirectionEstimateEntity before dismissing the loading state — no fire-and-forget"], "depends_on": "03" },
  { "id": "12", "title": "Implement DirectionEstimateWidget probability visualization", "description": "Renders the weighted directional estimate on the report detail page.", "scope": ["apps/mobile/lib/app/modules/direction_sighting/presentation/"], "acceptance": ["Updates immediately after a new sighting is logged"], "depends_on": "11" },
  { "id": "13", "title": "Implement RewardEntity behind an opaque report reference", "description": "Creates the reward module's domain layer, never reading Report category/tags directly.", "scope": ["apps/mobile/lib/app/modules/reward/domain/"], "acceptance": ["RewardEntity's fromJson never parses a category or tag field"], "depends_on": "03" },
  { "id": "14", "title": "Implement reward data layer, RewardBloc, and Reporter-only allocation UI", "description": "Completes the reward module, gating allocation controls to the Reporter.", "scope": ["apps/mobile/lib/app/modules/reward/data/", "apps/mobile/lib/app/modules/reward/presentation/", "apps/mobile/lib/app/modules/reward/reward_module.dart"], "acceptance": ["Allocation controls are hidden for any user other than the report's reporter"], "depends_on": "13" },
  { "id": "15", "title": "Implement IdentityBloc and Role/AnonymityMode in packages/core", "description": "Builds the shared identity state consumed by every feature module.", "scope": ["packages/core/lib/src/identity/"], "acceptance": ["Role defaults to Anonymous until a registration/session action changes it"], "depends_on": null },
  { "id": "16", "title": "Implement OfflineQueueService in packages/core", "description": "Provides local persistence and flush-on-connectivity for offline writes.", "scope": ["packages/core/lib/src/offline/offline_queue_service.dart"], "acceptance": ["Queued items are dispatched in order once connectivity is detected", "pendingCount reflects the actual local queue size"], "depends_on": "15" },
  { "id": "17", "title": "Implement LoginPage with Google, Apple, and Facebook sign-in buttons", "description": "Builds the frictionless social-login screen in packages/core (decision 31), no email/password form.", "scope": ["packages/core/lib/src/identity/presentation/login_page.dart", "packages/core/lib/src/identity/domain/authenticate_with_provider_usecase.dart"], "acceptance": ["Tapping each provider button triggers that provider's native SDK flow", "A successful login emits ProviderLoginCompleted and updates IdentityBloc"], "depends_on": "15" },
  { "id": "18", "title": "Gate OfferReward UI behind Reporter registration", "description": "Prompts an anonymous Reporter to log in before they can offer a Reward (decision 33).", "scope": ["apps/mobile/lib/app/modules/reward/presentation/bloc/reward_bloc.dart", "apps/mobile/lib/app/modules/reward/presentation/page/"], "acceptance": ["Anonymous Reporter tapping 'Offer Reward' sees RewardOfferBlockedAnonymousReporter and a login prompt, not a raw error"], "depends_on": "17" },
  { "id": "19", "title": "Show reward-ineligibility notice to anonymous Helpers", "description": "Informs an anonymous Helper, before they submit a Help Offer on a Reward-bearing Report, that they won't be eligible for the Reward (decision 34).", "scope": ["apps/mobile/lib/app/modules/help_offer/presentation/page/help_offer_form_page.dart"], "acceptance": ["Notice is shown only when the target Report has an active Reward and the current user is anonymous", "Anonymous Helper can still submit the Help Offer after seeing the notice"], "depends_on": "10" },
  { "id": "20", "title": "Add phone/WhatsApp OTP option to LoginPage", "description": "Adds the 4th confirmed login method (decision 31) to the social sign-in screen.", "scope": ["packages/core/lib/src/identity/presentation/login_page.dart"], "acceptance": ["User can request and submit an OTP code as an alternative to the three social buttons"], "depends_on": "17" }
]
```

## Save

Saved to: `D:\ProjetoVGR\app\docs\specs\vgr\003-mobile-tactical-design.md`
