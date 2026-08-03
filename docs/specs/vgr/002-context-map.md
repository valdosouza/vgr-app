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
| Payment Intermediation | Execute the Reward payout: hold Reporter funds via a licensed PSP, retain the platform fee, release to the Helper's registered payout method — or step aside for peer-to-peer, non-high-risk Reports | Does not decide reward amount or allocation (Reward & Incentives), does not run its own banking license — delegates to an external PSP | Core Team (MVP) | PaymentIntent, PSPSplit |
| Panic Alert | Let any user trigger an always-available panic alert (menu-accessed), optionally pre-configured (persistent activation + recipient choice) for anticipated-risk users, routing to the Authorized Responder pool and/or a personal trusted contact | Does not dispatch to real authorities (deferred), does not decide Responder approval criteria (Admin Configuration) | Core Team (MVP) | PanicAlert, ResponderPoolMembership, TrustedContact |
| Messaging | Own the masked chat thread between a Reporter and each Helper on a Report, enforcing the same anonymity rules as the Report's RiskTier | Does not decide anonymity rules itself — conforms to Identity & Trust and Admin Configuration | Core Team (MVP) | ChatThread, ChatMessage |
| Admin Configuration | Own every runtime-editable registry an administrator manages: RiskTier per Category, category detail-form schemas, monetization fee rules, panic-responder approval, dual-control decryption access | Does not execute the business rules it configures — Help Matching, Report Management, Reward & Incentives, and Payment Intermediation each read from this config, never duplicate it | Core Team (MVP) | RiskTierConfig, CategoryFormSchema, FeeRule, ResponderApproval, DualControlAccessRequest |

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

[Admin Configuration] → [Help Matching]
Pattern   : Open Host Service
Direction : upstream (Admin Configuration) → downstream (Help Matching)
Justification: The severity filter (decision 49) and Dynamic Radius rules read the RiskTierConfig registry as a stable published contract, never duplicating the admin's configuration logic.

[Admin Configuration] → [Report Management]
Pattern   : Open Host Service
Direction : upstream (Admin Configuration) → downstream (Report Management)
Justification: Report Management reads RiskTierConfig (mandatory-anonymity/hidden-engagement behavior, decisions 40-41) and CategoryFormSchema (decision 47) — both admin-managed, never hardcoded.

[Admin Configuration] → [Reward & Incentives]
Pattern   : Open Host Service
Direction : upstream (Admin Configuration) → downstream (Reward & Incentives)
Justification: Fee rules (decision 39) and the peer-to-peer-vs-intermediated toggle (decision 58) are admin-configured, read by Reward & Incentives at allocation/payout time.

[Reward & Incentives] → [Payment Intermediation]
Pattern   : Customer-Supplier
Direction : upstream (Reward & Incentives) → downstream (Payment Intermediation)
Justification: Reward & Incentives decides WHAT is owed and to WHOM (allocation); Payment Intermediation decides HOW the money moves (PSP split, fee retention) — Reward & Incentives has negotiation power over the payout contract, Payment Intermediation never sees Report/Category context (inherits the ACL from decisions 30, 60).

[Identity & Trust] → [Payment Intermediation]
Pattern   : Conformist
Direction : upstream (Identity & Trust) → downstream (Payment Intermediation)
Justification: Payment Intermediation needs a Helper's registered payout identity (KYC) to release funds — it consumes Identity & Trust's registration record as-is; the Reporter never sees this identity (decision 60).

[Identity & Trust] → [Panic Alert]
Pattern   : Conformist
Direction : upstream (Identity & Trust) → downstream (Panic Alert)
Justification: "Authorized Responder" is a role-like membership built on Identity & Trust's user model; Panic Alert consumes it without redefining identity.

[Admin Configuration] → [Panic Alert]
Pattern   : Customer-Supplier
Direction : upstream (Admin Configuration) → downstream (Panic Alert)
Justification: Responder approval criteria (decision 52, still an open pending item) are set by Admin Configuration; Panic Alert negotiates what fields it needs from an approval decision, without owning the approval workflow itself.

[Report Management] → [Messaging]
Pattern   : Customer-Supplier
Direction : upstream (Report Management) → downstream (Messaging)
Justification: A chat thread only exists in the context of a specific Report/HelpOffer pair; Report Management has negotiation power over which minimal fields (reportId, participant roles) Messaging receives.

[Identity & Trust] → [Messaging]
Pattern   : Conformist
Direction : upstream (Identity & Trust) → downstream (Messaging)
Justification: Messaging masks participant identity following whatever anonymity mode Identity & Trust reports for that Report's RiskTier (decisions 40, 55) — it enforces the rule at the transport level, it doesn't reinterpret it.
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

Context : Panic Alert
Reason  : The two-tier accessibility model (menu-always-available vs. opt-in persistent activation) and the dual recipient routing (platform pool vs. personal trusted contact) directly protect users under active threat (protective-order holders, elderly, decisions 62-65) — a wrong design choice here has irreversible real-world consequences.
Investment: Full tactical DDD — PanicAlert and ResponderPoolMembership as Aggregates with explicit invariants (an alert always resolves to at least one recipient); heavy scenario-based testing on the routing logic.

Context : Payment Intermediation
Reason  : The dual-rail design (standard PSP payout for identified Helpers, while anonymity toward the Reporter must survive a real money transfer, decision 60) is a genuine differentiator most reward-adjacent apps don't need to solve.
Investment: Moderate-to-full tactical DDD — bounded today by the still-open PSP vendor selection (decision 59); the ACL boundary toward Reward & Incentives is the part that needs to be right from day one, since it's expensive to retrofit.
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

Decision    : Payment Intermediation is split out from Reward & Incentives into its own Bounded Context, not one aggregate inside Reward.
Context     : Reward & Incentives answers "what is owed, to whom" (an allocation question); Payment Intermediation answers "how does the money actually move" (a PSP-integration question) — decision 59 leaves the PSP vendor open, so this boundary lets that choice change without touching allocation logic.
Consequences: + PSP can be swapped later without redesigning Reward's domain model; − one more Customer-Supplier integration to maintain.

Decision    : Admin Configuration is one Bounded Context covering four distinct registries (RiskTier, category forms, fee rules, responder approval, dual-control access), not four separate contexts.
Context     : All four share the same underlying capability — an admin-editable registry read by other contexts at runtime, mirroring the tb_feature_flag pattern (decision 46) — splitting them would multiply the same Open Host Service pattern four times for no isolation benefit, since they change together (one admin panel, one team).
Consequences: + one panel, one access-control model, one place to add the next admin-configurable rule; − a context this broad must resist becoming a dumping ground — any registry that grows its OWN business invariants (not just config) should be split out later.

Decision    : Messaging and Panic Alert are Core, not Generic, despite "chat" and "alert" sounding like commodity names.
Context     : Both inherit hard, safety-specific constraints from the rest of the domain (Messaging must enforce RiskTier-driven masking; Panic Alert must resolve to a real recipient under a threat scenario) — a generic off-the-shelf chat/push SDK would not encode either constraint.
Consequences: + forces the same design rigor as Report Management instead of bolting on a library; − more initial engineering cost than reaching for a commodity chat/notification SDK.
```

## Save

Saved to: `D:\ProjetoVGR\app\docs\specs\vgr\002-context-map.md`
