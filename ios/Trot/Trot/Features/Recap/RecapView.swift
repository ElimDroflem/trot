import SwiftUI

/// Weekly-recap sheet per `docs/spec.md` → "6. Weekly recap as a fixed ritual."
/// A celebratory ritual surface, not a dashboard — Bricolage Grotesque headline,
/// dog photo as the hero, the week's numbers, comparison to last week, streak,
/// and one insight.
struct RecapView: View {
    let recap: WeeklyRecap
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.brandSurface.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Space.lg) {
                    header
                    photo
                    statsCard
                    if recap.hasComparison {
                        comparisonRow
                    }
                    streakAndInsightStack
                    Color.clear.frame(height: Space.xl)
                }
                .padding(.horizontal, Space.md)
                .padding(.top, Space.md)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onDismiss) {
                Text("Done")
                    .font(.bodyLarge.weight(.semibold))
                    .foregroundStyle(Color.brandTextOnPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.md)
                    .background(Color.brandPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            }
            .padding(.horizontal, Space.md)
            .padding(.bottom, Space.sm)
            .background(Color.brandSurface)
        }
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.brandCelebration.delay(0.05)) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("This week")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brandTextTertiary)
                .textCase(.uppercase)
            Text("\(recap.dogName)'s week.")
                .font(.displayMedium)
                .foregroundStyle(Color.brandSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var photo: some View {
        ZStack {
            Circle()
                .fill(Color.brandSecondaryTint)
                .frame(width: 160, height: 160)

            if let data = recap.photo, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 160)
                    .clipShape(Circle())
            } else {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.brandSecondary.opacity(0.5))
            }
        }
        .overlay { Circle().stroke(Color.brandDivider, lineWidth: 1) }
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            statColumn(
                value: "\(recap.thisWeek.totalMinutes)",
                label: "minutes"
            )
            Divider().frame(height: 36).overlay(Color.brandDivider)
            statColumn(
                value: "\(Int(round(recap.thisWeek.percentNeedsMet * 100)))%",
                label: "needs met"
            )
            Divider().frame(height: 36).overlay(Color.brandDivider)
            statColumn(
                value: "\(recap.thisWeek.walkCount)",
                label: recap.thisWeek.walkCount == 1 ? "walk" : "walks"
            )
        }
        .padding(.vertical, Space.md)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.titleLarge)
                .foregroundStyle(Color.brandSecondary)
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.brandTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var comparisonRow: some View {
        let descriptor = comparisonDescriptor()
        return HStack(spacing: Space.sm) {
            Image(systemName: descriptor.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(descriptor.color)
            Text(descriptor.phrase)
                .font(.bodyMedium)
                .foregroundStyle(Color.brandTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Space.md)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .brandCardShadow()
    }

    private struct ComparisonDescriptor {
        let symbol: String
        let color: Color
        let phrase: String
    }

    private func comparisonDescriptor() -> ComparisonDescriptor {
        let delta = recap.minutesDelta
        if delta > 0 {
            return ComparisonDescriptor(
                symbol: "arrow.up.right",
                color: .brandSuccess,
                phrase: "\(delta) minutes more than last week."
            )
        }
        if delta < 0 {
            return ComparisonDescriptor(
                symbol: "arrow.down.right",
                color: .brandWarning,
                phrase: "\(abs(delta)) minutes less than last week."
            )
        }
        return ComparisonDescriptor(
            symbol: "equal",
            color: .brandTextSecondary,
            phrase: "Held steady against last week."
        )
    }

    private var streakAndInsightStack: some View {
        VStack(spacing: Space.md) {
            row(
                icon: "flame",
                title: "Streak",
                detail: streakDetail
            )
            if let insight = recap.featuredInsight {
                row(
                    icon: "sparkle",
                    title: insight.title,
                    detail: insight.body
                )
            }
        }
    }

    private func row(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Space.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.brandSecondary)
                .frame(width: 20)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.bodyMedium.weight(.semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                Text(detail)
                    .font(.bodyMedium)
                    .foregroundStyle(Color.brandTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Space.md)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .brandCardShadow()
    }

    private var streakDetail: String {
        if recap.streakDays == 0 {
            return "No active streak. Today's a good day to start."
        }
        return "\(recap.streakDays.pluralised("day"))."
    }
}

#Preview {
    RecapView(
        recap: WeeklyRecap(
            thisWeek: WeekStats(totalMinutes: 320, percentNeedsMet: 0.78, walkCount: 6),
            lastWeek: WeekStats(totalMinutes: 240, percentNeedsMet: 0.6, walkCount: 5),
            streakDays: 5,
            featuredInsight: Insight(title: "When you walk", body: "Most walks happen in the morning. 67% so far."),
            photo: nil,
            dogName: "Luna"
        ),
        onDismiss: {}
    )
}
