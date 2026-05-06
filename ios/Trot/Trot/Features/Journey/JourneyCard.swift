import SwiftUI
import SwiftData

/// Visual journey card for Home — Trot's signature long-tail engagement element.
/// Draws the active route as a smooth SwiftUI Path through normalised control
/// points, splits it into "completed" (coral) and "locked" (faint) portions at
/// the dog's progress fraction, plants landmark stamps along the path, and
/// positions the dog's photo as the journey marker.
///
/// No commissioned assets — purely shapes, SF Symbols, and brand tokens.
struct JourneyCard: View {
    let dog: Dog

    private var route: Route? {
        JourneyService.currentRoute(for: dog)
    }

    var body: some View {
        if let route {
            cardBody(route: route)
        } else {
            // Defensive fallback: no route data (e.g. Routes.json missing in tests).
            // Just hide the card silently rather than crash.
            EmptyView()
        }
    }

    @ViewBuilder
    private func cardBody(route: Route) -> some View {
        let progressFraction = route.totalKm > 0
            ? min(1, max(0, dog.routeProgressKm / route.totalKm))
            : 0
        let next = JourneyService.nextLandmark(for: dog)

        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(route.name.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(Color.brandTextSecondary)
                Spacer()
                Text(progressLabel(progressKm: dog.routeProgressKm, totalKm: route.totalKm))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brandTextTertiary)
            }

            JourneyPathView(
                route: route,
                progressFraction: progressFraction,
                dogPhoto: dog.photo
            )
            .frame(height: 120)

            nextLandmarkLine(next)
        }
        .padding(Space.md)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
    }

    private func progressLabel(progressKm: Double, totalKm: Double) -> String {
        let progress = formatKm(progressKm)
        let total = formatKm(totalKm)
        let toGo = formatKm(max(0, totalKm - progressKm))
        return "\(progress) of \(total) km · \(toGo) to go"
    }

    private func formatKm(_ km: Double) -> String {
        if km >= 10 { return String(format: "%.0f", km) }
        return String(format: "%.1f", km)
    }

    @ViewBuilder
    private func nextLandmarkLine(_ next: NextLandmark?) -> some View {
        if let next {
            HStack(spacing: Space.xs) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brandTextTertiary)
                Text("\(next.metersAway)m to ???")
                    .font(.bodyMedium)
                    .foregroundStyle(Color.brandTextSecondary)
                Spacer()
            }
        } else {
            HStack(spacing: Space.xs) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brandSecondary)
                Text("Route complete")
                    .font(.bodyMedium.weight(.semibold))
                    .foregroundStyle(Color.brandSecondary)
                Spacer()
            }
        }
    }
}

/// Inner SwiftUI view that draws the route path + landmarks + dog marker.
/// Separated so the layout math has its own GeometryReader scope.
private struct JourneyPathView: View {
    let route: Route
    let progressFraction: Double
    let dogPhoto: Data?

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let points = route.pathPoints.map { p in
                CGPoint(x: p.x * size.width, y: p.y * size.height)
            }

            ZStack {
                // Locked / not-yet-walked portion (drawn full, then completed
                // overlays it).
                JourneyPath(points: points)
                    .stroke(
                        Color.brandDivider.opacity(0.55),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )

                // Completed portion in coral.
                JourneyPath(points: points)
                    .trim(from: 0, to: progressFraction)
                    .stroke(
                        Color.brandPrimary,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )

                // Landmark stamps. Each landmark's position along the route is
                // approximated by linear interpolation among the control points
                // (faithful enough at this scale; precise arc-length traversal
                // isn't worth the complexity for v1).
                ForEach(route.landmarks) { landmark in
                    let landmarkFraction = landmark.kmFromStart / max(0.0001, route.totalKm)
                    let unlocked = landmarkFraction <= progressFraction
                    let pos = pointAlong(points: points, fraction: landmarkFraction)
                    LandmarkStamp(landmark: landmark, unlocked: unlocked)
                        .position(pos)
                }

                // Dog marker — slides along the path at progressFraction.
                let dogPos = pointAlong(points: points, fraction: progressFraction)
                DogMarker(photo: dogPhoto)
                    .position(dogPos)
            }
        }
    }

    /// Linear interpolation between consecutive control points to get the
    /// approximate location at progress `fraction` (0...1).
    private func pointAlong(points: [CGPoint], fraction: Double) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        guard points.count > 1 else { return points[0] }
        let f = max(0, min(1, fraction))
        let scaled = f * Double(points.count - 1)
        let lower = Int(scaled.rounded(.down))
        let upper = min(points.count - 1, lower + 1)
        let t = scaled - Double(lower)
        let p0 = points[lower]
        let p1 = points[upper]
        return CGPoint(
            x: p0.x + (p1.x - p0.x) * t,
            y: p0.y + (p1.y - p0.y) * t
        )
    }
}

/// SwiftUI Shape that builds a smooth path through the supplied control points
/// using Catmull-Rom-to-Bezier conversion. Produces an organic curve rather
/// than angular line segments.
private struct JourneyPath: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count >= 2 else { return path }
        path.move(to: points[0])

        if points.count == 2 {
            path.addLine(to: points[1])
            return path
        }

        for i in 0..<points.count - 1 {
            let p0 = points[max(0, i - 1)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(points.count - 1, i + 2)]

            let c1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6.0,
                y: p1.y + (p2.y - p0.y) / 6.0
            )
            let c2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6.0,
                y: p2.y - (p3.y - p1.y) / 6.0
            )
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        return path
    }
}

private struct LandmarkStamp: View {
    let landmark: Landmark
    let unlocked: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(unlocked ? Color.brandPrimaryTint : Color.brandSurface)
                .frame(width: 22, height: 22)
            Circle()
                .stroke(
                    unlocked ? Color.brandPrimary : Color.brandDivider,
                    lineWidth: unlocked ? 1.5 : 1
                )
                .frame(width: 22, height: 22)
            Image(systemName: unlocked ? landmark.symbolName : "lock.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(unlocked ? Color.brandPrimary : Color.brandTextTertiary)
        }
        .accessibilityLabel(unlocked ? landmark.name : "Locked landmark")
    }
}

private struct DogMarker: View {
    let photo: Data?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.brandSurfaceElevated)
                .frame(width: 32, height: 32)
            Circle()
                .stroke(Color.brandPrimary, lineWidth: 2)
                .frame(width: 32, height: 32)
            if let photo, let image = UIImage(data: photo) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 26, height: 26)
                    .clipShape(Circle())
            } else {
                Image(systemName: "dog.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brandPrimary)
            }
        }
        .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 1)
        .accessibilityLabel("Your dog's position on the route")
    }
}
