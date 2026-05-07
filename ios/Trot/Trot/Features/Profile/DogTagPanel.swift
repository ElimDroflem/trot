import SwiftUI

/// "Player card" for the dog. Sits below the photo header on the Dog tab and
/// gives the user a glanceable summary of who their dog is — same vibe as
/// the back of a baseball card. Replaces the old form-list of Basics /
/// Activity / Health cards on the Dog tab; the full editable surface lives
/// in `DogSettingsSheet` now.
///
/// Layout:
///   - Hero strip: lifetime walks + lifetime minutes side-by-side. Big numbers,
///     "since" caption underneath, the career-stat feel.
///   - 2×2 stat grid: Age, Weight, Daily target, Activity level. Each tile
///     gets an icon, big value, small label.
struct DogTagPanel: View {
    let dog: Dog

    private let columns = [
        GridItem(.flexible(), spacing: Space.sm),
        GridItem(.flexible(), spacing: Space.sm),
    ]

    var body: some View {
        VStack(spacing: Space.sm) {
            heroStrip

            LazyVGrid(columns: columns, spacing: Space.sm) {
                StatTile(
                    icon: "calendar",
                    tint: .brandPrimary,
                    value: ageValue,
                    unit: ageUnit,
                    label: "Age"
                )
                StatTile(
                    icon: "scalemass.fill",
                    tint: .brandSecondary,
                    value: weightValue,
                    unit: "kg",
                    label: "Weight"
                )
                StatTile(
                    icon: "target",
                    tint: .brandPrimary,
                    value: "\(dog.dailyTargetMinutes)",
                    unit: "min/day",
                    label: "Daily target"
                )
                StatTile(
                    icon: activityIcon,
                    tint: activityTint,
                    value: activityLabel,
                    unit: "",
                    label: "Activity"
                )
            }
        }
    }

    // MARK: - Hero strip (lifetime stats)

    private var heroStrip: some View {
        HStack(spacing: Space.sm) {
            heroColumn(
                value: "\(lifetimeWalks)",
                label: lifetimeWalks == 1 ? "WALK" : "WALKS"
            )
            heroColumn(
                value: "\(lifetimeMinutes)",
                label: "MINUTES"
            )
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(Color.brandPrimaryTint)
        )
    }

    private func heroColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.displayLarge)
                .foregroundStyle(Color.brandTextPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(Color.brandTextSecondary)
        }
        .padding(.vertical, Space.md)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Derivations

    private var lifetimeWalks: Int { (dog.walks ?? []).count }
    private var lifetimeMinutes: Int { (dog.walks ?? []).reduce(0) { $0 + $1.durationMinutes } }

    private var ageValue: String {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: dog.dateOfBirth, to: .now)
        let years = comps.year ?? 0
        if years == 0 { return "\(max(0, comps.month ?? 0))" }
        return "\(years)"
    }

    private var ageUnit: String {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: dog.dateOfBirth, to: .now)
        let years = comps.year ?? 0
        if years == 0 { return "mo" }
        return years == 1 ? "yr" : "yrs"
    }

    private var weightValue: String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: dog.weightKg)) ?? "\(dog.weightKg)"
    }

    private var activityLabel: String {
        switch dog.activityLevel {
        case .low: return "Low"
        case .moderate: return "Mod."
        case .high: return "High"
        }
    }

    private var activityIcon: String {
        switch dog.activityLevel {
        case .low: return "leaf.fill"
        case .moderate: return "figure.walk"
        case .high: return "bolt.fill"
        }
    }

    private var activityTint: Color {
        switch dog.activityLevel {
        case .low: return .brandSecondary
        case .moderate: return .brandPrimary
        case .high: return .brandPrimary
        }
    }
}

// MARK: - Stat tile (also reusable elsewhere if we ever want it)

private struct StatTile: View {
    let icon: String
    let tint: Color
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 26, height: 26)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.displayMedium)
                    .foregroundStyle(Color.brandTextPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.brandTextTertiary)
                }
            }
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(Color.brandTextSecondary)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value) \(unit)")
    }
}
