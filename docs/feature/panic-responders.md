# Panic Responders (admin)

## OVERVIEW
Admin approval queue for `ResponderPoolMembership` requests (decisions 51-52): any authenticated user can request Authorized Responder status via the API; only an admin can approve or deny it here. Built on the register factory's list half (`app/shared/register/`).

## STRUCTURE
```
apps/admin/lib/app/modules/panic-responders/
├── domain/entity/responder_approval_entity.dart   # id, userId, status (pending/approved/denied), criteriaNotes
├── domain/repository/responder_approval_repository.dart
├── data/responder_approval_repository_impl.dart
├── presentation/bloc/                             # ResponderApprovalBloc (PagedListBloc) — ResolveRequested
├── presentation/page/responder_approval_queue_page.dart
└── panic_responders_module.dart                   # mounted at /panic-responders
```

## BEHAVIOR (since PS3, 2026-10-04)
- A paged workflow list (`PagedListBloc` + `PagedListScreen`, decision 220): the API's pending queue, oldest first, page/pageSize only — the row carries no applicant name or e-mail, so there is no text filter (PS0). Empty state "No pending requests".
- Approve / Deny (tooltips "Approve" / "Deny"; disabled without the screen's UPDATE) call `resolve(id, approved)` through `act()`: success is confirmed by the feedback bridge ("Request approved." / "Request denied.") and the page is reloaded quietly — the request leaves because the server says so. A refusal reaches the operator through the bridge and the queue STAYS (it used to be replaced by an error screen showing the API's raw English message).
- `criteriaNotes` is rendered as plain free text: decision 190 closed the criterion as free human judgment — no eligibility form is pending.

## HISTORY
- Task 05 — first version removed the resolved item from local state instead of re-fetching; superseded by the quiet reload above.
- Required API task 27 (`ResponderPoolMembership` workflow) first, per decision 66, along with API task 11 (`Role`/`AnonymityMode`/`UserIdentity`), see `D:\ProjetoVGR\api\docs\feature\panic-responders.md`.

## REFERENCES

- [**README.md**](../README.md): Documentation navigation index.
- [**category-forms.md**](./category-forms.md): sibling admin-config feature, same pattern.
- API-side counterpart: `D:\ProjetoVGR\api\docs\feature\panic-responders.md`.
