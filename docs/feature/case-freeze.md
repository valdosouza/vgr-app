# Case freeze (P1) — apps/admin

The report front's ONE panel screen (decisions 141/142,
`AI/docs/decisions/VGR-plano.md`; plan phase P1 in
`AI/docs/plans/plano-denuncia.md`). API contract: `/api/case-freeze`
(`api/docs/feature/reports.md`). Full search/moderation/statistics are a
LATER front (142) — this screen deliberately does nothing but freeze.

## Reaching it

Migration 034 flips the `case_freeze` interface from kind 'R' (chosen in
032 when only the API side existed) to kind 'T', so it appears on the
dynamic menu under Operations for users holding VIEW — nothing else about
the row (grants included) changes. Route `/case-freeze` +
`interface_routes` entry, guarded by `AdminSessionGuard`.

## Flow (`CaseFreezePage`)

Look a case up by id; the screen then renders ONE of three actions,
decided strictly by the server state (the bloc re-fetches after every
mutation — the app never guesses a transition):

- **Not frozen** → freeze with a MANDATORY reason (141: "we cannot
  destroy evidence" — writ/case number). One human suffices. The API
  writes no timeline event, so the investigated is never tipped off.
- **Frozen, no pending request** → request unfreeze (step 1 of dual
  control, 141d), also with a mandatory reason.
- **Frozen, pending request** → approve unfreeze (step 2): shows who
  requested and why; the server enforces that the approver is a
  DIFFERENT user (a same-user attempt renders its 422 verbatim), and the
  retention clock RESTARTS on approval.

The reason field mirrors the API's 3-character minimum client-side;
UPDATE-gated buttons render disabled without the grant (decision 72:
UX-only — the API is the authority). Every action is audited server-side
(116).

## Tests

+14 (admin 93 total): repository (state mapping with pending unfreeze,
mandatory-reason body, both dual-control endpoints, failure surface),
bloc (lookup, lookup error, freeze-then-refetch, rejected action keeps
case, mutation-without-case no-op), page (freeze flow with empty-reason
block, step-1→step-2 render, same-user 422 verbatim, UPDATE-less
disabled buttons, 404 lookup). Suites: core 31, admin 93, mobile 79 —
all green.
