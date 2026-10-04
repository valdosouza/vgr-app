# Monetization Config (admin)

## OVERVIEW
Admin editor for `FeeRule` (decisions 39, 58): fee percent + allowed payment modes, per Category or globally (`category: null`). Mirrors `risk-config`'s structure, but is the first admin module to depend on another admin module's repository (`RiskConfigRepository`), because it checks "high-tier Categories can't allow peer_to_peer" (decision 58) before calling the API. The API enforces the same veto since 2026-08-19 (write-time 422 `BUSINESS_RULE`, read-time stripping — `api/src/modules/monetization-config/fee-rule.service.ts`); the panel's check is defense in depth, and its refusal has the API's own shape.

## STRUCTURE
```
apps/admin/lib/app/modules/monetization-config/
├── domain/entity/fee_rule_entity.dart      # PaymentMode, FeeRuleEntity (category: String?, feePercent, paymentModeAllowed)
├── domain/repository/fee_rule_repository.dart
├── data/fee_rule_repository_impl.dart
├── presentation/bloc/                      # MonetizationConfigBloc — FetchRequested, RuleEdited
├── presentation/page/monetization_config_list_page.dart
└── monetization_config_module.dart         # mounted at /monetization-config; binds its OWN RiskConfigRepository
```

## STATUS
- Task 07 — DONE. Required its own API prerequisite first (decision 66): task 32 (`FeeRule` registry), which itself hadn't existed in the API backlog at all until this session (see `docs/feature/monetization-config.md` on the API side).
- **Both acceptance criteria are satisfied, unlike the API side**:
  - "A Category-specific rule overrides the global default when present" — the page lists whatever `FeeRule` rows the API returns (global + per-Category), same "no synthesis" approach as the API's `listFeeRules`.
  - "High-tier Categories cannot have `peer_to_peer` added to `paymentModeAllowed`" — enforced **here**, in `MonetizationConfigBloc._onRuleEdited`, by cross-referencing `RiskConfigRepository.list()` fetched alongside `FeeRuleRepository.list()` on load. The peer-to-peer checkbox is also disabled in the UI for high-tier rows (defense in depth, not just a post-submit rejection).
  - To read the tiers the module imports `risk-config`'s repository CODE and binds its own `RiskConfigRepository` (it first used `imports: [RiskConfigModule()]`, which left the bloc unbuildable — flutter_modular 5.0.3 shares only `export: true` binds, and an exported bind disappears from its own module; found live 2026-09-21 by `admin_module_wiring_test`). The panel's one module-to-module import, registered in `docs/adr/ARCHITECTURE.md`.
- Fee percent + payment mode are edited inline per row (text field + checkbox + Save button) — `RuleEdited` updates local state directly rather than re-fetching the whole list. Since PS3 (2026-10-04): a fee outside 0..100 (`feeRuleUpdateDto`) is a validation pendency instead of a silent no-op; a saved rule is confirmed and a refused one (API or local veto) is reported through the feedback bridge (decision 221) with the rows kept — it used to replace the screen with an error showing the API's raw English text. A fixed catalog: unpaged by decision 220.
- Simplification, not yet a full editor: "Add a new Category's rule" isn't implemented — only rows the API already returned are editable. Same category as `category-forms`' documented "not yet a full editor" gap; a follow-up, not a re-opening of this task.

## REFERENCES
- [**README.md**](../README.md): Documentation navigation index.
- [**risk-config.md**](./risk-config.md): sibling admin-config feature; also the module this one imports for `RiskConfigRepository`.
- API-side counterpart: `D:\ProjetoVGR\api\docs\feature\monetization-config.md`.
