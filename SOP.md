# Nimva — Standard Operating Procedures

*Processes to follow every time, for every change — development, enhancement, or debugging.*

---

## 1. Issue-First Development

**No code before a GitHub issue exists.**

Every feature, bug fix, enhancement, or refactor starts with a GitHub issue — even small ones. This keeps the commit history meaningful and the portfolio evidence clear.

**Issue checklist before writing code:**
- [ ] Issue title is short and describes the outcome, not the task ("Week strip tap highlights selected day" not "fix tap bug")
- [ ] Body answers: *what* needs to change, *why* it matters, *which screen or file* is involved
- [ ] Label applied: `feature`, `bug`, `enhancement`, `refactor`, or `🔥 stray-spark`
- [ ] If it's a bug: include steps to reproduce and what the expected behavior is
- [ ] If it touches a screen: reference the relevant screen name from `docs/design-reference.md`
- [ ] If it touches the algorithm: reference the relevant FR number from `docs/technical-requirements.md`

**Reference the issue in every related commit:**

```
add squash-stretch transition to mood label (#14)
```

---

## 2. Git Workflow

### Branch naming
```
feature/issue-14-squash-stretch-text
bug/issue-22-energy-bar-clips
```

### Commit message format
Short subject line (under 60 characters) + bullet list of what changed. No multi-paragraph explanations — those go in the issue or Stray Spark Log.

```
add squash-stretch transition to mood label (#14)

- replaced contentTransition(.opacity) with .id() + AnyTransition
- added squashStretch preset to NimvaAnimation
- added SquashTransformModifier to NimvaMotion.swift
```

### What to never commit
- `.env` files or any file containing keys/secrets
- Xcode-generated `.DS_Store` files (already in `.gitignore`)
- `dev-notes/` directory (already excluded per CLAUDE.md)
- Half-finished features without a matching issue

---

## 3. Test Requirements

### What always needs unit tests
| Area | Rule |
|---|---|
| Algorithm changes | Any change to `Scheduler.swift` or `PatternLearning.swift` requires a corresponding test in `NimvaTests/SchedulerTests.swift` |
| New energy logic | Any new threshold, score formula, or placement rule needs at least one passing and one edge-case test |
| Model changes | Changes to `Event.swift` or `WeekCache.swift` fields need tests verifying persistence behavior |
| Bug fixes | Every bug fix needs a regression test — the test should fail on the old code and pass on the fix |

### What does NOT need unit tests (MVP)
- SwiftUI view layout and appearance — covered by the Xcode Preview + manual visual check
- CloudKit sync behavior — out of scope until integration test environment is set up
- StoreKit flows — too environment-dependent; validate manually in sandbox

### Running the test suite
```bash
xcodebuild test \
  -scheme Nimva \
  -destination 'platform=iOS Simulator,id=1B85C734-04C3-43D6-AA97-37911A3072B5'
```

**All 43 tests must pass before any commit that touches `Algorithm/` or `Models/`.**

### Coverage target
- `Algorithm/` directory: 90%+ line coverage
- `Models/` directory: 70%+ line coverage
- `Views/` directory: no coverage requirement (visual — use Previews)

### Known coverage exceptions (do not chase these)

| File | Coverage | Why it's OK |
|---|---|---|
| `WeekCache.swift` | 0% | Pure `@Model` storage — only field assignments in `init`, no logic to unit test. Requires a `ModelContainer` (integration test scope). |
| `SchedulerService.swift` | ~7% | All methods require `ModelContext` (SwiftData). Integration test scope only. |
| `Scheduler.swift` implicit closures | 0% | Xcode coverage tool artifact — `Dictionary.subscript(_:default:)` generates internal closures that the tool counts but that execute normally whenever the parent line runs. Cannot be targeted by tests. The real function coverage is 96%+. |

---

## 4. Design System Compliance

Every view must use the design system. No hardcoded values.

### Colors — always `NimvaColors.*`
- Never use `Color(hex:)` directly in a view — add a named constant to `NimvaTheme.swift` instead
- All color pairs must pass WCAG 2.1 AA (4.5:1 for normal text, 3:1 for large text/UI components)
- Contrast ratio comments are already on each color in `NimvaTheme.swift` — update them if you change a color
- **Coral (`#e0825a`) is the second flexible-event color everywhere — never use blue for this role**

### Typography — always `NimvaFont.*`
- No raw `.font(.system(size: X))` unless creating a new role — add it to `NimvaFont` in `NimvaTheme.swift`

### Animation — always `NimvaAnimation.*`
- Never use `.animation(...)` directly — always use `.nimvaAnimation(_:value:)` so Reduce Motion is respected
- Exception: `repeatForever` animations inside `.onAppear` — use the local `reduceMotion` environment variable pattern (see `EmberAvatar` in `EnergyZoneCard.swift`)
- Adding a new animation curve? Add it to `NimvaAnimation` enum in `NimvaMotion.swift` with a comment explaining when to use it

### Haptics — always `NimvaHaptics.*`
- Never call `UIImpactFeedbackGenerator` or `UINotificationFeedbackGenerator` directly
- Haptics must respect the haptics toggle in Settings (`@AppStorage("hapticsEnabled")`)

### Spacing and layout — always `NimvaLayout.*`
- Minimum touch target: `NimvaLayout.minTouchTarget` (44pt) — apply `.minTouchTarget()` to any interactive element visually smaller than this

---

## 5. Accessibility Checklist

Run this check on every new or modified screen before closing an issue.

- [ ] All text passes WCAG 2.1 AA contrast against its background (verify against `NimvaTheme.swift` contrast comments)
- [ ] Every interactive element is at least 44×44pt (use `.minTouchTarget()`)
- [ ] Color is never the only indicator of meaning — pair with text, icon, or shape
- [ ] Animation is non-essential — the screen is fully usable with Reduce Motion enabled
- [ ] Haptics and sounds are gated by their respective AppStorage toggles
- [ ] All images/icons have accessibility labels set (`.accessibilityLabel(...)`)
- [ ] VoiceOver reading order makes sense — use `.accessibilityElement(children:)` when needed

---

## 6. Architecture Rules (Non-Negotiable)

These were decided during planning and confirmed in use — don't change without a strong reason and a documented decision in the Stray Spark Log.

| Rule | Detail |
|---|---|
| **Cache the week** | Store computed result in `WeekCache`. Recompute only when an event is added, edited, or deleted. Never recompute per-screen or per-day. |
| **Energy labels are user-set** | The app never infers or auto-assigns an energy label. Users always set them. The EMA in `PatternLearning.swift` learns from user-set labels, not from sensor data. |
| **No backend at MVP** | SwiftData + CloudKit only. No Firebase, no Supabase, no custom server. |
| **No EventKit** | Calendar integration is deferred to v2. Do not import or use EventKit in MVP code. |
| **Single `Event` model** | Do not split into `FixedEvent` / `FlexibleEvent` SwiftData models. Use the `isFixed` bool. |
| **`totalDuration` and `deadline` are always nil in v1** | These fields exist on `Event` for future task-splitting. Do not implement splitting logic yet. |

---

## 7. PRO Tier Rules

- **No PRO mentions outside the Insights screen** — Settings, Home, Plan, and Onboarding screens stay neutral
- **Exception:** the onboarding PRO trial prompt (AppStorage key: `"hasSeenProTrialOffer"`, shown once only)
- **Insights is computed on-device, on-demand** — only when a PRO user opens the Insights tab. Never pre-compute, never cache PRO data.
- **Free tier must remain fully functional** — core scheduling is always free. PRO is a deeper layer, not a gate.
- **No dark patterns** — the trial prompt has a clearly visible "Maybe later" skip link. No guilt, no pressure, no hiding the skip.

---

## 8. Debugging Protocol

### Step 1 — Reproduce and document

Before touching any code, reproduce the bug reliably. Write down:
- What you did
- What happened
- What you expected to happen
- Which file/screen/function is involved

### Step 2 — Log a Stray Spark entry OR open a GitHub issue

Use `STRAY_SPARK_LOG.md` format:
```
### [Date] — Short title
**Spark:** What happened / what broke / what was noticed
**Chase:** What was tried, investigated, or considered
**Catch:** How it was resolved (or: still open)
**Tags:** #bug #decision #performance #design-change #open-question
```

For anything that took more than 20 minutes to debug, also open a GitHub issue with `🔥 stray-spark` label so it's searchable.

### Step 3 — Fix, then write a regression test

If the bug is in `Algorithm/` or `Models/`, write a test that fails on the unfixed code and passes after the fix. Commit the test alongside the fix.

### Step 4 — Close the issue with a "Catch" comment

Reference the commit hash in the closing comment.

---

## 9. SourceKit vs. Real Errors

SourceKit (the Xcode editor index) frequently reports false positives — `Cannot find type 'DayOfWeek' in scope`, `Cannot find 'NimvaColors' in scope`, etc. — for code that compiles and tests correctly.

**Triage rule:**
1. Does `Cmd+B` in Xcode succeed? → SourceKit false positive. Ignore.
2. Does `xcodebuild test` pass? → False positive. No action needed.
3. Does the build fail with a real compiler error? → Real issue. Fix it.

Do not make code changes in response to SourceKit-only errors.

---

## 10. Before Closing Any Issue

- [ ] Code compiles cleanly (`Cmd+B` or `xcodebuild build`)
- [ ] All existing tests pass (`xcodebuild test`)
- [ ] New tests written if the change touches `Algorithm/` or `Models/`
- [ ] Design system compliance checked (colors, animation, haptics)
- [ ] Accessibility checklist completed for any modified screen
- [ ] Issue referenced in the commit message (`#XX`)
- [ ] Stray Spark Log updated if anything surprising happened during the work
- [ ] Preview renders correctly in Xcode Canvas for any modified view
