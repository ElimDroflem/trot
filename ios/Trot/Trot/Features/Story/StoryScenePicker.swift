import SwiftUI

/// Second step of the story-onboarding flow. Shown after the user commits
/// a genre but before the first LLM page is written. Same calm-cards
/// aesthetic as `StoryGenrePicker` so the visual rhythm carries through.
///
/// The user picks one of four genre-bound openings; the choice is
/// persisted on `Story.sceneRaw` and shipped to the LLM via the
/// `scenePrompt` context key so page 1 visibly opens in that world.
///
/// **Why a separate step instead of an inline scene row on the genre
/// picker:** keeping it a separate "page turn" makes the scene feel
/// like a deliberate authorial choice, not a form field. It also lets
/// the atmosphere stay locked on the chosen genre while the user
/// considers the world (no preview-thrash from highlighting both at
/// once).
struct StoryScenePicker: View {
    let genre: StoryGenre
    let dogName: String

    @Binding var selected: StoryGenre.Scene?
    let onBegin: (StoryGenre.Scene) -> Void
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                header

                VStack(spacing: Space.sm) {
                    ForEach(genre.scenes) { scene in
                        sceneCard(for: scene)
                    }
                }
                .padding(.horizontal, Space.md)

                if let selected {
                    Button(action: { onBegin(selected) }) {
                        HStack(spacing: Space.xs) {
                            Image(systemName: selected.symbol)
                                .font(.system(size: 16, weight: .semibold))
                            Text("Begin")
                                .font(.bodyLarge.weight(.semibold))
                        }
                        .foregroundStyle(Color.brandTextOnPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.md)
                        .background(genre.primaryColor)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        .shadow(color: genre.primaryColor.opacity(0.35), radius: 12, y: 6)
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
        VStack(alignment: .leading, spacing: Space.sm) {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Back")
                        .font(.bodyMedium.weight(.medium))
                }
                .foregroundStyle(Color.brandTextSecondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: Space.xs) {
                Text(genre.sceneQuestion)
                    .font(.displayLarge)
                    .atmosphereTextPrimary()
                Text("Pick where \(dogName)'s book opens.")
                    .font(.bodyMedium)
                    .atmosphereTextSecondary()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.md)
    }

    @ViewBuilder
    private func sceneCard(for scene: StoryGenre.Scene) -> some View {
        let isSelected = selected == scene
        Button {
            withAnimation(.brandDefault) { selected = scene }
        } label: {
            HStack(alignment: .center, spacing: Space.md) {
                ZStack {
                    Circle()
                        .fill(genre.accentColor.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: scene.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(genre.accentColor)
                }

                Text(scene.displayName)
                    .font(.titleSmall.weight(.semibold))
                    .foregroundStyle(Color.brandTextPrimary)
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
