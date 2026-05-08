import SwiftUI

/// Renders the page's prose with the right *typographic ritual* for the
/// genre — not just font choice, but how the first letter is dressed,
/// whether each paragraph is prefixed, and what's printed after the last
/// word. Sits inside the page card, between header and footer.
///
/// Three flavours, picked from `StoryGenre`:
///   1. `hasDropCap` (fantasy, cosy mystery) — first letter rendered as
///      a 3-line drop cap in the genre's accent colour.
///   2. `hasTerminalProse` (sci-fi) — every paragraph prefixed with `> `,
///      a blinking cursor block follows the final character.
///   3. Default — straight serif/monospaced body in the genre's prose
///      colour, no extra ritual.
///
/// `lineLimit` clamps the visible prose to a preview height; the rest is
/// reserved for the full-screen reader. The page card on the Story tab
/// uses ~4 lines so it stays compact and the choices/decisions footer
/// stays close to the fold; the full reader passes `nil` to show
/// everything.
struct GenreProseView: View {
    let genre: StoryGenre
    let prose: String
    /// Maximum number of prose lines to render. `nil` = full prose.
    /// Used by the page card on the live Story tab to keep the height
    /// short — the user reaches the full prose by tapping "Read more".
    var lineLimit: Int? = nil

    var body: some View {
        if genre.hasTerminalProse {
            TerminalProse(genre: genre, prose: prose, lineLimit: lineLimit)
        } else if genre.hasDropCap {
            DropCapProse(genre: genre, prose: prose, lineLimit: lineLimit)
        } else {
            PlainProse(genre: genre, prose: prose, lineLimit: lineLimit)
        }
    }
}

// MARK: - Plain

private struct PlainProse: View {
    let genre: StoryGenre
    let prose: String
    let lineLimit: Int?

    var body: some View {
        Text(prose)
            .font(.system(.body, design: genre.bodyFontDesign))
            .foregroundStyle(genre.bookProseColor)
            .lineSpacing(4)
            .lineLimit(lineLimit)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            // `fixedSize(vertical: true)` only when we WANT the prose to
            // expand to its natural height. With a `lineLimit` clamp we
            // need SwiftUI free to truncate, so it's omitted.
            .modifier(VerticalFixedIfUnclamped(active: lineLimit == nil))
    }
}

// MARK: - Drop cap (fantasy + cosy)

private struct DropCapProse: View {
    let genre: StoryGenre
    let prose: String
    let lineLimit: Int?

    var body: some View {
        let trimmed = prose.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = trimmed.first {
            let rest = String(trimmed.dropFirst())
            HStack(alignment: .top, spacing: 6) {
                Text(String(first))
                    .font(.system(size: 56, weight: .bold, design: .serif))
                    .foregroundStyle(genre.accentColor)
                    .baselineOffset(-8)
                    .padding(.trailing, 2)
                Text(rest)
                    .font(.system(.body, design: genre.bodyFontDesign))
                    .foregroundStyle(genre.bookProseColor)
                    .lineSpacing(4)
                    .lineLimit(lineLimit)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(VerticalFixedIfUnclamped(active: lineLimit == nil))
            }
        } else {
            PlainProse(genre: genre, prose: prose, lineLimit: lineLimit)
        }
    }
}

// MARK: - Terminal (sci-fi)

private struct TerminalProse: View {
    let genre: StoryGenre
    let prose: String
    let lineLimit: Int?

    @State private var cursorOn = true

    var body: some View {
        let allParagraphs = prose
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        // In preview mode, only the first paragraph renders — multi-
        // paragraph terminal output blows up the card otherwise — and
        // we suppress the blinking cursor (it implies "this is where
        // input is", which would confuse a teaser).
        let paragraphs = lineLimit != nil ? Array(allParagraphs.prefix(1)) : allParagraphs
        let isPreview = lineLimit != nil
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                HStack(alignment: .top, spacing: 6) {
                    Text(">")
                        .font(.system(.body, design: .monospaced).weight(.bold))
                        .foregroundStyle(genre.accentColor)
                    if !isPreview && index == paragraphs.count - 1 {
                        // Last paragraph gets the blinking cursor block
                        // appended inline. AttributedString avoids the
                        // iOS-26-deprecated `Text + Text` concatenation
                        // while keeping the cursor on the same line as
                        // the final character.
                        Text(terminalAttributedString(for: paragraph))
                            .font(.system(.body, design: .monospaced))
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(paragraph)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(genre.bookProseColor)
                            .lineSpacing(3)
                            .lineLimit(lineLimit)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .modifier(VerticalFixedIfUnclamped(active: lineLimit == nil))
                    }
                }
            }
        }
        .onAppear {
            if !isPreview { startBlink() }
        }
    }

    private func terminalAttributedString(for paragraph: String) -> AttributedString {
        var prose = AttributedString(paragraph)
        prose.foregroundColor = genre.bookProseColor
        var cursor = AttributedString(cursorOn ? " ▌" : "  ")
        cursor.foregroundColor = genre.accentColor
        prose.append(cursor)
        return prose
    }

    private func startBlink() {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 520_000_000)
                cursorOn.toggle()
            }
        }
    }
}

/// Applies `fixedSize(horizontal: false, vertical: true)` only when the
/// prose has no line clamp — without the clamp we want the text view
/// to grow to its natural height; with a clamp we need SwiftUI free to
/// truncate, which fixedSize prevents.
private struct VerticalFixedIfUnclamped: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content.fixedSize(horizontal: false, vertical: true)
        } else {
            content
        }
    }
}
