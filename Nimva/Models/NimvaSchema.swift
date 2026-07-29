import SwiftData

/// The current on-disk schema shape. Bump by adding a new `NimvaSchemaVN` enum + a migration
/// stage in `NimvaMigrationPlan` — see docs/schema-migrations.md for the exact steps to follow
/// every time a model gains/loses/changes a field.
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
