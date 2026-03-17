import SpriteKit
import Shared

/// The office husky -- always present, wanders the room, reacts to screen state.
///
/// Behavior system: weighted random selection from idle behaviors,
/// interrupted by screen reactions and user clicks.
///
/// ANIMATION RULE: Never modify sprite scale in animations.
/// Perspective scaling is handled by OfficeScene via setScale() on this node.
/// Sprite scale is ONLY set in setSpriteDirection().
class HuskyNode: SKNode {

    private let sprite: SKSpriteNode
    let shadow: SKNode  // Exposed so OfficeScene can manage it separately
    private let assets = SpriteAssetLoader.shared
    private let hasRealSprites: Bool
    private let baseTexture: SKTexture?  // Standing south texture for guaranteed reset

    private var wanderTimer: TimeInterval = 0
    private var nextActionDelay: TimeInterval = 3.0
    private let wanderZone: CGRect
    private let huskyScale: CGFloat

    // Special positions
    var dogBedPosition: CGPoint = .zero
    var waterBowlPosition: CGPoint = .zero
    var monitorPosition: CGPoint = .zero
    var lampPosition: CGPoint = .zero
    var lampExclusionRadius: CGFloat = 20

    // MARK: - Behavior State Machine

    enum Behavior {
        case idle              // standing still, breathing
        case wandering         // walking to a random point
        case sitting           // sitting upright (sprite animation)
        case lyingDown         // lying flat (sprite animation)
        case sleeping          // curled up on dog bed (sprite animation)
        case playing           // rolling/batting paws (sprite animation)
        case drinking          // at water bowl (sprite animation)
        case zoomies           // sudden fast run in random pattern
        case lookingAround     // cycling through directions
        case watchingCursor    // facing mouse direction
        case reactingToScreen  // walking toward monitor
        case scared            // running away from click
    }

    private(set) var behavior: Behavior = .idle
    private var idleDuration: TimeInterval = 0  // how long in current idle behavior

    init(startPosition: CGPoint, wanderZone: CGRect, spriteSize: CGFloat) {
        self.wanderZone = wanderZone
        self.huskyScale = 1.5

        if let tex = assets.huskyTexture(direction: "south") {
            sprite = SKSpriteNode(texture: tex)
            sprite.setScale(huskyScale)
            baseTexture = tex
            hasRealSprites = true
        } else {
            sprite = SKSpriteNode(
                color: SKColor(red: 0.6, green: 0.6, blue: 0.65, alpha: 1.0),
                size: CGSize(width: 16, height: 12)
            )
            baseTexture = nil
            hasRealSprites = false
        }
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.0)

        // Shadow: separate node, NOT a child of HuskyNode.
        // OfficeScene adds it independently so perspective setScale() on HuskyNode
        // doesn't distort the shadow position.
        let shadowShape = SKShapeNode(ellipseOf: CGSize(width: 18, height: 7))
        shadowShape.fillColor = SKColor(white: 0, alpha: 0.18)
        shadowShape.strokeColor = .clear
        shadowShape.zPosition = -1
        shadow = shadowShape

        super.init()
        addChild(sprite)
        position = startPosition
        name = "husky"

        playIdleAnimation()
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(deltaTime: TimeInterval) {
        // Only pick new actions when in a non-busy state
        let canAct = (behavior == .idle || behavior == .sitting
                      || behavior == .lyingDown || behavior == .lookingAround
                      || behavior == .watchingCursor)
        guard canAct else { return }

        wanderTimer += deltaTime
        idleDuration += deltaTime

        if wanderTimer >= nextActionDelay {
            wanderTimer = 0
            pickNextAction()
        }
    }

    // MARK: - Action Selection

    private func pickNextAction() {
        // Weighted random selection based on what feels natural
        // After sitting/lying for a while, more likely to get up and move
        let weights: [(Behavior, Double)] = [
            (.wandering, 30),        // most common: wander to new spot
            (.sitting, 15),          // sit down for a bit
            (.lookingAround, 15),    // look around the room
            (.lyingDown, 10),        // lie down flat
            (.playing, 8),           // playful roll
            (.drinking, 5),          // go drink water
            (.zoomies, 4),           // sudden burst of energy
            (.watchingCursor, 8),    // track the user's mouse
            (.idle, 5),              // just stand and breathe
        ]

        let total = weights.reduce(0) { $0 + $1.1 }
        var roll = Double.random(in: 0..<total)
        var picked: Behavior = .idle

        for (b, w) in weights {
            roll -= w
            if roll <= 0 { picked = b; break }
        }

        executeAction(picked)
    }

    private func executeAction(_ action: Behavior) {
        switch action {
        case .wandering:
            wanderToRandomSpot()
        case .sitting:
            startSitting()
        case .lyingDown:
            startLyingDown()
        case .playing:
            startPlaying()
        case .drinking:
            goToDrinkWater()
        case .zoomies:
            startZoomies()
        case .lookingAround:
            startLookingAround()
        case .watchingCursor:
            startWatchingCursor()
        case .idle:
            behavior = .idle
            playIdleAnimation()
            nextActionDelay = Double.random(in: 3...8)
        default:
            break
        }
    }

    // MARK: - Screen Reactions

    func reactToScreenStatus(_ status: ScreenNode.ScreenStatus) {
        switch status {
        case .error:
            reactToError()
        case .needsInput:
            reactToWarning()
        case .running:
            if behavior == .sleeping { wakeUp() }
        case .idle, .off:
            break
        }
    }

    func goNap() {
        guard behavior != .sleeping else { return }
        behavior = .reactingToScreen

        // Walk to dog bed, then transition to sleep
        walkTo(target: dogBedPosition, speed: 25) { [weak self] in
            self?.behavior = .sleeping
            // playSleepAnimation handles its own texture (no clearSpriteAnimations needed
            // since walkTo's completion already cleared + set south)
            self?.playSleepAnimation()
        }
    }

    private func wakeUp() {
        behavior = .idle
        clearSpriteAnimations()
        setSpriteDirection("south", flipX: false)
        playIdleAnimation()
        wanderTimer = 0
        nextActionDelay = 2.0
    }

    private func reactToError() {
        guard behavior != .scared else { return }
        behavior = .reactingToScreen

        let nearMonitor = CGPoint(
            x: monitorPosition.x + CGFloat.random(in: -15...15),
            y: monitorPosition.y - 25
        )
        walkTo(target: nearMonitor, speed: 50) { [weak self] in
            self?.playBarkAnimation {
                self?.transitionToIdle(delay: 3...6)
            }
        }
    }

    private func reactToWarning() {
        guard behavior == .idle || behavior == .sitting || behavior == .lyingDown
              || behavior == .lookingAround || behavior == .watchingCursor else { return }
        behavior = .reactingToScreen

        let nearMonitor = CGPoint(
            x: monitorPosition.x + CGFloat.random(in: -10...10),
            y: monitorPosition.y - 25
        )
        walkTo(target: nearMonitor, speed: 35) { [weak self] in
            self?.playHeadTiltAnimation {
                self?.transitionToIdle(delay: 4...8)
            }
        }
    }

    private func transitionToIdle(delay: ClosedRange<Double>) {
        behavior = .idle
        idleDuration = 0
        wanderTimer = 0
        nextActionDelay = Double.random(in: delay)
        playIdleAnimation()
    }

    // MARK: - Click

    func hitTest(_ point: CGPoint) -> Bool {
        let hitFrame = CGRect(
            x: position.x - 20, y: position.y - 5,
            width: 40, height: 50
        )
        return hitFrame.contains(point)
    }

    func scare() {
        let wasSleeping = (behavior == .sleeping || behavior == .lyingDown)
        behavior = .scared
        removeAction(forKey: "wander")
        clearSpriteAnimations()

        // Pick farthest random point
        var best = position
        var bestDist: CGFloat = 0
        for _ in 0..<8 {
            let candidate = CGPoint(
                x: CGFloat.random(in: wanderZone.minX...wanderZone.maxX),
                y: CGFloat.random(in: wanderZone.minY...wanderZone.maxY)
            )
            let dist = hypot(candidate.x - position.x, candidate.y - position.y)
            if dist > bestDist { bestDist = dist; best = candidate }
        }

        let dir = dominantDirection(toward: best)
        let isFlipped = (dir == "east" || dir == "north-east" || dir == "south-east")
        let texDir = mirrorDirection(dir)
        setSpriteDirection(texDir, flipX: isFlipped)

        // Use running animation for scared sprint
        var runFrames = assets.huskyRunFrames(direction: dir)
        if runFrames.isEmpty {
            if let mirror = mirrorMap[dir] {
                runFrames = assets.huskyRunFrames(direction: mirror)
            }
        }
        if !runFrames.isEmpty {
            sprite.run(SKAction.repeatForever(SKAction.animate(with: runFrames, timePerFrame: 1.0 / 14.0)), withKey: "walkAnim")
        } else {
            startWalkAnimation(direction: dir, speed: 14.0)
        }

        let distance = hypot(best.x - position.x, best.y - position.y)

        // If was sleeping, brief startled pause before running
        let preDelay: TimeInterval = wasSleeping ? 0.3 : 0
        let move = SKAction.move(to: best, duration: TimeInterval(distance / 100))
        move.timingMode = .easeOut

        let scareDir = texDir
        let scareFlipped = isFlipped
        let done = SKAction.run { [weak self] in
            // Keep facing the direction we ran -- don't snap to south
            self?.sprite.removeAllActions()
            self?.sprite.position = .zero
            self?.setSpriteDirection(scareDir, flipX: scareFlipped)
            self?.behavior = .idle
            self?.idleDuration = 0
            self?.wanderTimer = 0
            self?.nextActionDelay = Double.random(in: 6...15)
            self?.playIdleAnimation()
        }

        if preDelay > 0 {
            run(SKAction.sequence([SKAction.wait(forDuration: preDelay), move, done]), withKey: "wander")
        } else {
            run(SKAction.sequence([move, done]), withKey: "wander")
        }
    }

    // Direction mirroring helpers
    private let mirrorMap: [String: String] = [
        "east": "west", "north-east": "north-west", "south-east": "south-west"
    ]

    private func mirrorDirection(_ dir: String) -> String {
        mirrorMap[dir] ?? dir
    }

    // MARK: - Behaviors

    private func wanderToRandomSpot() {
        var target: CGPoint
        var attempts = 0
        repeat {
            target = CGPoint(
                x: CGFloat.random(in: wanderZone.minX...wanderZone.maxX),
                y: CGFloat.random(in: wanderZone.minY...wanderZone.maxY)
            )
            attempts += 1
        } while hypot(target.x - lampPosition.x, target.y - lampPosition.y) < lampExclusionRadius && attempts < 10

        behavior = .wandering
        walkTo(target: target, speed: 20) { [weak self] in
            self?.transitionToIdle(delay: 3...8)
        }
    }

    private func startSitting() {
        behavior = .sitting
        clearSpriteAnimations()
        setSpriteDirection("south", flipX: false)

        let frames = assets.huskySittingFrames()
        if !frames.isEmpty {
            let animate = SKAction.animate(with: frames, timePerFrame: 1.0 / 6.0)
            let hold = SKAction.animate(with: [frames.last!], timePerFrame: Double.random(in: 4...10))
            sprite.run(SKAction.sequence([animate, hold, SKAction.run { [weak self] in
                self?.transitionToIdle(delay: 2...5)
            }]))
        } else {
            // No sprite: just wait
            nextActionDelay = Double.random(in: 4...10)
            playIdleAnimation()
        }
    }

    private func startLyingDown() {
        behavior = .lyingDown
        clearSpriteAnimations()
        sprite.xScale = huskyScale  // no flip
        sprite.yScale = huskyScale

        let frames = assets.huskySleepingFrames()
        if !frames.isEmpty {
            // Transition down
            let lieDown = SKAction.animate(with: frames, timePerFrame: 1.0 / 4.0)
            // Breathe for a while (loop last 4 frames)
            let breathFrames = Array(frames.suffix(4))
            let breathe = SKAction.repeat(
                SKAction.animate(with: breathFrames, timePerFrame: 1.0 / 2.0),
                count: Int.random(in: 3...6)
            )
            // Get back up (reverse the transition)
            let getUp = SKAction.animate(with: frames.reversed(), timePerFrame: 1.0 / 6.0)
            sprite.run(SKAction.sequence([lieDown, breathe, getUp, SKAction.run { [weak self] in
                self?.transitionToIdle(delay: 2...4)
            }]))
        } else {
            nextActionDelay = Double.random(in: 4...8)
            playIdleAnimation()
        }
    }

    private func startPlaying() {
        behavior = .playing
        clearSpriteAnimations()
        setSpriteDirection("south", flipX: false)

        let frames = assets.huskyPlayingFrames()
        if !frames.isEmpty {
            let animate = SKAction.animate(with: frames, timePerFrame: 1.0 / 8.0)
            let playLoop = SKAction.repeat(animate, count: Int.random(in: 2...4))
            sprite.run(SKAction.sequence([playLoop, SKAction.run { [weak self] in
                self?.transitionToIdle(delay: 3...6)
            }]))
        } else {
            transitionToIdle(delay: 2...4)
        }
    }

    private func goToDrinkWater() {
        behavior = .drinking

        // Walk to just above the bowl, facing south (toward bowl)
        let drinkSpot = CGPoint(x: waterBowlPosition.x, y: waterBowlPosition.y + 12)
        walkTo(target: drinkSpot, speed: 25) { [weak self] in
            guard let self else { return }
            self.sprite.removeAllActions()
            self.sprite.position = .zero
            // Face south toward the bowl
            if let tex = self.baseTexture {
                self.sprite.texture = tex
                self.sprite.texture?.filteringMode = .nearest
            }
            self.sprite.xScale = self.huskyScale
            self.sprite.yScale = self.huskyScale

            self.playDrinkAnimation {
                // Reset to standing texture after drinking
                if let tex = self.baseTexture {
                    self.sprite.texture = tex
                    self.sprite.texture?.filteringMode = .nearest
                }
                self.transitionToIdle(delay: 3...6)
            }
        }
    }

    private func startZoomies() {
        behavior = .zoomies
        clearSpriteAnimations()

        // Build a zigzag path of 3-5 random points
        var points: [CGPoint] = []
        for _ in 0..<Int.random(in: 3...5) {
            let p = CGPoint(
                x: CGFloat.random(in: wanderZone.minX...wanderZone.maxX),
                y: CGFloat.random(in: wanderZone.minY...wanderZone.maxY)
            )
            points.append(p)
        }

        runZoomPath(points: points, index: 0)
    }

    private func runZoomPath(points: [CGPoint], index: Int) {
        guard index < points.count else {
            sprite.removeAllActions()
            sprite.position = .zero
            behavior = .idle
            idleDuration = 0
            wanderTimer = 0
            nextActionDelay = Double.random(in: 5...10)
            playIdleAnimation()
            return
        }

        let target = points[index]
        let dir = dominantDirection(toward: target)
        let isFlipped = (dir == "east" || dir == "north-east" || dir == "south-east")
        let texDir = mirrorDirection(dir)

        // Update direction and animation for this segment
        setSpriteDirection(texDir, flipX: isFlipped)

        var runFrames = assets.huskyRunFrames(direction: dir)
        if runFrames.isEmpty {
            if let mirror = mirrorMap[dir] {
                runFrames = assets.huskyRunFrames(direction: mirror)
            }
        }

        sprite.removeAction(forKey: "walkAnim")
        sprite.removeAction(forKey: "walkBob")
        if !runFrames.isEmpty {
            sprite.run(SKAction.repeatForever(SKAction.animate(with: runFrames, timePerFrame: 1.0 / 14.0)), withKey: "walkAnim")
        } else {
            let bob = SKAction.sequence([
                SKAction.moveBy(x: 0, y: 2.0, duration: 0.08),
                SKAction.moveBy(x: 0, y: -2.0, duration: 0.08),
            ])
            sprite.run(SKAction.repeatForever(bob), withKey: "walkBob")
        }

        let distance = hypot(target.x - position.x, target.y - position.y)
        let move = SKAction.move(to: target, duration: TimeInterval(distance / 90))
        move.timingMode = .easeInEaseOut

        run(SKAction.sequence([move, SKAction.run { [weak self] in
            self?.runZoomPath(points: points, index: index + 1)
        }]), withKey: "wander")
    }

    private func startLookingAround() {
        behavior = .lookingAround
        clearSpriteAnimations()

        let directions = ["south", "east", "south-west", "west", "south-east"].shuffled()
        var actions: [SKAction] = []

        for dir in directions.prefix(3) {
            actions.append(SKAction.run { [weak self] in
                let isWest = (dir == "west")
                self?.setSpriteDirection(isWest ? "east" : dir, flipX: isWest)
            })
            actions.append(SKAction.wait(forDuration: Double.random(in: 0.8...2.0)))
        }

        actions.append(SKAction.run { [weak self] in
            self?.setSpriteDirection("south", flipX: false)
            self?.transitionToIdle(delay: 3...6)
        })

        run(SKAction.sequence(actions), withKey: "wander")
    }

    private func startWatchingCursor() {
        behavior = .watchingCursor
        clearSpriteAnimations()
        // Just idle facing south -- mouseMoved in OfficeScene will call faceCursor()
        playIdleAnimation()
        nextActionDelay = Double.random(in: 4...8)
    }

    /// Called by OfficeScene.mouseMoved when behavior == .watchingCursor
    func faceCursor(scenePoint: CGPoint) {
        guard behavior == .watchingCursor else { return }
        let dir = dominantDirection(toward: scenePoint)
        let isWest = (dir == "west")
        setSpriteDirection(isWest ? "east" : dir, flipX: isWest)
    }

    // MARK: - Walk

    private func walkTo(target: CGPoint, speed: CGFloat, completion: (() -> Void)? = nil) {
        let dir = dominantDirection(toward: target)
        let distance = hypot(target.x - position.x, target.y - position.y)
        let duration = TimeInterval(distance / speed)

        clearSpriteAnimations()

        let isFlipped = (dir == "east" || dir == "north-east" || dir == "south-east")
        let texDir = mirrorDirection(dir)
        setSpriteDirection(texDir, flipX: isFlipped)
        startWalkAnimation(direction: dir, speed: 8.0)

        let move = SKAction.move(to: target, duration: max(duration, 0.3))
        move.timingMode = .easeInEaseOut

        let capturedTexDir = texDir
        let capturedFlipped = isFlipped
        let done = SKAction.run { [weak self] in
            self?.sprite.removeAllActions()
            self?.sprite.position = .zero
            self?.setSpriteDirection(capturedTexDir, flipX: capturedFlipped)
            completion?()
        }

        run(SKAction.sequence([move, done]), withKey: "wander")
    }

    // MARK: - Sprite Animations

    private func playIdleAnimation() {
        // DON'T call clearSpriteAnimations here -- it resets to south.
        // Just add the idle animation. The sprite keeps its current direction texture.
        sprite.removeAction(forKey: "idle")
        sprite.removeAction(forKey: "walkAnim")
        sprite.removeAction(forKey: "walkBob")
        sprite.position = .zero
        sprite.zRotation = 0

        // Try idle frames for current direction -- but we only have south/south-west/north-west
        // Use subtle position bob as universal idle (works with any direction texture)
        let breathe = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 0.6, duration: 2.5),
            SKAction.moveBy(x: 0, y: -0.6, duration: 2.5),
        ])
        sprite.run(SKAction.repeatForever(breathe), withKey: "idle")
    }

    private func startWalkAnimation(direction: String, speed: TimeInterval) {
        // Try exact direction first, then mirrored direction for east-ish
        var walkFrames = assets.huskyWalkFrames(direction: direction)
        if walkFrames.isEmpty {
            // Try mirrored: east -> west, north-east -> north-west, south-east -> south-west
            let mirrored: [String: String] = [
                "east": "west", "north-east": "north-west", "south-east": "south-west"
            ]
            if let mirror = mirrored[direction] {
                walkFrames = assets.huskyWalkFrames(direction: mirror)
            }
        }

        if !walkFrames.isEmpty {
            let animate = SKAction.animate(with: walkFrames, timePerFrame: 1.0 / speed)
            sprite.run(SKAction.repeatForever(animate), withKey: "walkAnim")
        } else {
            // Fallback: hop (no frames for this direction at all)
            let bob = SKAction.sequence([
                SKAction.moveBy(x: 0, y: 2.0, duration: 0.12),
                SKAction.moveBy(x: 0, y: -2.0, duration: 0.12),
            ])
            sprite.run(SKAction.repeatForever(bob), withKey: "walkBob")
        }
    }

    private func playSleepAnimation() {
        clearSpriteAnimations()
        // Don't call setSpriteDirection here -- it would reset to standing texture.
        // The sleep frames handle the transition from standing to curled.
        // Also: don't flip. Keep xScale positive so the curled pose stays consistent.
        sprite.xScale = huskyScale
        sprite.yScale = huskyScale

        let frames = assets.huskySleepingFrames()
        if !frames.isEmpty {
            // Play full transition once (stand -> curl down)
            let transition = SKAction.animate(with: frames, timePerFrame: 1.0 / 4.0)

            // Then loop the last 4 frames (breathing while curled) forever
            let breathFrames = Array(frames.suffix(4))
            let breathLoop = SKAction.repeatForever(
                SKAction.animate(with: breathFrames, timePerFrame: 1.0 / 2.0)
            )

            sprite.run(SKAction.sequence([transition, breathLoop]), withKey: "idle")
        } else {
            let breathe = SKAction.sequence([
                SKAction.moveBy(x: 0, y: 0.3, duration: 3.0),
                SKAction.moveBy(x: 0, y: -0.3, duration: 3.0),
            ])
            sprite.run(SKAction.repeatForever(breathe), withKey: "idle")
        }
    }

    private func playBarkAnimation(completion: @escaping () -> Void) {
        let barkFrames = assets.huskyBarkFrames()
        if !barkFrames.isEmpty {
            let animate = SKAction.animate(with: barkFrames, timePerFrame: 1.0 / 8.0)
            sprite.run(SKAction.sequence([animate, animate, SKAction.run(completion)]))
        } else {
            let shake = SKAction.sequence([
                SKAction.moveBy(x: 2, y: 0, duration: 0.06),
                SKAction.moveBy(x: -4, y: 0, duration: 0.06),
                SKAction.moveBy(x: 4, y: 0, duration: 0.06),
                SKAction.moveBy(x: -2, y: 0, duration: 0.06),
                SKAction.run(completion),
            ])
            sprite.run(shake)
        }
    }

    private func playDrinkAnimation(completion: @escaping () -> Void) {
        let frames = assets.huskyDrinkingFrames()
        if !frames.isEmpty {
            let animate = SKAction.animate(with: frames, timePerFrame: 1.0 / 6.0)
            let drinkLoop = SKAction.repeat(animate, count: 3)
            sprite.run(SKAction.sequence([drinkLoop, SKAction.run(completion)]))
        } else {
            // Fallback: bob down/up (drinking motion)
            let drink = SKAction.sequence([
                SKAction.moveBy(x: 0, y: -3, duration: 0.3),
                SKAction.wait(forDuration: 0.5),
                SKAction.moveBy(x: 0, y: 3, duration: 0.3),
                SKAction.wait(forDuration: 0.2),
                SKAction.moveBy(x: 0, y: -3, duration: 0.3),
                SKAction.wait(forDuration: 0.5),
                SKAction.moveBy(x: 0, y: 3, duration: 0.3),
                SKAction.run(completion),
            ])
            sprite.run(drink)
        }
    }

    private func playHeadTiltAnimation(completion: @escaping () -> Void) {
        let tilt = SKAction.sequence([
            SKAction.rotate(toAngle: 0.15, duration: 0.3),
            SKAction.wait(forDuration: 1.0),
            SKAction.rotate(toAngle: -0.1, duration: 0.2),
            SKAction.wait(forDuration: 0.5),
            SKAction.rotate(toAngle: 0, duration: 0.2),
            SKAction.run(completion),
        ])
        sprite.run(tilt)
    }

    private func clearSpriteAnimations() {
        sprite.removeAllActions()
        sprite.position = .zero
        sprite.zRotation = 0
        // Force-reset to the base standing texture.
        // This guarantees no stale animation frame persists.
        if let tex = baseTexture {
            sprite.texture = tex
            sprite.texture?.filteringMode = .nearest
        }
        sprite.xScale = huskyScale
        sprite.yScale = huskyScale
    }

    // MARK: - Sprite Direction

    /// Set sprite texture and flip. ONLY place sprite scale is set.
    private func setSpriteDirection(_ direction: String, flipX: Bool) {
        guard hasRealSprites else { return }
        if let tex = assets.huskyTexture(direction: direction) {
            sprite.texture = tex
            sprite.texture?.filteringMode = .nearest
        }
        sprite.xScale = flipX ? -huskyScale : huskyScale
        sprite.yScale = huskyScale
    }

    private func dominantDirection(toward target: CGPoint) -> String {
        let dx = target.x - position.x
        let dy = target.y - position.y
        if abs(dx) > abs(dy) {
            return dx > 0 ? "east" : "west"
        } else {
            return dy > 0 ? "north" : "south"
        }
    }
}
