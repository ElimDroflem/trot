import SwiftUI

struct HomeView: View {
    var body: some View {
        TabView {
            todayTab
                .tabItem { Label("Today", systemImage: "house.fill") }

            placeholderTab(title: "Activity")
                .tabItem { Label("Activity", systemImage: "calendar") }

            placeholderTab(title: "Insights")
                .tabItem { Label("Insights", systemImage: "lightbulb") }

            placeholderTab(title: "Luna")
                .tabItem { Label("Luna", systemImage: "person.crop.circle") }
        }
        .tint(.brandPrimary)
    }

    private var todayTab: some View {
        ZStack {
            Color.brandSurface.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Space.lg) {
                    HomeHeader()
                    StreakAndDateRow(streakDays: 14, dateLabel: "Tue · 7 May")
                    HeroPhotoPlaceholder()
                    TodayProgressCard(
                        dogName: "Luna",
                        partOfDay: "morning",
                        minutesDone: 42,
                        targetMinutes: 60,
                        rationale: "Beagles do best with a second walk before sundown.",
                        percent: 0.70,
                        minutesToGo: 18
                    )
                    WalksSection()
                    Color.clear.frame(height: Space.lg)
                }
                .padding(.horizontal, Space.md)
                .padding(.top, Space.sm)
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
}

private struct HomeHeader: View {
    var body: some View {
        HStack {
            Button(action: {}) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.brandSurfaceElevated)
                    .clipShape(Circle())
            }
            Spacer()
            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.brandSurfaceElevated)
                    .clipShape(Circle())
            }
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

private struct HeroPhotoPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Radius.lg)
            .fill(Color.brandSecondaryTint)
            .frame(height: 280)
            .overlay {
                VStack(spacing: Space.sm) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.brandSecondary.opacity(0.5))
                    Text("Luna")
                        .font(.titleMedium)
                        .foregroundStyle(Color.brandSecondary.opacity(0.7))
                }
            }
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

            Text("\(minutesDone) of \(targetMinutes) minutes done. \(rationale)")
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
    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("THIS MORNING")
                .font(.captionBold)
                .tracking(0.5)
                .foregroundStyle(Color.brandTextSecondary)

            WalkRow(
                title: "42-minute walk",
                subtitle: "7:42 am · Passive",
                statusText: "Confirmed",
                statusColor: .brandSuccess
            )
        }
    }
}

private struct WalkRow: View {
    let title: String
    let subtitle: String
    let statusText: String
    let statusColor: Color

    var body: some View {
        HStack(spacing: Space.md) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 40, height: 40)
                .background(Color.brandPrimaryTint)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
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
}

#Preview {
    HomeView()
}
