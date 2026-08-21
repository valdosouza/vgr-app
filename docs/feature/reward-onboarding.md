# Reward payout onboarding — apps/mobile

Mobile screen for the helper's registration as a reward recipient
(decisions 104/143 in `AI/docs/decisions/VGR-plano.md`; API contract:
`api/docs/feature/reward.md`'s `onboardAsRecipient`). Closes the last
open item of the "Deliberately not built in this slice" list for the
reward domain — the API endpoint existed since 2026-08-21, no screen
drove it until now.

## Module (`app/modules/reward_onboarding`)

Own Clean module mounted at `/reward-onboarding/`. Unlike `help_offer`,
it is not tied to a report — a helper registers once and can then be
targeted by any future reserve — so it takes no route parameter and is
reachable from any identified-helper context, not just one case.

Entry point today: the "Offer help" success screen
(`help_offer_form_page.dart`), shown only when the helper is identified
(`IdentityBloc.state.token != null`) — an anonymous offer can never
claim a reward (decisions 34/35), so the link only makes sense there.

## Status-first flow

`GET /app-reward/onboarding` runs before the form ever renders
(`OnboardingStarted`): an already-onboarded account (one profile per
account, decision 143) goes straight to `OnboardingAlreadyDone` instead
of a form that could only 409. The same mapping catches a submit-time
`DUPLICATE` (a second device or a race), so the user never sees a raw
error for this specific case.

## KYC form

Field-for-field mirror of the API's `onboardRecipientDto` (zod):
legal name, email, tax id, mobile phone, monthly income, and a street /
number / neighborhood / postal code address. Client-side validation is
presence-only (plus a positive-number check on income) — the server
stays the authority; this only saves a round trip, same pattern as
`report_form_page.dart`.

**None of this is persisted or logged by the VGR** (decision 143): the
data goes straight to `POST /app-reward/onboarding`, which the API
forwards to the payment rail and only keeps the opaque
`railRecipientId`. The intro text says so explicitly, since the form
otherwise looks exactly like it is asking for personal data the app
would keep.

## Tests

+20 (mobile 99 total): repository (status read, submit wire body,
DUPLICATE and OFFLINE surfacing), bloc (form vs already-done branch on
status, load error, submit success/duplicate/other-failure, submit
before ready is a no-op), page (already-done view skips the form, fill
→ submit → success, empty-fields inline errors, DUPLICATE routes to
already-done, other failure keeps the form with an inline error, done
seam). Plus 2 in `help_offer_form_page_test.dart` for the entry link's
visibility (identified vs anonymous). Suites: core 31, admin 79, mobile
99 — all green.
