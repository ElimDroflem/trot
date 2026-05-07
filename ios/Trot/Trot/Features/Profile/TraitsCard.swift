import SwiftUI

/// "What Luna's earned so far" — a visible collection of milestone-derived
/// achievements on the dog's profile. Drives the day-1 unlock-chain dopamine
/// the retention plan called for: every milestone a user crosses surfaces
/// here, stays here, and locked tiles tease what's next.
///
/// Pure-function over `Dog.firedMilestones` — no schema change. Each
/// `MilestoneCode` maps to a `Trait` (icon + title + flavour) via the
/// extension below. Locked tiles show a lock icon + "???"; tapping any tile
/// (locked or unlocked) opens `AchievementDetailSheet` with the requirement,
/// progress bar, and dog-centric body copy.
struct TraitsCard: View {
    let dog: Dog

    @State private var selectedCode: MilestoneCode?

    private let columns = [
        GridItem(.flexible(), spacing: Space.sm),
        GridItem(.flexible(), spacing: Space.sm),
        GridItem(.flexible(), spacing: Space.sm)
    ]

    private var unlocked: Set<MilestoneCode> {
        Set(dog.firedMilestones.compactMap { MilestoneCode(rawValue: $0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack {
                Text("ACHIEVEMENTS")
                    .font(.caption.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(Color.brandTextSecondary)
                Spacer()
                Text("\(unlocked.count) of \(MilestoneCode.allCases.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brandTextTertiary)
            }

            LazyVGrid(columns: columns, spacing: Space.sm) {
                ForEach(MilestoneCode.allCases, id: \.self) { code in
                    Button {
                        selectedCode = code
                    } label: {
                        TraitTile(code: code, isUnlocked: unlocked.contains(code))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Space.md)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
        .sheet(item: $selectedCode) { code in
            AchievementDetailSheet(
                code: code,
                isUnlocked: unlocked.contains(code),
                dog: dog
            )
        }
    }
}

extension MilestoneCode: Identifiable {
    var id: String { rawValue }
}

/// One achievement tile — square cell with icon and a 1-line title underneath.
/// Locked tiles show a lock icon + "???" to preserve the unlock surprise.
/// Tapping (handled by the parent) opens the detail sheet.
private struct TraitTile: View {
    let code: MilestoneCode
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? Color.brandPrimaryTint : Color.brandSurface)
                Circle()
                    .stroke(
                        isUnlocked ? Color.brandPrimary : Color.brandDivider,
                        lineWidth: isUnlocked ? 1.5 : 1
                    )
                Image(systemName: isUnlocked ? code.trait.symbolName : "lock.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isUnlocked ? Color.brandPrimary : Color.brandTextTertiary)
            }
            .frame(width: 56, height: 56)

            Text(isUnlocked ? code.trait.title : "???")
                .font(.captionBold)
                .foregroundStyle(isUnlocked ? Color.brandTextPrimary : Color.brandTextTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(height: 32, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            isUnlocked
                ? "Achievement unlocked: \(code.trait.title). \(code.trait.description). Tap for details."
                : "Locked achievement. Tap to see what's needed."
        )
    }
}

// MARK: - Trait mapping

extension MilestoneCode {
    /// Visible representation of the milestone — icon, short title, flavour
    /// line. Lives next to the milestone codes themselves rather than in a
    /// separate registry so adding a new code requires adding the trait too.
    struct Trait {
        let title: String
        let description: String
        let symbolName: String
    }

    var trait: Trait {
        switch self {
        case .firstWalk:
            return Trait(
                title: "First steps",
                description: "First walk together.",
                symbolName: "figure.walk"
            )
        case .firstHalfTargetDay:
            return Trait(
                title: "Warming up",
                description: "Hit half her daily target for the first time.",
                symbolName: "flame"
            )
        case .firstFullTargetDay:
            return Trait(
                title: "Full target",
                description: "Hit a daily target in full.",
                symbolName: "checkmark.seal.fill"
            )
        case .first100LifetimeMinutes:
            return Trait(
                title: "Hundred club",
                description: "100 lifetime minutes walked together.",
                symbolName: "100.circle.fill"
            )
        case .first3DayStreak:
            return Trait(
                title: "Three in a row",
                description: "Three days walked in a row.",
                symbolName: "flame.fill"
            )
        case .firstWeek:
            return Trait(
                title: "First week",
                description: "A full week with Trot.",
                symbolName: "calendar.badge.checkmark"
            )
        case .streak7Days:
            return Trait(
                title: "Week streak",
                description: "Seven days walked in a row.",
                symbolName: "flame.fill"
            )
        case .streak14Days:
            return Trait(
                title: "Two-week streak",
                description: "Two weeks straight.",
                symbolName: "flame.fill"
            )
        case .streak30Days:
            return Trait(
                title: "Month streak",
                description: "Thirty days. A real habit now.",
                symbolName: "flame.circle.fill"
            )
        }
    }
}
