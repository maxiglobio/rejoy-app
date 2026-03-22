import SwiftUI
import UIKit

/// Shared state for profile avatar, used by ProfileView and MainTabView., used by ProfileView and MainTabView.
@MainActor
final class ProfileState: ObservableObject {
    static let shared = ProfileState()

    private static let avatarDataKey = "profileAvatarData"
    private static let displayNameKey = "profileDisplayName"

    @Published var avatarImage: UIImage?

    private init() {
        loadAvatar()
    }

    func loadAvatar() {
        if let data = UserDefaults.standard.data(forKey: Self.avatarDataKey),
           let image = UIImage(data: data) {
            avatarImage = image
        } else {
            avatarImage = nil
        }
    }

    func saveAvatar(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        UserDefaults.standard.set(data, forKey: Self.avatarDataKey)
        avatarImage = image
    }

    func clearAvatar() {
        UserDefaults.standard.removeObject(forKey: Self.avatarDataKey)
        avatarImage = nil
    }

    static var displayName: String? {
        get { UserDefaults.standard.string(forKey: displayNameKey) }
        set { UserDefaults.standard.set(newValue, forKey: displayNameKey) }
    }

    /// Initials for placeholder (e.g. "JD" from "John Doe" or "J" from "john@email.com")
    static func initials() -> String {
        if let name = displayName, !name.isEmpty {
            let parts = name.split(separator: " ").compactMap { $0.first }
            if parts.count >= 2 {
                return String(parts.prefix(2)).uppercased()
            }
            if let first = parts.first {
                return String(first).uppercased()
            }
        }
        return "?"
    }
}
