import Foundation
import SwiftData

enum TrotSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [
            Dog.self, Walk.self, WalkWindow.self,
            Story.self, StoryChapter.self, StoryPage.self,
        ]
    }
}
