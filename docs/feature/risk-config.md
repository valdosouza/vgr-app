# Risk Config (admin)

## OVERVIEW
Admin editor for the RiskTier of each report Category (decision 46): one row per
Category with its tier (`low` / `medium` / `high`) as an inline dropdown. The tier drives
the server-side degradation of position (decision 135) and the peer-to-peer veto of
`monetization-config` (decision 58). A fixed catalog — unpaged by decision 220.

## STRUCTURE
```
apps/admin/lib/app/modules/risk-config/
├── domain/entity/risk_tier_config_entity.dart   # category + RiskTier (core)
├── domain/repository/risk_config_repository.dart
├── data/risk_config_repository_impl.dart       # GET /api/risk-config, PUT /api/risk-config/:category
├── presentation/bloc/                          # RiskConfigBloc — FetchRequested, TierEdited; ActionFailed / ActionSucceeded one-shots
├── presentation/page/risk_config_list_page.dart
└── risk_config_module.dart                     # mounted at /risk-config
```

## BEHAVIOR
- The dropdown answers only with the screen's UPDATE (decision 72 — UX only; the API
  enforces).
- A tier change persists via `upsert()` and updates the row in place (no re-fetch). Since
  PS3 (2026-10-04) the outcome goes through the feedback bridge (decision 221): saved is
  confirmed, a refusal is reported translated by code and the list STAYS (it used to be
  replaced by an error screen with the API's raw English message). A load failure shows
  the translated error with a retry.
- `monetization-config` imports this module's repository code and binds its own instance
  to read the tiers — the panel's one documented module-to-module import.

## REFERENCES
- [**README.md**](../README.md): Documentation navigation index.
- [**monetization-config.md**](./monetization-config.md): the screen that reads these tiers.
- [**category-forms.md**](./category-forms.md): sibling fixed catalog, same pattern.
