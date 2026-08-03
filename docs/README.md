# Project Documentation

Index of project technical documentation for **VGR Mobile App**. Use the links below to navigate the available documents.

## Documentation Index
**RULE:** Only reference documents located in `./docs/adr/` or `./docs/feature/`. No other folders are permitted. Always validate that referenced files exist in one of these directories before finalizing the document.

| Document | Description | Reading |
|----------|-------------|----------|
| [**ARCHITECTURE.md**](./adr/ARCHITECTURE.md) | Architecture, folder organization, and code patterns for the project. | **Mandatory** |
| [**TESTS.md**](./adr/TESTS.md) | Testing strategies, patterns, and execution commands. | **Mandatory** |
| [**identity.md**](./feature/identity.md) | Shared Role/AnonymityMode state (`packages/core`), consumed by mobile and admin. | Optional |
| [**admin-panel.md**](./feature/admin-panel.md) | `apps/admin` structure and role-gating (decision 56). | Optional |
| [**network.md**](./feature/network.md) | Shared `ApiClient`/`Failure` (`packages/core`), used by every repository. | Optional |
| [**category-forms.md**](./feature/category-forms.md) | Admin editor for per-Category detail-field schema (decision 47). | Optional |

## Recommended Reading Order

1. **adr/ARCHITECTURE.md** — technical foundation and project organization.
2. **adr/TESTS.md** — code validation and quality.
3. Additional documents in adr/ or feature/ folders as needed for the task.
