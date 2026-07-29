# TestFlight Beta Setup

Step-by-step for getting Nimva into testers' hands via TestFlight. Do these in order — later steps depend on earlier ones existing in App Store Connect.

## 0. Before you start

These block the upload/review and should already be done (or in progress) before you touch App Store Connect:

- [ ] App icon added (#26) — App Store Connect rejects uploads without one
- [ ] Accessibility audit pass (#30) — see the note in the previous conversation on how to actually drive it (iOS Settings → Accessibility, not an in-app control)
- [ ] Clean end-to-end run on a fresh simulator/device (onboarding → add events → build a week → check-in)
- [ ] Confirm no purchase is required in TestFlight — `ProService.isTestFlight` auto-unlocks PRO for any build installed via TestFlight (`sandboxReceipt`), so testers never hit StoreKit at all. Nothing to configure here, just don't remove that check.
- [x] Fixed 2026-07-29: local data (including Insights) was getting wiped on schema changes — `NimvaApp.swift`'s CloudKit fallback used to delete the store on *any* container-init failure, including a plain schema mismatch or CloudKit not being reachable yet. Now uses a versioned schema + migration plan (`Nimva/Models/NimvaSchema.swift`) and only wipes as a true last resort. **Before adding/changing any field on `Event`, `WeekCache`, or `Intention` from here on, follow `docs/schema-migrations.md`** — skipping it reintroduces the same data-loss bug, and after 1.0 ships that means a real tester's/user's schedule instead of just your own test data.

## 1. Apple Developer Program

- [ ] Enroll (or confirm active enrollment) at developer.apple.com — required before App Store Connect will let you create an app record
- [ ] Confirm your Team ID matches what's set in Xcode's Signing & Capabilities for the Nimva target

## 2. App Store Connect — app record

- [ ] Create the app record: My Apps → + → New App
  - Platform: iOS
  - Name: Nimva (check availability — reserve it now if not already)
  - Primary language, Bundle ID (must match Xcode's), SKU (any internal string, e.g. `nimva-ios`)
- [ ] Under **App Information**:
  - Privacy Policy URL: `https://ninjagirlgmr.github.io/Nimva-app/privacy.html`
  - Category: pick something like Productivity or Health & Fitness
- [ ] Under **App Privacy** (privacy "nutrition label"): fill this out now even though you're still pre-listing — TestFlight review checks it. Since there's no backend and no analytics, most categories should be "Data Not Collected." CloudKit sync counts as user content stored, but it's in the user's own private database, not shared with you — reflect that honestly.

## 3. CloudKit — production container

- [ ] In Xcode, confirm the CloudKit container is using the **Production** environment, not just Development, before archiving for TestFlight. Development-only data doesn't carry over to testers.
- [ ] In the [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard/), deploy your Development schema to Production for the container Nimva uses. This is a one-way push and only needs doing once (redo it if you add/change SwiftData models later).
- [ ] If you add/change a model AFTER deploying to Production: redo the Dashboard push AND follow `docs/schema-migrations.md` for the app-side migration. Do both — the Dashboard push is CloudKit's server-side schema, the migration plan is the on-device store; skipping either one risks a tester's local data getting wiped or their sync silently breaking.

## 4. Build upload

- [ ] In Xcode: Product → Archive (Release configuration, real device or "Any iOS Device" destination — Archive doesn't work for Simulator)
- [ ] Organizer → Distribute App → App Store Connect → Upload
- [ ] Wait for processing to finish (usually 15–60 min) — you'll get an email, or watch the build appear under TestFlight tab in App Store Connect

## 5. TestFlight — Test Information

- [ ] Under the TestFlight tab → Test Information, fill in:
  - Beta App Description (what testers are testing)
  - Feedback email (your address)
  - Marketing URL (optional)
  - Privacy Policy URL (same as above — TestFlight asks separately from App Information)

## 6. Internal Testing (fastest way to get started)

- [ ] Add yourself / anyone on your Apple Developer team as an internal tester — internal builds skip Beta App Review, so this is the quickest way to confirm the uploaded build actually installs and runs correctly before inviting outside testers
- [ ] Add the processed build to the Internal Testing group, install via the TestFlight app, smoke-test it

## 7. External Testing (friends, family, real beta testers)

- [ ] Create an External Testing group (e.g. "Beta Testers")
- [ ] Add the build to the group
- [ ] Submit for **Beta App Review** (required for any external tester, even a group of one) — this is a lighter review than full App Store review but still takes 1–2 days typically
- [ ] Once approved, invite testers by email or share the public TestFlight link
- [ ] Testers install the TestFlight app from the App Store, then accept your invite

## 8. After testers are in

- [ ] Watch TestFlight crash logs and feedback (screenshots + written feedback come through automatically via the TestFlight app's shake-to-report)
- [ ] Each new build you upload needs to go through steps 4–5 again but does NOT need re-review for *internal* testers; external testers need re-review only for build changes that alter significant functionality (minor bug-fix builds are often auto-approved faster)

## Notes specific to Nimva

- No backend, no server-side feature flags — every tester runs the same on-device logic, so bugs are always reproducible locally if a tester describes their steps.
- Insights (PRO) resets its data when a new build is installed over an old one during testing — this is expected (it's a fresh SwiftData store per install unless CloudKit sync has already caught up), not a bug to chase.
- Promo codes for post-launch free access (#89) are a separate, later step — not needed for beta since TestFlight already grants PRO for free automatically.
