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
