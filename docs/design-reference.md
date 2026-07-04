# Nimva — App Design Reference
*Last updated: active session*

---

## App Overview

**Name:** Nimva (working title — cleared in public searches, attorney check recommended)
**Concept:** Energy-aware scheduling app — manages *energy* across the week, not just time
**Tagline direction:** Your week, balanced around you
**Audience:** Students, neurodivergent users, young adults — works for everyone but over-delivers for this group
**Model:** Freemium

---

## Tech Stack

- **Platform:** Native iOS — Swift + SwiftUI, SwiftData, CloudKit
- **Calendar integration (v2):** Apple EventKit
- **Cost at any scale:** effectively $99/year flat (Apple Developer fee) — see `nimva_technical_requirements.md` for full detail, this is the single source of truth for stack and cost

---

## Free vs Paid Features

### Free
- Fixed + flexible event input with energy tagging
- Auto-generated week based on energy load
- Basic end of week check-in
- Character energy meter
- Passive pattern learning (schedule silently improves)
- Google + Apple calendar sync

### Paid (PRO)
- Detailed burnout analysis and written explanations
- Pattern coaching ("here's why Thursday is consistently hard")
- Multi-week planning
- Advanced calendar integrations
- Deeper personalization insights

---

## Design System

### Color Palette (Dark Mode Primary)
- **Background:** `#100c28`
- **Surface:** `#1e1850` / `#181440`
- **Border/frame:** `#241a50`
- **Card dark:** `#1a1648`
- **Purple primary:** `#6c50d0`
- **Purple muted:** `#2d2060` / `#5040b0`
- **Teal (flexible/positive):** `#1d9e75`
- **Blue (secondary flexible):** `#378add`
- **Amber (energy/warning):** `#ba7517` / `#ef9f27`
- **Text primary:** `#e8e0ff` / `#e0d8ff`
- **Text secondary:** `#a090d0` / `#c0b0f0`
- **Text muted:** `#6050a0`

### Color Palette (Light Mode)
- **Background:** `#f2f0ff`
- **Surface:** `#ffffff`
- **Border:** `#ccc6f0`
- **Card:** `#eeeaff` / `#e4f8f0` / `#e4f0fc`
- **Purple primary:** `#6c50d0` (same)
- **Text primary:** `#2a1f60`
- **Text secondary:** `#5040a0`
- **Text muted:** `#9080c0`

### Typography Scale
- **Page title:** 16–17px, weight 500
- **Section label:** 10–11px, uppercase, letter-spacing 0.07–0.08em
- **Card title:** 12–13px, weight 500
- **Body/meta:** 10–11px
- **Tags/chips:** 8–10px, weight 500

### Spacing & Shape
- **Card border radius:** 12–14px
- **Frame border radius:** 38–40px
- **8pt grid** for spacing consistency
- **Generous whitespace** — breathing room is intentional

### Accessibility
- WCAG 2.1 AA minimum contrast ratios (4.5:1 text, 3:1 large text)
- All interactive elements minimum 44×44px touch targets
- Color never used as the only indicator — always paired with label/shape
- ARIA labels on all character images and progress bars
- Colorblind-safe palette (no red/green only combinations)

---

## Character / Mascot

**Name:** Ember (character name within app called Nimva)
**Style:** Soft, rounded, calm yet playful — environmental shadow blending so she feels *made of* the app's atmosphere rather than pasted on top of it
**Emotional range:** Subtle — never dramatic or anxious
- 😴 Relaxed / waiting
- 🙂 Ready / content
- 🤔 Thinking / working
- 😌 Calm / listening
- 😊 Happy / satisfied
- 😐 Neutral / okay
- 😮‍💨 Concerned (heavy week) — subtle raised eyebrow, not alarmed

### Ember's Color Palette (finalised)

| Zone | Color | Hex |
|---|---|---|
| Body + lower face | App background | `#100c28` |
| Stomach + nose bridge | Deep purple | `#2a1a5e` |
| Nose + top of head | Coral | `#e0825a` |
| Cheek accents | Plum | `#83446b` |
| Frills | Mid purple | `#4c3280` |
| Frill frames | Bright amber | `#f7c46a` |
| Transition (amber→body) | Warm amber | `#f2a84b` |
| Nose tip + lips | Cream | `#fdf1da` |
| Eyes | Pale gold shades (multi-tone) | — |

**Design rationale:** Body uses `#100c28` (the actual app background) so Ember feels embedded in the scene. Coral nose/top of head (`#e0825a`) is a deliberate pop — the same coral used for flexible events, tying the character into the data color system. The amber frill frames (`#f7c46a`) match the existing `amberWarm` glow rendered behind her in code, making the glow feel like it emanates from her frills specifically.

**Mood state shifts:** Brighten the amber/coral areas for a good week; desaturate toward the purple tones for a heavy one. Silhouette stays identical — only color temperature shifts.

**Small size rule (24pt mini):** Expression must read from eye shape and body brightness alone — no fine detail. The cream nose tip and pale gold eye shine are the two anchor points that stay legible at tiny sizes.

**Character placement:**
- Home screen: energy meter zone
- Week generation: reacts during build process
- Check-in: speaks through speech bubbles each step
- Done screens: larger, more expressive

*Sprite sizes: 56pt standard · 64pt big moment · 24pt mini*

---

## Interaction & Motion Design

*Inspired by Duolingo's strengths — adapted to fit Nimva's calmer, care-focused tone*

### What to borrow

**1. Mascot does emotional work everywhere**
Ember shouldn't only appear on dedicated screens (check-in, generation). A small Ember icon should live persistently — e.g. a corner of the home screen — and its expression should reflect the week's energy state passively. A glance at Ember alone should communicate something, even without reading the bar.

**2. Micro-animations on routine actions**
- Energy bar changes use a subtle spring/ease animation, not instant snaps
- Approving a week triggers a brief positive moment — Ember's glow pulses softly (not full confetti)
- Completing the weekly check-in includes one small animated beat — Ember's glow brightening as the closing message appears

**3. Healthy continuity tracking (no streaks/guilt)**
Track "weeks where energy stayed balanced" as a quiet positive counter. Ember's glow can be gradually brighter with consistency. Critically: **no broken-streak imagery, no red X's, no negative framing for skipped weeks.** This audience is actively trying to avoid burnout — guilt mechanics would directly undermine the app's purpose.

**4. Journey/path view of progress (PRO candidate)**
A simple month view showing each week as a dot on a horizontal path, colored by energy balance score. Lets users see their own trend over time at a glance. Natural fit for the Insights screen.

**5. Bite-sized interactive instruction, not paragraphs**
Validates the onboarding direction already designed — screen 3 has users interact with an example energy chip rather than read about it. Extend this into the app itself: first-time-only inline hints pointing at UI elements ("tap here to set how this feels 👆"), shown once and never again.

**6. Sound and haptics (mobile)**
- Soft haptic tap when selecting an energy label
- Gentle chime when a week is approved
- **Must be easily mutable** — sound-sensitive users are common in this audience. Requires a clear toggle in Settings.

### What NOT to borrow

- Streaks with guilt mechanics or broken-streak visuals
- Leaderboards or social comparison
- FOMO-driven push notifications
- Any gamification that creates pressure to "perform" — directly contradicts the app's purpose

### Guiding principle

Borrow the elements about **warmth, feedback, and making routine actions feel good.** Avoid anything about **pressure, competition, or extrinsic motivation through guilt.** Nimva should feel like it's on the user's side, never judging.

---

## Visual Style Direction

*Result of a full style sweep — refining "professional yet inviting" with a cozy, lived-in quality*

### Decisions made

**Base palette: kept original purple/blue.** A side-by-side isolation test compared the original `#100c28`/purple base against a shifted plum/indigo base, both with identical glow treatment applied. The hue difference alone was negligible — the cozy feeling comes from the glow/spark additions, not a base palette change. Original palette retained, avoiding a risky full repaint of everything already designed.

**Ember as a literal light source.** The energy zone's warm glow is centered directly on Ember's circular avatar (not a corner of the card), radiating outward and fading toward the edge of the card. This makes Ember narratively *the* light source — "a small warm light in a cool space" — rather than a character sitting near an unrelated decorative glow.

- Glow: radial gradient `#e0a458` → `#c4895a` → transparent, centered on Ember's position, ~32% opacity, blurred
- Ember's avatar border: `#e0a458` (warm amber-terracotta) instead of cool purple
- Energy bar gradient updated to teal → mauve → amber (`#1d9e75` → `#a8689c` → `#e0a458`) to tie into the warm glow without changing the card color itself

**Spark connector on the week strip.** A small glowing dot (radial gradient `#ffd9a0` → `#e0a458`, soft box-shadow glow) sits beneath the currently selected day in the week strip. This replaced an earlier idea of making the whole day column glow — the spark is a quiet marker, not a competing focal point. Visually ties the selected day to Ember's "attention."

**Energy zone reorganized into a grouped card:**
- Top row: Ember (with glow) + mood label + day-specific note + weekly energy bar, side by side
- Divider
- Bottom row: three stat chips (events left / heaviest day / flex slots remaining)

This groups everything Ember-related into one cohesive unit rather than scattered separate elements — addresses "feels like a lot on screen" without removing content (an attempt to remove the stat chips and simplify event tags made the screen feel empty/hollow rather than calm — content was restored, organization was the actual fix).

**Day-reactive Ember (from earlier session):** Ember's expression and the mood/note text respond to whichever day is selected in the week strip — not just the weekly average. The weekly energy bar stays stable/weekly regardless of selected day, serving as the trustworthy "big picture" reference point. Glow ring color around Ember's face shifts warm (amber) for heavy days, cool (teal) for light days.

### Typography (reserved for future implementation)
- **Outfit** — headers, greetings, large numbers (energy %, balance scores) — adds personality
- **Nunito** — body text, event details, timestamps — maximizes readability
- Both meet dynamic type scaling and accessibility requirements for App Store/Play Store

### Things considered and explicitly rejected
- **U-shaped/warped card and button silhouettes** — explored but reverted; original rounded-rectangle shapes retained
- **Full plum/indigo base palette repaint** — tested via isolation comparison, difference too subtle to justify the risk/effort of changing every screen already designed
- **Removing stat chips and event type tags entirely** — made the screen feel empty; restored

### Accessibility notes specific to glow/warmth elements
- Glow effects stay soft/blurred (never sharp/high-contrast) — sharp bright elements against dark backgrounds can cause halation issues for users with astigmatism
- Glow and spark are decorative/atmospheric only — never the sole indicator of information (day selection is also shown via the existing scale/highlight treatment of the day column itself)
- Contrast ratios for any new text colors introduced (e.g. `#b8a8d0`, `#8a7ab8`) need verification against WCAG AA before final implementation — not yet checked

---

## Cross-Screen Consistency Rules

*From the full screen sweep — applies to all screens going forward, including re-renders of earlier screens*

### Color
- **Coral (`#e0825a`) replaces blue (`#378add`/`#185fa5`) everywhere** as the secondary flexible-event color. This was decided for colorblind accessibility (teal/blue can be confused under some colorblindness types; coral does not have this issue) but was only applied to the home screen render. **Standing rule: any screen showing the second flexible event color uses coral, not blue.** Affects: event detail screen, week generation screens, check-in screens when re-rendered.

### Ember's glow & spark
- **Glow and spark are not home-screen-exclusive** — Ember carries her glow wherever she appears prominently
- **Strongest on:** Home screen and Insights screen (PRO) — these are the "Ember is present and active" moments
- Other screens where Ember appears (onboarding, week generation, check-in) can carry a lighter/subtler version of the glow, or none, depending on context — not required to match home screen's intensity, but the glow should never feel like it's *missing* from a screen Ember is clearly "in"
- Spark marker (selected day indicator) is specific to the week strip — only appears on Home and Plan/week-view screens

### Stat chips / summary info layout
- Layout can vary by screen (e.g. home screen's grouped card vs. a different arrangement on Insights) — **variety is fine**
- Consistent factors across all variants: same chip shape/corner radius, same text hierarchy (large number/value, small label beneath), same muted background color (`#100c28` chip on `#1a1648` card)

### Typography
- Outfit/Nunito pairing remains reserved, not yet applied
- When applied: consistency rule is **per-area logic, not per-screen** — headers and big numbers get Outfit everywhere, body/dense text gets Nunito everywhere, regardless of which screen. Don't need pixel-identical font sizes across screens, just consistent *role-based* assignment

### Naming/labels
- "see all" (not "see full week" or other variants) — short link text standard
- Energy label visibility on event cards: **TBD as a single rule** — currently inconsistent (some cards show "· Takes effort" in the subtitle, others show time only). Needs one decision applied everywhere once UI development starts. Leaning toward: show on detail/list views, omit on compact home screen cards (home screen already communicates load via the day strip + Ember's day-note).

---

## Energy Tagging System

### Labels (Option D — Hybrid)
| Label | Meaning |
|---|---|
| Alright | Barely drains me |
| Manageable | Fine, I'll be okay |
| Takes Effort | Needs recovery time |
| Pretty Draining | Takes a lot out of me |

- User selects a label first (fast, approachable)
- Fine-tune slider underneath for precision
- Option E running in background: app learns category patterns and suggests energy levels over time
- Option E is user-controlled toggle — on/off per event

---

## Event Types

| Type | Color | Border |
|---|---|---|
| Fixed (unmovable) | Purple `#6c50d0` | `#2d2060` background |
| Flexible (auto-scheduled) | Teal `#1d9e75` | `#0c2418` background |
| Flexible variant | Blue `#378add` | `#0c1c38` background |

---

## Screens Designed

### 1. Home Screen ✓
**Zones (top to bottom):**
- Status bar
- Personalized greeting ("Good morning, Alex 👋")
- Scaling week strip — 7 days, perspective falloff from selected day
- Energy zone card — character + mood label + energy bar + 3 summary chips
- Day event list — dot + name + time range + energy label + type tag
- Add event button
- Bottom navigation (Home / Plan / Insights PRO / Me)

**Week strip dots:** Green = light day, Amber = moderate, Blue = heavy

**Summary chips:** Events left / Heaviest day / Flex slots remaining

---

### 2. Add Event — Fixed ✓
**Fields:**
- Event name (text input)
- Event type toggle: Fixed | Flexible
- Time: Start + End picker
- Energy section: 4 label chips + fine-tune slider
- Learn my patterns toggle (Option E)
- "Add to week" button (purple)

---

### 3. Add Event — Flexible ✓
**Fields:**
- Event name
- Event type toggle: Fixed | Flexible (flexible selected)
- Preferred window (Afternoon dropdown) + Duration (~1.5 hrs)
- Nimva note: "Nimva will find the best slot based on your energy load"
- Energy section: 4 label chips + fine-tune slider
- Learn my patterns toggle
- "Add to week" button (teal)

---

### 4. Week Generation Screen ✓
**Three states:**

**State 1 — Ready to build**
- Day strip scrollable, full day names, wider columns
- Fixed events placed as anchors
- Unscheduled flexible events shown as chips below
- Character: 😴 "ready when you are"
- Progress bar at 0%
- "Build my week" button (purple, sparkles icon)

**State 2 — Building**
- Day strip compresses to narrow columns (whole week visible)
- Events drop in day by day left to right
- Currently placing event shown at ~45% opacity
- Unscheduled chips shrink as placed
- Character: 🤔 "finding the best slots..."
- Progress bar filling
- Button disabled, shows "Building..."

**State 3 — Week ready**
- Full week shown in narrow columns
- Amber warning chip: "Wednesday looks heavy — tap to lighten it"
- Teal balance chip: "Energy spread across 5 days — nice"
- Character: 😊 "looks like a solid week"
- Verdict text: plain language explanation of what Nimva did
- Progress bar shows energy balance score
- Two buttons: "Approve week" (teal) + "Redo" (muted)

**Event adjustment (post-generation):**
- Tap event → list of available slots with energy load shown per day
- Drag and drop → direct placement, snaps into slot
- Both options flag slots that would cause high burnout

---

### 5. Weekly Check-in — Conversational Flow ✓
**Trigger:** Notification (in-app + push) on Sunday. Clearly optional.
**Progress:** Dot indicators at top — completed = teal, current = purple pill, remaining = dark

**Step 1 — Overall feeling**
- Character asks via speech bubble: "how did this week feel overall?"
- 5 feeling cards in 2×2 grid + 1 full-width: Rough / Heavy / Okay / Good / Really great
- Tap one → moves automatically (no next button)

**Step 2 — One event at a time**
- Character: "how did this one actually feel?"
- One event card on screen at a time
- Shows original energy tag for comparison
- Three buttons: Easier than expected / About right / Harder than expected
- Counter: "2 of 3 · tap to answer"
- Only surfaces events worth asking about (not all events)

**Step 3 — Optional note**
- Character: "anything on your mind? even a few words helps"
- Single minimal text field
- Hint: "Nimva uses this to improve your next week"
- Next button + "nothing to add" skip option

**Step 4 — Smart suggestions**
- Character: "based on this week — here are two small changes"
- App proactively surfaces 1–2 suggestions based on what it learned
- Each suggestion: label (Noticed / From your note) + description + "Sounds good" / "Ignore"
- "No changes needed" skip at bottom

**Step 5 — Done**
- Larger character, speech bubble: "your next week will feel a little more like you"
- Plain language summary of what Nimva learned (3 bullet points)
- Closing line: "see you next Sunday — have a good one"
- Single green "Back to home" button

---

## All Screens Designed ✓

All 8 planned screens are now complete:

- [x] Home Screen (dark + light)
- [x] Add Event — Fixed
- [x] Add Event — Flexible
- [x] Week Generation (3 states)
- [x] Weekly Check-in (5 steps, conversational)
- [x] Onboarding flow (4 screens)
- [x] Insights screen (PRO + locked free version with Ember/lock)
- [x] Settings / profile screen
- [x] Event detail / edit screen (free + PRO versions)

**Onboarding flow — 4 screens:**
1. Welcome — app name, tagline, three feature cards (energy aware / auto scheduled / gets smarter), get started button
2. The concept — character speech bubble, side by side comparison of week without vs with Nimva, caption explaining the reasoning, skip option
3. Energy tagging — critical screen addressing feedback confusion. Clear subtitle: "Nimva doesn't track your energy automatically — you tag it once and Nimva learns from there." Example event card with four label chips, Alright selected. Honest note at bottom.
4. Ready — happy character, three step checklist (add fixed → add flexible → build week), teal "Add my first event" button leading straight into add event flow

**Insights screen:**
- PRO: 5-week trend path (colored dots), pattern callouts, category breakdown (energy vs expected per category), coaching suggestion with accept/dismiss
- Free/locked: same content blurred (note: should use generic placeholder data, not real generated insights, to avoid wasted computation), Ember animated bonking against a lock icon, "Try PRO free for 7 days" CTA

**Settings / Profile screen — sectioned:**
- Profile card (avatar, name, email, edit)
- Appearance (light/dark/system)
- Notifications (check-in reminder, sounds & haptics)
- Energy & Learning (pattern learning toggle, reset patterns)
- Calendars (Google/Apple connection status)
- Account (export data, sign out, delete account)
- No PRO mentions — kept neutral per design decision, Insights is the only PRO touchpoint

**Event detail/edit screen:**
- Free: full edit access, basic "Nimva noticed something" note when pattern learning adjusted the event
- PRO: same edit access + full energy history timeline with reasoning ("3 weeks ago tagged Takes Effort → now Pretty Draining, based on 3 check-ins")
- Recurrence handling noted (edit asks "this one or all occurrences")

### Pending render
- Onboarding screens 1-4: designed, rendered (v3)
- All other screens: designed and rendered

### Loading states (noted, not yet designed)
- Default: Ember idle/walk-cycle animation during loads
- Edge case delight: if load exceeds expected time, Ember's idle animation could evolve into something playful (juggling, doodling) as a surprise rather than a built feature
- Mini-game (Chrome dinosaur style) explicitly NOT pursued — would imply performance problems and adds unnecessary scope

---

## Business Notes

- **Market:** Scheduling apps market $673M in 2025, projected $2.17B by 2034
- **Differentiator:** Manages energy not just time — complementary to Google Calendar, not competing
- **Key risk:** Discoverability (see Wick case study — good product, near zero downloads)
- **Launch strategy:** Build audience before launch, document build process publicly, lead with personal story, target neurodivergent communities on Reddit/Discord
- **Early test audience:** Robotics club, school community, ADHD/neurodivergent subreddits

---

## Name Search History
*All checked against web, App Store, Google Play, and USPTO public records*

| Name | Status |
|---|---|
| Ember | Conflict — habit tracker app |
| Emberly | Conflict — kids app + note-taking platform |
| Wick | Conflict — Wick study planner (same audience) |
| Steady | Conflict — employment platform |
| Lumi | Conflict — trademarked by AMAO Inc. in software category |
| Cadence | Risk — Cadence Design Systems trademark |
| Solv | Conflict — healthcare app |
| Vela | Multiple conflicts |
| Nura | Conflict — nutrition app + planning app |
| Drift | Conflict — sales platform + wellness apps |
| Eniva | Conflict — Eniva Health company |
| Paxen | Minor risk — PAX Labs similarity, attorney check needed |
| **Nimva** | **Clean — no conflicts found. Attorney clearance recommended before committing.** |

---

## Community Feedback Findings

*4 responses collected from initial concept page share — early signal only*

### Raw Results Summary

| Question | Responses |
|---|---|
| Core idea clarity | 3 × Yes immediately, 1 × Needed a moment |
| Most useful feature | 1 × Energy tagging, 2 × Auto week generation, 1 × Pattern learning |
| Ease of use (1-5) | 4 × rated 4 |
| Design approachability | 4 × Yes very much |
| Would you use it | 2 × Yes right now, 1 × Probably yes, 1 × Maybe |

### Key Findings

**What's working:**
- Design rated 4/5 by every respondent — clean sweep on approachability and friendliness
- Core concept landed immediately for 3 of 4 people
- 3 of 4 would use it right now or probably yes — strong signal for an unbuilt concept

**Confusion points (acted on):**
- Two respondents expressed confusion about how energy input actually works — *"I don't know how it would track my energy"* and *"how exactly would you input what you need to do?"* The concept of user-defined energy labels wasn't clear enough from the concept page alone.
- **Action taken:** Onboarding screen 3 was specifically designed to address this — clear subtitle: "Nimva doesn't track your energy automatically — you tag it once and Nimva learns from there." Concept page annotation language was also sharpened.

**Feature suggestions from respondents:**
- *"Send me notifications when my burnout is at its lowest"* — proactive good-energy notifications, telling the user when they have capacity to take something on. Genuinely useful and achievable.
- *"A tiny little bird"* — character direction suggestion from a respondent, aligns with the calm playful personality defined for Ember. Filed as an open direction to consider for character design, not yet committed to.

### New Feature Added to Roadmap

**Proactive capacity notifications (PRO)**
When the user has an unusually light day or open energy window, Nimva sends a gentle notification: *"You have good energy capacity tomorrow afternoon — a good time to schedule something that usually takes effort."* Turns the app from reactive to proactive. Stored as a user preference toggle, computed on-device against the week's energy map.

---

## Technical Architecture, Cost Map & Infrastructure

*This section previously lived here but has been superseded — the full, current technical architecture (native iOS / Swift / SwiftUI / SwiftData / CloudKit), cost map, infrastructure decisions, and self-sustaining economics now live in `nimva_technical_requirements.md`, which is the single source of truth for all technical and cost details. Keeping that information in one place avoids this document and the requirements doc drifting out of sync as the stack evolves.*

See `nimva_technical_requirements.md` sections 4-7 specifically for the current stack and cost model.

---