# Strategic Design — Problem Space

**Domain:** vgr
**Source:** `D:\ProjetoVGR\docs\decisions\VGR-plano.md` (17 recorded decisions)

## Section 1 — Event Storming

| # | Domain Event | Command | Aggregate | External Systems | Read Models |
|---|---|---|---|---|---|
| 1 | Report Submitted | SubmitReport | Report | Geolocation Service | NearbyReportsFeed |
| 2 | Reward Offered | OfferReward | Report | Payment/Perk Provider *(future — not in MVP)* | ReportDetailView |
| 3 | Help Offer Submitted | SubmitHelpOffer | HelpOffer | none | HelperQueueView |
| 4 | Helper Registration Completed | CompleteHelperRegistration | UserAccount | none | none |
| 5 | Direction Sighting Logged | LogDirectionSighting | Report | none | DirectionAggregationView |
| 6 | Help Offer Accepted | AcceptHelpOffer | Report | none | ReportDetailView |
| 7 | Report Resolved | ResolveReport | Report | none | ReportHistoryView |
| 8 | Reward Claimed | ClaimReward | Reward | Payment/Perk Provider *(future — not in MVP)* | RewardLedgerView |

Notes:
- Events 2 and 8 (reward money/perk settlement) reference an external Payment/Perk Provider that is **not decided** — decision 1 in VGR-plano.md documents reward as flexible (money, perks, reciprocity, or none), but no payment rail has been chosen. Treat as a boundary stub until decided.
- Event 5 (Direction Sighting Logged) is the mechanism behind decision 1's vehicle-theft example (aggregate multiple sightings before exposing direction, to prevent the offender from reverse-engineering that they're being tracked). It is distinct from the deferred predictive/push-notification feature (decision 11, explicitly out of MVP) — logging and aggregating raw sightings is MVP-compatible; predicting future position and pushing proactive notifications is not.
- "Anonymous Mode" and "Identity Disclosure" are not modeled as separate events — they are an attribute chosen at the moment of `SubmitReport` / `SubmitHelpOffer` (decision 6), not a state transition of their own.

## Section 2 — Subdomain Classification

| Subdomain | Type | Justification |
|---|---|---|
| Report Management | Core | The entry point and reason the app exists — differentiator is in allowing unrestricted report types (decision 3) |
| Help Matching (proximity + dynamic radius) | Core | The connection mechanism between people is the product's central hypothesis (decisions 2, 7) |
| Reward & Incentives | Core | Multi-type reward model (money/perks/reciprocity/none, case-dependent) is a deliberate differentiator, not a commodity payout feature (decision 1) |
| Identity & Trust (anonymity, anti-retaliation) | Core | Explicit, safety-critical design requirement called out by the product owner — most people don't engage for fear of retaliation (decision 6) |
| User Registration & Compliance | Supporting | Necessary to enable Core subdomains (reward claims, LGPD) but not itself a differentiator — could use standard auth patterns |
| Geolocation Primitives | Supporting | Raw geolocation (device position, distance calculation) is commodity; only the per-category dynamic radius **rule** is Core, the geolocation plumbing is Supporting |
| Direction Prediction & Push Notifications | Generic *(deferred)* | Explicitly out of MVP scope (decision 11) — when built, likely commodity ML/notification infra, not a differentiator |
| Police Validation Workflow | Generic *(deferred)* | Explicitly out of MVP scope (decision 12) |

## Section 3 — Ubiquitous Language Glossary

| Term | Definition | Notes |
|---|---|---|
| Report | A submission describing something happening that the reporter wants help with | Not limited to crime — decision 3 explicitly rejects a closed category list |
| Category | The nature-of-incident axis of a Report's classification (e.g. assault, missing person) | Curated list, seeded from the legacy app's icon set; see decision 9 |
| Subject Tag | The who/what-is-involved axis of a Report's classification (e.g. child, vehicle, animal) | Second axis of the two-axis taxonomy (decision 3) |
| Free Tag | A user-authored tag used when no existing Category/Subject Tag fits | Part of the hybrid taxonomy (decision 9) — avoid confusing with Category |
| Reporter | The person who submits a Report | May act anonymously or registered (decision 4) |
| Helper | A person who offers to assist with a Report | May be anonymous, registered without reward, or registered with reward (decision 4) |
| Help Offer | A Helper's candidacy to assist a specific Report, including the chosen Help Type | Distinct from the Report itself — one Report can have many Help Offers |
| Help Type | The kind of assistance a Helper selects when submitting a Help Offer (e.g. physical presence, remote guidance, forwarding to authorities) | Fixed list from decision 10 — not a free-text field |
| Dynamic Radius | The search/visibility radius for a Report, computed per Category rather than a fixed global value | Decision 7 — e.g. large and growing for lost pets, small for domestic violence |
| Reward | An optional incentive offered by the Reporter for help resolving a Report | Not necessarily money — decision 1 (perks, reciprocity, or none) |
| Anonymous Mode | A Reporter's or Helper's choice to withhold identity | Never forced — decision 6; core to the anti-retaliation requirement |
| Role | The capacity a user acts under: anonymous, reporter, helper, or police | Decision 4 — police is a validated tier, not a self-declared one |
| Resolution | The terminal state of a Report once the underlying situation is addressed | "Addressed" has no fixed definition — decision 5 explicitly leaves Help Type open-ended |
| Direction Sighting | A single crowd-sourced observation of which way a fleeing subject/vehicle went | Aggregated across multiple sightings before being surfaced, to prevent the offender from detecting the tracking (decision 1, example 5) |

## Section 4 — Socratic Questions

**Business Invariants and Consistency**
1. Can a Report exist in a "Resolved" state while it still has open, unaddressed Help Offers — and if so, what happens to those Helpers who haven't been notified the situation is over?
2. If a Reporter edits or retracts a Report after Help Offers already exist against it (e.g. changes the Category, or cancels a Reward), what happens to Helpers who committed based on the original terms?
3. Is there any rule preventing the same person from being both the Reporter and a Helper on their own Report (self-dealing to fraudulently claim a Reward)?

**Scalability and Performance**
4. When a densely populated area has hundreds of open Reports within a Helper's Dynamic Radius (decision 2's "ordered by most recent" scenario), is there pagination, or does the NearbyReportsFeed load everything matching the radius?
5. For Direction Sighting aggregation (vehicle theft, decision 1 example 5), how many concurrent sightings can arrive per second in a busy urban area, and does the aggregation logic run synchronously per request or as a background job?

**Security and Sensitive Data**
6. What specifically is stored for an "Anonymous" Reporter or Helper — is there always a hidden internal identifier for abuse investigation, or is the anonymity irreversible even to the platform operator?
7. Given decision 8 (LGPD/Brazil focus for the MVP, data model prepared for other jurisdictions), what happens today if a Reporter or Helper is physically located outside Brazil — is the app blocked, or does it silently apply Brazilian rules to non-Brazilian data subjects?
8. Since Reports can concern minors (Child subject tag) or the missing-child scenario flagged as legally sensitive (decision 1, example 2), is there a distinct data-handling and retention policy for Reports tagged with a minor, or do all Reports share one retention rule?

**Concurrency and Failures**
9. If two Helpers submit conflicting Direction Sightings for the same vehicle-theft Report at nearly the same time, how is the aggregated "most likely direction" reconciled, and can a malicious actor inject false sightings to skew it?
10. If the app is offline (no connectivity) when a Reporter is trying to submit a time-critical Report (e.g. a fleeing vehicle), is there any offline queuing/retry, or is the Report simply lost?

**Responsibility Boundaries Between Layers**
11. Is the per-Category Dynamic Radius calculation (decision 7) a rule owned by the Report Management subdomain, or does it belong to a separate Help Matching subdomain that Report Management depends on — this affects where the logic and its tests live in Section 2 (Context Map).
12. Does the Reward subdomain need to know about Category/Subject Tag at all, or should it only ever see an opaque Report reference — coupling Reward logic to Report internals would violate the Core/Core boundary between two independently evolving subdomains.

### Resolutions (Round 1)

Answered by the product owner — full text in `VGR-plano.md` decisions 18–30.

| Q# | Resolution | Decision # |
|---|---|---|
| 1 | Helpers stay linked to a Resolved Report; receive a thank-you/closure message | 18 |
| 2 | Helpers stay linked to an edited Report (may keep interest) or a resolved one (closure message); Report has an event timeline | 19 |
| 3 | A person cannot be both Reporter and Helper on the same Report; Reporter may still interact with their own Report's timeline | 20 |
| 4 | NearbyReportsFeed is paginated, ordered by recency or relevance | 21 |
| 5 | Direction Sighting processing is synchronous, prioritizing information speed | 22 |
| 6 | IP and other legally-collectible metadata are always logged internally, even for "anonymous" users — anonymity is social/UI-level, not forensic | 23 |
| 7 | Brazilian law (LGPD) applies regardless of physical location — no geo-blocking or adaptive jurisdiction in the MVP | 24 |
| 8 | Sensitive/minor data retention still needs legal research (LGPD/GDPR) — open pending item, not yet resolved | 25 (⚠️ open) |
| 9 | Direction reconciliation is a weighted statistical model (e.g. 50/50 prior, shifting with more sightings); anonymous sightings weighted lower than identified ones as fraud mitigation | 26, 27 |
| 10 | Offline queueing is required — reports/sightings are recorded locally and dispatched based on connectivity/server availability; also serves as flow control under load | 28 |
| 11 | Dynamic Radius belongs to the Help Matching bounded context, not Report Management | 29 |
| 12 | Reward decisions belong entirely to the Reporter (who to pay, how much); app does not arbitrate — legal research still needed on informant-payment regulations | 30 (⚠️ open) |

Two items remain genuinely open (flagged ⚠️ above) and require legal research before Phase 3 (Tactical Design) commits to a data model for them: minor-data retention windows (Q8/decision 25) and informant-reward legality (Q12/decision 30). Both are tracked as pending legal research, not blockers for Phase 2.

---

**Architecture Tip:** The Reward subdomain's external payment/perk rail is undecided and should be modeled behind an Anti-Corruption Layer from day one, so that choosing (or changing) a payment provider later doesn't leak into the Report or Help Offer aggregates.

## Save

Saved to: `D:\ProjetoVGR\app\docs\specs\vgr\001-problem-space.md`
