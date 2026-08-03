# Auth (admin login)

## OVERVIEW
Real email/password login for `apps/admin` (decision 67), replacing the temporary manual-QA `IdentityBloc` bypass used earlier in this session. Calls the API's `POST /auth/admin-login`, then sets `ApiClient`'s session token and updates `IdentityBloc` to `Role.admin`.

Phase 2 of the admin-controls plan (decision 73) added: **session persistence** ("Keep me signed in" stores the JWT in `LocalPrefs`; `AdminSessionGuard` restores it on page refresh and drops it when expired via `jwt_utils`), **"Remember my email"** (stores the email only, never the password), and the **password recovery flow** (`/recovery-password` requests a 6-digit code by email, `/change-password` sets the new one). All auth screens are internationalized (en-US source, pt-BR).

## STRUCTURE
```
apps/admin/lib/app/modules/auth/
├── domain/repository/auth_repository.dart   # login / recoveryPassword / changePassword
├── data/auth_repository_impl.dart           # POST /auth/admin-login | /auth/recovery-password | /auth/change-password
├── presentation/bloc/                       # LoginBloc (+ LoginPrefsRequested) · RecoveryBloc
└── presentation/page/                       # login_page · recovery_password_page · change_password_page

packages/core/lib/src/
├── storage/local_prefs.dart                 # session_token / keep_connected / remembered_email
├── identity/jwt_utils.dart                  # decodeJwtPayload / isJwtExpired (client-side check only; API is the authority)
└── identity/admin_session_guard.dart        # restores persisted session before redirecting to /login
```

Not a `flutter_modular` sub-`Module` like the other admin features — `ChildRoute`s for `/login`, `/recovery-password` and `/change-password` live in `AppModule` itself, each wrapped in its own `BlocProvider` inline, since there's no route subtree under them.

## STATUS
- DONE. `AdminSessionGuard`'s `redirectTo` (in `packages/core`) changed from `/access-denied` to `/login` — the old `AccessDeniedPage` is deleted, `LoginPage` renders at that route instead.
- On success, `LoginBloc` fires `IdentityBloc.add(ProviderLoginCompleted(role: Role.admin, anonymityMode: AnonymityMode.anonymous, token: jwt))` — every other admin repository's `ApiClient` calls now carry that JWT automatically via `ApiClient.setToken` (see `network.md`), with zero changes to `risk-config`/`category-forms`/`panic-responders`/`dual-control-access`/`monetization-config`.
- `admin_route_gate_test.dart` (`apps/admin/test/app/modules/home/`) updated to assert the login page's email field appears, instead of the old "Access denied" text.
- No account-creation UI — `AdminAccount` rows are seeded via the API's `scripts/seed-admin.ts` (decision 67), not through this app.
- **Bug found during manual QA (user reported "login não funcionou" after entering correct credentials) and fixed**: the initial `LoginPage` used `BlocBuilder`, which only updates `IdentityBloc` on `LoginSuccess` but never navigates — so the URL stayed on `/login` with the form still visible, indistinguishable from a silent failure even though `POST /auth/admin-login` had returned 200 with a valid JWT (confirmed via curl and via the running app's own network log during debugging). Fixed by switching to `BlocConsumer` with a `listener` that calls `Modular.to.navigate('/')` on `LoginSuccess`. A widget test (`login_navigation_test.dart`, using a minimal test `Module` with a mocked `AuthRepository`) verifies the login field disappears after a successful submit — the earlier tests only asserted `IdentityBloc.state.role`, never that the page itself moved on.

## REFERENCES
- [**README.md**](../README.md): Documentation navigation index.
- [**identity.md**](./identity.md): `IdentityState.token`, set here.
- [**network.md**](./network.md): `ApiClient.setToken`, used here.
- API-side counterpart: `D:\ProjetoVGR\api\docs\feature\auth.md`.
