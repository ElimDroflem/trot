import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(
        filter: #Predicate<Dog> { $0.archivedAt == nil },
        sort: \Dog.createdAt,
        order: .reverse
    )
    private var activeDogs: [Dog]

    var body: some View {
        TabView {
            todayTab
                .tabItem { Label("Today", systemImage: "house.fill") }

            placeholderTab(title: "Activity")
                .tabItem { Label("Activity", systemImage: "calendar") }

            placeholderTab(title: "Insights")
                .tabItem { Label("Insights", systemImage: "lightbulb") }

            placeholderTab(title: activeDogs.first?.name ?? "Dog")
                .tabItem {
                    Label(activeDogs.first?.name ?? "Dog", systemImage: "person.crop.circle")
                }
        }
        .tint(.brandPrimary)
    }

    @ViewBuilder
    private var todayTab: some View {
        ZStack {
            Color.brandSurface.ignoresSafeArea()

            if let dog = activeDogs.first {
                ScrollView {
                    VStack(spacing: Space.lg) {
                        HomeHeader()
                        StreakAndDateRow(
                            streakDays: 14,
                            dateLabel: Self.dateLabel(for: .now)
                        )
                        HeroPhoto(dog: dog)
                        TodayProgressCard(
                            dogName: dog.name,
                            partOfDay: Self.partOfDay(for: .now),
                            minutesDone: minutesDone(for: dog),
                            targetMinutes: dog.dailyTargetMinutes,
                            rationale: dog.llmRationale,
                            percent: percent(for: dog),
                            minutesToGo: minutesToGo(for: dog)
                        )
                        WalksSection(
                            sectionTitle: Self.walksSectionTitle(for: .now),
                            walks: walksToday(for: dog)
                        )
                        Color.clear.frame(height: Space.lg)
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.top, Space.sm)
                }
            } else {
                EmptyDogPlaceholder()
            }
        }
    }

    private func placeholderTab(title: String) -> some View {
        ZStack {
            Color.brandSurface.ignoresSafeArea()
            Text(title)
                .font(.titleLarge)
                .foregroundStyle(Color.brandTextSecondary)
        }
    }

    // MARK: - Today helpers (local time per spec)

    private func walksToday(for dog: Dog) -> [Walk] {
        let calendar = Calendar.current
        return (dog.walks ?? [])
            .filter { calendar.isDateInToday($0.startedAt) }
            .sorted { $0.startedAt > $1.startedAt }
    }

    private func minutesDone(for dog: Dog) -> Int {
        walksToday(for: dog).reduce(0) { $0 + $1.durationMinutes }
    }

    private func percent(for dog: Dog) -> Double {
        let target = dog.dailyTargetMinutes
        guard target > 0 else { return 0 }
        return min(1.0, Double(minutesDone(for: dog)) / Double(target))
    }

    private func minutesToGo(for dog: Dog) -> Int {
        max(0, dog.dailyTargetMinutes - minutesDone(for: dog))
    }

    // MARK: - Date / time-of-day formatting

    private static func partOfDay(for date: Date) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<22: return "evening"
        default: return "night"
        }
    }

    private static func walksSectionTitle(for date: Date) -> String {
        "THIS \(partOfDay(for: date).uppercased())"
    }

    private static func dateLabel(for date: Date) -> String {
        Self.dateLabelFormatter.string(from: date)
    }

    private static let dateLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "EEE · d MMM"
        return formatter
    }()
}

private struct HomeHeader: View {
    var body: some View {
        HStack {
            Button(action: {}) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.brandSurfaceElevated)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Back")

            Spacer()

            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.brandSurfaceElevated)
                    .clipShape(Circle())
            }
            .accessibilityLabel("More options")
        }
    }
}

private struct StreakAndDateRow: View {
    let streakDays: Int
    let dateLabel: String

    var body: some View {
        HStack {
            HStack(spacing: Space.xs) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Color.brandPrimary)
                Text("\(streakDays) days")
                    .font(.bodyMedium.weight(.semibold))
                    .foregroundStyle(Color.brandTextPrimary)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .background(Color.brandSurfaceElevated)
            .clipShape(Capsule())

            Spacer()

            Text(dateLabel)
                .font(.bodyMedium.weight(.semibold))
                .foregroundStyle(Color.brandTextPrimary)
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.sm)
                .background(Color.brandSurfaceElevated)
                .clipShape(Capsule())
        }
    }
}

private struct HeroPhoto: View {
    let dog: Dog

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.lg)
            .fill(Color.brandSecondaryTint)
            .frame(height: 280)
            .overlay {
                if let data = dog.photo, let image = uiImage(from: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                } else {
                    VStack(spacing: Space.sm) {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.brandSecondary.opacity(0.5))
                        Text(dog.name)
                            .font(.titleMedium)
                            .foregroundStyle(Color.brandSecondary.opacity(0.7))
                    }
                }
            }
    }

    private func uiImage(from data: Data) -> UIImage? {
        UIImage(data: data)
    }
}

private struct TodayProgressCard: View {
    let dogName: String
    let partOfDay: String
    let minutesDone: Int
    let targetMinutes: Int
    let rationale: String
    let percent: Double
    let minutesToGo: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("\(dogName)'s \(partOfDay).")
                .font(.displayMedium)
                .foregroundStyle(Color.brandSecondary)

            Text(progressLine)
                .font(.bodyLarge)
                .foregroundStyle(Color.brandTextPrimary)

            ProgressTrack(percent: percent)
                .frame(height: 10)

            HStack {
                Text("\(Int(percent * 100))% of today's needs")
                    .font(.bodyMedium)
                    .foregroundStyle(Color.brandTextSecondary)
                Spacer()
                Text("\(minutesToGo) min to go")
                    .font(.bodyMedium)
                    .foregroundStyle(Color.brandTextSecondary)
            }
        }
    }

    private var progressLine: String {
        let base = "\(minutesDone) of \(targetMinutes) minutes done."
        let trimmed = rationale.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? base : "\(base) \(trimmed)"
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
                    .frame(width: geo.size.width * max(0, min(1, percent)))
            }
        }
    }
}

private struct WalksSection: View {
    let sectionTitle: String
    let walks: [Walk]

    var body: some View {
        if walks.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text(sectionTitle)
                    .font(.captionBold)
                    .tracking(0.5)
                    .foregroundStyle(Color.brandTextSecondary)

                ForEach(walks) { walk in
                    WalkRow(walk: walk)
                }
            }
        }
    }
}

private struct WalkRow: View {
    let walk: Walk

    var body: some View {
        HStack(spacing: Space.md) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 40, height: 40)
                .background(Color.brandPrimaryTint)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("\(walk.durationMinutes)-minute walk")
                    .font(.bodyLarge.weight(.semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                Text(subtitle)
                    .font(.bodyMedium)
                    .foregroundStyle(Color.brandTextSecondary)
            }

            Spacer()

            Text(statusText)
                .font(.bodyMedium.weight(.semibold))
                .foregroundStyle(statusColor)
        }
    }

    private var subtitle: String {
        let timeText = Self.timeFormatter.string(from: walk.startedAt).lowercased()
        let sourceText = walk.source == .passive ? "Passive" : "Manual"
        return "\(timeText) · \(sourceText)"
    }

    private var statusText: String {
        walk.source == .passive ? "Confirmed" : "Logged"
    }

    private var statusColor: Color {
        .brandSuccess
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
}

private struct EmptyDogPlaceholder: View {
    var body: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "pawprint.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color.brandTextTertiary)
            Text("No dogs yet.")
                .font(.titleMedium)
                .foregroundStyle(Color.brandTextSecondary)
            Text("Add a dog to get started.")
                .font(.bodyMedium)
                .foregroundStyle(Color.brandTextTertiary)
        }
        .padding(Space.xl)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Dog.self, Walk.self, WalkWindow.self], inMemory: true)
}
