# Report form (A1) — apps/mobile

First feature of `apps/mobile` (until now a bare skeleton): the submission
screen of the Report front. Decisions 134-142 (`AI/docs/decisions/VGR-plano.md`);
plan phase A1 in `AI/docs/plans/plano-denuncia.md`; spec tasks 03-06/16/21 as
amended (MA1-MA7 block in `docs/specs/vgr/003-mobile-tactical-design.md`).
API contract in `api/docs/feature/reports.md` + `media.md`.

## Shape

`lib/app/modules/report/` — Clean Architecture module, admin pattern:

- **domain**: `ReportInput` (XOR category/freeTag + mandatory `subject`,
  decision 140 — the invariant throws at construction), `PhotoDraft`
  (per-photo `keepOriginal` + the EXIF-warning version the reporter saw,
  decisions 86/130), `CategoryFormSchemaEntity` (decision 47), ports
  `LocationGateway`/`PhotoGateway` (plugins stay swappable),
  `SubmitReportUsecase`.
- **data**: `ReportRepositoryImpl` (submit + category-forms with local
  cache), `ReportQueueTasks` (offline chain), geolocator/image_picker
  adapters.
- **presentation**: `ReportFormBloc` + `ReportFormPage` (all `Vgr*`,
  decision 133 — guard test replicated into `apps/mobile/test`).

Bootstrap (`main.dart`/`app_module.dart`) mirrors apps/admin: EasyLocalization
(en-US source, pt-BR), ModularApp; the report form is the app's front door
while A2 (feed) doesn't exist.

## Submission (decisions 28/32/123/137)

- `clientKey` (UUID) is born with the DRAFT and never changes across
  retries — user tap, queue replay, anything: the API answers 200 with the
  same report (decision 137). A new draft (post-success "new report") gets
  a new key.
- Online: `POST /app-reports`; photos NEVER ride the submit body — they are
  enqueued and uploaded in background (decision 123: "a denúncia nunca
  espera").
- Transport failure: the WHOLE draft (photos included) is queued and the
  user sees the queued state as a promise, not an error. An API rejection
  (validation/451) is surfaced and never enqueued — a retry would fail
  identically.
- The mobile MVP has no login screen (social adapters are round 6 of
  [auth]); every report goes out `anonymous=true`. The identity switch is
  wired for when sessions exist (`IdentityBloc.role != anonymous`).

## Offline queue (`packages/core`, spec task 16 — decision 28)

`OfflineQueueService`: persisted FIFO (shared_preferences), generic
per-kind handlers, strict order — a retryable failure (transport/5xx)
STOPS the flush so a dependent task never runs before its predecessor; a
judged refusal (4xx) drops the task. Flush on boot + periodic retry
(30s, no connectivity plugin: a timer also heals captive portals and
API-down-radio-up). Report chain: `report_submit` → `report_media_upload`
(per photo) → `report_media_attach` (with the `x-client-key` bearer
header, decision 134). Every step is replay-safe on the API side except
the raw upload — a crash between upload and attach re-uploads and the
first blob dies as an orphan in 48h (decision 136, by design).

## Dynamic form (decision 47)

`GET /app-reports/category-forms` is fetched on open and cached locally;
offline the cache renders the same form and pre-validates `required`
fields client-side (the server stays the authority on submit). Field types
map string/number/boolean/date → text/digits/checkbox/text-with-hint;
labels are the admin-configured field names (no translation in the MVP).

## Position (decisions 7/135)

Mandatory: submit stays disabled until `LocationGateway` answers; denial
is a retryable state with its own message. The exact position leaves the
device only in the submit body — nothing else ever carries it.

## Photos and EXIF (decisions 129/130/139)

Up to 10 photos (client-side mirror of MEDIA_MAX_PER_REPORT). Tapping a
thumbnail toggles "keep original": turning it ON opens the approved v1
warning (`exif-warning/v1`, decision 139) — reinforced with the extra
paragraph in the anonymous flow — and records the version seen; default
is always discard. Captured bytes are sent as captured (the server strips
the normalized variant; the encrypted original survives only when asked).
HEIC→JPEG conversion belongs to the capture gateway and is not wired
while the MVP targets Android (iOS build prerequisite, noted in the port).

## Tests

37 in `apps/mobile/test` (entity XOR/round-trip, repository online/queued/
422-never-enqueued/cache, offline chain end-to-end with header assert,
bloc lifecycle/photos/clientKey-stability, page widget tests incl. EXIF
dialog and queued banner, design-system guard) + 8 in `packages/core`
(queue FIFO/retry-stop/drop/chaining/persistence). Suites: core 31,
admin 79, mobile 37 — all green.

New mobile deps: shared_preferences, uuid, geolocator, image_picker.
New Vgr widgets: `VgrPhotoThumb`, `VgrWrap`, icons image/camera/gallery.
`ApiClient` gained `postMultipart` and per-call `headers` (additive).
