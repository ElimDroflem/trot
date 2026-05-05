import SwiftUI

struct TrotLogo: View {
    var size: CGFloat = 28
    var color: Color = .brandTextPrimary
    var dotColor: Color = .brandPrimary

    var body: some View {
        Text("Trot")
            .font(.custom("Bricolage Grotesque", size: size).weight(.bold))
            .tracking(size * -0.045)
            .foregroundStyle(color)
            .overlay(alignment: .leading) {
                Circle()
                    .fill(dotColor)
                    .frame(width: size * 0.18, height: size * 0.18)
                    .offset(x: size * 0.74, y: size * 0.04)
            }
            .accessibilityLabel("Trot")
    }
}

#Preview {
    VStack(spacing: 24) {
        TrotLogo(size: 28)
        TrotLogo(size: 48)
        TrotLogo(size: 72)
    }
    .padding(40)
    .background(Color.brandSurface)
}
