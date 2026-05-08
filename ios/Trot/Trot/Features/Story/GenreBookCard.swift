import SwiftUI

/// View modifier that paints any container with the genre's *book chrome*
/// — surface colour, border, corner ornament, shadow. Replaces the
/// generic `Color.brandSurfaceElevated` + `RoundedRectangle` + hairline
/// pattern used elsewhere on the Story tab.
///
/// The shadow tint is the genre's primary colour so e.g. fantasy plum
/// cards bleed a soft violet shadow instead of grey, which sells the
/// "this card lives in this genre" feeling. Sci-fi gets a teal-cyan
/// shadow against its near-black surface.
///
/// Two presentation styles are exposed:
///   - `.page` (default) — full padding, full shadow, used for the page
///     card and the chapter shelf cards.
///   - `.compact` — smaller corner radius, lighter shadow, used for
///     subordinate cards (footer panels, choice lists).
struct GenreBookCard: ViewModifier {
    enum Style {
        case page
        case compact
    }

    let genre: StoryGenre
    let style: Style

    func body(content: Content) -> some View {
        let radius = cornerRadius
        content
            .padding(padding)
            .background(genre.bookSurface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(genre.bookBorder, lineWidth: borderWidth)
            )
            .overlay(alignment: .topLeading) {
                if style == .page {
                    GenreCornerOrnament(genre: genre)
                        .padding(8)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if style == .page {
                    GenreCornerOrnament(genre: genre)
                        .rotationEffect(.degrees(180))
                        .padding(8)
                }
            }
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowOffset
            )
    }

    private var padding: CGFloat {
        switch style {
        case .page:    return Space.md
        case .compact: return Space.md
        }
    }

    private var cornerRadius: CGFloat {
        switch style {
        case .page:    return Radius.lg
        case .compact: return Radius.md
        }
    }

    private var borderWidth: CGFloat {
        switch style {
        case .page:    return 1.5
        case .compact: return 1.0
        }
    }

    private var shadowColor: Color {
        switch style {
        case .page:    return genre.primaryColor.opacity(0.22)
        case .compact: return genre.primaryColor.opacity(0.12)
        }
    }

    private var shadowRadius: CGFloat {
        switch style {
        case .page:    return 14
        case .compact: return 6
        }
    }

    private var shadowOffset: CGFloat {
        switch style {
        case .page:    return 6
        case .compact: return 3
        }
    }
}

extension View {
    /// Apply the genre's book-card chrome (surface, border, ornament,
    /// shadow) to a container.
    func genreBookCard(_ genre: StoryGenre, style: GenreBookCard.Style = .page) -> some View {
        modifier(GenreBookCard(genre: genre, style: style))
    }
}

/// Tiny corner ornament shown at top-left and bottom-right of every page
/// card. Its shape varies per genre so the card silhouette itself reads
/// as a particular kind of book — magnifier in noir, pentagram-like in
/// horror, fleur-de-lis spike in fantasy, terminal-corner bracket in
/// sci-fi, leaf in cosy, compass arrow in adventure.
private struct GenreCornerOrnament: View {
    let genre: StoryGenre

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(genre.bookBorder.opacity(0.85))
    }

    private var symbol: String {
        switch genre {
        case .murderMystery: return "magnifyingglass"
        case .horror:        return "asterisk"
        case .fantasy:       return "fleuron"          // ❧ glyph
        case .sciFi:         return "chevron.left.forwardslash.chevron.right"
        case .cosyMystery:   return "leaf.fill"
        case .adventure:     return "location.north.line.fill"
        }
    }
}
