import SwiftUI

/// The genre a user picks for their dog's story when they first open the
/// Story tab. Locked per dog — switching would break LLM continuity and
/// cheapen the universe.
///
/// Each genre carries its own tone hints (sent to the LLM), palette
/// (drives the GenreAtmosphereLayer + page chrome), motif name (decorative
/// element rendered behind the prose), and body-font choice (book feel —
/// monospace for noir/sci-fi, serif for fantasy/horror/cosy/adventure).
///
/// The user-facing copy is deliberately pulpy — the picker should feel
/// like opening a book in a charity-shop window, not configuring a setting.
enum StoryGenre: String, Codable, CaseIterable, Sendable, Identifiable {
    case murderMystery
    case horror
    case fantasy
    case sciFi
    case cosyMystery
    case adventure

    var id: String { rawValue }

    /// Display name shown on the picker card and chapter title slugs.
    var displayName: String {
        switch self {
        case .murderMystery: return "Murder Mystery"
        case .horror:        return "Horror"
        case .fantasy:       return "Fantasy"
        case .sciFi:         return "Sci-Fi"
        case .cosyMystery:   return "Cosy Mystery"
        case .adventure:     return "Adventure"
        }
    }

    /// One-line tease shown beneath each picker card. Pulpy and specific —
    /// "There's an old prophecy. The dog is in it."
    var tease: String {
        switch self {
        case .murderMystery: return "There's been a thing at the village hall. Time to investigate."
        case .horror:        return "Something is wrong in the woods. Probably."
        case .fantasy:       return "There's an old prophecy. The dog is in it."
        case .sciFi:         return "The signal came from the park. You should not have answered."
        case .cosyMystery:   return "Tea. Biscuits. A missing garden gnome. Get to it."
        case .adventure:     return "There's something in the hills. Let's go and see."
        }
    }

    /// Sent to the LLM in the system prompt. Establishes the universe
    /// without letting the model break the fourth wall or get parodic.
    var toneInstruction: String {
        switch self {
        case .murderMystery:
            return "A grounded village-noir murder mystery. Suspicious neighbours, footprints, smoke, glances held a beat too long. Use understated dread. The dog is your partner — they smell things you don't."
        case .horror:
            return "Folk-horror with restraint. Long shadows, animals behaving oddly, half-glimpsed shapes at field edges. Never gore — the unease is the point. Some chapters resolve to the dog being the dog (relief, comedy); others stay genuinely uncanny."
        case .fantasy:
            return "Soft high-fantasy in a recognisable British countryside. Hedgerow magic, prophecies in pub gardens, talking foxes who know things. The dog has a destiny — they take it more seriously than they should."
        case .sciFi:
            return "Quiet British sci-fi. Inexplicable signals, government men in cars, things in the sky that shouldn't be there. Deadpan delivery. Dog is unbothered by alien tech, intensely bothered by squirrels."
        case .cosyMystery:
            return "Warm village-cosy mystery: WI meetings, gardens, fêtes. Stakes are low — a missing trophy, a poisoned tart, a feud over hedges. The dog is everyone's favourite suspect and witness."
        case .adventure:
            return "Outdoor adventure across UK landscapes. Hills, weather, distance. Earned by walking. Dog is the engine — pulls when interested, sits when bored, finds the path."
        }
    }

    /// Top-of-screen primary brand colour for this genre. Used by the
    /// atmosphere layer's gradient top stop and any genre badges.
    var primaryColor: Color {
        switch self {
        case .murderMystery: return Color(red: 0.18, green: 0.20, blue: 0.24)   // noir charcoal
        case .horror:        return Color(red: 0.20, green: 0.22, blue: 0.30)   // deep slate-blue
        case .fantasy:       return Color(red: 0.42, green: 0.20, blue: 0.50)   // royal plum
        case .sciFi:         return Color(red: 0.08, green: 0.18, blue: 0.40)   // midnight blue
        case .cosyMystery:   return Color(red: 0.62, green: 0.42, blue: 0.32)   // warm tea
        case .adventure:     return Color(red: 0.20, green: 0.36, blue: 0.28)   // forest green
        }
    }

    /// Mid-band colour — used in the gradient between top and brand surface.
    var midColor: Color {
        switch self {
        case .murderMystery: return Color(red: 0.50, green: 0.48, blue: 0.46)
        case .horror:        return Color(red: 0.42, green: 0.36, blue: 0.42)
        case .fantasy:       return Color(red: 0.78, green: 0.60, blue: 0.84)
        case .sciFi:         return Color(red: 0.30, green: 0.62, blue: 0.92)
        case .cosyMystery:   return Color(red: 0.92, green: 0.78, blue: 0.62)
        case .adventure:     return Color(red: 0.62, green: 0.78, blue: 0.50)
        }
    }

    /// Accent — used for chapter-title underlines, motifs, and key marks.
    var accentColor: Color {
        switch self {
        case .murderMystery: return Color(red: 0.85, green: 0.30, blue: 0.30)   // typewriter red
        case .horror:        return Color(red: 0.85, green: 0.20, blue: 0.20)   // blood red
        case .fantasy:       return Color(red: 0.95, green: 0.80, blue: 0.30)   // gold
        case .sciFi:         return Color(red: 0.30, green: 0.95, blue: 0.92)   // neon cyan
        case .cosyMystery:   return Color(red: 0.40, green: 0.62, blue: 0.40)   // sage
        case .adventure:     return Color(red: 0.95, green: 0.65, blue: 0.20)   // amber sun
        }
    }

    /// Body-font design for the prose in this genre. Returns a SwiftUI
    /// `Font.Design` so a single `.bodyLarge.serif()` style flows from here.
    var bodyFontDesign: Font.Design {
        switch self {
        case .murderMystery: return .monospaced   // typewriter feel
        case .horror:        return .serif         // antique book
        case .fantasy:       return .serif         // old leather
        case .sciFi:         return .monospaced    // terminal
        case .cosyMystery:   return .serif         // tea-stained paper
        case .adventure:     return .serif         // adventure novel
        }
    }

    /// SF Symbol used for the picker card icon and chapter shelf badge.
    var symbol: String {
        switch self {
        case .murderMystery: return "magnifyingglass"
        case .horror:        return "moon.haze.fill"
        case .fantasy:       return "wand.and.stars"
        case .sciFi:         return "antenna.radiowaves.left.and.right"
        case .cosyMystery:   return "cup.and.saucer.fill"
        case .adventure:     return "mountain.2.fill"
        }
    }
}
