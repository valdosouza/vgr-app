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
enum of decision 10 (never free text); since HT2 (decision 208) the
entity carries reportId + `helpTypes: Set<HelpType>` (one to five) +
anonymous. A second route, `/offer/:id/types/:offerId`, reuses the same
form to edit the fronts of the helper's own existing offer (211 — see
"Several fronts per offer" below).

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
when the reward front lands. The logged-in helper's identification
choice (6) arrived in round 21 — see "Showing the helper's name" below.

Since C2 (decision 169) the same card also warns the anonymous helper that without an account there is NO chat with the reporter (`offer-anonymous-no-chat-notice`, `offer.anonymousNoChatNotice`) — before submitting, never blocking; see `chat.md`.

## Showing the helper's name (H2, 2026-10-05 — decisions 237/238)

The browser test of 2026-10-05 found that a logged-in helper was ALWAYS
named to the reporter: the form sent `anonymous: false` whenever there
was a session, and the choice decision 170 relies on had never been
built. Round 21 (`AI/docs/decisions/VGR-plano.md` 237-239) made naming
oneself an explicit opt-in that first passes the category's risk
analysis, as the reporter's identity does:

- **Low / medium tier** — the form shows an UNCHECKED
  `offer-show-name` box ("Show my name to the reporter") with
  `offer-show-name-warning`: if in doubt leave it unchecked, a report can
  be fake, made just to find out who helps. Unchecked → the offer goes
  `anonymous: true`.
- **High tier** — no box at all: `offer-high-risk-name-notice` says the
  name is never shown to the reporter or other helpers, even if the
  helper wants it (40/60). The offer goes `anonymous: true`; the server
  masks high tier anyway, so the app is only a mirror.
- **Unknown tier** — the detail page pushes `/offer/:id` with the case's
  `tier` as `arguments`; a bare deep link has none and fails closed:
  `offer-hidden-name-notice`, offer hidden.
- **No account** — no name to choose; the anonymous card above is
  unchanged. **Editing fronts** (211) never touches the name.

Hidden is social, not forensic: the account stays on the offer, so a
hidden helper can still chat (173), be rated (180) and receive a reward
(60) — the success view keeps the reward-onboarding link for every
helper with an account. The API side (H1) treats an absent `anonymous`
as hidden too (`api/docs/feature/reports.md`, "Hidden by default").

## Several fronts per offer (HT2, 2026-09-19 — decisions 208-214)

Rodada 16 (`AI/docs/plans/plano-oferta-multitipo.md`) fixed what the
first two-actor test exposed: the form drew checkboxes but behaved like
radio buttons. Now:

- **Bloc**: `HelpOfferReady.selected` is a `Set<HelpType>`;
  `HelpOfferTypeToggled` adds or removes ONE front, never replacing the
  others; submit is a no-op (and the button disabled) with an empty set
  (208: minimum one). The wire body is `helpTypes: []` only (213).
- **Detail page**: every offer row lists all its fronts " · "-separated
  (`_helpTypesLabel`, `detail.helpType.*`), for the owner's `offers[]`.
- **"Change help types" (211)**: the `participant` view carries
  `myOffer { helpOfferId, helpTypes }` (API HT1 addendum of the same
  date) — the page renders a "Your offer" section
  (`detail-my-offer-types`) and, while the case is open, the
  `detail-edit-offer-types-button`, which pushes
  `/offer/:reportId/types/:offerId` with the current wire values as
  `arguments`. The form opens in edit mode (`HelpOfferEdit`): current
  fronts checked, "Save" instead of "Send offer", no anonymous notices
  (an edit is always identified — the server only serves `myOffer` to an
  account-holding participant), no self-dealing check. Save goes through
  `UpdateHelpOfferTypesUsecase` → `PUT /app-help-offers/:id/types`;
  success is `HelpOfferTypesUpdated` (`offer-updated-view`), and the
  detail reloads on return so the new set and the `help_offer_updated`
  timeline item show. A resolved case answers 422 (shown inline, form
  kept); someone else's offer 404. A resolved case shows the fronts
  read-only, no button.
- Unknown wire values from a newer API are ignored by `HelpType.fromWire`,
  never a crash.

## Data layer

`POST /app-help-offers` on the app plane (MA10) with
`{reportId, helpTypes, anonymous}`; 201 answers `helpOfferId`. Offers do
NOT ride the offline queue — they respond to a live case someone else
owns, so a transport failure surfaces as `OFFLINE` and the user retries.
A second offer on the same report is the API's 409 `DUPLICATE`,
translated by code (80/83). No `listByReport`: offers are only read
inside `GET /app-reports/:id`, masked server-side by tier (40/41/60).

After a successful offer the detail reloads, so the owner-visible
timeline event (`help_offered`, identity-free) and any state change
show up.

## Tests

H2 (2026-10-05): +5 form-page tests (mobile 433 total, all green) — an
account-holding helper starts hidden with the warning and still gets the
reward link; checking the box on a medium case sends `anonymous: false`;
high tier shows only the notice and sends hidden; an unknown tier fails
closed; no account shows no choice. The first four fail on the previous
form. Edit mode also asserts there is no name box.

HT2 (2026-09-19): mobile 428 total, all green — bloc (set accumulates,
toggle removes one, submit posts the whole set, empty set no-op, edit
mode opens with current set and PUTs to the same offer, empty edit
no-op, 422 keeps selection), usecase (`UpdateHelpOfferTypesUsecase`
refuses an empty set locally), repository (list body in decision 10's
order, PUT body/answer, unknown front ignored, 404, OFFLINE), form page
(two boxes stay checked and both go on the wire, unchecking the last
disables submit, edit mode title/checked/Save/no notices, save → updated
view → done seam, 422 inline), entity (`helpTypes` list, `myOffer`
facet through `copyWithOffers`), detail page (" · " join, participant
section + button hands over the offer, resolved read-only, owner has no
section).

Original A3 count: +19 (mobile 79 total): usecase (self-dealing Left without repository
call, pass-through, failure surface), repository (wire body, 409, OFFLINE
never-queued), bloc (blocked without usecase, blocked ignores submit,
select→submit, no-selection no-op, failure keeps selection), form page
(disabled-with-message own report, anonymous notice + still-submittable,
single-select behavior, duplicate error retryable, done seam), detail
page (offer button for public open, absent for owner and resolved).
Suites: core 31, admin 79, mobile 79 — all green.
