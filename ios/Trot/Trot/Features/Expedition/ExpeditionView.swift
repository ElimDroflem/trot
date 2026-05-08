import SwiftUI
import SwiftData
import Combine

/// Live-walk sheet — the heart of expedition mode. Replaces "Log a past walk"
/// for new walks. While open, a 1Hz timer drives:
///   - the elapsed-time display
///   - the live "X min to today's first/second page" countdown to the next
///     story milestone (50% target → page 1, 100% → page 2, then capped)
///   - mid-walk PAGE UNLOCKED toasts when this walk crosses a milestone
///
/// Time-based throughout — milestones unlock by accumulated minutes today,
/// not by estimated distance. Wall-clock time means backgrounding doesn't
/// lose progress.
///
/// Replaced May 2026 — earlier shape was driven by the now-removed Journey/
/// route system (landmarks unlocking with route progress).
struct ExpeditionView: View {
    let dog: Dog

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var state = ExpeditionState()
    @State private var showingFinishConfirm = false
    @State private var showingDiscardConfirm = false
    @State private var showingLogPast = false
    /// Mid-walk milestone toast state. Holds the milestone the user just
    /// crossed (`.halfTarget` for "PAGE 1 UNLOCKED", `.fullTarget` for
    /// "PAGE 2 UNLOCKED"). Cleared after a few seconds by the tick handler.
    @State private var visibleMilestone: StoryMilestoneToast?
    @State private var milestoneVisibleSince: Date?
    /// Set of milestone toasts already fired in this session, so we don't
    /// re-fire them every tick once the threshold's been crossed.
    @State private var firedMilestones: Set<StoryMilestoneToast> = []

    /// 1Hz tick — refreshes elapsedSeconds for the UI.
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.brandSurface.ignoresSafeArea()

                VStack(spacing: Space.lg) {
                    photoMarker
                        .padding(.top, Space.lg)

                    if state.hasStarted {
                        timerBlock
                        storyProgress
                    } else {
                        readyBlock
                    }

                    Spacer()

                    if state.hasStarted {
                        finishButton
                            .padding(.horizontal, Space.lg)
                            .padding(.bottom, Space.xl)
                    } else {
                        readyActions
                            .padding(.horizontal, Space.lg)
                            .padding(.bottom, Space.xl)
                    }
                }

                if let visibleMilestone {
                    StoryMilestoneToastView(milestone: visibleMilestone)
                        .padding(.horizontal, Space.md)
                        .padding(.top, Space.sm)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                }
            }
            .navigationTitle(state.hasStarted ? "Walking with \(dog.name)" : "Walk with \(dog.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if state.hasStarted {
                            showingDiscardConfirm = true
                        } else {
                            // No timer running, no walk to discard.
                            dismiss()
                        }
                    }
                    .tint(.brandPrimary)
                }
            }
        }
        .sheet(isPresented: $showingLogPast) {
            LogWalkSheet(dogs: [dog])
        }
        .interactiveDismissDisabled(state.elapsedSeconds > 0)
        .onReceive(tick) { _ in
            handleTick()
        }
        // Brand-styled bottom sheets replace the iOS-glass confirmation
        // dialogs. Same intent (Finish / Discard) but rendered on the
        // brand surface so they don't read as system chrome.
        .sheet(isPresented: $showingFinishConfirm) {
            BrandConfirmSheet(
                title: "End this walk?",
                message: "Save what \(dog.name) has done so far.",
                primary: .init(label: "Finish walk", role: .normal) { finishWalk() },
                secondary: .init(label: "Keep walking")
            )
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingDiscardConfirm) {
            BrandConfirmSheet(
                title: "Discard this walk?",
                message: "The time so far won't be saved.",
                primary: .init(label: "Discard", role: .destructive) { dismiss() },
                secondary: .init(label: "Keep walking")
            )
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Ready state

    /// Copy block shown before the user taps Start. The pulsing photo
    /// above + this block + the action buttons below give the page a
    /// real "ready when you are" beat.
    private var readyBlock: some View {
        VStack(spacing: Space.xs) {
            Text("Ready when you are")
                .font(.titleSmall)
                .foregroundStyle(Color.brandTextPrimary)
            Text("Tap start when you head out the door.")
                .font(.bodyMedium)
                .foregroundStyle(Color.brandTextSecondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Space.lg)
    }

    /// Bottom of the ready screen — primary Start button + a quiet
    /// "Log a past walk instead" link beneath. The link is plain text on
    /// purpose so the eye goes to the coral primary first.
    private var readyActions: some View {
        VStack(spacing: Space.md) {
            Button(action: startWalk) {
                HStack(spacing: Space.xs) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Start walk")
                        .font(.bodyLarge.weight(.semibold))
                }
                .foregroundStyle(Color.brandTextOnPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.md)
                .background(Color.brandPrimary)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            }
            Button(action: { showingLogPast = true }) {
                Text("Log a past walk instead")
                    .font(.bodyMedium.weight(.semibold))
                    .foregroundStyle(Color.brandPrimary)
                    .padding(.vertical, Space.sm)
            }
        }
    }

    private func startWalk() {
        withAnimation(.brandDefault) {
            state.start()
        }
    }

    // MARK: - Components

    private var photoMarker: some View {
        ZStack {
            Circle()
                .stroke(Color.brandDivider, lineWidth: 6)
                .frame(width: 160, height: 160)
            Circle()
                .stroke(Color.brandPrimary.opacity(0.6), lineWidth: 6)
                .frame(width: 160, height: 160)
                .scaleEffect(pulseScale)
                .opacity(pulseOpacity)
                .animation(
                    .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                    value: pulseScale
                )

            if let data = dog.photo, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 140, height: 140)
                    .clipShape(Circle())
            } else {
                Image(systemName: "dog.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.brandSecondary.opacity(0.6))
                    .frame(width: 140, height: 140)
                    .background(Color.brandSecondaryTint)
                    .clipShape(Circle())
            }
        }
    }

    /// Computed property used as an animation key so the pulse runs.
    private var pulseScale: CGFloat {
        state.elapsedSeconds % 2 == 0 ? 1.06 : 1.0
    }

    private var pulseOpacity: Double {
        state.elapsedSeconds % 2 == 0 ? 0.4 : 0.7
    }

    private var timerBlock: some View {
        VStack(spacing: Space.xs) {
            Text(formatTime(state.elapsedSeconds))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(Color.brandTextPrimary)
                .monospacedDigit()
            Text("with \(dog.name)")
                .font(.bodyMedium)
                .foregroundStyle(Color.brandTextSecondary)
        }
    }

    /// Story-mode progress strip during a live walk. Shows the current
    /// minutes-walked-today vs the dog's daily target with a single line
    /// caption naming the next milestone. Bar fills toward the next
    /// milestone (half-target until page 1; full-target until page 2;
    /// full once both pages today are accounted for).
    @ViewBuilder
    private var storyProgress: some View {
        let minutesNow = liveMinutesToday
        let target = max(1, dog.dailyTargetMinutes)
        let halfTarget = max(1, target / 2)
        let pagesToday = pagesGeneratedToday

        VStack(alignment: .leading, spacing: Space.sm) {
            HStack {
                Image(systemName: storyProgressIcon)
                    .foregroundStyle(Color.brandTextTertiary)
                Text(storyProgressCaption(
                    minutesNow: minutesNow,
                    target: target,
                    halfTarget: halfTarget,
                    pagesToday: pagesToday
                ))
                    .font(.bodyLarge.weight(.semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                Spacer()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.brandDivider.opacity(0.6))
                    Capsule()
                        .fill(Color.brandPrimary)
                        .frame(width: geo.size.width * storyProgressFraction(
                            minutesNow: minutesNow,
                            target: target,
                            halfTarget: halfTarget,
                            pagesToday: pagesToday
                        ))
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, Space.lg)
    }

    /// Icon for the story-progress caption. Lock when the next page is
    /// still gated, book once both are unlocked.
    private var storyProgressIcon: String {
        let minutesNow = liveMinutesToday
        let target = max(1, dog.dailyTargetMinutes)
        if pagesGeneratedToday >= 2 || (pagesGeneratedToday >= 1 && minutesNow >= target) {
            return "book.fill"
        }
        return "lock.fill"
    }

    private func storyProgressCaption(
        minutesNow: Int,
        target: Int,
        halfTarget: Int,
        pagesToday: Int
    ) -> String {
        if pagesToday >= 2 || (pagesToday >= 1 && minutesNow >= target) {
            return "Two pages today. Walk for the love of it."
        }
        if pagesToday == 0 {
            if minutesNow < halfTarget {
                return "\(halfTarget - minutesNow) min to today's first page"
            }
            // First page is already earnable; the second milestone is full.
            let needed = max(0, target - minutesNow)
            return "\(needed) min to today's second page"
        }
        // pagesToday == 1 — chasing page 2
        let needed = max(0, target - minutesNow)
        return "\(needed) min to today's second page"
    }

    /// Bar fraction. Anchors against the *next* milestone — fills toward
    /// half-target until that's hit, then full-target. After both pages
    /// are done, sits at 100%.
    private func storyProgressFraction(
        minutesNow: Int,
        target: Int,
        halfTarget: Int,
        pagesToday: Int
    ) -> Double {
        if pagesToday >= 2 || (pagesToday >= 1 && minutesNow >= target) {
            return 1.0
        }
        if pagesToday == 0 && minutesNow < halfTarget {
            return min(1, max(0, Double(minutesNow) / Double(halfTarget)))
        }
        return min(1, max(0, Double(minutesNow) / Double(target)))
    }

    private var finishButton: some View {
        Button(action: { showingFinishConfirm = true }) {
            Text("Finish walk")
                .font(.bodyLarge.weight(.semibold))
                .foregroundStyle(Color.brandTextOnPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.md)
                .background(Color.brandPrimary)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .disabled(state.elapsedSeconds < 5)
        .opacity(state.elapsedSeconds < 5 ? 0.5 : 1)
    }

    // MARK: - Tick handler (live progression + mid-walk milestone fires)

    private func handleTick() {
        // Skip everything until the user has tapped Start. Otherwise we'd
        // fire milestone toasts during the ready state with no walk logged.
        guard state.hasStarted else { return }
        state.tick()

        // Auto-dismiss milestone toast after ~3s.
        if let since = milestoneVisibleSince, Date.now.timeIntervalSince(since) >= 3 {
            withAnimation(.brandDefault) {
                visibleMilestone = nil
                milestoneVisibleSince = nil
            }
        }

        // Mid-walk milestone detection: live minutes-today (logged today
        // + minutes elapsed in this live session) crosses a story
        // threshold → fire the matching toast once.
        let minutesNow = liveMinutesToday
        let target = max(1, dog.dailyTargetMinutes)
        let halfTarget = max(1, target / 2)
        let pagesToday = pagesGeneratedToday

        // Page 1 — fires when the user crosses half-target AND no pages
        // have been generated today yet (otherwise the threshold has
        // already been earned, e.g. user generated page 1 yesterday-end
        // / today-morning before the live walk).
        if pagesToday == 0,
           minutesNow >= halfTarget,
           !firedMilestones.contains(.halfTarget) {
            firedMilestones.insert(.halfTarget)
            withAnimation(.brandCelebration) {
                visibleMilestone = .halfTarget
                milestoneVisibleSince = .now
            }
            return
        }

        // Page 2 — fires when the user crosses full-target AND has
        // already generated page 1 today (otherwise full-target on a
        // single big walk just unlocks page 1; page 2 needs a separate
        // commit-and-walk-on cycle).
        if pagesToday >= 1,
           minutesNow >= target,
           !firedMilestones.contains(.fullTarget) {
            firedMilestones.insert(.fullTarget)
            withAnimation(.brandCelebration) {
                visibleMilestone = .fullTarget
                milestoneVisibleSince = .now
            }
        }
    }

    // MARK: - Finish

    private func finishWalk() {
        // If somehow the user reaches finish without ever pressing Start
        // (shouldn't be possible — Finish is gated on `hasStarted`), use
        // `now` as a reasonable fallback so we save something rather than
        // crashing.
        let minutes = max(1, state.elapsedMinutes)

        // Snapshot story-mode state BEFORE we insert the walk. The
        // celebration overlay needs old vs new minutes-today so the bar
        // can animate the advance, and `pagesAlreadyToday` so the
        // PAGE UNLOCKED stamp distinguishes page 1 from page 2.
        let oldMinutesToday = minutesAlreadyToday
        let target = max(1, dog.dailyTargetMinutes)
        let pagesAlreadyToday = pagesGeneratedToday
        let isFirstWalk = (dog.walks ?? []).isEmpty

        let walk = Walk(
            startedAt: state.startedAt ?? .now,
            durationMinutes: minutes,
            distanceMeters: nil,
            source: .manual,
            notes: "",
            dogs: [dog]
        )
        modelContext.insert(walk)
        do {
            try modelContext.save()
        } catch {
            // Save failed — bail without enqueueing anything.
            dismiss()
            return
        }

        // Notifications + milestones (mirrors the LogWalkSheet save flow)
        Task { await NotificationService.reschedule(for: dog) }
        let new = MilestoneService.newMilestones(for: dog)
        if !new.isEmpty {
            MilestoneService.markFired(new, on: dog)
            appState.enqueueCelebrations(new, for: dog)
        }

        let payload = PendingWalkCompletePayload(
            dogID: dog.persistentModelID,
            dogName: dog.name.isEmpty ? "Your dog" : dog.name,
            isFirstWalk: isFirstWalk,
            oldMinutesToday: oldMinutesToday,
            newMinutesToday: oldMinutesToday + minutes,
            targetMinutes: target,
            pagesAlreadyToday: pagesAlreadyToday
        )

        // Enqueue BEFORE dismiss so the overlay is already queued by the
        // time the sheet animates away — the dismissal reveals it from
        // underneath in one continuous motion. (Earlier code did
        // dismiss + 350ms wait + enqueue, which felt like the
        // celebration only arrived after the sheet had closed.)
        appState.pendingWalkCompletes.append(payload.makeEvent(minutes: minutes))
        dismiss()
    }

    // MARK: - Helpers

    /// Minutes already walked today across all walks (excluding this live
    /// session). Read off `dog.walks`. Used to compute story-mode
    /// thresholds during the live tick AND for the celebration payload.
    private var minutesAlreadyToday: Int {
        let calendar = Calendar.current
        let now = Date.now
        return (dog.walks ?? [])
            .filter { calendar.isDate($0.startedAt, inSameDayAs: now) }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    /// Total minutes today INCLUDING the in-progress live session. This
    /// is what drives the live story-progress strip + mid-walk milestone
    /// toast detection.
    private var liveMinutesToday: Int {
        minutesAlreadyToday + state.elapsedMinutes
    }

    /// Story pages already generated today. Drives the milestone gating
    /// logic (page 1 = first half-target crossing; page 2 = full target
    /// AFTER page 1 already exists).
    private var pagesGeneratedToday: Int {
        let calendar = Calendar.current
        let now = Date.now
        let pages = (dog.story?.chapters ?? []).flatMap { $0.pages ?? [] }
        return pages.filter { calendar.isDate($0.createdAt, inSameDayAs: now) }.count
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Story milestone toast

/// Mid-walk celebration toast. Distinguishes which milestone was just
/// crossed so the toast headline is right ("PAGE 1 UNLOCKED" vs "PAGE 2
/// UNLOCKED"). Replaces the old landmark-name reveal toast.
enum StoryMilestoneToast: Hashable {
    case halfTarget
    case fullTarget

    var headline: String {
        switch self {
        case .halfTarget: return "PAGE 1 UNLOCKED"
        case .fullTarget: return "PAGE 2 UNLOCKED"
        }
    }

    var subline: String {
        switch self {
        case .halfTarget: return "Open the Story tab to read it."
        case .fullTarget: return "Both of today's pages are in."
        }
    }
}

private struct StoryMilestoneToastView: View {
    let milestone: StoryMilestoneToast

    var body: some View {
        HStack(spacing: Space.md) {
            ZStack {
                Circle()
                    .fill(Color.brandPrimaryTint)
                    .frame(width: 44, height: 44)
                Image(systemName: "book.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.brandPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.headline)
                    .font(.caption.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.brandPrimary)
                Text(milestone.subline)
                    .font(.caption)
                    .foregroundStyle(Color.brandTextSecondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(Space.md)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .brandCardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(milestone.headline). \(milestone.subline)")
    }
}
