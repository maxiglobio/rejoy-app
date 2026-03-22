import Foundation
import SwiftData

@Model
final class Intention {
    var id: UUID
    var name: String
    var emoji: String
    var note: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, emoji: String = "✨", note: String = "", createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.note = note
        self.createdAt = createdAt
    }

    var displayTitle: String {
        "\(emoji) \(name)"
    }
}
