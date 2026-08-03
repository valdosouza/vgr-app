# Auth (admin login)

## OVERVIEW
Real email/password login for `apps/admin` (decision 67), replacing the temporary manual-QA `IdentityBloc` bypass used earlier in this session. Calls the API's `POST /auth/admin-login`, then sets `ApiClient`'s session token and updates `IdentityBloc` to `Role.admin`.

## STRUCTURE
```
apps/admin/lib/app/modules/auth/
├── domain/repository/auth_repository.dart   # login(email, password) -> Either<Failure, String> (jwt)
├── data/auth_repository_impl.dart           # POST /auth/admin-login; calls ApiClient.setToken(jwt) as a side effect
├── presentation/bloc/                       # LoginBloc — LoginSubmitted -> Loading/Success/Error
└── presentation/page/login_page.dart
```

Not a `flutter_modular` sub-`Module` like the other admin features — it's a single `ChildRoute('/login', ...)` in `AppModule` itself, wrapped in its own `BlocProvider` inline, since there's no route subtree under it.

## STATUS
- DONE. `AdminSessionGuard`'s `redirectTo` (in `packages/core`) changed from `/access-denied` to `/login` — the old `AccessDeniedPage` is deleted, `LoginPage` renders at that route instead.
- On success, `LoginBloc` fires `IdentityBloc.add(ProviderLoginCompleted(role: Role.admin, anonymityMode: AnonymityMode.anonymous, token: jwt))` — every other admin repository's `ApiClient` calls now carry that JWT automatically via `ApiClient.setToken` (see `network.md`), with zero changes to `risk-config`/`category-forms`/`panic-responders`/`dual-control-access`/`monetization-config`.
- `admin_route_gate_test.dart` (`apps/admin/test/app/modules/home/`) updated to assert the login page's email field appears, instead of the old "Access denied" text.
- No account-creation UI — `AdminAccount` rows are seeded via the API's `scripts/seed-admin.ts` (decision 67), not through this app.

## REFERENCES
- [**README.md**](../README.md): Documentation navigation index.
- [**identity.md**](./identity.md): `IdentityState.token`, set here.
- [**network.md**](./network.md): `ApiClient.setToken`, used here.
- API-side counterpart: `D:\ProjetoVGR\api\docs\feature\auth.md`.
