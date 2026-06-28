# 🔥 The Stray Spark Log

*A running record of bugs caught, decisions made, and sparks that flew off while building Nimva.*

---

## What This Is

Every fire throws off a few stray sparks — small, sometimes unexpected, occasionally the start of something interesting. This log tracks the bugs, fixes, dead ends, "wait why did I do it that way," and small decisions made along the way while building Nimva.

It serves two purposes:

1. **A real debugging/decision journal** — so future-you (or anyone picking up this project) can see *why* something is the way it is, not just *what* it is
2. **A documentation artifact** — for the portfolio, this shows the actual engineering process: not just the polished result, but the thinking, mistakes, and course-corrections along the way. The real work lives in this kind of log, not just the final demo.

---

## How to Use This Log

Each entry should be quick to write — this isn't meant to be formal. A simple format:

```
### [Date] — Short title
**Spark:** What happened / what broke / what was noticed
**Chase:** What was tried, investigated, or considered
**Catch:** How it was resolved (or: still open, revisit later)
**Tags:** #bug #decision #performance #design-change #open-question
```

Entries don't need to be bugs specifically — "Stray Spark" also covers:
- A design decision that changed mid-implementation
- A "huh, that's not what I expected" moment
- A performance discovery (good or bad)
- An open question that got deferred

---

## GitHub Issues Integration

This log pairs naturally with GitHub Issues once development moves to a repository:

- Create a custom label: **🔥 `stray-spark`**
- The format above (Spark / Chase / Catch / Tags) works directly as a GitHub Issue template — "Spark" and "Chase" go in the issue description, "Catch" goes in the closing comment when resolved, "Tags" become GitHub labels
- Closed stray-spark issues become a searchable history of the project's actual development story — useful both for development (searching past fixes) and for the portfolio (showing real engineering process via commit/issue history, not just polished final code)
- Open stray-spark issues with no "Catch" yet are naturally the project's informal backlog of open questions/known quirks

---

## Log Entries

### [Template] — Example Entry

**Spark:** The scheduling algorithm placed two "Pretty Draining" events back to back on the same day, even though the balance score said the week was "good."

**Chase:** Checked the balance score formula — it averages load across the *week*, so two heavy events on one day can still produce a decent weekly average even if that specific day is rough. The score was technically correct but didn't communicate the actual problem.

**Catch:** Added a separate per-day check (already partially designed as the "heavy day" flag, FR-3.3) that's independent of the weekly average — a day can be flagged even if the week overall looks fine. This was a case where the *requirement* was right but the *implementation* needed an additional check the requirement didn't explicitly spell out.

**Tags:** #bug #design-change

---

*New entries go below this line.*

---

### 2026-06-28 — @ViewBuilder won't let you assign inside a switch

**Spark:** `WeekGenerationView.swift` threw `Type '()' cannot conform to 'View'` at a `switch` statement that assigned a string variable (`warningText = "..."`) before returning a view. The error message points at the switch, not the assignment — confusing.

**Chase:** Inside a `@ViewBuilder` context, Swift treats every `switch` as view-producing. An assignment like `warningText = "..."` returns `()` (Void), which can't conform to `View`. The compiler error is technically correct but the phrasing is misleading — you'd expect it to say "assignment is not a view."

**Catch:** Extracted the string logic into plain private functions (`heavyDayChipText(for:)`, `positiveChipText(activeDays:flexPlaced:)`) outside the `@ViewBuilder` context. The `insightChips` var then just calls those functions. Rule going forward: never assign to a variable inside a `@ViewBuilder` switch. Extract to a helper function instead.

**Tags:** #bug #swift-gotcha

---

### 2026-06-28 — `textMuted` failed WCAG AA contrast

**Spark:** `NimvaColors.textMuted` was `#6050a0` (2.85:1 against the dark background). WCAG 2.1 AA requires 4.5:1 for normal text. The muted text color was failing accessibility even for a basic readability check.

**Chase:** Used a JavaScript contrast ratio formula to check all color pairs: `L1 = (channel >= 0.04045) ? ((channel + 0.055) / 1.055)^2.4 : channel/12.92`. Discovered the original purple-leaning muted color was too dark on the dark card background.

**Catch:** Replaced `textMuted` with `#8878c8` (5.04:1 ✓ passes AA). Kept the original `#6050a0` as `textDecorative` for purely incidental text (separators, decorative labels) where contrast doesn't affect readability. Added contrast ratios as inline comments on all colors in `NimvaTheme.swift` so any future change can be immediately cross-checked.

**Tags:** #bug #accessibility #design-change

---

### 2026-06-28 — SourceKit false positives throughout the project

**Spark:** SourceKit continuously reported errors like `Cannot find type 'Event' in scope`, `Cannot find 'NimvaColors' in scope`, `No such module 'UIKit'` — for code that compiles and runs correctly. These appeared in the editor and via diagnostic tools even while tests were passing.

**Chase:** These are transient SourceKit indexing artifacts. SourceKit maintains its own index separately from the compiler; when new files are added or modules change, the index falls behind. The actual Swift compiler (used by Xcode Build and xcodebuild) always had clean output.

**Catch:** False positives clear after Xcode reindexes (Cmd+Shift+K clean build, or just waiting). No code changes needed — confirmed by running the full test suite (`xcodebuild test`), which shows 43/43 passing against the same files SourceKit claims can't compile. Going forward: trust `Cmd+B` and the test runner over SourceKit diagnostic annotations.

**Tags:** #tooling #xcode-quirk

---

### 2026-06-28 — Reduce Motion wasn't wired to ad-hoc animations

**Spark:** Several existing animation calls (`EmberAvatar`'s ring transition, `WeeklyEnergyBar`'s fill, `WeekStripView`'s day selection) used raw `.animation(...)` modifiers. These ignore iOS's "Reduce Motion" accessibility setting — users who need motion reduced (vestibular disorders, ADHD sensitivity) would still get animations.

**Chase:** WCAG 2.3.3 requires respecting `prefers-reduced-motion`. iOS exposes this as `@Environment(\.accessibilityReduceMotion)`. The fix needed to be systematic — a per-call check every time would be easy to forget.

**Catch:** Created `NimvaMotion.swift` with a `nimvaAnimation(_:value:)` view extension that automatically reads `accessibilityReduceMotion` and passes `.none` when it's enabled. All animation calls across the app now route through this. The Ember breathing pulse (new this session) is the first animation to also use a local reduce-motion check inside a `@State`-driven `repeatForever` animation — needed a slightly different pattern since `animation(_:value:)` doesn't work for repeat-forever animations triggered on `onAppear`.

**Tags:** #accessibility #design-change #decision

---
