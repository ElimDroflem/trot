import Foundation

struct LogWalkFormState {
    var startedAt: Date = .now
    var durationMinutes: Int = 30
    var notes: String = ""

    var isValid: Bool {
        durationMinutes > 0 && startedAt <= .now
    }

    func makeWalk(for dogs: [Dog]) -> Walk {
        Walk(
            startedAt: startedAt,
            durationMinutes: durationMinutes,
            distanceMeters: nil,
            source: .manual,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            dogs: dogs
        )
    }

    /// Mutates `walk` to reflect the form state. Used when editing an existing walk.
    /// Doesn't change `walk.dogs` or `walk.source` — those aren't editable in this form.
    func apply(to walk: Walk) {
        walk.startedAt = startedAt
        walk.durationMinutes = durationMinutes
        walk.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Pre-populates form state from an existing Walk for editing.
    static func from(_ walk: Walk) -> LogWalkFormState {
        var state = LogWalkFormState()
        state.startedAt = walk.startedAt
        state.durationMinutes = walk.durationMinutes
        state.notes = walk.notes
        return state
    }
}
