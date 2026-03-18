import SpriteKit

/// Pixel-art speech bubble that pops in above the husky, holds, then fades out
/// and removes itself from the scene.
class SpeechBubbleNode: SKNode {

    init(text: String) {
        super.init()

        let label = SKLabelNode(text: text)
        label.fontName = "Menlo-Bold"
        label.fontSize = 10
        label.fontColor = SKColor(white: 0.15, alpha: 1.0)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center

        // Bubble background sized to text
        let padX: CGFloat = 8
        let padY: CGFloat = 4
        let width = max(label.frame.width + padX * 2, 30)
        let height = label.frame.height + padY * 2
        let rect = CGRect(x: -width / 2, y: 0, width: width, height: height)
        let bg = SKShapeNode(path: CGPath(roundedRect: rect, cornerWidth: 4, cornerHeight: 4, transform: nil))
        bg.fillColor = SKColor(white: 0.95, alpha: 0.92)
        bg.strokeColor = SKColor(white: 0.25, alpha: 0.7)
        bg.lineWidth = 1

        // Tail triangle pointing down
        let tailPath = CGMutablePath()
        tailPath.move(to: CGPoint(x: -3, y: 0))
        tailPath.addLine(to: CGPoint(x: 0, y: -4))
        tailPath.addLine(to: CGPoint(x: 3, y: 0))
        tailPath.closeSubpath()
        let tail = SKShapeNode(path: tailPath)
        tail.fillColor = bg.fillColor
        tail.strokeColor = bg.strokeColor
        tail.lineWidth = 1

        addChild(bg)
        addChild(tail)
        label.position = CGPoint(x: 0, y: height / 2)
        addChild(label)

        alpha = 0
        setScale(0.5)
    }

    required init?(coder: NSCoder) { fatalError() }

    func show(duration: TimeInterval = 2.5) {
        let appear = SKAction.group([
            SKAction.fadeIn(withDuration: 0.15),
            SKAction.scale(to: 1.0, duration: 0.15),
        ])

        run(SKAction.sequence([
            appear,
            SKAction.wait(forDuration: duration),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.scale(to: 0.8, duration: 0.3),
            ]),
            SKAction.removeFromParent(),
        ]))
    }
}
