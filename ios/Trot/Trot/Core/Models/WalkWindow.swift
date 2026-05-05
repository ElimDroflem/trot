import Foundation
import SwiftData

@Model
final class WalkWindow {
    var slot: WalkSlot = WalkSlot.earlyMorning
    var enabled: Bool = true
    var createdAt: Date = Date()

    var dog: Dog?

    init(slot: WalkSlot, enabled: Bool = true, dog: Dog? = nil) {
        self.slot = slot
        self.enabled = enabled
        self.dog = dog
    }
}
