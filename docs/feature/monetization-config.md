# Monetization Config (admin)

## OVERVIEW
Admin editor for `FeeRule` (decisions 39, 58): fee percent + allowed payment modes, per Category or globally (`category: null`). Mirrors `risk-config`'s structure, but is the first admin module to depend on another admin module's repository (`RiskConfigRepository`), because it enforces "high-tier Categories can't allow peer_to_peer" — a rule the API deliberately does **not** enforce (see `D:\ProjetoVGR\api\docs\feature\monetization-config.md`).

## STRUCTURE
```
apps/admin/lib/app/modules/monetization-config/
├── domain/entity/fee_rule_entity.dart      # PaymentMode, FeeRuleEntity (category: String?, feePercent, paymentModeAllowed)
├── domain/repository/fee_rule_repository.dart
├── data/fee_rule_repository_impl.dart
├── presentation/bloc/                      # MonetizationConfigBloc — FetchRequested, RuleEdited
├── presentation/page/monetization_config_list_page.dart
└── monetization_config_module.dart         # mounted at /monetization-config; imports: [RiskConfigModule()]
```

## STATUS
- Task 07 — DONE. Required its own API prerequisite first (decision 66): task 32 (`FeeRule` registry), which itself hadn't existed in the API backlog at all until this session (see `docs/feature/monetization-config.md` on the API side).
- **Both acceptance criteria are satisfied, unlike the API side**:
  - "A Category-specific rule overrides the global default when present" — the page lists whatever `FeeRule` rows the API returns (global + per-Category), same "no synthesis" approach as the API's `listFeeRules`.
  - "High-tier Categories cannot have `peer_to_peer` added to `paymentModeAllowed`" — enforced **here**, in `MonetizationConfigBloc._onRuleEdited`, by cross-referencing `RiskConfigRepository.list()` fetched alongside `FeeRuleRepository.list()` on load. The peer-to-peer checkbox is also disabled in the UI for high-tier rows (defense in depth, not just a post-submit rejection).
  - This required declaring `imports: [RiskConfigModule()]` in `MonetizationConfigModule` — flutter_modular scopes a module's `binds` to itself by default; `imports` is the documented mechanism for one module to reach another's bindings. No other admin module needed this before now.
- Fee percent + payment mode are edited inline per row (text field + checkbox + Save button), matching `risk-config`'s "no full reload" pattern — `RuleEdited` updates local state directly rather than re-fetching the whole list.
- Simplification, not yet a full editor: "Add a new Category's rule" isn't implemented — only rows the API already returned are editable. Same category as `category-forms`' documented "not yet a full editor" gap; a follow-up, not a re-opening of this task.

## REFERENCES
- [**README.md**](../README.md): Documentation navigation index.
- [**risk-config.md**](./risk-config.md): sibling admin-config feature; also the module this one imports for `RiskConfigRepository`.
- API-side counterpart: `D:\ProjetoVGR\api\docs\feature\monetization-config.md`.
