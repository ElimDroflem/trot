import SwiftUI

/// "When's the best time to walk today?" tile on the Today tab.
///
/// Three visual states:
///   - **No postcode**: a calm prompt sending the user to Profile to add one.
///   - **Loading**: a placeholder while geocoding/forecast is in flight.
///   - **Recommendation**: weather icon, headline, optional detail, and a small
///     temperature pill.
///
/// Loads itself on appear, and re-fetches when the postcode changes (the
/// `.task(id:)` modifier keys off it). The forecast itself is cached for 30
/// minutes inside `WeatherService`, so opening the app twice in an hour is one
/// request.
struct WalkWindowTile: View {
    let dog: Dog

    @Environment(AppState.self) private var appState
    @State private var state: TileState = .loading
    @State private var postcode: String = UserPreferences.postcode
    @State private var showingPostcodeEditor = false

    enum TileState {
        case loading
        case noPostcode
        case unavailable
        case ready(WalkRecommendationService.Recommendation)
    }

    var body: some View {
        Group {
            switch state {
            case .loading:        loadingTile
            case .noPostcode:     noPostcodeButton
            case .unavailable:    unavailableButton
            case .ready(let rec): recommendationTile(rec)
            }
        }
        .task(id: postcode) { await load() }
        .onAppear {
            // UserPreferences isn't observable, so re-read on each appear so a
            // postcode added in Profile/Edit lands on the next Home view.
            let current = UserPreferences.postcode
            if current != postcode { postcode = current }
        }
        .sheet(isPresented: $showingPostcodeEditor) {
            PostcodeEditSheet {
                // Re-read to pick up the new value; .task(id: postcode)
                // re-fires the load when this changes.
                postcode = UserPreferences.postcode
            }
        }
    }

    // MARK: - States

    private var loadingTile: some View {
        tileShell(
            icon: "cloud",
            tint: .brandTextTertiary,
            title: "Checking the forecast…",
            subtitle: nil,
            tempPill: nil
        )
    }

    /// Tappable — opens the postcode editor sheet inline so the user can fix
    /// the empty state without spelunking into Profile.
    private var noPostcodeButton: some View {
        Button { showingPostcodeEditor = true } label: {
            tileShell(
                icon: "location.fill",
                tint: .brandPrimary,
                title: "Add a postcode for the daily walk forecast.",
                subtitle: "Tap to add. Used only for weather, never for live tracking.",
                tempPill: nil
            )
        }
        .buttonStyle(.plain)
    }

    /// Tappable — lets the user retry by re-entering / correcting the postcode.
    /// Most "unavailable" states are a typo in the postcode that the geocoder
    /// can't resolve; surfacing the editor here is the fast fix.
    private var unavailableButton: some View {
        Button { showingPostcodeEditor = true } label: {
            tileShell(
                icon: "cloud.slash",
                tint: .brandTextTertiary,
                title: "Forecast unavailable.",
                subtitle: "Tap to check the postcode.",
                tempPill: nil
            )
        }
        .buttonStyle(.plain)
    }

    private func recommendationTile(_ rec: WalkRecommendationService.Recommendation) -> some View {
        tileShell(
            icon: weatherIcon(for: rec.category, isDay: !appState.atmosphereIsNight),
            tint: weatherTint(for: rec.category),
            title: rec.headline,
            subtitle: rec.detail,
            tempPill: "\(Int(rec.temperatureC.rounded()))°"
        )
    }

    // MARK: - Shell

    private func tileShell(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String?,
        tempPill: String?
    ) -> some View {
        HStack(alignment: .top, spacing: Space.md) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: Space.xs) {
                HStack(alignment: .top) {
                    Text("WALK WINDOW")
                        .font(.caption.weight(.semibold))
                        .tracking(0.5)
                        .foregroundStyle(Color.brandTextTertiary)
                    Spacer()
                    if let temp = tempPill {
                        Text(temp)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(tint)
                            .padding(.horizontal, Space.xs)
                            .padding(.vertical, 2)
                            .background(tint.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Text(title)
                    .font(.bodyLarge.weight(.semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.brandTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(Space.md)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
    }

    // MARK: - Loading

    private func load() async {
        let trimmed = UserPreferences.postcode
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            await update(.noPostcode)
            return
        }

        guard let location = await WeatherService.location(for: trimmed) else {
            await update(.unavailable)
            return
        }
        guard let forecast = await WeatherService.forecast(for: location) else {
            await update(.unavailable)
            return
        }

        if let rec = WalkRecommendationService.recommend(for: dog, forecast: forecast) {
            await update(.ready(rec))
        } else {
            await update(.unavailable)
        }
    }

    @MainActor
    private func update(_ next: TileState) {
        withAnimation(.brandDefault) { state = next }
    }

    // MARK: - Visual mapping

    /// Sun symbols at night look wrong on a deep-navy sky — swap to moon
    /// variants when the atmosphere is in night mode. Categories without a
    /// natural night counterpart (storm, snow) keep their daytime icon.
    private func weatherIcon(for category: WeatherCategory, isDay: Bool) -> String {
        switch category {
        case .clear:        return isDay ? "sun.max.fill" : "moon.stars.fill"
        case .partlyCloudy: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case .cloudy:       return "cloud.fill"
        case .fog:          return "cloud.fog.fill"
        case .drizzle:      return isDay ? "cloud.drizzle.fill" : "cloud.moon.rain.fill"
        case .rain:         return isDay ? "cloud.rain.fill" : "cloud.moon.rain.fill"
        case .snow:         return "cloud.snow.fill"
        case .thunder:      return isDay ? "cloud.bolt.rain.fill" : "cloud.moon.bolt.fill"
        }
    }

    private func weatherTint(for category: WeatherCategory) -> Color {
        switch category {
        case .clear, .partlyCloudy: return .brandPrimary
        case .cloudy, .fog:         return .brandSecondary
        case .drizzle, .rain:       return .brandSecondary
        case .snow:                 return .brandTextSecondary
        case .thunder:              return .brandError
        }
    }
}
