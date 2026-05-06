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

    private var activeDog: Dog? { appState.selectedDog(from: activeDogs) }

    var body: some View {
        ZStack {
            Color.brandSurface.ignoresSafeArea()

            if let dog = activeDog {
                let state = InsightsService.state(for: dog)
                ScrollView {
                    VStack(spacing: Space.lg) {
                        header(for: dog)
                        if let learning = state.learning {
                            LearningCard(progress: learning, dogName: dog.name)
                        }
                        if state.observations.isEmpty {
                            EmptyObservationsCard(hasLearning: state.learning != nil, dogName: dog.name)
                        } else {
                            ForEach(state.observations) { observation in
                                ObservationCard(insight: observation)
                            }
                        }
                        Color.clear.frame(height: Space.lg)
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.top, Space.md)
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
}

// MARK: - Components

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
    }

    private var remainingLabel: String {
        switch progress.remainingDays {
        case 0: return "Ready"
        case 1: return "1 day to go"
        default: return "\(progress.remainingDays) days to go"
        }
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
