import SwiftUI

/// Full-bleed atmospheric weather layer that lives behind the main content.
/// Reads the current hour from the cached Open-Meteo forecast (postcode-only,
/// no GPS) and themes the screen accordingly.
///
/// Visual stack (back to front):
///   1. Sky gradient — top 55% of the screen, weather + day/night driven
///   2. Sun disc OR cloud bank, depending on category
///   3. Particle layer (rain, snow, fog, lightning)
///
/// All animation runs inside ONE `Canvas` per particle layer wrapped in a
/// `TimelineView(.animation)` — single redraw per frame, no per-particle
/// `View`. Particle positions are deterministic from `seed + elapsed time`
/// so we don't need any state per particle.
///
/// Reduce-motion: keeps the sky + sun disc + clouds (atmosphere stays), drops
/// rain/snow/lightning (motion-heavy).
///
/// We force light mode in v1, so the night palette is a *softened dusk*,
/// never a fully dark screen — the brand surface still reads through.
///
/// Loading state: silent. Render nothing until the forecast lands so we never
/// flash a mood that's about to change.
struct WeatherMoodLayer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var snapshot: HourlySnapshot?

    var body: some View {
        Group {
            if let snapshot {
                content(for: snapshot)
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
    private func content(for snapshot: HourlySnapshot) -> some View {
        let category = snapshot.category
        let isDay = snapshot.isDay
        ZStack {
            SkyGradient(category: category, isDay: isDay)

            // Atmospheric mid-layer (sun OR clouds OR neither). These sit
            // behind the foreground particles so rain falls through them.
            switch category {
            case .clear:
                SunDisc(isDay: isDay, intensity: 1.0)
            case .partlyCloudy:
                ZStack {
                    SunDisc(isDay: isDay, intensity: 0.7)
                    CloudBank(density: 0.4, windSpeedKmh: snapshot.windSpeedKmh, tint: cloudTint(isDay: isDay))
                }
            case .cloudy:
                CloudBank(density: 0.85, windSpeedKmh: snapshot.windSpeedKmh, tint: cloudTint(isDay: isDay))
            case .fog:
                FogLayer()
            case .drizzle, .rain, .thunder:
                CloudBank(density: 0.95, windSpeedKmh: snapshot.windSpeedKmh, tint: stormCloudTint())
            case .snow:
                CloudBank(density: 0.6, windSpeedKmh: snapshot.windSpeedKmh, tint: cloudTint(isDay: isDay))
            }

            // Foreground particles — gated on reduce-motion since these are
            // the motion-heavy bits.
            if !reduceMotion {
                particles(for: category)
            }
        }
    }

    @ViewBuilder
    private func particles(for category: WeatherCategory) -> some View {
        switch category {
        case .rain:    RainLayer(intensity: 1.0)
        case .drizzle: RainLayer(intensity: 0.45)
        case .thunder: ZStack {
            RainLayer(intensity: 1.2)
            LightningLayer()
        }
        case .snow:    SnowLayer()
        default:       Color.clear
        }
    }

    // MARK: - Cloud tint helpers

    private func cloudTint(isDay: Bool) -> Color {
        isDay ? Color.white.opacity(0.85) : Color(red: 0.92, green: 0.88, blue: 0.95).opacity(0.75)
    }

    private func stormCloudTint() -> Color {
        Color(red: 0.40, green: 0.43, blue: 0.50).opacity(0.55)
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
                snapshot = current
            }
        }
    }
}

// MARK: - Sky gradient (the always-on atmosphere)

/// Top-down gradient covering roughly the top 55% of the screen. The colour
/// stops are chosen per (category × isDay) so morning sun feels different
/// from a dusk overcast. Bottom of the screen always fades to clear so the
/// brand-surface gradient under us still reads.
private struct SkyGradient: View {
    let category: WeatherCategory
    let isDay: Bool

    var body: some View {
        LinearGradient(
            colors: stops,
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var stops: [Color] {
        switch (category, isDay) {
        case (.clear, true):
            return [
                Color(red: 0.62, green: 0.84, blue: 0.96).opacity(0.65),
                Color(red: 0.92, green: 0.78, blue: 0.55).opacity(0.30),
                .clear,
            ]
        case (.clear, false):
            // Dusk: pinks and warm purples. Still bright at the bottom because
            // we force light mode.
            return [
                Color(red: 0.78, green: 0.62, blue: 0.78).opacity(0.55),
                Color(red: 0.96, green: 0.74, blue: 0.62).opacity(0.35),
                .clear,
            ]
        case (.partlyCloudy, true):
            return [
                Color(red: 0.68, green: 0.82, blue: 0.92).opacity(0.55),
                Color(red: 0.94, green: 0.86, blue: 0.72).opacity(0.20),
                .clear,
            ]
        case (.partlyCloudy, false):
            return [
                Color(red: 0.65, green: 0.62, blue: 0.78).opacity(0.45),
                Color(red: 0.92, green: 0.78, blue: 0.68).opacity(0.20),
                .clear,
            ]
        case (.cloudy, _):
            return [
                Color(red: 0.66, green: 0.70, blue: 0.78).opacity(0.55),
                Color(red: 0.78, green: 0.80, blue: 0.84).opacity(0.30),
                .clear,
            ]
        case (.fog, _):
            return [
                Color(red: 0.82, green: 0.82, blue: 0.84).opacity(0.55),
                Color(red: 0.86, green: 0.86, blue: 0.86).opacity(0.30),
                .clear,
            ]
        case (.drizzle, _), (.rain, _):
            return [
                Color(red: 0.42, green: 0.50, blue: 0.62).opacity(0.55),
                Color(red: 0.58, green: 0.65, blue: 0.75).opacity(0.30),
                .clear,
            ]
        case (.thunder, _):
            return [
                Color(red: 0.32, green: 0.34, blue: 0.46).opacity(0.65),
                Color(red: 0.48, green: 0.50, blue: 0.62).opacity(0.30),
                .clear,
            ]
        case (.snow, _):
            return [
                Color(red: 0.84, green: 0.88, blue: 0.94).opacity(0.65),
                Color(red: 0.94, green: 0.96, blue: 0.98).opacity(0.30),
                .clear,
            ]
        }
    }
}

// MARK: - Sun disc

/// Soft sun in the top-right with a halo and slowly rotating rays. Day version
/// is a warm gold; dusk is pinker. Pure SwiftUI — no images.
private struct SunDisc: View {
    let isDay: Bool
    var intensity: Double = 1.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            Canvas { canvas, size in
                let t = context.date.timeIntervalSinceReferenceDate
                // Anchor the sun in the top-right at ~75% width, ~22% height.
                let centre = CGPoint(x: size.width * 0.78, y: size.height * 0.18)
                let coreRadius: CGFloat = 36
                let haloRadius: CGFloat = 110

                // Soft halo (radial gradient drawn as concentric circles)
                let haloRect = CGRect(
                    x: centre.x - haloRadius, y: centre.y - haloRadius,
                    width: haloRadius * 2, height: haloRadius * 2
                )
                canvas.fill(
                    Path(ellipseIn: haloRect),
                    with: .color(haloColor.opacity(0.16 * intensity))
                )
                let midRect = haloRect.insetBy(dx: 28, dy: 28)
                canvas.fill(
                    Path(ellipseIn: midRect),
                    with: .color(haloColor.opacity(0.20 * intensity))
                )

                // Slow rotating rays — 8 thin lines fanning out from the core.
                let rotation = t * 0.18
                let rayInner: CGFloat = coreRadius + 6
                let rayOuter: CGFloat = coreRadius + 56
                for i in 0..<8 {
                    let angle = rotation + Double(i) * (.pi / 4)
                    let p1 = CGPoint(
                        x: centre.x + cos(angle) * rayInner,
                        y: centre.y + sin(angle) * rayInner
                    )
                    let p2 = CGPoint(
                        x: centre.x + cos(angle) * rayOuter,
                        y: centre.y + sin(angle) * rayOuter
                    )
                    var path = Path()
                    path.move(to: p1)
                    path.addLine(to: p2)
                    canvas.stroke(
                        path,
                        with: .color(coreColor.opacity(0.18 * intensity)),
                        lineWidth: 2
                    )
                }

                // Core disc
                let coreRect = CGRect(
                    x: centre.x - coreRadius, y: centre.y - coreRadius,
                    width: coreRadius * 2, height: coreRadius * 2
                )
                canvas.fill(
                    Path(ellipseIn: coreRect),
                    with: .color(coreColor.opacity(0.85 * intensity))
                )
            }
        }
    }

    private var coreColor: Color {
        isDay
            ? Color(red: 0.99, green: 0.85, blue: 0.45)
            : Color(red: 0.99, green: 0.62, blue: 0.48)  // dusk pink
    }

    private var haloColor: Color {
        isDay
            ? Color(red: 0.99, green: 0.78, blue: 0.42)
            : Color(red: 0.96, green: 0.55, blue: 0.65)
    }
}

// MARK: - Cloud bank (drifting puffs)

/// Several soft cloud shapes drifting horizontally. Density controls how many
/// clouds and how big they are; wind-speed controls drift rate. Each cloud is
/// drawn as a cluster of overlapping circles for a soft puffy look.
private struct CloudBank: View {
    var density: Double = 0.6
    var windSpeedKmh: Double = 8
    var tint: Color = .white

    private var cloudCount: Int { max(2, Int(density * 6)) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            Canvas { canvas, size in
                let t = context.date.timeIntervalSinceReferenceDate
                // pts/sec — tied to wind speed, with a sensible floor so even
                // a still day has gentle motion.
                let baseSpeed = max(8, windSpeedKmh * 1.6)

                for i in 0..<cloudCount {
                    let seed = Double(i) * 0.6180339887
                    let yFraction = 0.05 + (seed.truncatingRemainder(dividingBy: 0.45))
                    let scale = 0.7 + (seed.truncatingRemainder(dividingBy: 0.6))
                    // Each cloud has its own speed multiplier so they don't
                    // travel in lockstep.
                    let speed = baseSpeed * (0.7 + (seed.truncatingRemainder(dividingBy: 0.5)))
                    let cycleWidth = size.width + 320  // off-screen on both sides
                    let xOffset = (t * speed + seed * 800).truncatingRemainder(dividingBy: cycleWidth)
                    let x = -160 + xOffset
                    let y = size.height * yFraction

                    drawPuff(in: &canvas, at: CGPoint(x: x, y: y), scale: scale, tint: tint, alpha: 0.55 * density)
                }
            }
        }
    }

    private func drawPuff(in canvas: inout GraphicsContext, at centre: CGPoint, scale: Double, tint: Color, alpha: Double) {
        // A cloud is 5 overlapping circles. Sizes/offsets chosen empirically
        // to look "puffy" rather than mathematical.
        let lobes: [(dx: Double, dy: Double, r: Double)] = [
            (-32,  4, 22),
            (-12, -6, 30),
            (  8, -10, 26),
            ( 28, -2, 24),
            ( 44,  6, 20),
        ]
        for lobe in lobes {
            let r = lobe.r * scale
            let rect = CGRect(
                x: centre.x + lobe.dx * scale - r,
                y: centre.y + lobe.dy * scale - r,
                width: r * 2,
                height: r * 2
            )
            canvas.fill(
                Path(ellipseIn: rect),
                with: .color(tint.opacity(alpha))
            )
        }
    }
}

// MARK: - Rain (diagonal streaks)

private struct RainLayer: View {
    var intensity: Double = 1.0

    private var dropCount: Int { Int(90 * intensity) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            Canvas { canvas, size in
                let t = context.date.timeIntervalSinceReferenceDate
                for i in 0..<dropCount {
                    let seed = Double(i) * 0.6180339887
                    let xOffset = (seed.truncatingRemainder(dividingBy: 1.0)) * size.width
                    let speed = 240 + (seed.truncatingRemainder(dividingBy: 0.5)) * 220
                    let cycle = (size.height + 80) / speed
                    let phase = (seed.truncatingRemainder(dividingBy: 1.0)) * cycle
                    let progress = (t + phase).truncatingRemainder(dividingBy: cycle) / cycle
                    let y = -40 + progress * (size.height + 80)
                    let x = xOffset + progress * 30 - 15
                    let length: CGFloat = 14 + CGFloat(i % 3) * 3
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x + 4, y: y + length))
                    canvas.stroke(
                        path,
                        with: .color(Color(red: 0.65, green: 0.78, blue: 0.92).opacity(0.55 * intensity)),
                        lineWidth: 1.4
                    )
                }
            }
        }
    }
}

// MARK: - Lightning (occasional jagged forks + flash)

/// Lightning is rare — a fork strikes roughly every 7-12 seconds, lasts ~120ms,
/// and is followed by a fading screen flash. We compute it deterministically
/// from `floor(t / interval)` so the strike has a defined start and the flash
/// fades naturally with the elapsed-since-start.
private struct LightningLayer: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            Canvas { canvas, size in
                let t = context.date.timeIntervalSinceReferenceDate
                let strikeInterval = 9.0
                let strikeIndex = floor(t / strikeInterval)
                let strikeStart = strikeIndex * strikeInterval
                let elapsed = t - strikeStart
                // Strike body lives for ~140ms, followed by a fade flash for ~600ms.
                if elapsed < 0.14 {
                    drawFork(canvas: &canvas, size: size, seed: strikeIndex)
                }
                if elapsed < 0.7 {
                    let flashAlpha = max(0, 0.45 - elapsed * 0.6)
                    canvas.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .color(.white.opacity(flashAlpha))
                    )
                }
            }
        }
    }

    private func drawFork(canvas: inout GraphicsContext, size: CGSize, seed: Double) {
        // Deterministic-but-varied: derive numbers from the strike index.
        let s = seed * 0.6180339887
        let startX = (s.truncatingRemainder(dividingBy: 0.7) + 0.15) * size.width
        var x = startX
        var y: CGFloat = 0
        var path = Path()
        path.move(to: CGPoint(x: x, y: y))
        // 5 jagged segments down to about 65% of the screen.
        for i in 1...5 {
            let bias = sin(seed * 7 + Double(i) * 1.3) * 26
            x += CGFloat(bias)
            y += size.height * 0.13
            path.addLine(to: CGPoint(x: x, y: y))
        }
        canvas.stroke(
            path,
            with: .color(.white.opacity(0.95)),
            lineWidth: 2.8
        )
        // Soft blue-white halo behind the fork.
        canvas.stroke(
            path,
            with: .color(Color(red: 0.85, green: 0.90, blue: 1.0).opacity(0.55)),
            lineWidth: 7
        )
    }
}

// MARK: - Snow (slow falling flakes)

private struct SnowLayer: View {
    private let flakeCount = 50

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
                    let radius: CGFloat = 1.6 + CGFloat(i % 3) * 0.9
                    let rect = CGRect(
                        x: x - radius, y: y - radius,
                        width: radius * 2, height: radius * 2
                    )
                    canvas.fill(
                        Path(ellipseIn: rect),
                        with: .color(.white.opacity(0.85))
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
                for i in 0..<5 {
                    let yFraction = 0.10 + Double(i) * 0.16
                    let drift = sin(t * 0.05 + Double(i) * 0.7) * 40
                    let bandHeight: CGFloat = 70
                    let y = size.height * yFraction + drift
                    let rect = CGRect(x: -40, y: y, width: size.width + 80, height: bandHeight)
                    canvas.fill(
                        Path(roundedRect: rect, cornerRadius: bandHeight / 2),
                        with: .color(.white.opacity(0.16))
                    )
                }
            }
        }
    }
}
