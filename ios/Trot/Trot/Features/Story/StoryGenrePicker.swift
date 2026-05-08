import SwiftUI

/// First impression of the Story tab. Shown only until the user picks a
/// genre — after that, it never returns (genre is locked per dog).
///
/// Each genre card takes up its own block, themed with the genre's
/// primary colour and accent. The visual signal: this isn't a settings
/// menu, it's the spine of a small bookshop. Display type for the genre
/// name, italic serif body for the tease, accent-coloured icon block.
struct StoryGenrePicker: View {
    let onPick: (StoryGenre) -> Void

    @State private var selected: StoryGenre?

    var body: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                header

                VStack(spacing: Space.md) {
                    ForEach(StoryGenre.allCases) { genre in
                        genreCard(for: genre)
                    }
                }
                .padding(.horizontal, Space.md)

                if let selected {
                    Button(action: { onPick(selected) }) {
                        Text("Begin \(selected.displayName)")
                            .font(.bodyLarge.weight(.semibold))
                            .foregroundStyle(Color.brandTextOnPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Space.md)
                            .background(selected.primaryColor)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
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
            Text("Six worlds. Same dog. The book grows by a page each walk — comedy comes from being a dog in the wrong place.")
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
            withAnimation(.brandCelebration) { selected = genre }
        } label: {
            HStack(alignment: .top, spacing: Space.md) {
                ZStack {
                    Circle()
                        .fill(genre.primaryColor.opacity(0.20))
                        .frame(width: 52, height: 52)
                    Image(systemName: genre.symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(genre.primaryColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(genre.displayName)
                        .font(.titleMedium.weight(.semibold))
                        .foregroundStyle(Color.brandTextPrimary)
                    Text(genre.tease)
                        .font(.bodyMedium)
                        .italic()
                        .foregroundStyle(Color.brandTextSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.brandSurfaceElevated)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(isSelected ? genre.accentColor : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .brandCardShadow()
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
