import Foundation
import SwiftData

@Model
final class Walk {
    var startedAt: Date = Date(timeIntervalSince1970: 0)
    var durationMinutes: Int = 0
    var distanceMeters: Double?
    var source: WalkSource = WalkSource.manual
    var notes: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Dog.walks)
    var dogs: [Dog]? = []

    init(
        startedAt: Date,
        durationMinutes: Int,
        distanceMeters: Double? = nil,
        source: WalkSource,
        notes: String = "",
        dogs: [Dog] = []
    ) {
        self.startedAt = startedAt
        self.durationMinutes = durationMinutes
        self.distanceMeters = distanceMeters
        self.source = source
        self.notes = notes
        self.dogs = dogs
    }
}
