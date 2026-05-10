import SwiftUI
import UserNotifications

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
    /// LLM-rewritten headline. Drops in over the deterministic headline
    /// once the proxy responds. Cached per (dog × dayKey) inside the
    /// service so we burn at most one call per day per dog.
    @State private var llmHeadline: String?
    /// When non-nil, the user has scheduled a reminder for the picked
    /// window's start time. We mirror this from UserDefaults on appear so
    /// the toggle survives an app restart.
    @State private var reminderScheduledFor: Date?
    /// True when the user tapped "Remind me" while notifications are
    /// denied. Surfaces an inline "Notifications are off · Open Settings"
    /// hint under the capsule. iOS only shows the system prompt once, so
    /// the only path back is via Settings.
    @State private var permissionDeniedHint: Bool = false

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
                subtitle: "Tap to add.",
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
        // LLM headline takes precedence when it's landed; falls back to the
        // deterministic copy. The deterministic copy is already a real range
        // ("Best 1pm to 3pm. Sunny, 18°.") so the LLM is icing rather than
        // load-bearing — if the proxy is offline the user still sees a clean
        // sentence.
        let title = llmHeadline ?? rec.headline
        return tileShell(
            icon: weatherIcon(for: rec.category, isDay: !appState.atmosphereIsNight),
            tint: weatherTint(for: rec.category),
            title: title,
            subtitle: rec.detail,
            tempPill: "\(Int(rec.temperatureC.rounded()))°",
            reminder: reminderState(for: rec)
        )
    }

    /// Decide whether the reminder row shows. Hidden when the window has
    /// already started (less than 5 minutes lead time) AND no reminder is
    /// already scheduled — there's nothing meaningful to remind for. Visible
    /// otherwise so the user can either set or cancel.
    private func reminderState(for rec: WalkRecommendationService.Recommendation) -> ReminderRowState {
        let leadTime: TimeInterval = 5 * 60
        let isFuture = rec.start.timeIntervalSinceNow >= leadTime
        let alreadyScheduled = reminderScheduledFor != nil
        if isFuture || alreadyScheduled {
            return .visible(scheduled: alreadyScheduled) {
                Task { await toggleReminder(for: rec) }
            }
        }
        return .hidden
    }

    // MARK: - Shell

    private func tileShell(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String?,
        tempPill: String?,
        reminder: ReminderRowState = .hidden
    ) -> some View {
        VStack(spacing: Space.sm) {
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
            // Reminder capsule sits on its own row when present, so it
            // doesn't compete with the temperature pill or the headline.
            // Hidden entirely (no row, no spacing) when not applicable.
            if case .visible(let scheduled, let action) = reminder {
                HStack {
                    Spacer()
                    ReminderCapsule(isScheduled: scheduled, action: action)
                }
            }
            // Inline hint shown only after the user tapped "Remind me"
            // while notifications are denied. Sits below the capsule
            // (not next to it) so the tap target stays comfortable on
            // small screens.
            if permissionDeniedHint {
                HStack(spacing: 4) {
                    Spacer()
                    Text("Notifications are off.")
                        .font(.caption)
                        .foregroundStyle(Color.brandTextSecondary)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.brandPrimary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Notifications are off. Open Settings to enable them.")
            }
        }
        .padding(Space.md)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
    }

    /// Whether the reminder row renders. `.hidden` keeps the tile compact
    /// when no rec is loaded yet or the window has already started.
    enum ReminderRowState {
        case hidden
        case visible(scheduled: Bool, action: () -> Void)
    }

    // MARK: - Loading

    private func load() async {
        // Re-read any persisted reminder so the capsule shows the right
        // state on each launch. UserDefaults is per-bundle so this is fine
        // for v1 (single-device).
        await MainActor.run {
            reminderScheduledFor = WalkWindowReminder.scheduledFireDate()
            llmHeadline = nil
        }

        // DEBUG override: when a forced weather category is set in Profile
        // → Debug Tools, synthesise an all-day forecast of that category so
        // the WalkWindowTile end-to-end matches the WeatherMoodLayer's
        // forced sky. Otherwise the mood layer shows clear sun while the
        // tile reads the real (probably cloudy) forecast and the QA story
        // becomes inconsistent.
        #if DEBUG
        if let forced = DebugOverrides.weatherCategory {
            let synthetic = Self.syntheticForecast(category: forced)
            if let rec = WalkRecommendationService.recommend(for: dog, forecast: synthetic) {
                update(.ready(rec))
                await refreshLLMHeadline(forecast: synthetic, rec: rec)
            } else {
                update(.unavailable)
            }
            return
        }
        #endif

        let trimmed = UserPreferences.postcode
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            update(.noPostcode)
            return
        }

        guard let location = await WeatherService.location(for: trimmed) else {
            update(.unavailable)
            return
        }
        guard let forecast = await WeatherService.forecast(for: location) else {
            update(.unavailable)
            return
        }

        if let rec = WalkRecommendationService.recommend(for: dog, forecast: forecast) {
            update(.ready(rec))
            // Fire the LLM rationale in the background — never block the UI
            // on it, never let a failure surface. The deterministic
            // headline already reads cleanly.
            await refreshLLMHeadline(forecast: forecast, rec: rec)
        } else {
            update(.unavailable)
        }
    }

    #if DEBUG
    /// Build a 24-hour synthetic forecast where every hour shares the same
    /// category and a sensible default temperature. Used by the debug
    /// weather override so simulator screenshots show the tile reacting to
    /// the same sky the WeatherMoodLayer is rendering.
    private static func syntheticForecast(category: WeatherCategory) -> WeatherForecast {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: .now)
        let (code, tempC, precip): (Int, Double, Int) = {
            switch category {
            case .clear:        return (0, 17, 0)
            case .partlyCloudy: return (2, 16, 5)
            case .cloudy:       return (3, 14, 20)
            case .fog:          return (45, 9, 10)
            case .drizzle:      return (51, 11, 60)
            case .rain:         return (63, 10, 90)
            case .snow:         return (73, 1, 80)
            case .thunder:      return (95, 14, 95)
            }
        }()
        let snapshots: [HourlySnapshot] = (0..<24).compactMap { hour in
            guard let time = calendar.date(byAdding: .hour, value: hour, to: dayStart) else { return nil }
            return HourlySnapshot(
                time: time,
                temperatureC: tempC,
                precipitationProbability: precip,
                weatherCodeRaw: code,
                windSpeedKmh: 8,
                isDay: hour >= 6 && hour < 21
            )
        }
        let location = WeatherLocation(
            postcode: "DEBUG",
            latitude: 0,
            longitude: 0,
            displayName: "Debug"
        )
        return WeatherForecast(location: location, hourly: snapshots, fetchedAt: .now)
    }
    #endif

    @MainActor
    private func update(_ next: TileState) {
        withAnimation(.brandDefault) { state = next }
    }

    /// Calls `LLMService.bestWindowRationale` and slots the response over
    /// the deterministic headline. Cached per (dog × dayKey) inside the
    /// service, so this is a single Anthropic call per dog per day.
    private func refreshLLMHeadline(
        forecast: WeatherForecast,
        rec: WalkRecommendationService.Recommendation
    ) async {
        let calendar = Calendar.current
        // Compress today's upcoming hours into a tight table the LLM can
        // reason over without burning tokens. 12 hours is enough to cover
        // any user's enabled walk windows.
        let upcoming = forecast.hourly
            .filter { $0.time >= calendar.startOfHour(for: .now) }
            .prefix(12)
        let hourlyTable = upcoming.map { snap in
            let h = calendar.component(.hour, from: snap.time)
            let label = WalkRecommendationService.clockLabel(hour: h)
            let temp = Int(snap.temperatureC.rounded())
            return "\(label): \(snap.category.rawValue), \(temp)°C, \(Int(snap.precipitationProbability))% rain"
        }.joined(separator: "\n")

        let startHour = calendar.component(.hour, from: rec.start)
        let endHour = calendar.component(.hour, from: rec.end)
        let pickedWindow = rec.durationHours >= 2
            ? "\(WalkRecommendationService.clockLabel(hour: startHour)) to \(WalkRecommendationService.clockLabel(hour: endHour))"
            : WalkRecommendationService.clockLabel(hour: startHour)
        let pickedConditions = "\(rec.category.rawValue), \(Int(rec.temperatureC.rounded()))°C"
        let walkSlots = (dog.walkWindows ?? []).filter(\.enabled).map { $0.slot.rawValue }

        let line = await LLMService.bestWindowRationale(
            for: dog,
            hourlyTable: hourlyTable,
            pickedWindow: pickedWindow,
            pickedConditions: pickedConditions,
            walkWindowSlots: walkSlots
        )
        guard let line, !line.isEmpty else { return }
        await MainActor.run {
            withAnimation(.brandDefault) { llmHeadline = line }
        }
    }

    /// Toggles the reminder for the picked window. If one is already
    /// scheduled, cancels it. Otherwise asks for notification permission
    /// (if undetermined), then schedules a single
    /// `UNCalendarNotificationTrigger` for the window's start time today.
    /// On denial, surfaces an inline hint and does not schedule.
    private func toggleReminder(for rec: WalkRecommendationService.Recommendation) async {
        if reminderScheduledFor != nil {
            await WalkWindowReminder.cancel()
            await MainActor.run {
                reminderScheduledFor = nil
                permissionDeniedHint = false
            }
            return
        }

        // Permission gate — only on the ON path. The first explicit
        // user-initiated request for any Trot notification, so this is
        // the right earned moment to ask. Once granted, the existing
        // NotificationService.reschedule call (in RootView) picks up
        // the auto-scheduled types (nudge / milestone / recap /
        // morning-window) on its next firing.
        var status = await NotificationService.authorizationStatus()
        if status == .notDetermined {
            _ = await NotificationService.requestPermission()
            status = await NotificationService.authorizationStatus()
        }
        let granted = status == .authorized || status == .provisional || status == .ephemeral
        guard granted else {
            await MainActor.run {
                permissionDeniedHint = true
            }
            return
        }

        let title = llmHeadline ?? rec.headline
        let body = "Time for \(dog.name)'s walk."
        let scheduled = await WalkWindowReminder.schedule(
            at: rec.start,
            title: title,
            body: body
        )
        await MainActor.run {
            reminderScheduledFor = scheduled ? rec.start : nil
            permissionDeniedHint = false
        }
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

// MARK: - Reminder capsule

/// Small button that lets the user schedule a one-shot notification at the
/// recommended walk-window's start time. Two visual states:
///   - **Idle**: a brand-primary "Remind me" capsule with a bell icon.
///   - **Scheduled**: a green-tinted "Reminder set" capsule with a tick.
///     Tap again cancels.
private struct ReminderCapsule: View {
    let isScheduled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isScheduled ? "checkmark.circle.fill" : "bell.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text(isScheduled ? "Reminder set" : "Remind me")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(isScheduled ? Color.brandSuccess : Color.brandPrimary)
            .padding(.horizontal, Space.sm)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill((isScheduled ? Color.brandSuccess : Color.brandPrimary).opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isScheduled ? "Cancel reminder" : "Set reminder for the walk window")
    }
}

// MARK: - Reminder scheduling

/// Wrapper around `UNUserNotificationCenter` for the single walk-window
/// reminder. We hold at most one reminder globally — tapping "Remind me"
/// when one is already scheduled cancels and replaces it. The scheduled
/// fire-time is mirrored into UserDefaults so the capsule shows the right
/// state across launches; on cancellation it's cleared.
@MainActor
enum WalkWindowReminder {
    private static let identifier = "trot.walkWindow.reminder"
    private static let storageKey = "trot.walkWindow.reminderFireDate"

    /// Returns the fire-date of the currently-scheduled reminder, or nil.
    /// Reads from UserDefaults rather than `pendingNotificationRequests()`
    /// so callers can decide synchronously what to render. We also clear
    /// the stored value if it's in the past — iOS already fired (or
    /// dropped) the notification by then.
    static func scheduledFireDate() -> Date? {
        guard let stamp = UserDefaults.standard.object(forKey: storageKey) as? Date else {
            return nil
        }
        if stamp <= Date() {
            UserDefaults.standard.removeObject(forKey: storageKey)
            return nil
        }
        return stamp
    }

    /// Schedules a one-shot notification at `at`. Replaces any existing
    /// reminder. Returns true on success. Failure modes: notification
    /// authorisation denied (we still write the storage key so the UI
    /// reflects the user's intent — they can grant permission and tap
    /// Allow when they next launch).
    @discardableResult
    static func schedule(at fireAt: Date, title: String, body: String) async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
            UserDefaults.standard.set(fireAt, forKey: storageKey)
            return true
        } catch {
            return false
        }
    }

    static func cancel() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
