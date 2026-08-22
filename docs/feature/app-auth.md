# App auth (email+password + Google) — apps/mobile

Mobile side of decisions 119/122-124/151/152
(`AI/docs/decisions/VGR-plano.md`); API contract:
`api/docs/feature/app-auth.md`. Closes round-6 items 2–3 of
`AI/docs/plans/plano-auth-usuarios.md` — before this, the API's
`/app-auth` had register/login/refresh/verify-email fully built but
**no mobile screen ever called it**.

## Scope: email+password, plus Google once credentials existed (decision 152)

Apple/Facebook and phone/WhatsApp OTP are absent by design, not by
oversight — decision 152 defers Apple/Facebook until real OAuth
credentials exist in those consoles (only then can the client SDK's
actual token format be discovered), and OTP stays blocked on the
round-6 commercial pendency (decision 120, same shape as the PSP's
decision 59). Google shipped in a later slice of the same session,
once a Web-type OAuth client id existed — `AuthRepository` grew
`loginWithProvider` additively, exactly as decision 152 anticipated
(`loginWithProvider` on the API already accepted a pre-verified
identity; wiring one provider never touched the others).

## Google sign-in (`domain/gateway/social_sign_in_gateway.dart`)

`SocialSignInGateway` is a port (same shape as `report`'s
`PhotoGateway`) so the `google_sign_in` SDK never touches
domain/presentation — only `data/google_sign_in_gateway.dart` imports
it. `GoogleSignInGatewayImpl.signInWithGoogle()` initializes
`GoogleSignIn.instance` once (memoized future, same pattern as
`ApiClient._ensureFreshToken`'s shared in-flight renewal) with the
**Web-type** OAuth client id as `serverClientId` — that is what makes
the SDK issue an ID token the API can verify (its `aud` has to be a
Web client, not the Android/iOS ones registered for the native
handshake). Returns the raw ID token, or null if the user cancelled
(`GoogleSignInExceptionCode.canceled`) — the usecase and bloc both
treat null as a silent no-op, never an error, mirroring the photo
picker's cancel contract.

`LoginBloc` gained `LoginWithGooglePressed`, sharing `LoginSubmitting`/
`LoginReady`/`LoginSuccess` with the password flow — a successful
Google session runs the exact same `_onSessionIssued` side effect
(persist refresh token, `IdentityBloc.add(ProviderLoginCompleted(...))`)
password login does, so the rest of the app cannot tell which method
was used. The button is hidden during the two-factor step (Google
never has one) and disabled while submitting.

**Not needed and deliberately not added**: the Firebase SDK / Google
Services Gradle plugin. A Firebase project was only a convenient way
to register OAuth client ids in the Google Cloud console; nothing in
the app loads Firebase (decision 143 — no external SDK without a
port, and this app has neither). `android/app/google-services.json`
is gitignored for that reason.

**Android signing note**: the machine-wide `~/.android/debug.keystore`
is shared by every Android app built on a given computer, which
collided with an unrelated app's registered SHA-1 while setting up the
OAuth client. Fixed with a project-scoped debug keystore
(`android/app/vgr-debug.keystore`, gitignored) wired into
`android/app/build.gradle.kts`'s debug `signingConfig` — see that
file's comment if this needs revisiting (e.g. registering a NEW
machine's debug SHA-1, or adding the release keystore later).

**iOS is not configured** — no iOS OAuth client or bundle
registration was created this session; Google sign-in only works on
Android today.

## Module (`app/modules/auth`)

```
domain/entity/app_session_entity.dart   # accessToken + refreshToken + accountId
domain/repository/auth_repository.dart
domain/usecase/                         # thin wrappers, one per repository method
data/auth_repository_impl.dart          # POST /app-auth/*, sets ApiClient's token on success
data/session_bootstrap.dart             # boot-time silent refresh (see below)
presentation/bloc/{register,login,email_verification,account}_bloc.dart
presentation/page/{register,login,email_verification,account}_page.dart
```

Mounted at `/auth` (`app_module.dart`) — routes are `/auth/register/`,
`/auth/login/`, `/auth/verify-email/`, `/auth/account/`.

## Session persistence (decision 122)

The app has no "keep me signed in" checkbox like the admin panel
(decision 73) — a mobile device's session is expected to survive a
relaunch, so the refresh token is **always** persisted via
`LocalPrefs.appRefreshToken`, a key kept deliberately separate from
the panel's `sessionToken` (decision 119: the two planes never share
storage). The short-lived access token itself never touches disk,
only `ApiClient`'s memory.

`AppWidget` (now a `StatefulWidget`) calls
`session_bootstrap.dart#restoreAppSession` in `initState`,
fire-and-forget, the same spirit as the offline queue's boot flush in
`app_module.dart`. It rotates a stored refresh token into a fresh
session via `POST /app-auth/refresh`; a missing or dead token is
swallowed — the app just starts anonymous, same outcome as any other
expired-session case the API already 401s.

## Entry points (decision 123 — auth is opt-in, never a gate)

The feed's app-bar action (`nearby_feed_page.dart`) is the only entry
point: a person icon that reads `IdentityBloc.state.token` — `null`
opens `/auth/login/`, non-null opens `/auth/account/`. Nothing else in
the app requires a session; reporting, browsing the feed, and
anonymous help all work exactly as before this module existed.

A second entry point lives on the identified-helper "offer help"
success screen (`help_offer_form_page.dart`, from the reward-onboarding
slice) — unrelated to this module's routes, but the same
`IdentityBloc.state.token` check.

## Login's two-factor branch (decision 124)

Unlike the panel, TOTP is never mandatory. `LoginBloc` treats the
API's `TWO_FACTOR_REQUIRED` failure code as a state transition
(`LoginTwoFactorRequired`), not an error — the form swaps to a code
field carrying the already-typed email/password so the user never
retypes them.

## Email verification (decision 151)

`EmailVerificationBloc` is a plain two-step flow: send → code field →
confirm. One subtlety: the API reuses the generic `UNAUTHORIZED`
error code for "wrong or expired code" (same shape as the panel's
password-recovery flow) — `core.errors.UNAUTHORIZED`'s translation
reads "session expired", which would be actively misleading here. The
page shows `failure.message` (the API's literal "Invalid or expired
code") instead of the code-translated `failureText()` for that one
field, mirroring `apps/admin`'s `RecoveryBloc` precedent for the same
reused-code situation.

## Sign-out (`account_page.dart`)

The API only exposes one shape: revoke everything
(`POST /app-auth/sign-out-everywhere`, decision 122). `AccountBloc`
treats it as best-effort — a failed/expired call still clears the
local refresh token and resets `IdentityBloc` to anonymous, because a
sign-out that can fail closed into a stuck "logged in" state would be
worse than a false negative on the API's book-keeping.

## IdentityBloc role on login

`Role.reporter` is used as the "identified app user" signal on
successful register/login/restore — the `Role` enum's own doc
comment describes it as "capacity within a report", which does not
quite fit a plane-wide login, but it is the closest existing value to
"not anonymous" and it is what `report_form_page.dart`'s
`isAnonymousUser` check already reads. Introducing a cleaner concept
for this is future work, not part of this slice.

## Tests

+32 in the auth module for email+password (repository: register/login/
refresh/verify/sign-out wire bodies and error mapping; blocs: success
wiring incl. `LocalPrefs` + `IdentityBloc` side effects, two-factor
branch, wrong/duplicate/offline failures, no-op guards; pages: consent
gate, done seams, two-factor round trip, translated-vs-raw error
display). +2 in `nearby_feed_page_test.dart` for the login/account
action swap. +8 more for Google (bloc: success/cancel/failure; page:
button success, hidden during two-factor). `flutter build apk --debug`
verified the new `google_sign_in` dependency doesn't break the Android
build. Suites: core 31, admin 126, mobile 141 — all green, analyzer
clean.
