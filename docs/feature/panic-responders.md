# Panic Responders (admin)

## OVERVIEW
Admin approval queue for `ResponderPoolMembership` requests (decisions 51-52): any authenticated user can request Authorized Responder status via the API; only an admin can approve or deny it here. Mirrors `risk-config`/`category-forms`'s structure.

## STRUCTURE
```
apps/admin/lib/app/modules/panic-responders/
├── domain/entity/responder_approval_entity.dart   # id, userId, status (pending/approved/denied), criteriaNotes
├── domain/repository/responder_approval_repository.dart
├── data/responder_approval_repository_impl.dart
├── presentation/bloc/                             # ResponderApprovalBloc — FetchRequested, ResolveRequested
├── presentation/page/responder_approval_queue_page.dart
└── panic_responders_module.dart                   # mounted at /panic-responders
```

## STATUS
- Task 05 — DONE. Approve/deny calls `resolve(id, approved)` and removes the item from local state directly (no re-fetch) — same "no reload" pattern as `risk-config`'s tier edit.
- `criteriaNotes` is rendered as plain free text with no input validation, per the tactical design's "Criteria field remains free-text pending decision 52's resolution" — there's no eligibility-criteria form yet because decision 52 hasn't defined what the criteria are.
- Required API task 27 (`ResponderPoolMembership` workflow) first, per decision 66 — that task didn't exist yet either, so it was built as part of this same session (see `D:\ProjetoVGR\api\docs\feature\panic-responders.md`), along with API task 11 (`Role`/`AnonymityMode`/`UserIdentity`) which task 27 itself depended on.

## REFERENCES

- [**README.md**](../README.md): Documentation navigation index.
- [**category-forms.md**](./category-forms.md): sibling admin-config feature, same pattern.
- API-side counterpart: `D:\ProjetoVGR\api\docs\feature\panic-responders.md`.
