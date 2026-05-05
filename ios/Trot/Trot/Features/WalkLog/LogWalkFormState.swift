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
}
