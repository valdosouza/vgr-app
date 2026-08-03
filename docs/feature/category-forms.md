# Category Forms (admin)

## OVERVIEW
Admin editor for the per-Category detail-field schema (decision 47), mirroring `risk-config`'s structure exactly. Reading side is what `apps/mobile`'s `CategoryDetailFormPage` will consume (mobile task 21).

## STRUCTURE
```
apps/admin/lib/app/modules/category-forms/
├── domain/entity/
│   ├── field_definition_entity.dart      # name, type (FieldType), required
│   └── category_form_schema_entity.dart  # category + List<FieldDefinitionEntity>
├── domain/repository/category_form_repository.dart
├── data/category_form_repository_impl.dart
├── presentation/bloc/                    # CategoryFormBloc — FetchRequested, FieldAdded
├── presentation/page/category_form_list_page.dart
└── category_forms_module.dart            # mounted at /category-forms
```

## STATUS
- Task 04 — DONE. `FieldAdded` persists via `upsert()` and updates local state directly (no re-fetch).
- **Known gap fixed along the way**: neither `risk-config` nor `category-forms` had a `GET` (list) endpoint on the API — the admin repositories were calling `apiClient.get(...)` against a route that didn't exist. Unit tests didn't catch it because they mock `ApiClient`. Added `GET /api/risk-config` and `GET /api/category-forms` (both admin-gated) to close this.
- **Simplification, not yet a full editor**: "Add field" appends a hardcoded placeholder field (`newField`, string, optional) rather than opening a name/type/required input dialog. Remove/reorder aren't implemented yet either — task 04's description says "add/remove/reorder" but the tactical design's acceptance criterion only requires the integration property (change reaches mobile without an app update), which is satisfied. A real field-editing form is a follow-up refinement, not re-opening this task.

## REFERENCES

- [**README.md**](../README.md): Documentation navigation index.
- [**risk-config.md**](./risk-config.md): sibling admin-config feature, same pattern.
