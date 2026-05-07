import SwiftUI
import SwiftData

/// Trot's signature retention surface, promoted from a Home card to a dedicated tab.
/// Layout: dog photo as the alive, breathing centerpiece; route name in display
/// type; an anticipation block that names the next landmark; a STRAIGHT-line
/// landmark timeline below it; recent crossings + coming-up routes scroll in
/// underneath. Pure SwiftUI — no commissioned art for v1.
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
    }

    @ViewBuilder
    private func journeyContent(dog: Dog, route: Route) -> some View {
        let progressFraction = route.totalKm > 0
            ? min(1, max(0, dog.routeProgressKm / route.totalKm))
            : 0
        let next = JourneyService.nextLandmark(for: dog)
        let recentLandmarks = recentlyUnlocked(route: route, progressKm: dog.routeProgressKm)

        ScrollView {
            VStack(spacing: Space.lg) {
                JourneyHero(dog: dog, route: route, progressKm: dog.routeProgressKm)

                NextLandmarkPanel(next: next, route: route, progressKm: dog.routeProgressKm)

                JourneyTimelineStrip(
                    route: route,
                    progressFraction: progressFraction,
                    dogPhoto: dog.photo
                )

                if !recentLandmarks.isEmpty {
                    RecentLandmarksSection(landmarks: recentLandmarks, route: route)
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

    /// Up to five most recent unlocked landmarks, in reverse km order.
    private func recentlyUnlocked(route: Route, progressKm: Double) -> [Landmark] {
        route.landmarks
            .filter { $0.kmFromStart <= progressKm }
            .sorted { $0.kmFromStart > $1.kmFromStart }
            .prefix(5)
            .map { $0 }
    }
}

// MARK: - Hero

/// Big route headline + the dog photo as the breathing centerpiece. The photo
/// itself does the work — coral ring, slow anticipation pulse, no extra chrome.
private struct JourneyHero: View {
    let dog: Dog
    let route: Route
    let progressKm: Double

    @State private var pulse = false

    private let photoSize: CGFloat = 180
    private let strokeWidth: CGFloat = 8

    var body: some View {
        VStack(spacing: Space.md) {
            VStack(spacing: 4) {
                Text(route.name)
                    .font(.displayMedium)
                    .foregroundStyle(Color.brandSecondary)
                    .multilineTextAlignment(.center)
                Text(statsLabel)
                    .font(.bodyMedium.weight(.semibold))
                    .foregroundStyle(Color.brandTextSecondary)
            }
            .frame(maxWidth: .infinity)

            ZStack {
                Circle()
                    .stroke(Color.brandPrimary, lineWidth: strokeWidth)

                photoFill
                    .frame(
                        width: photoSize - strokeWidth * 2,
                        height: photoSize - strokeWidth * 2
                    )
                    .clipShape(Circle())
            }
            .frame(width: photoSize, height: photoSize)
            .scaleEffect(pulse ? 1.025 : 1.0)
            .brandCardShadow()
            .onAppear {
                withAnimation(.brandAnticipation.repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            .accessibilityLabel("\(dog.name) on \(route.name).")
        }
    }

    private var statsLabel: String {
        let progress = formatKm(progressKm)
        let total = formatKm(route.totalKm)
        let toGo = formatKm(max(0, route.totalKm - progressKm))
        return "\(progress) of \(total) km · \(toGo) to go"
    }

    private func formatKm(_ km: Double) -> String {
        if km >= 10 { return String(format: "%.0f", km) }
        return String(format: "%.1f", km)
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
                    startRadius: 20,
                    endRadius: 110
                )
                Image(systemName: "dog.fill")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(Color.brandSecondary.opacity(0.6))
            }
        }
    }
}

// MARK: - Anticipation block

/// Names the next unreached landmark and shows how close we are. The biggest
/// pull on this screen — "240m to The Bench" is what makes someone leave the
/// house.
private struct NextLandmarkPanel: View {
    let next: NextLandmark?
    let route: Route
    let progressKm: Double

    @State private var animatedFraction: Double = 0

    var body: some View {
        if let next {
            content(next: next)
                .onAppear {
                    withAnimation(.brandDefault) {
                        animatedFraction = fractionToNext(next: next)
                    }
                }
                .onChange(of: progressKm) { _, _ in
                    withAnimation(.brandDefault) {
                        animatedFraction = fractionToNext(next: next)
                    }
                }
        } else {
            routeCompleteContent
        }
    }

    @ViewBuilder
    private func content(next: NextLandmark) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.brandPrimary)
                Text("\(next.metersAway)m to ???")
                    .font(.titleSmall)
                    .foregroundStyle(Color.brandTextPrimary)
                Spacer()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.brandDivider)
                        .frame(height: 6)
                    Capsule()
                        .fill(Color.brandPrimary)
                        .frame(width: geo.size.width * max(0.02, animatedFraction), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(Space.md)
        .background(Color.brandPrimaryTint)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(next.metersAway) metres to the next landmark.")
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

    /// How close are we to the next landmark, expressed as a fraction of the
    /// distance between the previous landmark (or start) and this one. Drives
    /// the progress bar fill.
    private func fractionToNext(next: NextLandmark) -> Double {
        let landmarksBefore = route.landmarks
            .filter { $0.kmFromStart < next.landmark.kmFromStart }
            .sorted { $0.kmFromStart < $1.kmFromStart }
        let prevKm = landmarksBefore.last?.kmFromStart ?? 0
        let span = next.landmark.kmFromStart - prevKm
        guard span > 0 else { return 1 }
        let progressedInSpan = max(0, progressKm - prevKm)
        return min(1, max(0.02, progressedInSpan / span))
    }
}

// MARK: - Straight-line timeline

/// The route as a horizontal line. Landmark dots positioned by their km, dog
/// photo as the marker positioned at progressFraction. Replaces the curved
/// Catmull-Rom path of the old Home card — straighter is cleaner and reads
/// better at a glance.
private struct JourneyTimelineStrip: View {
    let route: Route
    let progressFraction: Double
    let dogPhoto: Data?

    @State private var markerPulse = false

    private let stripHeight: CGFloat = 80
    private let dogSize: CGFloat = 40
    private let dotSize: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack {
                Text("THE ROUTE")
                    .font(.caption.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(Color.brandTextSecondary)
                Spacer()
                Text("\(route.landmarks.count) landmarks")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brandTextTertiary)
            }

            GeometryReader { geo in
                let width = geo.size.width
                let trackY = stripHeight / 2

                ZStack(alignment: .topLeading) {
                    // Locked baseline — full width, faint
                    Capsule()
                        .fill(Color.brandDivider.opacity(0.55))
                        .frame(width: width, height: 4)
                        .offset(y: trackY - 2)

                    // Completed coral overlay
                    Capsule()
                        .fill(Color.brandPrimary)
                        .frame(width: width * progressFraction, height: 4)
                        .offset(y: trackY - 2)

                    // Landmark dots
                    ForEach(route.landmarks) { landmark in
                        let fraction = landmark.kmFromStart / max(0.0001, route.totalKm)
                        let unlocked = fraction <= progressFraction
                        TimelineDot(landmark: landmark, unlocked: unlocked)
                            .frame(width: dotSize, height: dotSize)
                            .position(
                                x: width * fraction,
                                y: trackY
                            )
                    }

                    // Dog marker — sits on the line at progressFraction.
                    DogTimelineMarker(photo: dogPhoto)
                        .frame(width: dogSize, height: dogSize)
                        .position(
                            x: width * progressFraction,
                            y: trackY
                        )
                        .scaleEffect(markerPulse ? 1.06 : 1.0)
                        .onAppear {
                            withAnimation(.brandAnticipation.repeatForever(autoreverses: true)) {
                                markerPulse = true
                            }
                        }
                }
            }
            .frame(height: stripHeight)
        }
        .padding(Space.md)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
    }
}

private struct TimelineDot: View {
    let landmark: Landmark
    let unlocked: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(unlocked ? Color.brandPrimaryTint : Color.brandSurface)
            Circle()
                .stroke(
                    unlocked ? Color.brandPrimary : Color.brandDivider,
                    lineWidth: unlocked ? 1.5 : 1
                )
            Image(systemName: unlocked ? landmark.symbolName : "lock.fill")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(unlocked ? Color.brandPrimary : Color.brandTextTertiary)
        }
        .accessibilityLabel(unlocked ? landmark.name : "Locked landmark")
    }
}

private struct DogTimelineMarker: View {
    let photo: Data?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.brandSurfaceElevated)
            Circle()
                .stroke(Color.brandPrimary, lineWidth: 2.5)
            if let photo, let image = UIImage(data: photo) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
                    .padding(3)
            } else {
                Image(systemName: "dog.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brandPrimary)
            }
        }
        .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)
        .accessibilityLabel("Your dog's position on the route")
    }
}

// MARK: - Recent landmarks

private struct RecentLandmarksSection: View {
    let landmarks: [Landmark]
    let route: Route

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("RECENT LANDMARKS")
                .font(.caption.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(Color.brandTextSecondary)

            VStack(spacing: 0) {
                ForEach(Array(landmarks.enumerated()), id: \.element.id) { index, landmark in
                    LandmarkRow(landmark: landmark)
                    if index < landmarks.count - 1 {
                        Divider()
                            .background(Color.brandDivider)
                            .padding(.leading, Space.lg + 24)
                    }
                }
            }
            .background(Color.brandSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .brandCardShadow()
        }
    }
}

private struct LandmarkRow: View {
    let landmark: Landmark

    var body: some View {
        HStack(spacing: Space.md) {
            Image(systemName: landmark.symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 24, height: 24)
                .background(Color.brandPrimaryTint)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(landmark.name)
                    .font(.bodyMedium.weight(.semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                Text(landmark.description)
                    .font(.caption)
                    .foregroundStyle(Color.brandTextSecondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm + 2)
    }
}

// MARK: - Coming up

/// Below-the-fold preview of the next route in the sequence + a small set of
/// "completed" badges if any routes are already done. Keeps the long-term
/// anticipation alive — the user can see what comes after London-Brighton.
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
            Text("COMPLETED")
                .font(.caption.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(Color.brandTextSecondary)
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
            Text("COMING UP")
                .font(.caption.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(Color.brandTextSecondary)

            HStack(spacing: Space.md) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.brandTextTertiary)
                    .frame(width: 36, height: 36)
                    .background(Color.brandSurface)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(route.name)
                        .font(.titleSmall)
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

// MARK: - Tiny flow layout (for the completed pills)

/// Wraps children onto multiple lines like CSS flex-wrap. Used for the
/// completed-routes pill cluster which can be 0..n long.
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
