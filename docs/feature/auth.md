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

## SECURITY PHASE S6 (decisions 112, 114, 117) — what changed here

The API's 15-minute revocable session and mandatory 2FA broke the old
login contract; this phase brought the panel back into agreement with it.

- **`LoginResult` is a sealed type**: a session, or "enrollment required".
  The API's `TWO_FACTOR_REQUIRED` code makes the form switch to the code
  step instead of showing an error, keeping the typed credentials; the
  enrollment branch carries **no session token at all** (decision 114).
- **New pages**: `two_factor_setup_page` (secret + otpauth URI as text —
  no QR dependency; a wrong code keeps the enrollment on screen; the ten
  recovery codes appear once, behind an explicit "I saved them" step
  before the session opens) and `two_factor_recover_page` (password + one
  unused backup code, which clears TOTP and re-enrolls next login).
- **Silent renewal in `ApiClient`** (decision 112): the token is exchanged
  at `POST /api/auth/renew` before expiry; concurrent calls share one
  renewal; a failed renewal stays quiet and lets the 401 flow through as
  "session over". The fresh token is persisted only under "keep me signed
  in" (decision 73).
- **`LegalBlockedView` in `packages/core`** (decision 117): HTTP 451 gets
  its own screen showing the typed reason (decision 78), with a safe
  fallback so a reason the app does not know yet never renders a raw key.
- **`SecureTokenStore`** abstraction: the web panel keeps `LocalPrefs`
  (the 15-minute TTL is what shrinks the XSS window), and the mobile app
  swaps in Keychain/Keystore later without touching callers.
- **`LoginBloc` is a singleton** in `AppModule` so the enrollment page can
  complete the session on the same bloc the login page started.

All auth screens use the `Vgr*` design system (decision 133) — see
[DESIGN-SYSTEM.md](../adr/DESIGN-SYSTEM.md).

⚠️ **Deploy note**: API and app must ship together — the login response
shape and the token contract changed on both sides.

## REFERENCES
- [**README.md**](../README.md): Documentation navigation index.
- [**identity.md**](./identity.md): `IdentityState.token`, set here.
- [**network.md**](./network.md): `ApiClient.setToken` and the silent renewal, used here.
- [**DESIGN-SYSTEM.md**](../adr/DESIGN-SYSTEM.md): the `Vgr*` rule these screens follow.
- API-side counterpart: `D:\ProjetoVGR\api\docs\feature\auth.md`.
