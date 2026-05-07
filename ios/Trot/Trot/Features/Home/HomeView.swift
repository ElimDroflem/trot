import SwiftUI
import SwiftData
import PhotosUI

struct HomeView: View {
    @Query(
        filter: #Predicate<Dog> { $0.archivedAt == nil },
        sort: \Dog.createdAt,
        order: .reverse
    )
    private var activeDogs: [Dog]

    @Environment(AppState.self) private var appState
    @State private var showingLogWalk = false
    @State private var showingExpedition = false
    @State private var editingWalk: Walk?
    @State private var showingAddAnotherDog = false

    private var selectedDog: Dog? { appState.selectedDog(from: activeDogs) }

    var body: some View {
        @Bindable var appStateBindable = appState
        TabView(selection: $appStateBindable.selectedTab) {
            todayTab
                .tabItem { Label("Today", systemImage: "house.fill") }
                .tag(TrotTab.today)

            JourneyView()
                .tabItem { Label("Journey", systemImage: "figure.walk.motion") }
                .tag(TrotTab.journey)

            InsightsView()
                .tabItem { Label("Insights", systemImage: "lightbulb") }
                .tag(TrotTab.insights)

            DogProfileView()
                .tabItem {
                    Label(selectedDog?.name ?? "Dog", systemImage: "dog.fill")
                }
                .tag(TrotTab.dog)
        }
        .tint(.brandPrimary)
        .overlay(alignment: .bottom) {
            // Strava-style centre FAB. Sits above the tab bar's centre slot —
            // raised so it reads as a floating primary action rather than a
            // fifth tab. Visible regardless of which tab is selected because
            // "walk with your dog" is the app's core verb.
            WalkActionFAB(
                onStartWalk: { showingExpedition = true },
                onLogPastWalk: { showingLogWalk = true }
            )
            // Tab-bar height + a lift so the button rises above the bar.
            // 49pt is the standard iOS tab-bar item height; we add ~22pt of
            // lift so roughly half the FAB sits above the bar, half over it.
            .padding(.bottom, 49 - 22)
        }
        .sheet(isPresented: $showingLogWalk) {
            if let dog = selectedDog {
                LogWalkSheet(dogs: [dog])
            }
        }
        .sheet(isPresented: $showingExpedition) {
            if let dog = selectedDog {
                ExpeditionView(dog: dog)
            }
        }
        .sheet(item: $editingWalk) { walk in
            if let dog = selectedDog {
                LogWalkSheet(dogs: [dog], editingWalk: walk)
            }
        }
        .sheet(isPresented: $showingAddAnotherDog) {
            NavigationStack {
                AddDogView(showsCancelButton: true)
                    .navigationTitle("Add a dog")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    @ViewBuilder
    private var todayTab: some View {
        ZStack {
            LinearGradient(
                colors: [Color.brandSurface, Color.brandSurfaceSunken],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Subtle full-bleed weather animation. Silent when no postcode is
            // set or while loading, so it never gets in the way.
            WeatherMoodLayer()

            if let dog = selectedDog {
                ScrollView {
                    VStack(spacing: Space.lg) {
                        HomeHeader(
                            activeDogs: activeDogs,
                            selectedDog: dog,
                            streakDays: StreakService.currentStreak(for: dog),
                            dateLabel: Self.dateLabel(for: .now),
                            onSelectDog: { appState.select($0) },
                            onAddAnotherDog: { showingAddAnotherDog = true }
                        )
                        DogPresenceCard(
                            dog: dog,
                            partOfDay: Self.partOfDay(for: .now),
                            minutesDone: minutesDone(for: dog),
                            targetMinutes: dog.dailyTargetMinutes,
                            percent: percent(for: dog),
                            minutesToGo: minutesToGo(for: dog)
                        )
                        // Daily dog-voice line is suppressed once the target's
                        // met — at that point the ring + "today done" pill say
                        // it. Showing a third "good work" line is just noise.
                        if percent(for: dog) < 1.0 {
                            DailyDogVoiceRow(dog: dog)
                        }
                        // Weather tile only when it's saying something useful
                        // (rain/snow/storm). On clear/cloudy days the mood
                        // layer already conveys the weather; a card too is
                        // duplicated info.
                        ConditionalWalkWindowTile(dog: dog)
                        TodayTimeline(
                            walks: walksToday(for: dog),
                            walkWindows: dog.walkWindows ?? [],
                            now: .now,
                            onTapWalk: { walk in editingWalk = walk }
                        )
                        // Extra clearance so the bottom card never hides
                        // behind the centre walk FAB.
                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.top, Space.sm)
                }
            } else {
                EmptyDogPlaceholder()
            }
        }
        .edgeGlass()
    }

    private func placeholderTab(title: String) -> some View {
        ZStack {
            Color.brandSurface.ignoresSafeArea()
            Text(title)
                .font(.titleLarge)
                .foregroundStyle(Color.brandTextSecondary)
        }
    }

    // MARK: - Today helpers (local time per spec)

    private func walksToday(for dog: Dog) -> [Walk] {
        let calendar = Calendar.current
        return (dog.walks ?? [])
            .filter { calendar.isDateInToday($0.startedAt) }
            .sorted { $0.startedAt > $1.startedAt }
    }

    private func minutesDone(for dog: Dog) -> Int {
        walksToday(for: dog).reduce(0) { $0 + $1.durationMinutes }
    }

    private func percent(for dog: Dog) -> Double {
        let target = dog.dailyTargetMinutes
        guard target > 0 else { return 0 }
        return min(1.0, Double(minutesDone(for: dog)) / Double(target))
    }

    private func minutesToGo(for dog: Dog) -> Int {
        max(0, dog.dailyTargetMinutes - minutesDone(for: dog))
    }

    // MARK: - Date / time-of-day formatting

    private static func partOfDay(for date: Date) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<22: return "evening"
        default: return "night"
        }
    }

    private static func walksSectionTitle(for date: Date) -> String {
        "THIS \(partOfDay(for: date).uppercased())"
    }

    private static func dateLabel(for date: Date) -> String {
        Self.dateLabelFormatter.string(from: date)
    }

    private static let dateLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "EEE · d MMM"
        return formatter
    }()
}

private struct HomeHeader: View {
    let activeDogs: [Dog]
    let selectedDog: Dog
    let streakDays: Int
    let dateLabel: String
    let onSelectDog: (Dog) -> Void
    let onAddAnotherDog: () -> Void

    var body: some View {
        // Single row: dog selector pill on the left, date and streak chip
        // sharing the right side. The "+" walk button moved to the centre of
        // the bottom tab bar (Strava-style FAB), so the header has no trailing
        // action button now — keeps the top of the screen calm.
        HStack(spacing: Space.sm) {
            Menu {
                ForEach(activeDogs) { dog in
                    Button {
                        onSelectDog(dog)
                    } label: {
                        if dog.persistentModelID == selectedDog.persistentModelID {
                            Label(dog.name, systemImage: "checkmark")
                        } else {
                            Text(dog.name)
                        }
                    }
                }
                Divider()
                Button {
                    onAddAnotherDog()
                } label: {
                    Label("Add another dog", systemImage: "plus")
                }
            } label: {
                HStack(spacing: Space.xs) {
                    Text(selectedDog.name)
                        .font(.bodyLarge.weight(.semibold))
                        .foregroundStyle(Color.brandTextPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.brandTextSecondary)
                }
                .padding(.horizontal, Space.md)
                .frame(height: 40)
                .background(Color.brandSurfaceElevated)
                .clipShape(Capsule())
                .brandCardShadow()
            }
            .accessibilityLabel("Switch dog")

            Spacer()

            // Date + streak in one trailing chip cluster — no longer a full
            // row underneath the selector, so the whole header is a single
            // visual line.
            HStack(spacing: Space.xs) {
                Text(dateLabel)
                    .font(.caption.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(Color.brandTextSecondary)
                    .textCase(.uppercase)
                Text("·")
                    .foregroundStyle(Color.brandTextTertiary)
                StreakChip(streakDays: streakDays)
            }
        }
    }
}

/// Compact flame chip that lives inline with the date — replaces the old
/// full-width StreakAndDateRow card. Pulses when the streak increments so the
/// celebration moment still lands; collapses to a tertiary "Today's the day"
/// at zero streak.
private struct StreakChip: View {
    let streakDays: Int
    @State private var scale: CGFloat = 1.0

    var body: some View {
        Group {
            if streakDays == 0 {
                Text("Today's the day")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brandTextSecondary)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Color.brandPrimary)
                    Text(streakDays.pluralised("day"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.brandTextPrimary)
                }
            }
        }
        .scaleEffect(scale)
        .onChange(of: streakDays) { oldValue, newValue in
            guard newValue > oldValue else { return }
            withAnimation(.brandCelebration) { scale = 1.15 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                withAnimation(.brandCelebration) { scale = 1.0 }
            }
        }
        .accessibilityLabel(
            streakDays == 0
                ? "No streak yet."
                : "Streak: \(streakDays.pluralised("day"))."
        )
    }
}

/// Single hero element for Home: the dog photo (or a calm placeholder) cropped
/// to a circle, with a coral progress arc tracing the outer edge. Replaces the
/// stacked HeroPhoto + TodayProgressCard pair — saves vertical space and ties
/// the photo (visual identity) and the ring (status) into one element instead
/// of two unrelated cards. Tapping opens the PhotosPicker so users can add or
/// change the photo from Home directly.
private struct DogPresenceCard: View {
    let dog: Dog
    let partOfDay: String
    let minutesDone: Int
    let targetMinutes: Int
    let percent: Double
    let minutesToGo: Int

    @Environment(\.modelContext) private var modelContext
    @State private var photoItem: PhotosPickerItem?
    @State private var animatedPercent: Double = 0

    private let circleSize: CGFloat = 220
    private let strokeWidth: CGFloat = 10
    private let photoInset: CGFloat = 8

    var body: some View {
        VStack(spacing: Space.md) {
            Text("\(dog.name)'s \(partOfDay).")
                .font(.displayMedium)
                .foregroundStyle(Color.brandSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                ringWithPhoto
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)

            captionRow
        }
        .onAppear {
            withAnimation(.brandDefault) { animatedPercent = percent }
        }
        .onChange(of: percent) { _, newValue in
            withAnimation(.brandDefault) { animatedPercent = newValue }
        }
        .onChange(of: photoItem) { _, newItem in
            Task { await loadPhoto(from: newItem) }
        }
    }

    private var ringWithPhoto: some View {
        ZStack {
            // Track ring
            Circle()
                .stroke(Color.brandDivider, lineWidth: strokeWidth)

            // Progress arc (animated)
            Circle()
                .trim(from: 0, to: max(0, min(1, animatedPercent)))
                .stroke(
                    Color.brandPrimary,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Photo or placeholder, inset slightly so the ring breathes
            photoFill
                .frame(width: circleSize - strokeWidth - photoInset * 2,
                       height: circleSize - strokeWidth - photoInset * 2)
                .clipShape(Circle())
        }
        .frame(width: circleSize, height: circleSize)
        .brandCardShadow()
    }

    @ViewBuilder
    private var photoFill: some View {
        if let data = dog.photo, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            placeholderFill
        }
    }

    private var placeholderFill: some View {
        ZStack {
            // Warm radial wash so the placeholder reads as a designed surface
            // rather than a missing asset.
            RadialGradient(
                colors: [Color.brandSurfaceElevated, Color.brandSecondaryTint],
                center: .center,
                startRadius: 20,
                endRadius: 140
            )
            VStack(spacing: Space.xs) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(Color.brandSecondary.opacity(0.6))
                Text("Add \(dog.name)'s photo")
                    .font(.bodyMedium.weight(.semibold))
                    .foregroundStyle(Color.brandSecondary)
            }
        }
    }

    /// Single line: minutes + (status pill if today done, "X min to go" if not).
    /// The percent number is dropped — the ring already draws it. The dog-voice
    /// affirmation row above this card is hidden when target's met so we don't
    /// stack three "you're done" messages.
    private var captionRow: some View {
        HStack(spacing: Space.xs) {
            Text("\(minutesDone) of \(targetMinutes) min")
                .font(.bodyLarge.weight(.semibold))
                .foregroundStyle(Color.brandTextPrimary)
            Spacer()
            if percent >= 1.0 {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text("today done")
                        .font(.bodyMedium.weight(.semibold))
                }
                .foregroundStyle(Color.brandSuccess)
            } else {
                Text("\(minutesToGo) min to go")
                    .font(.bodyMedium)
                    .foregroundStyle(Color.brandTextSecondary)
            }
        }
    }

    private var accessibilityLabel: String {
        let photoState = dog.photo == nil ? "Add a photo of \(dog.name)" : "Change \(dog.name)'s photo"
        let progress = "Today: \(Int(min(1, percent) * 100)) percent."
        return "\(photoState). \(progress)"
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let raw = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: raw) else { return }
        let downscaled = image.downscaledJPEGData()
        await MainActor.run {
            dog.photo = downscaled
            try? modelContext.save()
        }
    }
}

/// Contextual one-line nudge in Trot's voice (about Luna, implicitly from her).
/// Driven by `DogVoiceService.dailyLine` — LLM-generated when available
/// (cached 24h via LLMService), templated fallback otherwise. The first paint
/// uses the templated value so there's no empty state, then async swaps in
/// the LLM line when it arrives. Visual treatment is deliberately understated
/// — a small leading dot + body text — so it reads as a voice rather than a
/// card.
private struct DailyDogVoiceRow: View {
    let dog: Dog
    @State private var line: String = ""

    var body: some View {
        HStack(alignment: .top, spacing: Space.sm) {
            Circle()
                .fill(Color.brandPrimary)
                .frame(width: 6, height: 6)
                .padding(.top, 8)
            Text(displayedLine)
                .font(.bodyLarge)
                .foregroundStyle(Color.brandTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(displayedLine)
        .task(id: dog.persistentModelID) {
            line = await DogVoiceService.dailyLine(for: dog)
        }
    }

    /// First-paint fallback before .task completes. Empty state is the
    /// templated line so users never see a blank row.
    private var displayedLine: String {
        line.isEmpty ? DogVoiceService.currentLine(for: dog) : line
    }
}

/// Render the WalkWindowTile only when the weather is actually saying
/// something useful — rain, drizzle, snow, fog, thunder. On clear/cloudy
/// days the WeatherMoodLayer behind everything already conveys the weather
/// and a card on top is duplicate information.
///
/// We re-read the postcode-cached forecast on appear (cheap — 30-min cache
/// in WeatherService) and decide locally; never blocks the main view.
private struct ConditionalWalkWindowTile: View {
    let dog: Dog
    @State private var shouldRender: Bool = false

    var body: some View {
        Group {
            if shouldRender {
                WalkWindowTile(dog: dog)
                    .transition(.opacity)
            } else {
                Color.clear.frame(height: 0)
            }
        }
        .task { await decide() }
    }

    private func decide() async {
        let postcode = UserPreferences.postcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !postcode.isEmpty else { return }

        // DEBUG override should always render the tile so we can QA it.
        #if DEBUG
        if let forced = DebugOverrides.weatherCategory {
            await MainActor.run {
                withAnimation(.brandDefault) {
                    shouldRender = noticeableCategories.contains(forced)
                }
            }
            return
        }
        #endif

        guard let location = await WeatherService.location(for: postcode) else { return }
        guard let forecast = await WeatherService.forecast(for: location) else { return }
        guard let current = forecast.snapshot(at: .now) else { return }
        await MainActor.run {
            withAnimation(.brandDefault) {
                shouldRender = noticeableCategories.contains(current.category)
            }
        }
    }

    private var noticeableCategories: Set<WeatherCategory> {
        [.drizzle, .rain, .snow, .thunder, .fog]
    }
}

private struct ProgressTrack: View {
    let percent: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.brandDivider)
                Capsule()
                    .fill(Color.brandSecondary)
                    .frame(width: geo.size.width * max(0, min(1, percent)))
            }
        }
    }
}

/// Visual day-strip showing today's walks against the dog's enabled walk windows.
/// Replaces the text walk list — the user feels the day at a glance.
///
/// Visual layers (back to front):
///   1. A flat track lane (the day, 5am-11pm) with rounded ends
///   2. Walk-window tints — full-track-height very-low-opacity coral bands
///      that read as "highlighted regions of the day" rather than chunky pills
///   3. Hour ticks every 2 hours along the bottom edge
///   4. Walks — solid coral pills at full track height
///   5. "Now" marker — a thin vertical pin with a small dot on top
///   6. Hour labels (6a, 10a, 2p, 6p, 10p) anchored at their real x-position
///
/// Range: 5am to 11pm (18 hours). Walks outside that range are clamped.
private struct TodayTimeline: View {
    let walks: [Walk]
    let walkWindows: [WalkWindow]
    let now: Date
    let onTapWalk: (Walk) -> Void

    private let startHour: Double = 5
    private let endHour: Double = 23
    private let trackHeight: CGFloat = 22
    private let labelHours: [Int] = [6, 10, 14, 18, 22]
    private let tickHours: [Int] = [6, 8, 10, 12, 14, 16, 18, 20, 22]

    private var hoursSpan: Double { endHour - startHour }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            // Drop the "TODAY" caption — the tab itself is called Today, so
            // the label was duplicating the screen name. The summary on the
            // right ("4 walks · 78 min") carries enough context on its own.
            HStack {
                Text(summary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brandTextSecondary)
                Spacer()
            }

            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    // 1. Track lane (the day)
                    RoundedRectangle(cornerRadius: trackHeight / 2)
                        .fill(Color.brandSurface)
                        .overlay {
                            RoundedRectangle(cornerRadius: trackHeight / 2)
                                .stroke(Color.brandDivider.opacity(0.7), lineWidth: 1)
                        }
                        .frame(height: trackHeight)

                    // 2. Walk-window tints — soft coral bands marking "the
                    //    times you said you'd walk." Clipped to the track so
                    //    the rounded ends bleed cleanly.
                    ForEach(enabledWindows, id: \.persistentModelID) { window in
                        let bounds = windowBounds(for: window.slot, in: geo.size.width)
                        Rectangle()
                            .fill(Color.brandPrimary.opacity(0.10))
                            .frame(width: max(bounds.width, 4), height: trackHeight)
                            .offset(x: bounds.x)
                    }

                    // 3. Walks — bold coral pills, the actual data.
                    ForEach(walks) { walk in
                        let bounds = walkBounds(for: walk, in: geo.size.width)
                        Button(action: { onTapWalk(walk) }) {
                            RoundedRectangle(cornerRadius: trackHeight / 2)
                                .fill(Color.brandPrimary)
                                .frame(width: max(bounds.width, 8), height: trackHeight)
                                .offset(x: bounds.x)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(walk.durationMinutes)-minute walk. Tap to edit.")
                    }

                    // Track-shape mask so window tints + walks can't bleed
                    // past the rounded lane. Applied to the whole ZStack via
                    // .mask below.
                }
                .mask {
                    RoundedRectangle(cornerRadius: trackHeight / 2)
                        .frame(height: trackHeight)
                }
                .overlay(alignment: .topLeading) {
                    // 4. Now marker — sits on top, ignoring the mask so the
                    //    pin head can extend a touch above the track.
                    let nowX = nowOffset(in: geo.size.width)
                    if nowX >= 0 && nowX <= geo.size.width {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(Color.brandTextPrimary)
                                .frame(width: 6, height: 6)
                            Capsule()
                                .fill(Color.brandTextPrimary.opacity(0.7))
                                .frame(width: 1.5, height: trackHeight)
                        }
                        .offset(x: nowX - 3, y: -3)
                        .accessibilityHidden(true)
                    }
                }
                .frame(height: trackHeight)
            }
            .frame(height: trackHeight)

            // 5. Hour labels anchored at real positions. GeometryReader picks
            //    up the actual width so 6a sits where 6am is, not where
            //    Spacer() decided.
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    ForEach(labelHours, id: \.self) { hour in
                        let x = positionX(forHour: Double(hour), width: geo.size.width)
                        Text(hourLabel(hour))
                            .font(.caption2)
                            .foregroundStyle(Color.brandTextTertiary)
                            .fixedSize()
                            .alignmentGuide(.leading) { d in d.width / 2 }
                            .offset(x: x)
                    }
                }
            }
            .frame(height: 14)
        }
        .padding(Space.md)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
    }

    private var enabledWindows: [WalkWindow] {
        walkWindows.filter(\.enabled)
    }

    private var summary: String {
        if walks.isEmpty {
            return "no walks yet"
        }
        let total = walks.reduce(0) { $0 + $1.durationMinutes }
        return "\(walks.count.pluralised("walk")) · \(total) min"
    }

    private func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0: return "12a"
        case 12: return "12p"
        case 1...11: return "\(hour)a"
        default: return "\(hour - 12)p"
        }
    }

    // MARK: - Position math

    /// X-pixel for a given hour on the timeline (no clamping — caller decides
    /// what to do with values outside the visible span).
    private func positionX(forHour hour: Double, width: CGFloat) -> CGFloat {
        let fraction = (hour - startHour) / hoursSpan
        return CGFloat(fraction) * width
    }

    private func windowBounds(for slot: WalkSlot, in width: CGFloat) -> (x: CGFloat, width: CGFloat) {
        let (start, end) = hourRange(for: slot)
        let xFraction = (start - startHour) / hoursSpan
        let widthFraction = (end - start) / hoursSpan
        return (CGFloat(xFraction) * width, CGFloat(widthFraction) * width)
    }

    private func hourRange(for slot: WalkSlot) -> (Double, Double) {
        switch slot {
        case .earlyMorning: return (5, 9)
        case .lunch: return (11, 14)
        case .afternoon: return (14, 18)
        case .evening: return (18, 22)
        }
    }

    private func walkBounds(for walk: Walk, in width: CGFloat) -> (x: CGFloat, width: CGFloat) {
        let cal = Calendar.current
        let hour = Double(cal.component(.hour, from: walk.startedAt))
        let minute = Double(cal.component(.minute, from: walk.startedAt))
        let startTime = hour + minute / 60
        let xFraction = max(0, min(1, (startTime - startHour) / hoursSpan))
        let widthFraction = Double(walk.durationMinutes) / 60.0 / hoursSpan
        let cappedWidth = min(widthFraction, 1 - xFraction)
        return (CGFloat(xFraction) * width, CGFloat(cappedWidth) * width)
    }

    private func nowOffset(in width: CGFloat) -> CGFloat {
        let cal = Calendar.current
        let hour = Double(cal.component(.hour, from: now))
        let minute = Double(cal.component(.minute, from: now))
        let nowTime = hour + minute / 60
        let xFraction = (nowTime - startHour) / hoursSpan
        return CGFloat(xFraction) * width
    }
}

private struct EmptyDogPlaceholder: View {
    var body: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "pawprint.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color.brandTextTertiary)
            Text("No dogs yet.")
                .font(.titleMedium)
                .foregroundStyle(Color.brandTextSecondary)
            Text("Add a dog to get started.")
                .font(.bodyMedium)
                .foregroundStyle(Color.brandTextTertiary)
        }
        .padding(Space.xl)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Dog.self, Walk.self, WalkWindow.self], inMemory: true)
}
