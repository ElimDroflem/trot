import Testing
import Foundation
@testable import Trot

@Suite("Story model")
struct StoryModelTests {
    /// Tripwire — the scene-setter feature relies on `sceneRaw` being a
    /// persisted field on `Story`. If anyone removes it the SwiftData
    /// schema migration would break and the LLM prologue would silently
    /// stop receiving scene context. Mirror reflection makes that
    /// regression visible at test time, not on next launch.
    @Test("Story has sceneRaw and genreRaw fields")
    func storyHasExpectedRawFields() {
        let story = Story(genre: .cosyMystery)
        // SwiftData prefixes stored properties with `_` in Mirror output.
        let names = Set(Mirror(reflecting: story).children.compactMap(\.label))
        #expect(names.contains("_sceneRaw"))
        #expect(names.contains("_genreRaw"))
    }

    /// `scene` returns nil for legacy stories that pre-date the
    /// scene-setter feature (sceneRaw == "").
    @Test("scene returns nil for empty sceneRaw (legacy story)")
    func sceneNilForLegacyStory() {
        let story = Story(genre: .cosyMystery)
        story.sceneRaw = ""
        #expect(story.scene == nil)
    }

    /// `scene` rehydrates a typed `StoryGenre.Scene` when sceneRaw
    /// matches one of the genre's scenes.
    @Test("scene rehydrates from a valid sceneRaw")
    func sceneRehydratesFromValidRaw() {
        let story = Story(genre: .cosyMystery)
        story.sceneRaw = "village"
        #expect(story.scene?.id == "village")
        #expect(story.scene?.displayName == "Village")
    }

    /// `scene` returns nil if the persisted raw doesn't match any scene
    /// under the current genre — a defensive case for cross-version
    /// drift (e.g. a v1.x scene-table change that drops an id).
    @Test("scene returns nil for unknown sceneRaw")
    func sceneNilForUnknownRaw() {
        let story = Story(genre: .cosyMystery)
        story.sceneRaw = "not_a_real_scene"
        #expect(story.scene == nil)
    }
}
