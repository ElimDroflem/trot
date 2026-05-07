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
    @State private var showingHomeRecap = false

    private var selectedDog: Dog? { appState.selectedDog(from: activeDogs) }

    var body: some View {
        TabView {
            todayTab
                .tabItem { Label("Today", systemImage: "house.fill") }

            ActivityView()
                .tabItem { Label("Activity", systemImage: "calendar") }

            JourneyView()
                .tabItem { Label("Journey", systemImage: "figure.walk.motion") }

            InsightsView()
                .tabItem { Label("Insights", systemImage: "lightbulb") }

            DogProfileView()
                .tabItem {
                    Label(selectedDog?.name ?? "Dog", systemImage: "dog.fill")
                }
        }
        .tint(.brandPrimary)
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
        .sheet(isPresented: $showingHomeRecap) {
            if let dog = selectedDog {
                RecapView(recap: RecapService.weekly(for: dog)) {
                    showingHomeRecap = false
                }
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

            if let dog = selectedDog {
                ScrollView {
                    VStack(spacing: Space.lg) {
                        HomeHeader(
                            activeDogs: activeDogs,
                            selectedDog: dog,
                            onSelectDog: { appState.select($0) },
                            onAddAnotherDog: { showingAddAnotherDog = true },
                            onStartWalk: { showingExpedition = true },
                            onLogPastWalk: { showingLogWalk = true }
                        )
                        StreakAndDateRow(
                            streakDays: StreakService.currentStreak(for: dog),
                            dateLabel: Self.dateLabel(for: .now)
                        )
                        DogPresenceCard(
                            dog: dog,
                            partOfDay: Self.partOfDay(for: .now),
                            minutesDone: minutesDone(for: dog),
                            targetMinutes: dog.dailyTargetMinutes,
                            percent: percent(for: dog),
                            minutesToGo: minutesToGo(for: dog)
                        )
                        TrotSaysLine(line: DogVoiceService.currentLine(for: dog))
                        TodayTimeline(
                            walks: walksToday(for: dog),
                            walkWindows: dog.walkWindows ?? [],
                            now: .now,
                            onTapWalk: { walk in editingWalk = walk }
                        )
                        WeeklyRecapTile(onTap: { showingHomeRecap = true })
                        Color.clear.frame(height: Space.lg)
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.top, Space.sm)
                }
            } else {
                EmptyDogPlaceholder()
            }
        }
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
    let onSelectDog: (Dog) -> Void
    let onAddAnotherDog: () -> Void
    let onStartWalk: () -> Void
    let onLogPastWalk: () -> Void

    var body: some View {
        HStack {
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
                .frame(height: 44)
                .background(Color.brandSurfaceElevated)
                .clipShape(Capsule())
                .brandCardShadow()
            }
            .accessibilityLabel("Switch dog")

            Spacer()

            Menu {
                Button(action: onStartWalk) {
                    Label("Start a walk", systemImage: "figure.walk")
                }
                Button(action: onLogPastWalk) {
                    Label("Log a past walk", systemImage: "clock.arrow.circlepath")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.brandTextOnPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.brandPrimary)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Add a walk")
        }
    }
}

/// Two layouts in one component:
///   - Promoted (streak in 1...6): vertical stack with the date as a small caption
///     and a wider, coral-tinted streak card below. Streak is the focus, since these
///     are the fragile early days where dropping a walk would hurt.
///   - Standard (streak == 0 or ≥7): side-by-side pills as before. At 0, the streak
///     pill becomes a calm "Today's the day" placeholder.
private struct StreakAndDateRow: View {
    let streakDays: Int
    let dateLabel: String

    @State private var scale: CGFloat = 1.0

    private var isPromoted: Bool { (1...6).contains(streakDays) }

    var body: some View {
        Group {
            if isPromoted {
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text(dateLabel)
                        .font(.caption.weight(.semibold))
                        .tracking(0.5)
                        .foregroundStyle(Color.brandTextSecondary)
                        .textCase(.uppercase)
                    promotedStreakCard
                }
            } else {
                HStack {
                    standardStreakPill
                    Spacer()
                    datePill
                }
            }
        }
        .scaleEffect(scale)
        .onChange(of: streakDays) { oldValue, newValue in
            // Increment-only pulse — burning-down doesn't deserve a celebration.
            guard newValue > oldValue else { return }
            withAnimation(.brandCelebration) { scale = 1.06 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                withAnimation(.brandCelebration) { scale = 1.0 }
            }
        }
    }

    private var promotedStreakCard: some View {
        HStack(spacing: Space.md) {
            Image(systemName: "flame.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.brandPrimary)
            VStack(alignment: .leading, spacing: 2) {
                Text(streakDays.pluralised("day"))
                    .font(.displayMedium)
                    .foregroundStyle(Color.brandTextPrimary)
                Text(promotedSubtitle)
                    .font(.bodyMedium)
                    .foregroundStyle(Color.brandTextSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brandPrimaryTint)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Streak: \(streakDays.pluralised("day")). \(promotedSubtitle)")
    }

    private var promotedSubtitle: String {
        switch streakDays {
        case 1: return "Day one. Build it from here."
        case 2: return "Two in a row."
        case 3: return "Three days. The habit is forming."
        case 4: return "Four days. Keep going."
        case 5: return "Five days. Almost a week."
        case 6: return "Six days. One more for the week."
        default: return ""
        }
    }

    @ViewBuilder
    private var standardStreakPill: some View {
        if streakDays == 0 {
            HStack(spacing: Space.xs) {
                Image(systemName: "flame")
                    .foregroundStyle(Color.brandTextSecondary)
                Text("Today's the day")
                    .font(.bodyMedium.weight(.semibold))
                    .foregroundStyle(Color.brandTextSecondary)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .background(Color.brandSurfaceElevated)
            .clipShape(Capsule())
            .brandCardShadow()
        } else {
            HStack(spacing: Space.xs) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Color.brandPrimary)
                Text(streakDays.pluralised("day"))
                    .font(.bodyMedium.weight(.semibold))
                    .foregroundStyle(Color.brandTextPrimary)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .background(Color.brandSurfaceElevated)
            .clipShape(Capsule())
            .brandCardShadow()
        }
    }

    private var datePill: some View {
        Text(dateLabel)
            .font(.bodyMedium.weight(.semibold))
            .foregroundStyle(Color.brandTextPrimary)
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .background(Color.brandSurfaceElevated)
            .clipShape(Capsule())
            .brandCardShadow()
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

    private var captionRow: some View {
        HStack(spacing: Space.xs) {
            Text("\(Int(min(1, percent) * 100))%")
                .font(.bodyLarge.weight(.semibold))
                .foregroundStyle(Color.brandPrimary)
            Text("·")
                .foregroundStyle(Color.brandTextTertiary)
            Text("\(minutesDone) of \(targetMinutes) min")
                .font(.bodyMedium)
                .foregroundStyle(Color.brandTextSecondary)
            Spacer()
            if percent < 1.0 {
                Text("\(minutesToGo) min to go")
                    .font(.bodyMedium)
                    .foregroundStyle(Color.brandTextSecondary)
            } else {
                Text("today done")
                    .font(.bodyMedium.weight(.semibold))
                    .foregroundStyle(Color.brandSuccess)
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
/// Driven by `DogVoiceService`. Visual treatment is deliberately understated — a
/// small leading dot + body text — so it reads as a voice rather than a card.
private struct TrotSaysLine: View {
    let line: String

    var body: some View {
        HStack(alignment: .top, spacing: Space.sm) {
            Circle()
                .fill(Color.brandPrimary)
                .frame(width: 6, height: 6)
                .padding(.top, 8)
            Text(line)
                .font(.bodyLarge)
                .foregroundStyle(Color.brandTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(line)
    }
}

/// Discoverable entry point for the weekly recap from the Today tab.
/// Subtle by design — the recap is a Sunday-evening ritual, not a constant
/// nag. This row keeps the surface aware of the recap year-round without
/// crowding the daily view.
private struct WeeklyRecapTile: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Space.sm) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brandPrimary)
                Text("This week's recap")
                    .font(.bodyMedium.weight(.semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brandTextTertiary)
            }
            .padding(.vertical, Space.sm)
            .padding(.horizontal, Space.md)
            .background(Color.brandSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .brandCardShadow()
        }
        .buttonStyle(.plain)
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
/// Replaces the text walk list — the user feels the day at a glance: where they
/// said they'd walk (window tints), what actually happened (coral segments),
/// and where "now" sits. Tapping a segment opens the existing edit sheet.
///
/// Range: 5am to 11pm (18 hours). Walks outside that range are clamped visually
/// (rare in practice). Today is the only day shown — historical days live in
/// the Activity tab.
private struct TodayTimeline: View {
    let walks: [Walk]
    let walkWindows: [WalkWindow]
    let now: Date
    let onTapWalk: (Walk) -> Void

    private let startHour: Double = 5
    private let endHour: Double = 23
    private let trackHeight: CGFloat = 28

    private var hoursSpan: Double { endHour - startHour }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack {
                Text("TODAY")
                    .font(.caption.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(Color.brandTextSecondary)
                Spacer()
                Text(summary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brandTextTertiary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track baseline
                    Capsule()
                        .fill(Color.brandDivider.opacity(0.6))
                        .frame(height: 4)

                    // Walk-window tints (where you planned to walk)
                    ForEach(enabledWindows, id: \.persistentModelID) { window in
                        let bounds = windowBounds(for: window.slot, in: geo.size.width)
                        Capsule()
                            .fill(Color.brandSecondaryTint)
                            .frame(width: max(bounds.width, 6), height: trackHeight - 8)
                            .offset(x: bounds.x)
                    }

                    // Walks (what actually happened)
                    ForEach(walks) { walk in
                        let bounds = walkBounds(for: walk, in: geo.size.width)
                        Button(action: { onTapWalk(walk) }) {
                            Capsule()
                                .fill(Color.brandPrimary)
                                .frame(width: max(bounds.width, 8), height: trackHeight)
                                .offset(x: bounds.x)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(walk.durationMinutes)-minute walk. Tap to edit.")
                    }

                    // Now marker
                    let nowX = nowOffset(in: geo.size.width)
                    if nowX >= 0 && nowX <= geo.size.width {
                        Capsule()
                            .fill(Color.brandTextPrimary.opacity(0.45))
                            .frame(width: 2, height: trackHeight + 8)
                            .offset(x: nowX - 1, y: -4)
                    }
                }
                .frame(height: trackHeight, alignment: .center)
            }
            .frame(height: trackHeight + 8)

            HStack {
                ForEach(hourLabels, id: \.self) { label in
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(Color.brandTextTertiary)
                    if label != hourLabels.last { Spacer() }
                }
            }
        }
        .padding(Space.md)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
    }

    private var enabledWindows: [WalkWindow] {
        walkWindows.filter(\.enabled)
    }

    private var hourLabels: [String] {
        ["6a", "10a", "2p", "6p", "10p"]
    }

    private var summary: String {
        if walks.isEmpty {
            return "no walks yet"
        }
        let total = walks.reduce(0) { $0 + $1.durationMinutes }
        return "\(walks.count.pluralised("walk")) · \(total) min"
    }

    // MARK: - Position math

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
