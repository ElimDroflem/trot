import CoreGraphics
import Foundation

/// Bundled route — immutable reference data loaded once from `Routes.json`.
struct Route: Decodable, Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let theme: RouteTheme
    let totalKm: Double
    let landmarks: [Landmark]
    let pathPoints: [RoutePoint]

    /// Final landmark (typically the route's destination). Nil for an empty route.
    var finalLandmark: Landmark? { landmarks.last }
}

struct Landmark: Decodable, Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let description: String
    let kmFromStart: Double
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
