import Foundation

struct Achievement: Identifiable, Codable {
    let id: UUID
    let section: Int
    let sortOrder: Int
    let symbol: String
    let title: [String: String]
    let description: [String: String]

    enum CodingKeys: String, CodingKey {
        case id
        case section
        case sortOrder = "sort_order"
        case symbol
        case title
        case description
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let idStr = try c.decode(String.self, forKey: .id)
        id = UUID(uuidString: idStr) ?? UUID()
        section = try c.decode(Int.self, forKey: .section)
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol) ?? "star.fill"
        title = try c.decode([String: String].self, forKey: .title)
        description = try c.decode([String: String].self, forKey: .description)
    }

    func title(for language: String) -> String {
        let lang = language.isEmpty ? "en" : language
        return title[lang] ?? title["ru"] ?? title["en"] ?? title.values.first ?? ""
    }

    func description(for language: String) -> String {
        let lang = language.isEmpty ? "en" : language
        return description[lang] ?? description["ru"] ?? description["en"] ?? description.values.first ?? ""
    }
}

struct AchievementsCatalog: Codable {
    let achievements: [Achievement]
}
