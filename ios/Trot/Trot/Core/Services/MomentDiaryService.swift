import Foundation
import SwiftData

/// Records `MomentDiaryEntry` rows when a walk crosses Moments in the user's
/// current season, and (asynchronously) upgrades the entry's dog-voice line
/// via the LLM. Called from both LogWalkSheet save and ExpeditionView finish
/// so they stay in sync.
///
/// Behavior:
///   1. Save flow detects Moments crossed via `JourneyService.applyWalk`.
///   2. If any crossings, immediately persist a single MomentDiaryEntry on
///      the dog with a TEMPLATED dogVoiceLine — the recent-Moments list and
///      the WalkCompleteOverlay can read it right away.
///   3. Fire-and-forget Task: ask LLM for a richer dog-voice diary line,
///      update the entry's `dogVoiceLine` field, save again. If the LLM
///      times out / fails / returns empty, the templated line remains.
///
/// One entry per walk (not per Moment crossed) — when a single walk crosses
/// 3+ Moments (common in week 1 with the dense Season 1 thresholds), the
/// entry is keyed to the LAST/furthest Moment and its line acknowledges
/// the multi-cross. Keeps the diary list focused (one card per walk) and
/// LLM cost predictable.
@MainActor
enum MomentDiaryService {
    /// Process the crossings from a freshly-applied walk. If any Moments
    /// crossed, persist a templated entry now and kick off LLM enrichment.
    /// No-op if `crossings` is empty.
    static func recordUnlocks(
        for dog: Dog,
        crossings: [Landmark],
        seasonID: String,
        modelContext: ModelContext
    ) {
        guard let headline = crossings.last else { return }

        let lifetimeMinutes = (dog.walks ?? []).reduce(0) { $0 + $1.durationMinutes }
        let firstWalkDate = (dog.walks ?? []).map(\.startedAt).min() ?? .now
        let daysSinceFirstWalk = max(0, Calendar.current.dateComponents([.day], from: firstWalkDate, to: .now).day ?? 0)

        let templated = templatedLine(
            headline: headline,
            allCrossings: crossings,
            lifetimeMinutes: lifetimeMinutes
        )

        let entry = MomentDiaryEntry(
            momentID: headline.id,
            seasonID: seasonID,
            momentTitle: headline.name,
            symbolName: headline.symbolName,
            dogVoiceLine: templated
        )
        entry.dog = dog
        modelContext.insert(entry)
        try? modelContext.save()

        // Enrich the entry asynchronously. Captured by reference — `entry` and
        // `dog` are @Model classes, so as long as the modelContext lives, the
        // references remain valid across the await.
        let crossedTitles = crossings.map(\.name)
        let momentDescription = headline.description
        let momentTitle = headline.name

        Task { @MainActor in
            let line = await LLMService.momentUnlockLine(
                for: dog,
                headlineMomentTitle: momentTitle,
                momentDescription: momentDescription,
                allCrossedTitles: crossedTitles,
                lifetimeMinutesWithDog: lifetimeMinutes,
                daysSinceFirstWalk: daysSinceFirstWalk
            )
            guard let line, !line.isEmpty else { return }
            entry.dogVoiceLine = line
            try? modelContext.save()
        }
    }

    /// Templated fallback line — used immediately on save and stays in place
    /// if the LLM call fails. Calm, observation-style, not a celebration.
    private static func templatedLine(
        headline: Landmark,
        allCrossings: [Landmark],
        lifetimeMinutes: Int
    ) -> String {
        let lifetimeHours = lifetimeMinutes / 60
        let timeLabel: String = {
            if lifetimeMinutes < 60 {
                return "\(lifetimeMinutes) minutes"
            }
            return lifetimeHours == 1 ? "an hour" : "\(lifetimeHours) hours"
        }()

        if allCrossings.count == 1 {
            return "\(timeLabel) of walks together. \(headline.description)"
        }
        return "\(timeLabel) of walks together. \(allCrossings.count) moments crossed in one walk."
    }
}
