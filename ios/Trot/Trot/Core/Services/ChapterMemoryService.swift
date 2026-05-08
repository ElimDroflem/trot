import Foundation
import SwiftData

/// Stores and (lazily) generates a one-sentence "chapter memory" for each
/// completed route, in the dog's voice. Spec: when the user finishes a route
/// (a "season" in user-facing copy), Trot fires one LLM call that summarises
/// the chapter — *"We learned the loop together. The bench at the corner
/// became ours."* — and caches it forever. The chapters journal renders the
/// memory next to the route name and date span.
///
/// Storage: UserDefaults, keyed by `chapter.<dogIDHash>.<routeID>`. JSON-
/// encoded so we can extend the payload later (e.g. add a date stamp on
/// generation) without a migration.
///
/// Failure-mode: on LLM miss (offline, timeout, rate-limit), the journal
/// falls back to a templated line that still reads as a memory. Cache is
/// only written on success, so a future foreground retry will try the LLM
/// again and replace the templated stand-in.
enum ChapterMemoryService {
    private static let storageKeyPrefix = "trot.chapter.memory."

    private struct Stored: Codable {
        let text: String
        let generatedAt: Date
    }

    /// Synchronous read of the cached memory. Returns nil if no LLM line has
    /// landed yet — caller should display the templated fallback in that
    /// case (and may trigger an async generation).
    static func cachedMemory(routeID: String, dog: Dog) -> String? {
        let key = storageKey(routeID: routeID, dog: dog)
        guard let data = UserDefaults.standard.data(forKey: key),
              let stored = try? JSONDecoder().decode(Stored.self, from: data) else {
            return nil
        }
        return stored.text
    }

    /// Templated fallback used while the LLM line is in-flight, or after a
    /// permanent failure. Built deterministically from the route's totals
    /// so it never reads as a placeholder. The user voice in this fallback
    /// is the *user's*, not the dog's — switching speakers makes the
    /// difference between "pending" and "failed" feel honest rather than
    /// hidden.
    static func templatedFallback(routeID: String, route: Route?, dog: Dog) -> String {
        let dogName = dog.name.isEmpty ? "your dog" : dog.name
        let total = route?.totalMinutes ?? 0
        let hours = total / 60
        if hours >= 2 {
            return "\(dogName) and you walked \(hours) hours together to close this chapter. That's the bond settling in."
        }
        if total > 0 {
            return "\(dogName) and you walked \(total) minutes together to close this chapter."
        }
        return "Another chapter walked together with \(dogName)."
    }

    /// Triggers an async LLM call to generate the memory and writes the
    /// result to UserDefaults on success. Idempotent — if a memory already
    /// exists for this (dog, route), this is a no-op. Safe to call from any
    /// JourneyView appear without rate-limit concerns.
    @MainActor
    static func generateIfNeeded(routeID: String, route: Route, dog: Dog) {
        guard cachedMemory(routeID: routeID, dog: dog) == nil else { return }
        let key = storageKey(routeID: routeID, dog: dog)
        let dogName = dog.name
        let routeName = route.name
        let totalMinutes = route.totalMinutes
        let landmarkNames = route.landmarks.map(\.name)

        Task {
            guard let text = await LLMService.chapterMemory(
                for: dog,
                routeName: routeName,
                routeTotalMinutes: totalMinutes,
                landmarkNames: landmarkNames
            ) else { return }
            let stored = Stored(text: text, generatedAt: .now)
            if let data = try? JSONEncoder().encode(stored) {
                await MainActor.run {
                    UserDefaults.standard.set(data, forKey: key)
                }
            }
            _ = dogName  // keep capture explicit; payload above already used.
        }
    }

    private static func storageKey(routeID: String, dog: Dog) -> String {
        "\(storageKeyPrefix)\(dog.persistentModelID.hashValue).\(routeID)"
    }
}
