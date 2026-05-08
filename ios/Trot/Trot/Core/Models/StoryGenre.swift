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
    /// Each entry ends with a one-line "channel <author>" cue so the
    /// LLM has a recognisable voice to model on rather than defaulting
    /// to genre-generic prose. Mimicry is explicitly forbidden — the
    /// author is a *direction*, not a costume.
    var toneInstruction: String {
        switch self {
        case .murderMystery:
            return """
            A grounded village-noir murder mystery. Suspicious neighbours, footprints, smoke, glances held a beat too long. Use understated dread. The dog is your partner — they smell things you don't.
            Channel Agatha Christie's voice: small village, ordinary people, something quietly wrong, clue-by-clue pacing, characters revealed through what they say at tea. Don't mimic, don't pastiche — channel.
            """
        case .horror:
            return """
            Folk-horror with restraint. Long shadows, animals behaving oddly, half-glimpsed shapes at field edges. Never gore — the unease is the point. Some chapters resolve to the dog being the dog (relief, comedy); others stay genuinely uncanny.
            Channel Stephen King's voice: ordinary people in ordinary places, the wrong thing arriving by inches, small specific physical details that snag the eye, dialogue that sounds real. Don't mimic, don't pastiche — channel.
            """
        case .fantasy:
            return """
            Grounded fantasy in a recognisable British countryside. Hedgerow magic, prophecies in pub gardens, talking foxes who know things. The dog has a destiny — they take it more seriously than they should.
            Channel George RR Martin's voice: character-led, no high-fantasy bombast, magic treated as politics, weather and food and exhaustion noted alongside wonder, point-of-view tight to one head. Don't mimic, don't pastiche — channel.
            """
        case .sciFi:
            return """
            Quiet British sci-fi. Inexplicable signals, government men in cars, things in the sky that shouldn't be there. Deadpan delivery. Dog is unbothered by alien tech, intensely bothered by squirrels.
            Channel Frank Herbert's voice (Dune): omen-and-signal pacing, dry ominous interiority, a sense of vast forces noticed by small people, sentences that mean two things at once. Don't mimic, don't pastiche — channel.
            """
        case .cosyMystery:
            return """
            Warm village-cosy mystery: WI meetings, gardens, fêtes. Stakes are low — a missing trophy, a poisoned tart, a feud over hedges. The dog is everyone's favourite suspect and witness.
            Channel Richard Osman's voice (Thursday Murder Club): chatty, dry, fond of its characters, gentle irony, jokes that earn their place, pace driven by curiosity rather than threat. Don't mimic, don't pastiche — channel.
            """
        case .adventure:
            return """
            Outdoor adventure across UK landscapes. Hills, weather, distance. Earned by walking. Dog is the engine — pulls when interested, sits when bored, finds the path.
            Channel Robert Macfarlane's voice: precise nouns for weather and stone and bird, a literary attention to landscape, history half-buried in placenames, the body's experience of distance. Don't mimic, don't pastiche — channel.
            """
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

    // MARK: - Card chrome

    /// Background colour for the page card / spine card / chapter shelf
    /// card. Replaces `Color.brandSurfaceElevated` on every Story-tab
    /// surface so the genre lives *on the cards*, not just behind them.
    var bookSurface: Color {
        switch self {
        case .murderMystery:
            return Color(red: 0.96, green: 0.93, blue: 0.85)   // aged paper cream
        case .horror:
            return Color(red: 0.92, green: 0.88, blue: 0.82)   // dim parchment
        case .fantasy:
            return Color(red: 0.98, green: 0.94, blue: 0.84)   // warm vellum
        case .sciFi:
            return Color(red: 0.06, green: 0.10, blue: 0.18)   // near-black terminal
        case .cosyMystery:
            return Color(red: 0.97, green: 0.94, blue: 0.88)   // tea-cream
        case .adventure:
            return Color(red: 0.96, green: 0.92, blue: 0.85)   // field-guide kraft
        }
    }

    /// Border stroke colour applied to every story card. Stronger than
    /// the daytime hairline because each card now visually IS the genre.
    var bookBorder: Color {
        switch self {
        case .murderMystery: return Color(red: 0.42, green: 0.10, blue: 0.10).opacity(0.55)   // dried-blood red
        case .horror:        return Color(red: 0.18, green: 0.10, blue: 0.10).opacity(0.50)   // soot
        case .fantasy:       return Color(red: 0.78, green: 0.62, blue: 0.20).opacity(0.55)   // gold leaf
        case .sciFi:         return Color(red: 0.30, green: 0.95, blue: 0.92).opacity(0.55)   // neon cyan
        case .cosyMystery:   return Color(red: 0.40, green: 0.62, blue: 0.40).opacity(0.45)   // sage
        case .adventure:     return Color(red: 0.50, green: 0.32, blue: 0.18).opacity(0.55)   // chestnut
        }
    }

    /// Default text colour for prose rendered on the book card. Mostly
    /// dark ink but sci-fi flips to terminal cyan because the card is
    /// near-black.
    var bookProseColor: Color {
        switch self {
        case .murderMystery: return Color(red: 0.16, green: 0.10, blue: 0.06)
        case .horror:        return Color(red: 0.18, green: 0.12, blue: 0.10)
        case .fantasy:       return Color(red: 0.30, green: 0.14, blue: 0.06)
        case .sciFi:         return Color(red: 0.62, green: 0.95, blue: 0.92)   // terminal cyan
        case .cosyMystery:   return Color(red: 0.30, green: 0.18, blue: 0.10)
        case .adventure:     return Color(red: 0.20, green: 0.15, blue: 0.08)
        }
    }

    /// Secondary text on the book card (page number, metadata). Lower-
    /// emphasis variant of `bookProseColor`.
    var bookMetaColor: Color {
        switch self {
        case .murderMystery: return Color(red: 0.42, green: 0.10, blue: 0.10)
        case .horror:        return Color(red: 0.55, green: 0.18, blue: 0.18)
        case .fantasy:       return Color(red: 0.62, green: 0.45, blue: 0.10)
        case .sciFi:         return Color(red: 0.30, green: 0.95, blue: 0.92).opacity(0.85)
        case .cosyMystery:   return Color(red: 0.40, green: 0.62, blue: 0.40)
        case .adventure:     return Color(red: 0.50, green: 0.32, blue: 0.18)
        }
    }

    // MARK: - Header style

    /// Per-genre layout for the page header (page number / chapter
    /// metadata) shown above the prose. Each style is rendered by
    /// `GenrePageHeader` — see that view for the visual specs.
    enum HeaderStyle {
        case noirStamp        // EXHIBIT 8 (red, monospace caps + thin black rule)
        case horrorHandwritten // shaky "page eight" + scratch
        case fantasyOrnate     // CHAPTER II · FOLIO IV with ornate divider
        case sciFiBracketed    // [FILE_08 :: 02.3]
        case cosyItalic        // Page Eight, Chapter Two (italic serif)
        case adventureStamp    // DAY 8 · LEG 3 (kraft-stamped feel)
    }

    var headerStyle: HeaderStyle {
        switch self {
        case .murderMystery: return .noirStamp
        case .horror:        return .horrorHandwritten
        case .fantasy:       return .fantasyOrnate
        case .sciFi:         return .sciFiBracketed
        case .cosyMystery:   return .cosyItalic
        case .adventure:     return .adventureStamp
        }
    }

    // MARK: - Prose treatment

    /// Whether the prose should render with an illuminated drop cap on
    /// the first letter. Fantasy + cosy get this — both lean book-feel.
    var hasDropCap: Bool {
        switch self {
        case .fantasy, .cosyMystery: return true
        default:                     return false
        }
    }

    /// Whether the prose should be rendered in terminal style — `> ` at
    /// the start of each paragraph and a blinking cursor block at the
    /// end. Sci-fi only.
    var hasTerminalProse: Bool { self == .sciFi }

    // MARK: - Full-screen overlay

    /// Identifies which full-screen overlay layer renders on top of the
    /// atmosphere (between the atmosphere and the cards). Adds film grain
    /// or scanlines or a vignette — subtle but pervasive.
    enum OverlayKind {
        case filmGrain     // murder mystery
        case vignette      // horror
        case parchment     // fantasy
        case scanlines     // sci-fi
        case warmGlow      // cosy
        case kraftFiber    // adventure
    }

    var overlayKind: OverlayKind {
        switch self {
        case .murderMystery: return .filmGrain
        case .horror:        return .vignette
        case .fantasy:       return .parchment
        case .sciFi:         return .scanlines
        case .cosyMystery:   return .warmGlow
        case .adventure:     return .kraftFiber
        }
    }
}
