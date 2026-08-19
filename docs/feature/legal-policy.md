# Legal Gate admin screens (L3) — apps/admin

Phase L3 of the Legal Gate plan (`AI/docs/plans/plano-legal-gate.md`,
decisions 76-79/103-109). API contract: `/api/legal-policy`
(`api/docs/feature/legal-gate.md`). The assessments screen belongs to L2
(AI pipeline) — not built yet, deliberately absent here.

## Module (`app/modules/legal-policy`, mounted at `/legal`)

One screen per tb_interface of migration 022, each on the dynamic menu
under Legal for users holding VIEW:

- **Jurisdictions** (`/legal/jurisdictions`, `legal_jurisdictions`) —
  the kill-switch screen (107): per row, the operational state as an
  inline dropdown. "Shut down fast, turn back on slowly": tightening
  applies immediately; loosening comes back as a pending state rendered
  with who proposed it, and the confirm button is gated by the layered
  guards (screen UPDATE **and** `dual_control_approval`) — the
  distinct-user rule stays the server's judgment.
- **Capabilities** (`/legal/capabilities`, `legal_capabilities`) — the
  catalog verdict for ONE jurisdiction (103): enter the code, see each
  capability's effective status. `unreviewed` is labeled as the block it
  is in production (fail-closed, principle L1); the active rule's
  version and review state ride the subtitle.
- **Rules** (`/legal/rules`, `legal_rules`) — proposal form (status
  dropdown; the typified-reason dropdown appears ONLY when not allowed,
  decision 78; expiry defaults to the DTO's 180 days), filterable
  version history (capability × jurisdiction — the "what applied on day
  X" answer of plan §6), and approve/reject on proposed rows. Approve
  needs the layered guards; a same-user approval renders the API's 422
  verbatim.

Every bloc reloads its list from the server after any mutation — states
(`proposed`/`active`/`superseded`, pending loosening) are never
assembled client-side.

## Tests

+15 (admin 108 total): repository (pending state mapping, kill-switch
body, per-jurisdiction catalog, proposal body with reason/expiry,
approve refusal), blocs (state change reloads list, refused confirm
keeps list+failure, catalog load, propose reloads under filter,
same-user approval keeps list), pages (pending render + confirm flow,
confirm disabled without `dual_control_approval`, unreviewed label +
uppercased jurisdiction, propose flow with conditional reason field,
same-user refusal). Suites: core 31, admin 108, mobile 79 — all green.
