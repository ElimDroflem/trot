import Foundation

/// User-level preferences that aren't tied to a specific dog. Currently:
/// postcode (for weather lookups). Stored in UserDefaults — no CloudKit sync
/// in v1, so users on a new device re-enter their postcode. Acceptable
/// trade-off vs introducing a UserSettings @Model just for one field.
enum UserPreferences {
    private static let postcodeKey = "trot.user.postcode"
    private static let ownerNameKey = "trot.user.ownerName"
    private static let storyIntroSeenKey = "trot.story.introSeen"
    private static let onboardingDoneKey = "trot.onboarding.done"
    private static let onboardingMigrationDoneKey = "trot.onboarding.migrationDone"

    /// True once the user has finished the new-user onboarding flow
    /// (profile → genre → scene → prologue → permissions). Drives
    /// `RootView` routing: false sends the user into `OnboardingFlowView`,
    /// true lets them through to `HomeView`. Set at the end of the
    /// permissions step (whether the user granted or skipped).
    static var onboardingDone: Bool {
        get { UserDefaults.standard.bool(forKey: onboardingDoneKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardingDoneKey) }
    }

    /// One-shot flag that flips true after the first launch in which
    /// `RootView` checked whether the user already had a dog with a
    /// story (i.e. they were already onboarded under the old flow). If
    /// so, `onboardingDone` is set to true so they don't get re-onboarded.
    static var onboardingMigrationDone: Bool {
        get { UserDefaults.standard.bool(forKey: onboardingMigrationDoneKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardingMigrationDoneKey) }
    }

    /// True once the user has tapped through the one-shot Story-mode intro
    /// that appears the first time they visit the Story tab. Survives app
    /// reinstall as long as iOS preserves UserDefaults; fresh install
    /// wipes it, which is fine — first-time users SHOULD see it again on
    /// a fresh device.
    static var storyIntroSeen: Bool {
        get { UserDefaults.standard.bool(forKey: storyIntroSeenKey) }
        set { UserDefaults.standard.set(newValue, forKey: storyIntroSeenKey) }
    }

    /// First name (or chosen handle) used by the Story tab when the LLM
    /// names the human protagonist alongside the dog. Empty by default —
    /// the LLM falls back to "the human" if so. Set during the Story
    /// genre-picker flow if the user wants to be named.
    static var ownerName: String {
        get {
            UserDefaults.standard.string(forKey: ownerNameKey) ?? ""
        }
        set {
            let cleaned = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.isEmpty {
                UserDefaults.standard.removeObject(forKey: ownerNameKey)
            } else {
                UserDefaults.standard.set(cleaned, forKey: ownerNameKey)
            }
        }
    }
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
            // Wake any view that depends on the postcode but doesn't own the
            // editor sheet — chiefly `WeatherMoodLayer`, which sits behind
            // every tab and so never gets a fresh `.onAppear` after a
            // postcode change.
            NotificationCenter.default.post(name: .trotPostcodeChanged, object: nil)
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
