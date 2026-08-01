# Nimva — Energy-Aware iOS Scheduling App

> *A scheduling application designed around energy, not just time.*

---

## About This Repository

This repository is the working codebase for **Nimva**, a native iOS app (Swift + SwiftUI + SwiftData + CloudKit) built to solve a problem I experience firsthand as a student managing a demanding academic schedule alongside leadership roles, extracurricular commitments, and personal health.

The core app — the energy-aware scheduling algorithm, event CRUD, week generation, Home/Plan/Insights/Settings, onboarding, and a full test suite — is built and in active pre-launch hardening, heading toward a TestFlight beta. This repo started life hosting a concept-preview landing page used to collect early feedback before any code existed; that origin is kept below for the portfolio narrative, but it no longer describes what's in this repository today.

---

## The Problem Nimva Is Solving

Most scheduling tools treat time as the scarce resource. They help you organize what to do and when — but they ignore a more fundamental constraint: **energy**.

A well-organized schedule can still lead to burnout if it stacks draining activities back to back, places high-effort commitments on already heavy days, or fails to learn that what feels manageable on paper feels exhausting in practice.

Nimva approaches scheduling differently. Every event is tagged with an energy cost — not a number on a scale, but a human-language label that reflects how an activity actually leaves you feeling. The app then builds a week that distributes energy load intelligently, flags days at risk of burnout, and learns individual patterns over time through an optional end-of-week check-in.

The target audience is students and young adults — particularly those who are neurodivergent or managing ADHD — though the core concept is broadly applicable to anyone whose schedule regularly outpaces their capacity.

---

## Origin — The Concept Preview

Before any Swift code was written, the idea was validated with a standalone concept-preview page and an anonymous feedback form. Kept here as part of the project's actual history — define the problem, validate before building, then build — rather than as a description of the current repository.

### What the concept page included

The hosted page walked through four core screens with annotated callouts explaining what each element does and why it was designed that way:

| Screen | Purpose |
|---|---|
| **Home screen** | Weekly energy overview, scaling day strip, color-coded event list |
| **Add event** | Fixed vs flexible event input, energy labeling, pattern learning toggle |
| **Week generation** | Animated build flow, energy balance score, approve or adjust |
| **Weekly check-in** | Conversational five-step feedback loop, smart suggestions |

Each annotation is written for someone encountering the concept for the first time — no assumed knowledge of the app required.

### The feedback form

The anonymous feedback form at the bottom of the concept page collected seven responses:

- Whether the core concept is immediately understood
- Likelihood of actual use
- Which feature resonates most
- Perceived ease of use (1–5 scale)
- Whether the design feels approachable
- Open suggestions for improvement
- Anything that felt confusing or off

Responses were stored anonymously — no names, no emails, no identifying information of any kind was collected or requested. The goal was honest, unfiltered reaction from real students and peers, not curated feedback from people who knew they were being watched.

### Design decisions from the concept page that carried through

**Dark mode first** — the app's primary palette is deep purple and blue with warm amber accents used specifically for energy warnings. This combination was chosen for its calm, professional feel and its performance under colorblind accessibility checks — the same palette (`NimvaColors`) ships in the real app today, coral now standing in for the second flexible-event color for stronger colorblind contrast.

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
| Concept validation (preview page + feedback) | ✅ Complete |
| Name and trademark research | ✅ Complete — Nimva selected |
| Technical architecture and requirements | ✅ Complete |
| Development environment setup | ✅ Complete |
| Core scheduling algorithm | ✅ Complete — unit tested |
| Native iOS build | ✅ Complete — Home, Plan, Insights, Settings, onboarding |
| PRO tier (Insights, StoreKit 2 subscription) | ✅ Complete |
| CloudKit private-database sync | ✅ Complete |
| Pre-launch hardening (accessibility, App Store prep) | 🔄 Active |
| TestFlight beta | ⏳ Next |
| Public App Store launch | ⏳ Planned |

---

## Technical Stack

| Layer | Technology |
|---|---|
| Platform | Native iOS — Swift + SwiftUI |
| Local storage | SwiftData |
| Sync | CloudKit (private database, per-user) |
| Scheduling logic | On-device greedy heuristic (LPT-style bin packing) |
| Subscriptions | StoreKit 2 |
| Calendar integration | Apple EventKit — on-demand, multi-week import |
| Notifications | `UNUserNotificationCenter` (local only) |
| Hosting | GitHub Pages — privacy policy, and formerly the concept-preview page |

---

## Context

This project was initiated and designed independently, outside of any coursework or guided program. It emerged from a genuine personal need — as a student simultaneously serving as President of my school's robotics team, President of my Student Honor Society, and active participant in upwards of nine clubs, managing time was never the challenge. Managing energy was.

Nimva is the result of approaching that problem the same way I approach an engineering challenge: define the problem precisely, research what already exists and why it falls short, make deliberate decisions about what to build and why, and document the thinking at every step.

The concept page, this repository, and the commit history behind it are all part of that documentation.

---

*Nimva is an independent student project, built solo end-to-end — concept through native iOS implementation. Currently in pre-launch hardening ahead of a TestFlight beta.*