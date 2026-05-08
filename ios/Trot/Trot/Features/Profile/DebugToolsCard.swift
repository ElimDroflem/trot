#if DEBUG
import SwiftUI
import SwiftData

/// DEBUG-only knobs surfaced inside the Profile tab. Two affordances today:
///   1. Force a specific `WeatherCategory` (+ optional force-night) so we can
///      QA every variant of `WeatherMoodLayer` without waiting for the real
///      sky to cooperate.
///   2. Wipe synthetic walks — removes the DebugSeed-injected demo walks
///      (filtered by the `[debug-seed]` notes tag) without touching real
///      user logs.
///
/// The whole file compiles out in release builds — the `#if DEBUG` wrap is
/// belt-and-braces (the call site in `DogProfileView` is also `#if DEBUG`).
struct DebugToolsCard: View {
    @Environment(\.modelContext) private var modelContext

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

    var body: some View {
        VStack(spacing: Space.md) {
            weatherCard
            demoDataCard
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
