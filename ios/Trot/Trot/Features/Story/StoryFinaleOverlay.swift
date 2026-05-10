import SwiftUI

/// Full-screen takeover when a book has just finished — the chapter-5
/// close path. Bigger than `StoryChapterCloseOverlay` because it's the
/// end of a book, not a chapter break. Genre-saturated background, the
/// book title in display type, the closing line in italic, a stats line
/// (chapter/page/walk count), and two buttons: re-read or start the next
/// book.
///
/// Dismissed via `onClose`. After dismiss, the book is no longer the
/// active story (`dog.story == nil`); the Story tab returns to the
/// `noStory` branch and the genre picker takes over for picking the
/// next book.
struct StoryFinaleOverlay: View {
    let story: Story
    let dog: Dog
    var onReadAll: () -> Void
    var onStartNew: () -> Void

    @State private var titleOpacity: Double = 0
    @State private var statsOpacity: Double = 0
    @State private var closingOpacity: Double = 0
    @State private var ctaOpacity: Double = 0

    private var genre: StoryGenre { story.genre }

    private var pages: [StoryPage] {
        (story.chapters ?? [])
            .sorted { $0.index < $1.index }
            .flatMap { $0.orderedPages }
    }

    private var statsLine: String {
        let chapters = story.chapters?.count ?? 0
        let pageCount = pages.count
        let walks = (dog.walks ?? []).count
        return "\(chapters) chapters · \(pageCount) pages · \(walks) walks"
    }

    var body: some View {
        ZStack {
            // Saturated genre background — same recipe as the chapter-
            // close overlay so the visual lineage reads, just held a
            // beat longer.
            LinearGradient(
                colors: [genre.primaryColor, genre.midColor.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GenreAtmosphereLayer(genre: genre)
                .opacity(0.65)

            VStack(spacing: Space.lg) {
                Spacer()

                VStack(spacing: 4) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(genre.accentColor)
                    Text("BOOK")
                        .font(.caption.weight(.semibold))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("FINISHED")
                        .font(.caption2.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.55))
                }

                Text(story.title)
                    .font(.displayLarge)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.lg)
                    .opacity(titleOpacity)

                Text(statsLine)
                    .font(.caption.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.75))
                    .opacity(statsOpacity)

                Text(story.closingLine)
                    .font(.system(.title3, design: genre.bodyFontDesign))
                    .italic()
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.lg)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(closingOpacity)

                Spacer()

                VStack(spacing: Space.sm) {
                    Button(action: onReadAll) {
                        Text("Read it all")
                            .font(.bodyLarge.weight(.semibold))
                            .foregroundStyle(genre.primaryColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Space.md)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }
                    .buttonStyle(.plain)

                    Button(action: onStartNew) {
                        Text("Start a new story")
                            .font(.bodyMedium.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Space.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.md)
                                    .stroke(.white.opacity(0.55), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Space.lg)
                .padding(.bottom, Space.xl)
                .opacity(ctaOpacity)
            }
        }
        .onAppear {
            withAnimation(.brandCelebration.delay(0.10)) { titleOpacity = 1 }
            withAnimation(.brandDefault.delay(0.45)) { statsOpacity = 1 }
            withAnimation(.brandDefault.delay(0.65)) { closingOpacity = 1 }
            withAnimation(.brandDefault.delay(0.95)) { ctaOpacity = 1 }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
