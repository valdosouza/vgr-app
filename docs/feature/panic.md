# Panic button — PP2 (mobile) — apps/mobile

Mobile side of the panic-button front (decision 51; round 14, decisions
190–199 in `AI/docs/decisions/VGR-plano.md`; plan
`AI/docs/plans/plano-panico.md` §4 PP2 row). PP1 (API,
`api/docs/feature/panic.md`) is what this codes against — read it first,
it is the authoritative contract. PP3 (mobile advanced/"activated" mode)
and PP4 (panel) are NOT here. Uncommitted, awaiting review.

## What this phase is, deliberately

- **Independent of the report flow, reachable at any time (62).** A new
  `panic` module, its own route (`/panic`), its own icon action on the
  feed's `VgrScaffold` — never nested under a report.
- **A cold trigger, no prior configuration (65).** No "activated"/
  "highlighted" opt-in screen exists (193/194 keep that out of scope) —
  tapping the button goes straight to a confirm dialog, then the API
  call. Nothing to fill in.
- **Single shot (191).** One position, captured at the moment of trigger,
  never updated. There is no live tracking screen and the repository
  never calls the trigger endpoint a second time for the same alert.
- **No free text anywhere (196).** The trigger request carries no message
  field, and the responder inbox renders a FIXED template built
  client-side from `{alertId, distanceKm}` only — the API never stores or
  serves anything else for a panic alert.
- **Only the triggerer resolves (197).** No admin/responder action exists
  to resolve someone else's alert — the inbox rows are read-only.
- **Cooldown is the server's problem (198).** This phase adds no
  client-side rate limiting of its own; a 409 `PANIC_ALERT_ACTIVE` is
  simply surfaced as a translated error.

## Where things live

A new `panic` module (`apps/mobile/lib/app/modules/panic/`):

- `domain/entity/panic_entities.dart` — `TriggeredAlertEntity {alertId,
  createdAt, recipientCount}` (the trigger response), `ResponderAlertEntity
  {alertId, distanceKm, createdAt, resolved}` (one inbox row),
  `ResponderRequestEntity` (the `POST .../responder-pool` response shape),
  `TriggerOutcome` (mirrors `SubmitOutcome`/`RateOutcome`: `.online(alert)`
  / `.queued()`).
- `domain/repository/panic_repository.dart` — `trigger()`, `resolve
  (alertId)`, `listAlerts({after, limit, position})`,
  `requestResponderAuthorization()`, plus `currentActiveAlertId()` and
  `responderRequestAlreadySent()` — see "The two known PP1 read gaps"
  below.
- `domain/usecase/*` — one thin wrapper per operation (architecture
  convention), no dedicated usecase tests (same precedent as
  `GetReportViewUsecase`/RT2's own usecases — these are exercised via the
  bloc tests that construct a real usecase over a mocked repository).
- `data/panic_local_store.dart`, `data/panic_repository_impl.dart`,
  `data/panic_queue_tasks.dart` — see "Data layer" below.
- `presentation/bloc/panic_hub_bloc.dart` — trigger/status/resolve flow.
- `presentation/bloc/panic_alerts_bloc.dart` — the responder inbox,
  mirrors `ChatConversationBloc`'s ticker/lifecycle shape exactly.
- `presentation/page/panic_hub_page.dart` (route `/panic/`),
  `presentation/page/panic_alerts_page.dart` (route `/panic/alerts`).
- `panic_module.dart` — the two blocs' binds and `ChildRoute`s.
  `PanicRepository` itself, and the `LocationGateway` it depends on, are
  bound at `AppModule` level (see "Cross-module wiring" below), not here.

`PanicRepository` is bound once in `app_module.dart` (like
`RatingRepository`/`MyReportsStore`) because it is reachable from BOTH
the panic module (trigger/resolve/inbox) and the auth module's account
page (the responder-request tile and the "My Alerts" navigation entry).

`nearby_feed_page.dart` gained a `feed-panic-button` action (`VgrIconName.
panic`, a new icon mapped to `Icons.sos` — decision 133's "named by
meaning" rule, added the same way RT2 added `starFilled`/`starOutline`)
in the SAME `actions` list as the existing account/login button — the
feed is the one screen every user, including a fully anonymous one,
always reaches, satisfying decision 62 with a single required entry
point. A second entry point on `account_page.dart` was considered
optional and not added beyond the two PP2-specific tiles described below.

`account_page.dart` gained two tiles, after the existing
`account-verify-email-tile`:

1. `account-become-responder-tile` — `onTap` shows `showVgrConfirm`
   (decision 190 is a real commitment: an admin will judge it, so it is
   confirmed the same way the panic trigger is), then dispatches
   `AccountResponderRequestPressed`. On success the tile's subtitle
   becomes "Request sent — pending review" and the tile stops accepting
   taps (`onTap: null`) — no "resend" affordance was added (default to
   never inviting an accidental duplicate, since the API enforces no
   uniqueness constraint of its own). If the local flag is already set on
   load, the page skips straight to that state without ever showing the
   inviting copy.
2. `account-my-alerts-tile` — a plain navigation entry to `/panic/alerts`.
   No status is computed or hinted at on this tile (there is nothing to
   compute it from, see the gaps below); the destination screen itself
   renders "Nothing here yet." for an empty list, whether that means "not
   a responder" or "a responder with nothing yet" — the two cases are
   indistinguishable client-side and that is fine, per PP1's own contract.

`AccountBloc` gained `AccountResponderRequestPressed` and three
`AccountReady` fields — `responderRequestSent`, `responderRequestSending`,
`responderRequestFailure` — following the exact shape RT2 already
established for the reputation section (`AccountStarted` now ALSO checks
`CheckResponderRequestSentUsecase` alongside `GetMyReputationUsecase`,
in parallel, both best-effort).

## The two known PP1 read gaps — handled, not papered over

PP1 built no endpoint to answer either of these questions from the
server:

1. **"Do I (as the trigger's account or device) have an active alert
   right now?"** There is no `GET /app-panic/alert/mine` or similar.
2. **"Is my own responder-pool request pending/approved/denied?"** There
   is no `GET /app-panic/responder-pool/mine` either — only the
   admin-gated list/resolve endpoints exist, and this app is not an admin
   client.

Both are handled the same way: **local bookkeeping only**, held by a new
`PanicLocalStore` (`data/panic_local_store.dart`) — the same
`SharedPreferences`-backed shape as `MyReportsStore` (a different entity;
`MyReportsStore` itself is untouched), holding:

- the CURRENT unresolved alert THIS DEVICE triggered, if any — a single
  `{alertId, clientKey}` record (never a map: only one active alert per
  device at a time by construction, mirroring the server's own cooldown,
  198), survives an app restart so `resolve` can still be called later.
- whether a responder-pool request was already sent from this device — a
  boolean, purely a UX nicety against inviting a duplicate `POST` (the API
  itself enforces no uniqueness).

`PanicRepository.currentActiveAlertId()` and
`.responderRequestAlreadySent()` surface these THROUGH the repository
contract (never touched directly by a bloc — decision 133's layering
still applies to storage, not just widgets).

**The accepted consequence**: if this device's local record is lost (a
reinstall, cleared app storage, a second device) while the SERVER still
has this account's alert `active`, a fresh trigger attempt gets back 409
`PANIC_ALERT_ACTIVE` with no way for the app to reconstruct or show the
actual stranded alert. `PanicRepositoryImpl.trigger()` and
`PanicHubBloc` both handle this without crashing — a clear translated
message (`core.errors.PANIC_ALERT_ACTIVE`), never a silent no-op — but
the user is stuck seeing that message on every retry until either the
server-side cooldown naturally clears (there is none — `active` alerts
do not expire) or an admin/responder resolves it through some other
means, or a follow-up phase adds the missing read endpoint. This is a
real, accepted gap of PP1's scope, not an oversight; flagged here and at
the top of `api/docs/feature/panic.md`'s "Deliberately out" section as a
candidate for a future round.

## Data layer

- `PanicRepository.trigger()` — `POST /app-panic/alert`. Generates its
  own FRESH `clientKey` per call (mirrors `RatingRepositoryImpl.rateOffer`
  — a genuine retry after a real refusal is its own new attempt, 137) and
  reads the device's position via `LocationGateway` INTERNALLY (never
  passed in): a location failure is a `Left` and the API is never called,
  same posture as the report form's position gate. Two-tier online/
  offline: an API-judged refusal (422/451, or 409 `PANIC_ALERT_ACTIVE` —
  198) is a `Left`, NEVER enqueued; a transport failure enqueues
  **`panic_alert_trigger`** and answers `TriggerOutcome.queued()` (decision
  28 — queued is a success, not an error). Online success saves
  `{alertId, clientKey}` to `PanicLocalStore` immediately; a QUEUED
  trigger cannot save it yet (the alertId does not exist server-side
  until the queue task actually runs) — `panic_queue_tasks.dart`'s
  `trigger` handler is where that save finally happens once the API
  answers.
- `PanicRepository.resolve(alertId)` — `POST /app-panic/alerts/:id/
  resolve`. Reads the locally-stored record to send `x-client-key` when
  the trigger was anonymous (mirrors `ReportRepositoryImpl.resolve`).
  Online success clears the local record. **Judgment call** (mirrors
  `report_queue_tasks.dart`'s `_judgeResolve` for the exact same reason):
  a 409 `PANIC_ALERT_ALREADY_RESOLVED` is treated as an EFFECTIVE success
  — the local record is cleared and the call returns `Right(null)` either
  way, since an ack that never reached this device after a first resolve
  DID succeed would otherwise strand the user on a permanently "active"
  screen for no product reason. Every other refusal (404 missing/not
  owner) surfaces as-is, untouched. A transport failure enqueues
  **`panic_alert_resolve`** and clears the local record right away too
  (queued is a success, 28) — a replayed dispatch is answered by the API
  as a resolve of the same alert either way.
- `PanicRepository.listAlerts({after, limit, position})` — `GET
  /app-panic/alerts?after&limit&lat&lng`, read-only, no offline queue (a
  stale cached inbox would be actively misleading, same posture as
  `getMyReputation`); a transport failure is `OFFLINE`.
- `PanicRepository.requestResponderAuthorization()` — `POST /app-panic/
  responder-pool` with an EMPTY body (no `criteriaNotes` is collected in
  this phase — 193/194 keep per-user configuration screens out of scope;
  decision 190 leaves eligibility to free admin judgment anyway). Online
  success marks the local "already sent" flag. No offline queue (an
  infrequent, identified-only action, same posture as `getMyReputation`).

## Presentation layer

- `PanicHubBloc` — `PanicPhase { loading, idle, triggering, active,
  resolving }` over a single state carrying `alertId`, `recipientCount`,
  `queued`, `failure`. `PanicHubStarted` reads
  `CheckActivePanicAlertUsecase` (the local record) to decide idle vs.
  active on load — even after a fresh app start. `PanicTriggerPressed` is
  dispatched by the page ONLY after `showVgrConfirm` (`destructive: true`,
  the same widget RT2 used for closing a report); a QUEUED outcome shows
  the active state WITHOUT an `alertId` yet (nothing to resolve until the
  queue lands it — a documented simplification: the hub does not
  auto-refresh mid-visit when a queued trigger settles in the background;
  leaving and returning to the screen, or an app restart, picks it up via
  the local record). `PanicResolvePressed` carries NO confirmation gate
  (calming a false alarm down should never carry extra friction) and is a
  no-op while no `alertId` exists yet.
- `PanicAlertsBloc` — mirrors `ChatConversationBloc`'s exact ticker/
  lifecycle shape: an injectable `PanicAlertsTicker` (tests hand a
  controlled stream, never a real `Duration(seconds: 5)` timer), started
  on load/resume, stopped on pause/dispose via a `WidgetsBindingObserver`
  in `panic_alerts_page.dart`. Poll interval: 5 seconds
  (`panicAlertsPollInterval`), same cadence as chat (decision 192 —
  polling only, never push). **Position cadence (judgment call)**: the
  responder's OWN position is re-read once per visit/resume, NEVER on
  every poll tick — repeatedly hitting the OS location API every 5
  seconds would be wasteful, and a resume (or a manual re-entry) is a
  fair moment to refresh it; a transient re-location failure on resume is
  swallowed, keeping the last known position rather than losing the whole
  screen over a permission blip. A failed poll tick keeps the inbox as it
  was (transient), same posture as chat's own tick failure handling.
- `panic_hub_page.dart` / `panic_alerts_page.dart` — read-only rendering
  of the above; the inbox's `_AlertTile` builds the FIXED template
  (`panic.alerts.template`, "Panic alert — {distance} km away") from
  `{alertId, distanceKm}` only, and renders a resolved row visually
  distinct (a "Resolved" caption) with no action control at all (197).

## Cross-module wiring

`app_module.dart` gained, alongside the existing `RatingRepository`/
`MyReportsStore` binds:

- `PanicLocalStore` — a singleton, mirrors `MyReportsStore`.
- `LocationGateway` — bound HERE too, not only inside `ReportModule`
  (which keeps its own copy unchanged). This is a deliberate departure
  from the "just duplicate the one-liner inside the sibling module"
  pattern RT2/chat established: `PanicRepositoryImpl.trigger()` needs
  `LocationGateway` internally, and `PanicRepository` must live at
  `AppModule` level to be reachable from the auth module — so the
  gateway has to be resolvable AT THAT LEVEL too. `PanicModule` itself
  does NOT re-declare the bind a third time; its own `PanicAlertsBloc`
  resolves the parent `AppModule` bind directly via `i.get<LocationGateway
  >()`, exactly like `ReportModule`'s blocs already resolve `ApiClient`/
  `MyReportsStore` from the parent without re-binding them.
- `PanicRepository` — a lazy singleton over `ApiClient`,
  `OfflineQueueService`, `PanicLocalStore`, `LocationGateway`.
- `PanicQueueTasks.register(...)` inside the SAME `OfflineQueueService`
  factory block where `ReportQueueTasks`/`ChatQueueTasks`/
  `RatingQueueTasks` already register theirs.
- `ModuleRoute('/panic', module: PanicModule())`, listed above the final
  `ModuleRoute('/', module: ReportModule())` catch-all (the file's own
  comment already states specific prefixes must precede it).

`auth_module.dart`'s `AccountBloc` bind gained
`CheckResponderRequestSentUsecase`/`RequestResponderAuthorizationUsecase`
over `i.get<PanicRepository>()`, mirroring how it already reaches
`RatingRepository` for the reputation section.

## Design system addition (133)

`VgrIconName.panic` (`packages/vgr_widgets/lib/src/vgr_icon.dart`) →
`Icons.sos` — a new semantic name, deliberately distinct from the
existing `alert` (used by report feed items), so the panic action reads
as visually different and more urgent. Added the same way RT2 added
`starFilled`/`starOutline`; covered by the existing "every semantic name
maps to an icon" guard test, no new test needed.

## Deliberately NOT here (193/194/199, mirrors PP1's own "Deliberately out")

- Any trusted-contact recipient mode, or an "activated/highlighted"
  per-user configuration screen — PP1 built none of the underlying data
  either.
- Client-side rate limiting beyond surfacing the server's own 409 (198 is
  explicitly server-side, identified-callers-only).
- Any reconstruction of a stranded local record from the server — see
  "The two known PP1 read gaps" above.
- Live tracking / a position update after trigger — single shot (191) is
  final by construction; the repository never calls the trigger endpoint
  twice for one alert.
- A second panic entry point beyond the feed's action — considered,
  judged unnecessary for this phase (the feed already satisfies "reachable
  at any time" for every user, anonymous included).
- PP3 (mobile advanced mode) and PP4 (panel) — separate future rounds.

## Tests

+0 `vgr_widgets` (23 → 23, unchanged): the new `VgrIconName.panic` is
covered by the existing "every semantic name maps to an icon" loop test,
no dedicated test needed.
+82 mobile (262 → 344): `TriggeredAlertEntity`/`ResponderAlertEntity`/
`ResponderRequestEntity`/`TriggerOutcome` parsing; `PanicLocalStore`
(active-alert save/replace/clear/restart-survival, the responder flag,
their independence); `PanicRepositoryImpl` (`trigger` incl. location
failure never calling the API, every judged code incl. 409
`PANIC_ALERT_ACTIVE`, transport queue, per-call fresh clientKey; `resolve`
incl. anonymous/identified headers, the 409-already-resolved judgment
call, 404 left untouched, transport queue clearing the record right away;
`listAlerts`; `requestResponderAuthorization`; `currentActiveAlertId`/
`responderRequestAlreadySent`) and its `panic_alert_trigger`/
`panic_alert_resolve` queue-task handlers (done, 5xx retry, judged-refusal
drop, the already-resolved-is-done judgment call); `PanicHubBloc`
(start-up from the local record, the full trigger flow incl. queued/
judged/location-failure paths, resolve incl. the no-alertId-yet no-op);
`PanicAlertsBloc` (ticker start/stop on load/resume/pause/dispose using
an injectable fake ticker, cursor advancing across ticks, a failed tick
kept transient, the position-per-visit/resume cadence incl. the
best-effort swallow on a failed resume relocation); `PanicHubPage`/
`PanicAlertsPage` widget tests for the confirm gate, every visual state,
and the retry affordance; `AccountBloc`/`AccountPage` responder-request
flow (sending/sent/failure, the already-sent skip, the confirm gate, the
plain "My Alerts" entry); `NearbyFeedPage`'s new panic action. `packages/
core` untouched (31/31 unchanged); `apps/admin` untouched.
