# Offering help (A3) — apps/mobile

Third phase of the Report front in the app (A1 = `report-form.md`, A2 =
`report-feed.md`). Decisions 6/10/18/20/34/35
(`AI/docs/decisions/VGR-plano.md`); plan phase A3 in
`AI/docs/plans/plano-denuncia.md`; spec tasks 09/10/19 as amended
MA8-MA10 (`docs/specs/vgr/003-mobile-tactical-design.md`). API contract:
`POST /app-help-offers` (`api/docs/feature/reports.md`).

## Module (`app/modules/help_offer`)

Own Clean module mounted at `/offer/:id`, reached from the detail of an
OPEN report the viewer does not own. `HelpType` is the closed 5-value
enum of decision 10 (never free text); the entity carries
reportId + helpType + anonymous.

## Self-dealing guard (decision 20, amendment MA8)

The spec keyed the guard on `IdentityBloc.currentUserId == reporterId`,
but the mobile MVP has no login and the API never exposes `reporterId`
(41). The ownership signal is decision 134's: this device holds the
report's `clientKey` in `MyReportsStore`, injected into the domain as an
`OwnsReport` port. It runs TWICE by design:

- **bloc, on start** — an own report renders the form DISABLED with a
  message (spec acceptance: disabled, not just rejected). This also
  covers a crafted deep link straight to `/offer/:id`.
- **usecase, before the repository** — the last line before the network;
  emits `SELF_DEALING` without ever calling the API.

The detail page additionally never shows the "Offer help" button unless
`access == public && status == 'open'` — the owner sees offers instead
(20), a participant already offered (one per report), and a resolved
case takes no new offers (18, server answers 422).

## Anonymous offers (decisions 34/35, amendment MA9)

No session = anonymous offer, accepted in full (35). The
reward-ineligibility notice (34) renders for EVERY anonymous helper
before submit and never blocks it; it narrows to reward-bearing reports
when the reward front lands. With round-6 auth in place, a logged-in
helper will get the identification choice (6) — the bloc already
carries `anonymous` per submission.

## Data layer

`POST /app-help-offers` on the app plane (MA10) with
`{reportId, helpType, anonymous}`; 201 answers `helpOfferId`. Offers do
NOT ride the offline queue — they respond to a live case someone else
owns, so a transport failure surfaces as `OFFLINE` and the user retries.
A second offer on the same report is the API's 409 `DUPLICATE`,
translated by code (80/83). No `listByReport`: offers are only read
inside `GET /app-reports/:id`, masked server-side by tier (40/41/60).

After a successful offer the detail reloads, so the owner-visible
timeline event (`help_offered`, identity-free) and any state change
show up.

## Tests

+19 (mobile 79 total): usecase (self-dealing Left without repository
call, pass-through, failure surface), repository (wire body, 409, OFFLINE
never-queued), bloc (blocked without usecase, blocked ignores submit,
select→submit, no-selection no-op, failure keeps selection), form page
(disabled-with-message own report, anonymous notice + still-submittable,
single-select behavior, duplicate error retryable, done seam), detail
page (offer button for public open, absent for owner and resolved).
Suites: core 31, admin 79, mobile 79 — all green.
