# Network

## OVERVIEW
Shared HTTP client (`packages/core`) used by every repository implementation in both `apps/mobile` and `apps/admin`. Decodes the API's envelope and converts non-2xx responses into a uniform `Failure`.

## STRUCTURE
```
packages/core/lib/src/
├── error/failure.dart      # Failure — message, statusCode?, code?; the Left side of every Either<Failure,T>
└── network/api_client.dart # ApiClient — get(path), post(path, body), put(path, body); all take an optional token
```

## CONVENTIONS
- Repository implementations wrap `ApiClient` calls in `try { ... Right(...) } on Failure catch (f) { Left(f) }` — never let a raw `Failure` escape past the repository layer.
- `Failure` is `Equatable`-based so it compares by value in tests.
- **Testing note**: dartz's `Right`/`Left` equality does not deep-compare a wrapped `List` — when asserting a `Right<Failure, List<T>>` in a test, `.fold()` and assert on the unwrapped list, not on the `Either` directly (see `risk_config_repository_impl_test.dart` for the pattern).

## STATUS
- `get`, `put`, `post` implemented and tested. `post` was added on demand for admin task 06 (`dual-control-access`'s `create`/`addApproval` are the first admin-side calls that need it — `panic-responders`'s `POST /api/panic/responder-pool` is only ever called by the future mobile app, not by admin, so it didn't force this sooner). REQUIRED next: `delete` when a task first needs it (not yet — add on demand, don't pre-build unused methods).
- `setToken(String?)` (decision 67) — sets a default token used automatically by `get`/`put`/`post` when no explicit `token` argument is passed; an explicit argument still overrides it. Added so admin login could set the session JWT once, without threading it through every existing repository call site (none of which pass a token today).

## REFERENCES

- [**README.md**](../README.md): Documentation navigation index.
- [**ARCHITECTURE.md**](../adr/ARCHITECTURE.md): Integration layer conventions this feature follows.
