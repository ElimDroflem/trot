import SwiftUI
import SwiftData
import Charts

struct ActivityView: View {
    @Query(
        filter: #Predicate<Dog> { $0.archivedAt == nil },
        sort: \Dog.createdAt,
        order: .reverse
    )
    private var activeDogs: [Dog]

    @Environment(AppState.self) private var appState
    @State private var currentMonth: Date = .now
    @State private var selectedDay: SelectedDay?

    private var activeDog: Dog? { appState.selectedDog(from: activeDogs) }

    var body: some View {
        ZStack {
            Color.brandSurface.ignoresSafeArea()
            WeatherMoodLayer()

            if let dog = activeDog {
                ScrollView {
                    VStack(spacing: Space.lg) {
                        monthHeader
                        weekdayHeader
                        calendarGrid(for: dog)
                        monthChartCard(for: dog)
                        summaryCard(for: dog)
                        Color.clear.frame(height: Space.lg)
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.top, Space.md)
                }
            } else {
                VStack(spacing: Space.md) {
                    Image(systemName: "calendar")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.brandTextTertiary)
                    Text("No dogs yet.")
                        .font(.titleMedium)
                        .foregroundStyle(Color.brandTextSecondary)
                }
            }
        }
        .sheet(item: $selectedDay) { selection in
            if let dog = activeDog {
                DayWalksSheet(date: selection.date, dog: dog)
            }
        }
    }

    // MARK: - Sections

    private var monthHeader: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.brandSurfaceElevated)
                    .clipShape(Circle())
                    .brandCardShadow()
            }
            .accessibilityLabel("Previous month")

            Spacer()

            Text(monthLabel(currentMonth))
                .font(.titleMedium)
                .foregroundStyle(Color.brandTextPrimary)

            Spacer()

            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.brandSurfaceElevated)
                    .clipShape(Circle())
                    .brandCardShadow()
            }
            .accessibilityLabel("Next month")
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brandTextTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func calendarGrid(for dog: Dog) -> some View {
        let cells = calendarCells
        let minutesByDay = minutesByDay(for: dog)
        let halfTarget = Double(dog.dailyTargetMinutes) / 2.0
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)
        let dogStart = calendar.startOfDay(for: dog.createdAt)

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
            ForEach(0..<cells.count, id: \.self) { index in
                if let day = cells[index] {
                    let dayStart = calendar.startOfDay(for: day)
                    let status = dayStatus(
                        dayStart: dayStart,
                        todayStart: todayStart,
                        dogStart: dogStart,
                        minutes: minutesByDay[dayStart] ?? 0,
                        halfTarget: halfTarget
                    )
                    let isToday = calendar.isDate(day, inSameDayAs: .now)
                    CalendarDayCell(
                        day: day,
                        status: status,
                        isToday: isToday,
                        onTap: { selectedDay = SelectedDay(date: day) }
                    )
                } else {
                    Color.clear.frame(height: 40)
                }
            }
        }
    }

    /// Bar chart of daily minutes across the visible month — gives the
    /// calendar grid above a quantitative companion. Days with no walks read
    /// as flat track. Today's bar (when in this month) is rendered in a
    /// brighter coral; past bars are coral. Future bars are skipped entirely.
    private func monthChartCard(for dog: Dog) -> some View {
        let series = dailyMinutesSeries(for: dog)
        let bestDay = series.max(by: { $0.minutes < $1.minutes })

        return VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Daily minutes")
                    .font(.titleSmall)
                    .foregroundStyle(Color.brandTextPrimary)
                Spacer()
                if let best = bestDay, best.minutes > 0 {
                    Text("Peak \(best.minutes) min")
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
                AxisMarks(values: .stride(by: .day, count: 7)) { value in
                    AxisValueLabel(format: .dateTime.day(), centered: true)
                        .font(.caption2)
                        .foregroundStyle(Color.brandTextTertiary)
                }
            }
            .frame(height: 110)

            insightLine(for: dog)
        }
        .padding(Space.md)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
    }

    /// One auto-generated takeaway. Always factual. Never naggy.
    @ViewBuilder
    private func insightLine(for dog: Dog) -> some View {
        let copy = monthInsightCopy(for: dog)
        if let copy {
            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.brandSecondary)
                Text(copy)
                    .font(.caption)
                    .foregroundStyle(Color.brandTextSecondary)
            }
        }
    }

    private func monthInsightCopy(for dog: Dog) -> String? {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else {
            return nil
        }
        let isCurrentMonth = monthInterval.contains(.now)

        let thisMonth = monthlyStats(for: dog)
        guard thisMonth.minutes > 0 else { return nil }

        // "vs last month" — only valid once the previous month exists in the
        // dog's lifetime. Compute side-by-side for a calm comparison.
        guard let prevMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth),
              let prevInterval = calendar.dateInterval(of: .month, for: prevMonth)
        else { return nil }

        let prevWalks = (dog.walks ?? []).filter { prevInterval.contains($0.startedAt) }
        let prevMinutes = prevWalks.reduce(0) { $0 + $1.durationMinutes }

        if prevMinutes == 0 {
            // First active month — celebrate the start, don't make a comparison.
            return isCurrentMonth ? "First month on Trot. Keep it rolling." : nil
        }

        let delta = thisMonth.minutes - prevMinutes
        if delta == 0 { return "Level with last month." }
        if delta > 0 { return "+\(delta) min versus last month." }
        return "\(delta) min versus last month."
    }

    /// One row per day in the visible month, today and earlier only.
    private func dailyMinutesSeries(for dog: Dog) -> [DailyMinute] {
        let calendar = Calendar.current
        guard
            let interval = calendar.dateInterval(of: .month, for: currentMonth),
            let monthRange = calendar.range(of: .day, in: .month, for: currentMonth)
        else { return [] }

        let todayStart = calendar.startOfDay(for: .now)
        let minutes = minutesByDay(for: dog)

        var rows: [DailyMinute] = []
        for offset in 0..<monthRange.count {
            guard let day = calendar.date(byAdding: .day, value: offset, to: interval.start) else { continue }
            let dayStart = calendar.startOfDay(for: day)
            // Skip future days — we don't want empty bars stretching to the
            // end of the month.
            if dayStart > todayStart { break }
            rows.append(
                DailyMinute(
                    day: dayStart,
                    minutes: minutes[dayStart] ?? 0,
                    isToday: calendar.isDate(day, inSameDayAs: .now)
                )
            )
        }
        return rows
    }

    private func summaryCard(for dog: Dog) -> some View {
        let stats = monthlyStats(for: dog)
        return HStack(spacing: 0) {
            statColumn(value: "\(stats.walks)", label: stats.walks == 1 ? "walk" : "walks")
            statColumn(value: "\(stats.minutes)", label: "minutes")
            statColumn(value: "\(stats.hitDays)", label: stats.hitDays == 1 ? "hit day" : "hit days")
        }
        .padding(.vertical, Space.lg)
        .padding(.horizontal, Space.md)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
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

    // MARK: - Navigation

    private func previousMonth() {
        if let newMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    private func nextMonth() {
        if let newMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    // MARK: - Calendar math

    private var calendarCells: [Date?] {
        let calendar = Calendar.current
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
            let monthRange = calendar.range(of: .day, in: .month, for: currentMonth)
        else { return [] }

        let firstDay = monthInterval.start
        let firstDayWeekday = calendar.component(.weekday, from: firstDay)  // 1=Sun, 2=Mon, ...
        let firstWeekday = calendar.firstWeekday
        let leadingEmpty = (firstDayWeekday - firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leadingEmpty)
        for offset in 0..<monthRange.count {
            if let day = calendar.date(byAdding: .day, value: offset, to: firstDay) {
                cells.append(day)
            }
        }
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        return cells
    }

    private var weekdaySymbols: [String] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = calendar.locale ?? Locale(identifier: "en_GB")
        let symbols = formatter.veryShortStandaloneWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        let offset = calendar.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }

    private func monthLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    // MARK: - Day classification

    private func dayStatus(
        dayStart: Date,
        todayStart: Date,
        dogStart: Date,
        minutes: Int,
        halfTarget: Double
    ) -> DayStatus {
        if dayStart > todayStart { return .future }
        if dayStart < dogStart { return .outsideDogLifetime }
        if minutes <= 0 { return .miss }
        if Double(minutes) >= halfTarget { return .hit }
        return .partial
    }

    private func minutesByDay(for dog: Dog) -> [Date: Int] {
        let calendar = Calendar.current
        var map: [Date: Int] = [:]
        for walk in (dog.walks ?? []) {
            let day = calendar.startOfDay(for: walk.startedAt)
            map[day, default: 0] += walk.durationMinutes
        }
        return map
    }

    private func monthlyStats(for dog: Dog) -> (walks: Int, minutes: Int, hitDays: Int) {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: currentMonth) else {
            return (0, 0, 0)
        }

        let monthWalks = (dog.walks ?? []).filter { interval.contains($0.startedAt) }
        let totalMinutes = monthWalks.reduce(0) { $0 + $1.durationMinutes }

        let halfTarget = Double(dog.dailyTargetMinutes) / 2.0
        var byDay: [Date: Int] = [:]
        for walk in monthWalks {
            let day = calendar.startOfDay(for: walk.startedAt)
            byDay[day, default: 0] += walk.durationMinutes
        }
        let hitDays = byDay.values.filter { Double($0) >= halfTarget && $0 > 0 }.count

        return (monthWalks.count, totalMinutes, hitDays)
    }
}

// MARK: - Chart row

/// One row in the daily-minutes chart. `isToday` brightens the bar so the
/// user can spot today's contribution at a glance.
private struct DailyMinute: Identifiable {
    let day: Date
    let minutes: Int
    let isToday: Bool
    var id: Date { day }
}

// MARK: - Day status

enum DayStatus {
    case hit
    case partial
    case miss
    case future
    case outsideDogLifetime
}

// MARK: - Selected day wrapper (Date isn't Identifiable)

struct SelectedDay: Identifiable {
    let date: Date
    var id: Date { date }
}

// MARK: - Day cell

private struct CalendarDayCell: View {
    let day: Date
    let status: DayStatus
    let isToday: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                background

                if isToday {
                    Circle()
                        .stroke(Color.brandPrimary, lineWidth: 2)
                        .padding(2)
                }

                Text(dayNumber)
                    .font(.bodyMedium.weight(.semibold))
                    .foregroundStyle(textColor)
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var background: some View {
        switch status {
        case .hit:
            Circle().fill(Color.brandSecondary).padding(4)
        case .partial:
            Circle().stroke(Color.brandWarning, lineWidth: 2).padding(4)
        case .miss, .future, .outsideDogLifetime:
            Color.clear
        }
    }

    private var textColor: Color {
        switch status {
        case .hit: return .brandTextOnSecondary
        case .partial, .miss: return .brandTextPrimary
        case .future, .outsideDogLifetime: return .brandTextTertiary
        }
    }

    private var dayNumber: String {
        String(Calendar.current.component(.day, from: day))
    }

    private var accessibilityLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "EEEE d MMMM"
        let dateText = formatter.string(from: day)
        let statusText: String
        switch status {
        case .hit: statusText = "target hit"
        case .partial: statusText = "partial"
        case .miss: statusText = "no walks"
        case .future: statusText = "future"
        case .outsideDogLifetime: statusText = "before dog added"
        }
        return "\(dateText), \(statusText)\(isToday ? ", today" : "")"
    }
}

#Preview {
    ActivityView()
        .modelContainer(for: [Dog.self, Walk.self, WalkWindow.self], inMemory: true)
}
