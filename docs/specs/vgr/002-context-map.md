# Strategic Design — Bounded Contexts and Context Map

**Domain:** vgr
**Source:** `001-problem-space.md` (Event Storming, Subdomains, Ubiquitous Language, Round 1 Resolutions)

## Section 1 — Bounded Context Identification

| Bounded Context | Responsibility | Boundary (excluded) | Team Ownership | Key Entities |
|---|---|---|---|---|
| Report Management | Own the Report lifecycle: submission, categorization/tagging, editing, timeline of events, resolution | Does not decide who helps, does not compute radius, does not handle reward payout | Core Team (MVP) | Report, ReportTimelineEvent, Category, SubjectTag, FreeTag |
| Help Matching | Compute the per-category Dynamic Radius, surface the paginated NearbyReportsFeed, own Help Offers and Help Type selection | Does not own Report content, does not decide reward, does not compute raw geolocation | Core Team (MVP) | HelpOffer, HelpType |
| Direction Sighting Aggregation | Log Direction Sightings for pursuit-style Reports (vehicle theft, missing pet) and reconcile them into a weighted directional estimate | Does not predict future position or trigger notifications (deferred) | Core Team (MVP) | DirectionSighting, DirectionEstimate |
| Reward & Incentives | Let a Reporter optionally offer and later allocate a Reward among Helpers, in whatever form the Reporter chooses | Does not arbitrate who deserves the Reward, does not know Report's Category/Tags | Core Team (MVP) | Reward, RewardClaim |
| Identity & Trust | Own Role (anonymous/reporter/helper/police), anonymity choice, and the hidden accountability log (IP, non-illegal metadata) used for abuse investigation and Sighting weighting | Does not own registration/consent flow or data-retention policy | Core Team (MVP) | UserIdentity, RoleAssignment, AccountabilityLogEntry |
| User Registration & Compliance | Own the registration flow, consent, jurisdiction rule (Brazil/LGPD applies regardless of location), and data-retention policy | Does not decide anonymity behavior at runtime — that's Identity & Trust | Core Team (MVP) | UserAccount, ConsentRecord, DataRetentionPolicy |
| Geolocation Primitives | Provide raw device position and distance calculation as a generic service | Does not decide radius size or matching rules — that's Help Matching | Core Team (MVP) | GeoPosition |
| Direction Prediction & Notifications *(deferred)* | Predict a fleeing subject's future position from Direction Sightings and push proactive alerts | Not built — explicitly out of MVP (decision 11) | Unassigned (future) | PredictedZone, PushAlert |
| Police Validation *(deferred)* | Validate a Role upgrade to "police" | Not built — explicitly out of MVP (decision 12) | Unassigned (future) | ValidationRequest |

## Section 2 — Context Map

```
[Report Management] → [Help Matching]
Pattern   : Open Host Service + Published Language
Direction : upstream (Report Management) → downstream (Help Matching)
Justification: Help Matching needs a stable, minimal Report projection (id, category, location, timestamp) to compute Dynamic Radius and build the NearbyReportsFeed — a published contract avoids Help Matching depending on Report Management's full internal model.

[Report Management] → [Direction Sighting Aggregation]
Pattern   : Customer-Supplier
Direction : upstream (Report Management) → downstream (Direction Sighting Aggregation)
Justification: Sightings only make sense in the context of a specific pursuit-style Report; Report Management has negotiation power over which Report fields are exposed (id, category, submission time).

[Identity & Trust] → [Direction Sighting Aggregation]
Pattern   : Conformist
Direction : upstream (Identity & Trust) → downstream (Direction Sighting Aggregation)
Justification: Sighting weighting (decision 27 — anonymous helper sightings weigh less) consumes Identity & Trust's role/verification model as-is, with no renegotiation.

[Identity & Trust] → [Help Matching]
Pattern   : Conformist
Direction : upstream (Identity & Trust) → downstream (Help Matching)
Justification: Help Matching needs to know if a candidate Helper is anonymous or identified to enforce decision 4's rules, without redefining identity itself.

[Identity & Trust] ←→ [User Registration & Compliance]
Pattern   : Partnership
Direction : bidirectional
Justification: The two contexts must co-evolve — every new Role or anonymity mode Identity & Trust introduces has direct consequences for what Compliance must retain/consent, and vice-versa (decision 25's open legal research affects both).

[Report Management] → [Reward & Incentives]
Pattern   : Anti-Corruption Layer
Direction : upstream (Report Management) → downstream (Reward & Incentives)
Justification: Per the Architecture Tip in 001-problem-space.md and decision 30 (Reporter alone decides reward, app does not arbitrate), Reward must see only an opaque Report reference (id + reporterId) — an ACL translates away Category/Tags/Timeline so Reward's payment-rail evolution never leaks into Report Management.

[Identity & Trust] → [Reward & Incentives]
Pattern   : Conformist
Direction : upstream (Identity & Trust) → downstream (Reward & Incentives)
Justification: Reward requires a registered identity before payout (decision 4); it accepts Identity & Trust's registration-tier model without renegotiating it.

[Help Matching] → [Geolocation Primitives]
Pattern   : Open Host Service
Direction : upstream (Geolocation Primitives) → downstream (Help Matching)
Justification: Geolocation is a generic/commodity capability (Subdomain classification, 001-problem-space.md Section 2) exposing a stable position/distance API that Help Matching consumes without customization.

[Direction Sighting Aggregation] → [Direction Prediction & Notifications]
Pattern   : Separate Ways
Direction : n/a — no integration exists today
Justification: Decision 11 explicitly defers this feature; modeling an integration now would be speculative design for a context that doesn't exist yet.

[Identity & Trust] → [Police Validation]
Pattern   : Separate Ways
Direction : n/a — no integration exists today
Justification: Decision 12 explicitly defers this feature.
```

## Section 3 — Core Domain Highlight

```
Context : Help Matching
Reason  : The per-category Dynamic Radius rule (decision 7, 29) and the paginated proximity feed are the connection mechanism that is the product's entire hypothesis — nothing here is off-the-shelf.
Investment: Full tactical DDD — Dynamic Radius as an explicit domain service with per-Category strategy, not a config value; HelpOffer as a rich Aggregate with Help Type as a first-class Value Object.

Context : Direction Sighting Aggregation
Reason  : The weighted statistical reconciliation (decisions 26, 27) and the anti-reverse-engineering requirement (decision 1, example 5) are bespoke algorithmic differentiators with real fraud-resistance stakes.
Investment: Full tactical DDD — DirectionEstimate as an Aggregate with explicit invariants around weight recalculation; heavy unit-test investment on the reconciliation algorithm.

Context : Identity & Trust
Reason  : The layered anonymity model (decision 4) plus mandatory hidden accountability logging (decision 23) is the safety-critical differentiator the product owner called out unprompted — most competitors either force full identity or allow unaccountable anonymity, not both simultaneously.
Investment: Full tactical DDD — Role and AnonymityMode as Value Objects with strict invariants; AccountabilityLogEntry as an Aggregate with its own retention rules, isolated from user-facing Identity data.

Context : Report Management
Reason  : Core in the sense that it's the product's entry point and the open-ended taxonomy (decision 3, 9) is a deliberate differentiator versus closed-category competitors, but the aggregate itself (Report + timeline) is a comparatively conventional CRUD+event-log shape.
Investment: Moderate tactical DDD — Report as an Aggregate Root with a real Timeline value object, but less algorithmic complexity than the three contexts above.

Context : Reward & Incentives
Reason  : Core because the multi-type, Reporter-arbitrated reward model (decision 1, 30) is deliberately not a standard payout feature — but its internal complexity is currently bounded by two open legal-research items (decisions 25, 30) rather than by algorithm design.
Investment: Moderate tactical DDD now (Reward, RewardClaim as Aggregates behind an ACL) — revisit investment level once legal research on informant-payment regulation lands.
```

## Section 4 — Architectural Decisions

```
Decision    : Reward & Incentives sees Report Management only through an opaque reference (Anti-Corruption Layer), never Category/Tags/Timeline directly.
Context     : Decision 30 — the app does not arbitrate reward, only the Reporter does; coupling Reward's internals to Report's taxonomy would violate that boundary and block future payment-provider changes.
Consequences: + Reward can evolve (new payout types, new legal constraints) without touching Report Management; − adds one explicit translation layer for what is, today, a conceptually simple feature.

Decision    : Direction Sighting Aggregation is a standalone Bounded Context, not a field/subcollection on Report.
Context     : It carries its own non-trivial algorithm (weighted statistical reconciliation, decisions 26-27) and its own performance profile (synchronous, high-throughput per decision 22).
Consequences: + isolates a hard sub-problem for independent testing, tuning, and scaling; − one more integration point that Report Management must support (exposing enough Report context for a Sighting to attach to).

Decision    : Identity & Trust and User Registration & Compliance are two separate Bounded Contexts in a Partnership relationship, not a single "Auth" module.
Context     : Identity & Trust changes at product-decision speed (new anonymity modes, new roles); Compliance changes at legal-decision speed (new jurisdictions, retention rules) — different stakeholders, different rate of change.
Consequences: + a jurisdiction change doesn't require touching runtime identity logic and vice-versa; − the two contexts must be kept in sync deliberately (e.g., a new Role requires a Compliance review).

Decision    : Offline queueing (decision 28) is treated as a cross-cutting client capability, not a Bounded Context of its own.
Context     : It's a delivery guarantee needed by multiple producing contexts (Report Management, Direction Sighting Aggregation), with no business rules or invariants of its own to own.
Consequences: + avoids inventing an artificial context with no real domain logic; − the capability must be implemented consistently by every context that produces offline-capable writes, rather than centralized once.

Decision    : Direction Prediction & Notifications and Police Validation are marked Separate Ways — no integration modeled with any existing context.
Context     : Both are explicitly out of MVP scope (decisions 11, 12); designing their integration now would be speculative.
Consequences: + zero design cost today; − when eventually built, will likely require revisiting Direction Sighting Aggregation's retention (history to predict from) and Identity & Trust's role model (adding a validated police tier) — flagged here so that revisit isn't a surprise.
```

## Save

Saved to: `D:\ProjetoVGR\app\docs\specs\vgr\002-context-map.md`
