# Nimva — A Mobile Application for Energy-Aware Scheduling
### Independent Project | Portfolio Writeup

---

## Overview

Nimva is a mobile scheduling application I designed and began developing independently, motivated by a problem I experienced firsthand. As a student simultaneously serving as President of my school's robotics team, President of my Student Honor Society (SHS), and active member of upwards of nine clubs — while maintaining a full academic course load — managing time was never the challenge. Managing energy was.

The project spans product research, UI/UX design, system architecture, and business planning — and represents my first end-to-end attempt at bringing a software product from an idea to a tangible, deployable design.

This document outlines the journey of building Nimva, the technical and design decisions made along the way, and the steps planned for its continued development.

---

## The Problem

Most scheduling applications treat time as the scarce resource. They help users organize *what* to do and *when* to do it, but they ignore a more fundamental constraint: energy.

As a neurodivergent student balancing coursework, the presidency of my robotics team, the presidency of my Student Honor Society, membership across nine or more clubs, the gym, and a social life, I found that even a well-organized schedule could lead to burnout if it failed to account for how mentally and physically demanding different activities are in combination. Scheduling a high-intensity robotics session immediately after an already draining school day is fundamentally different from scheduling it on a lighter afternoon — yet no existing tool made that distinction.

Existing applications such as Google Calendar, Apple Calendar, and productivity tools like Notion or Todoist are powerful but passive. They record commitments; they do not reason about capacity. After researching the market and speaking with peers who described similar struggles, I identified a clear gap: an application that understands energy as a resource, distributes activities to minimize burnout risk, and learns individual patterns over time.

---

## Research and Validation

Before writing a single line of code or designing a single screen, I spent time pressure-testing the core assumptions behind the idea.

**Market research** confirmed that scheduling and productivity tools are a growing space, driven in part by increasing awareness of burnout and mental health among students and young professionals — validating that the problem was worth solving at scale.

**Competitive analysis** revealed that while apps like Wick (a student planner) addressed scheduling for students, none meaningfully incorporated energy management or neurodivergent-friendly design principles. Wick, despite having a solid concept and positive user reviews, had accumulated fewer than 3,600 total downloads — a case study in how discoverability and differentiation matter as much as execution.

**Differentiation** was defined clearly: Nimva does not replace calendar apps. It sits on top of them, doing something they cannot — reasoning about energy load across a week and building a schedule that protects the user from accumulating burnout.

---

## Technical Architecture

With the product concept validated, I researched and selected a technology stack appropriate for a native mobile application built by a solo developer, with cost and platform integration as central considerations.

### Selected Stack

| Layer | Technology | Rationale |
|---|---|---|
| Platform | Native iOS — Swift + SwiftUI | Best performance and OS integration, direct access to platform capabilities without a cross-platform abstraction layer |
| Local storage | SwiftData | Native persistence layer that integrates directly with Apple's sync framework |
| Sync | CloudKit | Each user's data syncs against their own iCloud storage rather than a shared pool billed to the developer — this was a deciding factor for cost sustainability |
| Authentication | Sign in with Apple | Native, simple, no third-party service required |
| Calendar integration (planned) | Apple EventKit | Allows Nimva to read and write to a user's existing calendar with permission |

### Why This Stack

The defining advantage of this stack is its cost model: because CloudKit's private database usage counts against each individual user's own iCloud storage rather than a pool billed to the developer, the infrastructure cost of the application does not scale with the number of people using it. This is a meaningfully different economic structure than a typical cross-platform backend-as-a-service approach, where cost grows in proportion to usage. Combined with on-device computation for the scheduling algorithm and pattern learning, there is effectively no backend service to operate or pay for — the only recurring cost at any scale is the standard $99/year Apple Developer Program fee required to publish on the App Store at all.

The tradeoff is platform scope: this approach is iOS-only at launch, with no Android equivalent without a separate effort later (a future path using Kotlin Multiplatform to share core logic while keeping native UI per platform was identified as a way to make any future Android expansion cheaper, but this remains deliberately out of scope for an initial release).

The scheduling algorithm itself is intentionally kept simple at launch. Rather than a machine learning model (which would introduce significant complexity for relatively little benefit at this stage), the core logic uses a greedy bin-packing approach, specifically a Longest-Processing-Time-first (LPT) heuristic:

1. Fixed events are placed as anchors on their assigned days
2. Flexible events are ranked by energy cost, highest first
3. The algorithm distributes flexible events across available slots, prioritizing days with lower existing energy loads
4. A burnout risk score is calculated for each day and the overall week

This approach runs entirely on the user's device, is computationally lightweight, and produces meaningful results without requiring large amounts of user data to function correctly from day one.

### Pattern Learning Engine

A lightweight learning layer sits on top of the core algorithm. After each weekly check-in, the app updates energy cost estimates for recurring event types based on user feedback. For example, if a user consistently rates gym sessions as harder than their original tag suggested, the app quietly adjusts its internal weight for that event type going forward.

This is deliberately kept simple — it is database logic and weighted averaging, not neural network inference — which keeps costs manageable and behavior predictable. Users can toggle this feature on or off per event, respecting autonomy and trust.

---

## Product Design

### Design Principles

The design system for Nimva was built around four principles:

1. **Energy first** — the user's energy state is always visible and always the primary piece of information on screen
2. **Calm clarity** — the interface should never create the anxiety it is designed to prevent; information is revealed progressively, never dumped
3. **Neurodivergent-friendly** — high contrast, clear hierarchy, minimal cognitive load per screen, consistent patterns, no hidden interactions
4. **Accessible by default** — WCAG 2.1 AA compliance, minimum 44×44px touch targets, color never used as the only indicator of meaning

### Color System

The palette was developed around a purple-blue primary with warm amber accents used specifically for energy warnings and high-load indicators. This combination was chosen because it tests well for colorblindness, reads calmly on dark backgrounds, and allows warm colors to carry urgent meaning without feeling alarming.

| Role | Color |
|---|---|
| Primary (purple) | `#6c50d0` |
| Positive / flexible events (teal) | `#1d9e75` |
| Secondary flexible (blue) | `#378add` |
| Energy warning (amber) | `#ba7517` |
| Background (dark) | `#100c28` |

### Screens Designed

**Home Screen** — A scaling week strip where the selected day is prominently foregrounded and surrounding days recede in size, creating a natural depth effect. A character energy meter shows the user's weekly energy state at a glance alongside three summary chips: events remaining, heaviest day, and flexible slots available.

**Add Event (Fixed and Flexible)** — A clean two-state form distinguishing between unmovable commitments and events the app can schedule freely. Energy is tagged using four human-language labels (Alright / Manageable / Takes Effort / Pretty Draining) with a precision slider for fine-tuning. A toggle controls whether the app learns from this event type over time.

**Week Generation** — A three-state animated flow: fixed events shown as anchors with empty slots waiting, a build animation where flexible events drop into place day by day, and a completed week view with a burnout balance score, plain-language explanation, and options to approve or regenerate.

**Weekly Check-in** — A five-step conversational flow designed to feel like a brief friendly exchange rather than a form. The character speaks through speech bubbles, one question appears at a time, events are reviewed individually rather than in a list, and the app surfaces one or two smart suggestions based on what it learned — the user simply accepts or dismisses them. Steps three and four are explicitly skippable.

### Character / Mascot

Nimva features a mascot character named Ember — a simple black and white design with pale color highlights that adapt to the active theme. The character communicates the user's energy state through subtle expression changes rather than dramatic reactions, reflecting the app's tone of being calm but present. In production, the character will replace emoji placeholders with custom illustrated expressions.

---

## Name and Branding

Selecting a name for the application required navigating a surprisingly dense trademark and IP landscape. After evaluating over fifteen candidate names against USPTO records, App Store listings, and general brand searches, most were eliminated due to conflicts:

- *Ember* — habit tracker app using an identical metaphor
- *Emberly* — children's education app
- *Wick* — direct competitor in the student scheduling space
- *Steady*, *Lumi*, *Cadence*, *Drift* — various trademark or app store conflicts

The name **Nimva** was selected as the final working title. It is a coined word with no existing trademark conflicts found in public searches, no negative associations across major languages checked, and a soft sound profile that aligns with the app's calm and approachable identity. A formal USPTO trademark clearance search with an attorney is planned before commercial launch.

---

## Challenges and What I Learned

**Scoping a solo project** — One of the earliest and most important lessons was learning to distinguish between what the app needs at launch and what it could grow into. Features like advanced machine learning, social accountability modes, and multi-week planning are genuinely valuable but would have paralyzed development if included in version one. Defining a focused MVP forced clearer thinking about what the core value proposition actually was.

**Design for a specific audience without excluding others** — Designing for neurodivergent users required making decisions that turned out to improve the experience for everyone: progressive disclosure, consistent patterns, high contrast, low cognitive load per screen. This mirrors well-established principles in universal design, where accessibility constraints often produce better design overall.

**Naming and IP** — The trademark research process was unexpectedly complex and taught me that good ideas do not exist in a vacuum. Nearly every intuitive name in the wellness and productivity space is occupied. This pushed me toward coined words and original branding, which ultimately produced a more ownable identity than any of the natural-language candidates would have.

**Validating before building** — The decision to spend significant time on research, competitive analysis, and design before writing production code was uncomfortable at first but proved correct. The product that emerged from that process is considerably more focused and differentiated than the version I would have built if I had started coding immediately.

---

## Future Development Steps

The following steps are planned for continued development of Nimva:

1. **Trademark clearance** — formal USPTO search and filing for the Nimva name
2. **Custom character illustration** — commission or create original character art to replace emoji placeholders across all screens
3. **Development environment setup** — Xcode project initialization, Apple Developer Program enrollment
4. **Core loop implementation** — event input via SwiftData, on-device scheduling algorithm
5. **UI implementation** — SwiftUI screens matching the designed layouts
6. **Alpha testing** — internal testing with a small group from my robotics team and school community
7. **Pattern learning implementation** — post check-in feedback loop and energy weight adjustment
8. **Beta launch** — limited release via TestFlight
9. **App Store submission** — public launch on the iOS App Store
10. **Marketing and community** — outreach to neurodivergent student communities, ADHD-focused subreddits and Discord servers, documentation of the build process shared publicly
11. **Future Android exploration** — evaluate a Kotlin Multiplatform approach to share core scheduling logic, should an Android version become a priority later

---

## Reflection

Nimva began as a personal frustration and became an exercise in thinking like an engineer and a designer simultaneously. Every decision — from the technology stack to the color of a progress bar — required understanding not just what was technically possible but what would actually serve the person on the other end of the screen.

As someone who has spent significant time as President of a competitive robotics team — managing both the technical programming challenges and the organizational demands of leading a team — I am comfortable working within constraints, coordinating across moving parts, and iterating quickly toward a functional result. This project extended that skillset into new territory: product research, user experience design, business modeling, and intellectual property — areas I had not formally studied but found I could navigate by approaching them with the same systematic curiosity I bring to an engineering problem.

I am applying to study mechanical or aerospace engineering with an interest in eventually bridging into software and systems integration. Nimva is evidence of how I think when I am given a problem, the freedom to define the solution, and enough time to do it properly.

---

*Project status: Design phase complete. Development in planning.*
*All screens, design decisions, and technical specifications documented in accompanying reference file.*