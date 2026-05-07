import Foundation
import SwiftData

/// A single diary entry, generated when the user unlocks a Moment in their
/// current season. Carries the dog-voice line written about the user
/// (never about the app) — the emotional artifact of that unlock.
///
/// Persisted so the user can re-read past Moments in the Journey tab. The
/// list grows with the relationship; nothing is ever deleted.
@Model
final class MomentDiaryEntry {
    /// The Moment / Landmark that unlocked this entry. Stable across app
    /// updates (matches Routes.json id field).
    var momentID: String = ""

    /// The season the Moment belonged to when it unlocked. Captured at write
    /// time so that even if Routes.json content changes later, the entry
    /// still knows which season it came from.
    var seasonID: String = ""

    /// The user-facing Moment title at the time of unlock.
    var momentTitle: String = ""

    /// Local-time wall clock at unlock. Used for the diary list's date label.
    var unlockedAt: Date = Date()

    /// LLM-generated dog-voice line about the user. Templated fallback when
    /// the proxy is offline. Always non-empty.
    var dogVoiceLine: String = ""

    /// SF Symbol for the Moment, captured at unlock so the diary entry's
    /// icon doesn't shift if Routes.json updates.
    var symbolName: String = "checkmark.seal.fill"

    @Relationship(inverse: \Dog.momentDiary)
    var dog: Dog?

    init(
        momentID: String,
        seasonID: String,
        momentTitle: String,
        symbolName: String,
        dogVoiceLine: String,
        unlockedAt: Date = Date()
    ) {
        self.momentID = momentID
        self.seasonID = seasonID
        self.momentTitle = momentTitle
        self.symbolName = symbolName
        self.dogVoiceLine = dogVoiceLine
        self.unlockedAt = unlockedAt
    }
}
