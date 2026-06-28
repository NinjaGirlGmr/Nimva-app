# Nimva — Technical Requirements & Infrastructure Plan

*Functional and non-functional requirements, infrastructure cost analysis, and toolchain decisions for development planning*

---

## 1. Purpose of This Document

This document defines what Nimva must do (functional requirements), how well it must do it (non-functional requirements), what infrastructure is needed to support it, and what that infrastructure costs at each stage of growth. It serves as the technical planning reference for development and as documentation of the engineering decision-making process behind the project.

---

## 2. Functional Requirements

*What the system must do — features and capabilities*

### 2.1 Account & Authentication
| ID | Requirement |
|---|---|
| FR-1.1 | Users can create an account via email/password |
| FR-1.2 | Users can sign in via Google (also enabling Calendar sync in one step) |
| FR-1.3 | Users can sign in via Apple (required by Apple if other social logins are offered) |
| FR-1.4 | Users can use the app anonymously before creating an account |
| FR-1.5 | Anonymous users are prompted to create an account before their data would be lost (e.g. before week 3) |
| FR-1.6 | Users can sign out |
| FR-1.7 | Users can delete their account and all associated data |
| FR-1.8 | Users can export their data |

### 2.2 Event Management
| ID | Requirement |
|---|---|
| FR-2.1 | Users can create a fixed event with name, start time, end time |
| FR-2.2 | Users can create a flexible event with name, preferred time window, and duration |
| FR-2.3 | Users can tag any event with an energy label (Alright / Manageable / Takes Effort / Pretty Draining) |
| FR-2.4 | Users can fine-tune an energy label using a slider |
| FR-2.5 | Users can toggle "learn my patterns" per event |
| FR-2.6 | Users can edit any field of an existing event |
| FR-2.7 | Users can delete an event |
| FR-2.8 | Editing a recurring event prompts the user to choose "this occurrence" or "all occurrences" |
| FR-2.9 | Users can view a category-based energy history for an event (PRO) |

### 2.3 Week Generation
| ID | Requirement |
|---|---|
| FR-3.1 | The system generates a week schedule placing flexible events around fixed events |
| FR-3.2 | The system calculates an energy balance score for the generated week |
| FR-3.3 | The system flags days that exceed a heavy-load threshold |
| FR-3.4 | Users can approve a generated week |
| FR-3.5 | Users can regenerate ("redo") a week |
| FR-3.6 | Users can manually move a flexible event to a different slot, shown with energy load context |
| FR-3.7 | Users can opt into automatic week regeneration without manual trigger |

### 2.4 Weekly Check-In
| ID | Requirement |
|---|---|
| FR-4.1 | The system sends an optional notification prompting the weekly check-in |
| FR-4.2 | Users can rate their overall week (5-point scale) |
| FR-4.3 | Users can rate individual events as easier/about right/harder than expected |
| FR-4.4 | Users can leave an optional free-text note |
| FR-4.5 | The system surfaces 1-2 specific suggestions based on check-in responses |
| FR-4.6 | Users can accept or dismiss each suggestion |
| FR-4.7 | Every step of the check-in is skippable |

### 2.5 Pattern Learning
| ID | Requirement |
|---|---|
| FR-5.1 | The system maintains a running weighted-average energy baseline per event category |
| FR-5.2 | The system suggests energy labels for new events based on category baselines |
| FR-5.3 | Users can accept or ignore a suggested energy label |
| FR-5.4 | Users can globally enable/disable pattern learning |
| FR-5.5 | Users can reset learned patterns to defaults |

### 2.6 Insights (PRO)
| ID | Requirement |
|---|---|
| FR-6.1 | PRO users can view a 5+ week energy balance trend |
| FR-6.2 | PRO users can view pattern callouts (e.g. "Wednesdays are consistently heaviest") |
| FR-6.3 | PRO users can view a category breakdown of energy vs. expectation |
| FR-6.4 | PRO users can view and act on coaching suggestions |
| FR-6.5 | Free users see a locked/blurred preview of the Insights screen with generic placeholder data |
| FR-6.6 | The locked Insights screen presents a PRO upgrade path with a free trial offer |

### 2.7 Calendar Integration (Version 2)
| ID | Requirement |
|---|---|
| FR-7.1 | Users can connect a Google Calendar account |
| FR-7.2 | Users can connect an Apple Calendar (iOS only) |
| FR-7.3 | On connection, existing calendar events are imported as fixed events |
| FR-7.4 | Approved Nimva weeks write flexible events back to the connected calendar |
| FR-7.5 | The system detects external calendar changes and flags conflicts before next generation |

### 2.8 Notifications
| ID | Requirement |
|---|---|
| FR-8.1 | Users receive a weekly check-in reminder (configurable, default Sunday evening) |
| FR-8.2 | PRO users can receive proactive capacity notifications ("good energy window tomorrow") |
| FR-8.3 | Users can toggle sounds/haptics for in-app interactions |
| FR-8.4 | Users can disable all notifications |

### 2.9 Onboarding
| ID | Requirement |
|---|---|
| FR-9.1 | New users see a 4-screen onboarding flow explaining the core concept |
| FR-9.2 | Onboarding explicitly explains that energy tagging is user-driven, not automatic |
| FR-9.3 | Onboarding is skippable after the second screen |
| FR-9.4 | Onboarding ends by directing the user into adding their first event |

---

## 3. Non-Functional Requirements

*How well the system must perform — quality attributes and constraints*

### 3.1 Performance
| ID | Requirement |
|---|---|
| NFR-1.1 | The week generation algorithm completes in under 2 seconds for a typical schedule (10-20 events) |
| NFR-1.2 | The home screen loads from cache in under 500ms, even offline |
| NFR-1.3 | Firestore reads are batched — loading a week requires no more than 1-2 read operations, not per-event reads |

### 3.2 Availability & Reliability
| ID | Requirement |
|---|---|
| NFR-2.1 | The app functions offline for viewing previously loaded data (Firestore offline persistence) |
| NFR-2.2 | Local changes made offline sync automatically when connectivity returns |
| NFR-2.3 | Scheduled notifications fire correctly even if the backend is temporarily unavailable (scheduled client-side) |

### 3.3 Accessibility
| ID | Requirement |
|---|---|
| NFR-3.1 | All text meets WCAG 2.1 AA contrast ratios (4.5:1 normal text, 3:1 large text) |
| NFR-3.2 | All interactive elements have minimum 44×44px touch targets |
| NFR-3.3 | No information is conveyed by color alone — always paired with text, icon, or shape |
| NFR-3.4 | The app supports OS-level dynamic type scaling |
| NFR-3.5 | All animations are subtle and non-essential — no information is conveyed only through motion |
| NFR-3.6 | Sounds and haptics can be fully disabled |
| NFR-3.7 | The palette avoids red/green-only distinctions and has been checked against common colorblindness types |

### 3.4 Security & Privacy
| ID | Requirement |
|---|---|
| NFR-4.1 | User data is only accessible to the authenticated user (Firestore security rules) |
| NFR-4.2 | OAuth tokens (Google Calendar) are stored securely and refreshed automatically |
| NFR-4.3 | Users can fully delete their account and all associated data (GDPR/CCPA compliance) |
| NFR-4.4 | Users can export their data in a portable format |
| NFR-4.5 | No personal data is logged in analytics beyond what's necessary for crash reporting |

### 3.5 Scalability
| ID | Requirement |
|---|---|
| NFR-5.1 | The architecture supports scaling from 0 to 50,000+ users without a fundamental redesign |
| NFR-5.2 | The scheduling algorithm runs as a stateless serverless function, scaling horizontally by default |
| NFR-5.3 | Database structure avoids per-event documents at the top level to prevent read/write cost explosions at scale |

### 3.6 Usability
| ID | Requirement |
|---|---|
| NFR-6.1 | Adding an event takes under 10 seconds for a returning user |
| NFR-6.2 | The weekly check-in takes under 60 seconds to complete |
| NFR-6.3 | Onboarding communicates the core energy-tagging concept without requiring the user to read a paragraph of text |
| NFR-6.4 | The interface uses no more than 3-4 distinct font sizes/weights per screen |

### 3.7 Maintainability
| ID | Requirement |
|---|---|
| NFR-7.1 | The codebase uses a single shared codebase for iOS and Android (React Native/Expo) |
| NFR-7.2 | The pattern learning system uses simple weighted averages, not a separate ML pipeline, to minimize maintenance overhead |
| NFR-7.3 | Design tokens (colors, spacing, type scale) are centrally defined, not hardcoded per screen |

### 3.8 Compatibility
| ID | Requirement |
|---|---|
| NFR-8.1 | The app supports current and previous major iOS and Android versions |
| NFR-8.2 | The app supports both light and dark system themes |
| NFR-8.3 | Calendar integration degrades gracefully on platforms where it isn't available (e.g. Apple Calendar on Android) |

---

## 4. Toolchain & Infrastructure

### 4.1 Selected Stack

| Layer | Technology | Why |
|---|---|---|
| Mobile framework | React Native (Expo) | Single codebase for iOS + Android, fits existing JavaScript knowledge, large ecosystem |
| Authentication | Firebase Auth | Handles email, Google, Apple, and anonymous auth with minimal setup |
| Database | Firebase Firestore | Generous free tier, real-time sync, built-in offline persistence |
| Backend logic | GCP Cloud Functions | Serverless — pay only when the scheduling algorithm runs |
| Calendar integration | Google Calendar API, Apple EventKit (`react-native-calendar-events`) | Industry standard for each platform |
| Push notifications | Expo Notifications | Free tier covers early-stage volume, integrates directly with Expo |
| Local caching | AsyncStorage | Enables offline-first home screen |
| Hosting (concept page) | GitHub Pages | Free, already in use |
| Feedback collection | Formspree | Free tier, already in use |

### 4.2 Why This Is the Cost-Effective Choice

The core principle behind this stack is **pay only for what runs, not what exists**. Every piece of backend infrastructure (Cloud Functions, Firestore) is usage-based rather than a flat server cost — a traditional always-on backend server (e.g. a VPS running Node.js continuously) would cost $5-20/month from day one regardless of whether anyone is using the app. Serverless functions cost effectively $0 at zero usage.

React Native with Expo specifically avoids the cost of maintaining two separate native codebases (Swift for iOS, Kotlin for Android), which would roughly double development time even for a solo developer working efficiently.

---

## 5. Infrastructure Costs — Full Breakdown

### 5.1 What's Free vs. What Isn't

**Genuinely free at any reasonable early scale:**
- Firebase Firestore (50,000 reads / 20,000 writes per day free)
- Firebase Auth (10,000 monthly active users free)
- GCP Cloud Functions (2,000,000 invocations/month free)
- Expo development and basic builds
- GitHub Pages hosting
- Formspree (50 submissions/month)
- Google Calendar API (10,000 requests/day free)

**Never free — required regardless of scale:**

| Item | Cost | Notes |
|---|---|---|
| Apple Developer Program | $99/year | Required to publish on the App Store, non-negotiable |
| Google Play Developer account | $25 one-time | Required to publish on Google Play |
| Domain name (optional but recommended) | ~$10-15/year | For a project website/landing page beyond GitHub Pages |

**Becomes a cost at moderate scale:**

| Item | Free tier limit | Cost beyond limit |
|---|---|---|
| Firestore reads/writes | 50K reads, 20K writes/day | ~$0.06 per 100K reads, ~$0.18 per 100K writes |
| Cloud Functions invocations | 2M/month | ~$0.40 per million after |
| Expo EAS Build | Limited free builds/month | $29/month for production tier (needed for frequent app store builds) |
| Push notifications (Expo) | 1,000/month free via Expo's service | Scales with user base |

### 5.2 Updated Cost Map by Phase

**Development (pre-launch): $0**
Everything fits within free tiers. The only unavoidable cost during development is if Apple/Google accounts are set up early to begin testing on real devices via TestFlight/Internal Testing — at which point the $99 Apple fee applies.

**Pre-launch / Beta (TestFlight, Internal Testing): ~$99-124**
- Apple Developer account: $99/year (needed for TestFlight)
- Google Play account: $25 one-time (needed for Internal Testing track)
- Everything else still free

**Early Launch (0-500 users): ~$0-15/month** (plus the one-time/annual account costs above)
- Firestore, Cloud Functions, Calendar API: free tier covers this comfortably
- Expo EAS: may need occasional paid builds (~$1-3 per build on pay-as-you-go if not on a plan) — budget ~$10/month for occasional builds during active development

**Growth (500-5,000 users): ~$25-50/month**
- Firestore reads/writes likely exceed free tier: ~$5-15/month
- Cloud Functions: still mostly free, ~$0-5/month
- Expo EAS Build production plan: $29/month (if shipping updates frequently)
- Apple account renewal: ~$8/month amortized

**Scale (5,000-50,000 users): ~$100-300/month**
- Firestore: $50-150/month
- Cloud Functions: $20-50/month
- Firebase Auth: $10-30/month
- Expo EAS: $29/month
- At this scale, even a conservative 2-3% PRO conversion at $3-5/month comfortably covers infrastructure (e.g. 5,000 users × 2.5% × $4 = $500/month revenue against $100-300/month costs)

### 5.3 One-Time / Periodic Costs (Non-Infrastructure)

| Item | Cost | When |
|---|---|---|
| USPTO trademark filing | $250-350 per class | When ready to formally protect "Nimva" |
| Attorney trademark clearance search | $300-500 | Recommended before filing, before heavy investment in branding |
| Custom character illustration (Ember) | $200-800 | Before public launch — replaces emoji placeholders |
| App Store screenshots/preview video | $0 (DIY) - $200 (freelance) | Before submission |

---

## 6. Risk Areas & Mitigations

### 6.1 Original Risk Table

| Risk | Likelihood | Mitigation |
|---|---|---|
| Firestore costs scale faster than expected due to inefficient queries | Medium | Strict adherence to NFR-1.3 (batched reads) from day one — retrofitting this later is expensive in both dev time and real cost |
| Calendar integration complexity delays launch | Medium-High | Explicitly deferred to Version 2 (FR-7.x) — MVP launches without it |
| App Store review delays | Medium | Allow 1-2 weeks buffer before any planned launch date; have a working build ready well in advance |
| Pattern learning produces "weird" suggestions with too little data | Medium | FR-5.1 specifies a minimum data threshold (3-5 occurrences) before suggestions surface |
| Free tier feels "too complete," hurting PRO conversion | Low (by design) | Insights (FR-6.x) is the only PRO-gated feature; everything else free-tier remains genuinely useful per earlier business decisions |

### 6.2 Risk Reassessment — Honest Likelihood Review

| Risk | Realistic likelihood | Reassessment |
|---|---|---|
| Firestore costs scale unexpectedly | **Low**, if NFR-1.3 followed from the start | Almost entirely preventable by design, not luck — the discipline has to happen at the schema-design stage, not retrofitted |
| Calendar integration delays | **High** if attempted in v1, **Low** as deferred | Already mitigated. Important reframe: this isn't "v2, then done" — external API changes (especially iOS permission models) make this **ongoing maintenance indefinitely**, not a one-time build |
| App Store review delays | **Medium-High**, especially first submission | First-time submissions are commonly rejected for minor policy issues (privacy policy wording, demo account requirements, missing data-safety disclosures). Budget more than the standard 1-2 weeks for the *first* submission specifically |
| Pattern learning produces weird suggestions | **Medium**, and largely unavoidable early on | With small early user counts, individual "weird" results from low sample sizes are expected, not just possible. Reframe from "risk to prevent" to "expected behavior that needs graceful framing" (e.g. "still learning your patterns" messaging until thresholds are met) |
| Free tier too generous, hurts conversion | **Low, but unknowable from planning alone** | This genuinely cannot be assessed without real usage data — flagged for revisit post-launch, not resolved now |

### 6.3 Previously Unlisted Risk — Vendor Lock-In

**Likelihood: Low impact now, but real.** The entire stack is built on Firebase/GCP. This is the correct cost-driven choice, but migrating away later (if pricing or terms changed unfavorably) would require a significant rewrite — Firestore's data model and Firebase Auth don't translate directly to other platforms.

**Mitigation:** The scheduling algorithm itself (FR-3.x) is intentionally stateless — it takes events in, returns a schedule out. This portion of the architecture is portable regardless of database choice. The lock-in risk is concentrated in the data layer, which is an acceptable tradeoff for a project at this stage, but worth knowing rather than discovering later.

### 6.4 Previously Unlisted Risk — Solo Developer Time & Sustained Motivation

**Likelihood: High — this is arguably the single biggest risk to the project overall**, and it's not technical.

This is a one-person project running alongside a full course load, robotics team leadership, Student Honor Society leadership, and participation in 9+ clubs. The design phase has been fast-moving and genuinely engaging. Development — backend logic, debugging, app store paperwork, calendar API edge cases — is slower, less immediately rewarding, and easy to deprioritize when school demands spike.

**Mitigations:**
- Build in small, demo-able milestones (e.g. "events can be added and saved" before "scheduling algorithm works") so progress remains visible and motivating even in slow stretches
- Treat the concept page and community feedback loop as ongoing — momentum from real people being interested can sustain motivation through less exciting development phases
- Accept that timeline estimates should be generous — "a school year" is a more realistic frame than "this summer" for a working MVP, given everything else on the plate

---

## 7. Cost Minimization Under a Low-Conversion Scenario

*Designing the infrastructure so that even with 2-5% (or lower) PRO conversion, costs never become a burden*

### 7.1 The Core Question

If Nimva gets real users but very few ever upgrade to PRO, does the app become a financial liability? The honest answer, working through the numbers: **only if Firestore usage scales carelessly — everything else stays near zero regardless of conversion.**

### 7.2 What Conversion Rate Affects (and What It Doesn't)

**Conversion rate has zero effect on:**
- Apple Developer fee ($99/year — fixed cost regardless of users or revenue)
- Google Play fee ($25 one-time)
- Cloud Functions costs (driven by *usage*, i.e. how many people generate weeks — not by who pays)
- Firebase Auth costs (free up to 10K MAU regardless of paid status)

**Conversion rate only affects:** whether PRO-tier compute (Insights generation, FR-6.x) is worth the marginal Cloud Function cost of computing it. Since Insights is computed only for PRO users, **a low conversion rate actually *reduces* this specific cost** — fewer people means less PRO-tier computation, not more financial exposure.

### 7.3 The Actual Cost Driver: Firestore at Scale, Independent of Conversion

The only place free users at scale create real cost is **Firestore reads/writes from free-tier daily usage** — checking the home screen, adding events, etc. This happens whether or not anyone ever pays.

**Concrete numbers:** Free tier covers 50,000 reads/day. If each active user generates roughly 10-15 reads per app open (home screen, week view, settings) and opens the app 1-2 times daily, the free tier supports **roughly 1,500-2,500 daily active users before any Firestore cost begins** — entirely independent of how many of them are PRO.

### 7.4 Design Decisions That Keep This True at Scale

1. **Aggressive client-side caching (NFR-1.2, AsyncStorage)** — a user opening the app multiple times in a day shouldn't re-read from Firestore each time if nothing changed. This is the single highest-leverage cost control and costs nothing to implement well from the start.

2. **Batch all week data into single documents (NFR-1.3, NFR-5.3)** — already specified, but worth restating as the *primary* lever: 1 read for a whole week vs. 10-20 reads for individual events is a 10-20x cost difference at identical user counts.

3. **Compute Insights (PRO) on-demand, not continuously** — Cloud Functions for Insights should run when a PRO user opens that screen, not on a schedule for all users. This ties PRO-tier compute cost directly to PRO-tier usage, which is inherently small if conversion is low.

4. **Avoid real-time listeners where polling suffices** — Firestore's real-time `onSnapshot` listeners keep connections open and can rack up reads if left active unnecessarily (e.g. a screen left open in the background). Use one-time `get()` reads for data that doesn't need live updates (most of Nimva's data — schedules don't change while you're not looking at them).

5. **Defer calendar sync (FR-7.x)** — beyond the integration complexity already discussed, calendar sync via webhooks/polling is a *recurring* background cost driver (checking for external changes) that scales with users regardless of conversion. Deferring this keeps the cost model simple until there's revenue to justify it.

### 7.5 Bottom Line

**At low conversion, the app's infrastructure cost is governed almost entirely by total active user count and Firestore query efficiency — not by how many people pay.** The fixed costs ($99/year Apple, $25 Google Play) exist regardless. Everything else stays near $0 until reaching roughly 1,500-2,500 daily active users *if* the caching and batching practices above are followed from the start — at which point even a handful of PRO subscribers ($3-5/month each) would offset the modest Firestore overage costs.

**The practical implication:** a low conversion rate is a *product/business* concern (does the PRO tier need to be more compelling?) but does not need to be treated as an *infrastructure risk* — the architecture as designed is inherently cheap to run for free users, by design.

### 7.6 What "Self-Sustaining" Actually Requires

If the goal is for PRO revenue to fully cover infrastructure costs (the only true fixed cost being the $99/year Apple fee, ~$8/month amortized, until meaningful Firestore overage begins around 10,000-25,000+ DAU with caching applied per 8.3):

| Conversion rate | PRO users needed for ~$100-300/month (scale-phase costs) | Total users needed |
|---|---|---|
| 2% | 1,250-3,750 | ~62,500-187,500 |
| 5% | 500-1,500 | ~10,000-30,000 |

**Key insight:** low conversion doesn't make the app *cost more* — it simply means more total users are needed before PRO revenue exceeds the (already small) infrastructure cost. Below that threshold, the ~$8/month Apple fee is a known, fixed, small out-of-pocket cost — not a sign of failure, just the realistic shape of freemium economics below tens of thousands of users. With the refined caching estimates in 8.3, infrastructure stays near $0 for a very long time regardless of conversion rate.

### 7.6a Goal Reframe — "Doesn't Cost Me" Rather Than "Profitable"

The actual goal is narrower and more achievable than full profitability: **the app should not actively cost money to operate while helping people**, and ideally any small PRO revenue offsets the one real fixed cost (~$8/month Apple fee) and funds its own updates. This is a meaningfully lower bar than "self-sustaining as a business," and per 8.3's refined estimates, it's realistic at a fairly small user count — a handful of PRO subscribers covers the Apple fee outright. Anything beyond that is a bonus, not a requirement for the app to keep existing.

### 7.6b Automated Budget Safeguards — How They Actually Work

Researched directly, since the mechanics matter for whether this is realistic to set up:

**Budget alerts alone do not stop spending** — GCP is explicit that they are notification-only by default. The automated shutoff is a separate system you build on top: a budget alert publishes to a Pub/Sub topic, a Cloud Function subscribes to that topic, and the function calls the Cloud Billing API to act.

**Important limitation:** disabling billing on a project terminates *all* Google Cloud services in that project — including free-tier services. Since Firebase/Firestore lives in the same GCP project, a full billing shutoff would take the entire app offline for all users, not just the expensive part. **This option is explicitly ruled out for Nimva** — the goal is containment of the specific runaway component, not an all-or-nothing kill switch. There's also a reporting delay (billing data can lag up to ~24 hours), so some overage before any automated action triggers is unavoidable regardless of setup — this is a reason to favor *narrow, targeted* containment over broad action, since broad action triggered late is both disruptive and too late to fully prevent the overage anyway.

**Recommended approach for Nimva — notify and contain, never nuke:**

| Threshold (% of monthly budget) | Action |
|---|---|
| 50% | Email notification only — early awareness, no action taken |
| 80% | Email + disable the *specific* suspected-expensive Cloud Function only (e.g. pause PRO Insights generation, or the scheduling function specifically if that's the runaway one) — core app (Firestore reads for home screen, auth, basic event CRUD) keeps working for all users |
| 100%+ | Same as 80%, plus disable any *additional* non-essential functions identified as contributors — but core read/write paths for existing user data remain untouched. Billing itself is never disabled. |

This means the worst case is "PRO users temporarily lose Insights, or new weeks can't be auto-generated for a bit" — annoying but not damaging, and nothing existing users have already saved is at risk. The runaway component gets isolated and contained while you investigate, rather than the whole app (and everyone's data access) going dark.

**Implementation note:** this requires identifying which Cloud Functions are "non-essential" (can be safely paused without breaking core app function) ahead of time — Insights generation and proactive notifications are good candidates, since their absence is inconvenient but not data-threatening. Core CRUD operations (adding/editing events, reading the current week) should never be in the auto-pause list.

**Likelihood this is ever triggered:** low if the caching patterns in 8.3 are followed from the start, but setup cost is also low (a few hours, entirely free) and the downside of *not* having it (an undetected runaway cost over days/weeks) is the exact scenario this whole goal reframe is trying to avoid. Cheap insurance — worth doing early, even before it feels necessary.

### 7.7 DIY Character Art (Ember)

If Ember's character art is illustrated in-house (Figma, Procreate, Illustrator, etc.) rather than commissioned, the **$200-800 line item in section 5.3 becomes $0 in direct cost**. The tradeoff is *time*, not money — preparing multiple expression states across light/dark themes and various sizes is a real time investment during development, not a financial one. Worth planning for in the development timeline even though it doesn't appear in the cost map.

---

## 8. Data Flow, Sync Behavior & Optimization

### 8.1 Ingress & Egress Map

**Ingress (data flowing into the system):**

| Source | Data | Frequency |
|---|---|---|
| User input | Event creation/edits, check-in responses, settings changes | Per user action |
| OAuth providers (Google/Apple) | Sign-in tokens, profile info | Sign-in, token refresh |
| Google Calendar webhooks (v2) | External calendar change notifications | Only when external calendar changes |
| Push notification service | Delivery receipts | Per notification sent |

**Egress (data flowing out of the system):**

| Destination | Data | Frequency |
|---|---|---|
| Client app | Week data, insights, suggestions | Per screen load (minimized via caching, see 8.3) |
| Google Calendar (v2) | Approved flexible events | Per week approval |
| Push notification service | Check-in reminders, capacity alerts | Per scheduled notification |
| Data export (FR-1.8) | Full user data archive | On user request only |

**Why this matters for cost:** Firestore's free tier is generous on reads/writes but egress bandwidth for large payloads is a separate (small) cost. Keeping payloads minimal — sending only the current week's data rather than the user's entire history on every load — keeps both read counts *and* payload size down.

### 8.2 Synchronous vs. Asynchronous Operations

| Operation | Sync or Async | Why |
|---|---|---|
| Adding/editing an event | **Sync (feels instant)** | User expects immediate visual confirmation — written optimistically to local state first, Firestore write happens in background |
| Week generation algorithm | **Async, with visible progress** | Takes up to 2 seconds (NFR-1.1) — the build animation (already designed) turns necessary latency into an engaging moment rather than a blocking wait |
| Pattern learning baseline updates | **Fully async, invisible** | Per NFR, happens after check-in submission with zero user-facing wait — user moves on immediately, baseline updates in the background |
| Push notification scheduling | **Async, client-side** | Scheduled locally (Expo Notifications) so it doesn't depend on a live connection to the backend |
| Calendar sync (v2) | **Async, background** | Conflict detection happens via webhook/poll independent of the user's active session |
| Insights generation (PRO) | **Async, on-demand** | Computed when a PRO user opens Insights — not pre-computed for all users (see 7.4.3) |

**General principle:** anything the user directly *did* (tap, type, select) should feel synchronous even if the actual write is async underneath (optimistic UI updates). Anything the *system* does in response (learning, scheduling, syncing) should be visibly async or fully invisible — never a blocking wait without explanation.

### 8.3 Optimization Summary — Data, Time, Cost, Efficiency

This consolidates optimization opportunities across the whole stack into one place.

**Data usage optimizations:**
- **Derived-data caching (the single highest-leverage pattern)**: cache the *computed result*, not just inputs. The generated week (schedule + balance score + flags) is stored as one complete document. Every screen that needs "this week" reads from that one cached object — viewing Wednesday's load, checking the balance score, reviewing the event list are all *local filters on already-loaded data*, never separate queries. Recompute only on explicit triggers: user taps "redo," or adds/edits/deletes an event (invalidates the cached week for regeneration on next view).
- Cache the current week locally (AsyncStorage) — avoid re-fetching unchanged data across app opens
- Fetch only the current week + minimal lookahead, not the user's full event history, on home screen load
- Use one-time `get()` reads instead of real-time `onSnapshot()` listeners for data that doesn't need live updates (most of Nimva)
- Store pattern-learning baselines as single small documents per category, not per-event records

**Refined read estimate with derived-data caching applied:**
With the cache-once-filter-locally pattern, a typical day for a returning user looks like: 1 read on first app open (week document, if local cache is stale/missing), 0 reads on subsequent opens that day (served from local cache), 1 write per event add/edit (updates the cached week document, which also updates local cache optimistically). **Realistic estimate: 1-2 reads per user per day**, not the earlier rough estimate of 10-15. This pushes the free-tier ceiling from ~1,500-2,500 DAU to roughly **10,000-25,000+ DAU** before any Firestore read cost begins — a significantly better number for the self-sustaining economics discussed in section 7.

**Time optimizations:**
- Greedy scheduling algorithm (already chosen) is O(n log n) at worst for typical event counts — fast by construction, not by luck
- Optimistic UI updates for event add/edit — perceived speed matches NFR-6.1 (under 10 seconds) easily since the wait is mostly visual, not network-bound
- Local notification scheduling removes dependency on backend round-trips for reminders

**Cost optimizations:**
- Batched week documents (1 read vs 10-20) — the single highest-leverage decision in the whole architecture
- On-demand Insights computation — PRO-tier compute scales with PRO usage, not total users
- **Automated budget alerts with safeguard actions**: GCP supports free budget alerts at chosen spending thresholds (e.g. $5, $10, $25). For a solo developer, the recommended setup is a tiered response — a low threshold ($5) triggers an email notification only, while a higher threshold ($25-50) triggers a Cloud Function that can pause specific services (e.g. disable the scheduling function) and send an alert, rather than silently continuing to run up costs from an undetected bug (such as an infinite loop or runaway query). This turns "discover a huge bill later" into "get notified and auto-pause within hours."

**Efficiency optimizations:**
- Stateless scheduling function — scales horizontally with zero coordination overhead
- Single codebase (React Native) — efficiency in *development* time, not just runtime
- Deferred calendar sync — avoids building/maintaining a recurring background process before it's justified by usage

### 8.4 Automated Test Cases

A test-code-only approach — every entry below is something written as runnable, repeatable test code rather than a manual checklist.

Organized by layer, from easiest/highest-value to implement first, to more involved.

**Layer 1 — Pure logic (no Firebase, no UI required)**

These are the highest-value starting point: fast to write, fast to run, and directly test the app's core differentiators.

| Test | What it verifies |
|---|---|
| Scheduling algorithm: given fixed events occupying specific days, assert flexible events are placed on the lowest-load remaining days | Core FR-3.1 correctness |
| Scheduling algorithm: given an empty flexible event list, assert no errors and a valid (if minimal) week is returned | Edge case handling |
| Scheduling algorithm: given more flexible events than available slots, assert graceful overflow handling (not a crash) | Edge case handling |
| Energy balance score calculation: given a known set of daily loads, assert the score formula produces the expected number | FR-3.2 correctness |
| Heavy-day flagging: given a day exceeding the threshold, assert it's flagged; given one just under, assert it's not | FR-3.3 boundary condition |
| Pattern learning formula: given a sequence of ratings, assert `newBaseline = oldBaseline*0.7 + newRating*0.3` produces expected values across multiple iterations | FR-5.1 correctness |
| Pattern learning threshold: assert no suggestion is surfaced before the minimum data point threshold (3-5) is met | FR-5.2 boundary condition |

**Layer 2 — Firestore rules & data layer (Firebase emulator, no live project needed)**

| Test | What it verifies |
|---|---|
| User A cannot read User B's week documents | NFR-4.1 — directly tests the security model |
| User A cannot write to User B's event subcollection | NFR-4.1 |
| Unauthenticated requests are rejected for all user data paths | NFR-4.1 |
| Deleting a user's account document also triggers cleanup of their weeks/events/checkins subcollections | FR-1.7, NFR-4.3 — this is easy to get *wrong* (delete the parent doc but orphan subcollections), so a test here is high-value |
| Writing a malformed event (missing required fields) is rejected by rules/schema validation | Data integrity |

**Layer 3 — Cached/derived data correctness**

These tests specifically verify the derived-data caching pattern (8.3) works correctly — arguably the most important *new* tests given today's discussion.

| Test | What it verifies |
|---|---|
| After generating a week, reading "Wednesday's events" returns data without a new Firestore read (assert via call-count mock) | Derived-data caching is actually being used, not silently falling back to per-day queries |
| Editing an event invalidates the cached week, and the next read triggers regeneration | Cache invalidation correctness |
| Adding an event does NOT invalidate days unaffected by the change (if the algorithm supports partial updates) | Efficiency — avoids unnecessary full recomputation |
| Local cache (AsyncStorage) and Firestore document remain consistent after a simulated offline edit + reconnect (Firebase emulator + mocked network state) | NFR-2.1/2.2 sync correctness — replaces manual "airplane mode" testing with a scripted emulator test |
| Simulated double-submit of the same event-creation request within a short window results in exactly one document, not two | Data integrity — replaces manual "rapidly tap save" testing with a scripted race-condition test |
| An event creation request that's interrupted mid-write (simulated network failure) either completes or fully rolls back — never leaves a partial document | Optimistic UI correctness — replaces manual "navigate away before save" testing |

**Layer 4 — Integration tests (multiple pieces working together)**

| Test | What it verifies |
|---|---|
| End-to-end: create event with "Pretty Draining" label → generate week → assert it's not placed on an already-heavy day | Cross-system correctness (energy tagging → algorithm) |
| End-to-end: complete check-in rating an event "harder than expected" 3 times across 3 weeks → assert the event's energy baseline shifts toward "Pretty Draining" | Cross-system correctness (check-in → pattern learning) |
| End-to-end: free user opens Insights → assert response contains placeholder/generic data, not a computed report (verify no scheduling/insights function was invoked) | FR-6.5 — also a *cost* test, verifying wasted compute isn't happening |
| End-to-end: PRO user opens Insights → assert the on-demand Cloud Function is invoked exactly once per view, not on a schedule | 7.4.3 — verifies the cost model assumption holds in practice |
| Scripted: create a week with two fixed events overlapping in time → assert the system either rejects the conflicting input or flags it clearly, never silently produces an invalid schedule | FR-3.1 edge case — replaces manual "overlapping fixed events" testing |
| Scripted: toggle pattern learning off → assert existing baselines remain in storage unchanged, but no new suggestions are generated on subsequent events | FR-5.4 — replaces manual toggle testing |
| Scripted: trigger account deletion → assert all subcollections (weeks, events, checkins) return empty/not-found afterward, not just the user document | FR-1.7, NFR-4.3 — replaces manual "delete account" testing |

**Layer 5 — UI/component tests**

| Test | What it verifies |
|---|---|
| All 4 onboarding screens render; skip option appears only from screen 2 onward | FR-9.3 |
| Energy label chips: selecting one visually deselects others (single-select behavior) | UI correctness |
| Week generation screen shows build animation, then transitions to complete state with approve/redo options | FR-3.4/3.5 UI flow |
| Settings toggles (pattern learning, sounds/haptics, notifications) persist across app restarts | Settings persistence |

**Recommended sequencing:** Layer 1 (pure logic) first — no setup required beyond the test framework itself, and these tests remain valuable forever as the algorithm evolves. Layer 2 (security rules) second, since getting this wrong is a real privacy risk (NFR-4.1) and the Firebase emulator makes it testable without a live project. Layers 3-5 follow naturally as those systems get built.

---

*This document complements the Nimva Design Reference, which covers UI/UX decisions, and the Portfolio Writeup, which covers the project narrative for admissions purposes.*
