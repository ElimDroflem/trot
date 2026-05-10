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

    /// The dog's CURRENT (in-progress) book. `nil` when no story is
    /// active — either because the user hasn't picked a genre yet, or
    /// because their last book finished and they haven't started the
    /// next one. When a book finishes (5 chapters closed), the Story is
    /// moved from this relationship into `completedStories`.
    @Relationship(deleteRule: .cascade)
    var story: Story?

    /// Archive of finished books. Cascade-delete so archiving a dog
    /// cleans up the whole library. Sorted by `Story.finishedAt` desc
    /// at the read site (`Dog.completedStoriesSorted`). New books move
    /// here from `story` at the moment of finale.
    @Relationship(deleteRule: .cascade)
    var completedStories: [Story]? = []

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

    /// Finished books, newest first. The model stores them as an
    /// unordered relationship; this is the read order for the bookshelf.
    var completedStoriesSorted: [Story] {
        (completedStories ?? []).sorted {
            ($0.finishedAt ?? .distantPast) > ($1.finishedAt ?? .distantPast)
        }
    }
}
