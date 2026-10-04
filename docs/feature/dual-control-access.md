# Dual Control Access (admin)

## OVERVIEW
The panel side of the decision 45 gate: access to decrypt an `AccountabilityLogEntry` needs a documented legal basis and **two distinct people** — the one who opens the request (its first authorization) and ONE approver who is a different user (decision 224). Both come from the session; the screen never asks who you are (223).

Since round 18 / DC2 (decisions 223–229, `AI/docs/plans/plano-dual-control.md`, 2026-10-04) the screen is a register in the design of the Legal Gate rules (227): the requests paged newest first, a request form, and "Approve" on the row. It replaced the phase-1 single-request flow whose approver was a typed id — which let one admin approve twice and grant alone.

Revealing (decrypting) a granted entry is not built: decision 228 keeps it for its own round, after the legal review decision 45 asks for.

## STRUCTURE
```
apps/admin/lib/app/modules/dual-control-access/
├── domain/entity/dual_control_request_entity.dart   # DualControlRequestEntity (status, requester/approver ids + NAMES), DualControlRequestDraft
├── domain/repository/dual_control_access_repository.dart  # list(PagedQuery), request(draft), approve(id) — no approver argument anywhere
├── data/dual_control_access_repository_impl.dart     # GET ?page..., POST /, POST /:id/approvals with an EMPTY body
├── presentation/bloc/dual_control_bloc.dart         # DualControlBloc extends RegisterBloc; DualControlApproved through act()
├── presentation/page/dual_control_access_page.dart  # RegisterScreen(openRows: false)
└── dual_control_access_module.dart                  # mounted at /dual-control-access/
```

## BEHAVIOR
- **List** (decision 220): paged, newest first, filter on the legal basis. Each row: `Request #id · log entry #n`, status (`Awaiting approval` / `Granted` / `Voided`), the legal basis, "Requested by {name} on {when}" and, once granted, "Approved by {name} on {when}". People by NAME, never e-mail (227); a blank name or a voided request with no requester reads as a dash.
- **New request** (INSERT): the factory form with two fields mirroring `dualControlCreateDto` — log entry id (`VgrValidators.positiveInteger`, the field keeps digits only) and legal basis (required, at most 500). No approver field. The API answers 404 when the log entry does not exist; it arrives on the bridge.
- **Approve** (only on a pending row): needs the screen's UPDATE AND the `dual_control_approval` resource (45/93), and is **disabled on the request you opened**, with "You opened this request — another person must approve it." The session user is `sessionUserIdOf(ApiClient.token)` (core `jwt_utils.dart`) — the `userId` claim of the very token the API judges on, read when the route builds. UX only: when it is unknown the button stays enabled and the API refuses the requester (422).
- **Outcomes** through the bridge (decision 221): an approval shows "Request approved — access granted." and the list reloads with the server's answer; a refusal — self-approval 422, not pending 409 (granted, voided, or lost to a simultaneous approval) — is a transient message and the list stays.
- Rows never open: a request is never edited or deleted (it is the record of who asked for what, 45(c)).

## TESTS
`test/app/modules/dual-control-access/` — repository (exact paged query, empty approval body, Left on refusal), bloc (open = factory save, approve signalled and reloaded, refusal keeps the list), page (names and statuses, Approve disabled on your own request and without the approver resource, form pendency and the draft sent, no "new" without INSERT, refusal through the bridge). `sessionUserIdOf` is covered in `packages/core/test/identity/jwt_utils_test.dart`, `positiveInteger` in `vgr_validators`.

## HISTORY
- Task 06 (phase 1): single-request flow with a typed approver id — built when the panel had no session.
- PS3 (2026-10-04): refusals moved to the bridge; the flow stopped dropping a request in progress.
- PS4 (2026-10-04): found that a typed approver let one admin grant alone — round 18 (223–229).
- DC1 (api `ea3184f`): requester/approver from the session, one approval by another user, DB CHECK, audit, paged list with names.
- DC2 (this screen): list + request form + approve on the row.

## REFERENCES
- [**README.md**](../README.md): Documentation navigation index.
- [**admin-panel.md**](./admin-panel.md): the panel inventory.
- [**ADMIN-SCREENS.md**](../adr/ADMIN-SCREENS.md): the factory this screen is built on.
- API-side counterpart: `api/docs/feature/dual-control-access.md`.
