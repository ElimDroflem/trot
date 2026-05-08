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

    // MARK: - Journey state (DEPRECATED — pending SwiftData migration)
    //
    // These three fields belonged to the v1 Journey/Route progression that
    // shipped before May 2026 and was replaced by the story-mode
    // milestone system. The fields linger because removing persisted
    // SwiftData properties is a schema migration (and a risk for
    // CloudKit-synced installs already in the wild). Listed in
    // `docs/refactor.md` for proper migration in a follow-up. Nothing
    // in the running app reads these any more.

    var activeRouteID: String = "trot-first-walk"
    var routeProgressMinutes: Int = 0
    var completedRouteIDs: [String] = []

    @Relationship(deleteRule: .cascade, inverse: \WalkWindow.dog)
    var walkWindows: [WalkWindow]? = []

    var walks: [Walk]? = []

    /// One-shot reference to this dog's narrative book. `nil` until the
    /// user picks a genre on the Story tab — that pick creates the Story
    /// + the first chapter + the prologue page in one transaction.
    /// Cascade-delete so archiving a dog cleans up their book; one dog,
    /// one story, lifetime.
    @Relationship(deleteRule: .cascade)
    var story: Story?

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
