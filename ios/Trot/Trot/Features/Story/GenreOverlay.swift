import SwiftUI

/// Full-bleed overlay that sits between `GenreAtmosphereLayer` and the
/// page content, giving each genre the feel of a *physical* medium rather
/// than just a colour treatment. Subtle but pervasive — the eye registers
/// it before the brain does.
///
///   - Murder mystery: drifting film grain (16mm noir feel)
///   - Horror: dark vignette closing the page corners
///   - Fantasy: parchment foxing — irregular warm blotches across the page
///   - Sci-fi: slow scan-line sweep + thin static lines
///   - Cosy mystery: warm radial glow centred low (afternoon sun on the
///     reading chair)
///   - Adventure: kraft-paper fibre cross-hatch
///
/// All variants are non-interactive (`allowsHitTesting(false)`) and
/// `ignoresSafeArea` so they bleed under tab bar and navigation chrome.
/// Reduce-motion drops the animated treatments to their static frame.
struct GenreOverlay: View {
    let genre: StoryGenre

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        layer
            .allowsHitTesting(false)
            .ignoresSafeArea()
    }

    @ViewBuilder
    private var layer: some View {
        switch genre.overlayKind {
        case .filmGrain:  FilmGrainLayer(animated: !reduceMotion)
        case .vignette:   VignetteLayer()
        case .parchment:  ParchmentLayer()
        case .scanlines:  ScanlinesLayer(tint: genre.accentColor, animated: !reduceMotion)
        case .warmGlow:   WarmGlowLayer(tint: genre.accentColor)
        case .kraftFiber: KraftFiberLayer()
        }
    }
}

// MARK: - Film grain (murder mystery)

private struct FilmGrainLayer: View {
    let animated: Bool

    var body: some View {
        if animated {
            TimelineView(.animation(minimumInterval: 1.0 / 18.0)) { context in
                Canvas { canvas, size in
                    drawGrain(canvas: canvas, size: size,
                              t: context.date.timeIntervalSinceReferenceDate)
                }
                .blendMode(.overlay)
                .opacity(0.55)
            }
        } else {
            Canvas { canvas, size in
                drawGrain(canvas: canvas, size: size, t: 0)
            }
            .blendMode(.overlay)
            .opacity(0.40)
        }
    }

    private func drawGrain(canvas: GraphicsContext, size: CGSize, t: TimeInterval) {
        // Sparse cloud of monochrome dots, reseeded every ~55ms by
        // shifting the seed with t. Cheap enough at 18fps and reads as
        // genuine 16mm grain when viewed in motion.
        let count = 320
        let frame = Int(t * 18)
        for i in 0..<count {
            let s = Double(i) * 0.6180339887 + Double(frame) * 0.317
            let xFrac = (s.truncatingRemainder(dividingBy: 1.0))
            let yFrac = ((s * 1.7).truncatingRemainder(dividingBy: 1.0))
            let bright = ((s * 3.3).truncatingRemainder(dividingBy: 1.0)) > 0.5
            let radius: CGFloat = 0.6 + CGFloat(i % 2) * 0.4
            let rect = CGRect(
                x: xFrac * size.width - radius,
                y: yFrac * size.height - radius,
                width: radius * 2, height: radius * 2
            )
            canvas.fill(
                Path(ellipseIn: rect),
                with: .color(bright
                    ? .white.opacity(0.35)
                    : .black.opacity(0.45))
            )
        }
    }
}

// MARK: - Vignette (horror)

private struct VignetteLayer: View {
    var body: some View {
        // Dark corners closing in. Radial gradient that sits on top of
        // everything except the cards. The page never quite feels safe.
        RadialGradient(
            colors: [
                .clear,
                .clear,
                Color.black.opacity(0.32),
                Color.black.opacity(0.55),
            ],
            center: .center,
            startRadius: 80,
            endRadius: 600
        )
        .blendMode(.multiply)
    }
}

// MARK: - Parchment foxing (fantasy)

private struct ParchmentLayer: View {
    var body: some View {
        // Irregular warm blotches across the full bleed — the look of an
        // old book whose vellum has aged. Static; built once.
        Canvas { canvas, size in
            let blotches: [(x: CGFloat, y: CGFloat, r: CGFloat, a: Double)] = [
                (0.12, 0.18, 80, 0.10),
                (0.78, 0.22, 60, 0.08),
                (0.42, 0.40, 110, 0.07),
                (0.20, 0.62, 90, 0.06),
                (0.86, 0.74, 70, 0.07),
                (0.32, 0.86, 100, 0.05),
                (0.62, 0.92, 80, 0.06),
                (0.92, 0.46, 50, 0.09),
                (0.06, 0.36, 65, 0.08),
            ]
            for blotch in blotches {
                let cx = size.width * blotch.x
                let cy = size.height * blotch.y
                let rect = CGRect(
                    x: cx - blotch.r, y: cy - blotch.r,
                    width: blotch.r * 2, height: blotch.r * 2
                )
                canvas.fill(
                    Path(ellipseIn: rect),
                    with: .color(Color(red: 0.55, green: 0.36, blue: 0.10).opacity(blotch.a))
                )
            }
        }
        .blendMode(.multiply)
        .opacity(0.65)
    }
}

// MARK: - Scanlines (sci-fi)

private struct ScanlinesLayer: View {
    let tint: Color
    let animated: Bool

    var body: some View {
        ZStack {
            // Static horizontal scan lines — read as CRT raster.
            Canvas { canvas, size in
                let spacing: CGFloat = 3
                var y: CGFloat = 0
                while y < size.height {
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: size.width, y: y))
                    canvas.stroke(line, with: .color(.black.opacity(0.18)), lineWidth: 1)
                    y += spacing
                }
            }

            // Slow drifting horizontal sweep — reads as a refresh cycle.
            if animated {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                    Canvas { canvas, size in
                        let t = context.date.timeIntervalSinceReferenceDate
                        let cycle: Double = 6.5
                        let progress = (t.truncatingRemainder(dividingBy: cycle)) / cycle
                        let bandHeight: CGFloat = 80
                        let y = CGFloat(progress) * (size.height + bandHeight) - bandHeight
                        let rect = CGRect(x: 0, y: y, width: size.width, height: bandHeight)
                        let gradient = Gradient(colors: [
                            .clear,
                            tint.opacity(0.18),
                            .clear,
                        ])
                        canvas.fill(
                            Path(rect),
                            with: .linearGradient(
                                gradient,
                                startPoint: CGPoint(x: 0, y: y),
                                endPoint: CGPoint(x: 0, y: y + bandHeight)
                            )
                        )
                    }
                }
            }
        }
        .blendMode(.multiply)
        .opacity(0.55)
    }
}

// MARK: - Warm glow (cosy mystery)

private struct WarmGlowLayer: View {
    let tint: Color

    var body: some View {
        // Soft afternoon-sun pool low and slightly off-centre — the
        // reading chair, three o'clock, kettle on.
        RadialGradient(
            colors: [
                tint.opacity(0.22),
                tint.opacity(0.10),
                .clear,
            ],
            center: UnitPoint(x: 0.62, y: 0.78),
            startRadius: 40,
            endRadius: 460
        )
        .blendMode(.softLight)
    }
}

// MARK: - Kraft fibre (adventure)

private struct KraftFiberLayer: View {
    var body: some View {
        // Cross-hatch of short brown strokes at low alpha — reads as
        // recycled-kraft paper. Static; rendered once.
        Canvas { canvas, size in
            let count = 240
            for i in 0..<count {
                let s = Double(i) * 0.6180339887
                let xFrac = (s.truncatingRemainder(dividingBy: 1.0))
                let yFrac = ((s * 2.3).truncatingRemainder(dividingBy: 1.0))
                let angle = ((s * 6.1).truncatingRemainder(dividingBy: 1.0)) * .pi
                let length: CGFloat = 4 + CGFloat(i % 4)
                let cx = xFrac * size.width
                let cy = yFrac * size.height
                let dx = cos(angle) * length
                let dy = sin(angle) * length
                var stroke = Path()
                stroke.move(to: CGPoint(x: cx - dx, y: cy - dy))
                stroke.addLine(to: CGPoint(x: cx + dx, y: cy + dy))
                canvas.stroke(
                    stroke,
                    with: .color(Color(red: 0.45, green: 0.30, blue: 0.18).opacity(0.18)),
                    lineWidth: 0.6
                )
            }
        }
        .blendMode(.multiply)
        .opacity(0.55)
    }
}
