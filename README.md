# Nimva — Concept Preview & Community Feedback

> *A scheduling application designed around energy, not just time.*

---

## About This Repository

This repository hosts the public concept preview for **Nimva**, an independently designed mobile application built to solve a problem I experience firsthand as a student managing a demanding academic schedule alongside leadership roles, extracurricular commitments, and personal health.

The concept page serves two purposes:

1. **To communicate the vision** — giving community members a clear, visual walkthrough of how Nimva works before a single line of production code is written
2. **To collect honest feedback** — an anonymous embedded form captures real reactions from students and peers whose input will directly shape what gets built

---

## The Problem Nimva Is Solving

Most scheduling tools treat time as the scarce resource. They help you organize what to do and when — but they ignore a more fundamental constraint: **energy**.

A well-organized schedule can still lead to burnout if it stacks draining activities back to back, places high-effort commitments on already heavy days, or fails to learn that what feels manageable on paper feels exhausting in practice.

Nimva approaches scheduling differently. Every event is tagged with an energy cost — not a number on a scale, but a human-language label that reflects how an activity actually leaves you feeling. The app then builds a week that distributes energy load intelligently, flags days at risk of burnout, and learns individual patterns over time through an optional end-of-week check-in.

The target audience is students and young adults — particularly those who are neurodivergent or managing ADHD — though the core concept is broadly applicable to anyone whose schedule regularly outpaces their capacity.

---

## What the Concept Page Includes

The hosted page walks through four core screens with annotated callouts explaining what each element does and why it was designed that way:

| Screen | Purpose |
|---|---|
| **Home screen** | Weekly energy overview, scaling day strip, color-coded event list |
| **Add event** | Fixed vs flexible event input, energy labeling, pattern learning toggle |
| **Week generation** | Animated build flow, energy balance score, approve or adjust |
| **Weekly check-in** | Conversational five-step feedback loop, smart suggestions |

Each annotation is written for someone encountering the concept for the first time — no assumed knowledge of the app required.

---

## The Feedback Form

The anonymous feedback form at the bottom of the concept page collects seven responses:

- Whether the core concept is immediately understood
- Likelihood of actual use
- Which feature resonates most
- Perceived ease of use (1–5 scale)
- Whether the design feels approachable
- Open suggestions for improvement
- Anything that felt confusing or off

Responses are stored anonymously — no names, no emails, no identifying information of any kind is collected or requested. The goal is honest, unfiltered reaction from real students and peers, not curated feedback from people who know they're being watched.

---

## Design Decisions Worth Noting

Several intentional choices were made in designing the concept page itself:

**Dark mode first** — the app's primary palette is deep purple and blue with warm amber accents used specifically for energy warnings. This combination was chosen for its calm, professional feel and its performance under colorblind accessibility checks.

**Annotated rather than described** — showing screens with numbered callouts communicates more in less time than written descriptions. Someone can understand the full concept in under three minutes without reading a word of prose.

**Anonymous by design** — removing all identity fields from the form was a deliberate choice. Feedback quality improves when respondents have no concern about being identified, particularly when asked to flag things that feel confusing or poorly designed.

**Conversational tone** — the app itself is designed to feel like a calm, helpful presence rather than a productivity tool. The concept page reflects that same tone — direct, warm, and free of unnecessary jargon.

---

## Project Status

| Phase | Status |
|---|---|
| Problem definition and market research | ✅ Complete |
| Feature set and freemium model definition | ✅ Complete |
| Design system and color palette | ✅ Complete |
| Core screen wireframes (8 of 8) | ✅ Complete |
| Community feedback collection | 🔄 Active |
| Name and trademark research | ✅ Complete — Nimva selected |
| Technical architecture and requirements | ✅ Complete |
| Development environment setup | ⏳ Planned |
| Core scheduling algorithm | ⏳ Planned |
| Native iOS build | ⏳ Planned |
| Alpha testing | ⏳ Planned |

---

## Technical Stack (Planned)

| Layer | Technology |
|---|---|
| Platform | Native iOS — Swift + SwiftUI |
| Local storage | SwiftData |
| Sync | CloudKit (private database, per-user) |
| Authentication | Sign in with Apple |
| Scheduling logic | On-device greedy heuristic |
| Subscriptions | StoreKit 2 |
| Calendar integration (v2) | Apple EventKit |
| Concept page | Vanilla HTML, CSS, JavaScript |
| Form backend | Formspree (anonymous submission handling) |
| Hosting | GitHub Pages |

---

## Context

This project was initiated and designed independently, outside of any coursework or guided program. It emerged from a genuine personal need — as a student simultaneously serving as President of my school's robotics team, President of my Student Honor Society, and active participant in upwards of nine clubs, managing time was never the challenge. Managing energy was.

Nimva is the result of approaching that problem the same way I approach an engineering challenge: define the problem precisely, research what already exists and why it falls short, make deliberate decisions about what to build and why, and document the thinking at every step.

The concept page and this repository are part of that documentation.

---

*Nimva is an independent student project. Currently in design and early planning phase.*