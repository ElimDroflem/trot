import SwiftUI

/// Full-screen takeover when a chapter just closed. Genre-themed
/// background, the chapter title in display type, the closing line in
/// italic body, and a "begin next chapter" button. Marks the chapter
/// seen on dismiss so the overlay never re-appears for the same close.
struct StoryChapterCloseOverlay: View {
    let chapter: StoryChapter
    let genre: StoryGenre
    let onDismiss: () -> Void

    @State private var titleOpacity: Double = 0
    @State private var closingOpacity: Double = 0
    @State private var ctaOpacity: Double = 0

    var body: some View {
        ZStack {
            // Saturated genre background — this is a celebration moment;
            // it should look distinctly different from the in-progress
            // Story tab so the user feels the chapter break.
            LinearGradient(
                colors: [genre.primaryColor, genre.midColor.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Drifting motif behind the title — same idea as the
            // GenreAtmosphereLayer's particle layer but anchored to the
            // overlay's coordinate system.
            GenreAtmosphereLayer(genre: genre)
                .opacity(0.65)

            VStack(spacing: Space.lg) {
                Spacer()

                VStack(spacing: 4) {
                    Image(systemName: genre.symbol)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(genre.accentColor)
                    Text("CHAPTER \(chapter.index)")
                        .font(.caption.weight(.semibold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("CLOSED")
                        .font(.caption2.weight(.semibold))
                        .tracking(0.5)
                        .foregroundStyle(.white.opacity(0.55))
                }

                Text(chapter.title)
                    .font(.displayLarge)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.lg)
                    .opacity(titleOpacity)

                Text(chapter.closingLine)
                    .font(.system(.title3, design: genre.bodyFontDesign))
                    .italic()
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.lg)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(closingOpacity)

                Spacer()

                Button(action: onDismiss) {
                    Text("Begin chapter \(chapter.index + 1)")
                        .font(.bodyLarge.weight(.semibold))
                        .foregroundStyle(genre.primaryColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.md)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Space.lg)
                .padding(.bottom, Space.xl)
                .opacity(ctaOpacity)
            }
        }
        .onAppear {
            withAnimation(.brandCelebration.delay(0.10)) { titleOpacity = 1 }
            withAnimation(.brandDefault.delay(0.45)) { closingOpacity = 1 }
            withAnimation(.brandDefault.delay(0.80)) { ctaOpacity = 1 }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
