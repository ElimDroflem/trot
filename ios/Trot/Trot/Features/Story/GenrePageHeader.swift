import SwiftUI

/// The header strip at the top of every page card, styled to match the
/// genre's idea of "what a page header in this kind of book looks like."
/// Six variants — one per `StoryGenre.HeaderStyle` — chosen because they
/// each draw on a real visual idiom from that genre's print history:
///
///   - Noir murder mystery: red `EXHIBIT 8` stamp + thin black rule
///   - Folk horror: shaky handwritten "page eight"
///   - Fantasy: ornate "CHAPTER II · FOLIO IV" with a flourish divider
///   - Sci-fi: bracketed terminal slug `[FILE_08 :: 02.3]`
///   - Cosy mystery: italic serif "Page Eight, Chapter Two"
///   - Adventure: "DAY 8 · LEG 3" stamp on a kraft band
///
/// Each variant is a header *strip* — designed to sit above the prose
/// inside a themed book-card. The header colours come from the genre
/// itself (`bookProseColor`, `bookMetaColor`, `accentColor`) so it lives
/// on the card surface, not on cream.
struct GenrePageHeader: View {
    let genre: StoryGenre
    let pageGlobalIndex: Int
    let chapterIndex: Int
    let pageInChapter: Int

    var body: some View {
        switch genre.headerStyle {
        case .noirStamp:        noirStamp
        case .horrorHandwritten: horrorHandwritten
        case .fantasyOrnate:    fantasyOrnate
        case .sciFiBracketed:   sciFiBracketed
        case .cosyItalic:       cosyItalic
        case .adventureStamp:   adventureStamp
        }
    }

    // MARK: - Noir

    private var noirStamp: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("EXHIBIT \(pageGlobalIndex)")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .tracking(2.5)
                    .foregroundStyle(Color(red: 0.85, green: 0.20, blue: 0.20))
                Spacer()
                Text("CH \(chapterIndex) · \(pageInChapter)/5")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(genre.bookMetaColor)
            }
            Rectangle()
                .fill(Color.black.opacity(0.65))
                .frame(height: 1)
        }
    }

    // MARK: - Horror

    private var horrorHandwritten: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("page \(numberToWord(pageGlobalIndex))")
                .font(.system(.caption, design: .serif).weight(.medium))
                .italic()
                .foregroundStyle(genre.bookProseColor)
                .rotationEffect(.degrees(-1.4))
            Spacer()
            Text("ch. \(numberToRoman(chapterIndex))")
                .font(.system(.caption2, design: .serif))
                .italic()
                .foregroundStyle(genre.bookMetaColor)
                .rotationEffect(.degrees(0.8))
        }
        .overlay(alignment: .bottomLeading) {
            // Hand-scratched underline — short and not quite straight.
            Path { path in
                path.move(to: CGPoint(x: 2, y: 14))
                path.addCurve(
                    to: CGPoint(x: 60, y: 16),
                    control1: CGPoint(x: 18, y: 12),
                    control2: CGPoint(x: 38, y: 18)
                )
            }
            .stroke(Color.black.opacity(0.55), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            .frame(height: 18)
            .offset(y: 6)
        }
    }

    // MARK: - Fantasy

    private var fantasyOrnate: some View {
        VStack(spacing: 4) {
            HStack {
                Text("CHAPTER \(numberToRoman(chapterIndex))")
                    .font(.system(.caption, design: .serif).weight(.semibold))
                    .tracking(2.0)
                    .foregroundStyle(genre.bookProseColor)
                Spacer()
                Text("FOLIO \(numberToRoman(pageGlobalIndex))")
                    .font(.system(.caption, design: .serif).weight(.semibold))
                    .tracking(2.0)
                    .foregroundStyle(genre.bookProseColor)
            }
            ornateDivider
        }
    }

    private var ornateDivider: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(genre.accentColor.opacity(0.55))
                .frame(height: 1)
            Image(systemName: "diamond.fill")
                .font(.system(size: 7))
                .foregroundStyle(genre.accentColor)
            Image(systemName: "diamond.fill")
                .font(.system(size: 5))
                .foregroundStyle(genre.accentColor.opacity(0.65))
            Image(systemName: "diamond.fill")
                .font(.system(size: 7))
                .foregroundStyle(genre.accentColor)
            Rectangle()
                .fill(genre.accentColor.opacity(0.55))
                .frame(height: 1)
        }
    }

    // MARK: - Sci-fi

    private var sciFiBracketed: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("[FILE_\(String(format: "%02d", pageGlobalIndex)) :: \(chapterIndex).\(pageInChapter)]")
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .tracking(1.5)
                .foregroundStyle(genre.accentColor)
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(genre.accentColor)
                    .frame(width: 6, height: 6)
                Text("LIVE")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .tracking(1.0)
                    .foregroundStyle(genre.accentColor.opacity(0.85))
            }
        }
    }

    // MARK: - Cosy

    private var cosyItalic: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Page \(numberToWord(pageGlobalIndex).capitalized), Chapter \(numberToWord(chapterIndex).capitalized)")
                .font(.system(.callout, design: .serif).weight(.regular))
                .italic()
                .foregroundStyle(genre.bookProseColor)
            Spacer()
        }
        .overlay(alignment: .bottomLeading) {
            Rectangle()
                .fill(genre.accentColor.opacity(0.45))
                .frame(width: 36, height: 1)
                .offset(y: 6)
        }
    }

    // MARK: - Adventure

    private var adventureStamp: some View {
        HStack(spacing: Space.xs) {
            HStack(spacing: 4) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("DAY \(pageGlobalIndex)")
                    .font(.system(.caption, design: .serif).weight(.heavy))
                    .tracking(1.5)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(genre.bookProseColor.opacity(0.5), lineWidth: 1.5)
            )
            .foregroundStyle(genre.bookProseColor)

            Text("LEG \(chapterIndex)")
                .font(.system(.caption2, design: .serif).weight(.bold))
                .tracking(1.5)
                .foregroundStyle(genre.bookMetaColor)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func numberToWord(_ n: Int) -> String {
        switch n {
        case 1: return "one"
        case 2: return "two"
        case 3: return "three"
        case 4: return "four"
        case 5: return "five"
        case 6: return "six"
        case 7: return "seven"
        case 8: return "eight"
        case 9: return "nine"
        case 10: return "ten"
        case 11: return "eleven"
        case 12: return "twelve"
        case 13: return "thirteen"
        case 14: return "fourteen"
        case 15: return "fifteen"
        default: return "\(n)"
        }
    }

    private func numberToRoman(_ n: Int) -> String {
        let values = [(1000, "M"), (900, "CM"), (500, "D"), (400, "CD"),
                      (100, "C"), (90, "XC"), (50, "L"), (40, "XL"),
                      (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var n = n
        var result = ""
        for (v, s) in values {
            while n >= v { result += s; n -= v }
        }
        return result
    }
}
