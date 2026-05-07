import SwiftUI

/// Detail card for a single achievement — shown when the user taps a tile
/// on the Profile achievements grid. Two layouts:
///
///   - **Locked:** big lock icon, the requirement (e.g. "Walk 100 minutes
///     total"), a progress bar with `current of target` underneath, and a
///     short flavour line tuned to how close they are.
///   - **Unlocked:** big coral icon, the dog-centric milestone title, the
///     longer body copy, and an "Unlocked" badge.
///
/// Presented modally from `AchievementsCard` (formerly TraitsCard).
struct AchievementDetailSheet: View {
    let code: MilestoneCode
    let isUnlocked: Bool
    let dog: Dog

    @Environment(\.dismiss) private var dismiss

    /// Computed once per sheet appearance — the underlying SwiftData fields
    /// don't change while the sheet is up.
    private var progress: UnlockProgress {
        code.progress(for: dog)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandSurface.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Space.lg) {
                        bigIcon
                        headerCopy
                        if isUnlocked {
                            unlockedBody
                        } else {
                            lockedBody
                        }
                        Spacer(minLength: Space.lg)
                    }
                    .padding(.horizontal, Space.lg)
                    .padding(.top, Space.xl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .tint(.brandPrimary)
                }
            }
        }
    }

    // MARK: - Pieces

    private var bigIcon: some View {
        ZStack {
            Circle()
                .fill(isUnlocked ? Color.brandPrimaryTint : Color.brandSurfaceElevated)
            Circle()
                .stroke(
                    isUnlocked ? Color.brandPrimary : Color.brandDivider,
                    lineWidth: isUnlocked ? 2 : 1
                )
            Image(systemName: isUnlocked ? code.trait.symbolName : "lock.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(isUnlocked ? Color.brandPrimary : Color.brandTextTertiary)
        }
        .frame(width: 140, height: 140)
        .padding(.top, Space.md)
    }

    private var headerCopy: some View {
        VStack(spacing: Space.xs) {
            Text(isUnlocked ? code.trait.title : "Locked")
                .font(.displayMedium)
                .foregroundStyle(Color.brandSecondary)
                .multilineTextAlignment(.center)
            if isUnlocked {
                Text("Unlocked")
                    .font(.caption.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(Color.brandTextOnPrimary)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, 4)
                    .background(Color.brandPrimary)
                    .clipShape(Capsule())
            }
        }
    }

    private var unlockedBody: some View {
        VStack(spacing: Space.md) {
            Text(code.title(dogName: dog.name))
                .font(.titleSmall)
                .foregroundStyle(Color.brandTextPrimary)
                .multilineTextAlignment(.center)
            Text(code.body(dogName: dog.name))
                .font(.bodyLarge)
                .foregroundStyle(Color.brandTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.sm)
        }
        .padding(.top, Space.sm)
    }

    private var lockedBody: some View {
        VStack(spacing: Space.lg) {
            Text(code.requirement)
                .font(.titleSmall)
                .foregroundStyle(Color.brandTextPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.sm)

            progressCard

            Text(nudgeLine)
                .font(.bodyMedium)
                .foregroundStyle(Color.brandTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.sm)
        }
        .padding(.top, Space.sm)
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack {
                Text("PROGRESS")
                    .font(.caption.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(Color.brandTextSecondary)
                Spacer()
                Text(progressLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brandPrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.brandDivider.opacity(0.6))
                    Capsule()
                        .fill(Color.brandPrimary)
                        .frame(width: geo.size.width * progress.percent)
                }
            }
            .frame(height: 10)
        }
        .padding(Space.md)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
    }

    // MARK: - Copy helpers

    /// "47 of 100 minutes" / "2 of 3 days" — pluralisation by current count
    /// (current is what reads, target sets the bar).
    private var progressLabel: String {
        let unit = pluralise(progress.unit, count: progress.target)
        return "\(progress.current) of \(progress.target) \(unit)"
    }

    /// Tone scales with how close the user is. Always factual, never naggy.
    private var nudgeLine: String {
        switch progress.percent {
        case 0:           return "Not started yet. Today's the day."
        case 0..<0.34:    return "Building from zero. Every walk counts toward this one."
        case 0.34..<0.67: return "Past the halfway mark."
        case 0.67..<1.0:  return "Almost there."
        default:          return "Ready to unlock — log a walk to claim it."
        }
    }

    /// Lightweight pluraliser. We only ever need to flip "minute" → "minutes"
    /// and "day" → "days" for these units, so a real localisation library is
    /// overkill — branch on the suffix.
    private func pluralise(_ unit: String, count: Int) -> String {
        guard count != 1 else { return unit }
        if unit.hasSuffix("s") { return unit }
        return unit + "s"
    }
}
