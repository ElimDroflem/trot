import SwiftUI
import SwiftData

/// Trot's signature retention surface. The Journey tab tells the user where
/// they are in their dog's narrative arc and what's coming next, with the
/// dog photo as the breathing centerpiece.
///
/// Layout, top to bottom:
///   1. Hero — dog photo inside a huge route-progress arc, route name
///      headline, "X% of <Route>" stat below.
///   2. Landmark trail — horizontal row of moment dots with the dog's
///      current position as a pulsing coral marker. Unlocked moments are
///      coral with their icon; locked are grey with a lock.
///   3. Up next — a single big display-type block naming time-to-next +
///      a redacted moment title.
///   4. Recent moments — diary cards with the dog-voice reflections
///      (the emotional payload).
///   5. Coming up — completed-route pills + the next route preview.
struct JourneyView: View {
    @Query(filter: #Predicate<Dog> { $0.archivedAt == nil })
    private var activeDogs: [Dog]
    @Environment(AppState.self) private var appState

    private var selectedDog: Dog? { appState.selectedDog(from: activeDogs) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.brandSurface, Color.brandSurfaceSunken],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            WeatherMoodLayer()

            if let dog = selectedDog {
                if let route = JourneyService.currentRoute(for: dog) {
                    journeyContent(dog: dog, route: route)
                } else {
                    noRouteFallback
                }
            } else {
                EmptyJourneyPlaceholder()
            }
        }
        .topStatusGlass()
    }

    @ViewBuilder
    private func journeyContent(dog: Dog, route: Route) -> some View {
        let next = JourneyService.nextLandmark(for: dog)
        let diaryEntries = recentDiaryEntries(for: dog)

        ScrollView {
            VStack(spacing: Space.lg) {
                JourneyHero(
                    dog: dog,
                    route: route,
                    progressMinutes: dog.routeProgressMinutes
                )

                LandmarkTrail(
                    route: route,
                    progressMinutes: dog.routeProgressMinutes
                )

                UpNextBlock(
                    next: next,
                    route: route,
                    progressMinutes: dog.routeProgressMinutes
                )

                if !diaryEntries.isEmpty {
                    RecentMomentsSection(entries: diaryEntries, dogName: dog.name)
                }

                ComingUpSection(currentRouteID: route.id, completedIDs: dog.completedRouteIDs)

                Color.clear.frame(height: Space.lg)
            }
            .padding(.horizontal, Space.md)
            .padding(.top, Space.md)
        }
    }

    @ViewBuilder
    private var noRouteFallback: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "map")
                .font(.system(size: 40))
                .foregroundStyle(Color.brandTextTertiary)
            Text("No active route")
                .font(.titleMedium)
                .foregroundStyle(Color.brandTextSecondary)
            Text("Routes load from the bundled data. Reinstall if this persists.")
                .font(.bodyMedium)
                .foregroundStyle(Color.brandTextTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(Space.xl)
    }

    private func recentDiaryEntries(for dog: Dog) -> [MomentDiaryEntry] {
        (dog.momentDiary ?? [])
            .sorted { $0.unlockedAt > $1.unlockedAt }
            .prefix(8)
            .map { $0 }
    }
}

// MARK: - Hero

/// Big route-progress arc with the dog photo at the center. The arc fills
/// in coral as the dog progresses through the route — like the Today ring
/// but at journey scale. Photo breathes with a slow anticipation pulse.
private struct JourneyHero: View {
    let dog: Dog
    let route: Route
    let progressMinutes: Int

    @State private var pulse = false
    @State private var animatedFraction: Double = 0

    private let outerSize: CGFloat = 260
    private let strokeWidth: CGFloat = 12
    private let photoInset: CGFloat = 26

    private var fraction: Double {
        guard route.totalMinutes > 0 else { return 0 }
        return min(1, max(0, Double(progressMinutes) / Double(route.totalMinutes)))
    }

    var body: some View {
        VStack(spacing: Space.md) {
            Text(route.name)
                .font(.displayMedium)
                .foregroundStyle(Color.brandSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.md)

            ZStack {
                // Track ring (faint)
                Circle()
                    .stroke(Color.brandDivider.opacity(0.7), lineWidth: strokeWidth)

                // Animated coral progress arc
                Circle()
                    .trim(from: 0, to: animatedFraction)
                    .stroke(
                        Color.brandPrimary,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Photo (breathes)
                photoFill
                    .frame(
                        width: outerSize - strokeWidth * 2 - photoInset * 2,
                        height: outerSize - strokeWidth * 2 - photoInset * 2
                    )
                    .clipShape(Circle())
                    .scaleEffect(pulse ? 1.025 : 1.0)
            }
            .frame(width: outerSize, height: outerSize)
            .brandCardShadow()
            .onAppear {
                withAnimation(.brandDefault.delay(0.05)) {
                    animatedFraction = fraction
                }
                withAnimation(.brandAnticipation.repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            .onChange(of: progressMinutes) { _, _ in
                withAnimation(.brandDefault) {
                    animatedFraction = fraction
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(dog.name) on \(route.name). \(Int(fraction * 100)) percent of the route.")

            heroStats
        }
    }

    private var heroStats: some View {
        HStack(spacing: Space.lg) {
            statColumn(
                value: "\(Int(fraction * 100))%",
                label: "OF ROUTE"
            )
            divider
            statColumn(
                value: formatDuration(progressMinutes),
                label: "WALKED"
            )
            divider
            statColumn(
                value: formatDuration(max(0, route.totalMinutes - progressMinutes)),
                label: "TO GO"
            )
        }
        .padding(.horizontal, Space.md)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.brandDivider)
            .frame(width: 1, height: 36)
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.titleMedium)
                .foregroundStyle(Color.brandTextPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(Color.brandTextTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    @ViewBuilder
    private var photoFill: some View {
        if let data = dog.photo, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                RadialGradient(
                    colors: [Color.brandSurfaceElevated, Color.brandSecondaryTint],
                    center: .center,
                    startRadius: 30,
                    endRadius: 130
                )
                Image(systemName: "dog.fill")
                    .font(.system(size: 50, weight: .regular))
                    .foregroundStyle(Color.brandSecondary.opacity(0.6))
            }
        }
    }
}

// MARK: - Landmark trail

/// Horizontal row of moment dots representing the route's landmarks.
/// Unlocked landmarks (passed by progressMinutes) are coral with their
/// symbol; locked are a small grey lock; the *current position* (just
/// before the next-up landmark) is a pulsing coral disc with a paw — the
/// dog's place on the trail.
///
/// Up to 6 visible at a time so the row stays readable on a phone — we
/// window around the current position. If the route is shorter than 6
/// landmarks we render them all.
private struct LandmarkTrail: View {
    let route: Route
    let progressMinutes: Int

    @State private var pulse = false

    private let maxVisible = 4
    private let dotSize: CGFloat = 36
    private let activeSize: CGFloat = 42

    var body: some View {
        let stops = visibleStops
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: 0) {
                ForEach(Array(stops.enumerated()), id: \.offset) { index, stop in
                    stopView(stop)
                    if index < stops.count - 1 {
                        connector(filled: stops[index + 1].state == .unlocked || stop.state == .current || stop.state == .unlocked)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 0) {
                ForEach(Array(stops.enumerated()), id: \.offset) { _, stop in
                    Text(stop.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(stop.state == .locked ? Color.brandTextTertiary : Color.brandTextPrimary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
            }
            .padding(.horizontal, Space.xs)
        }
        .padding(.vertical, Space.md)
        .padding(.horizontal, Space.sm)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
        .onAppear {
            withAnimation(.brandAnticipation.repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    @ViewBuilder
    private func stopView(_ stop: TrailStop) -> some View {
        switch stop.state {
        case .unlocked:
            ZStack {
                Circle()
                    .fill(Color.brandPrimary)
                Image(systemName: stop.symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: dotSize, height: dotSize)
            .accessibilityLabel("Unlocked: \(stop.label)")
        case .current:
            ZStack {
                Circle()
                    .fill(Color.brandPrimaryTint)
                Circle()
                    .stroke(Color.brandPrimary, lineWidth: 3)
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brandPrimary)
            }
            .frame(width: activeSize, height: activeSize)
            .scaleEffect(pulse ? 1.08 : 1.0)
            .accessibilityLabel("Current position: \(stop.label)")
        case .locked:
            ZStack {
                Circle()
                    .fill(Color.brandSurface)
                Circle()
                    .stroke(Color.brandDivider, lineWidth: 1.5)
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.brandTextTertiary)
            }
            .frame(width: dotSize, height: dotSize)
            .accessibilityLabel("Locked: \(stop.label)")
        }
    }

    private func connector(filled: Bool) -> some View {
        Rectangle()
            .fill(filled ? Color.brandPrimary : Color.brandDivider)
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Stops construction

    /// Window the route's landmarks into `maxVisible` stops, centred on the
    /// dog's current progress when possible. No virtual placeholder — the
    /// real landmarks are the trail.
    private var visibleStops: [TrailStop] {
        let sorted = route.landmarks.sorted { $0.minutesFromStart < $1.minutesFromStart }
        var stops: [TrailStop] = []
        for landmark in sorted {
            let state: StopState = progressMinutes >= landmark.minutesFromStart ? .unlocked : .locked
            let label = state == .unlocked ? landmark.name : "???"
            stops.append(TrailStop(label: label, symbolName: landmark.symbolName, state: state))
        }

        // Insert the "current" marker between the last unlocked and the next
        // locked, so the dog visually sits between them.
        if let firstLockedIndex = stops.firstIndex(where: { $0.state == .locked }) {
            stops.insert(
                TrailStop(label: "You", symbolName: "pawprint.fill", state: .current, isVirtual: true),
                at: firstLockedIndex
            )
        }

        // Window — keep up to maxVisible centred on the current marker.
        guard stops.count > maxVisible else { return stops }
        let currentIndex = stops.firstIndex(where: { $0.state == .current }) ?? stops.count / 2
        let half = maxVisible / 2
        var lower = max(0, currentIndex - half)
        var upper = min(stops.count, lower + maxVisible)
        // If we hit the right edge first, slide the window left.
        if upper - lower < maxVisible {
            lower = max(0, upper - maxVisible)
        }
        // If the lower edge is at zero, slide right.
        if upper - lower < maxVisible {
            upper = min(stops.count, lower + maxVisible)
        }
        return Array(stops[lower..<upper])
    }

    private struct TrailStop {
        let label: String
        let symbolName: String
        let state: StopState
        var isVirtual: Bool = false
    }

    private enum StopState {
        case unlocked, current, locked
    }
}

// MARK: - Up next block

/// Display-type "Up next: <duration> to <???>". Replaces the old NEXT UP
/// caption and progress bar — the trail above carries the visual job; this
/// block is the single high-value sentence underneath.
private struct UpNextBlock: View {
    let next: NextLandmark?
    let route: Route
    let progressMinutes: Int

    var body: some View {
        if let next {
            content(next: next)
        } else {
            routeCompleteContent
        }
    }

    private func content(next: NextLandmark) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("UP NEXT")
                .font(.caption.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(Color.brandTextSecondary)
            HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                Text(durationLabel(minutesAway: next.minutesAway))
                    .font(.displayMedium)
                    .foregroundStyle(Color.brandPrimary)
                Text("to ???")
                    .font(.titleSmall)
                    .foregroundStyle(Color.brandTextSecondary)
                Spacer()
                Image(systemName: "arrow.forward.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.brandPrimary.opacity(0.45))
            }
        }
        .padding(Space.md)
        .background(Color.brandPrimaryTint)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Up next, \(next.minutesAway) minutes to the next moment.")
    }

    private func durationLabel(minutesAway: Int) -> String {
        if minutesAway < 60 { return "\(minutesAway) min" }
        let h = minutesAway / 60
        let m = minutesAway % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    private var routeCompleteContent: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.brandSecondary)
            Text("\(route.name) complete!")
                .font(.titleSmall)
                .foregroundStyle(Color.brandSecondary)
            Spacer()
        }
        .padding(Space.md)
        .background(Color.brandSecondaryTint)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    }
}

// MARK: - Recent Moments (diary entries)

private struct RecentMomentsSection: View {
    let entries: [MomentDiaryEntry]
    let dogName: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Diary entries")
                .font(.titleSmall)
                .foregroundStyle(Color.brandTextPrimary)

            VStack(spacing: Space.sm) {
                ForEach(entries) { entry in
                    DiaryEntryCard(entry: entry, dogName: dogName)
                }
            }
        }
    }
}

private struct DiaryEntryCard: View {
    let entry: MomentDiaryEntry
    let dogName: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                ZStack {
                    Circle()
                        .fill(Color.brandPrimary)
                    Image(systemName: entry.symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.momentTitle)
                        .font(.bodyLarge.weight(.semibold))
                        .foregroundStyle(Color.brandTextPrimary)
                    Text(Self.dateLabel(entry.unlockedAt))
                        .font(.caption)
                        .foregroundStyle(Color.brandTextTertiary)
                }
                Spacer()
            }

            Text("\u{201C}\(entry.dogVoiceLine)\u{201D}")
                .font(.bodyLarge)
                .italic()
                .foregroundStyle(Color.brandTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Spacer()
                Text("— \(dogName)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brandSecondary)
            }
        }
        .padding(Space.md)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.momentTitle), \(Self.dateLabel(entry.unlockedAt)). \(dogName) says: \(entry.dogVoiceLine)")
    }

    private static func dateLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let days = calendar.dateComponents([.day], from: date, to: .now).day ?? 0
        if days < 7 {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_GB")
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}

// MARK: - Coming up

private struct ComingUpSection: View {
    let currentRouteID: String
    let completedIDs: [String]

    var body: some View {
        let nextID = JourneyService.nextRouteID(after: currentRouteID)
        let nextRoute = JourneyService.route(for: nextID)
        let completed = completedRoutes()

        VStack(alignment: .leading, spacing: Space.md) {
            if !completed.isEmpty {
                completedBlock(routes: completed)
            }
            if let nextRoute, nextID != currentRouteID, !completedIDs.contains(currentRouteID) {
                comingUpBlock(route: nextRoute)
            }
        }
    }

    private func completedRoutes() -> [Route] {
        completedIDs.compactMap { JourneyService.route(for: $0) }
    }

    private func completedBlock(routes: [Route]) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Completed seasons")
                .font(.titleSmall)
                .foregroundStyle(Color.brandTextPrimary)
            FlowLayout(spacing: Space.sm) {
                ForEach(routes) { route in
                    completedPill(route: route)
                }
            }
        }
    }

    private func completedPill(route: Route) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
            Text(route.name)
                .font(.captionBold)
        }
        .foregroundStyle(Color.brandSecondary)
        .padding(.horizontal, Space.sm + 2)
        .padding(.vertical, 6)
        .background(Color.brandSecondaryTint)
        .clipShape(Capsule())
    }

    private func comingUpBlock(route: Route) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Up next, after this")
                .font(.titleSmall)
                .foregroundStyle(Color.brandTextPrimary)

            HStack(spacing: Space.md) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.brandTextTertiary)
                    .frame(width: 36, height: 36)
                    .background(Color.brandSurface)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(route.name)
                        .font(.bodyLarge.weight(.semibold))
                        .foregroundStyle(Color.brandTextPrimary)
                    Text(route.subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.brandTextSecondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(Space.md)
            .background(Color.brandSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .brandCardShadow()
        }
    }
}

// MARK: - Empty state

private struct EmptyJourneyPlaceholder: View {
    var body: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "map")
                .font(.system(size: 40))
                .foregroundStyle(Color.brandTextTertiary)
            Text("Add a dog to begin a journey.")
                .font(.titleMedium)
                .foregroundStyle(Color.brandTextSecondary)
        }
        .padding(Space.xl)
    }
}

// MARK: - Tiny flow layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = Space.sm

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[CGSize]] = [[]]
        var currentRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentRowWidth + size.width > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([])
                currentRowWidth = 0
            }
            rows[rows.count - 1].append(size)
            currentRowWidth += size.width + spacing
        }

        let height = rows.reduce(0) { sum, row in
            sum + (row.map(\.height).max() ?? 0) + spacing
        } - spacing
        return CGSize(width: maxWidth, height: max(0, height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
