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

    // MARK: - Journey state (per-dog progression along bundled routes)

    /// ID of the route the dog is currently traversing. Defaults to the starter
    /// route. Auto-advances through `JourneyService.routeSequence` when the
    /// active route's `routeProgressMinutes` reaches `totalMinutes`.
    var activeRouteID: String = "trot-first-walk"

    /// Cumulative MINUTES of walking on the active route. Resets to 0 (with
    /// overflow carrying over) when a route completes. Driven by
    /// `JourneyService.applyWalk` after every walk save. Time, not distance —
    /// see `JourneyService+Routes.swift` for rationale.
    var routeProgressMinutes: Int = 0

    /// IDs of routes the dog has fully completed, in chronological order. Used
    /// for the long-tail "you walked Hadrian's Wall this year" emotional artifact
    /// and as a sanity check that auto-advance happened.
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
