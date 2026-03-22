import SwiftUI
import UIKit

struct SeedsInfoCarouselSheet: View {
    @Environment(\.appLanguage) private var appLanguage
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    private let seedsPerSecond = AppSettings.seedsPerSecond
    private var seedsPerMinute: Int { seedsPerSecond * 60 }
    private var seedsPerHour: Int { seedsPerSecond * 3600 }
    private var seedsPerDay: Int { seedsPerSecond * 86400 }

    private let slides: [(symbol: String, titleKey: String, descKey: String)] = [
        ("leaf.fill", "seeds_info_slide_1_title", "seeds_info_slide_1_desc"),
        ("clock.fill", "seeds_info_slide_2_title", "seeds_info_slide_2_desc"),
        ("chart.line.uptrend.xyaxis", "seeds_info_slide_3_title", "seeds_info_slide_3_desc"),
        ("eye.fill", "seeds_info_slide_4_title", "seeds_info_slide_4_desc"),
        ("drop.fill", "seeds_info_slide_5_title", "seeds_info_slide_5_desc"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(0..<slides.count, id: \.self) { index in
                        slideContent(for: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(minHeight: 320)
                .onChange(of: currentPage) { _, _ in
                    UISelectionFeedbackGenerator().selectionChanged()
                }

                paginationDots
                    .padding(.top, 24)
                    .padding(.bottom, 16)
            }
            .navigationTitle(L.string("what_is_seeds", language: appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.string("done", language: appLanguage)) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }
                }
            }
        }
    }

    private func slideContent(for index: Int) -> some View {
        let slide = slides[index]
        let desc = formattedDescription(for: index)
        return VStack(spacing: 24) {
            Image(systemName: slide.symbol)
                .font(AppFont.rounded(size: 64))
                .foregroundStyle(AppColors.rejoyOrange)

            Text(L.string(slide.titleKey, language: appLanguage))
                .font(AppFont.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text(desc)
                .font(AppFont.body)
                .foregroundStyle(AppColors.dotsSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 32)
    }

    private func formattedDescription(for index: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSize = 3
        switch appLanguage {
        case "ru", "uk":
            formatter.groupingSeparator = "."
        default:
            formatter.groupingSeparator = ","
        }
        let s = formatter.string(from: NSNumber(value: seedsPerSecond)) ?? "\(seedsPerSecond)"
        let m = formatter.string(from: NSNumber(value: seedsPerMinute)) ?? "\(seedsPerMinute)"
        let h = formatter.string(from: NSNumber(value: seedsPerHour)) ?? "\(seedsPerHour)"
        let d = formatter.string(from: NSNumber(value: seedsPerDay)) ?? "\(seedsPerDay)"
        let base = L.string(slides[index].descKey, language: appLanguage)
        switch index {
        case 1: return String(format: base, s)
        case 2: return String(format: base, m, h, d)
        default: return base
        }
    }

    private var paginationDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<slides.count, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? AppColors.rejoyOrange : AppColors.rejoyOrange.opacity(0.3))
                    .frame(width: index == currentPage ? 10 : 8, height: index == currentPage ? 10 : 8)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
    }
}
