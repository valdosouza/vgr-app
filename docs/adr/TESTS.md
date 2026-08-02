# Testing Protocol

## OVERVIEW
TDD is mandatory (RED → GREEN → REFACTOR). `flutter_test` for unit/widget,
`integration_test` for E2E, `mocktail` for test doubles (same choice as
setes-app — no code generation). No business logic without a test written
first.

## COMMANDS
| Type | Command | Description |
|------|---------|-------------|
| Unit | `flutter test packages/core/test` (and other packages) | Pure logic tests (usecases, mappers, validators) |
| Widget | `flutter test apps/mobile/test` | Isolated widget tests (presentation layer) |
| Integration/E2E | `flutter test apps/mobile/integration_test` | Full flow on device/emulator |
| Coverage | `flutter test --coverage` (run inside each package/app) | Generates `coverage/lcov.info` |
| Full workspace | `flutter pub get` at the root, then run the commands above per member | The workspace has no native aggregated runner |

## MINIMUM COVERAGE
REQUIRED: Maintain the following minimum coverage levels:

| Layer | Coverage | Description |
|-------|----------|-------------|
| domain (usecase, entity) | 90% | Business rules and invariants |
| data (repository, datasource) | 80% | External integrations and mapping |
| presentation (bloc) | 80% | State transitions (buildable + one-shot) |
| presentation (page/widget) | 60% | Prioritize loading/error/empty states and accessibility |
| Global | 75% | Total workspace average |

⚠️ Initial proposal — no CI configured yet. Adjust after the first TDD
cycles via `harness-tracer`/`harness-evaluator`.

## PATTERNS & BEST PRACTICES
REQUIRED: AAA (Arrange, Act, Assert) — one main assertion per test.
REQUIRED: Mock only external boundaries (`ApiClient`, storage, geolocation) via `mocktail` — never internal domain logic.
REQUIRED: Bloc tested by state transition — `bloc.stream` with `emitsInOrder([...])`/`expectLater`, covering "buildable" (List/Form) and "one-shot" (ActionSuccess/ActionFailure) states separately.
REQUIRED: Repository tested converting exceptions into `Left(Failure)` and success into `Right(T)` — both paths, always.
REQUIRED: Widget tests verify loading/error/empty states, not only the happy path.
FORBIDDEN: Business logic inside `setUp()`/`tearDown()`.
FORBIDDEN: Tests that depend on execution order or shared global state.
FORBIDDEN: Real network calls in unit/widget tests — real calls only in a controlled `integration_test`.

## TOOLING
- **Framework:** `flutter_test` (SDK), `integration_test` (E2E)
- **Assertions:** `package:test` matchers (`expect`, `emitsInOrder`)
- **Mocks/Stubs:** `mocktail` (same choice as setes-app)
- **Coverage:** `flutter test --coverage` → `lcov.info`
- **CI Integration:** TBD — no pipeline configured yet

## TROUBLESHOOTING
- **Flaky tests:** identify by running `flutter test --reporter expanded` multiple times; report here with the test name.
- **Debug mode:** `flutter test --start-paused` (unit/widget) or `flutter test integration_test --verbose` (E2E).
