import SwiftUI
import SwiftData
import Charts

/// Insights tab — rebuilt around a visual hero chart instead of stacked
/// text observations. Reading order:
///
///   1. Header — "Insights" / "What Luna's been up to."
///   2. Weekday rhythm chart — bars showing minutes-per-weekday so the
///      pattern is visible, not just stated.
///   3. Stats grid — 2×2 of StatCard (this week, vs last, longest walk,
///      current streak). Replaces the old "4 walks / 78 minutes" strip.
///   4. Luna says — single LLM dog-voice line about a noticed pattern.
///   5. Weekly recap tile — moved here from Today (one home only).
///   6. Long-tail observations as text cards (only when distinctive).
///   7. Learning state when there's < 7 days of data.
struct InsightsView: View {
    @Query(
        filter: #Predicate<Dog> { $0.archivedAt == nil },
        sort: \Dog.createdAt,
        order: .reverse
    )
    private var activeDogs: [Dog]

    @Environment(AppState.self) private var appState
    @State private var showingRecap = false

    private var activeDog: Dog? { appState.selectedDog(from: activeDogs) }

    var body: some View {
        ZStack {
            Color.brandSurface.ignoresSafeArea()
            WeatherMoodLayer()

            if let dog = activeDog {
                let state = InsightsService.state(for: dog)
                let stats = InsightsStats.compute(for: dog)
                ScrollView {
                    VStack(spacing: Space.lg) {
                        header(for: dog)

                        if (dog.walks ?? []).isEmpty {
                            EmptyObservationsCard(
                                hasLearning: state.learning != nil,
                                dogName: dog.name
                            )
                        } else {
                            WeekdayRhythmCard(
                                minutesByWeekday: stats.minutesByWeekday,
                                averagePerActiveDay: stats.averageMinutesPerActiveDay,
                                dogName: dog.name
                            )
                            DailyMinutesCard(dog: dog)
                            StatGrid(stats: stats)
                        }

                        DogInsightsListCard(insights: DogInsightsService.insights(for: dog))

                        weeklyRecapButton(for: dog)

                        if let learning = state.learning {
                            LearningCard(progress: learning, dogName: dog.name)
                        }

                        // Long-tail observations (filter out anything the
                        // stats / written insights already cover so we never
                        // say the same thing twice on the same screen).
                        let observations = filterLongTail(state.observations)
                        ForEach(observations) { observation in
                            ObservationCard(insight: observation)
                        }

                        // Clearance for the centre walk FAB.
                        Color.clear.frame(height: 100)
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
        .edgeGlass()
    }

    // MARK: - Filtering

    /// Drop everything the new `DogInsightsListCard` and the stat grid
    /// already cover (lifetime stats, weekly trend, generic time-of-day) so
    /// the Insights tab doesn't say the same thing twice.
    private func filterLongTail(_ observations: [Insight]) -> [Insight] {
        observations.filter { obs in
            obs.title != "Lifetime walks"
                && obs.title != "Weekly trend"
                && obs.title != "When you walk"
                && obs.title != "Favorite hour"
        }
    }

    // MARK: - Pieces

    private func header(for dog: Dog) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Insights")
                .font(.displayMedium)
                .foregroundStyle(Color.brandSecondary)
            Text("What \(dog.name)'s been up to.")
                .font(.bodyMedium)
                .foregroundStyle(Color.brandTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func weeklyRecapButton(for dog: Dog) -> some View {
        Button(action: { showingRecap = true }) {
            HStack(spacing: Space.sm) {
                ZStack {
                    Circle()
                        .fill(Color.brandPrimaryTint)
                        .frame(width: 36, height: 36)
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.brandPrimary)
                }
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
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
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

// MARK: - Hero chart (weekday rhythm)

/// Bar chart of total walking minutes per weekday across the dog's history.
/// Coral bars; the average-per-active-day caption sits underneath. When all
/// bars are zero we render a flat track with a "Trot is still learning"
/// caption rather than a confusing empty axis.
private struct WeekdayRhythmCard: View {
    /// 7 integers, Mon (0) → Sun (6), of total minutes walked on that weekday.
    let minutesByWeekday: [Int]
    let averagePerActiveDay: Int
    let dogName: String

    /// Full weekday names — used as Y-axis labels in the horizontal bar
    /// chart. We render the chart sideways so it visually differs from the
    /// daily-minutes vertical chart underneath.
    private let weekdayLabels: [String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var allZero: Bool { minutesByWeekday.allSatisfy { $0 == 0 } }
    private var topWeekday: (label: String, minutes: Int)? {
        let max = minutesByWeekday.max() ?? 0
        guard max > 0, let idx = minutesByWeekday.firstIndex(of: max) else { return nil }
        return (fullDayName(idx), max)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Weekday rhythm")
                    .font(.titleSmall)
                    .foregroundStyle(Color.brandTextPrimary)
                Spacer()
                if !allZero {
                    Text("avg \(averagePerActiveDay) min")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.brandTextTertiary)
                }
            }

            // Horizontal bars — Y-axis is the day, X-axis is minutes. Visually
            // distinct from the vertical daily-minutes chart further down on
            // the same screen, so the eye reads them as different shapes.
            Chart {
                ForEach(Array(minutesByWeekday.enumerated()), id: \.offset) { index, minutes in
                    BarMark(
                        x: .value("Minutes", minutes),
                        y: .value("Day", weekdayLabels[index])
                    )
                    .foregroundStyle(Color.brandPrimary)
                    .cornerRadius(3)
                }
            }
            .chartYAxis {
                AxisMarks(preset: .aligned, position: .leading, values: weekdayLabels) { _ in
                    AxisValueLabel()
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.brandTextTertiary)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine()
                        .foregroundStyle(Color.brandDivider.opacity(0.6))
                    AxisValueLabel()
                        .font(.caption2)
                        .foregroundStyle(Color.brandTextTertiary)
                }
            }
            .frame(height: 160)

            if allZero {
                Text("Trot is still learning \(dogName)'s rhythm. Log a walk.")
                    .font(.caption)
                    .foregroundStyle(Color.brandTextSecondary)
            } else if let top = topWeekday {
                Text("Strongest day so far: \(top.label).")
                    .font(.caption)
                    .foregroundStyle(Color.brandTextSecondary)
            }
        }
        .padding(Space.md)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
    }

    private func fullDayName(_ index: Int) -> String {
        ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][index]
    }
}

// MARK: - Daily minutes (rolling 30 days)

/// Bar chart of the last 30 days' walking minutes. Shows shape over time
/// rather than a static grid. Today's bar reads slightly brighter so the
/// user spots their contribution to the running picture.
///
/// Replaces the dedicated Activity tab — the calendar grid was redundant
/// once daily minutes are visible at a glance, and "tap a day to see its
/// walks" wasn't a path many people used.
private struct DailyMinutesCard: View {
    let dog: Dog

    private struct DailyMinute: Identifiable {
        let day: Date
        let minutes: Int
        let isToday: Bool
        var id: Date { day }
    }

    private let windowDays = 30

    private var series: [DailyMinute] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let minutesByDay: [Date: Int] = (dog.walks ?? []).reduce(into: [:]) { acc, walk in
            let day = calendar.startOfDay(for: walk.startedAt)
            acc[day, default: 0] += walk.durationMinutes
        }

        return (0..<windowDays).reversed().compactMap { offset -> DailyMinute? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return nil
            }
            return DailyMinute(
                day: day,
                minutes: minutesByDay[day] ?? 0,
                isToday: offset == 0
            )
        }
    }

    private var peakMinutes: Int {
        series.map(\.minutes).max() ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Last 30 days")
                    .font(.titleSmall)
                    .foregroundStyle(Color.brandTextPrimary)
                Spacer()
                if peakMinutes > 0 {
                    Text("Peak \(peakMinutes) min")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.brandTextTertiary)
                }
            }

            Chart {
                ForEach(series) { entry in
                    BarMark(
                        x: .value("Day", entry.day, unit: .day),
                        y: .value("Minutes", entry.minutes)
                    )
                    .foregroundStyle(entry.isToday ? Color.brandPrimary : Color.brandPrimary.opacity(0.8))
                    .cornerRadius(2)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(Color.brandDivider.opacity(0.6))
                    AxisValueLabel().font(.caption2).foregroundStyle(Color.brandTextTertiary)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .font(.caption2)
                        .foregroundStyle(Color.brandTextTertiary)
                }
            }
            .frame(height: 110)
        }
        .padding(Space.md)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
    }
}

// MARK: - Stat grid + cards

private struct StatGrid: View {
    let stats: InsightsStats

    private let columns = [
        GridItem(.flexible(), spacing: Space.sm),
        GridItem(.flexible(), spacing: Space.sm),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Space.sm) {
            StatCard(
                icon: "calendar",
                tint: .brandPrimary,
                value: "\(stats.thisWeekMinutes)",
                unit: "min",
                label: "This week"
            )
            // When there's no prior week to compare against, the delta card
            // would show "+78" against zero — misleading. Replace with a
            // calm "First week" placeholder until a real comparison exists.
            if stats.lastWeekMinutes == 0 {
                StatCard(
                    icon: "sparkle",
                    tint: .brandSecondary,
                    value: "—",
                    unit: "",
                    label: "First week"
                )
            } else {
                StatCard(
                    icon: stats.weekDeltaIcon,
                    tint: stats.weekDeltaIsBetter ? .brandSuccess : .brandSecondary,
                    value: stats.weekDeltaValue,
                    unit: stats.weekDeltaUnit,
                    label: "vs last week"
                )
            }
            StatCard(
                icon: "stopwatch.fill",
                tint: .brandSecondary,
                value: "\(stats.longestWalkMinutes)",
                unit: "min",
                label: "Longest walk"
            )
            StatCard(
                icon: stats.currentStreak == 0 ? "flame" : "flame.fill",
                tint: stats.currentStreak == 0 ? .brandTextTertiary : .brandPrimary,
                value: "\(stats.currentStreak)",
                unit: stats.currentStreak == 1 ? "day" : "days",
                label: "Current streak"
            )
        }
    }
}

private struct StatCard: View {
    let icon: String
    let tint: Color
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.displayMedium)
                    .foregroundStyle(Color.brandTextPrimary)
                Text(unit)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brandTextTertiary)
            }
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(Color.brandTextSecondary)
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value) \(unit)")
    }
}

// MARK: - Stats helper

/// Pure-function rollup of the numbers shown in the stat grid + chart hero.
/// Keeps the view code clean and lets us test the math separately.
struct InsightsStats: Equatable {
    let thisWeekMinutes: Int
    let lastWeekMinutes: Int
    let longestWalkMinutes: Int
    let currentStreak: Int
    /// 7 integers, Mon (index 0) → Sun (index 6).
    let minutesByWeekday: [Int]
    let averageMinutesPerActiveDay: Int

    var weekDelta: Int { thisWeekMinutes - lastWeekMinutes }
    var weekDeltaIsBetter: Bool { weekDelta > 0 }

    /// Display value for the "vs last week" card. When there's no prior week
    /// data (a brand-new dog), we say "—" rather than report a misleading
    /// 100% gain over zero.
    var weekDeltaValue: String {
        if lastWeekMinutes == 0 && thisWeekMinutes == 0 { return "—" }
        if lastWeekMinutes == 0 { return "+\(thisWeekMinutes)" }
        return weekDelta >= 0 ? "+\(weekDelta)" : "\(weekDelta)"
    }

    var weekDeltaUnit: String {
        thisWeekMinutes == 0 && lastWeekMinutes == 0 ? "" : "min"
    }

    var weekDeltaIcon: String {
        if lastWeekMinutes == 0 { return "arrow.up.right" }
        return weekDelta >= 0 ? "arrow.up.right" : "arrow.down.right"
    }

    static func compute(
        for dog: Dog,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> InsightsStats {
        let walks = dog.walks ?? []
        let todayDay = calendar.startOfDay(for: today)
        let thisStart = calendar.date(byAdding: .day, value: -6, to: todayDay) ?? todayDay
        let lastStart = calendar.date(byAdding: .day, value: -13, to: todayDay) ?? todayDay
        let lastEnd = calendar.date(byAdding: .day, value: -7, to: todayDay) ?? todayDay

        var thisWeekMinutes = 0
        var lastWeekMinutes = 0
        var longest = 0
        var byWeekday: [Int: Int] = [:]      // weekday raw (1=Sun, 7=Sat)
        var activeDays: Set<Date> = []

        for walk in walks {
            let day = calendar.startOfDay(for: walk.startedAt)
            if day >= thisStart && day <= todayDay {
                thisWeekMinutes += walk.durationMinutes
            }
            if day >= lastStart && day <= lastEnd {
                lastWeekMinutes += walk.durationMinutes
            }
            longest = max(longest, walk.durationMinutes)
            let weekday = calendar.component(.weekday, from: walk.startedAt)
            byWeekday[weekday, default: 0] += walk.durationMinutes
            activeDays.insert(day)
        }

        // Re-key Sun-first (1=Sun … 7=Sat) into Mon-first (Mon … Sun) for UK
        // reading conventions.
        let monFirst: [Int] = (0..<7).map { i in
            // i=0 → Monday (raw 2), i=1 → Tuesday (raw 3), …, i=5 → Saturday
            // (raw 7), i=6 → Sunday (raw 1)
            let raw = i == 6 ? 1 : i + 2
            return byWeekday[raw] ?? 0
        }

        let totalMinutes = walks.reduce(0) { $0 + $1.durationMinutes }
        let avgPerActiveDay = activeDays.isEmpty ? 0 : Int(round(Double(totalMinutes) / Double(activeDays.count)))

        let streak = StreakService.currentStreak(for: dog, today: today, calendar: calendar)

        return InsightsStats(
            thisWeekMinutes: thisWeekMinutes,
            lastWeekMinutes: lastWeekMinutes,
            longestWalkMinutes: longest,
            currentStreak: streak,
            minutesByWeekday: monFirst,
            averageMinutesPerActiveDay: avgPerActiveDay
        )
    }
}

// MARK: - Written insights list

/// Rendered output of `DogInsightsService.insights(for:)`. One card with
/// 1-3 written insights stacked inside, each with an icon + title + body.
/// Replaces the LLM-driven `LunaSaysCard` — Insights now talks to the
/// owner directly, in plain English, anchored in real data and breed/age
/// context. The dog-voice surface lives on Home now.
private struct DogInsightsListCard: View {
    let insights: [DogInsight]

    var body: some View {
        if insights.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("Trot notices")
                    .font(.titleSmall)
                    .foregroundStyle(Color.brandTextPrimary)

                VStack(spacing: 0) {
                    ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                        if index > 0 {
                            Rectangle()
                                .fill(Color.brandDivider.opacity(0.5))
                                .frame(height: 1)
                                .padding(.horizontal, Space.md)
                        }
                        row(for: insight)
                    }
                }
                .background(Color.brandSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                .brandCardShadow()
            }
        }
    }

    private func row(for insight: DogInsight) -> some View {
        HStack(alignment: .top, spacing: Space.sm) {
            ZStack {
                Circle()
                    .fill(tint(for: insight.kind).opacity(0.14))
                    .frame(width: 32, height: 32)
                Image(systemName: icon(for: insight.kind))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint(for: insight.kind))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.bodyLarge.weight(.semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                Text(insight.body)
                    .font(.bodyMedium)
                    .foregroundStyle(Color.brandTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Space.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.title). \(insight.body)")
    }

    /// Per-kind icon. Pulls from SF Symbols and uses a coral/secondary tint
    /// pair so the eye groups insights of the same kind across screens.
    private func icon(for kind: DogInsight.Kind) -> String {
        switch kind {
        case .volume:    return "target"
        case .lifeStage: return "heart.fill"
        case .health:    return "cross.case.fill"
        case .timeOfDay: return "clock.fill"
        case .trend:     return "chart.line.uptrend.xyaxis"
        case .streak:    return "flame.fill"
        }
    }

    private func tint(for kind: DogInsight.Kind) -> Color {
        switch kind {
        case .volume, .streak, .trend: return .brandPrimary
        case .health, .lifeStage:      return .brandSecondary
        case .timeOfDay:               return .brandSecondary
        }
    }
}

// MARK: - Existing components (unchanged)

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
