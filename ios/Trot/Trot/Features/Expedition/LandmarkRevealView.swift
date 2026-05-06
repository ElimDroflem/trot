import SwiftUI

/// Slide-in toast shown atop ExpeditionView when a landmark is crossed
/// mid-walk. Auto-dismisses on a timer driven by the parent view; this
/// component is purely presentational.
struct LandmarkRevealView: View {
    let landmark: Landmark

    var body: some View {
        HStack(spacing: Space.md) {
            ZStack {
                Circle()
                    .fill(Color.brandPrimaryTint)
                    .frame(width: 44, height: 44)
                Image(systemName: landmark.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.brandPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(landmark.name)
                    .font(.bodyLarge.weight(.semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                if !landmark.description.isEmpty {
                    Text(landmark.description)
                        .font(.caption)
                        .foregroundStyle(Color.brandTextSecondary)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .padding(Space.md)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .brandCardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Landmark unlocked: \(landmark.name). \(landmark.description)")
    }
}
