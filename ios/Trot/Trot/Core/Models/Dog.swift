import Foundation
import SwiftData

@Model
final class Dog {
    var name: String = ""

    @Attribute(.externalStorage) var photo: Data?

    var breedPrimary: String = ""
    var breedSecondary: String?

    var dateOfBirth: Date = Date(timeIntervalSince1970: 0)
    var weightKg: Double = 0
    var sex: Sex = Sex.female
    var isNeutered: Bool = false

    var healthNotes: String = ""
    var hasArthritis: Bool = false
    var hasHipDysplasia: Bool = false
    var isBrachycephalic: Bool = false

    var activityLevel: ActivityLevel = ActivityLevel.moderate
    var dailyTargetMinutes: Int = 60
    var llmRationale: String = ""

    var archivedAt: Date?
    var createdAt: Date = Date()

    /// Codes for first-week-loop milestones already celebrated for this dog.
    /// Stored as `MilestoneCode` raw values (Strings) so the column stays primitive
    /// for CloudKit. Service layer (`MilestoneService`) maps to/from the typed enum.
    var firedMilestones: [String] = []

    /// The Sunday-startOfDay of the most recent week whose recap this dog has seen.
    /// `RecapService` uses this to decide whether to auto-show the recap on a given
    /// Sunday evening. Per-dog so multi-dog households don't have to share the flag.
    var lastRecapSeenWeekStart: Date?

    @Relationship(deleteRule: .cascade, inverse: \WalkWindow.dog)
    var walkWindows: [WalkWindow]? = []

    var walks: [Walk]? = []

    init(
        name: String,
        breedPrimary: String,
        dateOfBirth: Date,
        weightKg: Double,
        sex: Sex,
        isNeutered: Bool,
        activityLevel: ActivityLevel = .moderate,
        dailyTargetMinutes: Int = 60
    ) {
        self.name = name
        self.breedPrimary = breedPrimary
        self.dateOfBirth = dateOfBirth
        self.weightKg = weightKg
        self.sex = sex
        self.isNeutered = isNeutered
        self.activityLevel = activityLevel
        self.dailyTargetMinutes = dailyTargetMinutes
    }
}
