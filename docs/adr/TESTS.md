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
| Widget | `flutter test` inside `apps/mobile` / `apps/admin` | Isolated widget tests (presentation layer) and each app's guards |
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

Coverage targets are a proposal — CI does not measure them yet (it
runs analyze + every suite, see TOOLING). Adjust after TDD cycles via
`harness-tracer`/`harness-evaluator`.

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
- **CI Integration:** `.github/workflows/ci.yml` — Flutter 3.41.3 (pinned), `flutter pub get`, `flutter analyze`, then `flutter test` for `packages/core`, `packages/vgr_validators`, `packages/vgr_widgets`, `apps/mobile` and `apps/admin`, on every push to `main` and every pull request. Run the same locally before pushing.

## TROUBLESHOOTING
- **Flaky tests:** identify by running `flutter test --reporter expanded` multiple times; report here with the test name.
- **Debug mode:** `flutter test --start-paused` (unit/widget) or `flutter test integration_test --verbose` (E2E).

## Admin: every screen is reached through the real shell (2026-09-21)

Page tests wrap their own `BlocProvider`, so they cannot catch a route
that mounts a page without one (found live on 2026-09-21 on five screens).
`apps/admin/test/app/modules/home/admin_module_wiring_test.dart` therefore
mounts the REAL `HomeModule` (decision 215) and walks every entry of
`interface_routes.dart`, asserting the page renders inside the outlet
(`vgr-page-title` present, `shell-modules-column` still there, no
exception). A new panel screen is covered automatically once it is in
`interfaceRoutes`; a new screen that is NOT there is the bug this test is
for. `home_page_test.dart` covers the shell itself (welcome, columns,
selection, drawer below 850 px, sign out).

## Admin: feedback only through the bridge (decision 221, 2026-10-04)

`apps/admin/test/feedback_bridge_guard_test.dart` scans `apps/admin/lib`
for `showVgr*`, `showDialog` and `ScaffoldMessenger` outside
`lib/app/shared/feedback/` — the same mechanics as the design-system
guard. Screens call `showSuccessFeedback` / `showFailureFeedback` /
`showValidationFeedback` / `askDecision`; the bridge picks the severity
from the `Failure` (no status or 5xx → dialog; 4xx → transient message).
PS2 introduced it with a shrinking list of screens pending migration;
PS3 (2026-10-04) emptied that list, so the rule now holds for the whole
panel with no exception.

## Admin: testing a screen built on the factory (PS2–PS4, 2026-10-04)

What the register/workflow tests in `apps/admin/test` do, so a new screen
copies the pattern instead of rediscovering it:

- **Real catalogs**: `pumpLocalized(tester, page)` (`test/helpers/`) loads
  the en-US catalog from disk, so assertions read what users read
  (`'Record saved.'`, `'Name: Required field.'`). A screen whose spinner
  never stops (a lookup left loading) needs `settle: false`.
- **Wide layout**: set `tester.view.physicalSize` (e.g. 1200×900, ratio 1)
  — the forms and pager are laid out for the web panel.
- **Privileges**: `grantAllPrivileges()` / `revokeAllPrivileges()` or
  `SessionAccess.instance.applyPermissions({...})` BEFORE the pump. Pumping
  a `const` page again does not rebuild it, so privileges changed between
  two pumps in one test are not re-read — split the case instead.
- **Stable keys, no string hunting**: `RegisterSearchPage.newButtonKey` /
  `.rowKey(id)` / `.emptyKey` / `.errorKey`, `VgrFormShell.saveKey` /
  `.deleteKey` / `.backKey`, `VgrPagingBar.previousKey` / `.nextKey` /
  `.summaryKey`, `VgrSearchBar.fieldKey` / `.buttonKey`, form fields
  `register-field-<name>` (checklist options `register-field-<name>-<id>`),
  bridge answers `decisionYesKey` / `decisionNoKey` / `feedbackCloseKey`.
- **The bridge in assertions**: a 4xx refusal is a `SnackBar` with the
  text of `core.errors.<CODE>`; a 5xx / no-status failure and a validation
  pendency are an `AlertDialog`. Assert the list or the form is STILL
  there afterwards — that is the regression PS3 fixed on several screens.
- **Checkboxes**: `pump()` between two taps on the same tile, or the
  second tap reads the stale value.
- **Blocs** (`RegisterBloc`, `PagedListBloc` subclasses): assert the
  signal and the view that follows it (`emitsInOrder([RegisterActionFailure,
  RegisterListLoaded])`); a row action through `act()` reloads QUIETLY (no
  `RegisterListLoading`).
- **Repositories**: assert the exact query string
  (`/api/x?page=1&pageSize=20&filter=...` — `PagedQuery.toQueryString`)
  and both `Right(PagedResult)` and `Left(Failure)`.

