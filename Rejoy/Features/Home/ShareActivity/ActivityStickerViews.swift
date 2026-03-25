import SwiftUI
import SwiftData

// MARK: - Shared Sticker Data

struct StickerData {
    let activityName: String
    let activityNameRaw: String
    let durationText: String
    let seedsText: String
    let symbolName: String
    let isRejoyed: Bool
    let avatarImage: UIImage?

    static func from(session: Session, activity: ActivityType?, isRejoyed: Bool, language: String, avatarImage: UIImage?) -> StickerData {
        let name = activity.map { L.activityName($0.name, language: language) } ?? L.string("activity", language: language)
        let nameRaw = activity?.name ?? "Study"
        let duration = L.formattedTimelineMinutes(session.durationSeconds, language: language)
        let seedsFormatted = formatSeeds(session.seeds, language: language)
        let seedsText = String(format: L.string("seeds_count_formatted", language: language), seedsFormatted)
        return StickerData(
            activityName: name,
            activityNameRaw: nameRaw,
            durationText: duration,
            seedsText: seedsText,
            symbolName: activity?.symbolName ?? "circle",
            isRejoyed: isRejoyed,
            avatarImage: avatarImage
        )
    }

    private static func formatSeeds(_ seeds: Int, language: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSize = 3
        switch language {
        case "ru":
            formatter.groupingSeparator = "."
            formatter.locale = Locale(identifier: "ru_RU")
        case "uk":
            formatter.groupingSeparator = "."
            formatter.locale = Locale(identifier: "uk_UA")
        default:
            formatter.groupingSeparator = ","
            formatter.locale = Locale(identifier: "en_US")
        }
        return formatter.string(from: NSNumber(value: seeds)) ?? "\(seeds)"
    }
}

// MARK: - Watermark

private struct StickerWatermark: View {
    var body: some View {
        Image("Watermark")
            .resizable()
            .renderingMode(.template)
            .foregroundStyle(.white)
            .frame(width: 69, height: 23)
    }
}

// MARK: - Design Tokens (from Figma #fe7302, #e3e3ea, #f2f2f6)

private let stickerOrange = AppColors.rejoyOrange
private let stickerPillGray = Color(red: 0.89, green: 0.89, blue: 0.92) // #e3e3ea
private let stickerBg = Color(red: 0.95, green: 0.95, blue: 0.96) // #f2f2f6

// MARK: - V1: Horizontal, transparent bg, orange border, white text, circular checkmark (Figma 40022735:54889 / 40022741:5336)

struct StickerV1View: View {
    let data: StickerData
    let language: String

    var body: some View {
        VStack(spacing: 11) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: data.symbolName)
                    .font(.system(size: 30, weight: .regular, design: .rounded))
                    .foregroundStyle(stickerOrange)
                VStack(alignment: .leading, spacing: 6) {
                    if data.isRejoyed {
                        HStack(spacing: 4) {
                            Text(data.activityName)
                            Text(L.string("rejoyed_exclamation", language: language))
                        }
                        .font(AppFont.rounded(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                    } else {
                        Text(data.activityName)
                            .font(AppFont.rounded(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                    }
                    HStack(spacing: 6) {
                        Text(data.durationText)
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                        Text(data.seedsText)
                    }
                    .font(AppFont.rounded(size: 16, weight: .regular))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
                .layoutPriority(1)
                Spacer(minLength: 8)
                if data.isRejoyed {
                    rejoyedCheckmarkCircle
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(width: 332)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(stickerOrange, lineWidth: 4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
            StickerWatermark()
        }
    }

    private var rejoyedCheckmarkCircle: some View {
        ZStack {
            Circle()
                .fill(Color.white)
            Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.black)
        }
        .frame(width: 42, height: 42)
    }
}

// MARK: - V2: Vertical centered, transparent bg, white text (Figma 40022741:5317)

struct StickerV2View: View {
    let data: StickerData
    let language: String

    var body: some View {
        VStack(spacing: 15) {
            VStack(spacing: 6) {
                Image(systemName: data.symbolName)
                    .font(.system(size: 38, weight: .regular, design: .rounded))
                    .foregroundStyle(stickerOrange)
                VStack(spacing: 6) {
                    Text(data.activityName)
                        .font(AppFont.rounded(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.15), radius: 0.5, x: 0, y: 0.5)
                    HStack(spacing: 4) {
                        Text(data.durationText)
                            .font(AppFont.rounded(size: 16, weight: .regular))
                        Text("•")
                        Text(data.seedsText)
                            .font(AppFont.rounded(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 0.5, x: 0, y: 0.5)
                }
                if data.isRejoyed {
                    rejoyedPillGray
                }
            }
            .padding(.vertical, 14)
            .frame(width: 310, height: 175)
            .background(Color.clear)
            StickerWatermark()
        }
    }

    private var rejoyedPillGray: some View {
        HStack(spacing: 6) {
            Text(L.string("rejoyed", language: language))
                .font(AppFont.rounded(size: 18, weight: .regular))
            Image(systemName: "checkmark")
                .font(AppFont.rounded(size: 18, weight: .regular))
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(stickerPillGray)
        .clipShape(Capsule())
    }
}

// MARK: - V3: Vertical, icon above card, gray bg, white border, orange pill (Figma 40022735:55065 / 40022741:5295)

struct StickerV3View: View {
    let data: StickerData
    let language: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: data.symbolName)
                .font(.system(size: 40, weight: .regular, design: .rounded))
                .foregroundStyle(stickerOrange)
                .frame(maxWidth: .infinity)
            VStack(spacing: 12) {
                VStack(spacing: 6) {
                    Text(data.activityName)
                        .font(AppFont.rounded(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                    HStack(spacing: 4) {
                        Text(data.durationText)
                            .font(AppFont.rounded(size: 16, weight: .regular))
                        Text("•")
                            .font(AppFont.rounded(size: 16, weight: .regular))
                        Text(data.seedsText)
                            .font(AppFont.rounded(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                }
                if data.isRejoyed {
                    rejoyedPillOrange
                }
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 16)
            .frame(width: 258)
            .background(stickerBg)
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(Color.white, lineWidth: 4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            StickerWatermark()
        }
        .frame(width: 258)
    }

    private var rejoyedPillOrange: some View {
        HStack(spacing: 6) {
            Text(L.string("rejoyed", language: language))
                .font(AppFont.rounded(size: 18, weight: .regular))
            Image(systemName: "checkmark")
                .font(AppFont.rounded(size: 18, weight: .regular))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(stickerOrange)
        .clipShape(Capsule())
    }
}

// MARK: - Buddha asset mapping

private func buddhaAssetName(for activityName: String) -> String {
    let key = activityName.lowercased()
    switch key {
    case "meditation": return "BuddhaMeditation"
    case "yoga": return "BuddhaYoga"
    case "walking": return "BuddhaWalking"
    case "running": return "BuddhaRunning"
    case "cooking": return "BuddhaCooking"
    case "family": return "BuddhaFamily"
    case "work", "reading", "study": return "BuddhaLearning"
    default: return "BuddhaLearning"
    }
}

// MARK: - V4: Buddha sticker, vertical centered, transparent bg (Figma 40023243:52722)

struct StickerV4View: View {
    let data: StickerData
    let language: String

    var body: some View {
        VStack(spacing: 6) {
            Image(buddhaAssetName(for: data.activityNameRaw))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 144, height: 130)
            VStack(spacing: 6) {
                Text(data.activityName)
                    .font(AppFont.rounded(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 0.5, x: 0, y: 0.5)
                HStack(spacing: 4) {
                    Text(data.durationText)
                        .font(AppFont.rounded(size: 16, weight: .regular))
                    Text("•")
                    Text(data.seedsText)
                        .font(AppFont.rounded(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.15), radius: 0.5, x: 0, y: 0.5)
            }
            StickerWatermark()
        }
        .frame(width: 310, height: 215)
        .background(Color.clear)
    }
}

// MARK: - V5: ZEN sticker (Figma 40023263:52818)

struct StickerV5View: View {
    let data: StickerData
    let language: String

    var body: some View {
        VStack(spacing: 0) {
            zenGraphic
                .frame(width: 380, height: 206)
            VStack(spacing: 6) {
                Text(data.activityName)
                    .font(AppFont.rounded(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 0.5, x: 0, y: 0.5)
                HStack(spacing: 4) {
                    Text(data.durationText)
                        .font(AppFont.rounded(size: 12, weight: .regular))
                    Text("•")
                        .font(AppFont.rounded(size: 12, weight: .regular))
                    Text(data.seedsText)
                        .font(AppFont.rounded(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.15), radius: 0.5, x: 0, y: 0.5)
                StickerWatermark()
                    .padding(.top, 12)
            }
            .offset(y: -20)
        }
        .padding(.bottom, 52)
        .frame(width: 380, height: 330)
        .background(Color.clear)
    }

    private var zenGraphic: some View {
        Image("ZenGraphic")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 380, height: 206)
    }
}
