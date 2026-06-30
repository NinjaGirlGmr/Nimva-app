# Nimva — Goals & Direction

_Last updated: 2026-06-30_

---

## The One Problem We're Solving

**Scheduling burnout.**

Not time management. Not productivity. The specific feeling of looking at your week and already feeling exhausted before it starts — where your schedule is draining you faster than you can recover. Google Trends confirms this is a rising, unaddressed problem ("scheduling burnout" went from 0 to 50–100 in the last 1–2 years).

Every feature we build passes this test: _does this help a user feel less burned out by their schedule, or supported through it?_ If not, it waits.

---

## The Four Things Nimva Does

Everything in the app exists to serve one of these four things. In order:

### 1. Look
See the week for what it actually is — in energy terms, not just time. Get an accurate picture fast, with as little friction as possible. Calendar import exists for this. The week strip and energy zones exist for this.

### 2. Help
Move what can be moved. Protect what should be protected. The scheduling algorithm places flexible events intelligently — lighter tasks after heavy days, small gaps kept clear. For users with nothing movable, the app still helps by surfacing *where* the small pockets of control are.

### 3. Tell
Report the energy state honestly. Heavy days, light days, recovery windows. Not buried in a report — surfaced clearly and plainly. "Tuesday is your heaviest day. You have a 20-minute gap at 2pm — that's a recovery window." If the week is genuinely hard, say so.

### 4. Support
Be on the user's side. Acknowledge hard weeks. Surface patterns over time so the user understands themselves better. Never guilt, never pressure. The tone is a calm observer who's rooting for them.

---

## Who We're Building For

Three real user types, detected from schedule data — never asked directly:

| Type | What they have | What Nimva emphasizes |
|---|---|---|
| **The Optimizer** | Mix of fixed + flexible events | Rearrange flexible things intelligently |
| **The Overloaded Fixed** | Wall-to-wall fixed, little movable | Name the problem, surface micro-recovery, validate the feeling |
| **The Pattern Learner** | Some flexibility, wants long-term insight | Understand their own energy trends over time |

The app detects which situation a user is in and shifts what it surfaces. Same data, different emphasis.

---

## What "Support" Actually Looks Like

For users with flexibility: "Here's how I rearranged your week. Tuesday was heavy so I moved study time to Thursday."

For users with no flexibility: "This week is genuinely packed. That's not a personal failing — it's the schedule. Here's where your recovery windows are."

For everyone: honest forward warnings. "Thursday has 4 draining events back to back. How you spend Wednesday evening matters."

The app should never pretend it can fix an unsustainable schedule. Trustworthy is more valuable than reassuring.

---

## Feature Priority

### Must ship (MVP)

| # | Feature | Which of the four it serves |
|---|---|---|
| #18 | StoreKit 2 / ProService | Infrastructure — gates PRO |
| #19 | On-demand calendar import | **Look** — removes re-entry friction |
| #8 | Insights tab | **Support** — pattern evidence over time (PRO) |
| #9 | Onboarding PRO trial prompt | Conversion path |
| #10 | Weekly check-in flow | **Support** — closes the loop, feeds patterns |
| #11 | Pattern reset | Data hygiene |
| #12 | CloudKit sync | Requires Apple Developer enrollment |

### Bonus features — only if they genuinely help and don't overwhelm

These are worth building if they serve Look / Help / Tell / Support without adding complexity the user has to manage:

| Idea | Which of the four | Notes |
|---|---|---|
| Recovery window callouts | **Tell** | Empty gaps explicitly labeled — useful for Overloaded Fixed users |
| "Name the feeling" moment | **Support** | One sentence after week gen if the week is brutal. Low cost, high trust |
| Recurring event auto-detection | **Look** | Import the same event multiple weeks → offer to make it recurring |
| Energy default by category | **Help** | Suggest a label based on past pattern — still user-set, just faster |
| Weekly load preview | **Tell** | "This week has 4 heavy days. Wednesday is your lightest." |

These are not on the build list yet. Each one gets evaluated before being issued: does it actually help, or does it just make the app feel busier?

### v2 — after real user feedback

| # | Feature | Why it waits |
|---|---|---|
| #15 | Proactive capacity alerts | Needs pattern data from real usage first |
| #13 | Multi-week view (PRO) | Complexity outweighs MVP value |
| #14 | Shareable weekly report | Nice-to-have, not core |
| #16 | Ongoing calendar sync | Much more complex than on-demand import |
| #17 | Android / KMP | After product-market fit confirmed on iOS |

---

## What We Are Not Building

- A to-do list
- A time tracker
- A mood journal
- A habit tracker
- A general calendar replacement
- Anything requiring a backend server at MVP
- Dark patterns on PRO upsell

---

## The North Star

A user opens Nimva on Sunday evening. They import their week from Apple Calendar in under a minute. The app shows them the energy shape of their week — clearly, honestly. If things can move, they move. If they can't, the user understands why Wednesday is going to be hard and where the one small window to breathe is. They close the app feeling like someone looked at their week with them and helped them carry it a little.

That's the product.
