import CoreGraphics
import Foundation

/// Bundled route — immutable reference data loaded once from `Routes.json`.
///
/// Routes are measured in **minutes of walking together**, not km. The geography
/// (route name, landmark names, route subtitle) stays as flavor — but the unit
/// of progression is time. This is honest given that the app collects only the
/// `durationMinutes` of each walk and never measures real distance, and it
/// matches the dog-welfare frame: a 60-minute slow walk and a 30-minute brisk
/// walk are not equivalent for the dog, even if they cover the same km.
///
/// Lengths are calibrated at a canonical 5 km/h pace (12 min/km) so the route
/// names remain anchored to a real-world distance — "London to Brighton ≈ 16
/// hours of walking together" — without ever displaying or computing km.
struct Route: Decodable, Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let theme: RouteTheme
    let totalMinutes: Int
    let landmarks: [Landmark]
    let pathPoints: [RoutePoint]

    /// Final landmark (typically the route's destination). Nil for an empty route.
    var finalLandmark: Landmark? { landmarks.last }
}

struct Landmark: Decodable, Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let description: String
    let minutesFromStart: Int
    let symbolName: String
}

/// Normalised 0-1 control point for the SwiftUI Path that draws a route.
/// Decoded from `{"x": Double, "y": Double}` JSON, exposed as a `CGPoint` to
/// the rendering code.
struct RoutePoint: Decodable, Sendable, Hashable {
    let x: Double
    let y: Double

    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

/// Per-route colour palette key. The view layer maps this to brand colours.
enum RouteTheme: String, Decodable, Sendable, Hashable {
    case townLane    // starter: warm coral/cream
    case coastal     // London-Brighton: blues + cream
    case roman       // Hadrian's Wall: stone greys + ochre
    case downs       // South Downs: greens + chalk
}

/// Top-level shape of `Routes.json`.
struct RoutesFile: Decodable, Sendable {
    let routes: [Route]
}
