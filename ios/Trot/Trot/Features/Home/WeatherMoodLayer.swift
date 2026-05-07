import SwiftUI

/// Subtle, full-bleed weather animation that lives behind the Today-tab content.
/// Reads the *current* hour from the cached Open-Meteo forecast (postcode-only,
/// no GPS) and renders one of:
///
///   - Clear / partly cloudy → warm radial wash + slowly drifting golden bokeh
///   - Cloudy → cool desaturated wash, no motion
///   - Fog → low-opacity horizontal bands drifting slowly
///   - Drizzle / rain → diagonal falling streaks at varying speeds
///   - Snow → falling flakes with horizontal drift
///   - Thunder → faster rain + occasional brightness pulse
///
/// All drawing is done in a single `Canvas` inside a `TimelineView(.animation)`
/// so there's one redraw per frame — no per-particle `View` to allocate, no
/// `withAnimation` chains to schedule. Particle positions are computed
/// deterministically from `seed + elapsed time` so we don't need any state.
///
/// `reduceMotion` flips animation off — the wash and tint stay so the mood
/// remains, but no particles animate.
///
/// Loading state: silent. While the forecast is loading we render nothing —
/// the existing brand-surface gradient under us is the calm fallback.
struct WeatherMoodLayer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var category: WeatherCategory?

    var body: some View {
        Group {
            if let category {
                content(for: category)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            } else {
                Color.clear
            }
        }
        .task { await load() }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func content(for category: WeatherCategory) -> some View {
        ZStack {
            wash(for: category)
            if !reduceMotion {
                particles(for: category)
            }
        }
    }

    // MARK: - Wash (always-on tint)

    @ViewBuilder
    private func wash(for category: WeatherCategory) -> some View {
        switch category {
        case .clear:
            RadialGradient(
                colors: [Color.brandPrimaryTint.opacity(0.55), .clear],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 480
            )
        case .partlyCloudy:
            RadialGradient(
                colors: [Color.brandPrimaryTint.opacity(0.35), .clear],
                center: .topTrailing,
                startRadius: 60,
                endRadius: 420
            )
        case .cloudy:
            LinearGradient(
                colors: [Color.brandSecondaryTint.opacity(0.35), .clear],
                startPoint: .top,
                endPoint: .center
            )
        case .fog:
            LinearGradient(
                colors: [Color.brandTextTertiary.opacity(0.25), .clear, Color.brandTextTertiary.opacity(0.18)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .drizzle, .rain:
            LinearGradient(
                colors: [Color.brandSecondary.opacity(0.18), .clear],
                startPoint: .top,
                endPoint: .center
            )
        case .snow:
            LinearGradient(
                colors: [Color.white.opacity(0.4), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        case .thunder:
            LinearGradient(
                colors: [Color.brandSecondary.opacity(0.30), .clear],
                startPoint: .top,
                endPoint: .center
            )
        }
    }

    // MARK: - Particles

    @ViewBuilder
    private func particles(for category: WeatherCategory) -> some View {
        switch category {
        case .clear:        SunBokehLayer()
        case .partlyCloudy: SunBokehLayer(intensity: 0.5)
        case .rain:         RainLayer(intensity: 1.0)
        case .drizzle:      RainLayer(intensity: 0.45)
        case .thunder:      RainLayer(intensity: 1.2, withFlash: true)
        case .snow:         SnowLayer()
        case .fog:          FogLayer()
        case .cloudy:       Color.clear
        }
    }

    // MARK: - Load

    private func load() async {
        let postcode = UserPreferences.postcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !postcode.isEmpty else { return }
        guard let location = await WeatherService.location(for: postcode) else { return }
        guard let forecast = await WeatherService.forecast(for: location) else { return }
        guard let current = forecast.snapshot(at: .now) else { return }
        await MainActor.run {
            withAnimation(.brandDefault) {
                category = current.category
            }
        }
    }
}

// MARK: - Sun bokeh (warm drifting dots)

private struct SunBokehLayer: View {
    var intensity: Double = 1.0
    private let dotCount = 10

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            Canvas { canvas, size in
                let t = context.date.timeIntervalSinceReferenceDate
                for i in 0..<dotCount {
                    let seed = Double(i) * 17.31
                    let x = ((sin(t * 0.05 + seed) + 1) / 2) * size.width
                    let y = ((cos(t * 0.04 + seed * 1.3) + 1) / 2) * size.height * 0.6
                    let radius = 6 + Double(i % 4) * 3
                    let alpha = 0.10 + 0.06 * Double((i % 3))
                    let rect = CGRect(
                        x: x - radius, y: y - radius,
                        width: radius * 2, height: radius * 2
                    )
                    let path = Path(ellipseIn: rect)
                    canvas.fill(
                        path,
                        with: .color(.orange.opacity(alpha * intensity))
                    )
                }
            }
        }
    }
}

// MARK: - Rain (diagonal streaks)

private struct RainLayer: View {
    var intensity: Double = 1.0
    var withFlash: Bool = false

    private var dropCount: Int { Int(70 * intensity) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            Canvas { canvas, size in
                let t = context.date.timeIntervalSinceReferenceDate
                for i in 0..<dropCount {
                    let seed = Double(i) * 0.6180339887
                    let xOffset = (seed.truncatingRemainder(dividingBy: 1.0)) * size.width
                    let speed = 220 + (seed.truncatingRemainder(dividingBy: 0.5)) * 200  // pts/sec
                    let cycle = (size.height + 80) / speed
                    let phase = (seed.truncatingRemainder(dividingBy: 1.0)) * cycle
                    let progress = (t + phase).truncatingRemainder(dividingBy: cycle) / cycle
                    let y = -40 + progress * (size.height + 80)
                    // Diagonal — drops fall slightly to the right.
                    let x = xOffset + progress * 30 - 15
                    let length: CGFloat = withFlash ? 16 : 12
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x + 4, y: y + length))
                    canvas.stroke(
                        path,
                        with: .color(.blue.opacity(0.28 * intensity)),
                        lineWidth: 1.2
                    )
                }

                if withFlash {
                    // Subtle flash on a slow cosine — never blinding, just a hint.
                    let flash = max(0, sin(t * 0.5))
                    if flash > 0.95 {
                        canvas.fill(
                            Path(CGRect(origin: .zero, size: size)),
                            with: .color(.white.opacity((flash - 0.95) * 0.6))
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Snow (slow falling flakes)

private struct SnowLayer: View {
    private let flakeCount = 40

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            Canvas { canvas, size in
                let t = context.date.timeIntervalSinceReferenceDate
                for i in 0..<flakeCount {
                    let seed = Double(i) * 0.6180339887
                    let xBase = (seed.truncatingRemainder(dividingBy: 1.0)) * size.width
                    let speed = 30 + (seed.truncatingRemainder(dividingBy: 0.5)) * 30
                    let cycle = (size.height + 40) / speed
                    let phase = (seed.truncatingRemainder(dividingBy: 1.0)) * cycle
                    let progress = (t + phase).truncatingRemainder(dividingBy: cycle) / cycle
                    let y = -20 + progress * (size.height + 40)
                    let drift = sin(t * 0.6 + seed * 3) * 18
                    let x = xBase + drift
                    let radius: CGFloat = 1.5 + CGFloat(i % 3) * 0.8
                    let rect = CGRect(
                        x: x - radius, y: y - radius,
                        width: radius * 2, height: radius * 2
                    )
                    canvas.fill(
                        Path(ellipseIn: rect),
                        with: .color(.white.opacity(0.75))
                    )
                }
            }
        }
    }
}

// MARK: - Fog (drifting horizontal bands)

private struct FogLayer: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
            Canvas { canvas, size in
                let t = context.date.timeIntervalSinceReferenceDate
                for i in 0..<4 {
                    let yFraction = 0.15 + Double(i) * 0.18
                    let drift = sin(t * 0.05 + Double(i) * 0.7) * 30
                    let bandHeight: CGFloat = 60
                    let y = size.height * yFraction + drift
                    let rect = CGRect(x: -40, y: y, width: size.width + 80, height: bandHeight)
                    canvas.fill(
                        Path(roundedRect: rect, cornerRadius: bandHeight / 2),
                        with: .color(.white.opacity(0.10))
                    )
                }
            }
        }
    }
}
