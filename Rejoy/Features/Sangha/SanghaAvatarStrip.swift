import SwiftUI

/// Horizontal avatar strip for Sangha members. Shows above heroCard on Home.
/// Dots Platform style: two-layer ring (colored outer + white inner), orange for active now, gray for normal.
struct SanghaAvatarStrip: View {
    let members: [SanghaMemberRow]
    var profilesByUserId: [UUID: ProfileRow] = [:]
    let activeUserIds: Set<UUID>
    let todaySeedsByUserId: [UUID: Int]
    var viewedMemberIds: Set<UUID> = []
    let currentUserId: UUID?
    @Binding var selectedMemberId: UUID?
    var onMemberTapped: ((UUID) -> Void)?
    @Environment(\.appLanguage) private var appLanguage
    @StateObject private var profileState = ProfileState.shared

    /// Sorted: Active (pulsating) → Unseen → Seen
    private var sortedMembers: [SanghaMemberRow] {
        members.sorted { a, b in
            let aActive = activeUserIds.contains(a.userId)
            let bActive = activeUserIds.contains(b.userId)
            if aActive != bActive { return aActive }
            let aSeeds = todaySeedsByUserId[a.userId] ?? 0
            let bSeeds = todaySeedsByUserId[b.userId] ?? 0
            let aUnseen = aSeeds > 0 && !viewedMemberIds.contains(a.userId)
            let bUnseen = bSeeds > 0 && !viewedMemberIds.contains(b.userId)
            if aUnseen != bUnseen { return aUnseen }
            return false
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(sortedMembers, id: \.userId) { member in
                    let hasActivityToday = (todaySeedsByUserId[member.userId] ?? 0) > 0
                    let hasUnseenActivity = hasActivityToday && !viewedMemberIds.contains(member.userId)
                    SanghaAvatarButton(
                        member: member,
                        profile: profilesByUserId[member.userId],
                        isActiveNow: activeUserIds.contains(member.userId),
                        hasUnseenActivity: hasUnseenActivity,
                        hasActivityToday: hasActivityToday,
                        isCurrentUser: member.userId == currentUserId,
                        profileState: member.userId == currentUserId ? profileState : nil
                    ) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onMemberTapped?(member.userId)
                        selectedMemberId = member.userId
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .scrollClipDisabled()
    }
}

private struct SanghaAvatarButton: View {
    let member: SanghaMemberRow
    let profile: ProfileRow?
    let isActiveNow: Bool
    let hasUnseenActivity: Bool
    let hasActivityToday: Bool
    let isCurrentUser: Bool
    let profileState: ProfileState?
    let onTap: () -> Void

    private let size: CGFloat = 74
    private let innerSize: CGFloat = 67  // 6.25% inset for rings
    private let outerRingWidth: CGFloat = 2.5
    private let innerRingWidth: CGFloat = 1
    @State private var activeRingScale: CGFloat = 1

    /// Orange when live (active now) or has unseen activity today.
    private var showOrangeRing: Bool {
        isActiveNow || hasUnseenActivity
    }

    private var outerRingColor: Color {
        showOrangeRing ? AppColors.rejoyOrange : Color(.systemGray3)
    }

    private var animatedRingWidth: CGFloat {
        isActiveNow ? outerRingWidth * activeRingScale : outerRingWidth
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .stroke(outerRingColor, lineWidth: animatedRingWidth)
                    .frame(width: size, height: size)
                Circle()
                    .stroke(Color.white, lineWidth: innerRingWidth)
                    .frame(width: innerSize, height: innerSize)
                avatarContent
            }
        }
        .buttonStyle(.plain)
        .onChange(of: isActiveNow) { _, active in
            guard active else {
                activeRingScale = 1
                return
            }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                activeRingScale = 2.2
            }
        }
        .onAppear {
            if isActiveNow {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    activeRingScale = 2.2
                }
            }
        }
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let ps = profileState, let image = ps.avatarImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: innerSize, height: innerSize)
                .clipShape(Circle())
        } else if let urlString = profile?.avatarUrl, let url = URL(string: urlString) {
            CachedAvatarImage(url: url, size: innerSize) {
                ShimmerAvatarSkeleton(size: size)
            }
        } else {
            placeholderCircle
        }
    }

    private var placeholderCircle: some View {
        ZStack {
            Circle()
                .fill(hasActivityToday ? AppColors.secondaryFill.opacity(0.92) : AppColors.secondaryFill.opacity(0.75))
                .frame(width: innerSize, height: innerSize)
            Text(memberInitials)
                .font(AppFont.rounded(size: innerSize * 0.4, weight: .semibold))
                .foregroundStyle(hasActivityToday ? AppColors.sectionHeader : AppColors.trailing)
        }
    }

    private var memberInitials: String {
        if isCurrentUser, let name = ProfileState.displayName, !name.isEmpty {
            return initials(from: name)
        }
        if let name = profile?.displayName, !name.isEmpty {
            return initials(from: name)
        }
        return "?"
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ").compactMap { $0.first }
        if parts.count >= 2 { return String(parts.prefix(2)).uppercased() }
        if let first = parts.first { return String(first).uppercased() }
        return "?"
    }
}
