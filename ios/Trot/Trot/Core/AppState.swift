import Foundation
import SwiftData

/// App-wide state injected via SwiftUI's environment.
/// Tracks the user's currently-selected dog across tabs and a queue of
/// pending first-week-loop celebrations to surface to the user.
/// Falls back to the most-recently-active dog when nothing is explicitly selected.
@Observable
final class AppState {
    var selectedDogID: PersistentIdentifier?

    /// FIFO queue of milestone celebrations waiting to be shown.
    /// Producer (LogWalkSheet save, RootView .task) pushes new beats from
    /// `MilestoneService.newMilestones(for:)`. Consumer (a celebration overlay
    /// on Home) reads `pendingCelebration` and dismisses by calling `consumeCelebration()`.
    var pendingCelebrations: [PendingCelebration] = []

    var pendingCelebration: PendingCelebration? { pendingCelebrations.first }

    /// Set to a dog's PersistentIdentifier when the weekly recap should auto-present.
    /// RootView observes and drives the sheet. Cleared on dismiss.
    var pendingRecapDogID: PersistentIdentifier?

    init(selectedDogID: PersistentIdentifier? = nil) {
        self.selectedDogID = selectedDogID
    }

    /// Returns the dog that should be displayed given the current selection and the
    /// available active dogs. If `selectedDogID` is unset or doesn't match any active
    /// dog (e.g. that dog was archived), falls back to `dogs.first`.
    func selectedDog(from dogs: [Dog]) -> Dog? {
        if let id = selectedDogID,
           let match = dogs.first(where: { $0.persistentModelID == id }) {
            return match
        }
        return dogs.first
    }

    /// Mark a dog as the active selection.
    func select(_ dog: Dog) {
        selectedDogID = dog.persistentModelID
    }

    /// Append celebrations for a given dog. Caller is responsible for having
    /// already called `MilestoneService.markFired(_:on:)` and saved the model
    /// context — this queue is purely for surfacing the moment to the user.
    func enqueueCelebrations(_ codes: [MilestoneCode], for dog: Dog) {
        guard !codes.isEmpty else { return }
        let dogName = dog.name.isEmpty ? "Your dog" : dog.name
        let entries = codes.map { PendingCelebration(code: $0, dogName: dogName) }
        pendingCelebrations.append(contentsOf: entries)
    }

    /// Pops the head of the celebration queue. Called by the overlay on dismiss.
    func consumeCelebration() {
        guard !pendingCelebrations.isEmpty else { return }
        pendingCelebrations.removeFirst()
    }
}

/// A queued celebration waiting to be surfaced. Captures `dogName` at enqueue
/// time so the title/body don't change if the user switches dogs before the
/// overlay is shown.
struct PendingCelebration: Identifiable, Equatable, Sendable {
    let id = UUID()
    let code: MilestoneCode
    let dogName: String

    var title: String { code.title(dogName: dogName) }
    var body: String { code.body(dogName: dogName) }
}
