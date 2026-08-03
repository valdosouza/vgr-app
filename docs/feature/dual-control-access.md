# Dual Control Access (admin)

## OVERVIEW
Two-approval progress UI for `DualControlAccessRequest` (decision 45): an admin starts a request (legal basis + target `AccountabilityLogEntry` id), then distinct admins each submit an approval until the 2-distinct-approver threshold is met.

## STRUCTURE
```
apps/admin/lib/app/modules/dual-control-access/
├── domain/entity/dual_control_access_request_entity.dart   # id, legalBasis, approverIds; isGrantable getter
├── domain/repository/dual_control_access_repository.dart   # create, addApproval, findPending
├── data/dual_control_access_repository_impl.dart
├── presentation/bloc/                                      # DualControlAccessBloc — RequestSubmitted, ApprovalSubmitted
├── presentation/page/dual_control_request_page.dart
└── dual_control_access_module.dart                         # mounted at /dual-control-access
```

## STATUS
- Task 06 — DONE. `DualControlActionSuccess` (one-shot) fires only on the approval call that pushes `isGrantable` to true — verified by a bloc test that the first approval yields `DualControlProgress`, not `DualControlActionSuccess`.
- Required a `packages/core` prerequisite: `ApiClient` only had `get`/`put` before this task — added `post` (TDD, see `network.md`), since `create`/`addApproval` are both state-changing actions without natural PUT idempotency.
- `approverId` is entered as free text in the page (`approver-id-field`), not derived from the signed-in admin's own identity — because nothing in `apps/admin` acquires or stores a JWT yet (`IdentityBloc` only tracks `Role`, not a per-admin identity/token), a pre-existing gap across every admin module, not something this task introduced. Flagged in `D:\ProjetoVGR\api\docs\feature\dual-control-access.md` as the reason the API also accepts `approverId` in the request body instead of deriving it server-side from the JWT.
- `DualControlRequestPage` is a single-request flow (create → track → grant), not a list/queue like `ResponderApprovalQueuePage` — matches the tactical design's snippet (`legalBasis` field + approver list on one page) and the functional test's GWT shape (one page, two sequential approvals).

## REFERENCES
- [**README.md**](../README.md): Documentation navigation index.
- [**network.md**](./network.md): `ApiClient.post`, added for this task.
- API-side counterpart: `D:\ProjetoVGR\api\docs\feature\dual-control-access.md`.
