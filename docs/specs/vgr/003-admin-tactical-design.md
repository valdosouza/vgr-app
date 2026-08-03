# Tactical Design — admin
**Domain:** vgr | **Project:** admin

> Frontend architecture: same Flutter Clean Architecture as `mobile` (`docs/adr/ARCHITECTURE.md`) — one `flutter_modular` module per admin capability, web-only target (decision 56). Reuses `packages/core`, `packages/vgr_widgets`, `packages/vgr_validators`. Talks to the same `vgr-api`, but exclusively administrative endpoints gated by dual-role control (decision 45).

## Section 1 — Main Structure

| Element | Layer / Type | Invariants / Tech Rules | 4-line Snippet |
|---|---|---|---|
| risk-config module | Integration + Components | Lists/edits RiskTierConfig per Category (decision 46) | *see below* |
| category-forms module | Integration + Components | Lists/edits CategoryFormSchema per Category (decision 47) | *see below* |
| panic-responders module | Integration + Components | Queue of pending ResponderPoolMembership requests; approve/deny (decisions 51-52) | *see below* |
| dual-control-access module | Integration + Components | Requests/approves AccountabilityLogEntry decryption; requires 2 distinct admin approvals + legal basis (decision 45) | *see below* |
| monetization-config module | Integration + Components | Edits fee rules for reward intermediation, per Category or globally (decisions 39, 58) | *see below* |
| AdminSessionBloc (in `packages/core`, shared with mobile) | Integration | Holds the authenticated admin's Role; admin endpoints require Role=admin (decision 4) | *see below* |

```dart
// modules/risk-config/presentation/page — RiskConfigListPage
class RiskConfigListPage extends StatelessWidget {
  // one row per Category: current RiskTier + edit action
}
```
```dart
// modules/dual-control-access/presentation/page — DualControlRequestPage
class DualControlRequestPage extends StatelessWidget {
  // shows legalBasis field + approver list; submit disabled until 2 distinct approverIds recorded
}
```
```dart
// modules/panic-responders/presentation/page — ResponderApprovalQueuePage
class ResponderApprovalQueuePage extends StatelessWidget {
  // pending requests list; approve/deny actions, criteria still undefined (decision 52)
}
```

## Section 2 — Types / Interfaces

| Name | Layer | Rules | 4-line Snippet |
|---|---|---|---|
| RiskTierConfigEntity | domain/entity (risk-config module) | category + tier (low/medium/high); mirrors API RiskTierConfig (decision 46) | *see below* |
| CategoryFormSchemaEntity | domain/entity (category-forms module) | category + list of field definitions (name, type, required) | *see below* |
| ResponderApprovalEntity | domain/entity (panic-responders module) | userId + status (pending/approved/denied) + criteria notes (decision 52, still open) | *see below* |
| DualControlAccessRequestEntity | domain/entity (dual-control-access module) | legalBasis + approverIds (max useful length 2); `isGrantable` only when approverIds.length >= 2 and distinct | *see below* |
| FeeRuleEntity | domain/entity (monetization-config module) | category (nullable = global default) + feePercent + paymentModeAllowed (decision 39, 58) | *see below* |

```dart
class RiskTierConfigEntity extends Equatable {
  final String category; final RiskTier tier;
  const RiskTierConfigEntity({required this.category, required this.tier});
}
```
```dart
class DualControlAccessRequestEntity extends Equatable {
  final String legalBasis; final List<String> approverIds;
  bool get isGrantable => approverIds.toSet().length >= 2 && legalBasis.isNotEmpty;
  const DualControlAccessRequestEntity({required this.legalBasis, required this.approverIds});
}
```
```dart
class FeeRuleEntity extends Equatable {
  final String? category; final double feePercent; final Set<PaymentMode> paymentModeAllowed;
  const FeeRuleEntity({this.category, required this.feePercent, required this.paymentModeAllowed});
}
```

## Section 3 — Usecases / Blocs

| Operation / Hook | Responsibility | Coordinates / Subscriptions | 4-line Snippet |
|---|---|---|---|
| ConfigureRiskTierUsecase | Admin sets/updates a Category's RiskTier | RiskConfigRepository | *see below* |
| ConfigureCategoryFormSchemaUsecase | Admin sets/updates a Category's detail-form schema | CategoryFormRepository | *see below* |
| ListPendingResponderRequestsUsecase / ApproveResponderUsecase | Lists and resolves Authorized Responder applications | ResponderApprovalRepository | *see below* |
| RequestDualControlAccessUsecase / AddApprovalUsecase | Creates and progresses a decryption request toward the 2-approver threshold | DualControlAccessRepository | *see below* |
| ConfigureFeeRuleUsecase | Admin sets fee percent and allowed payment modes, per Category or globally | FeeRuleRepository | *see below* |

```dart
class AddApprovalUsecase {
  Future<Either<Failure, DualControlAccessRequestEntity>> call(String requestId, String approverId) {
    // rejects a duplicate approverId; grants only when isGrantable becomes true after this call
  }
}
```
```dart
class ConfigureRiskTierUsecase {
  Future<Either<Failure, void>> call(String category, RiskTier tier) =>
    repository.upsert(category, tier); // takes effect on next TTL cache refresh, no deploy needed
}
```

## Section 4 — Events / Actions

| Event / Action Name | Trigger | Minimum Payload | Consumers |
|---|---|---|---|
| RiskTierConfigSaved | ConfigureRiskTierUsecase resolves | `{ category, tier }` | RiskConfigListPage (refreshes row) |
| CategoryFormSchemaSaved | ConfigureCategoryFormSchemaUsecase resolves | `{ category }` | CategoryFormListPage |
| ResponderRequestResolved | ApproveResponderUsecase resolves | `{ userId, approved }` | ResponderApprovalQueuePage (removes from queue) |
| DualControlApprovalAdded | AddApprovalUsecase resolves, threshold not yet met | `{ requestId, approverCount }` | DualControlRequestPage (updates progress) |
| DualControlAccessGranted | AddApprovalUsecase resolves, threshold met | `{ requestId }` | DualControlRequestPage (one-shot success state) |
| FeeRuleSaved | ConfigureFeeRuleUsecase resolves | `{ category, feePercent }` | MonetizationConfigPage |

## Section 5 — Data Access Interfaces

| Resource / Adapter | Methods / Actions | Return Types / Expected State |
|---|---|---|
| RiskConfigRepository | list, upsert | `Either<Failure,List<RiskTierConfigEntity>>`, `Either<Failure,void>` |
| CategoryFormRepository | list, upsert | `Either<Failure,List<CategoryFormSchemaEntity>>`, `Either<Failure,void>` |
| ResponderApprovalRepository | listPending, resolve | `Either<Failure,List<ResponderApprovalEntity>>`, `Either<Failure,void>` |
| DualControlAccessRepository | create, addApproval, findPending | `Either<Failure,String>`, `Either<Failure,DualControlAccessRequestEntity>`, `Either<Failure,List<DualControlAccessRequestEntity>>` |
| FeeRuleRepository | list, upsert | `Either<Failure,List<FeeRuleEntity>>`, `Either<Failure,void>` |

```dart
abstract class DualControlAccessRepository {
  Future<Either<Failure, DualControlAccessRequestEntity>> addApproval(String requestId, String approverId);
}
```

## Section 6 — Ordered Development Tasks

```json
[
  { "id": "01", "title": "Bootstrap admin app shell and AdminSessionBloc role gate", "description": "Ensures every admin route requires Role=admin from IdentityBloc before rendering.", "scope": ["apps/admin/lib/app/modules/home/", "packages/core/lib/src/identity/admin_session_guard.dart"], "acceptance": ["Non-admin session is redirected away from every admin route"], "depends_on": null, "note": "Amended — cross-project dependency: requires packages/core's IdentityBloc, specified as mobile tactical design task 15 but not yet implemented anywhere. Build that first." },
  { "id": "02", "title": "Implement RiskTierConfigEntity and RiskConfigRepository", "description": "Domain/data layer for listing and editing RiskTier per Category (decision 46).", "scope": ["apps/admin/lib/app/modules/risk-config/domain/", "apps/admin/lib/app/modules/risk-config/data/"], "acceptance": ["upsert() call reaches the API's RiskTierConfig endpoint"], "depends_on": "01" },
  { "id": "03", "title": "Implement RiskConfigListPage", "description": "Table of Categories with current RiskTier and inline edit.", "scope": ["apps/admin/lib/app/modules/risk-config/presentation/", "apps/admin/lib/app/modules/risk-config/risk_config_module.dart"], "acceptance": ["Editing a row's tier persists without a page reload"], "depends_on": "02" },
  { "id": "04", "title": "Implement CategoryFormSchemaEntity, repository, and editor page", "description": "Lets an admin add/remove/reorder detail-form fields per Category (decision 47).", "scope": ["apps/admin/lib/app/modules/category-forms/"], "acceptance": ["Adding a field here is reflected in the mobile app's CategoryDetailFormPage without an app update"], "depends_on": "01" },
  { "id": "05", "title": "Implement ResponderApprovalEntity, repository, and approval queue page", "description": "Lists pending Authorized Responder requests with approve/deny actions (decisions 51-52).", "scope": ["apps/admin/lib/app/modules/panic-responders/"], "acceptance": ["Approve/deny removes the request from the pending queue", "Criteria field remains free-text pending decision 52's resolution"], "depends_on": "01" },
  { "id": "06", "title": "Implement DualControlAccessRequestEntity and two-approval progress UI", "description": "Lets an admin start a decryption request and track it toward the 2-distinct-approver threshold (decision 45).", "scope": ["apps/admin/lib/app/modules/dual-control-access/"], "acceptance": ["Request cannot reach Granted state with only 1 approver", "The same approverId cannot be counted twice"], "depends_on": "01" },
  { "id": "07", "title": "Implement FeeRuleEntity, repository, and monetization config page", "description": "Lets an admin set fee percent and allowed payment modes per Category or globally (decisions 39, 58).", "scope": ["apps/admin/lib/app/modules/monetization-config/"], "acceptance": ["A Category-specific rule overrides the global default when present", "High-tier Categories cannot have peer_to_peer added to paymentModeAllowed (mirrors decision 58 server-side constraint)"], "depends_on": "01" }
]
```

## Save

Saved to: `D:\ProjetoVGR\app\docs\specs\vgr\003-admin-tactical-design.md`
