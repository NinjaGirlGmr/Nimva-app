import SwiftData

/// The current on-disk schema shape. See docs/schema-migrations.md before adding a second
/// version — a naive "copy the enum, bump the number" (both versions pointing at the same
/// live `Event`/`WeekCache`/`Intention` classes) crashes on launch with "Duplicate version
/// checksums detected," because SwiftData computes each VersionedSchema's checksum from the
/// model's actual declared properties: two versions referencing the identical current class
/// hash identically, and a SchemaMigrationPlan can't tell them apart. A real second version
/// needs its own frozen snapshot of the old shape, not a second reference to the live model.
/// (Caught 2026-08-04 — see STRAY_SPARK_LOG.md. Collapsed back to one version since no real
/// install exists yet to migrate from; `wasLogged` just ships as part of this version's shape.)
enum NimvaSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Event.self, WeekCache.self, Intention.self]
    }
}

enum NimvaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [NimvaSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
