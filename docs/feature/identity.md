# Identity

## OVERVIEW
Shared identity state (Role, AnonymityMode) consumed by every feature module in both `apps/mobile` and `apps/admin`. Lives in `packages/core` — REQUIRED for any module that needs to know who the current user is or how they're allowed to present themselves.

## STRUCTURE
```
packages/core/lib/src/identity/
├── domain/
│   ├── role.dart             # Role enum: anonymous, reporter, helper, police
│   ├── anonymity_mode.dart   # AnonymityMode enum: anonymous, identifiedNoReward, identifiedWithReward
│   └── identity_state.dart   # IdentityState — role + anonymityMode + token (nullable), Equatable
└── presentation/
    ├── identity_event.dart   # IdentityEvent — ProviderLoginCompleted (role, anonymityMode, token?) so far
    └── identity_bloc.dart    # IdentityBloc — defaults to Anonymous, updates on ProviderLoginCompleted
```

Exported via `packages/core/lib/core.dart`.

## STATUS
- `IdentityBloc` implemented with default state and `ProviderLoginCompleted` handling.
- `IdentityState.token` (decision 67) — the JWT from whichever login flow fired `ProviderLoginCompleted`. `apps/admin`'s login is the first thing that sets it (see `auth.md`); `apps/mobile`'s OAuth/OTP flow will set it the same way once built.
- REQUIRED next: `AuthenticateWithProviderUsecase` (mobile task 17) is what actually fires `ProviderLoginCompleted` for end users — not yet implemented.
- Role transition to `police` has no producing usecase yet (deferred, decision 12).

## REFERENCES

- [**README.md**](../README.md): Documentation navigation index.
- [**ARCHITECTURE.md**](../adr/ARCHITECTURE.md): module/layer conventions this feature follows.
