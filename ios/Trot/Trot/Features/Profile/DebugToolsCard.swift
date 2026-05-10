#if DEBUG
import SwiftUI
import SwiftData

/// DEBUG-only knobs surfaced inside the Profile tab. Three affordances:
///   1. Force a specific `WeatherCategory` (+ optional force-night) so we can
///      QA every variant of `WeatherMoodLayer` without waiting for the real
///      sky to cooperate.
///   2. Wipe synthetic walks — removes the DebugSeed-injected demo walks
///      (filtered by the `[debug-seed]` notes tag) without touching real
///      user logs.
///   3. Story controls — swap the active story's genre/scene, force-finish
///      a book, or seed a complete one. Mirrors the
///      `trot://debug/story/...` deep links so deep-link and UI flows
///      converge on the same StoryService helpers.
///
/// The whole file compiles out in release builds — the `#if DEBUG` wrap is
/// belt-and-braces (the call site in `DogProfileView` is also `#if DEBUG`).
struct DebugToolsCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Dog> { $0.archivedAt == nil })
    private var activeDogs: [Dog]

    /// Bumped on save so the parent re-reads `DebugOverrides` and re-renders.
    @State private var refreshTick: Int = 0
    /// Local copy so the picker is bindable; mirrored to UserDefaults on change.
    @State private var override: WeatherCategoryChoice = .auto
    /// Force-night toggle. Only meaningful when an override is active (the
    /// real-forecast path uses the API's `is_day` field).
    @State private var forceNight: Bool = false
    /// Live count of synthetic walks in the store — refreshed on appear and
    /// after a wipe so the banner stays honest.
    @State private var syntheticCount: Int = 0
    @State private var showingWipeConfirm = false
    /// Sheet flags for the story-control pickers.
    @State private var showingGenreSwap = false
    @State private var showingSceneSwap = false
    @State private var showingFinishConfirm = false

    /// First active dog — the implicit subject of the story-control buttons.
    /// Mirrors the deep-link contract (`firstActiveDog(in:)`).
    private var firstDog: Dog? { activeDogs.first }

    var body: some View {
        VStack(spacing: Space.md) {
            weatherCard
            demoDataCard
            storyControlsCard
        }
        .onAppear {
            override = WeatherCategoryChoice(category: DebugOverrides.weatherCategory)
            forceNight = DebugOverrides.forceNight
            refreshSyntheticCount()
        }
        .onChange(of: override) { _, newValue in
            DebugOverrides.weatherCategory = newValue.category
            refreshTick &+= 1
        }
        .onChange(of: forceNight) { _, newValue in
            DebugOverrides.forceNight = newValue
            refreshTick &+= 1
        }
    }

    // MARK: - Weather override

    private var weatherCard: some View {
        FormCard(title: "Debug · weather override") {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("Force a weather variant. Affects every tab. Auto = use the real forecast.")
                    .font(.caption)
                    .foregroundStyle(Color.brandTextTertiary)

                Picker("Weather override", selection: $override) {
                    ForEach(WeatherCategoryChoice.allCases, id: \.self) { choice in
                        Text(choice.label).tag(choice)
                    }
                }
                .pickerStyle(.menu)
                .tint(.brandPrimary)
                .padding(.vertical, Space.xs)

                Toggle("Force night", isOn: $forceNight)
                    .tint(.brandPrimary)
                    .font(.bodyMedium)
                    .disabled(override == .auto)
                Text("Forces nighttime palette + moon for the override above. Only applies when an override is set.")
                    .font(.caption2)
                    .foregroundStyle(Color.brandTextTertiary)
            }
            .padding(.vertical, Space.xs)
        }
    }

    // MARK: - Demo data

    private var demoDataCard: some View {
        FormCard(title: "Debug · demo data") {
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.brandSecondary)
                    Text(bannerText)
                        .font(.caption)
                        .foregroundStyle(Color.brandTextSecondary)
                }

                Button(role: .destructive) {
                    showingWipeConfirm = true
                } label: {
                    Text("Wipe synthetic walks")
                        .font(.bodyMedium.weight(.semibold))
                        .foregroundStyle(syntheticCount > 0 ? Color.brandError : Color.brandTextTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.sm)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .stroke(syntheticCount > 0 ? Color.brandError.opacity(0.5) : Color.brandDivider, lineWidth: 1)
                        )
                }
                .disabled(syntheticCount == 0)
            }
            .padding(.vertical, Space.xs)
        }
        .confirmationDialog(
            "Wipe \(syntheticCount) synthetic walk\(syntheticCount == 1 ? "" : "s")?",
            isPresented: $showingWipeConfirm,
            titleVisibility: .visible
        ) {
            Button("Wipe", role: .destructive) { wipeSynthetic() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes only walks tagged \(DebugSeed.syntheticNotesTag) by DebugSeed. Real user-logged walks are untouched.")
        }
    }

    private var bannerText: String {
        if syntheticCount == 0 { return "No synthetic walks in store." }
        return "\(syntheticCount) synthetic walk\(syntheticCount == 1 ? "" : "s") from DebugSeed."
    }

    private func refreshSyntheticCount() {
        syntheticCount = DebugSeed.syntheticWalkCount(in: modelContext)
    }

    private func wipeSynthetic() {
        _ = DebugSeed.wipeSyntheticWalks(in: modelContext)
        refreshSyntheticCount()
    }

    // MARK: - Story controls

    private var storyControlsCard: some View {
        FormCard(title: "Debug · story") {
            VStack(alignment: .leading, spacing: Space.sm) {
                if let dog = firstDog {
                    activeStoryRow(dog: dog)
                    storyButtons(dog: dog)
                    if !(dog.completedStories ?? []).isEmpty {
                        completedRow(dog: dog)
                    }
                } else {
                    Text("No active dog. Add one first.")
                        .font(.caption)
                        .foregroundStyle(Color.brandTextTertiary)
                }
            }
            .padding(.vertical, Space.xs)
        }
        .sheet(isPresented: $showingGenreSwap) {
            if let dog = firstDog, let story = dog.story {
                genreSwapSheet(currentGenre: story.genre, dog: dog)
            }
        }
        .sheet(isPresented: $showingSceneSwap) {
            if let dog = firstDog, let story = dog.story {
                sceneSwapSheet(genre: story.genre, dog: dog)
            }
        }
        .confirmationDialog(
            "Force-finish the active book?",
            isPresented: $showingFinishConfirm,
            titleVisibility: .visible
        ) {
            Button("Finish", role: .destructive) {
                guard let dog = firstDog else { return }
                _ = StoryService.debugForceFinishActiveStory(for: dog, in: modelContext)
                refreshTick &+= 1
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Stamps templated title + closing line, moves the book to completed. No LLM call.")
        }
    }

    @ViewBuilder
    private func activeStoryRow(dog: Dog) -> some View {
        if let story = dog.story {
            let chapters = story.chapters?.count ?? 0
            let pages = (story.chapters ?? []).flatMap { $0.pages ?? [] }.count
            HStack(spacing: Space.xs) {
                Image(systemName: story.genre.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(story.genre.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(story.genre.displayName) · \(story.scene?.displayName ?? "no scene")")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.brandTextPrimary)
                    Text("\(chapters) ch · \(pages) pages")
                        .font(.caption2)
                        .foregroundStyle(Color.brandTextTertiary)
                }
                Spacer(minLength: 0)
            }
        } else {
            HStack(spacing: Space.xs) {
                Image(systemName: "book")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brandTextTertiary)
                Text("No active story.")
                    .font(.caption)
                    .foregroundStyle(Color.brandTextTertiary)
                Spacer(minLength: 0)
            }
        }
    }

    private func storyButtons(dog: Dog) -> some View {
        VStack(spacing: Space.xs) {
            HStack(spacing: Space.xs) {
                debugButton(label: "Swap genre", isEnabled: dog.story != nil) {
                    showingGenreSwap = true
                }
                debugButton(label: "Swap scene", isEnabled: dog.story != nil) {
                    showingSceneSwap = true
                }
            }
            HStack(spacing: Space.xs) {
                debugButton(label: "Force-finish", isEnabled: dog.story != nil, isDestructive: true) {
                    showingFinishConfirm = true
                }
                debugButton(label: "Seed completed", isEnabled: true) {
                    _ = StoryService.debugSeedCompletedBook(for: dog, in: modelContext)
                    refreshTick &+= 1
                }
            }
        }
    }

    private func completedRow(dog: Dog) -> some View {
        let count = dog.completedStories?.count ?? 0
        return HStack(spacing: Space.xs) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.brandSecondary)
            Text("\(count) completed book\(count == 1 ? "" : "s") on the shelf.")
                .font(.caption)
                .foregroundStyle(Color.brandTextSecondary)
            Spacer(minLength: 0)
        }
        .padding(.top, Space.xs)
    }

    private func debugButton(
        label: String,
        isEnabled: Bool,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isDestructive ? Color.brandError : Color.brandPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.xs)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .stroke(
                            isDestructive ? Color.brandError.opacity(0.5) : Color.brandPrimary.opacity(0.5),
                            lineWidth: 1
                        )
                )
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }

    // MARK: - Swap sheets

    private func genreSwapSheet(currentGenre: StoryGenre, dog: Dog) -> some View {
        NavigationStack {
            ZStack {
                Color.brandSurface.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Space.sm) {
                        ForEach(StoryGenre.allCases) { genre in
                            Button {
                                if let story = dog.story {
                                    story.genre = genre
                                    for chapter in (story.chapters ?? []) where chapter.closedAt != nil && chapter.seenAt == nil {
                                        chapter.seenAt = chapter.closedAt
                                    }
                                    try? modelContext.save()
                                }
                                showingGenreSwap = false
                                refreshTick &+= 1
                            } label: {
                                HStack(spacing: Space.md) {
                                    Image(systemName: genre.symbol)
                                        .foregroundStyle(genre.accentColor)
                                    Text(genre.displayName)
                                        .foregroundStyle(Color.brandTextPrimary)
                                    if genre == currentGenre {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.brandPrimary)
                                    } else {
                                        Spacer()
                                    }
                                }
                                .font(.bodyMedium)
                                .padding(Space.md)
                                .background(Color.brandSurfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(Space.md)
                }
            }
            .navigationTitle("Swap genre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { showingGenreSwap = false }
                }
            }
        }
    }

    private func sceneSwapSheet(genre: StoryGenre, dog: Dog) -> some View {
        NavigationStack {
            ZStack {
                Color.brandSurface.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Space.sm) {
                        ForEach(genre.scenes) { scene in
                            Button {
                                StoryService.debugSwapScene(to: scene, for: dog, in: modelContext)
                                showingSceneSwap = false
                                refreshTick &+= 1
                            } label: {
                                HStack(spacing: Space.md) {
                                    Image(systemName: scene.symbol)
                                        .foregroundStyle(genre.accentColor)
                                    Text(scene.displayName)
                                        .foregroundStyle(Color.brandTextPrimary)
                                    if scene.id == dog.story?.sceneRaw {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.brandPrimary)
                                    } else {
                                        Spacer()
                                    }
                                }
                                .font(.bodyMedium)
                                .padding(Space.md)
                                .background(Color.brandSurfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(Space.md)
                }
            }
            .navigationTitle("Swap scene")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { showingSceneSwap = false }
                }
            }
        }
    }

    /// "Auto" plus every WeatherCategory case, packaged for a Picker.
    enum WeatherCategoryChoice: Hashable, CaseIterable {
        case auto
        case clear, partlyCloudy, cloudy, fog, drizzle, rain, snow, thunder

        init(category: WeatherCategory?) {
            switch category {
            case .none: self = .auto
            case .clear?:        self = .clear
            case .partlyCloudy?: self = .partlyCloudy
            case .cloudy?:       self = .cloudy
            case .fog?:          self = .fog
            case .drizzle?:      self = .drizzle
            case .rain?:         self = .rain
            case .snow?:         self = .snow
            case .thunder?:      self = .thunder
            }
        }

        var category: WeatherCategory? {
            switch self {
            case .auto:         return nil
            case .clear:        return .clear
            case .partlyCloudy: return .partlyCloudy
            case .cloudy:       return .cloudy
            case .fog:          return .fog
            case .drizzle:      return .drizzle
            case .rain:         return .rain
            case .snow:         return .snow
            case .thunder:      return .thunder
            }
        }

        var label: String {
            switch self {
            case .auto:         return "Auto (real forecast)"
            case .clear:        return "Clear"
            case .partlyCloudy: return "Partly cloudy"
            case .cloudy:       return "Cloudy"
            case .fog:          return "Fog"
            case .drizzle:      return "Drizzle"
            case .rain:         return "Rain"
            case .snow:         return "Snow"
            case .thunder:      return "Thunder"
            }
        }
    }
}
#endif
