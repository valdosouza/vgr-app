# Masked chat (C2) — apps/mobile

Mobile side of the chat between reporter and helper (decision 54; round
12, decisions 168–177 in `AI/docs/decisions/VGR-plano.md`; plan
`AI/docs/plans/plano-chat.md` §4). C1 (API, `api/docs/feature/chat.md`)
is what this codes against; C3 (panel reading under `chat_evidence`,
decision 175) is a separate front. Uncommitted, awaiting review.

## What the app NEVER decides

- **Identity (170).** Every participant arrives as an opaque
  `participantToken` + `role` + `displayName` (null unless the API chose
  to send one). The screens render `displayName ?? role label` — no
  lookup, no fallback, no name for the reporter, ever. A helper's own
  thread labels the other side by ROLE because the route says so; the
  owner's list hands the conversation the participant it received.
- **Eligibility (169).** The "Chat" button on the detail exists ONLY when
  the served view carries `chat` (`ReportViewEntity.chat` →
  `ReportChatFacetEntity`): owner `{threads, unread}`, helper participant
  `{threadId, unread}` — `threadId` null still gets the button, the first
  message creates the thread (173). No facet → no button.
- **Closed (173).** `closed` is served on every page/summary; the page
  replaces the composer with `chat.closedNotice` and keeps reading.
- **Time (174).** Timestamps are rendered as served (already degraded by
  tier) with the same `YYYY-MM-DD HH:MM` cut the detail uses. No read
  receipt exists anywhere.

## Module (`app/modules/chat`, mounted at `/chat` BEFORE `/`)

| Route | Page | Who |
|---|---|---|
| `/chat/threads/:reportId` | `ChatThreadsPage` — one row per helper: label/served name, last message time, unread `VgrBadge`, closed marker; empty and error states | owner |
| `/chat/:reportId/thread/:threadId` (`new` = no thread yet) | `ChatConversationPage` — bubbles by served `mine`, pending/failed markers, composer, closed notice | both |

`ChatConversationArgs {otherRole, otherName}` travels as Modular
`arguments` from the list; a deep link without it labels the other side
by role only.

## Data layer

- `ChatRepositoryImpl`: `GET /app-chat/:reportId/threads`,
  `GET /app-chat/threads/:threadId/messages?after=&limit=` (cursor =
  highest `messageId` shown, default 50). The anonymous reporter's
  ownership rides `x-client-key` from `MyReportsStore` exactly like the
  report detail (134/169) — which is why `fetchMessages` takes the
  `reportId` too; a logged-in user carries the bearer via `ApiClient`.
- `send()` never calls the API: it enqueues **`chat.post`** on the
  `OfflineQueueService` with an app-generated UUID v4 `clientKey` (172/137)
  and answers the optimistic `pending` bubble. Registered in
  `app_module.dart` next to `ReportQueueTasks`.
- `ChatQueueTasks.post` handler: `POST /app-chat/threads/:threadId/messages`
  or, when `threadId` is null, `POST /app-chat/:reportId/messages`
  (find-or-create, 173). 201 and a 200 replay both **settle**; 422
  `CONTACT_NOT_ALLOWED` / 409 `CHAT_CLOSED` / 451 **fail the bubble and
  drop the task** — the API judged, a retry cannot succeed (same rule as
  `report_queue_tasks.dart`); 5xx and transport errors keep the task.
  Outcomes reach the open screen through `ChatSendOutcomes` (broadcast
  bus, one per app).

## Delivery (172)

`ChatConversationBloc` loads the first page, then subscribes to an
injectable ticker (`chatPollInterval` = 5 s) and fetches `after=<lastId>`
on every tick, appending only what is new. A served message whose
`clientKey` matches a pending bubble replaces it (the poll may beat the
queue outcome — no duplicates). Polling stops on `ConversationPaused`
(the page's `WidgetsBindingObserver` on paused/inactive/hidden) and on
bloc close; `ConversationResumed` polls at once and subscribes again.
Never in background. A helper with no thread polls nothing until the
first message settles with a `threadId`.

## Anti-contact mirror (171/154)

`VgrValidators.noDirectContact` (`packages/vgr_validators`, see
`validators.md`) reproduces `api/src/shared/chat/contact-filter.ts` rule
by rule with the SAME fixtures. The composer runs `required`,
`maxLength(1000)` (`chatMaxLength`, mirrors `CHAT_MAX_LENGTH`) and
`noDirectContact` BEFORE enqueueing; a hit shows
`core.fieldErrors.CONTACT_NOT_ALLOWED {kind, match}` under the field and
nothing is queued. The server re-checks regardless; its refusal arrives
on the bubble through the same key.

## Anonymous helper (169)

`HelpOfferFormPage` shows, for a helper WITHOUT a session, a second line
in the anonymous card (`offer-anonymous-no-chat-notice`,
`offer.anonymousNoChatNotice`) BEFORE submitting: no account, no chat —
same pattern as the reward notice (34). It never blocks the offer.

## Design system additions (133)

`VgrChatBubble` (side by `mine`, `sent|pending|failed` status with a
translated label, theme colors), `VgrChatComposer` (multi-line field +
send icon button with required tooltip, `maxLength` enforced at input),
`VgrChatMessageList` (bottom-anchored list), `VgrBadge`; icons
`VgrIconName.chat` / `.send`. Guard test stays green.

## Tests

+56 mobile (144 → 200): entities (mapping incl. `displayName: null`,
purged, failure code precedence), repository (paths, owner header/no
header, query defaults, enqueue payload, never-direct-API), queue task
(thread/report route, header, 201/200 settle, 422/409/451 fail without
retry, 5xx/transport keep), threads bloc, conversation bloc (initial +
poll append, transient tick failure, optimistic → settle, fail, poll/
outcome dedupe, no-thread → polling after settle, closed refuses send,
pause/resume), threads page, conversation page (roles not names, local
phone block, pending → settled, refused reason, closed notice, error),
detail button per facet (owner/helper/`threadId: null`/absent), offer
form notice, entity facet. +49 `vgr_validators` (42 → 91): the API spec
fixtures one by one. +8 `vgr_widgets` (11 → 19).
