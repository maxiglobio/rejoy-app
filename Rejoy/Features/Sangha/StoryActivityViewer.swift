import SwiftUI

/// Full-screen story-style activity viewer. Swipe or tap avatars to switch between members (Instagram-style).
struct StoryActivityViewer: View {
    let members: [SanghaMemberRow]
    var profilesByUserId: [UUID: ProfileRow] = [:]
    let initialMemberId: UUID
    let date: Date
    let activityTypes: [ActivityType]
    var onMemberViewed: ((UUID) -> Void)?
    let onDismiss: () -> Void
    @Environment(\.appLanguage) private var appLanguage
    @StateObject private var profileState = ProfileState.shared

    @State private var currentIndex: Int = 0
    @State private var hasHadUserSwitch = false
    @State private var reactionBurstId: Int = 0

    private var currentMember: SanghaMemberRow? {
        guard members.indices.contains(currentIndex) else { return nil }
        return members[currentIndex]
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(members.enumerated()), id: \.element.userId) { index, member in
                    StoryActivityCard(
                        member: member,
                        profile: profilesByUserId[member.userId],
                        date: date,
                        activityTypes: activityTypes,
                        isCurrentUser: member.userId == SupabaseService.shared.currentUserId,
                        profileState: member.userId == SupabaseService.shared.currentUserId ? profileState : nil,
                        onReactionBurst: { reactionBurstId += 1 }
                    )
                    .padding(.horizontal, 20)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.25), value: currentIndex)

            VStack(spacing: 0) {
                HStack {
                    Text(L.string("karma_partners", language: appLanguage))
                        .font(AppFont.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Spacer(minLength: 0)
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 4)

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(members.enumerated()), id: \.element.userId) { index, member in
                                StoryAvatarPill(
                                    member: member,
                                    profile: profilesByUserId[member.userId],
                                    profileState: member.userId == SupabaseService.shared.currentUserId ? profileState : nil,
                                    isSelected: index == currentIndex
                                ) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        currentIndex = index
                                        onMemberViewed?(member.userId)
                                    }
                                }
                                .id(index)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: currentIndex) { _, newIndex in
                        if hasHadUserSwitch {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        hasHadUserSwitch = true
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                    .onAppear {
                        proxy.scrollTo(currentIndex, anchor: .center)
                    }
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .overlay {
            if reactionBurstId > 0 {
                ReactionBurstOverlay(instanceId: reactionBurstId) { id in
                    if reactionBurstId == id { reactionBurstId = 0 }
                }
                .id(reactionBurstId)
                .allowsHitTesting(false)
                .ignoresSafeArea()
            }
        }
        .onAppear {
            if let idx = members.firstIndex(where: { $0.userId == initialMemberId }) {
                currentIndex = idx
            }
            onMemberViewed?(initialMemberId)
        }
        .onChange(of: currentIndex) { _, _ in
            if let member = currentMember {
                onMemberViewed?(member.userId)
            }
        }
    }
}

private struct StoryAvatarPill: View {
    let member: SanghaMemberRow
    let profile: ProfileRow?
    let profileState: ProfileState?
    let isSelected: Bool
    let onTap: () -> Void

    private let size: CGFloat = 44
    private let selectedSize: CGFloat = 52

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .stroke(isSelected ? AppColors.rejoyOrange : Color.white.opacity(0.3), lineWidth: isSelected ? 3 : 1.5)
                    .frame(width: (isSelected ? selectedSize : size) + 8, height: (isSelected ? selectedSize : size) + 8)
                avatarContent
                    .frame(width: isSelected ? selectedSize : size, height: isSelected ? selectedSize : size)
                    .clipShape(Circle())
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let ps = profileState, let image = ps.avatarImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else if let urlString = profile?.avatarUrl, let url = URL(string: urlString) {
            CachedAvatarImage(url: url, size: isSelected ? selectedSize : size) {
                Text("?").font(AppFont.rounded(size: 16, weight: .semibold)).foregroundStyle(AppColors.rejoyOrange)
            }
        } else {
            Circle()
                .fill(AppColors.rejoyOrange.opacity(0.3))
                .overlay(
                    Text(memberInitials)
                        .font(AppFont.rounded(size: (isSelected ? selectedSize : size) * 0.4, weight: .semibold))
                        .foregroundStyle(AppColors.rejoyOrange)
                )
        }
    }

    private var memberInitials: String {
        if let name = profile?.displayName, !name.isEmpty {
            let parts = name.split(separator: " ").compactMap { $0.first }
            if parts.count >= 2 { return String(parts.prefix(2)).uppercased() }
            if let first = parts.first { return String(first).uppercased() }
        }
        if let name = ProfileState.displayName, !name.isEmpty, member.userId == SupabaseService.shared.currentUserId {
            let parts = name.split(separator: " ").compactMap { $0.first }
            if parts.count >= 2 { return String(parts.prefix(2)).uppercased() }
            if let first = parts.first { return String(first).uppercased() }
        }
        return "?"
    }
}

private struct StoryActivityCard: View {
    let member: SanghaMemberRow
    let profile: ProfileRow?
    let date: Date
    let activityTypes: [ActivityType]
    let isCurrentUser: Bool
    let profileState: ProfileState?
    var onReactionBurst: (() -> Void)?
    @State private var sessions: [SessionRow] = []
    @State private var isActiveNow: Bool = false
    @State private var activeTrackingState: ActiveTrackingStateRow?
    @State private var now: Date = Date()
    @State private var isLoading = true
    @State private var reactionsBySessionId: [UUID: (count: Int, hasReacted: Bool)] = [:]
    @State private var showNudgeSent = false
    @State private var isSendingNudge = false
    @State private var remoteActivityTypes: [UUID: ActivityTypeRow] = [:]
    @Environment(\.appLanguage) private var appLanguage

    private func activityDisplay(for id: UUID) -> (name: String, symbolName: String) {
        if let a = activityTypes.first(where: { $0.id == id }) {
            return (a.name, a.symbolName)
        }
        if let r = remoteActivityTypes[id] {
            return (r.name, r.symbolName)
        }
        return (L.string("activity", language: appLanguage), "circle")
    }

    private var hasNoActivityToday: Bool {
        Calendar.current.isDateInToday(date) && !isLoading && sessions.isEmpty && !isActiveNow
    }

    private var memberDisplayName: String {
        if isCurrentUser, let name = ProfileState.displayName, !name.isEmpty {
            return name
        }
        if let name = profile?.displayName, !name.isEmpty {
            return name
        }
        return L.string("partner", language: appLanguage)
    }

    private var completedSeeds: Int {
        sessions.reduce(0) { $0 + $1.seeds }
    }

    private var completedMinutes: Int {
        sessions.reduce(0) { $0 + $1.durationSeconds } / 60
    }

    private var accumulatingSeconds: Int {
        guard let state = activeTrackingState else { return 0 }
        return max(0, Int(now.timeIntervalSince(state.startedAt)))
    }

    private var accumulatingSeeds: Int {
        accumulatingSeconds * AppSettings.seedsPerSecond
    }

    private var totalSeeds: Int {
        completedSeeds + accumulatingSeeds
    }

    private var totalMinutes: Int {
        completedMinutes + (accumulatingSeconds / 60)
    }

    private var seedsSubtitle: String {
        if isActiveNow {
            return "\(L.string("seeds_planted", language: appLanguage)) · \(L.string("seeds_accumulating", language: appLanguage))"
        }
        return "\(L.string("seeds_planted", language: appLanguage)) · \(L.formattedDuration(minutes: totalMinutes, language: appLanguage))"
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(memberDisplayName)
                .font(AppFont.title2)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)

            if isActiveNow {
                Text(L.string("active_now", language: appLanguage))
                    .font(AppFont.subheadline)
                    .foregroundStyle(AppColors.rejoyOrange)
            }

            if isLoading {
                ActivityCardSkeleton()
            } else {
                Text("\(totalSeeds)")
                    .font(AppFont.rounded(size: 40, weight: .semibold))
                    .foregroundStyle(isActiveNow ? AppColors.rejoyOrange : .white)
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Text(seedsSubtitle)
                    .font(AppFont.subheadline)
                    .foregroundStyle(.white.opacity(0.8))

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(sessions, id: \.id) { session in
                        let display = activityDisplay(for: session.activityTypeId)
                        let reaction = reactionsBySessionId[session.id] ?? (0, false)
                        HStack(spacing: 12) {
                            Image(systemName: display.symbolName)
                                .font(AppFont.title3)
                                .foregroundStyle(AppColors.rejoyOrange)
                                .frame(width: 32)
                            Text(L.activityName(display.name, language: appLanguage))
                                .font(AppFont.body)
                                .foregroundStyle(.white)
                            Spacer()
                            Text(L.formattedDuration(minutes: session.durationSeconds / 60, language: appLanguage))
                                .font(AppFont.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                            KarmaPartnersReactionChip(
                                count: reaction.count,
                                hasReacted: reaction.hasReacted,
                                canReact: SupabaseService.shared.currentUserId != nil && !reaction.hasReacted
                            ) {
                                reactToSession(session.id)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    if isActiveNow, let state = activeTrackingState {
                        let display = activityDisplay(for: state.activityTypeId)
                        HStack(spacing: 12) {
                            Image(systemName: display.symbolName)
                                .font(AppFont.title3)
                                .foregroundStyle(AppColors.rejoyOrange)
                                .frame(width: 32)
                            Text(L.activityName(display.name, language: appLanguage))
                                .font(AppFont.body)
                                .foregroundStyle(.white)
                            Spacer()
                            Text(L.formattedDuration(minutes: accumulatingSeconds / 60, language: appLanguage))
                                .font(AppFont.subheadline)
                                .foregroundStyle(AppColors.rejoyOrange)
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            Spacer()
            if hasNoActivityToday && !isCurrentUser && SupabaseService.shared.currentUserId != nil {
                Button {
                    sendNudge()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.raised.fill")
                            .font(AppFont.title3)
                        Text(L.string("push_to_activity_button", language: appLanguage))
                            .font(AppFont.headline)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColors.rejoyOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .disabled(isSendingNudge)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .padding(.top, 150)
        .overlay {
            if showNudgeSent {
                Text(L.string("nudge_sent", language: appLanguage))
                    .font(AppFont.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .task(id: member.userId) {
            isLoading = true
            await loadData()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if isActiveNow {
                now = Date()
            }
        }
    }

    private func loadData() async {
        do {
            let rows = try await SupabaseService.shared.fetchSessions(userId: member.userId, date: date)
            let active = try await SanghaService.shared.fetchActiveTrackingState(forUserIds: [member.userId])
            var reactions: [SessionReactionRow] = []
            if !rows.isEmpty {
                reactions = (try? await SupabaseService.shared.fetchReactions(sessionIds: rows.map(\.id))) ?? []
            }
            let localIds = Set(activityTypes.map(\.id))
            var neededIds = Set(rows.map(\.activityTypeId))
            if let state = active.first(where: { $0.userId == member.userId }) {
                neededIds.insert(state.activityTypeId)
            }
            let missingIds = neededIds.subtracting(localIds)
            var remote: [UUID: ActivityTypeRow] = [:]
            if !missingIds.isEmpty, let fetched = try? await SupabaseService.shared.fetchActivityTypesByIds(Array(missingIds)) {
                for row in fetched { remote[row.id] = row }
            }
            let currentId = SupabaseService.shared.currentUserId
            var map: [UUID: (count: Int, hasReacted: Bool)] = [:]
            for sessionId in rows.map(\.id) {
                let sessionReactions = reactions.filter { $0.sessionId == sessionId }
                let count = sessionReactions.count
                let hasReacted = currentId.map { id in sessionReactions.contains { $0.reactorUserId == id } } ?? false
                map[sessionId] = (count, hasReacted)
            }
            await MainActor.run {
                sessions = rows
                let state = active.first { $0.userId == member.userId }
                isActiveNow = state != nil
                activeTrackingState = state
                reactionsBySessionId = map
                remoteActivityTypes = remote
                isLoading = false
            }
        } catch {
            await MainActor.run {
                sessions = []
                isActiveNow = false
                activeTrackingState = nil
                reactionsBySessionId = [:]
                remoteActivityTypes = [:]
                isLoading = false
            }
        }
    }

    private func sendNudge() {
        guard !isSendingNudge else { return }
        isSendingNudge = true
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        Task {
            do {
                try await SupabaseService.shared.insertNudge(receiverUserId: member.userId)
                await MainActor.run {
                    showNudgeSent = true
                    isSendingNudge = false
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        await MainActor.run { showNudgeSent = false }
                    }
                }
            } catch {
                await MainActor.run { isSendingNudge = false }
            }
        }
    }

    private func reactToSession(_ sessionId: UUID) {
        guard let current = reactionsBySessionId[sessionId], !current.hasReacted else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        reactionsBySessionId[sessionId] = (current.count + 1, true)
        onReactionBurst?()
        Task {
            try? await SupabaseService.shared.insertReaction(sessionId: sessionId)
        }
    }
}

// MARK: - Karma Partners reaction (liquid glass chip)

private enum KarmaPartnersChipVisualState: Equatable {
    /// Signed in, user has not smiled yet — strong “tap me” vs clear “pressing” feedback.
    case interactive(pressed: Bool)
    /// Already reacted: quiet, no orange invite.
    case reacted
    /// Not signed in: preview only.
    case locked
}

private struct KarmaPartnersChipAppearance: View {
    let count: Int
    let state: KarmaPartnersChipVisualState

    private var isPressed: Bool {
        if case .interactive(let pressed) = state { return pressed }
        return false
    }

    private var isInteractive: Bool {
        if case .interactive = state { return true }
        return false
    }

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "face.smiling.fill")
                .font(AppFont.rounded(size: 16, weight: .semibold))
            Text("\(count)")
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background { capsuleBackground }
        .scaleEffect(isInteractive && isPressed ? 0.9 : 1)
        .shadow(color: Color.black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowY)
        .shadow(color: Color.black.opacity(0.1), radius: isInteractive && !isPressed ? 1 : 0, x: 0, y: 1)
        .opacity(overallOpacity)
    }

    private var foregroundColor: Color {
        switch state {
        case .interactive(let pressed):
            return pressed ? .white : .white.opacity(0.98)
        case .reacted:
            return .white.opacity(0.5)
        case .locked:
            return .white.opacity(0.38)
        }
    }

    @ViewBuilder
    private var capsuleBackground: some View {
        ZStack {
            Capsule()
                .fill(.ultraThinMaterial)

            switch state {
            case .interactive(let pressed):
                // Idle = clearly orange “tap me”; pressed = deeper / hotter orange.
                Capsule()
                    .fill(AppColors.rejoyOrange.opacity(pressed ? 0.52 : 0.36))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(pressed ? 0.1 : 0.1),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(pressed ? 0.35 : 0.38), Color.clear],
                            startPoint: UnitPoint(x: 0.22, y: 0.1),
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.overlay)
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: pressed
                                ? [
                                    AppColors.rejoyOrange.opacity(0.95),
                                    AppColors.rejoyOrange.opacity(0.4)
                                ]
                                : [
                                    AppColors.rejoyOrange.opacity(0.75),
                                    AppColors.rejoyOrange.opacity(0.32)
                                ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: pressed ? 1.5 : 1.15
                    )
            case .reacted, .locked:
                Capsule()
                    .fill(Color.white.opacity(0.05))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.clear],
                            startPoint: UnitPoint(x: 0.25, y: 0.1),
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.overlay)
                Capsule()
                    .stroke(Color.white.opacity(state == .reacted ? 0.22 : 0.16), lineWidth: 1)
            }
        }
    }

    private var shadowOpacity: Double {
        switch state {
        case .interactive(let pressed):
            return pressed ? 0.22 : 0.38
        case .reacted:
            return 0.22
        case .locked:
            return 0.18
        }
    }

    private var shadowRadius: CGFloat {
        switch state {
        case .interactive(let pressed):
            return pressed ? 4 : 10
        case .reacted:
            return 6
        case .locked:
            return 5
        }
    }

    private var shadowY: CGFloat {
        switch state {
        case .interactive(let pressed):
            return pressed ? 1.5 : 4
        default:
            return 3
        }
    }

    private var overallOpacity: Double {
        switch state {
        case .locked:
            return 0.9
        default:
            return 1
        }
    }
}

private struct KarmaPartnersReactionButtonStyle: ButtonStyle {
    let count: Int

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .hidden()
            .overlay {
                KarmaPartnersChipAppearance(
                    count: count,
                    state: .interactive(pressed: configuration.isPressed)
                )
            }
            .animation(.spring(response: 0.26, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

/// Smiles + count in a frosted capsule; interactive vs pressed vs done read clearly different.
private struct KarmaPartnersReactionChip: View {
    let count: Int
    let hasReacted: Bool
    let canReact: Bool
    let action: () -> Void

    var body: some View {
        Group {
            if canReact {
                Button(action: action) {
                    KarmaPartnersChipAppearance(count: count, state: .interactive(pressed: false))
                }
                .buttonStyle(KarmaPartnersReactionButtonStyle(count: count))
            } else if hasReacted {
                KarmaPartnersChipAppearance(count: count, state: .reacted)
            } else {
                KarmaPartnersChipAppearance(count: count, state: .locked)
            }
        }
    }
}

private struct ReactionBurstOverlay: View {
    let instanceId: Int
    let onComplete: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let bottomInset = geo.safeAreaInsets.bottom
            ZStack {
                ForEach(0..<12, id: \.self) { i in
                    ReactionParticle(
                        screenHeight: geo.size.height,
                        screenWidth: geo.size.width,
                        bottomInset: bottomInset,
                        index: i
                    )
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                onComplete(instanceId)
            }
        }
    }
}

private struct ReactionParticle: View {
    let screenHeight: CGFloat
    let screenWidth: CGFloat
    let bottomInset: CGFloat
    let index: Int
    let startX: CGFloat
    let endX: CGFloat
    let delay: Double
    @State private var offsetX: CGFloat
    @State private var offsetY: CGFloat
    @State private var opacity: Double = 1

    init(screenHeight: CGFloat, screenWidth: CGFloat, bottomInset: CGFloat, index: Int) {
        self.screenHeight = screenHeight
        self.screenWidth = screenWidth
        self.bottomInset = bottomInset
        self.index = index
        self.startX = CGFloat.random(in: -50 ... 50)
        self.endX = CGFloat.random(in: -screenWidth / 2 + 40 ... screenWidth / 2 - 40)
        self.delay = Double.random(in: 0 ... 0.2)
        _offsetX = State(initialValue: startX)
        _offsetY = State(initialValue: screenHeight / 2 + bottomInset + 60)
    }

    var body: some View {
        Image(systemName: "face.smiling.fill")
            .font(.system(size: 44))
            .foregroundStyle(AppColors.rejoyOrange)
            .offset(x: offsetX, y: offsetY)
            .opacity(opacity)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeOut(duration: 2.5)) {
                        offsetX = endX
                        offsetY = -screenHeight / 2 - 80
                        opacity = 0
                    }
                }
            }
    }
}

private struct ActivityCardSkeleton: View {
    @State private var opacity: CGFloat = 0.3

    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(opacity))
                .frame(width: 120, height: 20)
                .frame(maxWidth: .infinity)

            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(opacity * 0.9))
                .frame(width: 100, height: 36)
                .frame(maxWidth: .infinity)

            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(opacity * 0.6))
                .frame(width: 160, height: 14)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(opacity * 0.8))
                            .frame(width: 32, height: 24)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(opacity * 0.6))
                            .frame(width: 120, height: 16)
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(opacity * 0.5))
                            .frame(width: 48, height: 14)
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                opacity = 0.5
            }
        }
    }
}
