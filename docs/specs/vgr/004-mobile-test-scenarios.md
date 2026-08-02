# Test Scenarios — mobile

**Domain:** vgr
**Project:** mobile
**Framework:** flutter_test, integration_test, mocktail (per `docs/adr/TESTS.md`)

## 1. Unit Tests

### 1.1 Entities (Aggregates/Aggregate Roots equivalent)

**ReportEntity**
- [ ] Should create ReportEntity successfully when category is set and freeTag is null
- [ ] Should create ReportEntity successfully when freeTag is set and category is null
- [ ] Should reject construction when both category and freeTag are null
- [ ] Should consider two ReportEntity instances equal when id, category, and freeTag match

**HelpOfferEntity**
- [ ] Should create HelpOfferEntity successfully when helperId differs from the report's reporterId
- [ ] Should carry the selected HelpType unchanged after construction

**DirectionEstimateEntity**
- [ ] Should create DirectionEstimateEntity successfully when probabilityByDirection values sum to 1.0
- [ ] Should reject construction when probabilityByDirection values do not sum to 1.0

**RewardEntity**
- [ ] Should create RewardEntity successfully from a JSON payload containing only id, reportId, and offer — no category or tag fields
- [ ] Should fail fromJson gracefully if a category or tag field is unexpectedly present (structural drift guard)

### 1.2 Value Objects / Types

- [ ] Should create RewardOfferType successfully for each of: money, perk, reciprocity, none
- [ ] Should behave correctly in Set/Map collections for ReportEntity, HelpOfferEntity (Equatable-based equality)
- [ ] Should return a new instance without modifying the original when a DirectionEstimateEntity is updated with a new sighting result

### 1.3 Usecases

**SubmitReportUsecase**
- [ ] Should return Right(id) when submission succeeds while online
- [ ] Should enqueue to OfflineQueueService and return Right(pendingLocalId) when the device is offline
- [ ] Should return Left(Failure) without enqueueing when the API returns a validation error (422)

**ListNearbyReportsUsecase**
- [ ] Should return Right(List<ReportEntity>) for a given page and ordering
- [ ] Should return Left(Failure) when the repository call fails

**SubmitHelpOfferUsecase**
- [ ] Should return Left(SelfDealingFailure) without calling the repository when helperId equals the report's reporterId
- [ ] Should return Right(id) when helperId differs from the report's reporterId and the call succeeds

**LogDirectionSightingUsecase**
- [ ] Should return Right(DirectionEstimateEntity) synchronously after a successful call — no intermediate loading state left dangling
- [ ] Should return Left(Failure) when the API call fails, without partially updating local state

**OfferRewardUsecase / AllocateRewardUsecase**
- [ ] Should only be invokable when IdentityBloc.currentUserId equals the report's reporterId (checked before repository call)
- [ ] Should return Left(UnregisteredReporterFailure) without calling the repository when the current user's AnonymityMode is anonymous (decision 33)

**AuthenticateWithProviderUsecase**
- [ ] Should return Right(void) and update IdentityBloc when the native SDK flow succeeds, for each of Google, Apple, Facebook
- [ ] Should return Left(Failure) without updating IdentityBloc when the native SDK flow is cancelled or fails
- [ ] Should return Right(void) when a valid OTP code is submitted for the phone/WhatsApp method (decision 31)

### 1.4 Blocs (buildable + one-shot states)

**ReportBloc**
- [ ] Should emit [ReportSubmitting, ReportSubmitted] when submission succeeds online
- [ ] Should emit [ReportSubmitting, ReportQueuedOffline] when submission is deferred offline
- [ ] Should emit [ReportSubmitting, ReportSubmissionFailed] when the usecase returns a Failure

**NearbyReportsFeedBloc**
- [ ] Should emit [FeedLoading, FeedLoaded] with the first page on initial fetch
- [ ] Should emit [FeedLoaded] with an appended, non-duplicated page when a next-page event is dispatched
- [ ] Should emit [FeedEmpty] when the first page returns zero Reports
- [ ] Should emit [FeedError] when the usecase returns a Failure

**HelpOfferBloc**
- [ ] Should emit a one-shot HelpOfferBlockedSelfDealing state without calling the usecase when the current user is the report's reporter

**DirectionSightingBloc**
- [ ] Should emit [SightingLogging, SightingLogged(estimate)] synchronously, never leaving SightingLogging as a terminal state

**RewardBloc**
- [ ] Should expose allocation-enabled state only when IdentityBloc reports currentUserId == report.reporterId
- [ ] Should emit a one-shot ActionSuccess state when RewardAllocationSubmitted resolves successfully
- [ ] Should emit a one-shot RewardOfferBlockedAnonymousReporter state, prompting login, when an anonymous user attempts to offer a Reward (decision 33)

**IdentityBloc**
- [ ] Should emit an updated IdentityState reflecting Role=reporter/helper and the chosen AnonymityMode after ProviderLoginCompleted
- [ ] Should default to Anonymous on app start before any login action occurs

## 2. Integration Tests

### 2.1 Repositories

**ReportRepositoryImpl**
- [ ] Should convert a successful API call into Right(ReportEntity list) for listNearby
- [ ] Should convert an API exception into Left(Failure) for submit
- [ ] Should route submit() through OfflineQueueService.enqueue when the device is offline, without calling the API client

**HelpOfferRepositoryImpl**
- [ ] Should convert a successful submit call into Right(id)
- [ ] Should convert a 403 self-dealing API response into Left(SelfDealingFailure)

**DirectionSightingRepositoryImpl**
- [ ] Should convert a successful logSighting call into Right(DirectionEstimateEntity) with the response body mapped in full

**RewardRepositoryImpl**
- [ ] Should convert a successful allocate call into Right(void)
- [ ] Should convert a 409 (Report not yet Resolved) response into Left(Failure) with a message the UI can display verbatim

### 2.2 Usecases (with real repository implementations, mocked ApiClient)

- [ ] Should execute SubmitReportUsecase → ReportRepositoryImpl → ApiClient.post → Right(id) end-to-end when the mocked API returns 201
- [ ] Should execute SubmitHelpOfferUsecase → HelpOfferRepositoryImpl → ApiClient.post → Right(id) end-to-end for a valid non-self-dealing submission

### 2.3 External Integrations

> Only the vgr-api HTTP boundary is mapped for the mobile project at MVP scope (per `002-context-map.md`). Geolocation plugin integration is marked N/A until decided (see `docs/adr/ARCHITECTURE.md` open item).

## 3. Functional Tests (widget / integration_test)

### 3.1 Happy Path Flows

- [ ] **Should submit a Report and navigate to confirmation when a user fills the ReportFormPage with a valid Category**
  - Given: ReportFormPage is open with core.ApiClient mocked to return 201
  - When: the user selects a Category, fills required fields, and taps Submit
  - Then: ReportBloc emits ReportSubmitted and the page navigates to the confirmation/detail route

- [ ] **Should show a queued-offline banner when submitting a Report without connectivity**
  - Given: ReportFormPage is open with connectivity mocked as offline
  - When: the user submits a valid Report
  - Then: ReportBloc emits ReportQueuedOffline and the banner is visible

- [ ] **Should load and paginate the NearbyReportsFeedPage**
  - Given: the feed API is mocked to return 2 pages of Reports
  - When: NearbyReportsFeedPage is opened and the user scrolls to the end
  - Then: page 1 renders first, then page 2 appends without duplicate entries

- [ ] **Should disable HelpOffer submission for a user viewing their own Report**
  - Given: IdentityBloc reports currentUserId equal to the opened Report's reporterId
  - When: HelpOfferFormPage is opened for that Report
  - Then: the submit control is disabled and a message is shown, matching HelpOfferBlockedSelfDealing

- [ ] **Should update the DirectionEstimateWidget immediately after logging a sighting**
  - Given: a Report detail page showing a 50/50 DirectionEstimateWidget
  - When: the user logs a Direction Sighting and the mocked API returns an updated estimate
  - Then: the probability bar re-renders with the new values before the loading indicator disappears

- [ ] **Should log in and update IdentityBloc when a user taps the Google/Apple/Facebook button**
  - Given: LoginPage is open with the native SDK mocked to succeed
  - When: the user taps one of the three social buttons
  - Then: ProviderLoginCompleted is emitted and the app navigates past LoginPage

- [ ] **Should log in via phone/WhatsApp OTP**
  - Given: LoginPage is open and the user has requested an OTP code
  - When: the user enters the correct code
  - Then: IdentityBloc updates and the app navigates past LoginPage

- [ ] **Should warn an anonymous Helper that they won't be reward-eligible before they submit a Help Offer**
  - Given: HelpOfferFormPage is open for a Report with an active Reward, current user is Anonymous
  - When: the page renders
  - Then: a reward-ineligibility notice is visible, and the submit control remains enabled (decision 34)

### 3.2 Alternative and Error Flows

- [ ] Should show a form-level error when SubmitReportUsecase returns Left(Failure) for a validation error
- [ ] Should show an empty-state illustration when NearbyReportsFeedBloc emits FeedEmpty
- [ ] Should show a standardized error message when the API returns 404 for a Report that no longer exists
- [ ] Should keep RewardBloc's allocation controls hidden (not merely disabled) for any non-Reporter viewer
- [ ] Should show a login prompt (not a raw error) when an anonymous user taps "Offer Reward" (decision 33)
- [ ] Should show a clear error when the social SDK flow is cancelled or fails, without leaving LoginPage in a stuck loading state

### 3.3 Security Scenarios

- [ ] Should never render AccountabilityLogEntry-shaped fields (IP, device metadata) anywhere in the UI, even in debug/error overlays
- [ ] Should mask or omit sensitive form fields from any crash/log report generated client-side
- [ ] Should prevent navigating to another user's HelpOffer detail page via a manually crafted deep link (route guard test)

## Save

Saved to: `D:\ProjetoVGR\app\docs\specs\vgr\004-mobile-test-scenarios.md`
