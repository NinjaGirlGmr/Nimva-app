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

### 2026-06-28 — TestFlight detection: sandboxReceipt is the canonical iOS approach

**Spark:** Needed a way to auto-unlock PRO for beta testers on TestFlight without requiring a real StoreKit purchase, and without the unlock accidentally persisting when the app hits the App Store.

**Chase:** Several approaches: `#if DEBUG` (too broad — catches Simulator and local dev, not just TestFlight), a custom entitlement (overkill), or reading `Bundle.main.appStoreReceiptURL`. On TestFlight builds, the receipt URL ends in `sandboxReceipt` rather than `receipt` — Apple's documented distinction between sandbox and production.

**Catch:** Used `Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"` in `ProService.isTestFlight`. One gotcha: Xcode reported a deprecation warning saying "deprecated in macOS 15.0" — this is macOS-only. The API is still correct and recommended for iOS. Left as-is with a comment in source.

**Tags:** #decision #storekit #testflight

---

### 2026-06-28 — Multi-day fixed events: one Event per day, not a model change

**Spark:** Users wanted to add recurring fixed events (MWF class) without tapping through Add Event three times. The obvious approach was adding a `repeatDays: [DayOfWeek]` field to the Event model.

**Chase:** A model change means a SwiftData migration, a ModelConfiguration version bump, and every Event consumer needing to handle an array. For MVP with no live users migration is low-risk — but the model complexity is permanent and leaks into every query.

**Catch:** `saveEvent()` in AddEventView loops over `selectedDays` and creates one `Event` per day. Multi-day selection is a UX convenience layer only — not a data model concern. Each Event is independent, can be edited or deleted individually, and existing code that handles single events works unchanged.

**Tags:** #decision #data-model

---

### 2026-07-04 — Dark mode was already the only working mode

**Spark:** User asked about adding a light mode. Settings had a 3-button theme picker writing to AppStorage. Started looking at what a real light mode toggle would require.

**Chase:** Nimva uses entirely custom NimvaColors — hardcoded dark hex literals, not system adaptive colors with `dynamicProvider`. Switching to "light" via the picker would have just shown dark colors on a white background — broken, not styled. The feature was never real.

**Catch:** Removed the picker from Settings, added a static "Dark" label and placeholder note. Hardcoded `.preferredColorScheme(.dark)` in NimvaApp.swift. Light mode properly deferred to a design pass post-launch (issue #20). The fix was admitting the current state and making it explicit rather than leaving a broken toggle in place.

**Tags:** #decision #design-change

---

### 2026-07-05 — Procedural glow beats a drawn asset for radial ambient light

**Spark:** Wanted a soft ambient glow behind Ember's face to make the face-only display feel less flat and communicate expression through color.

**Chase:** Three options: (1) drawn PNG glow asset per expression color, (2) greyscale map + hue shift via `colorMultiply`, (3) procedural SwiftUI `Circle` with blur. Drawn approach needs separate assets per color and can't animate between them. Greyscale map is useful when the shape is complex. For a pure radial soft glow, a blurred circle *is* mathematically the same result as any drawn radial gradient.

**Catch:** Went procedural: `Circle().fill(glowColor).blur(radius: 28).opacity(0.22).scaleEffect(1.35)`. Color is expression-driven via `EmberExpression.glowColor`. SwiftUI's `.animation()` cross-fades automatically on expression change — something drawn assets can't do without multiple files and manual interpolation. Zero asset files added.

**Tags:** #decision #design-change #ember

---

### 2026-07-05 — private → internal is the right pattern for testable logic

**Spark:** Writing tests for `CalendarImportService` and time parsing hit a wall: `nimvaDay`, `dedupKey`, and `parseTimeString` were all `private`, so `@testable import Nimva` couldn't reach them.

**Chase:** Options: (1) test indirectly through public methods — fragile and tests too much at once, (2) move test code into the app target — wrong separation, (3) change `private` to `internal` on the specific methods being tested.

**Catch:** Changed `nimvaDay` and `dedupKey` to `internal`. Extracted `parseTimeString` from `TimeInputRow.commit()` into a module-level `internal` function. `@testable import` grants access to `internal` symbols — that's exactly what it's for. Rule now in CLAUDE.md and CONTRIBUTING.md: logic that needs testing should be `internal`, not `private`, and extracted out of view code into standalone functions.

**Tags:** #decision #testing #swift-pattern

---

### 2026-07-23 — CloudKit sync crashed on launch: default values, not entitlements

**Spark:** App crashed on launch somewhere between build 60 and 62. Bisected with the user to two commits: `fc390d6` (working) vs `1b3c947` "enable CloudKit private database sync" (failing) — so the CloudKit-enabling commit itself was the cause, not anything downstream. Two later commits (`fbd52db`, `02a974c`) had already tried graceful-fallback and test-runner-skip patches without actually fixing the crash.

**Chase:** Assumed first it'd be entitlements/provisioning (missing iCloud capability, container not deployed) since that's the usual CloudKit gotcha. It wasn't. SwiftData's CloudKit integration (`ModelConfiguration(cloudKitDatabase:)`) has a stricter, less-documented requirement: every non-relationship stored property must be `Optional` *or* have a default value declared inline on the property itself — an `init` parameter default doesn't count. `Event`, `WeekCache`, and `Intention` had none of their required properties (`name`, `isFixed`, `energyCost`, `weekStartDate`, `placementsJSON`, etc.) declared with inline defaults — only set via constructor params. `NSPersistentCloudKitContainer` validates this at `ModelContainer` init and traps (not throws), so it crashed before any `do/catch` in `NimvaApp.swift` could run — explains why the existing fallback-on-failure code never helped.

**Catch:** Added inline default values to every non-optional stored property across all three `@Model` classes (init bodies untouched — purely a schema-level fix, no behavior change). Also unwound a WIP workaround in `NimvaApp.swift` that had forced Debug builds to always use an in-memory store (which hid the crash locally but left Release/TestFlight builds still broken) — restored CloudKit for both Debug and Release now that the schema is actually compliant, keeping only the `XCTestSessionIdentifier` check so the test runner still gets in-memory. Rule going forward: any new `@Model` property needs either `?` or an inline default, full stop, if CloudKit sync is ever going to touch it.

**Tags:** #bug #swiftdata #cloudkit #decision

---

### 2026-07-23 — "Build my week" felt pointless because the week was already built

**Spark:** User noticed flexible events were already placed before ever tapping "Build my week" in the Plan tab — as if the button was theater over a decision already made.

**Chase:** Found three separate auto-recompute triggers, only one of which was ever meant to exist. (1) `HomeView`'s `.onAppear`/scene-phase-active handlers called `recomputeSchedule()` whenever `cacheIsStale` — which was true not just on a real week rollover, but also whenever *no cache existed yet at all*, silently running the full algorithm the first moment Home appeared with 3+ events. (2) `AddEventView` and `EditEventView`'s sheets both had `onDismiss: recomputeSchedule` — so every single add or edit re-ran the whole algorithm immediately. Neither of these was a bug in isolation — (2) was explicitly sanctioned by the "recompute on event added/edited/deleted" non-negotiable rule already in CLAUDE.md — but together they meant the schedule was fully assembled well before the user ever reached the Plan tab's explicit build ceremony. There was already a correctly-built "Ready to build your week? Tap to go to the Plan tab" nudge card gated on `cache == nil` — it just could never fire, because the cache was never allowed to stay nil.

**Catch:** Removed both. `HomeView.cache` now returns nil (not just "stale") whenever the freshest cache isn't for the current week, so the existing nudge card takes over correctly instead of showing stale or auto-built data. Add/Edit sheets no longer recompute on dismiss — new or edited events sit as "unscheduled" until the user explicitly taps "Build my week" or "Redo." Delete/undo-delete were deliberately left recomputing, since removing a *placed* event needs the stored balance score / heavy-day flags to stay accurate immediately, and that wasn't the behavior in question. This required actually rewriting the non-negotiable caching rule in CLAUDE.md and `technical-requirements.md` 8.3 — confirmed explicitly with the user first, since silently changing a documented non-negotiable rule isn't something to do on a hunch, even when the user's own request implies it.

**Tags:** #bug #decision #ux

---

### 2026-07-24 — `assert` + a graceful clamp are contradictory, and the crash masqueraded as unrelated test failures

**Spark:** While hardening the new rolling-calendar `weekOffset` parameter, added `assert(weekOffset >= 0, ...)` right above a defensive `let weekOffset = max(0, weekOffset)` clamp in `SchedulerService.regenerate`/`loadCachedSchedule` — belt-and-suspenders, in theory. Wrote a regression test that deliberately passes `weekOffset: -3` to confirm the clamp works. Ran the full suite: ~30 tests failed across four unrelated files (`CompletionStateTests`, `SchedulerServiceOverflowTests`, `SchedulerServiceDayQueryTests`, `UserTypeDetectionTests` in a completely different file) — none of which touch `regenerate` or `loadCachedSchedule` at all. Every failure showed `(0.000 seconds)` with no assertion message.

**Chase:** `assert()` traps (crashes the process) in debug builds when its condition is false — it doesn't throw, doesn't get caught, doesn't let code after it run. My own test's `-3` tripped the assert and crashed the whole test process mid-batch, and the test runner marked every other test scheduled in that same process/batch as "Failed" with zero diagnostic detail, since the process never got to report real results for them — a crash upstream reads as scattered unrelated failures downstream if you don't recognize the "0.000s, no message, spans totally unrelated suites" signature. `assert` and a subsequent graceful fallback are fundamentally incompatible: if the assert fires, the fallback code below it never executes anyway, so combining them either crashes (assert) or the assert is pointless dead weight (the clamp alone already handles it). Pick one contract, not both.

**Catch:** Removed both `assert` calls, kept only the silent `max(0, weekOffset)` clamp. This path needs to degrade safely even in debug builds (where the negative-offset regression test runs), not trap — a hard precondition would have been the right call for something the codebase asserts can truly never happen without a caller bug, but here the whole point was "verify this is handled gracefully," which is incompatible with a crashing guard. Rule going forward: don't pair `assert`/`precondition` with a fallback for the same condition in the same breath, and if a test deliberately exercises an "invalid" input, that's a signal the code path should degrade, not trap.

**Tags:** #bug #testing #swift-gotcha

---

### 2026-07-26 — "assume the newest row is the one you want" bit three separate times

**Spark:** Bug-testing the rolling calendar surfaced Home showing fixed events fine but never flexible ones, even after confirming a real "This week" build existed and displayed correctly in the Plan tab. Traced it to `HomeView.cache` — `caches.first` (newest by `weekStartDate`), then check if *that* row happens to match the current week; if not, treat it as "nothing built yet." Once a future week gets built via the rolling calendar chevrons, that future cache is legitimately "newest," so Home silently decided the current week — which was genuinely, correctly built — didn't exist.

**Chase:** This is the exact same mistake as `loadCachedSchedule`'s original `.first`-then-check bug from the rolling calendar's design-review pass (2026-07-23), and structurally similar to the future-trim ordering bug from the hardening pass the next day — three separate instances this week of "grab the newest/first item and assume it's the one you want" instead of actually searching for the match. The first two got fixed in `SchedulerService`; this one lived in `HomeView`'s own inline computed property, which duplicated similar lookup logic instead of reusing anything, so the earlier fix never reached it.

**Catch:** Extracted `SchedulerService.currentWeekCache(from:)` — a shared, searching (`caches.first { matches }`, not `caches.first` then check) lookup — and pointed `HomeView.cache` at it instead of keeping its own inline duplicate. Added regression tests specifically for "a newer future cache exists but the current week should still be found." Rule worth remembering: whenever multiple time-scoped rows can coexist (which is now permanent given the rolling calendar), "newest" and "the one I want" are different questions — every lookup needs to ask the second one explicitly, and duplicated inline versions of the same lookup are exactly how a fix in one place stops covering the others.

**Tags:** #bug #decision #swift-gotcha
