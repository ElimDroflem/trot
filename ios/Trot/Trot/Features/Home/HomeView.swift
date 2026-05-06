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
                            onAddWalk: { showingLogWalk = true }
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
                        RationaleCard(rationale: dog.llmRationale)
                        WalksSection(
                            sectionTitle: Self.walksSectionTitle(for: .now),
                            walks: walksToday(for: dog),
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
    let onAddWalk: () -> Void

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

            Button(action: onAddWalk) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.brandTextOnPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.brandPrimary)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Log a walk")
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

/// Evergreen breed-rationale tile per `docs/spec.md` → "First-week loop":
/// surfaces the personalised "why this target" line daily, not gated behind a
/// settings drill-in. Hides itself if the rationale is empty (defensive — a
/// pre-existing dog with no rationale recorded shouldn't render an empty card).
private struct RationaleCard: View {
    let rationale: String

    var body: some View {
        let trimmed = rationale.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            HStack(alignment: .top, spacing: Space.sm) {
                Image(systemName: "sparkle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brandSecondary)
                    .padding(.top, 2)
                Text(trimmed)
                    .font(.bodyMedium)
                    .foregroundStyle(Color.brandTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Space.md)
            .background(Color.brandSecondaryTint)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Why this target. \(trimmed)")
        }
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

private struct WalksSection: View {
    let sectionTitle: String
    let walks: [Walk]
    let onTapWalk: (Walk) -> Void

    var body: some View {
        if walks.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text(sectionTitle)
                    .font(.captionBold)
                    .tracking(0.5)
                    .foregroundStyle(Color.brandTextSecondary)

                ForEach(walks) { walk in
                    Button(action: { onTapWalk(walk) }) {
                        WalkRow(walk: walk)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Tap to edit or delete this walk.")
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.brandDefault, value: walks.count)
        }
    }
}

private struct WalkRow: View {
    let walk: Walk

    var body: some View {
        HStack(spacing: Space.md) {
            Image(systemName: glyphName)
                .font(.system(size: 18))
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 40, height: 40)
                .background(Color.brandPrimaryTint)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("\(walk.durationMinutes)-minute walk")
                    .font(.bodyLarge.weight(.semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                Text(subtitle)
                    .font(.bodyMedium)
                    .foregroundStyle(Color.brandTextSecondary)
            }

            Spacer()

            Text(statusText)
                .font(.bodyMedium.weight(.semibold))
                .foregroundStyle(statusColor)
        }
    }

    private var glyphName: String {
        // Passive walks were detected by HealthKit (the dog walked itself in iOS's eyes);
        // manual walks were a deliberate tap from the user.
        walk.source == .passive ? "figure.walk" : "hand.tap.fill"
    }

    private var subtitle: String {
        let timeText = Self.timeFormatter.string(from: walk.startedAt).lowercased()
        let sourceText = walk.source == .passive ? "Passive" : "Manual"
        return "\(timeText) · \(sourceText)"
    }

    private var statusText: String {
        walk.source == .passive ? "Confirmed" : "Logged"
    }

    private var statusColor: Color {
        .brandSuccess
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
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
