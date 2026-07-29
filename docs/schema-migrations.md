# Schema migrations — read this before changing any `@Model`

## Why this file exists

`NimvaApp.swift` used to delete the local SwiftData store any time the CloudKit-backed
container failed to initialize — which happens whenever a model's fields change without
a matching migration. That meant every schema tweak wiped local data on the next launch,
including Insights history. Fixed 2026-07-29 by adding a versioned schema
(`Nimva/Models/NimvaSchema.swift`) and tightening the fallback so a wipe only happens as
an absolute last resort (real store corruption), not for an ordinary schema change or a
CloudKit hiccup.

That fix only holds if every future model change goes through the steps below. Skipping
this for a "quick field add" recreates the exact bug it fixes — and after 1.0 ships, that's
a real user's schedule getting wiped, not just your own test data.

## Every time you add/remove/rename a field on `Event`, `WeekCache`, or `Intention`

1. Open `Nimva/Models/NimvaSchema.swift`.
2. Copy the current highest `NimvaSchemaVN` enum, bump the number (e.g. `NimvaSchemaV1` →
   `NimvaSchemaV2`), and bump `versionIdentifier` (e.g. `Schema.Version(2, 0, 0)`).
3. Add a `MigrationStage` to `NimvaMigrationPlan.stages` describing the move from the
   previous version to the new one:
   - **Lightweight** (adding an optional field, adding a field with an inline default,
     removing a field) — usually just:
     ```swift
     .lightweight(fromVersion: NimvaSchemaV1.self, toVersion: NimvaSchemaV2.self)
     ```
   - **Custom** (renaming a field, changing a type, splitting/merging fields, backfilling
     a new non-optional field from old data) — use `.custom(fromVersion:toVersion:willMigrate:didMigrate:)`
     and write the transform explicitly. Don't guess — if a field rename is involved, a
     lightweight migration silently drops the old data instead of carrying it over.
4. Update `NimvaApp.swift`'s `Schema(versionedSchema:)` call to point at the new latest
   version if it's referenced by name anywhere else (it currently isn't — it always reads
   `NimvaSchemaV1`/whatever the latest enum is via the migration plan's `schemas` array,
   so double check you added the new enum to that array too).
5. Build + run on a device/simulator that already has an *older* build installed (don't
   delete the app first) and confirm existing events/insights are still there after the
   new build launches. This is the actual regression test for "did the migration work" —
   a clean install always looks fine even if migration is broken, since there's nothing to
   migrate from.
6. Note the change in `STRAY_SPARK_LOG.md` if the migration needed anything non-lightweight
   (custom migrations are exactly the kind of "huh, that's interesting" gotcha worth logging
   for future-you).

## What NOT to do

- Don't edit `NimvaSchemaV1` in place once it's shipped to any real user (TestFlight
  counts). Add a new version instead — editing a shipped version's shape out from under
  existing installs is exactly what migrations exist to avoid.
- Don't remove the corruption-only fallback in `NimvaApp.swift` "to simplify" — it's the
  genuine last resort for an unreadable store, not a stand-in for doing the migration step.
