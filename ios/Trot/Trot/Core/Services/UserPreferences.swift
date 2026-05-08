import Foundation

/// User-level preferences that aren't tied to a specific dog. Currently:
/// postcode (for weather lookups). Stored in UserDefaults — no CloudKit sync
/// in v1, so users on a new device re-enter their postcode. Acceptable
/// trade-off vs introducing a UserSettings @Model just for one field.
enum UserPreferences {
    private static let postcodeKey = "trot.user.postcode"
    private static let cachedLocationKey = "trot.user.cachedLocation"

    /// Latest postcode the user typed in onboarding or Profile. Whitespace-
    /// trimmed and uppercased. Empty means unset.
    static var postcode: String {
        get {
            UserDefaults.standard.string(forKey: postcodeKey) ?? ""
        }
        set {
            let cleaned = newValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            UserDefaults.standard.set(cleaned, forKey: postcodeKey)
            // Invalidate the cached lat/lon if the postcode changed — the
            // weather service will geocode again on next fetch.
            if let cached = cachedLocation(for: cleaned), cached.postcode == cleaned {
                // Same postcode, keep cache.
            } else {
                UserDefaults.standard.removeObject(forKey: cachedLocationKey)
            }
        }
    }

    /// Returns the cached `WeatherLocation` if its postcode matches the
    /// requested one. Avoids re-geocoding on every weather fetch.
    static func cachedLocation(for postcode: String) -> WeatherLocation? {
        guard let data = UserDefaults.standard.data(forKey: cachedLocationKey) else { return nil }
        guard let location = try? JSONDecoder().decode(WeatherLocation.self, from: data) else { return nil }
        return location.postcode == postcode ? location : nil
    }

    static func setCachedLocation(_ location: WeatherLocation) {
        guard let data = try? JSONEncoder().encode(location) else { return }
        UserDefaults.standard.set(data, forKey: cachedLocationKey)
    }
}

// MARK: - Debug overrides

/// Lightweight UserDefaults-backed knobs used during development to force
/// specific UI states without waiting for the real world to cooperate
/// (sunny weather at 1am, etc.). Reads are gated by the call sites — typically
/// the override only takes effect in DEBUG builds, but the storage itself is
/// available everywhere so the override toggle works inside the app.
enum DebugOverrides {
    private static let weatherCategoryKey = "trot.debug.weatherCategoryOverride"
    private static let forceNightKey = "trot.debug.forceNightOverride"

    /// Forced weather category. `nil` means "use the real forecast."
    /// `WeatherMoodLayer` checks this on load (DEBUG only) and skips the
    /// network call when it's set.
    static var weatherCategory: WeatherCategory? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: weatherCategoryKey),
                  let category = WeatherCategory(rawValue: raw)
            else { return nil }
            return category
        }
        set {
            if let category = newValue {
                UserDefaults.standard.set(category.rawValue, forKey: weatherCategoryKey)
            } else {
                UserDefaults.standard.removeObject(forKey: weatherCategoryKey)
            }
        }
    }

    /// Forces the synthetic weather snapshot's `isDay` to false so we can QA
    /// the night palette and moon disc on a sunny afternoon. Only applies
    /// when `weatherCategory` is also set (the override path).
    static var forceNight: Bool {
        get { UserDefaults.standard.bool(forKey: forceNightKey) }
        set { UserDefaults.standard.set(newValue, forKey: forceNightKey) }
    }
}
