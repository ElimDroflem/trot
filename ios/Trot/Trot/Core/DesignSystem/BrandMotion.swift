import SwiftUI

extension Animation {
    static let brandDefault: Animation = .spring(response: 0.4, dampingFraction: 0.8)
    static let brandCelebration: Animation = .spring(response: 0.5, dampingFraction: 0.6)
    /// Slow ease that breathes — for things-to-look-forward-to (next landmark,
    /// daily quest, dog photo at rest). Apply with `.repeatForever(autoreverses: true)`.
    static let brandAnticipation: Animation = .easeInOut(duration: 1.8)
}
