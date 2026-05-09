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
    @Environment(AppState.self) private var appState
    @State private var snapshot: HourlySnapshot?
    /// Re-read on every appear so a debug-override change in Profile lands
    /// immediately on the next tab swap.
    @State private var refreshTrigger: Int = 0

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
        .task(id: refreshTrigger) { await load() }
        .onAppear { refreshTrigger &+= 1 }
        // The editor sheet that writes the postcode is owned by other views
        // (WalkWindowTile, DogSettingsSheet), so dismissing it never fires
        // .onAppear on the mood layer. Bump the trigger when
        // `UserPreferences.postcode` changes so the new value lands without
        // forcing the user to switch tabs.
        .onReceive(NotificationCenter.default.publisher(for: .trotPostcodeChanged)) { _ in
            refreshTrigger &+= 1
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func content(for snapshot: HourlySnapshot) -> some View {
        let category = snapshot.category
        let isDay = snapshot.isDay
        ZStack {
            SkyGradient(category: category, isDay: isDay)

            // Star field — only visible at night, only meaningful with sky
            // showing through. Sits below the moon/clouds.
            if !isDay && (category == .clear || category == .partlyCloudy) {
                StarField()
            }

            // Atmospheric mid-layer (sun/moon OR clouds OR neither). These sit
            // behind the foreground particles so rain falls through them.
            switch category {
            case .clear:
                if isDay {
                    SunDisc(intensity: 1.0)
                } else {
                    MoonDisc(intensity: 1.0)
                }
            case .partlyCloudy:
                ZStack {
                    if isDay {
                        SunDisc(intensity: 0.7)
                    } else {
                        MoonDisc(intensity: 0.7)
                    }
                    CloudBank(density: 0.4, windSpeedKmh: snapshot.windSpeedKmh, tint: cloudTint(isDay: isDay))
                }
            case .cloudy:
                CloudBank(density: 0.85, windSpeedKmh: snapshot.windSpeedKmh, tint: cloudTint(isDay: isDay))
            case .fog:
                FogLayer(isDay: isDay)
            case .drizzle, .rain, .thunder:
                CloudBank(density: 0.95, windSpeedKmh: snapshot.windSpeedKmh, tint: stormCloudTint(isDay: isDay))
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

    /// Cloud tint differs between day (bright white puffs) and night (dim
    /// silvery clouds with a navy undercast) so the same cloudy hour reads
    /// genuinely differently at noon and midnight.
    private func cloudTint(isDay: Bool) -> Color {
        isDay
            ? Color.white.opacity(0.85)
            : Color(red: 0.62, green: 0.66, blue: 0.78).opacity(0.55)
    }

    /// Storm clouds — flatter/darker than fair clouds. Night version pushes
    /// further toward indigo so the rain palette doesn't feel daylit.
    private func stormCloudTint(isDay: Bool) -> Color {
        isDay
            ? Color(red: 0.40, green: 0.43, blue: 0.50).opacity(0.55)
            : Color(red: 0.20, green: 0.22, blue: 0.32).opacity(0.62)
    }

    // MARK: - Load

    private func load() async {
        // DEBUG override: when set, skip the network entirely and synthesise a
        // snapshot that matches the chosen category. Lets us QA every visual
        // variant on a sunny day at lunchtime without waiting for real
        // weather to cooperate. No-op on release builds.
        #if DEBUG
        if let forced = DebugOverrides.weatherCategory {
            await MainActor.run {
                withAnimation(.brandDefault) {
                    snapshot = Self.syntheticSnapshot(for: forced)
                }
                publishAtmosphere(snapshot)
            }
            return
        }
        #endif

        let postcode = UserPreferences.postcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !postcode.isEmpty else { return }
        guard let location = await WeatherService.location(for: postcode) else { return }
        guard let forecast = await WeatherService.forecast(for: location) else { return }
        guard let current = forecast.snapshot(at: .now) else { return }
        await MainActor.run {
            withAnimation(.brandDefault) {
                snapshot = current
            }
            publishAtmosphere(snapshot)
        }
    }

    /// Publishes the loaded snapshot's category + isDay onto AppState so
    /// other views (card borders, tab headers) can swap their styling
    /// without needing to re-fetch the forecast themselves.
    @MainActor
    private func publishAtmosphere(_ snap: HourlySnapshot?) {
        guard let snap else { return }
        appState.atmosphereIsNight = !snap.isDay
        appState.atmosphereCategory = snap.category
    }

    /// Build an `HourlySnapshot` whose `category` resolves to `target` and whose
    /// other fields read as a plausible example of that weather. Used by the
    /// DEBUG override path. The wind speed deliberately varies per category so
    /// cloud drift speed differs visibly between (e.g.) calm and stormy.
    /// `isDay` honours `DebugOverrides.forceNight` so the night palettes can
    /// be QA'd without waiting for actual nightfall.
    private static func syntheticSnapshot(for target: WeatherCategory) -> HourlySnapshot {
        let (code, tempC, precip, wind): (Int, Double, Int, Double) = {
            switch target {
            case .clear:        return (0, 18, 0, 6)
            case .partlyCloudy: return (2, 16, 5, 10)
            case .cloudy:       return (3, 13, 20, 12)
            case .fog:          return (45, 9, 10, 4)
            case .drizzle:      return (51, 11, 60, 14)
            case .rain:         return (63, 10, 90, 18)
            case .snow:         return (73, 1, 80, 10)
            case .thunder:      return (95, 14, 95, 26)
            }
        }()
        let isDay: Bool = {
            #if DEBUG
            return !DebugOverrides.forceNight
            #else
            return true
            #endif
        }()
        return HourlySnapshot(
            time: .now,
            temperatureC: tempC,
            precipitationProbability: precip,
            weatherCodeRaw: code,
            windSpeedKmh: wind,
            isDay: isDay
        )
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
        // Explicit `Gradient.Stop` locations so the gradient hits `.clear`
        // by ~60% of screen height. Below that, the warm-cream brand surface
        // shows through — cards then sit on cream, not on dark navy. Without
        // this, the cards on Insights / Today / Journey punch out of a
        // night sky as flat white blocks (user feedback: "clunky / 0%
        // opacity"). The atmosphere stays night-flavoured at the top where
        // the moon and stars live.
        LinearGradient(
            stops: stops,
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Saturated stops, pushed harder than v1 so the atmosphere actually
    /// reads through the warm-cream brand surface beneath. Earlier values
    /// were diluted to the point that a clear afternoon and a clear dusk
    /// looked similar — both somewhere around "vaguely warm." Now each
    /// (category × isDay) pair has a distinct palette.
    /// Locations: the gradient hits `.clear` at 0.60 (60% down the screen).
    /// Below that the brand-cream surface reads through. Three colour stops
    /// occupy the upper 60% so the sky/atmosphere reads with full character
    /// in the top half where it belongs.
    private var stops: [Gradient.Stop] {
        let (top, mid, low) = colorStops
        return [
            .init(color: top, location: 0.0),
            .init(color: mid, location: 0.20),
            .init(color: low, location: 0.40),
            .init(color: .clear, location: 0.60),
        ]
    }

    /// Three-colour palette per (category × isDay). Locations are applied by
    /// `stops` so this only owns the colour story.
    private var colorStops: (top: Color, mid: Color, low: Color) {
        switch (category, isDay) {
        case (.clear, true):
            // Bright daytime — saturated sky blue at the top, warm gold mid.
            return (
                Color(red: 0.42, green: 0.74, blue: 0.96).opacity(0.92),
                Color(red: 0.62, green: 0.84, blue: 0.96).opacity(0.70),
                Color(red: 0.96, green: 0.78, blue: 0.45).opacity(0.42)
            )
        case (.clear, false):
            // Deep night — navy at the top fading to a soft indigo wash.
            return (
                Color(red: 0.08, green: 0.11, blue: 0.32).opacity(0.92),
                Color(red: 0.22, green: 0.24, blue: 0.50).opacity(0.72),
                Color(red: 0.46, green: 0.42, blue: 0.66).opacity(0.40)
            )
        case (.partlyCloudy, true):
            return (
                Color(red: 0.50, green: 0.76, blue: 0.94).opacity(0.85),
                Color(red: 0.78, green: 0.86, blue: 0.94).opacity(0.55),
                Color(red: 0.96, green: 0.84, blue: 0.62).opacity(0.32)
            )
        case (.partlyCloudy, false):
            return (
                Color(red: 0.10, green: 0.14, blue: 0.34).opacity(0.88),
                Color(red: 0.32, green: 0.34, blue: 0.55).opacity(0.62),
                Color(red: 0.55, green: 0.56, blue: 0.72).opacity(0.36)
            )
        case (.cloudy, true):
            return (
                Color(red: 0.45, green: 0.52, blue: 0.62).opacity(0.85),
                Color(red: 0.66, green: 0.72, blue: 0.80).opacity(0.55),
                Color(red: 0.84, green: 0.86, blue: 0.88).opacity(0.30)
            )
        case (.cloudy, false):
            return (
                Color(red: 0.16, green: 0.20, blue: 0.32).opacity(0.92),
                Color(red: 0.32, green: 0.36, blue: 0.46).opacity(0.65),
                Color(red: 0.50, green: 0.52, blue: 0.60).opacity(0.32)
            )
        case (.fog, true):
            return (
                Color(red: 0.72, green: 0.74, blue: 0.78).opacity(0.85),
                Color(red: 0.84, green: 0.84, blue: 0.86).opacity(0.55),
                Color(red: 0.92, green: 0.92, blue: 0.92).opacity(0.30)
            )
        case (.fog, false):
            return (
                Color(red: 0.34, green: 0.38, blue: 0.46).opacity(0.85),
                Color(red: 0.46, green: 0.50, blue: 0.58).opacity(0.60),
                Color(red: 0.60, green: 0.62, blue: 0.68).opacity(0.32)
            )
        case (.drizzle, true), (.rain, true):
            return (
                Color(red: 0.22, green: 0.32, blue: 0.50).opacity(0.92),
                Color(red: 0.40, green: 0.52, blue: 0.66).opacity(0.65),
                Color(red: 0.62, green: 0.72, blue: 0.82).opacity(0.32)
            )
        case (.drizzle, false), (.rain, false):
            return (
                Color(red: 0.08, green: 0.14, blue: 0.30).opacity(0.95),
                Color(red: 0.20, green: 0.28, blue: 0.42).opacity(0.70),
                Color(red: 0.36, green: 0.42, blue: 0.55).opacity(0.36)
            )
        case (.thunder, true):
            return (
                Color(red: 0.18, green: 0.20, blue: 0.34).opacity(0.95),
                Color(red: 0.32, green: 0.36, blue: 0.50).opacity(0.70),
                Color(red: 0.50, green: 0.54, blue: 0.66).opacity(0.32)
            )
        case (.thunder, false):
            return (
                Color(red: 0.06, green: 0.07, blue: 0.18).opacity(0.97),
                Color(red: 0.18, green: 0.20, blue: 0.32).opacity(0.75),
                Color(red: 0.34, green: 0.36, blue: 0.46).opacity(0.36)
            )
        case (.snow, true):
            return (
                Color(red: 0.66, green: 0.78, blue: 0.92).opacity(0.85),
                Color(red: 0.84, green: 0.90, blue: 0.96).opacity(0.55),
                Color(red: 0.96, green: 0.97, blue: 0.99).opacity(0.30)
            )
        case (.snow, false):
            return (
                Color(red: 0.20, green: 0.30, blue: 0.50).opacity(0.85),
                Color(red: 0.42, green: 0.52, blue: 0.70).opacity(0.55),
                Color(red: 0.72, green: 0.78, blue: 0.88).opacity(0.30)
            )
        }
    }
}

// MARK: - Sun disc

/// Soft sun in the top-right with a halo and slowly rotating rays. Pure
/// SwiftUI — no images. Only used during the day; nighttime uses `MoonDisc`.
private struct SunDisc: View {
    var intensity: Double = 1.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            Canvas { canvas, size in
                let t = context.date.timeIntervalSinceReferenceDate
                // Anchor the sun in the top-right at ~75% width, ~20% height.
                let centre = CGPoint(x: size.width * 0.78, y: size.height * 0.18)
                let coreRadius: CGFloat = 50
                let haloRadius: CGFloat = 150

                // Outer glow — three concentric soft rings so the halo reads
                // through the warm cream brand surface underneath.
                for i in 0..<3 {
                    let r = haloRadius - CGFloat(i) * 32
                    let rect = CGRect(
                        x: centre.x - r, y: centre.y - r,
                        width: r * 2, height: r * 2
                    )
                    canvas.fill(
                        Path(ellipseIn: rect),
                        with: .color(haloColor.opacity((0.16 + Double(i) * 0.08) * intensity))
                    )
                }

                // Slow rotating rays — 12 thin lines (was 8) so the sun
                // visibly throws light around it.
                let rotation = t * 0.18
                let rayInner: CGFloat = coreRadius + 8
                let rayOuter: CGFloat = coreRadius + 78
                for i in 0..<12 {
                    let angle = rotation + Double(i) * (.pi / 6)
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
                        with: .color(coreColor.opacity(0.30 * intensity)),
                        lineWidth: 2.5
                    )
                }

                // Core disc — opaque so it reads as a real light source.
                let coreRect = CGRect(
                    x: centre.x - coreRadius, y: centre.y - coreRadius,
                    width: coreRadius * 2, height: coreRadius * 2
                )
                canvas.fill(
                    Path(ellipseIn: coreRect),
                    with: .color(coreColor.opacity(0.98 * intensity))
                )
                // Inner highlight for a touch of dimensionality.
                let innerRect = coreRect.insetBy(dx: 12, dy: 12)
                canvas.fill(
                    Path(ellipseIn: innerRect),
                    with: .color(.white.opacity(0.18 * intensity))
                )
            }
        }
    }

    private var coreColor: Color { Color(red: 1.00, green: 0.86, blue: 0.40) }
    private var haloColor: Color { Color(red: 1.00, green: 0.78, blue: 0.36) }
}

// MARK: - Moon disc

/// Nighttime counterpart to `SunDisc`. Soft luminous moon with a cool halo,
/// a few craters for character, and a slow drift of sparkles around it.
/// Anchored in the same top-right slot so the eye finds the "sky's main
/// thing" in the same place day or night.
private struct MoonDisc: View {
    var intensity: Double = 1.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            Canvas { canvas, size in
                let t = context.date.timeIntervalSinceReferenceDate
                let centre = CGPoint(x: size.width * 0.78, y: size.height * 0.18)
                let coreRadius: CGFloat = 46
                let haloRadius: CGFloat = 140

                // Cool halo — three concentric soft rings, dimmer than the
                // sun's so it reads as moonlight rather than daylight.
                for i in 0..<3 {
                    let r = haloRadius - CGFloat(i) * 30
                    let rect = CGRect(
                        x: centre.x - r, y: centre.y - r,
                        width: r * 2, height: r * 2
                    )
                    canvas.fill(
                        Path(ellipseIn: rect),
                        with: .color(haloColor.opacity((0.10 + Double(i) * 0.06) * intensity))
                    )
                }

                // Core disc — luminous off-white, slightly cool.
                let coreRect = CGRect(
                    x: centre.x - coreRadius, y: centre.y - coreRadius,
                    width: coreRadius * 2, height: coreRadius * 2
                )
                canvas.fill(
                    Path(ellipseIn: coreRect),
                    with: .color(coreColor.opacity(0.96 * intensity))
                )

                // Inner highlight — a soft top-left brightening for that
                // "almost waning gibbous" look.
                let highlightRect = CGRect(
                    x: centre.x - coreRadius + 6,
                    y: centre.y - coreRadius + 6,
                    width: coreRadius * 1.5,
                    height: coreRadius * 1.5
                )
                canvas.fill(
                    Path(ellipseIn: highlightRect),
                    with: .color(.white.opacity(0.16 * intensity))
                )

                // Three craters — fixed positions relative to the disc, in
                // a faintly darker grey so they read without being noisy.
                let craters: [(dx: CGFloat, dy: CGFloat, r: CGFloat)] = [
                    (-14,  -8, 6),
                    ( 12,   4, 8),
                    ( -4,  16, 4),
                ]
                for crater in craters {
                    let rect = CGRect(
                        x: centre.x + crater.dx - crater.r,
                        y: centre.y + crater.dy - crater.r,
                        width: crater.r * 2,
                        height: crater.r * 2
                    )
                    canvas.fill(
                        Path(ellipseIn: rect),
                        with: .color(craterColor.opacity(0.32 * intensity))
                    )
                }

                // A handful of sparkles drifting slowly around the moon —
                // anchored deterministically off `t` so positions are stable
                // but always moving.
                let sparkleCount = 5
                for i in 0..<sparkleCount {
                    let phase = Double(i) * 1.31
                    let angle = t * 0.05 + phase
                    let radius = 90.0 + sin(t * 0.3 + phase) * 18
                    let sparkleX = centre.x + CGFloat(cos(angle) * radius)
                    let sparkleY = centre.y + CGFloat(sin(angle) * radius * 0.7)
                    let sparkleR: CGFloat = 1.6
                    let twinkle = (sin(t * 1.4 + phase) + 1) / 2  // 0...1
                    let rect = CGRect(
                        x: sparkleX - sparkleR,
                        y: sparkleY - sparkleR,
                        width: sparkleR * 2,
                        height: sparkleR * 2
                    )
                    canvas.fill(
                        Path(ellipseIn: rect),
                        with: .color(.white.opacity((0.45 + 0.45 * twinkle) * intensity))
                    )
                }
            }
        }
    }

    private var coreColor: Color { Color(red: 0.96, green: 0.96, blue: 0.92) }
    private var haloColor: Color { Color(red: 0.78, green: 0.84, blue: 0.96) }
    private var craterColor: Color { Color(red: 0.55, green: 0.58, blue: 0.66) }
}

// MARK: - Star field

/// A sparse layer of stars across the upper sky. Twinkles via a per-star
/// phase. Rendered only at night for clear / partly-cloudy skies — heavy
/// cloud and storm cover would block them anyway.
private struct StarField: View {
    private let starCount = 28

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
            Canvas { canvas, size in
                let t = context.date.timeIntervalSinceReferenceDate
                for i in 0..<starCount {
                    let seed = Double(i) * 0.6180339887
                    let xFrac = (seed.truncatingRemainder(dividingBy: 1.0))
                    // Stars sit in the upper half only — below that they'd
                    // collide with the dog photo / cards.
                    let yFrac = 0.04 + (seed.truncatingRemainder(dividingBy: 0.45))
                    let x = xFrac * size.width
                    let y = yFrac * size.height
                    // Skip stars that would overlap the moon's anchor.
                    let moonCentre = CGPoint(x: size.width * 0.78, y: size.height * 0.18)
                    let dx = x - moonCentre.x
                    let dy = y - moonCentre.y
                    if dx * dx + dy * dy < 130 * 130 { continue }

                    let twinklePhase = seed * 6.28
                    let twinkle = (sin(t * 1.6 + twinklePhase) + 1) / 2  // 0...1
                    let alpha = 0.35 + 0.55 * twinkle
                    let radius: CGFloat = 1.0 + CGFloat(i % 3) * 0.5
                    let rect = CGRect(
                        x: x - radius, y: y - radius,
                        width: radius * 2, height: radius * 2
                    )
                    canvas.fill(
                        Path(ellipseIn: rect),
                        with: .color(.white.opacity(alpha))
                    )
                }
            }
        }
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
    var isDay: Bool = true

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
                        with: .color(bandColor.opacity(0.16))
                    )
                }
            }
        }
    }

    private var bandColor: Color {
        isDay ? .white : Color(red: 0.78, green: 0.82, blue: 0.92)
    }
}
