# Legal Gate admin screens (L3) — apps/admin

Phase L3 of the Legal Gate plan (`AI/docs/plans/plano-legal-gate.md`,
decisions 76-79/103-109). API contract: `/api/legal-policy`
(`api/docs/feature/legal-gate.md`). The assessments screen belongs to L2
(AI pipeline) — not built yet, deliberately absent here.

## Module (`app/modules/legal-policy`, mounted at `/legal`)

One screen per tb_interface of migration 022, each on the dynamic menu
under Legal for users holding VIEW. Since PS3 (2026-10-04, plano
`painel-modelo-setes` §8) every list is PAGED and filtered by text
(decision 220 — the API's `pagedQueryDto`), and every refusal reaches the
operator through the feedback bridge (decision 221) with the list kept.

- **Jurisdictions** (`/legal/jurisdictions`, `legal_jurisdictions`) —
  the kill-switch screen (107), a workflow list (`PagedListBloc` +
  `PagedListScreen`), filter on code / name. Per row, the operational
  state as an inline dropdown. "Shut down fast, turn back on slowly":
  tightening applies immediately; loosening comes back as a pending state
  rendered with who proposed it, and the confirm button is gated by the
  layered guards (screen UPDATE **and** `dual_control_approval`) — the
  distinct-user rule stays the server's judgment.
- **Capabilities** (`/legal/capabilities`, `legal_capabilities`) — the
  catalog verdict for ONE jurisdiction (103), typed in the header
  (uppercased); nothing is fetched before one is chosen (the empty state
  says so), choosing one restarts at page 1; filter on capability /
  description. `unreviewed` is labeled as the block it is in production
  (fail-closed, principle L1); the active rule's version and review state
  ride the subtitle.
- **Rules** (`/legal/rules`, `legal_rules`) — the register factory with a
  PROPOSAL-only form ("new", by INSERT): capability (3..80), jurisdiction
  (2..10, sent uppercased), status, a typified reason that appears ONLY
  for a non-allowed status and is then required with no preselected value
  (decision 78), legal basis (≤ 4000); expiry defaults to the DTO's 180
  days. Rows never open — a rule is versioned, a change is a new proposal
  (107). The paged history is filtered by text (capability / jurisdiction
  code / legal basis — the API's text filter replaced the two exact
  filters of L3). Proposed rows carry approve (layered guards) and reject
  (UPDATE); a same-user approval is refused by the API and shown through
  the bridge.

Every row action reloads the page from the server (`act()`, a quiet
reload) — states (`proposed`/`active`/`superseded`, pending loosening) are
never assembled client-side.

## Tests

+15 (admin 108 total): repository (pending state mapping, kill-switch
body, per-jurisdiction catalog, proposal body with reason/expiry,
approve refusal), blocs (state change reloads list, refused confirm
keeps list+failure, catalog load, propose reloads under filter,
same-user approval keeps list), pages (pending render + confirm flow,
confirm disabled without `dual_control_approval`, unreviewed label +
uppercased jurisdiction, propose flow with conditional reason field,
same-user refusal). Suites: core 31, admin 108, mobile 79 — all green.

PS3 (2026-10-04) rewrote the three screens on the factory: repository /
bloc / page tests in `test/app/modules/legal-policy/` (paged contracts,
reload on action, refusal through the bridge, no fetch before a
jurisdiction, reason required, closed rows).
