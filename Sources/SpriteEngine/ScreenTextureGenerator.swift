import SpriteKit

/// Generates dark, ambient screen content textures programmatically.
///
/// These fill the monitor trapezoids with subtle content that looks like
/// a real screen seen from across a dim room -- dark with faint hints of
/// what's on screen. Much better than bright icon-like textures.
final class ScreenTextureGenerator {

    static let shared = ScreenTextureGenerator()

    private var cache: [String: SKTexture] = [:]

    // Warm dark palette matching the cozy room
    private let screenBlack = (r: 0.04, g: 0.03, b: 0.06)

    // MARK: - Public

    /// Get a random center screen texture for the given category.
    func centerTexture(for category: ScreenContentManager.StatusCategory) -> SKTexture {
        let variants: [String]
        switch category {
        case .working:    variants = ["code", "terminal", "chat"]
        case .waiting:    variants = ["chat", "browser"]
        case .idle:       variants = ["music", "social", "chart"]
        case .noSessions: variants = ["music", "social", "chart"]
        case .error:      variants = ["terminal", "browser"]
        }
        let pick = variants.randomElement() ?? "code"
        return texture(named: "center-\(pick)", size: 96, generator: centerGenerator(pick))
    }

    /// Get a random side screen texture for the given category.
    /// Uses the same content types as center but avoids duplicating within one rotation.
    func sideTexture(for category: ScreenContentManager.StatusCategory, excluding: String? = nil) -> SKTexture {
        let variants: [String]
        switch category {
        case .working:    variants = ["code", "terminal", "chat"]
        case .waiting:    variants = ["chat", "browser"]
        case .idle:       variants = ["music", "social", "chart"]
        case .noSessions: variants = ["music", "social", "chart"]
        case .error:      variants = ["terminal", "browser"]
        }
        // Avoid showing the same content as the excluded name
        let filtered = variants.filter { $0 != excluding }
        let pick = filtered.randomElement() ?? variants.randomElement() ?? "code"
        return texture(named: "side-\(pick)", size: 96, generator: centerGenerator(pick))
    }

    // MARK: - Texture Cache

    private func texture(named name: String, size: Int, generator: () -> CGImage?) -> SKTexture {
        if let cached = cache[name] { return cached }
        guard let image = generator() else {
            return SKTexture(cgImage: fallbackImage(size: size))
        }
        let tex = SKTexture(cgImage: image)
        tex.filteringMode = .nearest
        cache[name] = tex
        return tex
    }

    // MARK: - Center Screen Generators (96x64)

    private func centerGenerator(_ variant: String) -> () -> CGImage? {
        switch variant {
        case "code":     return { self.generateCode() }
        case "terminal": return { self.generateTerminal() }
        case "chat":     return { self.generateChat() }
        case "browser":  return { self.generateBrowser() }
        case "music":    return { self.generateMusic() }
        case "social":   return { self.generateSocial() }
        case "chart":    return { self.generateChart() }
        default:         return { self.generateCode() }
        }
    }

    /// Dark code editor: faint colored lines on near-black
    private func generateCode() -> CGImage? {
        let w = 96, h = 64
        return withContext(w: w, h: h) { ctx in
            // Faint line number gutter
            ctx.setFillColor(CGColor(srgbRed: 0.08, green: 0.07, blue: 0.10, alpha: 1.0))
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: h))

            // Code lines at random positions with syntax colors
            let colors: [(r: Double, g: Double, b: Double)] = [
                (0.4, 0.5, 0.7),   // keyword blue
                (0.6, 0.4, 0.6),   // string purple
                (0.3, 0.5, 0.3),   // comment green
                (0.6, 0.5, 0.3),   // variable amber
                (0.5, 0.4, 0.4),   // plain gray
            ]
            for y in stride(from: 4, to: h - 2, by: Int.random(in: 5...7)) {
                let indent = Int.random(in: 12...28)
                let lineLen = Int.random(in: 15...55)
                let c = colors.randomElement()!
                let alpha = Double.random(in: 0.18...0.35)
                ctx.setFillColor(CGColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: alpha))
                ctx.fill(CGRect(x: indent, y: y, width: lineLen, height: 2))

                // Sometimes a second segment (different color)
                if Bool.random() {
                    let c2 = colors.randomElement()!
                    let gap = Int.random(in: 2...4)
                    let len2 = Int.random(in: 8...20)
                    ctx.setFillColor(CGColor(srgbRed: c2.r, green: c2.g, blue: c2.b, alpha: alpha * 0.8))
                    ctx.fill(CGRect(x: indent + lineLen + gap, y: y, width: len2, height: 2))
                }
            }
        }
    }

    /// Dark terminal: faint green text on black
    private func generateTerminal() -> CGImage? {
        let w = 96, h = 64
        return withContext(w: w, h: h) { ctx in
            // Prompt lines with green tint
            for y in stride(from: 4, to: h - 4, by: Int.random(in: 6...8)) {
                // Prompt symbol
                let alpha = Double.random(in: 0.15...0.30)
                ctx.setFillColor(CGColor(srgbRed: 0.2, green: 0.5, blue: 0.25, alpha: alpha))
                ctx.fill(CGRect(x: 4, y: y, width: 6, height: 2))

                // Command text
                let cmdLen = Int.random(in: 20...65)
                let cmdAlpha = Double.random(in: 0.12...0.25)
                ctx.setFillColor(CGColor(srgbRed: 0.25, green: 0.45, blue: 0.2, alpha: cmdAlpha))
                ctx.fill(CGRect(x: 12, y: y, width: cmdLen, height: 2))

                // Output lines (dimmer)
                if Bool.random() {
                    let outY = y + Int.random(in: 3...4)
                    let outLen = Int.random(in: 30...70)
                    ctx.setFillColor(CGColor(srgbRed: 0.2, green: 0.35, blue: 0.18, alpha: cmdAlpha * 0.6))
                    ctx.fill(CGRect(x: 6, y: outY, width: outLen, height: 1))
                }
            }
        }
    }

    /// Dark chat: faint message bubbles
    private func generateChat() -> CGImage? {
        let w = 96, h = 64
        return withContext(w: w, h: h) { ctx in
            // Chat header bar
            ctx.setFillColor(CGColor(srgbRed: 0.08, green: 0.06, blue: 0.10, alpha: 1.0))
            ctx.fill(CGRect(x: 0, y: h - 8, width: w, height: 8))

            // Message bubbles alternating sides
            var y = 6
            var isLeft = true
            while y < h - 12 {
                let bubbleW = Int.random(in: 25...50)
                let bubbleH = Int.random(in: 5...10)
                let x = isLeft ? 6 : w - bubbleW - 6
                let alpha = Double.random(in: 0.12...0.22)

                if isLeft {
                    ctx.setFillColor(CGColor(srgbRed: 0.15, green: 0.12, blue: 0.22, alpha: alpha))
                } else {
                    ctx.setFillColor(CGColor(srgbRed: 0.1, green: 0.15, blue: 0.22, alpha: alpha))
                }

                let rect = CGRect(x: x, y: y, width: bubbleW, height: bubbleH)
                let path = CGPath(roundedRect: rect, cornerWidth: 2, cornerHeight: 2, transform: nil)
                ctx.addPath(path)
                ctx.fillPath()

                y += bubbleH + Int.random(in: 3...5)
                isLeft.toggle()
            }
        }
    }

    /// Dark browser: faint address bar and content blocks
    private func generateBrowser() -> CGImage? {
        let w = 96, h = 64
        return withContext(w: w, h: h) { ctx in
            // Tab bar
            ctx.setFillColor(CGColor(srgbRed: 0.07, green: 0.06, blue: 0.09, alpha: 1.0))
            ctx.fill(CGRect(x: 0, y: h - 6, width: w, height: 6))

            // Address bar
            ctx.setFillColor(CGColor(srgbRed: 0.06, green: 0.05, blue: 0.08, alpha: 1.0))
            ctx.fill(CGRect(x: 0, y: h - 12, width: w, height: 5))
            ctx.setFillColor(CGColor(srgbRed: 0.15, green: 0.18, blue: 0.25, alpha: 0.2))
            ctx.fill(CGRect(x: 8, y: h - 11, width: 50, height: 3))

            // Content blocks
            for y in stride(from: 4, to: h - 16, by: Int.random(in: 7...10)) {
                let blockW = Int.random(in: 30...75)
                let blockH = Int.random(in: 3...6)
                let x = Int.random(in: 4...12)
                let alpha = Double.random(in: 0.08...0.15)
                ctx.setFillColor(CGColor(srgbRed: 0.15, green: 0.14, blue: 0.18, alpha: alpha))
                ctx.fill(CGRect(x: x, y: y, width: blockW, height: blockH))
            }
        }
    }

    /// Dark music player: faint visualizer bars
    private func generateMusic() -> CGImage? {
        let w = 96, h = 64
        return withContext(w: w, h: h) { ctx in
            // Album art placeholder (dark square)
            ctx.setFillColor(CGColor(srgbRed: 0.08, green: 0.06, blue: 0.10, alpha: 1.0))
            ctx.fill(CGRect(x: 30, y: 28, width: 24, height: 24))

            // Progress bar
            ctx.setFillColor(CGColor(srgbRed: 0.2, green: 0.15, blue: 0.25, alpha: 0.2))
            ctx.fill(CGRect(x: 12, y: 20, width: 60, height: 2))
            ctx.setFillColor(CGColor(srgbRed: 0.3, green: 0.2, blue: 0.35, alpha: 0.25))
            ctx.fill(CGRect(x: 12, y: 20, width: 35, height: 2))

            // Visualizer bars at bottom
            let barCount = 16
            let barW = 3
            let gap = 2
            let startX = (w - barCount * (barW + gap)) / 2
            for i in 0..<barCount {
                let barH = Int.random(in: 3...18)
                let alpha = Double.random(in: 0.12...0.25)
                ctx.setFillColor(CGColor(srgbRed: 0.3, green: 0.2, blue: 0.4, alpha: alpha))
                ctx.fill(CGRect(x: startX + i * (barW + gap), y: 3, width: barW, height: barH))
            }
        }
    }

    /// Dark social feed: faint post blocks
    private func generateSocial() -> CGImage? {
        let w = 96, h = 64
        return withContext(w: w, h: h) { ctx in
            var y = 4
            while y < h - 6 {
                // Avatar circle hint
                let alpha = Double.random(in: 0.10...0.18)
                ctx.setFillColor(CGColor(srgbRed: 0.18, green: 0.15, blue: 0.20, alpha: alpha))
                ctx.fillEllipse(in: CGRect(x: 4, y: y + 1, width: 5, height: 5))

                // Name line
                ctx.setFillColor(CGColor(srgbRed: 0.20, green: 0.18, blue: 0.22, alpha: alpha))
                ctx.fill(CGRect(x: 12, y: y + 4, width: Int.random(in: 15...25), height: 2))

                // Post text lines
                for line in 0..<Int.random(in: 1...3) {
                    let lineAlpha = alpha * 0.7
                    ctx.setFillColor(CGColor(srgbRed: 0.15, green: 0.13, blue: 0.18, alpha: lineAlpha))
                    ctx.fill(CGRect(x: 12, y: y - line * 3, width: Int.random(in: 40...70), height: 1))
                }

                // Divider
                ctx.setFillColor(CGColor(srgbRed: 0.08, green: 0.07, blue: 0.10, alpha: 0.5))
                ctx.fill(CGRect(x: 2, y: y - 1, width: w - 4, height: 1))

                y += Int.random(in: 12...18)
            }
        }
    }

    /// Dark chart: faint candlesticks or line
    private func generateChart() -> CGImage? {
        let w = 96, h = 64
        return withContext(w: w, h: h) { ctx in
            // Axis lines
            ctx.setFillColor(CGColor(srgbRed: 0.10, green: 0.09, blue: 0.12, alpha: 0.5))
            ctx.fill(CGRect(x: 8, y: 6, width: 1, height: h - 14))
            ctx.fill(CGRect(x: 8, y: 6, width: w - 16, height: 1))

            // Line chart
            var prevX = 12
            var prevY = Int.random(in: 20...40)
            for x in stride(from: 14, to: w - 8, by: 3) {
                let newY = max(10, min(h - 12, prevY + Int.random(in: -5...5)))
                let alpha = Double.random(in: 0.15...0.28)
                ctx.setStrokeColor(CGColor(srgbRed: 0.2, green: 0.35, blue: 0.3, alpha: alpha))
                ctx.setLineWidth(1.5)
                ctx.move(to: CGPoint(x: prevX, y: prevY))
                ctx.addLine(to: CGPoint(x: x, y: newY))
                ctx.strokePath()
                prevX = x
                prevY = newY
            }

            // Grid lines (very faint)
            for gy in stride(from: 15, to: h - 10, by: 12) {
                ctx.setFillColor(CGColor(srgbRed: 0.08, green: 0.07, blue: 0.10, alpha: 0.3))
                ctx.fill(CGRect(x: 9, y: gy, width: w - 18, height: 1))
            }
        }
    }

    // Side screens reuse center generators -- the abstract patterns (dots, bars)
    // were too sparse to read at tiny sizes. Same content, different random seed.

    // MARK: - Helpers

    private func withContext(w: Int, h: Int, draw: (CGContext) -> Void) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Fill with near-black background
        ctx.setFillColor(CGColor(srgbRed: screenBlack.r, green: screenBlack.g, blue: screenBlack.b, alpha: 1.0))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

        draw(ctx)
        return ctx.makeImage()
    }

    private func fallbackImage(size: Int) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil, width: size, height: size,
            bitsPerComponent: 8, bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(CGColor(srgbRed: screenBlack.r, green: screenBlack.g, blue: screenBlack.b, alpha: 1.0))
        ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        return ctx.makeImage()!
    }
}
