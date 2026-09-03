# Nearby feed + report detail (A2) — apps/mobile

Second phase of the Report front in the app (A1 = `report-form.md`).
Decisions 2/21/50/128/134/135 (`AI/docs/decisions/VGR-plano.md`); plan
phase A2 in `AI/docs/plans/plano-denuncia.md`; spec tasks 07/08/22. API
contracts in `api/docs/feature/help-matching.md` + `reports.md`.

## Feed (`NearbyFeedPage` — now the app's home)

`GET /app-feed` — anonymous by design (success criterion 2). The route
moved: the feed is `/`, the form is `/new` behind a floating "Report"
button — submitting stays one tap away (decision 123). The viewer
position is read per (re)start through the same `LocationGateway` port
and used transiently; it is never stored (110).

Everything rendered arrives DEGRADED by tier (135): grid position,
snapped distance ("~1.5 km"), bucketed timestamp. The app adds nothing —
`FeedItemEntity` has no sharper field to leak. States Loading / Loaded /
Empty / Error render distinctly (spec 1.4); pagination is a page-control
button (allowed by decision 21) that appends WITHOUT duplicating (the
feed moves under pagination — dedupe by reportId, spec task 07
acceptance); a failed next page keeps current items and stays retryable.
Ordering recency|relevance reloads from page 1.

## Detail (`ReportDetailPage` — spec task 22, decision 50)

`GET /app-reports/:id`. The SERVER resolves `access`; the page renders
strictly by it and never tries to show more than it received:

- `summary` (resolved, non-participant): closure status only — no
  timeline, no details, no offers (the spec's restricted-view scenario).
- `public` (open): taxonomy, degraded position labeled "approximate",
  detail fields, media publicIds.
- `owner`/`participant`: exact position, timeline (created/edited/
  resolved/media_attached/help_offered), media with dimensions; the owner
  additionally gets the offers list masked by tier (identity only when
  the helper chose it AND tier ≠ high; timestamps never on high — 40/41/60).
- `hidden` (B2, decision 167): when panel moderation hid the case, owner/participant
  views carry `hidden: true` and the page shows a `VgrText` notice
  (`detail.hiddenNotice`) — no reason, no action; third parties get a 404.

### Media streaming

`VgrNetworkImage` (new, design system) streams
`GET /app-reports/:id/media/:publicId/:variant` with the `x-client-key`
header when this device owns the report. The variant is chosen by
`ReportViewEntity.thumbVariant`: third parties on high tier request ONLY
`blur` (128 — asking for `thumb` would 404); owner/participant get
`thumb`.

## Ownership (`MyReportsStore` — decision 134)

New local map reportId → clientKey, saved on EVERY successful submit
(inline and offline-queue paths). Presenting the key in `x-client-key`
is what makes this device the owner on reads — it never travels anywhere
else. This closes the loop A1 left open: a queued report submitted hours
later is still "yours" when it shows up in the feed.

## Tests

+23 (mobile 60 total): repository feed query/ownership header/no-key
paths, feed bloc (loading/empty/error-retry/append-dedupe/failed-page/
order-reload), detail bloc (view/clientKey/error + blur-variant rule),
feed page (states, load-more, item tap, FAB), detail page (summary-only
scenario, degraded public view, owner timeline+masked offers, error).
Suites: core 31, admin 79, mobile 60 — all green.
