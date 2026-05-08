import SwiftUI
import SwiftData

/// Trot's signature retention surface. Tells the user where they are in
/// their dog's narrative arc and what's coming next, with the dog photo as
/// the breathing centerpiece.
///
/// Three vertical bands, top to bottom — one screen, one story:
///
///   1. **Chapter hero** — dog photo inside a route-progress arc, route
///      name + subtitle in display type, the cumulative-distance brag
///      ("You and Bonnie have walked 18 km together. That's Brighton to
///      Hove.") and a single narrative line tied to where the user is in
///      the route.
///   2. **The path** — vertical scrollable list of every landmark on the
///      current route. Past landmarks: filled, named, dated. Current
///      "you" position: pulsing. Next 1-2 locked landmarks fully named so
///      the user has something to walk toward. Beyond that: silhouettes —
///      mystery without redaction.
///   3. **Chapters journal** — every completed route as a memory card
///      with the chapter name, total time, and an LLM-generated single-
///      sentence memory in the dog's voice (cached forever via
///      `ChapterMemoryService`). Falls back to a templated line if the
///      LLM is offline or the memory hasn't generated yet.
///
/// The earlier "???" placeholders, "Up next ???" block, "Highlights"
/// card, "Completed seasons" pills, and "Up next, after this" tease
/// are all gone — the data was rich (36 named landmarks across 4 routes
/// with descriptions and SF symbols) but the old UI redacted it.
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
        .edgeGlass()
    }

    @ViewBuilder
    private func journeyContent(dog: Dog, route: Route) -> some View {
        let next = JourneyService.nextLandmark(for: dog)

        ScrollView {
            VStack(spacing: Space.lg) {
                JourneyHero(
                    dog: dog,
                    route: route,
                    progressMinutes: dog.routeProgressMinutes,
                    next: next
                )

                JourneyPath(
                    route: route,
                    progressMinutes: dog.routeProgressMinutes
                )

                ChaptersJournal(
                    dog: dog,
                    completedIDs: dog.completedRouteIDs
                )

                // Extra clearance so the last card never hides behind the
                // centre walk FAB.
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
}

// MARK: - Hero

/// Chapter hero — route name + subtitle, dog photo inside a progress arc,
/// distance-translation brag, and a single narrative line about where the
/// user is in the chapter. Replaces the old hero + standalone Highlights
/// card; the lifetime stats live here now.
private struct JourneyHero: View {
    let dog: Dog
    let route: Route
    let progressMinutes: Int
    let next: NextLandmark?

    @State private var pulse = false
    @State private var animatedFraction: Double = 0

    private let outerSize: CGFloat = 220
    private let strokeWidth: CGFloat = 11
    private let photoInset: CGFloat = 22

    private var fraction: Double {
        guard route.totalMinutes > 0 else { return 0 }
        return min(1, max(0, Double(progressMinutes) / Double(route.totalMinutes)))
    }

    var body: some View {
        VStack(spacing: Space.md) {
            VStack(spacing: 4) {
                Text(route.name)
                    .font(.displayMedium)
                    .atmosphereTextPrimary()
                    .multilineTextAlignment(.center)
                Text(route.subtitle)
                    .font(.bodyMedium)
                    .atmosphereTextSecondary()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.md)
            }

            ZStack {
                Circle()
                    .stroke(Color.brandDivider.opacity(0.7), lineWidth: strokeWidth)

                Circle()
                    .trim(from: 0, to: animatedFraction)
                    .stroke(
                        Color.brandPrimary,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                photoFill
                    .frame(
                        width: outerSize - strokeWidth * 2 - photoInset * 2,
                        height: outerSize - strokeWidth * 2 - photoInset * 2
                    )
                    .clipShape(Circle())
                    .scaleEffect(pulse ? 1.025 : 1.0)

                percentBadge
                    .offset(x: outerSize / 2 - 24, y: outerSize / 2 - 24)
            }
            .frame(width: outerSize, height: outerSize)
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

            narrativeLine

            heroStats

            if let translation = distanceLine {
                // Distance line sits BELOW the atmosphere gradient (which
                // fades to clear ~60% down) so it lives on the cream brand
                // surface — use the standard secondary text colour, not the
                // atmosphere swap, so it doesn't read as washed-out cream
                // on cream at night.
                Text(translation)
                    .font(.bodyMedium)
                    .italic()
                    .foregroundStyle(Color.brandTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.md)
            }
        }
    }

    /// One sentence that locates the user in this chapter. Three buckets:
    /// just-started, midway, almost-done. Pulled from the route's `subtitle`
    /// so each chapter has its own voice — no LLM, no per-walk variation,
    /// just clear positioning.
    private var narrativeLine: some View {
        let pct = Int(fraction * 100)
        let dogName = dog.name
        let text: String = {
            if pct < 20 {
                return "Just starting *\(route.name)* with \(dogName)."
            } else if pct < 75 {
                return "Halfway through *\(route.name)* with \(dogName). The bond is settling in."
            } else if pct < 100 {
                return "Almost through *\(route.name)*. \(dogName) knows the rhythm."
            } else {
                return "*\(route.name)* — walked. Onto the next chapter."
            }
        }()
        return Text(.init(text))
            .font(.bodyLarge)
            .foregroundStyle(Color.brandTextPrimary)
            .multilineTextAlignment(.center)
            .padding(Space.md)
            .frame(maxWidth: .infinity)
            .background(Color.brandSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .brandCardShadow()
    }

    /// Three-column lifetime strip — walks, minutes, km. Shifts the
    /// "Highlights" card's job into the hero where it belongs (the lifetime
    /// numbers tell the chapter context at a glance, not as a separate
    /// section).
    private var heroStats: some View {
        let walks = dog.walks ?? []
        let walkCount = walks.count
        let minutes = walks.reduce(0) { $0 + $1.durationMinutes }
        let km = DistanceTranslator.totalKilometres(for: dog)
        return HStack(spacing: 0) {
            statColumn(value: "\(walkCount)", label: walkCount == 1 ? "WALK" : "WALKS")
            divider
            statColumn(value: formatDuration(minutes), label: "TOGETHER")
            divider
            statColumn(value: km >= 10 ? "\(Int(km.rounded()))" : String(format: "%.1f", km), label: "KM")
        }
        .padding(.vertical, Space.sm)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.brandDivider)
            .frame(width: 1, height: 28)
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

    private var distanceLine: String? {
        let km = DistanceTranslator.totalKilometres(for: dog)
        guard let milestone = DistanceTranslator.milestone(forKilometres: km) else { return nil }
        let pretty = km >= 10 ? "\(Int(km.rounded())) km" : String(format: "%.1f km", km)
        return "That's about \(milestone.label) — \(pretty) walked together."
    }

    private var percentBadge: some View {
        Text("\(Int(fraction * 100))%")
            .font(.titleSmall.weight(.bold))
            .foregroundStyle(Color.brandTextOnPrimary)
            .padding(.horizontal, Space.sm)
            .padding(.vertical, 6)
            .background(Color.brandPrimary)
            .clipShape(Capsule())
            .shadow(color: Color.brandPrimary.opacity(0.4), radius: 6, x: 0, y: 3)
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h\(m)"
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

// MARK: - Vertical path

/// Vertical scrollable path of every landmark on the current route. Replaces
/// the old horizontal landmark trail.
///
/// Progressive reveal pattern, anchored on the dog's current position:
///   * past landmarks  → filled coral icon, full name + description
///   * current "you"   → pulsing coral with paw icon, naming the next
///                        landmark inline so anticipation has a target
///   * next locked     → full name visible, full icon at half tint,
///                        description visible (this is the *pull* — the
///                        thing the user is walking toward)
///   * one beyond      → name visible at low alpha, icon outline only,
///                        no description
///   * two+ beyond     → silhouette icon only, no name (mystery without
///                        redaction)
private struct JourneyPath: View {
    let route: Route
    let progressMinutes: Int

    @State private var pulse = false

    private let dotSize: CGFloat = 36
    private let activeSize: CGFloat = 40
    private let connectorWidth: CGFloat = 2

    var body: some View {
        let stops = pathStops
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                pathRow(
                    stop: stop,
                    isFirst: index == 0,
                    isLast: index == stops.count - 1
                )
            }
        }
        .padding(Space.md)
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
    private func pathRow(stop: PathStop, isFirst: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: Space.sm) {
            VStack(spacing: 0) {
                connectorAbove(visible: !isFirst, filled: stop.connectorAboveFilled)
                stopGlyph(stop: stop)
                connectorBelow(visible: !isLast, filled: stop.connectorBelowFilled)
            }
            .frame(width: max(activeSize, dotSize))

            VStack(alignment: .leading, spacing: 4) {
                if let nameText = stop.nameText {
                    Text(nameText)
                        .font(stop.kind == .current ? .bodyLarge.weight(.semibold) : .bodyLarge.weight(.semibold))
                        .foregroundStyle(stop.nameColor)
                }
                if let detail = stop.detailText {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Color.brandTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let stamp = stop.stampText {
                    Text(stamp.uppercased())
                        .font(.caption2.weight(.semibold))
                        .tracking(0.5)
                        .foregroundStyle(Color.brandTextTertiary)
                }
            }
            .padding(.top, isFirst ? 0 : 4)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(stop.accessibilityLabel)
    }

    @ViewBuilder
    private func stopGlyph(stop: PathStop) -> some View {
        switch stop.kind {
        case .past:
            ZStack {
                Circle().fill(Color.brandPrimary)
                Image(systemName: stop.symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: dotSize, height: dotSize)
        case .current:
            ZStack {
                Circle().fill(Color.brandPrimaryTint)
                Circle().stroke(Color.brandPrimary, lineWidth: 3)
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brandPrimary)
            }
            .frame(width: activeSize, height: activeSize)
            .scaleEffect(pulse ? 1.08 : 1.0)
        case .nextLocked:
            ZStack {
                Circle().fill(Color.brandPrimary.opacity(0.18))
                Circle().stroke(Color.brandPrimary.opacity(0.5), lineWidth: 1.5)
                Image(systemName: stop.symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brandPrimary)
            }
            .frame(width: dotSize, height: dotSize)
        case .nearLocked:
            ZStack {
                Circle().stroke(Color.brandDivider, lineWidth: 1.5)
                Image(systemName: stop.symbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.brandTextTertiary)
            }
            .frame(width: dotSize, height: dotSize)
        case .farLocked:
            ZStack {
                Circle().stroke(Color.brandDivider.opacity(0.5), lineWidth: 1)
                Image(systemName: stop.symbolName)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.brandTextTertiary.opacity(0.5))
            }
            .frame(width: dotSize, height: dotSize)
        }
    }

    private func connectorAbove(visible: Bool, filled: Bool) -> some View {
        Rectangle()
            .fill(filled ? Color.brandPrimary : Color.brandDivider)
            .frame(width: connectorWidth, height: 18)
            .opacity(visible ? 1 : 0)
    }

    private func connectorBelow(visible: Bool, filled: Bool) -> some View {
        Rectangle()
            .fill(filled ? Color.brandPrimary : Color.brandDivider)
            .frame(width: connectorWidth, height: 32)
            .opacity(visible ? 1 : 0)
    }

    // MARK: - Path construction

    /// Builds the ordered list of path stops by walking the route's landmarks
    /// (sorted by minutesFromStart), inserting the "current you" marker
    /// between the last unlocked and first locked, and assigning a kind
    /// based on each landmark's position relative to the current marker.
    private var pathStops: [PathStop] {
        let sorted = route.landmarks.sorted { $0.minutesFromStart < $1.minutesFromStart }
        var stops: [PathStop] = []

        var firstLockedIndex: Int?
        for (offset, landmark) in sorted.enumerated() {
            let isUnlocked = progressMinutes >= landmark.minutesFromStart
            if !isUnlocked, firstLockedIndex == nil {
                firstLockedIndex = offset
            }
        }

        for (offset, landmark) in sorted.enumerated() {
            let isUnlocked = progressMinutes >= landmark.minutesFromStart
            if isUnlocked {
                stops.append(PathStop(
                    id: landmark.id,
                    kind: .past,
                    symbolName: landmark.symbolName,
                    nameText: landmark.name,
                    nameColor: .brandTextPrimary,
                    detailText: landmark.description,
                    stampText: "Crossed",
                    connectorAboveFilled: true,
                    connectorBelowFilled: true,
                    accessibilityLabel: "Crossed: \(landmark.name). \(landmark.description)"
                ))
            } else if let firstLockedIndex, offset >= firstLockedIndex {
                let distanceFromCurrent = offset - firstLockedIndex
                let kind: PathStop.Kind
                switch distanceFromCurrent {
                case 0:  kind = .nextLocked
                case 1:  kind = .nearLocked
                default: kind = .farLocked
                }
                let nameText: String?
                let nameColor: Color
                let detailText: String?
                let stampText: String?
                switch kind {
                case .nextLocked:
                    let minutesAway = max(0, landmark.minutesFromStart - progressMinutes)
                    nameText = landmark.name
                    nameColor = .brandTextPrimary
                    detailText = landmark.description
                    stampText = "About \(formatMinutesAway(minutesAway)) walked away"
                case .nearLocked:
                    nameText = landmark.name
                    nameColor = .brandTextSecondary
                    detailText = nil
                    stampText = nil
                case .farLocked:
                    nameText = nil
                    nameColor = .brandTextTertiary
                    detailText = nil
                    stampText = nil
                default:
                    nameText = nil
                    nameColor = .brandTextTertiary
                    detailText = nil
                    stampText = nil
                }
                stops.append(PathStop(
                    id: landmark.id,
                    kind: kind,
                    symbolName: landmark.symbolName,
                    nameText: nameText,
                    nameColor: nameColor,
                    detailText: detailText,
                    stampText: stampText,
                    connectorAboveFilled: false,
                    connectorBelowFilled: false,
                    accessibilityLabel: kind == .nextLocked
                        ? "Coming up: \(landmark.name). \(landmark.description)"
                        : (nameText.map { "Locked: \($0)" } ?? "Locked landmark")
                ))
            }
        }

        // "You" marker — inserted between last past and first locked. If the
        // user has finished every landmark, the marker sits at the end.
        let firstNonPastIndex = stops.firstIndex(where: { $0.kind != .past }) ?? stops.count
        let nextName: String?
        if firstNonPastIndex < stops.count {
            let nextStop = stops[firstNonPastIndex]
            nextName = nextStop.nameText
        } else {
            nextName = nil
        }
        let youDetail: String?
        if let nextName {
            youDetail = "Walking toward \(nextName)."
        } else {
            youDetail = nil
        }
        let youStop = PathStop(
            id: "__you__",
            kind: .current,
            symbolName: "pawprint.fill",
            nameText: "You're here",
            nameColor: .brandTextPrimary,
            detailText: youDetail,
            stampText: nil,
            connectorAboveFilled: true,
            connectorBelowFilled: false,
            accessibilityLabel: "You are here. \(youDetail ?? "")"
        )
        stops.insert(youStop, at: firstNonPastIndex)

        return stops
    }

    private func formatMinutesAway(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) hr" : "\(h) hr \(m) min"
    }

    private struct PathStop: Identifiable {
        enum Kind {
            case past
            case current
            case nextLocked
            case nearLocked
            case farLocked
        }
        let id: String
        let kind: Kind
        let symbolName: String
        let nameText: String?
        let nameColor: Color
        let detailText: String?
        let stampText: String?
        let connectorAboveFilled: Bool
        let connectorBelowFilled: Bool
        let accessibilityLabel: String
    }
}

// MARK: - Chapters journal

/// A memory card per completed route. Replaces the old "Completed seasons"
/// pill row + "Up next, after this" tease, both of which were mystery noise
/// rather than emotional payoff. Each card shows the chapter name, total
/// time, and a one-sentence dog-voice memory generated by
/// `ChapterMemoryService` (LLM, cached forever) with a templated fallback.
///
/// On appear, the card requests memory generation for any completed route
/// that doesn't have one yet. Idempotent — fires at most one LLM call per
/// (dog, route) for the lifetime of the install.
private struct ChaptersJournal: View {
    let dog: Dog
    let completedIDs: [String]

    /// Bumped after a memory generation request so the view re-reads the
    /// cache. Generation is fire-and-forget; we re-render lazily on next
    /// scrolls or tab returns. The bump is for deterministic SwiftUI Preview
    /// updates more than runtime needs.
    @State private var refreshTick: Int = 0

    var body: some View {
        let routes = completedRoutes
        if routes.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("Chapters walked")
                    .font(.titleSmall)
                    .foregroundStyle(Color.brandTextPrimary)

                VStack(spacing: Space.sm) {
                    ForEach(routes) { route in
                        chapterCard(route: route)
                    }
                }
            }
            .onAppear {
                for route in routes {
                    ChapterMemoryService.generateIfNeeded(routeID: route.id, route: route, dog: dog)
                }
            }
        }
    }

    private var completedRoutes: [Route] {
        completedIDs.compactMap { JourneyService.route(for: $0) }
    }

    private func chapterCard(route: Route) -> some View {
        let memory = ChapterMemoryService.cachedMemory(routeID: route.id, dog: dog)
            ?? ChapterMemoryService.templatedFallback(routeID: route.id, route: route, dog: dog)
        let totalLabel = formatHours(route.totalMinutes)
        return VStack(alignment: .leading, spacing: Space.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(route.name)
                    .font(.bodyLarge.weight(.semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text(totalLabel)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Color.brandSecondary)
            }
            Text(.init("*\(memory)*"))
                .font(.bodyMedium)
                .foregroundStyle(Color.brandTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Chapter walked: \(route.name). \(memory)")
    }

    private func formatHours(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m) min" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
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
