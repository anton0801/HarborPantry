import SwiftUI

// MARK: - Public view

struct SeaLoader: View {

    /// `nil` = endless mode. `0...1` = determinate mode (water level follows progress).
    let progress: Double?
    /// Globe diameter in points. Everything scales with it.
    let size: CGFloat
    /// Label shown in endless mode.
    let title: String
    /// Label shown when progress reaches 1. `nil` keeps "100%".
    let completedTitle: String?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate = Date()
    @State private var level: SmoothValue

    init(progress: Double? = nil,
         size: CGFloat = 240,
         title: String = "Loading",
         completedTitle: String? = "Done") {
        self.progress = progress
        self.size = size
        self.title = title
        self.completedTitle = completedTitle
        _level = State(initialValue: SmoothValue(Self.waterLevel(for: progress)))
    }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let now = context.date.timeIntervalSinceReferenceDate
            // Reduced motion: freeze the scene on a frame where the fish is mid-tank.
            let t = reduceMotion ? 2.4 : context.date.timeIntervalSince(startDate)

            VStack(spacing: size * 0.09) {
                globe(t: t, level: level.value(at: now))
                label(t: t)
            }
        }
        .onChange(of: progress) { newValue in
            level.retarget(Self.waterLevel(for: newValue),
                           at: Date().timeIntervalSinceReferenceDate,
                           duration: reduceMotion ? 0 : 0.64)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: Globe

    private func globe(t: Double, level: Double) -> some View {
        ZStack {
            Canvas { ctx, canvasSize in
                SeaScene(S: canvasSize.width, t: t, level: level).draw(in: &ctx)
            }
            GlassOverlay(size: size)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(haloColor, lineWidth: 1))
        .shadow(color: shadowColor, radius: size * 0.12, x: 0, y: size * 0.1)
        .shadow(color: glowColor, radius: size * 0.3)
    }

    // MARK: Label

    private func label(t: Double) -> some View {
        let scale = min(max(size / 240, 0.8), 1.3)
        return HStack(alignment: .lastTextBaseline, spacing: 8 * scale) {
            Text(labelText)
                .font(.system(size: 17 * scale, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(textColor)
            if progress == nil {
                HStack(spacing: 5 * scale) {
                    ForEach(0..<3) { i in
                        let phase = fract((t - Double(i) * 0.18) / 1.5)
                        let k = reduceMotion ? 0.5 - 0.5 * cos(2 * .pi * phase) : sin(.pi * phase)
                        Circle()
                            .fill(dotColor)
                            .frame(width: 6 * scale, height: 6 * scale)
                            .opacity(0.5 + 0.5 * k)
                            .offset(y: reduceMotion ? 0 : -4 * scale * k)
                    }
                }
            }
        }
    }

    private var labelText: String {
        guard let p = progress else { return title }
        if p >= 1, let done = completedTitle { return done }
        return "\(Int((min(max(p, 0), 1) * 100).rounded()))%"
    }

    private var accessibilityText: String {
        guard let p = progress else { return title }
        return "Loaded \(Int((min(max(p, 0), 1) * 100).rounded())) percent"
    }

    // MARK: Theme (only the chrome adapts; the globe itself is theme-independent)

    private var isDark: Bool { colorScheme == .dark }
    private var textColor: Color { isDark ? Color(seaHex: 0xC9EFE3) : Color(seaHex: 0x164F5B) }
    private var dotColor: Color { isDark ? Color(seaHex: 0x7FE8C6) : Color(seaHex: 0x1FA08A) }
    private var haloColor: Color { Color.white.opacity(isDark ? 0.09 : 0.7) }
    private var shadowColor: Color {
        isDark ? Color.black.opacity(0.6) : Color(seaHex: 0x0C6078).opacity(0.45)
    }
    private var glowColor: Color { isDark ? Color(seaHex: 0x3FD0B4).opacity(0.3) : .clear }

    private static func waterLevel(for progress: Double?) -> Double {
        guard let p = progress else { return 0.62 }
        return 0.48 + 0.44 * min(max(p, 0), 1)
    }
}

// MARK: - Glass overlay (static, cached by SwiftUI)

private struct GlassOverlay: View {
    let size: CGFloat

    var body: some View {
        let u = size / 240
        ZStack {
            // inner rim light, top-left
            Circle()
                .strokeBorder(Color.white.opacity(0.62), lineWidth: 30 * u)
                .blur(radius: 16 * u)
                .offset(x: 14 * u, y: 16 * u)
            // inner shade, bottom-right
            Circle()
                .strokeBorder(Color(seaHex: 0x05304E).opacity(0.5), lineWidth: 40 * u)
                .blur(radius: 20 * u)
                .offset(x: -16 * u, y: -20 * u)
            // thin glass edge
            Circle()
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 1.5)
            // specular highlights
            specular(diameter: size * 0.38, squash: 0.18 / 0.38, alpha: 0.92)
                .position(x: size * 0.32, y: size * 0.18)
            specular(diameter: size * 0.12, squash: 0.5, alpha: 0.7)
                .position(x: size * 0.77, y: size * 0.84)
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }

    private func specular(diameter: CGFloat, squash: CGFloat, alpha: Double) -> some View {
        Circle()
            .fill(RadialGradient(colors: [Color.white.opacity(alpha), Color.white.opacity(0)],
                                 center: .center, startRadius: 0, endRadius: diameter * 0.35))
            .frame(width: diameter, height: diameter)
            .scaleEffect(x: 1, y: squash)
            .rotationEffect(.degrees(-32))
    }
}

// MARK: - Scene (everything animated, drawn per frame)

private struct SeaScene {
    let S: CGFloat        // globe diameter
    let t: Double         // seconds since appearance
    let level: Double     // water level, 0...1 of globe height

    /// Point scale relative to the 240pt reference design.
    private var u: CGFloat { S / 240 }

    func draw(in ctx: inout GraphicsContext) {
        drawAir(&ctx)
        drawWater(&ctx)
        drawDune(&ctx, front: false)
        drawWeeds(&ctx)
        drawDune(&ctx, front: true)
        drawBubbles(&ctx)
        drawFish(&ctx, far: true)
        drawFish(&ctx, far: false)
        drawRays(&ctx)
    }

    // MARK: Air

    private func drawAir(_ ctx: inout GraphicsContext) {
        ctx.fill(Path(CGRect(x: 0, y: 0, width: S, height: S)),
                 with: .linearGradient(Gradient(colors: [Color(seaHex: 0xF2FDF9), Color(seaHex: 0xC8F2EC)]),
                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: S)))
    }

    // MARK: Water + waves

    private func drawWater(_ ctx: inout GraphicsContext) {
        let surfaceY = S * (1 - CGFloat(level))
        let sl = osc(t, period: 11.2)                     // slosh: tilt + breathing level
        let angle = -1.4 + 2.8 * sl
        let breath = (2 - 4 * sl) * u

        var c = ctx
        c.translateBy(x: S / 2, y: surfaceY)
        c.rotate(by: .degrees(angle))
        c.translateBy(x: -S / 2, y: -surfaceY + breath)

        let left = -0.3 * S, right = 1.3 * S, bottom = 1.4 * S
        let bodyH = bottom - surfaceY
        c.fill(Path(CGRect(x: left, y: surfaceY, width: right - left, height: bodyH)),
               with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(seaHex: 0x22AAD4), location: 0),
                    .init(color: Color(seaHex: 0x22AAD4), location: 22 * u / bodyH),
                    .init(color: Color(seaHex: 0x1A8DBF), location: 76 * u / bodyH),
                    .init(color: Color(seaHex: 0x0F5C92), location: 1)
                ]),
                startPoint: CGPoint(x: 0, y: surfaceY),
                endPoint: CGPoint(x: 0, y: bottom)))

        // (midline offset pt, amplitude pt, periods per second, colour) — back to front
        let period = 0.8 * S
        let waves: [(dy: CGFloat, amp: CGFloat, speed: Double, color: Color)] = [
            (-4, 7.0,  2.0 / 9.5, Color(seaHex: 0x7FE8C6)),
            (-2, 5.6, -2.0 / 6.8, Color(seaHex: 0x3FD0B4)),
            ( 0, 4.2,  2.0 / 4.9, Color(seaHex: 0x22AAD4))
        ]
        for w in waves {
            let mid = surfaceY + w.dy * u
            let shift = CGFloat(w.speed * t) * period
            var p = Path()
            let steps = 96
            for i in 0...steps {
                let x = left + (right - left) * CGFloat(i) / CGFloat(steps)
                let y = mid - w.amp * u * sin(2 * .pi * (x + shift) / period)
                if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
            }
            p.addLine(to: CGPoint(x: right, y: mid + 14 * u))
            p.addLine(to: CGPoint(x: left, y: mid + 14 * u))
            p.closeSubpath()
            c.fill(p, with: .color(w.color))
        }
    }

    // MARK: Seabed

    private func drawDune(_ ctx: inout GraphicsContext, front: Bool) {
        var c = ctx
        c.translateBy(x: 0, y: 0.75 * S)
        c.scaleBy(x: S / 240, y: S / 240)   // local box: 240 x 60

        var p = Path()
        if front {
            p.move(to: CGPoint(x: 0, y: 60))
            p.addLine(to: CGPoint(x: 0, y: 50))
            p.addCurve(to: CGPoint(x: 150, y: 42), control1: CGPoint(x: 50, y: 38), control2: CGPoint(x: 100, y: 48))
            p.addCurve(to: CGPoint(x: 240, y: 40), control1: CGPoint(x: 190, y: 37), control2: CGPoint(x: 220, y: 46))
            p.addLine(to: CGPoint(x: 240, y: 60))
            p.closeSubpath()
            c.fill(p, with: .color(Color(seaHex: 0x0F5772)))

            let pebbles: [(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat)] = [
                (152, 43, 13, 5), (182, 46, 8, 3.5), (70, 47, 10, 4)
            ]
            for e in pebbles {
                c.fill(Path(ellipseIn: CGRect(x: e.cx - e.rx, y: e.cy - e.ry, width: 2 * e.rx, height: 2 * e.ry)),
                       with: .color(Color(seaHex: 0x1C7C98)))
            }
        } else {
            p.move(to: CGPoint(x: 0, y: 60))
            p.addLine(to: CGPoint(x: 0, y: 40))
            p.addCurve(to: CGPoint(x: 116, y: 30), control1: CGPoint(x: 34, y: 22), control2: CGPoint(x: 74, y: 36))
            p.addCurve(to: CGPoint(x: 240, y: 24), control1: CGPoint(x: 158, y: 24), control2: CGPoint(x: 198, y: 34))
            p.addLine(to: CGPoint(x: 240, y: 60))
            p.closeSubpath()
            c.fill(p, with: .color(Color(seaHex: 0x12657F)))
        }
    }

    // MARK: Seaweed

    private struct Blade {
        let path: Path
        let color: Color
        let width: CGFloat
        let origin: CGPoint
        let period: Double     // one half-swing (CSS alternate duration)
        let phase: Double
    }

    private static func blade(_ a: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ b: CGPoint,
                              color: UInt32, width: CGFloat, period: Double, phase: Double) -> Blade {
        var p = Path()
        p.move(to: a)
        p.addCurve(to: b, control1: c1, control2: c2)
        return Blade(path: p, color: Color(seaHex: color), width: width, origin: a, period: period, phase: phase)
    }

    private static let leftBlades: [Blade] = [
        blade(CGPoint(x: 34, y: 110), CGPoint(x: 25, y: 86), CGPoint(x: 44, y: 68), CGPoint(x: 33, y: 40),
              color: 0x2FAE86, width: 7, period: 3.6, phase: 0),
        blade(CGPoint(x: 54, y: 110), CGPoint(x: 63, y: 90), CGPoint(x: 47, y: 72), CGPoint(x: 58, y: 46),
              color: 0x58CF9F, width: 6, period: 4.1, phase: 1.3),
        blade(CGPoint(x: 18, y: 110), CGPoint(x: 12, y: 94), CGPoint(x: 25, y: 84), CGPoint(x: 17, y: 64),
              color: 0x1F8E6D, width: 5, period: 4.6, phase: 2.2)
    ]

    private static let rightBlades: [Blade] = [
        blade(CGPoint(x: 30, y: 80), CGPoint(x: 24, y: 62), CGPoint(x: 38, y: 52), CGPoint(x: 29, y: 32),
              color: 0x2FAE86, width: 6, period: 3.9, phase: 0.8),
        blade(CGPoint(x: 46, y: 80), CGPoint(x: 52, y: 66), CGPoint(x: 40, y: 58), CGPoint(x: 48, y: 44),
              color: 0x1F8E6D, width: 5, period: 4.4, phase: 2.6)
    ]

    private func drawWeeds(_ ctx: inout GraphicsContext) {
        var l = ctx                                   // left cluster: 120 x 110 box
        l.translateBy(x: 0.11 * S, y: 0.62 * S)
        l.scaleBy(x: 0.003 * S, y: 0.003 * S)
        drawBlades(&l, Self.leftBlades)

        var r = ctx                                   // right cluster: 80 x 80 box
        r.translateBy(x: 0.69 * S, y: 0.73 * S)
        r.scaleBy(x: 0.00275 * S, y: 0.00275 * S)
        drawBlades(&r, Self.rightBlades)
    }

    private func drawBlades(_ c: inout GraphicsContext, _ blades: [Blade]) {
        for b in blades {
            let angle = -6 + 12 * osc(t, period: b.period * 2, phase: b.phase)
            var bc = c
            bc.translateBy(x: b.origin.x, y: b.origin.y)
            bc.rotate(by: .degrees(angle))
            bc.translateBy(x: -b.origin.x, y: -b.origin.y)
            bc.stroke(b.path, with: .color(b.color), style: StrokeStyle(lineWidth: b.width, lineCap: .round))
        }
    }

    // MARK: Bubbles

    private func drawBubbles(_ ctx: inout GraphicsContext) {
        // (x fraction, diameter pt, cycle seconds, phase seconds)
        let bubbles: [(x: CGFloat, s: CGFloat, d: Double, phase: Double)] = [
            (0.32, 7, 4.6, 1.1), (0.46, 5, 3.8, 2.9), (0.58, 9, 5.4, 0.4),
            (0.68, 6, 4.2, 3.5), (0.40, 4, 5.0, 4.4)
        ]
        for b in bubbles {
            let p = fract((t + b.phase) / b.d)
            let alpha: Double
            if p < 0.12 {
                alpha = p / 0.12 * 0.95
            } else if p < 0.78 {
                alpha = 0.95 - (p - 0.12) / 0.66 * 0.10
            } else {
                alpha = 0.85 * (1 - (p - 0.78) / 0.22)
            }
            let scale = 0.5 + 0.5 * p
            let wobble = (-4 + 8 * osc(t + b.phase, period: b.d / 2.3 * 2)) * u
            let d = b.s * u * scale
            let cx = b.x * S + b.s * u / 2 + wobble
            let cy = 0.86 * S - b.s * u / 2 - CGFloat(p) * 0.46 * S
            let rect = CGRect(x: cx - d / 2, y: cy - d / 2, width: d, height: d)

            var bc = ctx
            bc.opacity = alpha
            bc.fill(Path(ellipseIn: rect),
                    with: .radialGradient(Gradient(colors: [Color.white.opacity(0.65), Color.white.opacity(0.04)]),
                                          center: CGPoint(x: cx - d * 0.14, y: cy - d * 0.16),
                                          startRadius: 0, endRadius: d * 0.62))
            bc.stroke(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.8)), lineWidth: 1.5 * u)
        }
    }

    // MARK: Fish

    private struct FishStyle {
        let body: Gradient
        let fin: Color
        let tail: Color
        let detailed: Bool
    }

    private static let mainFish = FishStyle(
        body: Gradient(colors: [Color(seaHex: 0xF6FFC4), Color(seaHex: 0x8ED77A)]),
        fin: Color(seaHex: 0x43B591), tail: Color(seaHex: 0x6FCF8F), detailed: true)

    private static let farFish = FishStyle(
        body: Gradient(colors: [Color(seaHex: 0xA6EAD9), Color(seaHex: 0x3AA896)]),
        fin: Color(seaHex: 0x2C8F82), tail: Color(seaHex: 0x2C8F82), detailed: false)

    /// Out: big and bright. Back: smaller, higher and dimmer for depth.
    /// Every turn happens outside the globe, so it is never visible.
    /// Returns nil while the fish is turning off-screen.
    private func swimState(cycle f: Double, reversed: Bool)
        -> (x: CGFloat, yLane: CGFloat, flipped: Bool, scale: CGFloat, alpha: Double)? {
        if f < 0.46 {
            let p = easeInOut(f / 0.46)
            let x = reversed ? 4.4 - 5.8 * p : -1.4 + 5.8 * p
            return (CGFloat(x), 0, reversed, 1, 1)
        } else if f >= 0.5 && f < 0.96 {
            let p = easeInOut((f - 0.5) / 0.46)
            let x = reversed ? -1.4 + 5.8 * p : 4.4 - 5.8 * p
            return (CGFloat(x), -0.7, !reversed, 0.66, 0.72)
        }
        return nil
    }

    private func drawFish(_ ctx: inout GraphicsContext, far: Bool) {
        let w = (far ? 0.14 : 0.25) * S
        let h = w * 40 / 64
        let laneBottom = S * (far ? 0.66 : 0.84)
        let f = far ? fract((t + 6) / 13) : fract(t / 10)
        guard let s = swimState(cycle: f, reversed: far) else { return }

        let bobT = far ? t + 1.3 : t
        let bob = osc(bobT, period: 5.2)
        let cx = s.x * w + w / 2
        let cy = laneBottom - h / 2 + s.yLane * h + CGFloat(-0.05 + 0.10 * bob) * h
        let pitch = -3 + 6 * bob

        drawFishShape(&ctx,
                      center: CGPoint(x: cx, y: cy),
                      width: w * s.scale,
                      flipped: s.flipped,
                      alpha: s.alpha * (far ? 0.6 : 1),
                      pitch: pitch,
                      tailAngle: -14 + 28 * osc(bobT, period: 0.96),
                      finAngle: -8 + 18 * osc(bobT, period: 1.2),
                      style: far ? Self.farFish : Self.mainFish)
    }

    private func drawFishShape(_ ctx: inout GraphicsContext, center: CGPoint, width: CGFloat, flipped: Bool,
                               alpha: Double, pitch: Double, tailAngle: Double, finAngle: Double,
                               style: FishStyle) {
        let k = width / 64                              // local box: 64 x 40, fish faces right
        var c = ctx
        c.opacity = alpha
        c.translateBy(x: center.x, y: center.y)
        c.scaleBy(x: flipped ? -k : k, y: k)
        c.rotate(by: .degrees(pitch))
        c.translateBy(x: -32, y: -20)

        var tail = c
        tail.translateBy(x: 15, y: 20)
        tail.rotate(by: .degrees(tailAngle))
        tail.translateBy(x: -15, y: -20)
        tail.fill(FishPaths.tail, with: .color(style.tail))

        c.fill(FishPaths.dorsal, with: .color(style.fin))
        c.fill(FishPaths.body, with: .linearGradient(style.body,
                                                     startPoint: CGPoint(x: 0, y: 6),
                                                     endPoint: CGPoint(x: 0, y: 34)))
        if style.detailed {
            c.stroke(FishPaths.highlight, with: .color(Color.white.opacity(0.6)),
                     style: StrokeStyle(lineWidth: 2, lineCap: .round))
            c.stroke(FishPaths.gill, with: .color(Color(seaHex: 0x5CC49A).opacity(0.85)),
                     style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }

        var fin = c
        fin.translateBy(x: 30, y: 23)
        fin.rotate(by: .degrees(finAngle))
        fin.translateBy(x: -30, y: -23)
        fin.fill(FishPaths.fin, with: .color(style.fin))

        c.fill(Path(ellipseIn: CGRect(x: 43.6, y: 14.6, width: 4.8, height: 4.8)), with: .color(Color(seaHex: 0x0B2B3C)))
        c.fill(Path(ellipseIn: CGRect(x: 46.0, y: 15.4, width: 1.6, height: 1.6)), with: .color(.white))
    }

    // MARK: Sun rays

    private func drawRays(_ ctx: inout GraphicsContext) {
        // (left fraction, width fraction, opacity, full drift period s, phase s)
        let rays: [(left: CGFloat, width: CGFloat, alpha: Double, period: Double, phase: Double)] = [
            (0.36, 0.24, 0.16, 14, 0), (0.58, 0.12, 0.11, 19, 4)
        ]
        for r in rays {
            let w = r.width * S, h = 1.6 * S
            let cx = (r.left + r.width / 2) * S
            let dx = CGFloat(-0.22 + 0.44 * osc(t, period: r.period, phase: r.phase)) * w
            var c = ctx
            c.blendMode = .screen
            c.opacity = r.alpha
            c.translateBy(x: cx + dx, y: 0.5 * S)
            c.rotate(by: .degrees(-28))
            c.translateBy(x: -w / 2, y: -h / 2)
            c.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)),
                   with: .linearGradient(Gradient(colors: [Color.white.opacity(0), .white, Color.white.opacity(0)]),
                                         startPoint: .zero, endPoint: CGPoint(x: w, y: 0)))
        }
    }
}

// MARK: - Fish geometry (64 x 40 box, facing right)

private enum FishPaths {
    static let tail: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 15, y: 20))
        p.addLine(to: CGPoint(x: 3, y: 8))
        p.addCurve(to: CGPoint(x: 3, y: 32), control1: CGPoint(x: 7, y: 14), control2: CGPoint(x: 7, y: 26))
        p.closeSubpath()
        return p
    }()

    static let dorsal: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 22, y: 12))
        p.addCurve(to: CGPoint(x: 42, y: 9), control1: CGPoint(x: 25, y: 1), control2: CGPoint(x: 37, y: 0))
        p.closeSubpath()
        return p
    }()

    static let body: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 14, y: 20))
        p.addCurve(to: CGPoint(x: 53, y: 18), control1: CGPoint(x: 19, y: 7), control2: CGPoint(x: 44, y: 6))
        p.addCurve(to: CGPoint(x: 53, y: 22), control1: CGPoint(x: 54, y: 19.5), control2: CGPoint(x: 54, y: 20.5))
        p.addCurve(to: CGPoint(x: 14, y: 20), control1: CGPoint(x: 44, y: 34), control2: CGPoint(x: 19, y: 33))
        p.closeSubpath()
        return p
    }()

    static let highlight: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 23, y: 13))
        p.addCurve(to: CGPoint(x: 47, y: 14), control1: CGPoint(x: 30, y: 8), control2: CGPoint(x: 40, y: 9))
        return p
    }()

    static let gill: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 42, y: 13))
        p.addCurve(to: CGPoint(x: 42, y: 27), control1: CGPoint(x: 46, y: 17), control2: CGPoint(x: 46, y: 24))
        return p
    }()

    static let fin: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 30, y: 23))
        p.addCurve(to: CGPoint(x: 24, y: 23), control1: CGPoint(x: 26, y: 31), control2: CGPoint(x: 21, y: 31))
        p.closeSubpath()
        return p
    }()
}

// MARK: - Helpers

/// Eased value that glides to a new target (used for the water level in determinate mode).
private struct SmoothValue {
    private var from: Double
    private var to: Double
    private var start: TimeInterval
    private var duration: Double

    init(_ value: Double) {
        from = value; to = value; start = 0; duration = 0
    }

    func value(at time: TimeInterval) -> Double {
        guard duration > 0 else { return to }
        let x = min(max((time - start) / duration, 0), 1)
        let eased = 1 - pow(1 - x, 3)                   // ease-out cubic
        return from + (to - from) * eased
    }

    mutating func retarget(_ target: Double, at time: TimeInterval, duration d: Double) {
        from = value(at: time)
        to = target
        start = time
        duration = d
    }
}

/// Smooth 0 → 1 → 0 oscillation (equivalent to an ease-in-out alternate animation).
@inline(__always) private func osc(_ t: Double, period: Double, phase: Double = 0) -> Double {
    0.5 - 0.5 * cos(2 * .pi * (t + phase) / period)
}

@inline(__always) private func easeInOut(_ p: Double) -> Double {
    0.5 - 0.5 * cos(.pi * min(max(p, 0), 1))
}

@inline(__always) private func fract(_ x: Double) -> Double {
    x - floor(x)
}

private extension Color {
    init(seaHex hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

// MARK: - Demo

struct SeaLoaderDemo: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var progress: Double? = nil
    @State private var isSimulating = false

    var body: some View {
        ZStack {
            RadialGradient(colors: colorScheme == .dark
                                ? [Color(seaHex: 0x0C3247), Color(seaHex: 0x04141F)]
                                : [Color(seaHex: 0xE6F5F2), Color(seaHex: 0xC5E6EE)],
                           center: .top, startRadius: 0, endRadius: 900)
                .ignoresSafeArea()

            VStack(spacing: 56) {
                SeaLoader(progress: progress)

                Button("Show progress mode") { simulate() }
                    .buttonStyle(PillButtonStyle())
                    .disabled(isSimulating)
            }
        }
    }

    /// Uneven, real-looking load, then back to endless mode.
    private func simulate() {
        guard !isSimulating else { return }
        isSimulating = true
        Task { @MainActor in
            for step in [0, 0.08, 0.21, 0.27, 0.44, 0.51, 0.66, 0.70, 0.83, 0.95, 1.0] {
                progress = step
                try? await Task.sleep(nanoseconds: UInt64.random(in: 260_000_000...680_000_000))
            }
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            progress = nil
            isSimulating = false
        }
    }
}

private struct PillButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let dark = colorScheme == .dark
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(dark ? Color(seaHex: 0xC9EFE3) : Color(seaHex: 0x164F5B))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Capsule().fill(Color.white.opacity(dark ? 0.04 : 0.5)))
            .overlay(Capsule().strokeBorder(dark ? Color(seaHex: 0xC9EFE3).opacity(0.22)
                                                 : Color(seaHex: 0x164F5B).opacity(0.24), lineWidth: 1))
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

#Preview("Sea loader") {
    SeaLoaderDemo()
}

#Preview("Dark") {
    SeaLoaderDemo()
        .preferredColorScheme(.dark)
}

#Preview("Sizes") {
    HStack(spacing: 32) {
        SeaLoader(size: 120, title: "Syncing")
        SeaLoader(progress: 0.64, size: 160)
    }
    .padding(40)
}
