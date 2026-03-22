import SwiftUI
import SpriteKit
import UIKit

@MainActor
final class SeedsJarCoordinator: ObservableObject {
    let scene: SeedsJarScene

    init(scene: SeedsJarScene) {
        self.scene = scene
    }

    func addSeeds(durationMinutes: Int) {
        guard durationMinutes > 0 else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        scene.addSeeds(durationMinutes: durationMinutes)
    }

    func resetSeeds(forTotalMinutes totalMinutes: Int) {
        scene.resetSeeds(forTotalMinutes: totalMinutes)
    }

    func triggerChaoticJump() {
        scene.triggerChaoticJump()
    }

    func turnGreen(durationMinutes: Int) {
        scene.turnGreen(durationMinutes: durationMinutes)
    }

    func turnGreenProportional(sessionMinutes: Int, totalMinutes: Int) {
        scene.turnGreenProportional(sessionMinutes: sessionMinutes, totalMinutes: totalMinutes)
    }
}

struct SeedsJarView: View {
    @StateObject private var accelerometer = AccelerometerService()
    @ObservedObject var coordinator: SeedsJarCoordinator
    var backgroundColor: Color = AppColors.dotsGlassBg

    private let jarCornerRadius: CGFloat = 24

    var body: some View {
        particleJarContent
            .onAppear {
                accelerometer.startUpdates()
            }
            .onDisappear {
                accelerometer.stopUpdates()
            }
            .onReceive(accelerometer.$gravity) { newGravity in
                coordinator.scene.updateGravity(x: newGravity.x, y: newGravity.y)
            }
    }

    /// Inner particle area: particles behind glass for refraction; .clear = minimal blur, max refraction.
    private var particleJarContent: some View {
        ZStack {
            // Layer 1: Particle field + gradient background (gradient helps refraction show)
            SpriteView(scene: coordinator.scene, options: [.allowsTransparency])
                .background(backgroundColor)

            // Layer 2: Glass overlay — particles refract through it; .clear = least blur
            glassOverlay
        }
    }

    @ViewBuilder
    private var glassOverlay: some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .glassEffect(.clear, in: .rect(cornerRadius: jarCornerRadius))
        }
        // iOS 17: no glass overlay; particles show normally
    }
}
