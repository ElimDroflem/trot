import Foundation

/// A "season" of the user-and-dog relationship. The app calls these `Route` in
/// type names (legacy), but every user-facing string says **season** — the
/// arc the user and dog are walking together right now. Each contains a series
/// of **Moments** (still typed `Landmark` for legacy reasons, displayed as
/// "Moment") that unlock as accumulated walking minutes pass their threshold.
///
/// Bond-framing: titles describe accumulated time and observations of the
/// relationship, never "first ever" (which would patronise users with older
/// dogs) and never the app as narrator. The LLM-generated diary entry on
/// each unlock carries the emotional payload — a short dog-voice line about
/// the user, written specifically for that user and dog.
///
/// Lengths are in MINUTES of walking together. Calibrated against a ~5 km/h
/// canonical pace (so the four seasons total roughly the time it takes to
/// walk all four real-world routes the type names came from), but km is never
/// displayed or computed.
struct Route: Decodable, Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let theme: RouteTheme
    let totalMinutes: Int
    let landmarks: [Landmark]

    /// Final Moment of the season (typically the season-completion celebration).
    /// Nil for an empty season.
    var finalLandmark: Landmark? { landmarks.last }
}

struct Landmark: Decodable, Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let description: String
    let minutesFromStart: Int
    let symbolName: String
}

/// Per-season colour palette key. The view layer maps this to brand colours.
enum RouteTheme: String, Decodable, Sendable, Hashable {
    case townLane    // first walks together: warm coral/cream
    case coastal     // finding your rhythm: blues + cream
    case roman       // rituals: stone greys + ochre
    case downs       // the long road: greens + chalk
}

/// Top-level shape of `Routes.json`.
struct RoutesFile: Decodable, Sendable {
    let routes: [Route]
}
