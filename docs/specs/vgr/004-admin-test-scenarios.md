# Test Scenarios — admin

**Domain:** vgr
**Project:** admin
**Framework:** flutter_test, integration_test, mocktail (per `docs/adr/TESTS.md`)

## 1. Unit Tests

### 1.1 Entities

**RiskTierConfigEntity**
- [ ] Should create successfully for any Category with tier one of low/medium/high
- [ ] Should consider two instances equal when category and tier match

**DualControlAccessRequestEntity**
> **Amended, 2026-10-04** (round 18 — DC2, decisions 223–227): the three
> items below judged typed approverIds client-side; superseded — the
> entity is `DualControlRequestEntity` and grantability is the server's
> answer (one approval by ANOTHER user, 224). Replaced by the `[x]` item.
- [ ] Should report isGrantable=false with 0 or 1 approverIds, regardless of legalBasis
- [ ] Should report isGrantable=true only with 2 distinct approverIds and a non-empty legalBasis
- [ ] Should report isGrantable=false if the same approverId appears twice in approverIds
- [x] Should map a request with requester/approver NAMES, and a voided pre-fix request with no requester to nulls (`dual_control_access_repository_impl_test`)

**FeeRuleEntity**
- [ ] Should create successfully with category=null representing the global default rule
- [ ] Should reject a paymentModeAllowed set containing peer_to_peer when the associated Category is high-tier (mirrors decision 58)

### 1.2 Usecases

**ConfigureRiskTierUsecase**
- [ ] Should return Right(void) when called by an authenticated admin with a valid Category and tier

**AddApprovalUsecase**
> **Amended, 2026-10-04** (round 18): there is no usecase layer in the
> panel and no approver argument — the approval posts an EMPTY body; the
> session is the approver (223). Superseded by the `[x]` item.
- [ ] Should return Right(entity) with isGrantable=false after the first distinct approval
- [ ] Should return Right(entity) with isGrantable=true after the second distinct approval
- [ ] Should return Left(Failure) without persisting when the same approverId is submitted twice
- [x] Should approve with an empty body and return the server's row, a refusal as Left (`dual_control_access_repository_impl_test`)

### 1.3 Blocs

**RiskConfigBloc**
- [ ] Should emit [Loading, Loaded(list)] on initial fetch
- [ ] Should emit an updated Loaded state after a successful tier edit, without a full page reload

**DualControlAccessBloc**
> **Amended, 2026-10-04** (round 18): now `DualControlBloc` on the register
> factory; one approval grants (224). Superseded by the `[x]` items.
- [ ] Should emit a one-shot ActionSuccess only when the second distinct approval is recorded, not the first
- [x] Should signal an approval and reload with the server's answer; a refused approval is signalled and the list stays (`dual_control_bloc_test`)

## 2. Integration Tests

### 2.1 Repositories

**RiskConfigRepository / CategoryFormRepository**
- [ ] Should convert a successful upsert call into Right(void)
- [ ] Should convert an API validation error into Left(Failure) with field-level detail preserved

**ResponderApprovalRepository**
- [ ] Should convert a successful resolve(approved: true) call into Right(void) and remove the item from a subsequent listPending call

**DualControlAccessRepository**
- [ ] Should convert a successful addApproval call into Right(entity) reflecting the updated approverIds

### 2.2 Usecases (with real repository implementations, mocked ApiClient)

- [ ] Should execute ConfigureRiskTierUsecase → RiskConfigRepository → ApiClient.put → Right(void) end-to-end
- [ ] Should execute AddApprovalUsecase twice in sequence → second call → Right(entity) with isGrantable=true

### 2.3 External Integrations

> Only the vgr-api administrative HTTP boundary is mapped for the admin project (per `002-context-map.md`). No third-party integrations at MVP scope.

## 3. Functional Tests (widget / integration_test)

### 3.1 Happy Path Flows

- [ ] **Should let an admin update a Category's RiskTier without a page reload**
  - Given: RiskConfigListPage is open with the API mocked to return the current tiers
  - When: the admin edits one Category's tier and saves
  - Then: the row reflects the new tier immediately, RiskTierConfigSaved fires

- [ ] **Should let an admin edit a Category's detail-form schema**
  - Given: CategoryFormListPage is open for "missing_person"
  - When: the admin adds a new field and saves
  - Then: CategoryFormSchemaSaved fires and the field appears in the schema list

- [ ] **Should let an admin approve a pending Authorized Responder request**
  - Given: ResponderApprovalQueuePage lists 1 pending request
  - When: the admin taps Approve
  - Then: the request disappears from the pending queue

- [ ] **Should require 2 distinct admins to grant a dual-control access request**
  - Given: DualControlRequestPage is open for a new request with a filled legalBasis
  - When: admin A approves, then admin B approves
  - Then: the request shows Granted only after B's approval, not after A's alone

> **Amended, 2026-10-04** (round 18 — DC2): the scenario above is
> superseded — A's request IS the first authorization and B's one approval
> grants (224); the two people are distinct by construction.
- [x] **Should let only ANOTHER admin approve a dual-control request** (`dual_control_access_page_test`)
  - Given: DualControlAccessPage lists a pending request opened by admin A
  - When: admin A looks at it, then admin B approves it
  - Then: A sees Approve disabled ("another person must approve"); after B's approval the row shows "Approved by B" and no Approve

- [ ] **Should let an admin set a fee rule for a Category**
  - Given: MonetizationConfigPage is open
  - When: the admin sets a feePercent for "robbery" with paymentModeAllowed={intermediated, peer_to_peer}
  - Then: FeeRuleSaved fires and the row reflects the saved rule

### 3.2 Alternative and Error Flows

- [ ] Should show a validation error, not a raw exception, when a fee rule tries to allow peer_to_peer on a high-tier Category
- [ ] Should show the current approver count (not just approved/pending) while a dual-control request is in progress
- [x] Should show who requested and who approved each dual-control request by name, and its status (amended 2026-10-04, decision 227 — supersedes the approver count above; `dual_control_access_page_test`)
- [ ] Should redirect away from every admin route when the session's Role is not admin

### 3.3 Security Scenarios

- [ ] Should never allow a single browser session/admin identity to satisfy both required approvals on a dual-control request (server-enforced, but UI must not imply it's possible)
- [ ] Should never render AccountabilityLogEntry contents anywhere in the admin UI outside the explicit, audited dual-control grant flow
- [ ] Should exclude every admin-only route from being reachable via a deep link when the session Role is not admin

## Save

Saved to: `D:\ProjetoVGR\app\docs\specs\vgr\004-admin-test-scenarios.md`
