import Foundation
import Combine

/// When the Profile tab shows the Altar segment, hide tab bar, floating start button, and active-tracking overlay for a focused altar experience.
@MainActor
final class AltarFocusController: ObservableObject {
    static let shared = AltarFocusController()

    @Published private(set) var isAltarFocused: Bool = false

    private init() {}

    func setAltarFocused(_ focused: Bool) {
        guard isAltarFocused != focused else { return }
        isAltarFocused = focused
    }
}
