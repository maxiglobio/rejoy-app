import Foundation
import CoreMotion

@MainActor
final class AccelerometerService: ObservableObject {
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()

    struct Gravity {
        var x: CGFloat
        var y: CGFloat
    }

    @Published private(set) var gravity: Gravity = Gravity(x: 0, y: -3.5)
    @Published private(set) var isAvailable: Bool = false

    private let gravityScale: CGFloat = 14
    private let lowPassAlpha: CGFloat = 0.28

    private var filteredX: CGFloat = 0
    private var filteredY: CGFloat = -3.5

    init() {
        isAvailable = motionManager.isDeviceMotionAvailable
        queue.qualityOfService = .userInteractive
    }

    func startUpdates() {
        guard isAvailable else { return }
        guard !motionManager.isDeviceMotionActive else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let attitude = motion.gravity

            DispatchQueue.main.async {
                let rawX = CGFloat(attitude.x) * self.gravityScale
                let rawY = CGFloat(attitude.y) * self.gravityScale

                self.filteredX = self.lowPassAlpha * rawX + (1 - self.lowPassAlpha) * self.filteredX
                self.filteredY = self.lowPassAlpha * rawY + (1 - self.lowPassAlpha) * self.filteredY

                self.gravity = Gravity(x: self.filteredX, y: self.filteredY)
            }
        }
    }

    func stopUpdates() {
        guard motionManager.isDeviceMotionActive else { return }
        motionManager.stopDeviceMotionUpdates()
        gravity = Gravity(x: 0, y: -3.5)
        filteredX = 0
        filteredY = -3.5
    }
}
