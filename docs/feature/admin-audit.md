# Admin audit trail (panel) — apps/admin

Phase B5 of front 142 (decisions 116, 158, 165, 166 in
`AI/docs/decisions/VGR-plano.md`; plan `AI/docs/plans/plano-moderacao-painel.md`).
API contract: `api/docs/feature/admin-audit.md` (`GET /api/admin-audit`, `/:id`,
`/facets`). Server-side write path: `api/src/shared/audit/admin-audit.ts`.

## OVERVIEW
`tb_admin_audit` has collected who-did-what on the panel since phase S4 (116);
until B5 nothing served it. Decision 166 started auditing case-detail reads,
and "auditing without a way to read is half of 116" (158) — this screen is
that other half. It is READ only: the panel has no write, and the API has no
write route to call.

Reaching it: interface `admin_audit` (kind 'T', Administration, VIEW only,
migration 042, bootstrap to de-facto admins — 165) shows on the dynamic menu
for VIEW holders; route `/admin-audit` + `interface_routes` entry; both
routes guarded by `AdminSessionGuard`.

## INVARIANTS THE SCREENS HONOUR

| Invariant | Where |
|---|---|
| Append-only (116): this phase adds READ only | `AdminAuditRepository` has `list`, `get`, `facets` and nothing else; no bloc event mutates anything |
| Reading the trail is NOT audited (166) | Server-side; the list hint says so. No "this read was recorded" note anywhere |
| `summary` served as stored, already secret-redacted (110); rendered as text / key-value tree, never executed | `AuditListItemEntity.summary` is `Object?` kept exactly as parsed by the API; the list prints `summaryPreview()` (compact JSON or collapsed text, cut at 80 chars); the detail prints a `VgrListTile` per top-level key with nested values pretty-printed (`JsonEncoder.withIndent`), or the string as-is |
| Operator `ip` is personal data: detail only, never the list | `AuditListItemEntity` has NO `ip` field (a payload carrying one cannot land anywhere — repository test); `AuditEntryEntity extends AuditListItemEntity` adds it; the detail shows it under a caption saying it is personal data visible only under this grant |
| No cross-plane leak: actors are panel users (`tb_user`), never app accounts | `actorName` comes from the API's LEFT JOIN on `tb_user`; `null` (deleted user) renders "Unknown user (#id)" — the row and the id never disappear |
| No raw Flutter widget (133); dates via `VgrValidators.isoDate` (157) | Guard green; from/to validated before the round trip, everything else is the API's 422 by field code (83) rendered via `failureText` |

## STRUCTURE
```
modules/admin-audit/
├── admin_audit_module.dart                  # binds repository + 2 blocs; '/' list, '/:id' detail
├── data/admin_audit_repository_impl.dart    # GET /api/admin-audit (Uri-built query), /:id, /facets
├── domain/entity/admin_audit_entities.dart  # Filters (toQueryParameters), ListItem (summaryPreview), Entry (+ip), Page (pageCount), Facets (empty)
├── domain/repository/admin_audit_repository.dart
└── presentation/
    ├── bloc/admin_audit_list_*    # Started → facets + page 1; Search → page 1; PageRequested under the same filters
    ├── bloc/admin_audit_detail_*  # Requested(id) → Loading → Loaded | Error
    └── page/admin_audit_list_page.dart, admin_audit_detail_page.dart
```

## LIST (`AdminAuditListPage`)
- Loads facets and the first page on entry (`AdminAuditListStarted`, both reads in flight
  together). A facets refusal leaves the dropdowns with only "Any" — the list still renders.
- Filter bar: actor id (`VgrTextField`, number), action (`VgrDropdownField` from
  `facets.actions`, catalog labels `adminAudit.action.*` with raw fallback), entity
  (`VgrDropdownField` from `facets.entities`, raw code names), entity id (`VgrTextField`),
  from/to (`YYYY-MM-DD`, `isoDate`), Apply. A selected value the facets no longer offer falls
  back to "Any" instead of crashing the dropdown.
- Rows (`VgrListTile`, `audit-row-{id}`): `when · actorName (#actorId) · action label`;
  subtitle `entity#entityId · summary preview`. Eye icon on `read` rows, pencil otherwise.
  Tap → `Modular.to.pushNamed('/admin-audit/$id')`.
- Prev/next with "Page X of Y" (`pageCount`, page size 50 = the API default); empty state
  `audit-empty`; refusal `audit-list-error` via `failureText`.

## DETAIL (`AdminAuditDetailPage`)
- "Back" `VgrTextButton` in the `VgrScaffold` actions (`audit-back`): pops when pushed from
  the list, navigates to `/admin-audit/` on a deep link.
- Sections: **Who · what · when** (when, actor, action, entity#entityId — `VgrSelectableText`
  values so an operator can copy an id), **Summary** (key/value list for a JSON object,
  nested values as indented monospace text; plain text otherwise; "No summary recorded."
  when null), **Operator IP** (value or "—", plus the personal-data caption `audit-ip-caption`).
- 404 → `audit-detail-error`, "Record not found.".

## TRANSLATIONS
`menu.interfaces.admin_audit` and the `adminAudit.*` block (title, hint, filters, action
labels, columns, row/actor formats, empty, pagination, detail sections, ip caption) in
`en-US.json` and `pt-BR.json`. Inserted by text — both catalogs carry a duplicate top-level
`legal` key, so they must never be round-tripped through a JSON parser.

## TESTS
+39 admin (232 → 271): entities (`toQueryParameters` omits unset / emits every name;
`summaryPreview` object / truncation / null; `pageCount`); repository (page+pageSize only,
every filter under the contract name, mapping incl. `actorName` null and summary object /
string / null, the list entity cannot hold an `ip`, 422 as `Left`; `get` with ip / null ip /
404; `facets` mapping / refusal); list bloc (idle, Started → facets + page 1, facets refusal
→ empty facets + list served, Search keeps facets, PageRequested under current filters,
PageRequested before load is a no-op, list refusal keeps filters + facets); detail bloc
(idle, loading → loaded, 404); list page (entry load + rows + no "IP" text, facets fill both
dropdowns and Apply sends every filter, malformed date blocked locally, pagination, empty,
403 by code, row tap → real detail page through a `ModularApp` and Back → list); detail
page (object summary as key/value + nested indented text, string summary, null summary,
ip + caption + unknown actor, null ip as dash, 404). Guard 133 green.

## REFERENCES
- [**README.md**](../README.md): Documentation navigation index.
- [**admin-panel.md**](./admin-panel.md): panel structure and the dynamic menu this screen enters through.
- [**report-moderation.md**](./report-moderation.md): the front (B1–B4) whose audited reads this screen makes visible.
