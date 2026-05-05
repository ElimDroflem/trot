import Foundation

enum Sex: String, Codable, CaseIterable, Sendable {
    case male
    case female
}

enum ActivityLevel: String, Codable, CaseIterable, Sendable {
    case low
    case moderate
    case high
}

enum WalkSource: String, Codable, CaseIterable, Sendable {
    case passive
    case manual
}

enum WalkSlot: String, Codable, CaseIterable, Sendable {
    case earlyMorning
    case lunch
    case afternoon
    case evening
}
