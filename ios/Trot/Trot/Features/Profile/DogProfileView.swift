import SwiftUI
import SwiftData

/// The Dog tab. Acts as a "player card" for the user's dog rather than a
/// settings list — photo and name are the hero, vital stats live below it
/// in a `DogTagPanel`, then achievements, then a single Settings entry that
/// pushes the full editable surface into a sheet.
struct DogProfileView: View {
    @Query(
        filter: #Predicate<Dog> { $0.archivedAt == nil },
        sort: \Dog.createdAt,
        order: .reverse
    )
    private var activeDogs: [Dog]

    @Environment(AppState.self) private var appState

    @State private var showingSettings = false

    private var activeDog: Dog? { appState.selectedDog(from: activeDogs) }

    var body: some View {
        ZStack {
            Color.brandSurface.ignoresSafeArea()
            WeatherMoodLayer()

            if let dog = activeDog {
                ScrollView {
                    VStack(spacing: Space.lg) {
                        photoHeader(dog: dog)
                        DogTagPanel(dog: dog)
                        TraitsCard(dog: dog)
                        settingsButton
                        // Clearance for the centre walk FAB.
                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.top, Space.md)
                }
            } else {
                emptyState
            }
        }
        .edgeGlass()
        .sheet(isPresented: $showingSettings) {
            if let dog = activeDog {
                DogSettingsSheet(dog: dog)
            }
        }
    }

    // MARK: - Sections

    /// Photo gets the same coral tracking ring used on Today so it doesn't
    /// melt into the weather mood layer behind it.
    private func photoHeader(dog: Dog) -> some View {
        let outerSize: CGFloat = 156
        let strokeWidth: CGFloat = 6
        let photoInset: CGFloat = 6
        let innerSize = outerSize - strokeWidth * 2 - photoInset * 2

        return VStack(spacing: Space.md) {
            ZStack {
                Circle()
                    .stroke(Color.brandPrimary, lineWidth: strokeWidth)

                Group {
                    if let data = dog.photo, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            Color.brandSecondaryTint
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(Color.brandSecondary.opacity(0.5))
                        }
                    }
                }
                .frame(width: innerSize, height: innerSize)
                .clipShape(Circle())
            }
            .frame(width: outerSize, height: outerSize)
            .brandCardShadow()

            VStack(spacing: Space.xs) {
                Text(dog.name)
                    .font(.displayMedium)
                    .foregroundStyle(Color.brandTextPrimary)
                if !dog.breedPrimary.isEmpty {
                    Text(breedAndAgeLine(dog: dog))
                        .font(.bodyMedium.weight(.semibold))
                        .foregroundStyle(Color.brandTextSecondary)
                }
            }
        }
        .padding(.top, Space.sm)
    }

    /// Single tap-target into the full editable surface. Replaces the long
    /// vertical wall of cards (Basics, Activity, Health, Walk windows,
    /// Postcode, Edit, Add another, Archive) that used to sit on this tab.
    private var settingsButton: some View {
        Button(action: { showingSettings = true }) {
            HStack(spacing: Space.sm) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brandTextSecondary)
                Text("Settings")
                    .font(.bodyLarge.weight(.semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brandTextTertiary)
            }
            .padding(Space.md)
            .background(Color.brandSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .brandCardShadow()
        }
        .buttonStyle(.plain)
        .padding(.top, Space.sm)
    }

    private var emptyState: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "pawprint.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color.brandTextTertiary)
            Text("No dog selected.")
                .font(.titleMedium)
                .foregroundStyle(Color.brandTextSecondary)
        }
        .padding(Space.xl)
    }

    // MARK: - Helpers

    private func breedAndAgeLine(dog: Dog) -> String {
        let breed = dog.breedPrimary
        let years = ageInYears(dog: dog)
        return "\(breed) · \(years)"
    }

    private func ageInYears(dog: Dog) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: dog.dateOfBirth, to: .now)
        let years = components.year ?? 0
        let months = components.month ?? 0
        if years == 0 {
            return "\(max(0, months)) mo"
        }
        return years == 1 ? "1 yr" : "\(years) yrs"
    }
}

#Preview {
    DogProfileView()
        .modelContainer(for: [Dog.self, Walk.self, WalkWindow.self], inMemory: true)
}
