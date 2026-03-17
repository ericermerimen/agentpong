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
        // No caching -- each call generates a fresh random texture
        // so all 3 screens look different and each rotation is unique.
        guard let image = generator() else {
            return SKTexture(cgImage: fallbackImage(size: size))
        }
        let tex = SKTexture(cgImage: image)
        tex.filteringMode = .nearest
        return tex
    }

    // MARK: - Screen Generators (96 wide x 192 tall for scrolling)

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

    /// Code editor: colored syntax lines on dark background
    private func generateCode() -> CGImage? {
        let w = 96, h = 192
        return withContext(w: w, h: h) { ctx in
            // Line number gutter
            ctx.setFillColor(CGColor(srgbRed: 0.08, green: 0.07, blue: 0.10, alpha: 1.0))
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: h))

            let colors: [(r: Double, g: Double, b: Double)] = [
                (0.45, 0.55, 0.75),  // keyword blue
                (0.65, 0.45, 0.65),  // string purple
                (0.35, 0.55, 0.35),  // comment green
                (0.65, 0.55, 0.35),  // variable amber
                (0.5, 0.45, 0.45),   // plain gray
            ]
            for y in stride(from: 3, to: h - 2, by: Int.random(in: 4...6)) {
                let indent = Int.random(in: 12...28)
                let lineLen = Int.random(in: 15...55)
                let c = colors.randomElement()!
                let alpha = Double.random(in: 0.55...0.80)
                ctx.setFillColor(CGColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: alpha))
                ctx.fill(CGRect(x: indent, y: y, width: lineLen, height: 2))

                if Bool.random() {
                    let c2 = colors.randomElement()!
                    let gap = Int.random(in: 2...4)
                    let len2 = Int.random(in: 8...20)
                    ctx.setFillColor(CGColor(srgbRed: c2.r, green: c2.g, blue: c2.b, alpha: alpha * 0.7))
                    ctx.fill(CGRect(x: indent + lineLen + gap, y: y, width: len2, height: 2))
                }
            }
        }
    }

    /// Terminal: green text on black
    private func generateTerminal() -> CGImage? {
        let w = 96, h = 192
        return withContext(w: w, h: h) { ctx in
            for y in stride(from: 3, to: h - 3, by: Int.random(in: 5...7)) {
                let alpha = Double.random(in: 0.50...0.80)
                // Prompt
                ctx.setFillColor(CGColor(srgbRed: 0.25, green: 0.6, blue: 0.3, alpha: alpha))
                ctx.fill(CGRect(x: 4, y: y, width: 6, height: 2))
                // Command
                let cmdLen = Int.random(in: 20...65)
                ctx.setFillColor(CGColor(srgbRed: 0.3, green: 0.55, blue: 0.25, alpha: alpha * 0.7))
                ctx.fill(CGRect(x: 12, y: y, width: cmdLen, height: 2))
                // Output
                if Bool.random() {
                    let outLen = Int.random(in: 30...70)
                    ctx.setFillColor(CGColor(srgbRed: 0.25, green: 0.4, blue: 0.2, alpha: alpha * 0.4))
                    ctx.fill(CGRect(x: 6, y: y + Int.random(in: 3...4), width: outLen, height: 1))
                }
            }
        }
    }

    /// Chat: message bubbles alternating sides
    private func generateChat() -> CGImage? {
        let w = 96, h = 192
        return withContext(w: w, h: h) { ctx in
            var y = 4
            var isLeft = true
            while y < h - 6 {
                let bubbleW = Int.random(in: 25...55)
                let bubbleH = Int.random(in: 5...10)
                let x = isLeft ? 6 : w - bubbleW - 6
                let alpha = Double.random(in: 0.50...0.70)
                let color = isLeft
                    ? CGColor(srgbRed: 0.2, green: 0.15, blue: 0.3, alpha: alpha)
                    : CGColor(srgbRed: 0.12, green: 0.2, blue: 0.3, alpha: alpha)
                ctx.setFillColor(color)
                let rect = CGRect(x: x, y: y, width: bubbleW, height: bubbleH)
                ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 2, cornerHeight: 2, transform: nil))
                ctx.fillPath()
                y += bubbleH + Int.random(in: 3...5)
                isLeft.toggle()
            }
        }
    }

    /// Browser: address bar and content blocks
    private func generateBrowser() -> CGImage? {
        let w = 96, h = 192
        return withContext(w: w, h: h) { ctx in
            // Tab + address bar at top (scrolls away)
            ctx.setFillColor(CGColor(srgbRed: 0.07, green: 0.06, blue: 0.09, alpha: 1.0))
            ctx.fill(CGRect(x: 0, y: h - 10, width: w, height: 10))
            ctx.setFillColor(CGColor(srgbRed: 0.18, green: 0.22, blue: 0.3, alpha: 0.35))
            ctx.fill(CGRect(x: 8, y: h - 8, width: 50, height: 3))
            // Content blocks
            for y in stride(from: 4, to: h - 14, by: Int.random(in: 6...9)) {
                let blockW = Int.random(in: 30...75)
                let blockH = Int.random(in: 2...5)
                let x = Int.random(in: 4...12)
                let alpha = Double.random(in: 0.50...0.65)
                ctx.setFillColor(CGColor(srgbRed: 0.18, green: 0.17, blue: 0.22, alpha: alpha))
                ctx.fill(CGRect(x: x, y: y, width: blockW, height: blockH))
            }
        }
    }

    /// Music player: visualizer bars
    private func generateMusic() -> CGImage? {
        let w = 96, h = 192
        return withContext(w: w, h: h) { ctx in
            // Repeating visualizer sections
            for section in stride(from: 4, to: h - 4, by: 24) {
                let barCount = 16
                let barW = 3
                let gap = 2
                let startX = (w - barCount * (barW + gap)) / 2
                for i in 0..<barCount {
                    let barH = Int.random(in: 3...20)
                    let alpha = Double.random(in: 0.50...0.75)
                    ctx.setFillColor(CGColor(srgbRed: 0.35, green: 0.25, blue: 0.5, alpha: alpha))
                    ctx.fill(CGRect(x: startX + i * (barW + gap), y: section, width: barW, height: barH))
                }
            }
        }
    }

    /// Social feed: post blocks with avatars
    private func generateSocial() -> CGImage? {
        let w = 96, h = 192
        return withContext(w: w, h: h) { ctx in
            var y = 4
            while y < h - 6 {
                let alpha = Double.random(in: 0.50...0.70)
                ctx.setFillColor(CGColor(srgbRed: 0.22, green: 0.18, blue: 0.25, alpha: alpha))
                ctx.fillEllipse(in: CGRect(x: 4, y: y + 1, width: 5, height: 5))
                ctx.fill(CGRect(x: 12, y: y + 4, width: Int.random(in: 15...25), height: 2))
                for line in 0..<Int.random(in: 1...3) {
                    ctx.setFillColor(CGColor(srgbRed: 0.18, green: 0.16, blue: 0.22, alpha: alpha * 0.7))
                    ctx.fill(CGRect(x: 12, y: y - line * 3, width: Int.random(in: 40...70), height: 1))
                }
                ctx.setFillColor(CGColor(srgbRed: 0.10, green: 0.09, blue: 0.12, alpha: 0.6))
                ctx.fill(CGRect(x: 2, y: y - 1, width: w - 4, height: 1))
                y += Int.random(in: 12...18)
            }
        }
    }

    /// Chart: line graph with grid
    private func generateChart() -> CGImage? {
        let w = 96, h = 192
        return withContext(w: w, h: h) { ctx in
            // Grid
            for gy in stride(from: 10, to: h - 5, by: 16) {
                ctx.setFillColor(CGColor(srgbRed: 0.10, green: 0.09, blue: 0.12, alpha: 0.4))
                ctx.fill(CGRect(x: 8, y: gy, width: w - 16, height: 1))
            }
            // Line chart
            var prevX = 10
            var prevY = Int.random(in: 30...h/2)
            for x in stride(from: 12, to: w - 6, by: 3) {
                let newY = max(8, min(h - 8, prevY + Int.random(in: -8...8)))
                ctx.setStrokeColor(CGColor(srgbRed: 0.25, green: 0.45, blue: 0.35, alpha: 0.5))
                ctx.setLineWidth(1.5)
                ctx.move(to: CGPoint(x: prevX, y: prevY))
                ctx.addLine(to: CGPoint(x: x, y: newY))
                ctx.strokePath()
                prevX = x
                prevY = newY
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
