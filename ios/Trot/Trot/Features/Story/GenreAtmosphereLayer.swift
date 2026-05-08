import SwiftUI

/// Full-bleed atmospheric layer for the Story tab. Same architectural
/// shape as `WeatherMoodLayer` (gradient + motif + optional particles)
/// but driven by the story's genre rather than the weather.
///
/// Each genre gets its own visual language:
///   - Murder mystery: noir black/grey gradient + drifting smoke + a
///     single warm streetlamp glow top-right
///   - Horror: deep slate-blue night with silhouetted trees and a slow
///     drift of fog at the foreground
///   - Fantasy: plum/gold gradient with slow firefly motes drifting
///     upward
///   - Sci-fi: midnight blue with a faint horizon-line grid + small
///     bright stars + a slow scan-line sweep
///   - Cosy mystery: warm cream/sage with floating tea-steam wisps
///   - Adventure: dawn forest green with sunbeam shafts + drifting birds
///     in silhouette
///
/// The bottom 40% of every variant fades to clear so the cream brand
/// surface reads through where cards sit. Same trick as the weather
/// layer; cards keep their hairline border via `brandCardShadow()`.
///
/// Reduce-motion: keeps the gradient + static motif, drops the moving
/// particles. Genre identity still reads.
struct GenreAtmosphereLayer: View {
    let genre: StoryGenre

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            SkyGradient(genre: genre)
            staticMotif
            if !reduceMotion {
                particles
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var staticMotif: some View {
        switch genre {
        case .murderMystery:
            StreetlampGlow(tint: genre.accentColor)
        case .horror:
            TreeSilhouettes(tint: Color.black.opacity(0.55))
        case .fantasy:
            FloatingMoon(tint: genre.accentColor)
        case .sciFi:
            HorizonGrid(tint: genre.accentColor)
        case .cosyMystery:
            TeaSteamHeader(tint: genre.accentColor)
        case .adventure:
            SunRays(tint: genre.accentColor)
        }
    }

    @ViewBuilder
    private var particles: some View {
        switch genre {
        case .murderMystery: SmokeDrift(tint: Color.white.opacity(0.18))
        case .horror:        FogBands(tint: Color.white.opacity(0.18))
        case .fantasy:       FireflyDrift(tint: genre.accentColor)
        case .sciFi:         StarPulses(tint: genre.accentColor)
        case .cosyMystery:   SteamDrift(tint: Color.white.opacity(0.32))
        case .adventure:     BirdDrift(tint: Color.black.opacity(0.45))
        }
    }
}

// MARK: - Sky gradient

private struct SkyGradient: View {
    let genre: StoryGenre

    var body: some View {
        // Same .clear-by-60% pattern as WeatherMoodLayer so cards rest on
        // cream not on the genre's atmospheric tint. Top of the screen
        // carries the genre identity; the lower content area is calm.
        LinearGradient(
            stops: [
                .init(color: genre.primaryColor.opacity(0.92), location: 0.0),
                .init(color: genre.midColor.opacity(0.62), location: 0.20),
                .init(color: genre.midColor.opacity(0.30), location: 0.40),
                .init(color: .clear, location: 0.60),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Murder mystery — streetlamp + smoke

private struct StreetlampGlow: View {
    let tint: Color

    var body: some View {
        Canvas { canvas, size in
            let centre = CGPoint(x: size.width * 0.82, y: size.height * 0.16)
            for i in 0..<3 {
                let r = 140 - CGFloat(i) * 32
                let rect = CGRect(
                    x: centre.x - r, y: centre.y - r,
                    width: r * 2, height: r * 2
                )
                canvas.fill(
                    Path(ellipseIn: rect),
                    with: .color(tint.opacity(0.10 + Double(i) * 0.06))
                )
            }
            // Lamp post line.
            var line = Path()
            line.move(to: CGPoint(x: centre.x, y: centre.y + 12))
            line.addLine(to: CGPoint(x: centre.x, y: size.height * 0.38))
            canvas.stroke(line, with: .color(.black.opacity(0.45)), lineWidth: 2)
            // Lamp head.
            let lamp = CGRect(x: centre.x - 6, y: centre.y, width: 12, height: 12)
            canvas.fill(
                Path(ellipseIn: lamp),
                with: .color(tint.opacity(0.85))
            )
        }
    }
}

private struct SmokeDrift: View {
    let tint: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
            Canvas { canvas, size in
                let t = context.date.timeIntervalSinceReferenceDate
                for i in 0..<4 {
                    let seed = Double(i) * 0.6180339887
                    let yFraction = 0.06 + (seed.truncatingRemainder(dividingBy: 0.32))
                    let drift = sin(t * 0.06 + Double(i) * 0.9) * 30
                    let bandHeight: CGFloat = 60
                    let y = size.height * yFraction + drift
                    let rect = CGRect(x: -40, y: y, width: size.width + 80, height: bandHeight)
                    canvas.fill(
                        Path(roundedRect: rect, cornerRadius: bandHeight / 2),
                        with: .color(tint.opacity(0.18))
                    )
                }
            }
        }
    }
}

// MARK: - Horror — trees + fog

private struct TreeSilhouettes: View {
    let tint: Color

    var body: some View {
        Canvas { canvas, size in
            // Three jagged "tree" shapes along the horizon at ~38% height.
            let baseY = size.height * 0.38
            let triangles: [(CGFloat, CGFloat)] = [
                (size.width * 0.12, 110),
                (size.width * 0.36, 80),
                (size.width * 0.72, 130),
                (size.width * 0.88, 95),
            ]
            for (x, h) in triangles {
                var path = Path()
                path.move(to: CGPoint(x: x, y: baseY))
                path.addLine(to: CGPoint(x: x - 28, y: baseY))
                path.addLine(to: CGPoint(x: x - 4, y: baseY - h * 0.55))
                path.addLine(to: CGPoint(x: x - 18, y: baseY - h * 0.55))
                path.addLine(to: CGPoint(x: x + 6, y: baseY - h))
                path.addLine(to: CGPoint(x: x + 30, y: baseY - h * 0.55))
                path.addLine(to: CGPoint(x: x + 16, y: baseY - h * 0.55))
                path.addLine(to: CGPoint(x: x + 40, y: baseY))
                path.closeSubpath()
                canvas.fill(path, with: .color(tint))
            }
        }
    }
}

private struct FogBands: View {
    let tint: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
            Canvas { canvas, size in
                let t = context.date.timeIntervalSinceReferenceDate
                for i in 0..<5 {
                    let yFraction = 0.32 + Double(i) * 0.05
                    let drift = sin(t * 0.04 + Double(i) * 0.7) * 50
                    let bandHeight: CGFloat = 70
                    let y = size.height * yFraction + drift
                    let rect = CGRect(x: -40, y: y, width: size.width + 80, height: bandHeight)
                    canvas.fill(
                        Path(roundedRect: rect, cornerRadius: bandHeight / 2),
                        with: .color(tint.opacity(0.22))
                    )
                }
            }
        }
    }
}

// MARK: - Fantasy — moon + fireflies

private struct FloatingMoon: View {
    let tint: Color

    var body: some View {
        Canvas { _, _ in /* Renders below in a separate moon disc */ }
            .overlay(alignment: .topTrailing) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.30))
                        .frame(width: 110, height: 110)
                        .blur(radius: 18)
                    Circle()
                        .fill(tint)
                        .frame(width: 56, height: 56)
                }
                .padding(.top, 48)
                .padding(.trailing, 30)
                .accessibilityHidden(true)
            }
    }
}

private struct FireflyDrift: View {
    let tint: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            Canvas { canvas, size in
                let t = context.date.timeIntervalSinceReferenceDate
                for i in 0..<14 {
                    let seed = Double(i) * 0.6180339887
                    let xBase = (seed.truncatingRemainder(dividingBy: 1.0)) * size.width
                    let yBase = (seed.truncatingRemainder(dividingBy: 0.5)) * size.height * 0.55
                    let drift = sin(t * 0.4 + seed * 5) * 26
                    let lift = (cos(t * 0.18 + seed * 3) * 0.5 + 0.5)
                    let y = yBase + drift - lift * 60
                    let x = xBase + cos(t * 0.5 + seed * 4) * 18
                    let twinkle = (sin(t * 1.6 + seed * 6) + 1) / 2
                    let radius: CGFloat = 1.8 + CGFloat(i % 3) * 0.6
                    let rect = CGRect(
                        x: x - radius, y: y - radius,
                        width: radius * 2, height: radius * 2
                    )
                    canvas.fill(
                        Path(ellipseIn: rect),
                        with: .color(tint.opacity(0.40 + 0.50 * twinkle))
                    )
                }
            }
        }
    }
}

// MARK: - Sci-fi — horizon grid + star pulses

private struct HorizonGrid: View {
    let tint: Color

    var body: some View {
        Canvas { canvas, size in
            let horizonY = size.height * 0.34
            // Horizontal lines.
            for i in 0..<5 {
                var line = Path()
                let y = horizonY + CGFloat(i) * 16
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                canvas.stroke(line, with: .color(tint.opacity(0.22 - Double(i) * 0.04)), lineWidth: 1)
            }
            // Vertical perspective lines fan toward the centre.
            let cx = size.width / 2
            for i in -4...4 {
                var line = Path()
                line.move(to: CGPoint(x: cx + CGFloat(i) * 28, y: horizonY))
                line.addLine(to: CGPoint(x: cx + CGFloat(i) * 90, y: horizonY + 80))
                canvas.stroke(line, with: .color(tint.opacity(0.14)), lineWidth: 1)
            }
        }
    }
}

private struct StarPulses: View {
    let tint: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
            Canvas { canvas, size in
                let t = context.date.timeIntervalSinceReferenceDate
                for i in 0..<22 {
                    let seed = Double(i) * 0.6180339887
                    let xFrac = (seed.truncatingRemainder(dividingBy: 1.0))
                    let yFrac = 0.04 + (seed.truncatingRemainder(dividingBy: 0.30))
                    let twinkle = (sin(t * 1.4 + seed * 6) + 1) / 2
                    let radius: CGFloat = 1.4 + CGFloat(i % 3) * 0.5
                    let rect = CGRect(
                        x: xFrac * size.width - radius,
                        y: yFrac * size.height - radius,
                        width: radius * 2, height: radius * 2
                    )
                    canvas.fill(
                        Path(ellipseIn: rect),
                        with: .color(tint.opacity(0.45 + 0.45 * twinkle))
                    )
                }
            }
        }
    }
}

// MARK: - Cosy mystery — tea steam

private struct TeaSteamHeader: View {
    let tint: Color

    var body: some View {
        Canvas { canvas, size in
            // Soft warm glow centred where the chapter title will sit.
            let centre = CGPoint(x: size.width * 0.5, y: size.height * 0.18)
            for i in 0..<3 {
                let r = 130 - CGFloat(i) * 30
                let rect = CGRect(
                    x: centre.x - r, y: centre.y - r,
                    width: r * 2, height: r * 2
                )
                canvas.fill(
                    Path(ellipseIn: rect),
                    with: .color(tint.opacity(0.10 + Double(i) * 0.05))
                )
            }
        }
    }
}

private struct SteamDrift: View {
    let tint: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
            Canvas { canvas, size in
                let t = context.date.timeIntervalSinceReferenceDate
                for i in 0..<6 {
                    let seed = Double(i) * 0.6180339887
                    let xBase = 0.30 + (seed.truncatingRemainder(dividingBy: 0.40))
                    let phase = sin(t * 0.5 + Double(i) * 1.2)
                    let yLift = (t * 18 + seed * 100).truncatingRemainder(dividingBy: 240)
                    let y = size.height * 0.34 - CGFloat(yLift)
                    let x = xBase * size.width + CGFloat(phase) * 18
                    let radius: CGFloat = 8 + CGFloat(i % 2) * 4
                    let rect = CGRect(
                        x: x - radius, y: y - radius,
                        width: radius * 2, height: radius * 2
                    )
                    let alpha = max(0, 1 - yLift / 240) * 0.5
                    canvas.fill(
                        Path(ellipseIn: rect),
                        with: .color(tint.opacity(alpha))
                    )
                }
            }
        }
    }
}

// MARK: - Adventure — sunrays + birds

private struct SunRays: View {
    let tint: Color

    var body: some View {
        Canvas { canvas, size in
            let centre = CGPoint(x: size.width * 0.78, y: size.height * 0.10)
            // Soft sun disc.
            let coreRect = CGRect(x: centre.x - 30, y: centre.y - 30, width: 60, height: 60)
            canvas.fill(Path(ellipseIn: coreRect), with: .color(tint.opacity(0.85)))
            // Soft rays radiating down/left.
            for i in 0..<8 {
                let angle = .pi * 0.7 + Double(i) * 0.08
                let p1 = CGPoint(
                    x: centre.x + cos(angle) * 28,
                    y: centre.y + sin(angle) * 28
                )
                let p2 = CGPoint(
                    x: centre.x + cos(angle) * 220,
                    y: centre.y + sin(angle) * 220
                )
                var ray = Path()
                ray.move(to: p1)
                ray.addLine(to: p2)
                canvas.stroke(ray, with: .color(tint.opacity(0.18)), lineWidth: 6)
            }
        }
    }
}

private struct BirdDrift: View {
    let tint: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
            Canvas { canvas, size in
                let t = context.date.timeIntervalSinceReferenceDate
                for i in 0..<3 {
                    let seed = Double(i) * 0.6180339887
                    let yBase = 0.14 + (seed.truncatingRemainder(dividingBy: 0.22))
                    let speed = 28.0 + (seed.truncatingRemainder(dividingBy: 0.5)) * 12
                    let cycle = (size.width + 200) / speed
                    let phase = (seed.truncatingRemainder(dividingBy: 1.0)) * cycle
                    let progress = (t + phase).truncatingRemainder(dividingBy: cycle) / cycle
                    let x = -100 + progress * (size.width + 200)
                    let y = size.height * yBase + sin(t * 0.6 + seed * 4) * 8
                    // V-shape silhouette.
                    var path = Path()
                    path.move(to: CGPoint(x: x - 10, y: y + 2))
                    path.addLine(to: CGPoint(x: x, y: y - 4))
                    path.addLine(to: CGPoint(x: x + 10, y: y + 2))
                    canvas.stroke(path, with: .color(tint), lineWidth: 1.6)
                }
            }
        }
    }
}
