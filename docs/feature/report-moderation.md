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

## B2 — moderation (`modules/reports`, decisions 162/163/165/167)

Same module, same routes, no new interface: moderating is the `reports`
UPDATE grant (165). API contract: `api/docs/feature/report-moderation.md`
§B2 (`POST /api/reports/:id/hide|unhide`, `POST /api/media/:publicId/block|unblock`).

### Invariants the screens honour

| Invariant | Where |
|---|---|
| One human + a catalog reason + one audit row, reverting included — no dual control (162) | Every act (hide, unhide, block, unblock) opens the ONE `ModerationReasonForm`; the bloc posts and re-fetches; the server audits |
| Reason catalog fixed in code (163): `spam · abuse · illegal_content · duplicate · personal_data · other`; note REQUIRED (3–500) only when `other` | `domain/entity/moderation_reason.dart` mirrors `api/src/shared/moderation/moderation-reason.ts`; the form builds its `VgrValidators` list conditionally: `required` on the code, `minLength(3)` on the note ONLY when `other`, `maxLength(500)` always (new validator in `vgr_validators`, mirrors `z.string().max(500)`) |
| Moderation never touches retention (162) | Nothing on the screen mentions expiry; the freeze block is untouched and `hidden`/`frozen` render independently |
| Hidden: gone from feed/public reads; owner and participants see a mark, never the reason (167) | Panel shows reason, note, `hiddenAt`, `hiddenBy`; the mobile owner view shows a `VgrText` notice only (see below) |
| Blocked media stays readable on the panel (M3) | The detail keeps listing blocked media with status, reason, note, "blocked since" |
| Buttons follow the grant, the API enforces (72) | Hide/Unhide/Block/Unblock render disabled without `can('reports', UPDATE)` |
| No raw Flutter widget (133); validation via `vgr_validators` (157) | Guard green; the form is `VgrDropdownField` + `VgrTextField` + `VgrPrimaryButton`/`VgrTextButton` |

### What changed

- Entities: `ReportListItemEntity.hidden`, `ReportFiltersEntity.hidden` (→ `hidden=true|false`),
  `ReportPanelDetailEntity.hidden/hiddenReasonCode/hiddenNote/hiddenAt/hiddenBy`,
  `ReportMediaEntity.blockedReasonCode/blockedNote/blockedAt`. Every new field tolerates
  absence (`false`/`null`) — the API is built from the same contract in parallel.
- Repository: `hide`, `unhide`, `blockMedia`, `unblockMedia` — body `{reasonCode, note?}`,
  the note omitted when blank. All answer `void`; the bloc re-fetches (server = authority).
- Bloc: four events through the same `_mutate` as the freeze actions (busy → post → refetch;
  a refusal keeps the case with `failure`).
- Detail page: new **Moderation** section (visible → "Hide report"; hidden → badge + reason
  label + note + "Hidden since … · By user N" + "Unhide"); each media row gets Block/Unblock
  by status (`available`/`blocked` only; nothing on a purged skeleton), with the form rendered
  right under that row. The last action's refusal renders once (`report-action-error`) above
  the Moderation section, shared with the freeze block.
- List page: `hidden` tri-state filter (`reports-filter-hidden`) and a `HIDDEN` mark on rows.
- `presentation/widget/moderation_reason_form.dart`: the reusable form (Components layer only —
  no bloc, no repository; the page maps `onSubmit` to the event).
- Translations `reports.moderation.*` and `reports.list.hidden/hiddenMark` (en-US, pt-BR);
  `menu.interfaces` untouched.

### Mobile — the owner's mark (167)

`ReportViewEntity.hidden` (bool, `false` when absent). `ReportDetailPage` shows, for
`owner`/`participant` only, `detail.hiddenNotice` ("This report is hidden from the public
feed by moderation.") — no reason, no action. Third parties never receive a hidden case
(the API answers 404), so the page has no branch for them.

### Tests

+15 admin (166 → 181): repository (four paths + bodies, note omitted, 409 as `Left`,
`hidden` on list/filter, detail `hidden*`/`blocked*` mapping); bloc (hide → refetch, unhide
409 keeps the case, block/unblock refetch); detail page (`other` without note blocked
locally, missing reason blocked, hide → `hide(7,'spam',null)`, unhide with note, blocked row
shows Unblock + reason + date, available row shows Block → `blockMedia`, cancel, all buttons
disabled without UPDATE, 409 rendered by code); list page (hidden filter → entity, `HIDDEN`
mark). +2 `vgr_validators` (`maxLength`). +4 mobile (140 → 144): entity default/flag, owner
sees the notice, visible case shows none. Guard 133 green in both apps.
