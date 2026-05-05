import Foundation
import SwiftData

enum TrotMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [TrotSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
