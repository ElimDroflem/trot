import SwiftUI

/// One-shot welcome card the first time the user visits the Story tab.
/// Replaces the genre picker on first visit; the user reads the framing
/// and taps "Begin" to commit; the genre picker takes over.
///
/// Persistence: `UserPreferences.storyIntroSeen`. Once flipped true, this
/// view never re-appears (even if the user wipes their story and starts
/// again — they already know what Story mode is by then).
///
/// Visual brief: warm cream surface, Bricolage Grotesque headline, plain
/// English body, brand-coloured "Begin" CTA. Calm, not loud — celebration
/// volume is reserved for actual milestones, not setup screens.
struct StoryIntroView: View {
    let dogName: String
    var onBegin: () -> Void

    private var resolvedDogName: String {
        let trimmed = dogName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "your dog" : trimmed
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Spacer().frame(height: Space.lg)

                Image(systemName: "book.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Color.brandPrimary)
                    .padding(.bottom, Space.sm)

                Text("\(resolvedDogName) is getting a book.")
                    .font(.displayLarge)
                    .atmosphereTextPrimary()
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: Space.md) {
                    bulletRow(
                        symbol: "pencil.and.outline",
                        title: "One page per walk.",
                        body: "Walk \(resolvedDogName), get a fresh page. Two pages a day at most — the book grows at the pace the dog walks."
                    )
                    bulletRow(
                        symbol: "books.vertical.fill",
                        title: "Six worlds, one dog.",
                        body: "Pick a genre — murder mystery, cosy, fantasy, sci-fi, horror, or adventure. Then pick where the story opens."
                    )
                    bulletRow(
                        symbol: "arrow.triangle.branch",
                        title: "You steer it.",
                        body: "Each page ends with two paths. Pick one and the next page follows your choice."
                    )
                }

                Spacer().frame(height: Space.md)

                Button(action: onBegin) {
                    Text("Begin")
                        .font(.bodyLarge.weight(.semibold))
                        .foregroundStyle(Color.brandTextOnPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.md)
                        .background(Color.brandPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        .shadow(color: Color.brandPrimary.opacity(0.30), radius: 12, y: 6)
                }
                .buttonStyle(.plain)

                Spacer().frame(height: Space.xl)
            }
            .padding(.horizontal, Space.md)
            .padding(.top, Space.md)
        }
    }

    private func bulletRow(symbol: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: Space.md) {
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brandPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.titleSmall.weight(.semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                Text(body)
                    .font(.bodyMedium)
                    .foregroundStyle(Color.brandTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    StoryIntroView(dogName: "Bonnie") { }
        .background(Color.brandSurface)
}
