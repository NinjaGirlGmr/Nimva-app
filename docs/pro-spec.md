# Nimva PRO — Feature Specification

*What PRO adds, why it's worth paying for, and how to surface it without pressure*

---

## Philosophy

The free tier handles the core need: scheduling around energy so weeks don't burn you out.
PRO answers a deeper question: **"Why does my week keep feeling like this, and what can I actually do about it?"**

Nimva's goal is to help first. PRO revenue covers costs and keeps the app running — it is not
the primary objective. The free tier should be genuinely useful on its own.

PRO should never feel like features are being withheld. It should feel like a deeper layer
for users who are ready for it.

---

## PRO Features (in priority order)

### 1. Insights — multi-week energy evidence
**What it is:** 5+ week trend showing energy patterns over time — balance scores, heaviest days,
pattern callouts, category breakdowns.

**Why it matters for this audience:** This is data users can bring to a therapist, ADHD coach,
counselor, or parent. "Look — Tuesdays have been depleted for 6 weeks. This isn't me failing,
this is the schedule." No other scheduling app produces this kind of evidence.

**Implementation:** Computed on-device, on-demand when a PRO user opens the Insights tab.
Free users see a blurred placeholder with generic data — never wasted compute on real data
for non-PRO users.

**Free locked view:** Ember animated against a lock icon. Upgrade CTA: "Try PRO free for 2 weeks."
Generic placeholder data only — no real user insights shown.

---

### 2. Pattern coaching — named, specific, actionable language
**What it is:** Written coaching suggestions based on detected patterns.
Not just a chart — full sentences:
> "Wednesdays have been your heaviest day for 4 weeks. The common factor is two draining fixed
> events with no gap between them. That window at 2pm is your best recovery time — keeping it
> clear makes the rest of the afternoon measurably better."

**Why it matters:** The app plays the role of a calm observer who notices things the user can't
see when they're inside the week. This is the counselor/coach voice.

**Implementation:** Generated from WeekCache + check-in history, fully on-device. Part of the
Insights screen, below the trend visualization.

---

### 3. Proactive capacity notifications
**What it is:** When an upcoming day or window looks lighter than the user's average, Nimva
sends a gentle notification:
> "Tomorrow afternoon looks lighter than usual. If there's something draining you've been
> putting off, tomorrow is a good day for it."

**Why it matters:** Flips the app from reactive ("here's your week") to proactive ("here's
your window"). Especially valuable for ADHD users who struggle to self-initiate — the app
surfaces the moment, the user just has to act.

**Implementation:** Local notification, scheduled on-device when the week is approved.
Computed from daily loads vs the user's rolling average. Toggle in Settings (PRO only).

---

### 4. Multi-week view
**What it is:** Ability to plan and view 2–4 weeks ahead, not just the current week.

**Why it matters:** Useful for planning around exams, deadlines, events, school terms.
The free tier is intentionally week-by-week. PRO gives the bigger picture.

**Implementation:** Extends WeekGenerationView to support future week generation and caching.
WeekCache model already supports this — just need UI and navigation.

---

### 5. Shareable weekly report
**What it is:** A simple exportable summary of any past week: energy balance score, heaviest day,
what patterns Nimva noticed, one suggestion. Exportable as PDF or via iOS share sheet.

**Why it matters:** Something a user could send to their ADHD coach, show a parent, or bring
to a therapy session. No other scheduling app produces this. Turns Nimva into evidence,
not just a tool.

**Implementation:** Generate a simple view from WeekCache data, render with ImageRenderer
or a PDF library, share via ShareSheet.

---

## What PRO Does NOT Include

- Anything that gates the core scheduling function (that stays free, always)
- Guilt mechanics, streaks, or pressure to upgrade
- Upsells anywhere except the Insights screen lock screen
- Features that require a backend or external service (all on-device)

---

## Onboarding PRO Trial Prompt

Shown as a soft interstitial after the final onboarding screen, before the user enters the app.
Not a hard paywall — clearly skippable.

**Design:**
- Ember with a warm expression (😊)
- Heading: "One more thing before you start"
- Subheading: "Nimva PRO is free for 2 weeks"
- 3 bullet points (Insights + evidence, pattern coaching, capacity alerts)
- Fine print: "No charge until after 14 days. Cancel anytime."
- Primary button: "Start free trial" (teal)
- Secondary: "Maybe later — go to free version" (text link, clearly visible, no dark patterns)

**Tone:** Informative, not pushy. The user already knows the free tier exists from onboarding.
This is just letting them know the trial exists, not pressuring them.

**AppStorage key:** `"hasSeenProTrialOffer"` — show once, never again.

---

## Pricing (from StoreKit 2 plan)

- 2-week free trial
- Monthly and annual options
- Price TBD — validate after launch with real user feedback
- No price mentions in onboarding — shown only on the StoreKit paywall screen

---

## Marketing Angle for PRO

Target: users who already love the free tier and want to understand their patterns better.

Core message: *"You've been using Nimva to manage your week. PRO shows you why certain weeks
keep feeling heavy — and gives you the data to do something about it."*

Secondary message: *"The kind of pattern data you'd want to bring to a counselor or coach."*

Do NOT lead with features. Lead with what it gives the user:
- Understanding (why does this keep happening?)
- Evidence (data to show someone else)
- Agency (knowing your good windows before they pass)
