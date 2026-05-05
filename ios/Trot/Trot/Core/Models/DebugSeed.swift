#if DEBUG
import Foundation
import SwiftData

enum DebugSeed {
    @MainActor
    static func seedIfEmpty(container: ModelContainer) {
        let context = container.mainContext

        let existing = (try? context.fetchCount(FetchDescriptor<Dog>())) ?? 0
        guard existing == 0 else { return }

        let calendar = Calendar(identifier: .gregorian)
        let dob = calendar.date(byAdding: .year, value: -3, to: .now)
            ?? Date(timeIntervalSince1970: 0)

        let luna = Dog(
            name: "Luna",
            breedPrimary: "Beagle",
            dateOfBirth: dob,
            weightKg: 12,
            sex: .female,
            isNeutered: true,
            activityLevel: .moderate,
            dailyTargetMinutes: 60
        )
        luna.llmRationale = "Beagles do best with a second walk before sundown."

        context.insert(luna)

        let morning = WalkWindow(slot: .earlyMorning, enabled: true, dog: luna)
        let evening = WalkWindow(slot: .evening, enabled: true, dog: luna)
        context.insert(morning)
        context.insert(evening)

        let walkStart = calendar.date(
            bySettingHour: 7, minute: 42, second: 0, of: .now
        ) ?? .now
        let walk = Walk(
            startedAt: walkStart,
            durationMinutes: 42,
            distanceMeters: 2800,
            source: .passive,
            notes: "",
            dogs: [luna]
        )
        context.insert(walk)

        do {
            try context.save()
        } catch {
            print("DebugSeed save failed: \(error)")
        }
    }
}
#endif
