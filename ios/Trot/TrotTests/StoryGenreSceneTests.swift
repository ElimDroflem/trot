import Testing
import Foundation
@testable import Trot

@Suite("StoryGenre.Scene")
struct StoryGenreSceneTests {
    /// Every genre ships exactly four scenes.
    @Test("Every genre has four scenes", arguments: StoryGenre.allCases)
    func everyGenreHasFourScenes(_ genre: StoryGenre) {
        #expect(genre.scenes.count == 4, "\(genre.displayName) must have 4 scenes, got \(genre.scenes.count)")
    }

    /// Scene IDs are unique within a genre. (Across genres they may
    /// repeat — there's a "seaside" in cosy and a "coastal_path" in
    /// adventure with the same `water.waves` symbol; that's fine because
    /// scenes are looked up via the genre's table, never globally.)
    @Test("Scene IDs are unique within a genre", arguments: StoryGenre.allCases)
    func sceneIDsUniqueWithinGenre(_ genre: StoryGenre) {
        let ids = genre.scenes.map(\.id)
        #expect(Set(ids).count == ids.count, "\(genre.displayName) has duplicate scene IDs: \(ids)")
    }

    /// Every field of every scene is non-empty. Scenes with empty prompts
    /// would silently degrade the LLM call (an empty `scenePrompt` causes
    /// the proxy to skip the scene-injection line entirely).
    @Test("All scene fields are non-empty", arguments: StoryGenre.allCases)
    func allSceneFieldsNonEmpty(_ genre: StoryGenre) {
        for scene in genre.scenes {
            #expect(!scene.id.isEmpty)
            #expect(!scene.displayName.isEmpty)
            #expect(!scene.symbol.isEmpty)
            #expect(!scene.prompt.isEmpty, "\(genre.displayName)/\(scene.displayName) has empty prompt")
        }
    }

    /// `scene(forID:)` round-trips for every scene the genre exposes,
    /// and returns nil for unknown ids. This is the lookup the SwiftData
    /// model uses to rehydrate `sceneRaw` into a typed scene.
    @Test("scene(forID:) round-trips and rejects unknown ids", arguments: StoryGenre.allCases)
    func sceneLookupRoundTrips(_ genre: StoryGenre) {
        for scene in genre.scenes {
            #expect(genre.scene(forID: scene.id) == scene)
        }
        #expect(genre.scene(forID: "this_is_not_a_real_scene_id") == nil)
        #expect(genre.scene(forID: "") == nil)
    }

    /// Sanity: every genre has a non-empty scene question.
    @Test("Every genre has a scene question", arguments: StoryGenre.allCases)
    func everyGenreHasASceneQuestion(_ genre: StoryGenre) {
        #expect(!genre.sceneQuestion.isEmpty)
    }
}
