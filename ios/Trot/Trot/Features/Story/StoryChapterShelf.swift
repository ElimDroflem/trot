import SwiftUI
import SwiftData

/// Horizontal scroll of completed chapters as themed book-spread cards.
/// Tap a chapter → full-screen reader. Replaces the v1 "Chapters walked"
/// pill list — that read as a settings UI; this reads as a bookshop.
///
/// Each card is the genre's accent gradient with the chapter number in
/// caps, the LLM-generated title in display type, and the closing line as
/// italic body. Visual density matches the genre — noir cards feel
/// printed, fantasy cards feel embossed, sci-fi cards feel terminal.
struct StoryChapterShelf: View {
    let dog: Dog
    let genre: StoryGenre
    let onTap: (StoryChapter) -> Void

    private var closedChapters: [StoryChapter] {
        (dog.story?.chapters ?? [])
            .filter { $0.closedAt != nil }
            .sorted { $0.index < $1.index }
    }

    var body: some View {
        if closedChapters.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("The story so far")
                    .font(.titleSmall)
                    .foregroundStyle(Color.brandTextPrimary)
                    .padding(.horizontal, Space.xs)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.sm) {
                        ForEach(closedChapters, id: \.persistentModelID) { chapter in
                            Button {
                                onTap(chapter)
                            } label: {
                                ChapterSpread(chapter: chapter, genre: genre)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Space.xs)
                }
            }
        }
    }
}

/// One chapter card in the horizontal shelf. Themed book-spread.
private struct ChapterSpread: View {
    let chapter: StoryChapter
    let genre: StoryGenre

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack {
                Text("CHAPTER \(chapter.index)")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Image(systemName: genre.symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }

            Text(chapter.title)
                .font(.titleMedium.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(chapter.closingLine)
                .font(.system(.caption, design: genre.bodyFontDesign))
                .italic()
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Image(systemName: "book.fill")
                    .font(.caption2)
                Text("\(chapter.pages?.count ?? 0) pages")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.white.opacity(0.75))
        }
        .padding(Space.md)
        .frame(width: 240, height: 200, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [genre.primaryColor, genre.midColor.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: genre.primaryColor.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}
