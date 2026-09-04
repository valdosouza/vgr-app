# Helper rating — RT2 (mobile) — apps/mobile

Mobile side of the helper-rating front (decision 48; round 13, decisions
178–189 in `AI/docs/decisions/VGR-plano.md`; plan
`AI/docs/plans/plano-rating.md` §4 RT2 row, §7). RT1 (API,
`api/docs/feature/rating.md`) is what this codes against — read it first,
it is the authoritative contract. RT3 (panel — the score per offer on the
case detail, decision 186) is NOT here. Uncommitted, awaiting review.

## What the app NEVER decides

- **Ratability (180/183/184).** `ratable` on an offer is computed
  server-side (resolved, not hidden, the helper has an account, not yet
  rated) — the app renders it as-is and never recomputes the rule. A
  `score` once present never changes from this app (183: no PUT/DELETE
  exists; immutable once given).
- **Reputation (184/185).** `GET /app-ratings/me` answers the caller's OWN
  `{count, average}` — `average` is null below the API's k-anonymity
  floor and the app never guesses at the floor value, it only renders
  null vs. a number. Nobody sees anyone else's reputation anywhere; there
  is no per-case reputation display, and no `/:id` variant to call even
  by mistake.
- **Closing (179).** No "outcome" field: a confirmation dialog
  (`showVgrConfirm`), then the resolve call. Existing help offers stay
  linked; the case timeline already shows the `resolved` event (A2).

## Where things live

No dedicated screens: both "Encerrar denúncia" and the rating control
extend the existing report detail (`apps/mobile/lib/app/modules/report/
presentation/page/report_detail_page.dart`), which already reloads on
`DetailStarted` and already lists offers — this satisfies decision 181's
"at closing, and later, any time until purge, never mandatory" without
new navigation. "My reputation" extends the existing account hub
(`apps/mobile/lib/app/modules/auth/presentation/page/account_page.dart`),
reachable only when signed in (the feed's account button already gates on
`IdentityBloc.state.token != null` — unchanged here).

A new `rating` module (`apps/mobile/lib/app/modules/rating/`) holds only
the write path and the reputation read — domain + data, no routes of its
own:

- `domain/entity/rating_entities.dart` — `RatingEntity` (the accepted
  write), `ReputationEntity` (`{count, average}`), `RateOutcome` (mirrors
  `SubmitOutcome` from `report_input.dart`: `.online(rating)` /
  `.queued()`).
- `domain/repository/rating_repository.dart` — `rateOffer(reportId,
  offerId, score)`, `getMyReputation()`.
- `data/rating_repository_impl.dart` + `data/rating_queue_tasks.dart` —
  see "Data layer" below.
- `domain/usecase/rate_offer_usecase.dart`,
  `get_my_reputation_usecase.dart` — thin wrappers (no dedicated test
  file, same precedent as `GetReportViewUsecase`).

`RatingRepository` is bound once in `app_module.dart` (like
`MyReportsStore`) because both the report module (rating an offer) and
the auth module (reading "my reputation") need it — a module-folder
convention this codebase already uses for `MyReportsStore` itself
(imported directly by the chat and help-offer modules).

The report module's own `OfferViewEntity` (`report_view_entity.dart`)
gained the `rating` facet (`OfferRatingEntity {score, ratable}`) parsed
in its own `fromJson`, and a `copyWithOffers` used to patch one row after
a rating settles — the `rating` module does not keep its own copy of that
entity.

## Data layer

- `ReportRepository.resolve(reportId)` — `POST /app-reports/:id/resolve`
  (no body). Same two-tier pattern as `submit`: online-first; an
  API-judged refusal (404 non-owner, 422 already resolved) is a `Left`
  and is **never** enqueued; a transport failure enqueues
  **`report_resolve`** and answers success-ish, same offline promise as a
  report submission (28).
  - **Judgment call**: the resolve endpoint's only business-rule refusal
    is "already resolved" (`api/src/modules/reports/reports.service.ts`).
    A queued resolve that runs after the SAME action already succeeded
    online (ack lost to a dropped connection) gets back that exact 422.
    `ReportQueueTasks._judgeResolve` treats it as `done` — the user's
    actual goal (the case IS resolved) is met either way — while every
    other refusal still drops without retrying forever.
- `RatingRepository.rateOffer` — `POST /app-reports/:reportId/offers/
  :offerId/rating` with a FRESH app-generated `clientKey` per attempt
  (never reused across attempts — a genuine retry after a real refusal is
  its own new attempt, decision 137). Online-first; a judged refusal
  (404/409 `ALREADY_RATED`/409 `RATING_CLOSED`/422 `RATING_NOT_ALLOWED`/
  451) is a `Left`, never enqueued; a transport failure enqueues
  **`rating_submit`** and answers `RateOutcome.queued()` — decision 181
  explicitly allows rating any time after resolution, including right
  when the device just came back online after closing an offline-queued
  resolve.
- `RatingRepository.getMyReputation` — `GET /app-ratings/me`, read-only,
  no offline queue (a stale cached aggregate would be actively
  misleading); a transport failure is `OFFLINE`, surfaced but never
  retried in the background.

## Presentation layer

- `ReportDetailBloc` gained `DetailResolvePressed` and
  `DetailRatePressed(offerId, score)` over the SAME `DetailLoaded` state
  (extended with `resolving`, `ratingOfferId`, `actionFailure` — the
  "submitting sub-state over a loaded view" idiom this codebase already
  uses in `ChatConversationBloc`/`HelpOfferBloc`, not a new one-shot
  state class). A successful/effectively-successful resolve reloads the
  whole view (fresh `status`, fresh per-offer `rating` facets). A rate
  attempt patches ONLY the affected offer locally via `copyWithOffers` —
  no reload needed: an online accept already carries the exact score, and
  an offline queue result is patched optimistically with the submitted
  score (confirmed for real on the next full reload). Either way the
  offer becomes non-`ratable` immediately so a second tap cannot race the
  first (183).
- `report_detail_page.dart`: the close button
  (`detail-resolve-button`) shows only for
  `access == owner && status == 'open'`, confirms via `showVgrConfirm`
  BEFORE dispatching. Each offer row's `trailing` slot carries the
  rating control ONLY on a resolved owner view AND only when the server
  sent a `rating` facet: interactive stars when `ratable`, read-only
  stars when a `score` already exists, nothing when neither (the helper
  had no account, 180).
- `AccountBloc` gained `AccountStarted` (dispatched once from the page's
  `initState`, same idiom as every other Started event here) which loads
  `{count, average}` best-effort (123 — an entirely optional section: a
  failed read just shows nothing, never blocks sign-out).
  `account_page.dart` renders count always, the average when present, or
  `auth.account.reputationNotEnough` when it is null — never recomputing
  the k = 5 floor itself.
- `help_offer_form_page.dart`'s anonymous-helper card gained a sibling
  caption (`offer-anonymous-no-rating-notice`,
  `offer.anonymousNoRatingNotice`) next to the existing no-chat one (169):
  without an account there is no identity to accumulate a reputation on
  either (180). Said BEFORE the offer, never blocking it — same pattern
  as 34/169.

## Design system addition (133)

`VgrRating` (`packages/vgr_widgets/lib/src/vgr_rating.dart`): a row of
`starCount` (default 5) stars, `value` (1..5 or null) and `onChanged`
(nullable — null is the read-only/disabled convention every Vgr* widget
follows). Each star is keyed `rating-star-<i>` and carries its own
`Semantics(button:, label: 'Rate i stars')` for screen readers. Two new
`VgrIconName` values (`starFilled`, `starOutline`) keep icon choice inside
the design system's "named by meaning" rule rather than a raw
`Icons.star` reference. `GestureDetector`/`Icon`/`Row`/`Semantics` are
used raw ONLY inside this file — exempt, `vgr_widgets` is where
encapsulating raw widgets is the job; the guard scans `apps/*/lib` and
`packages/core/lib`, not this package.

## Deliberately NOT here

- RT3 (panel: the score per offer on the report-moderation case detail,
  decision 186) — separate front, `apps/admin`. DONE: `ReportOfferEntity.
  ratingScore` (`apps/admin/lib/app/modules/reports/domain/entity/
  report_entities.dart`) parsed from the SAME `GET /api/reports/:id` the
  rest of the case detail already used, rendered read-only via `VgrRating`
  in the offer row's `trailing` slot
  (`apps/admin/lib/app/modules/reports/presentation/page/
  report_detail_page.dart`, `_offerRating`). No aggregate-by-helper
  screen, matching the decision. Details: `api/docs/feature/
  report-moderation.md`.
- Per-case reputation for anyone, editing/removing a given rating, a
  reporter-rates-helper "outcome" field: none of these exist anywhere —
  registered as visions in the plan, not built (per RT1's own doc).
- A dedicated "rate this offer" screen: the existing detail page already
  satisfies "at closing, and later, never mandatory" (181) by extending
  its own offers list; a separate screen was considered and rejected as
  unnecessary navigation for a single star-tap action.

## Tests

+4 `vgr_widgets` (19 → 23): `VgrRating` read-only vs interactive, filled/
outline painting by `value`, key stability.
+67 mobile (195 → 262): `OfferRatingEntity`/`ReportViewEntity.rating`
parsing + `copyWithOffers`; `ReportRepositoryImpl.resolve` (online, no
stored key, judged refusal, transport queue) and its
`report_resolve` queue-task handler (done, 5xx retry, 422-as-done,
genuine-refusal drop); `RatingEntity`/`ReputationEntity`/`RateOutcome`
parsing; `RatingRepositoryImpl` (`rateOffer` paths incl. every judged
code, transport queue, fresh clientKey per attempt; `getMyReputation`
incl. 401/offline) and its `rating_submit` queue-task handler;
`ReportDetailBloc`'s resolve/rate event handling (reload, in-flight
flags, judgment-call 422, local patch on rate, ignored-when-not-ratable,
ignored-while-in-flight); `ReportDetailPage` widget tests for the close
button (confirm/cancel, owner/non-owner, open/resolved gating) and the
rating control (interactive tap dispatches, read-only never dispatches,
absent when not ratable and unrated, absent on an open case);
`AccountBloc`/`AccountPage` reputation rendering (count+average, below
the floor, failed read); the widened anonymous-helper notice on the
offer form. `packages/core` untouched (31/31 unchanged).
