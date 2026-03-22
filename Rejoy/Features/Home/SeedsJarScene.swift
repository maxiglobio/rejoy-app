import SpriteKit
import SwiftUI
import UIKit

final class SeedsJarScene: SKScene {
    private let seedsContainer = SKNode()
    private let maxVisibleSeeds = 300
    private let dotsPerHour = 24
    private let maxMinutes = 24 * 60     // 24h max
    private let seedRadius: CGFloat = 4
    private let inset: CGFloat = 12

    private var currentParticleCount: Int = 0

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
        // Match WelcomeParticlesScene baseline; tilt overwrites via updateGravity.
        physicsWorld.gravity = CGVector(dx: 0, dy: -5)

        if seedsContainer.parent == nil {
            addChild(seedsContainer)
        }
        setupBoundary()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        setupBoundary()
    }

    private func setupBoundary() {
        childNode(withName: "boundary")?.removeFromParent()
        let rect = CGRect(
            x: inset,
            y: inset,
            width: max(1, size.width - inset * 2),
            height: max(1, size.height - inset * 2)
        )
        let path = CGPath(roundedRect: rect, cornerWidth: 24, cornerHeight: 24, transform: nil)
        let boundary = SKNode()
        boundary.name = "boundary"
        boundary.physicsBody = SKPhysicsBody(edgeLoopFrom: path)
        boundary.physicsBody?.isDynamic = false
        boundary.physicsBody?.friction = 0.3
        addChild(boundary)
    }

    /// Add particles: 1h = 24 dots, max 24h.
    func addSeeds(durationMinutes: Int) {
        let cappedMinutes = min(durationMinutes, maxMinutes)
        let targetParticles = min(maxVisibleSeeds, cappedMinutes * dotsPerHour / 60)
        let particlesToAdd = min(max(1, targetParticles), maxVisibleSeeds - currentParticleCount)
        guard particlesToAdd > 0 else { return }

        let spawnY = size.height - inset - seedRadius * 2
        let spawnWidth = size.width - inset * 2 - seedRadius * 4

        for _ in 0..<particlesToAdd {
            let seed = makeSeedNode()
            seed.position = CGPoint(
                x: size.width / 2 + CGFloat.random(in: -spawnWidth / 2...spawnWidth / 2),
                y: spawnY
            )
            seedsContainer.addChild(seed)
            currentParticleCount += 1
        }
    }

    /// Same body tuning as WelcomeParticlesScene.makeDotNode() for consistent feel.
    private func makeSeedNode() -> SKShapeNode {
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

    func triggerChaoticJump() {
        seedsContainer.children.forEach { node in
            guard let body = node.physicsBody else { return }
            let impulse = CGVector(
                dx: CGFloat.random(in: -50...50),
                dy: CGFloat.random(in: 30...80)
            )
            body.applyImpulse(impulse)
        }
    }

    /// Turn N circles green, where N = durationMinutes * 24 / 60 (same formula as addSeeds).
    func turnGreen(durationMinutes: Int) {
        guard durationMinutes > 0 else { return }
        let cappedMinutes = min(durationMinutes, maxMinutes)
        let count = min(maxVisibleSeeds, max(1, cappedMinutes * dotsPerHour / 60))

        var turned = 0
        for node in seedsContainer.children {
            guard turned < count, let shape = node as? SKShapeNode, shape.name != "green" else { continue }
            shape.fillColor = .systemGreen
            shape.strokeColor = UIColor.systemGreen.withAlphaComponent(0.6)
            shape.name = "green"
            turned += 1
        }
    }

    /// Turn circles green proportionally when jar is capped. sessionMinutes/totalMinutes * particleCount.
    func turnGreenProportional(sessionMinutes: Int, totalMinutes: Int) {
        guard sessionMinutes > 0, totalMinutes > 0 else { return }
        let particleCount = seedsContainer.children.count
        guard particleCount > 0 else { return }
        let cappedSession = min(sessionMinutes, maxMinutes)
        let cappedTotal = min(totalMinutes, maxMinutes)
        let count = max(0, min(particleCount, Int(round(Double(cappedSession) / Double(cappedTotal) * Double(particleCount)))))
        guard count > 0 else { return }
        var turned = 0
        for node in seedsContainer.children {
            guard turned < count, let shape = node as? SKShapeNode, shape.name != "green" else { continue }
            shape.fillColor = .systemGreen
            shape.strokeColor = UIColor.systemGreen.withAlphaComponent(0.6)
            shape.name = "green"
            turned += 1
        }
    }

    /// Fill jar: 1h = 24 dots, max 24h.
    func resetSeeds(forTotalMinutes totalMinutes: Int) {
        seedsContainer.removeAllChildren()
        currentParticleCount = 0

        guard size.width > 0, size.height > 0 else { return }

        let cappedMinutes = min(totalMinutes, maxMinutes)
        let particleCount = max(0, min(maxVisibleSeeds, cappedMinutes * dotsPerHour / 60))
        guard particleCount > 0 else { return }

        let rect = CGRect(
            x: inset + seedRadius * 2,
            y: inset + seedRadius * 2,
            width: size.width - inset * 2 - seedRadius * 4,
            height: size.height - inset * 2 - seedRadius * 4
        )

        for _ in 0..<particleCount {
            let seed = makeSeedNode()
            seed.position = CGPoint(
                x: rect.midX + CGFloat.random(in: -rect.width / 2...rect.width / 2),
                y: rect.minY + CGFloat.random(in: 0...min(rect.height, CGFloat(particleCount) * seedRadius * 3))
            )
            seedsContainer.addChild(seed)
            currentParticleCount += 1
        }
    }
}
