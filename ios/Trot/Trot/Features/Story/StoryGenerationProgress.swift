import SwiftUI

/// Shown for the few seconds between "user tapped Begin <Genre>" and
/// "the prologue page has been persisted by `StoryService`." The picker
/// gets removed from the hierarchy immediately on tap; this view replaces
/// it so the press feels alive instead of frozen.
///
/// The atmosphere/overlay layers are already painting the chosen genre
/// behind us (see `StoryView.body` — `pendingGenrePick` overrides the
/// genre source while we're here). All we need to render is a calm
/// status block with the genre's symbol and one line of "what's
/// happening" copy in the genre's voice.
struct StoryGenerationProgress: View {
    let genre: StoryGenre

    var body: some View {
        VStack(spacing: Space.lg) {
            Spacer(minLength: 0)

            // Genre badge — same shape as the picker so the transition
            // reads as the picked card growing into a cover.
            ZStack {
                Circle()
                    .fill(genre.accentColor.opacity(0.20))
                    .frame(width: 72, height: 72)
                Image(systemName: genre.symbol)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(genre.accentColor)
            }

            VStack(spacing: Space.xs) {
                Text(genre.displayName.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(2.0)
                    .atmosphereTextSecondary()
                Text(headline)
                    .font(.displayMedium)
                    .multilineTextAlignment(.center)
                    .atmosphereTextPrimary()
                    .padding(.horizontal, Space.lg)
                Text(subline)
                    .font(.bodyMedium)
                    .multilineTextAlignment(.center)
                    .atmosphereTextSecondary()
                    .padding(.horizontal, Space.xl)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ProgressView()
                .progressViewStyle(.circular)
                .tint(genre.accentColor)
                .scaleEffect(1.2)
                .padding(.top, Space.sm)

            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Genre-flavoured progress copy. Each line is one sentence in the
    /// voice of the book the user just chose, so the wait *feels* like
    /// part of the story rather than a loading screen.
    private var headline: String {
        switch genre {
        case .murderMystery: return "Setting the scene…"
        case .horror:        return "Listening for it…"
        case .fantasy:       return "Opening the book…"
        case .sciFi:         return "Booting the signal…"
        case .cosyMystery:   return "Putting the kettle on…"
        case .adventure:     return "Unfolding the map…"
        }
    }

    private var subline: String {
        switch genre {
        case .murderMystery: return "The first page is being typed up. Won't be a minute."
        case .horror:        return "The first page is finding its words."
        case .fantasy:       return "The first page is being inked."
        case .sciFi:         return "The first page is decoding."
        case .cosyMystery:   return "The first page is settling in."
        case .adventure:     return "The first page is being marked out."
        }
    }
}
