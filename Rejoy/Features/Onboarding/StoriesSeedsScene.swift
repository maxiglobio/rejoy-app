import SpriteKit
import SwiftUI

/// Demo gravity scene for Stories onboarding slide 2: 65 white dots falling and settling.
final class StoriesSeedsScene: SKScene {
    private let seedsContainer = SKNode()
    private let dotCount = 65
    private let seedRadius: CGFloat = 5
    private let inset: CGFloat = 16
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
        physicsWorld.gravity = CGVector(dx: 0, dy: -12)

        if seedsContainer.parent == nil {
            addChild(seedsContainer)
        }
        setupBoundary()
        spawnDots()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        if hasSpawned {
            // Recreate dots when size changes (e.g. orientation)
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
        let path = CGPath(roundedRect: rect, cornerWidth: 20, cornerHeight: 20, transform: nil)
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

        let spawnY = size.height - inset - seedRadius * 2
        let spawnWidth = size.width - inset * 2 - seedRadius * 4

        // Stagger spawn slightly for a more natural rain effect
        for i in 0..<dotCount {
            let seed = makeDotNode()
            seed.position = CGPoint(
                x: size.width / 2 + CGFloat.random(in: -spawnWidth / 2...spawnWidth / 2),
                y: spawnY + CGFloat(i % 5) * 2  // Small vertical spread
            )
            seedsContainer.addChild(seed)
        }
    }

    private func makeDotNode() -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: seedRadius)
        node.fillColor = .white
        node.strokeColor = UIColor.white.withAlphaComponent(0.5)
        node.lineWidth = 0.5

        node.physicsBody = SKPhysicsBody(circleOfRadius: seedRadius)
        node.physicsBody?.restitution = 0.15
        node.physicsBody?.friction = 0.5
        node.physicsBody?.linearDamping = 0.4
        node.physicsBody?.allowsRotation = false
        node.physicsBody?.mass = 0.08

        return node
    }
}
