import SwiftUI

/// Curated SF Symbols for custom activity types, organized by category.
enum ActivitySymbolOptions {
    static let all: [(category: String, symbols: [String])] = [
        ("Fitness & Movement", [
            "figure.walk", "figure.run", "figure.yoga", "figure.wave",
            "figure.mind.and.body", "bicycle", "sportscourt.fill",
            "figure.strengthtraining.traditional", "figure.cooldown",
            "figure.outdoor.cycle", "figure.swim", "figure.skiing.downhill"
        ]),
        ("Mind & Wellness", [
            "brain.head.profile", "brain", "leaf.fill", "leaf",
            "heart.fill", "heart", "lungs.fill", "face.smiling.fill",
            "sparkles", "moon.stars.fill", "medal.fill"
        ]),
        ("Work & Study", [
            "briefcase.fill", "laptopcomputer", "desktopcomputer",
            "book.fill", "book.closed.fill", "graduationcap.fill",
            "pencil.and.outline", "doc.text.fill", "lightbulb.fill",
            "hammer.fill", "wrench.and.screwdriver.fill", "scissors"
        ]),
        ("Creative & Arts", [
            "paintbrush.fill", "paintpalette.fill", "music.note",
            "guitars.fill", "pianokeys", "theatermasks.fill",
            "camera.fill", "photo.fill", "camera.macro",
            "paintbrush.pointed.fill", "pencil.and.ruler.fill"
        ]),
        ("Home & Daily", [
            "frying.pan.fill", "house.fill", "cup.and.saucer.fill",
            "bed.double.fill", "washer.fill", "refrigerator.fill",
            "basket.fill", "carrot.fill", "fork.knife.fill"
        ]),
        ("Nature & Outdoors", [
            "sun.max.fill", "moon.stars.fill", "cloud.sun.fill",
            "tree.fill", "mountain.2.fill", "bird.fill",
            "pawprint.fill", "fish.fill", "ladybug.fill"
        ]),
        ("Social & People", [
            "person.2.fill", "person.3.fill", "person.crop.circle.fill",
            "bubble.left.and.bubble.right.fill", "person.2.crop.circle.stack.fill",
            "phone.fill", "envelope.fill", "message.fill"
        ]),
        ("Other", [
            "star.fill", "sparkles", "flame.fill", "drop.fill",
            "gift.fill", "cart.fill", "airplane", "car.fill",
            "tram.fill", "bus.fill", "ferry.fill", "globe.americas.fill"
        ])
    ]

    static var flatList: [String] {
        all.flatMap { $0.symbols }
    }

    /// Returns categories with the given symbol included if it's not already in the list.
    static func allIncluding(_ symbol: String) -> [(category: String, symbols: [String])] {
        let flat = flatList
        guard !flat.contains(symbol) else { return all }
        var result = all
        if let first = result.first {
            result[0] = (first.category, [symbol] + first.symbols)
        }
        return result
    }
}
