import SpriteKit
import SwiftUI
import UIKit

/// ~500 orange particles with gravity, full-screen boundary — for the login/welcome page.
final class WelcomeParticlesScene: SKScene {
    private let seedsContainer = SKNode()
    private let dotCount = 500
    private let seedRadius: CGFloat = 4
    private let inset: CGFloat = 0  // Full screen boundary
    private var hasSpawned = false

    override init(size: CGSize) {
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        view.allowsTransparency = true
        view.isOpaque = false
        scaleMode = .resizeFill
        physicsWorld.gravity = CGVector(dx: 0, dy: -5)

        if seedsContainer.parent == nil {
            addChild(seedsContainer)
        }
        setupBoundary()
        spawnDots()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        if hasSpawned {
            seedsContainer.removeAllChildren()
            hasSpawned = false
            setupBoundary()
            spawnDots()
        }
    }

    private func setupBoundary() {
        childNode(withName: "boundary")?.removeFromParent()
        let rect = CGRect(
            x: inset,
            y: inset,
            width: max(1, size.width - inset * 2),
            height: max(1, size.height - inset * 2)
        )
        let path = CGPath(rect: rect, transform: nil)
        let boundary = SKNode()
        boundary.name = "boundary"
        boundary.physicsBody = SKPhysicsBody(edgeLoopFrom: path)
        boundary.physicsBody?.isDynamic = false
        boundary.physicsBody?.friction = 0.3
        addChild(boundary)
    }

    private func spawnDots() {
        guard !hasSpawned, size.width > 0, size.height > 0 else { return }
        hasSpawned = true

        let spawnY = size.height - seedRadius * 2
        let spawnWidth = size.width - seedRadius * 4
        let batchSize = 10
        let spawnDuration: TimeInterval = 2.5
        let batches = (dotCount + batchSize - 1) / batchSize
        let interval = spawnDuration / Double(batches)

        for batch in 0..<batches {
            let delay = interval * Double(batch) + Double.random(in: 0...0.08)
            let wait = SKAction.wait(forDuration: delay)
            let spawn = SKAction.run { [weak self] in
                guard let self = self else { return }
                let styles: [UIImpactFeedbackGenerator.FeedbackStyle] = [.light, .soft, .medium, .rigid, .heavy]
                let style = styles.randomElement() ?? .light
                UIImpactFeedbackGenerator(style: style).impactOccurred()
                let count = min(batchSize, self.dotCount - batch * batchSize)
                for _ in 0..<count {
                    let seed = self.makeDotNode()
                    seed.position = CGPoint(
                        x: self.size.width / 2 + CGFloat.random(in: -spawnWidth / 2...spawnWidth / 2),
                        y: spawnY + CGFloat.random(in: -30...30)
                    )
                    self.seedsContainer.addChild(seed)
                }
            }
            run(SKAction.sequence([wait, spawn]))
        }
    }

    private func makeDotNode() -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: seedRadius)
        node.fillColor = AppColors.rejoyOrangeUIColor
        node.strokeColor = AppColors.rejoyOrangeUIColor.withAlphaComponent(0.5)
        node.lineWidth = 0.5

        node.physicsBody = SKPhysicsBody(circleOfRadius: seedRadius)
        node.physicsBody?.restitution = 0.15
        node.physicsBody?.friction = 0.5
        node.physicsBody?.linearDamping = 0.4
        node.physicsBody?.allowsRotation = false
        node.physicsBody?.mass = 0.08

        return node
    }

    func updateGravity(x: CGFloat, y: CGFloat) {
        physicsWorld.gravity = CGVector(dx: x, dy: y)
    }
}
