# Direction sighting — DS2 (mobile) — apps/mobile

Mobile side of the direction-sighting front (round 15, decisions 200-207
in `AI/docs/decisions/VGR-plano.md`; plan
`AI/docs/plans/plano-direction-sightings.md` §4 DS2 row). DS1 (API,
`api/docs/feature/direction-sightings.md`) is what this codes against —
read it first, it is the authoritative contract. DS3 (panel) is empty by
decision (201 chose the hardcoded eligibility pattern, no admin screen) —
nothing to build there. Uncommitted, awaiting review.

A community member near an OPEN report whose category involves a fleeing
subject (robbery, kidnapping, fugitive, missing) taps which of 8 compass
directions they saw it go. Once a report has enough sightings (a floor,
env-configured server-side, invisible to this app), everyone who can see
that report — including anonymous public feed viewers — sees the single
most-likely direction. Below the floor, nothing shows, on purpose.

## What the app NEVER decides

- **Eligibility (201).** The 4-category list (`robbery`, `kidnapping`,
  `fugitive`, `missing`) mirrored client-side
  (`_directionSightingEligibleCategories`,
  `report_detail_page.dart`) is a UX HINT ONLY — it exists solely to hide
  a button that would otherwise always fail server-side with 422
  `DIRECTION_SIGHTING_NOT_ELIGIBLE`. The app never treats it as
  authoritative and never uses it for anything beyond that one
  affordance decision.
- **The disclosure floor (202) and the reconciliation algorithm (26).**
  The app renders whatever `directionEstimate` the server sends — `{
  direction } | null` — and never guesses at, recomputes, or infers the
  floor value or the weighting logic. A `null` estimate could mean "below
  the floor", "ineligible category", or "no sightings yet" — the app does
  not distinguish between these, nor should it.
- **Self-dealing (200).** Enforced server-side only. The app just does
  not offer the picker to the report's own owner (`view.access ==
  ReportAccess.owner`) as a UX courtesy, since that call would always
  fail with 422 `BUSINESS_RULE` anyway.
- **Weighting (27/205), reputation (206).** Nothing here; entirely
  server-side, nothing for the app to render or decide.

## The write/read asymmetry (decisions 22/203) — how the app uses it

`POST /app-direction-sightings` ALWAYS answers `{ sightingId, reportId,
estimate, count }`, UNGATED by the disclosure floor — private,
synchronous feedback to the device that just acted. The app shows this
ONCE, right after a successful ONLINE submission, as a caption:
"Current best guess so far: North (6 sightings)." (`detail.directionFeedback`,
`ReportDetailBloc`'s `sightFeedback` state field). This is deliberately
NEVER read from anywhere else — in particular, never confused with the
shared, floor-gated READ facet (`view.directionEstimate`) rendered
elsewhere on the very same screen, which may still show `null` to
everyone else below the floor even though this device just got a private
`estimate`/`count` back. A QUEUED (offline) sighting has no synchronous
feedback at all — `sightFeedback` stays null until the next full reload.

## Where things live

No dedicated screen: the picker and the read-only estimate both extend
the existing report detail
(`apps/mobile/lib/app/modules/report/presentation/page/report_detail_page.dart`),
between the position block and the detail-fields block. The feed tile
(`apps/mobile/lib/app/modules/report/presentation/page/nearby_feed_page.dart`,
`_FeedTile`) gained a read-only trailing label — the SECOND place
decision 204 requires the shared facet.

A new `direction_sighting` module
(`apps/mobile/lib/app/modules/direction_sighting/`) holds only the write
path and its local bookkeeping — domain + data, no routes of its own:

- `domain/entity/direction_sighting_entities.dart` —
  `DirectionSightingResult` (the write response: `sightingId`, `reportId`,
  `estimate`, `count`), `SightOutcome` (mirrors `SubmitOutcome`/
  `RateOutcome`: `.online(result)` / `.queued()`).
- `domain/repository/direction_sighting_repository.dart` —
  `logSighting({reportId, direction})`.
- `domain/usecase/log_sighting_usecase.dart` — thin wrapper, same
  precedent as `RateOfferUsecase`.
- `data/direction_sighting_repository_impl.dart` +
  `data/direction_sighting_queue_tasks.dart` — see "Data layer" below.
- `data/direction_sighting_local_store.dart` — see "Local bookkeeping"
  below.

### The shared `Direction` type

Both `ReportViewEntity`/`FeedItemEntity` (in the `report` module) and this
new module need the identical 8-value type. `packages/core` already hosts
`RiskTier` for the exact same reason (a value 2+ modules need, promoted
rather than one module importing another's entity file —
`docs/adr/ARCHITECTURE.md`'s "a module never imports another module") —
`Direction` (`packages/core/lib/src/geo/direction.dart`) follows the same
shape: a lowerCamelCase enum (`n, ne, e, se, s, sw, w, nw` — avoiding the
`constant_identifier_names` lint an uppercase `N, NE, ...` would trigger)
with a `wire` field carrying the API's actual string ('N', 'NE', ...),
plus a `DirectionJson` extension (`fromJson`/`toJson`) mirroring
`RiskTierJson`'s exact convention.

`packages/vgr_widgets`' `VgrCompass` deliberately does NOT import
`Direction` — see "Design system addition" below for why.

## Data layer

- `DirectionSightingRepositoryImpl.logSighting` — `POST
  /app-direction-sightings` with a FRESH app-generated `clientKey` per
  attempt (decision 137; this sighting's OWN idempotency key — unlike a
  report/offer clientKey, it never doubles as a bearer secret, since a
  sighting is append-only and never resolved/edited later). Online-first;
  a judged refusal (404/422 `DIRECTION_SIGHTING_NOT_ELIGIBLE`/422
  `BUSINESS_RULE`/451) is a `Left`, never enqueued; a transport failure
  enqueues **`direction_sighting_submit`** and answers
  `SightOutcome.queued()` (decision 28 — a sighting survives offline
  exactly like every other write in this app).

## Local bookkeeping — a soft, UX-level spam mitigation (NOT a security boundary)

`tb_direction_sighting` has no unique constraint on (account/device,
report) — only on the sighting's own `clientKey` (DS1's own documented
gap). Nothing stops the SAME device from submitting multiple different-
direction sightings for the same report. `DirectionSightingLocalStore`
(mirrors `PanicLocalStore`'s shape exactly: `SharedPreferences`-backed,
`_storageKey`/`_load`/`_persist`) is the app's own mitigation: once this
device has successfully logged a sighting for a report, it is remembered
locally and the picker is replaced by a read-only "you already pointed X
— thanks" state instead of being re-offered.

This is explicitly a UX nicety, never a real boundary — a reinstall or a
second device bypasses it entirely, same posture as
`PanicLocalStore.responderRequestSent`'s own documented caveat. There is
also NO server endpoint to read "did I already sight this report" or
"what did I pick" — this local record is the ONLY place that fact lives.

The record is written at the EARLIEST point the write is durably known —
online success OR the moment a transport failure gets enqueued
(`DirectionSightingRepositoryImpl`, both branches) — never only after an
eventual background flush. This matters: without it, revisiting the
report detail page while a sighting is still queued (not yet flushed)
would re-offer the picker and risk a second, different-direction
submission from the very same device before the first one even reached
the server. `DirectionSightingQueueTasks`'s own handler also writes the
record on a successful flush — a harmless, defensive duplicate for any
task that somehow reaches it without having gone through the repository
first.

## Presentation layer

- `ReportDetailBloc` gained `DetailSightPressed(direction)` over the SAME
  `DetailLoaded` state (extended with `sightedDirection`, `sighting`,
  `sightFeedback` — the exact same "submitting sub-state over a loaded
  view" idiom RT2 already used for `resolving`/`ratingOfferId`/
  `actionFailure`, not a new one-shot state class). `_load` reads
  `DirectionSightingLocalStore.sightingFor` alongside the server view so
  the page knows from the first frame whether to offer the picker or the
  read-only confirmation. A successful sighting (online OR queued) sets
  `sightedDirection` optimistically from the event itself — mirroring how
  RT2 patches a rated offer locally without waiting for a reload — and,
  for an online result only, `sightFeedback` carries the private
  `estimate`/`count` once. A judged failure surfaces via the same
  `actionFailure` field RT2 already uses for resolve/rate refusals; the
  picker stays offered (nothing was recorded). Guards mirror `_onRatePressed`
  exactly: ignored while already in flight (`sighting == true`), ignored
  once already sighted (`sightedDirection != null`), and a defensive,
  UX-only re-check that the viewer is not the report's own owner.
- `report_detail_page.dart`'s new block sits between the position row and
  the detail-fields section. It has two independent parts: the shared
  read-only estimate (`view.directionEstimate != null` → "Estimated
  direction: North", ALWAYS rendered when present, regardless of
  category/access/status — the server already decided when to include
  it) and, only when `view.access != ReportAccess.owner && view.status ==
  'open' && category ∈ {robbery, kidnapping, fugitive, missing}`, either
  the `VgrCompass` picker (not yet sighted) or the read-only "You pointed
  North — thanks!" confirmation (already sighted, this session or a
  previous one) plus, once, the private write-response feedback caption.
- `nearby_feed_page.dart`'s `_FeedTile` gained a `trailing` slot — a plain
  read-only `VgrText.caption` of the localized compass name, present only
  when `item.directionEstimate != null` — mirroring EXACTLY how the admin
  panel's report detail page added `trailing: _offerRating(offer)` to a
  `VgrListTile` for RT3's read-only rating display (same slot, same
  idea, a different read-only widget).

## Design system addition (133)

`VgrCompass` (`packages/vgr_widgets/lib/src/vgr_compass.dart`): a `Wrap`
of the 8 compass points as labeled chips, `value` (the selected/estimated
point, or null) and `onChanged` (nullable — null is the read-only/disabled
convention every Vgr* widget follows, mirroring `VgrRating` exactly). A
tap fires `onChanged` with the tapped code IMMEDIATELY — no confirm step,
since a sighting is a low-stakes, append-only contribution, not something
needing `showVgrConfirm` (same reasoning `VgrRating`'s star tap already
established). Each point is keyed `direction-<code>` (e.g. `direction-N`)
and carries its own `Semantics(button:, label: 'Direction <code>')` for
screen readers.

**Judgment call — `VgrCompass` uses plain wire strings ('N', 'NE', ...),
never the `Direction` enum.** `packages/vgr_widgets` depends on nothing
but `vgr_validators` today (no `packages/core`, no business logic — the
Style layer's own rule in `docs/adr/ARCHITECTURE.md`, and the package's
own pubspec comment: "the design system carries no format rule, it only
hands the enum to the formatter"). Giving `VgrCompass` a `Direction?`/
`ValueChanged<Direction>?` signature would open a NEW dependency edge
(`vgr_widgets → packages/core`) that does not exist anywhere else in this
design system, for a widget whose entire value space is 8 known short
codes — no different in spirit from `VgrRating`'s own plain `int` (1..5)
rather than some `StarRating` enum. The conversion between `Direction`
and its wire code happens at the one call site that already has both
`core` and `easy_localization` in scope (`report_detail_page.dart`, via
`DirectionJson.fromJson`/`.name`). `packages/vgr_widgets` stays exactly as
decoupled as it was before this front.

## Translations

`detail.directionEstimate`, `detail.directionPrompt`,
`detail.directionSighted`, `detail.directionFeedback`
(`apps/mobile/assets/translations/{en-US,pt-BR}.json`'s `detail` catalog);
a new top-level `compass` catalog (`compass.n` … `compass.nw`) for the 8
point labels, reused by both the detail page and the feed tile;
`core.errors.DIRECTION_SIGHTING_NOT_ELIGIBLE` (the one new error code DS1
adds — `BUSINESS_RULE`/`LEGAL_BLOCKED`/`NOT_FOUND`/`VALIDATION_FAILED`
already exist in the catalog and are reused as-is).

## Deliberately NOT here

- **DS3 (panel)** — empty by decision 201 (the hardcoded eligibility
  pattern needs no admin screen). Nothing in `apps/admin` changed.
- **A dedicated "log a sighting" screen** — the existing detail page
  already satisfies this with a small inline block, same precedent as
  RT2's "Encerrar denúncia"/rating control needing no new navigation.
- **Reading "did I already sight this report" from the server, or "what
  did I pick"** — no such endpoint exists (DS1's own documented gap); see
  "Local bookkeeping" above for the app's own soft substitute.
- **Any client-side reconciliation, weighting, or floor logic** — the app
  is a pure renderer of whatever the server decided.

## Tests

+2 `packages/core` (31 → 33): `Direction`'s wire round-trip, every value
both ways. +4 `vgr_widgets` (23 → 27):
`VgrCompass` key stability, read-only vs interactive, immediate one-tap
callback, all 8 points independently tappable. +47 mobile (344 → 391):
`ReportViewEntity`/`FeedItemEntity.directionEstimate` parsing (absence,
every one of the 8 points, equality, `copyWithOffers` carry-over);
`DirectionSightingResult`/`SightOutcome` parsing; `DirectionSightingLocalStore`
(save/read, independence per report, restart survival);
`DirectionSightingRepositoryImpl` (online success incl. the local-store
write, every judged refusal incl. nothing recorded locally, transport
queue incl. the local-store write at enqueue time, fresh clientKey per
attempt) and its `direction_sighting_submit` queue-task handler (replay,
5xx retry, judged-refusal drop, optional localStore); `ReportDetailBloc`'s
`DetailSightPressed` handling (local record loaded on `DetailStarted`,
online success with feedback, queued success without feedback, in-flight
guard, judged-failure surfacing, owner guard, already-sighted guard,
in-flight race guard); `ReportDetailPage` widget tests (shared estimate
rendered regardless of eligibility, absent when null, picker → tap →
read-only confirmation + feedback, already-sighted device skips straight
to read-only, owner never sees the picker, ineligible category never
shows it, resolved report never shows it); `NearbyFeedPage`'s feed-tile
trailing indicator (present/absent by `directionEstimate`). `apps/admin`
untouched (288/288 unchanged).
