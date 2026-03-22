import Foundation

/// Reusable model for onboarding stories.
struct StoryItem: Identifiable {
    let id: Int
    let imageName: String
    let videoName: String?
    let titleKey: String
    let subtitleKey: String

    static let all: [StoryItem] = [
        StoryItem(id: 0, imageName: "ExplainerSlide1", videoName: nil, titleKey: "how_to_use_slide_1_title", subtitleKey: "how_to_use_slide_1_desc"),
        StoryItem(id: 1, imageName: "ExplainerSlide2", videoName: "slide2", titleKey: "how_to_use_slide_2_title", subtitleKey: "how_to_use_slide_2_desc"),
        StoryItem(id: 2, imageName: "ExplainerSlide3", videoName: "slide3", titleKey: "how_to_use_slide_3_title", subtitleKey: "how_to_use_slide_3_desc"),
        StoryItem(id: 3, imageName: "ExplainerSlide4", videoName: nil, titleKey: "how_to_use_slide_4_title", subtitleKey: "how_to_use_slide_4_desc"),
        StoryItem(id: 4, imageName: "ExplainerSlide5", videoName: "slide5", titleKey: "how_to_use_slide_5_title", subtitleKey: "how_to_use_slide_5_desc"),
        StoryItem(id: 5, imageName: "ExplainerSlide6", videoName: nil, titleKey: "how_to_use_slide_6_title", subtitleKey: "how_to_use_slide_6_desc"),
        StoryItem(id: 6, imageName: "ExplainerSlide7", videoName: nil, titleKey: "how_to_use_slide_7_title", subtitleKey: "how_to_use_slide_7_desc"),
        StoryItem(id: 7, imageName: "ExplainerSlide8", videoName: nil, titleKey: "how_to_use_slide_8_title", subtitleKey: "how_to_use_slide_8_desc"),
        StoryItem(id: 8, imageName: "ExplainerSlide9", videoName: nil, titleKey: "how_to_use_slide_9_title", subtitleKey: "how_to_use_slide_9_desc"),
    ]
}
