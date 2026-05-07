import SwiftUI
import SwiftData

struct InsightsView: View {
    @Query(
        filter: #Predicate<Dog> { $0.archivedAt == nil },
        sort: \Dog.createdAt,
        order: .reverse
    )
    private var activeDogs: [Dog]

    @Environment(AppState.self) private var appState
    @State private var showingRecap = false
    @State private var lunaSaysLine: String?

    private var activeDog: Dog? { appState.selectedDog(from: activeDogs) }

    var body: some View {
        ZStack {
            Color.brandSurface.ignoresSafeArea()
            WeatherMoodLayer()

            if let dog = activeDog {
                let state = InsightsService.state(for: dog)
                ScrollView {
                    VStack(spacing: Space.lg) {
                        header(for: dog)
                        if let line = lunaSaysLine {
                            LunaSaysCard(line: line, dogName: dog.name)
                                .transition(.opacity)
                        }
                        weeklyRecapButton(for: dog)
                        if let learning = state.learning {
                            LearningCard(progress: learning, dogName: dog.name)
                        }
                        if state.observations.isEmpty {
                            EmptyObservationsCard(hasLearning: state.learning != nil, dogName: dog.name)
                        } else {
                            // The "Lifetime walks" entry gets a magazine-style stat
                            // block instead of a generic observation card. The rest
                            // render through ObservationCard as before.
                            if hasLifetimeObservation(state.observations) {
                                LifetimeStatsCard(
                                    walkCount: lifetimeWalkCount(for: dog),
                                    minutesTotal: lifetimeMinutes(for: dog)
                                )
                            }
                            ForEach(state.observations.filter { $0.title != "Lifetime walks" }) { observation in
                                ObservationCard(insight: observation)
                            }
                        }
                        Color.clear.frame(height: Space.lg)
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.top, Space.md)
                }
                .task(id: dog.persistentModelID) {
                    await refreshLunaSays(for: dog, observations: state.observations)
                }
            } else {
                VStack(spacing: Space.md) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.brandTextTertiary)
                    Text("No dogs yet.")
                        .font(.titleMedium)
                        .foregroundStyle(Color.brandTextSecondary)
                }
            }
        }
    }

    private func hasLifetimeObservation(_ observations: [Insight]) -> Bool {
        observations.contains(where: { $0.title == "Lifetime walks" })
    }

    /// Picks the most personality-revealing observation and asks the LLM to
    /// render it in dog-voice. Skips when there's nothing distinctive to say
    /// (lifetime stats only) — better silent than canned.
    @MainActor
    private func refreshLunaSays(for dog: Dog, observations: [Insight]) async {
        guard let promoted = promotedObservation(from: observations) else {
            withAnimation(.brandDefault) { lunaSaysLine = nil }
            return
        }
        let line = await LLMService.insightLine(
            for: dog,
            pattern: promoted.title,
            detail: promoted.body
        )
        withAnimation(.brandDefault) { lunaSaysLine = line }
    }

    /// Order of preference: rhythm/personality observations first, performance
    /// second, lifetime stats last (and lifetime alone is treated as "nothing
    /// to say in dog-voice yet").
    private func promotedObservation(from observations: [Insight]) -> Insight? {
        let priority: [String] = [
            "When you walk",
            "Weekday vs weekend",
            "Favorite hour",
            "Weekly trend",
        ]
        for title in priority {
            if let match = observations.first(where: { $0.title == title }) {
                return match
            }
        }
        return nil
    }

    private func lifetimeWalkCount(for dog: Dog) -> Int {
        (dog.walks ?? []).count
    }

    private func lifetimeMinutes(for dog: Dog) -> Int {
        (dog.walks ?? []).reduce(0) { $0 + $1.durationMinutes }
    }

    private func header(for dog: Dog) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Insights")
                .font(.displayMedium)
                .foregroundStyle(Color.brandSecondary)
            Text("Patterns Trot is noticing about \(dog.name).")
                .font(.bodyMedium)
                .foregroundStyle(Color.brandTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func weeklyRecapButton(for dog: Dog) -> some View {
        Button(action: { showingRecap = true }) {
            HStack(spacing: Space.sm) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brandPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("This week's recap")
                        .font(.bodyLarge.weight(.semibold))
                        .foregroundStyle(Color.brandTextPrimary)
                    Text("Last 7 days at a glance.")
                        .font(.caption)
                        .foregroundStyle(Color.brandTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brandTextTertiary)
            }
            .padding(Space.md)
            .background(Color.brandSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .brandCardShadow()
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingRecap) {
            RecapView(recap: RecapService.weekly(for: dog), dog: dog) {
                showingRecap = false
            }
        }
    }
}

// MARK: - Components

/// Top-of-Insights dog-voice quote, sourced from LLMService.insightLine.
/// Visual is a quote-style card — italic body, "— Luna" attribution — so
/// the speaker (the dog) is unambiguous. Skipped silently when no distinctive
/// observation is available or LLM is offline.
private struct LunaSaysCard: View {
    let line: String
    let dogName: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: 6) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brandPrimary)
                Text("\(dogName.uppercased()) SAYS")
                    .font(.caption.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(Color.brandTextSecondary)
            }
            Text(line)
                .font(.titleSmall)
                .italic()
                .foregroundStyle(Color.brandTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Space.md)
        .background(Color.brandPrimaryTint)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dogName) says: \(line)")
    }
}

private struct LearningCard: View {
    let progress: LearningProgress
    let dogName: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                Image(systemName: "sparkle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brandSecondary)
                Text("Trot is learning \(dogName)'s patterns")
                    .font(.bodyLarge.weight(.semibold))
                    .foregroundStyle(Color.brandTextPrimary)
            }
            ProgressTrack(percent: progress.fraction)
                .frame(height: 8)
            HStack {
                Text("Day \(progress.daysOfData) of \(progress.target)")
                    .font(.bodyMedium)
                    .foregroundStyle(Color.brandTextSecondary)
                Spacer()
                Text(remainingLabel)
                    .font(.bodyMedium)
                    .foregroundStyle(Color.brandTextSecondary)
            }
        }
        .padding(Space.md)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
    }

    private var remainingLabel: String {
        if progress.remainingDays == 0 { return "Ready" }
        return "\(progress.remainingDays.pluralised("day")) to go"
    }
}

/// Magazine-style two-column stat block for the lifetime walks summary.
/// Promoted from a generic observation card because the numbers themselves
/// are the moment — the user feels them accumulate.
private struct LifetimeStatsCard: View {
    let walkCount: Int
    let minutesTotal: Int

    var body: some View {
        HStack(spacing: 0) {
            statColumn(value: "\(walkCount)", label: walkCount == 1 ? "walk" : "walks")
            statColumn(value: "\(minutesTotal)", label: "minutes")
        }
        .padding(.vertical, Space.lg)
        .padding(.horizontal, Space.md)
        .frame(maxWidth: .infinity)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Lifetime: \(walkCount.pluralised("walk")), \(minutesTotal) minutes total")
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: Space.xs) {
            Text(value)
                .font(.displayMedium)
                .foregroundStyle(Color.brandSecondary)
            Text(label.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(Color.brandTextTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ObservationCard: View {
    let insight: Insight

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(insight.title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brandTextTertiary)
            Text(insight.body)
                .font(.bodyLarge)
                .foregroundStyle(Color.brandTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Space.md)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
    }
}

private struct EmptyObservationsCard: View {
    let hasLearning: Bool
    let dogName: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Image(systemName: "lightbulb")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(Color.brandTextTertiary)
            Text(headline)
                .font(.bodyLarge.weight(.semibold))
                .foregroundStyle(Color.brandTextPrimary)
            Text(detail)
                .font(.bodyMedium)
                .foregroundStyle(Color.brandTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.md)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
    }

    private var headline: String {
        hasLearning ? "Your first walk unlocks the first observation." : "Nothing to read yet."
    }

    private var detail: String {
        hasLearning
            ? "Log a walk and Trot will start picking up on \(dogName)'s rhythm."
            : "Log walks consistently and \(dogName)'s patterns will surface here."
    }
}

private struct ProgressTrack: View {
    let percent: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.brandDivider)
                Capsule()
                    .fill(Color.brandSecondary)
                    .frame(width: geo.size.width * CGFloat(percent))
            }
        }
    }
}

#Preview {
    InsightsView()
        .modelContainer(for: [Dog.self, Walk.self, WalkWindow.self], inMemory: true)
        .environment(AppState())
}
