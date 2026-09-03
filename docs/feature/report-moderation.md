# Report moderation (panel) — apps/admin

Front 142, round 11 (decisions 158–167 in `AI/docs/decisions/VGR-plano.md`;
plan `AI/docs/plans/plano-moderacao-painel.md`). Five phases, B1 → B2 → B4 →
B3 → B5 (158). API contract: `api/docs/feature/report-moderation.md`.

## B1 — search + detail (`modules/reports`)

Reaching it: interface `reports` (kind 'T', Operations, migration 038)
shows on the dynamic menu for VIEW holders; route `/reports` +
`interface_routes` entry; both routes guarded by `AdminSessionGuard`.
The panel plane is `/api/reports`; the app feed at `/app-help-matching`
is untouched.

### Invariants the screens honour

| Invariant | Where |
|---|---|
| Position DEGRADED by default; exact only via `report_exact_position` grant, audited (159/135) | `ReportDetailPage._position`: renders the grid point + precision note; "Reveal exact position" exists only when `SessionAccess.can('report_exact_position', VIEW)`; the reveal is a separate repository call (`GET /api/reports/:id/position`) and the note says the read was audited |
| Anonymous reporter: no identity; identified: opaque id + displayName, never e-mail (160) | `ReportActorEntity` is the ONLY identity shape; `reporter == null` → "Anonymous". Same for helpers in offers |
| Detail read audited, list not (166) | Server-side. The list hint says so; the list bloc fetches nothing until Search |
| Freeze stays on `/api/case-freeze` (141/165) | `ReportsRepositoryImpl` duplicates the four one-line calls of `case_freeze_repository_impl.dart` (modules never import each other); the detail EMBEDS P1's three states, buttons gated by `case_freeze` UPDATE |
| No raw Flutter widget (133); format validation via `vgr_validators` (157) | Guard test green; `VgrValidators.isoDate` (from/to) and `VgrValidators.minLength(3)` (freeze reason) added to the package with tests |

### Structure

```
modules/reports/
├── reports_module.dart                 # binds repository + 2 blocs; '/' list, '/:id' detail
├── data/reports_repository_impl.dart   # /api/reports (Uri-built query), /api/reports/:id, /:id/position, /api/case-freeze/*
├── domain/entity/report_entities.dart  # Filters, ListItem, Page, PanelDetail (+Actor/Position/Media/Offer/TimelineEvent), ExactPosition, FreezeState
├── domain/entity/report_taxonomy.dart  # CATEGORIES/SUBJECTS/tiers/statuses key lists (copy of the API seed, source named)
├── domain/repository/reports_repository.dart
└── presentation/
    ├── bloc/reports_list_*   # filters → page 1; prev/next under the same filters
    ├── bloc/report_detail_*  # detail + freeze state; freeze actions re-fetch BOTH; exact-position reveal
    └── page/reports_list_page.dart, report_detail_page.dart
```

### List (`ReportsListPage`)

Filter bar: id, status, category, subject, tier (`VgrDropdownField`, "Any"
sentinel omits the parameter), frozen / with-media (tri-state dropdown),
from/to (`YYYY-MM-DD`, validated by `VgrValidators.isoDate` before the
round trip). Rows: `#id · taxonomy · subject` with tier · status · media
count · createdAt and FROZEN / PURGED / Anonymous marks; empty state;
prev/next with "Page X of Y" (`ReportPageEntity.pageCount`). Tap →
`Modular.to.pushNamed('/reports/$id')`. Server refusals (403, 422 by field
code) render through `failureText` (80/83).

`VgrDropdownField` gained `isExpanded: true` (design-system change, with a
test): the natural width of a dropdown is its widest option, which
overflowed inside the fixed-width filter slots.

### Detail (`ReportDetailPage`)

Sections: header (taxonomy, tier, status, created/resolved/expires, PURGED
marker), reporter, position (+ reveal), detail fields (key: value),
timeline, media, help offers, Retention/freeze (P1's three states: not
frozen → freeze with reason; frozen → request unfreeze; pending → approve;
disabled without `case_freeze` UPDATE). When `/api/case-freeze` refuses
(no `case_freeze` VIEW at all) the detail still renders and the section
says the state is unavailable.

**Media are listed, not shown.** The panel has no authenticated image
widget: `/api/media/:publicId/:variant` needs the panel JWT in the
`Authorization` header, and Flutter web's `Image.network` cannot send
headers (the mobile app uses `x-client-key`, a different plane). The
detail therefore lists `publicId · mime · WxH · status` per attachment;
rendering thumbnails is a follow-up that needs either a token-in-query
variant of the media route or a blob-fetching widget in `vgr_widgets`.

### Tests

+40 (admin 126 → 166), +6 `vgr_validators` (34 → 40), +1 `vgr_widgets`
(10 → 11). Repository (query string per filter, list/detail mapping incl.
anonymous → null and purged skeleton, exact position, the four freeze
calls), both blocs (search/page/no-op/error; load, freeze refetch,
rejected action keeps case, reveal, reveal refused, no-op), both pages
(no fetch before search, filters → call, empty, pagination, date
validation, error, navigation to `/reports/:id` through a ModularApp;
anonymous vs identified rendering, reveal hidden without grant, freeze
flow with `TOO_SHORT`, same-user 422, UPDATE-less disabled, freeze state
refused, purged skeleton, 404). Guard 133 green.
