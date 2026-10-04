# Dual Control Access (admin)

## OVERVIEW
Two-approval progress UI for `DualControlAccessRequest` (decision 45): an admin starts a request (legal basis + target `AccountabilityLogEntry` id), then distinct admins each submit an approval until the 2-distinct-approver threshold is met.

## STRUCTURE
```
apps/admin/lib/app/modules/dual-control-access/
├── domain/entity/dual_control_access_request_entity.dart   # id, legalBasis, approverIds; isGrantable getter
├── domain/repository/dual_control_access_repository.dart   # create, addApproval, findPending
├── data/dual_control_access_repository_impl.dart
├── presentation/bloc/                                      # DualControlAccessBloc — RequestSubmitted, ApprovalSubmitted; DualControlActionFailed one-shot
├── presentation/page/dual_control_request_page.dart
└── dual_control_access_module.dart                         # mounted at /dual-control-access
```

## STATUS
- Task 06 — DONE. `DualControlActionSuccess` (one-shot) fires only on the approval call that pushes `isGrantable` to true — verified by a bloc test that the first approval yields `DualControlProgress`, not `DualControlActionSuccess`.
- Required a `packages/core` prerequisite: `ApiClient` only had `get`/`put` before this task — added `post` (TDD, see `network.md`), since `create`/`addApproval` are both state-changing actions without natural PUT idempotency.
- `approverId` is entered as free text in the page (`approver-id-field`), not derived from the signed-in admin's identity. When this was built the panel had no session; it has had a real one since (login + JWT, decisions 67/112/114), but the API (`api/src/modules/admin-access/dual-control.dto.ts`) still takes `approverId` from the request BODY.
- ⚠️ **Open risk (found during PS4, 2026-10-04 — pending a decision)**: because the approver is whatever the body says, ONE admin holding both grants (`dual_control_access` UPDATE + `dual_control_approval` UPDATE) can post two approvals with two different typed ids and reach the 2-distinct-approver threshold alone — which defeats decision 45. The fix belongs to the API (approver = the session user, `req.user`), with this page dropping the field; registered in `AI/docs/plans/plano-painel-modelo-setes.md` §9.
- Since PS3 (2026-10-04): a refused request or approval reaches the operator through the feedback bridge (decision 221) and the page STAYS on the step it was on (a refused approval used to fall back to the start form, dropping the request in progress); a missing log-entry id, legal basis or approver id is a validation pendency instead of a silent no-op.
- `DualControlRequestPage` is a single-request flow (create → track → grant), not a list/queue like `ResponderApprovalQueuePage` — matches the tactical design's snippet (`legalBasis` field + approver list on one page) and the functional test's GWT shape (one page, two sequential approvals).

## REFERENCES
- [**README.md**](../README.md): Documentation navigation index.
- [**network.md**](./network.md): `ApiClient.post`, added for this task.
- API-side counterpart: `D:\ProjetoVGR\api\docs\feature\dual-control-access.md`.
