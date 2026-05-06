import SwiftUI

struct FormCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(title.uppercased())
                .font(.captionBold)
                .tracking(0.5)
                .foregroundStyle(Color.brandTextSecondary)
                .padding(.leading, Space.xs)

            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .background(Color.brandSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .brandCardShadow()
        }
    }
}

struct FormRow<Trailing: View>: View {
    let label: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Text(label)
                .font(.bodyLarge)
                .foregroundStyle(Color.brandTextPrimary)
            Spacer()
            trailing
                .font(.bodyLarge)
                .foregroundStyle(Color.brandTextPrimary)
        }
        .padding(.vertical, Space.sm)
    }
}

struct FormDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.brandDivider)
            .frame(height: 1)
    }
}
