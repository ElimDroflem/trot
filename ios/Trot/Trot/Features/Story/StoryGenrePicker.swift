import SwiftUI

/// First impression of the Story tab. Shown only until the user picks a
/// genre — after that, it never returns (genre is locked per dog).
///
/// **Design intent:** the picker is a calm shelf. All six cards share the
/// same cream surface, the same hairline border, the same body font.
/// The only per-genre signal on each card is a small accent-coloured
/// icon. The full book treatment — themed surfaces, drop caps, scanlines,
/// ornate dividers — only appears AFTER the user has picked, so the
/// reveal feels like opening the book rather than walking through a
/// showroom of every binding at once. (Earlier iteration painted every
/// card with its own surface/border/font; that read as "mish-mash". This
/// version trades that loudness for anticipation.)
struct StoryGenrePicker: View {
    /// Two-way binding so the parent (`StoryView`) can observe the
    /// currently-highlighted card and crossfade the atmosphere layer
    /// behind the picker. Highlighting a card is *preview*; picking a
    /// genre is committed by tapping "Begin <Genre>" at the bottom.
    @Binding var selected: StoryGenre?
    let onPick: (StoryGenre) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                header

                VStack(spacing: Space.sm) {
                    ForEach(StoryGenre.allCases) { genre in
                        genreCard(for: genre)
                    }
                }
                .padding(.horizontal, Space.md)

                if let selected {
                    Button(action: { onPick(selected) }) {
                        HStack(spacing: Space.xs) {
                            Image(systemName: selected.symbol)
                                .font(.system(size: 16, weight: .semibold))
                            Text("Begin \(selected.displayName)")
                                .font(.bodyLarge.weight(.semibold))
                        }
                        .foregroundStyle(Color.brandTextOnPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.md)
                        .background(selected.primaryColor)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        .shadow(color: selected.primaryColor.opacity(0.35), radius: 12, y: 6)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Space.md)
                    .padding(.top, Space.sm)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Color.clear.frame(height: Space.xl)
            }
            .padding(.top, Space.md)
        }
    }

    private var header: some View {
        VStack(spacing: Space.xs) {
            Text("Pick a story.")
                .font(.displayLarge)
                .atmosphereTextPrimary()
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Six worlds. Same dog. The book grows by a page each walk.")
                .font(.bodyMedium)
                .atmosphereTextSecondary()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Space.md)
    }

    @ViewBuilder
    private func genreCard(for genre: StoryGenre) -> some View {
        let isSelected = selected == genre
        Button {
            // Animate the highlight + the atmosphere swap together so
            // the bloom feels like a single gesture.
            withAnimation(.brandDefault) { selected = genre }
        } label: {
            HStack(alignment: .center, spacing: Space.md) {
                ZStack {
                    Circle()
                        .fill(genre.accentColor.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: genre.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(genre.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(genre.displayName)
                        .font(.titleSmall.weight(.semibold))
                        .foregroundStyle(Color.brandTextPrimary)
                    Text(genre.tease)
                        .font(.bodyMedium)
                        .foregroundStyle(Color.brandTextSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.brandSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(isSelected ? genre.accentColor : Color.brandDivider, lineWidth: isSelected ? 2 : 1)
            )
            .brandCardShadow()
            .scaleEffect(isSelected ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
