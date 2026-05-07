#if DEBUG
import SwiftUI

/// DEBUG-only knobs surfaced inside the Profile tab. Currently a single
/// affordance: force a specific `WeatherCategory` so we can QA every variant
/// of `WeatherMoodLayer` without waiting for the real sky to cooperate.
///
/// The whole file compiles out in release builds — the `#if DEBUG` wrap is
/// belt-and-braces (the call site in `DogProfileView` is also `#if DEBUG`).
struct DebugToolsCard: View {
    /// Bumped on save so the parent re-reads `DebugOverrides` and re-renders.
    @State private var refreshTick: Int = 0
    /// Local copy so the picker is bindable; mirrored to UserDefaults on change.
    @State private var override: WeatherCategoryChoice = .auto

    var body: some View {
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
            }
            .padding(.vertical, Space.xs)
        }
        .onAppear {
            override = WeatherCategoryChoice(category: DebugOverrides.weatherCategory)
        }
        .onChange(of: override) { _, newValue in
            DebugOverrides.weatherCategory = newValue.category
            refreshTick &+= 1
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
