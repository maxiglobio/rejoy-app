import SwiftUI

struct ProfileVisibilityView: View {
    var initialIsVisible: Bool? = nil

    @AppStorage("appLanguage") private var appLanguageStorage = ""
    @State private var mySanghas: [SanghaRow] = []
    @State private var myMembership: SanghaMemberRow?
    @State private var memberCountBySanghaId: [UUID: Int] = [:]
    @State private var sanghaToLeave: SanghaRow?
    @State private var showInviteSheet = false
    @State private var showCreateSangha = false
    @State private var selectedSanghaForOptions: SanghaRow?
    @State private var showSwitchToPrivateAlert = false
    @State private var showLeaveGroupAlert = false
    @State private var visibilityError: String?
    @State private var isRefreshing = false
    @State private var optimisticVisibility: Bool? = nil

    private var isVisible: Bool {
        (optimisticVisibility ?? myMembership?.isVisible ?? initialIsVisible) ?? false
    }

    private var groups: [SanghaRow] { mySanghas }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    ProfileSectionHeader(title: L.string("public_profile", language: appLanguageStorage))
                    ProfileCard {
                    Button {
                        handleSwitcherTap()
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "person.2.fill")
                                .font(AppFont.rounded(size: 20, weight: .medium))
                                .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.008))
                                .frame(width: 28)
                            Text(L.string("public_profile", language: appLanguageStorage))
                                .font(AppFont.rounded(size: 18, weight: .regular))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 0)
                            HStack(spacing: 8) {
                                Toggle("", isOn: Binding(
                                    get: { isVisible },
                                    set: { _ in handleSwitcherTap() }
                                ))
                                .labelsHidden()
                                .tint(AppColors.rejoyOrange)
                                .disabled(optimisticVisibility != nil)
                                if optimisticVisibility != nil {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                }
                }
                if !isVisible {
                    Text(L.string("private_profile_description", language: appLanguageStorage))
                        .font(AppFont.rounded(size: 15, weight: .regular))
                        .foregroundStyle(AppColors.dotsSecondaryText)
                        .padding(.horizontal, 4)
                        .padding(.top, 8)
                }

                if isVisible || mySanghas.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ProfileSectionHeader(title: L.string("groups", language: appLanguageStorage))
                        if isRefreshing {
                            GroupCardSkeleton()
                            GroupCardSkeleton()
                        } else {
                        ForEach(groups, id: \.id) { sangha in
                        ProfileCard {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(sangha.name)
                                        .font(AppFont.headline)
                                        .foregroundStyle(.primary)
                                    Text(String(format: L.string("group_members_count", language: appLanguageStorage), memberCountBySanghaId[sangha.id] ?? 0))
                                        .font(AppFont.rounded(size: 14, weight: .regular))
                                        .foregroundStyle(AppColors.trailing)
                                }
                                Spacer(minLength: 0)
                                ShareLink(
                                    item: String(format: L.string("invite_message", language: appLanguageStorage), sangha.inviteCode),
                                    subject: Text("\(L.string("sangha", language: appLanguageStorage)): \(sangha.name)")
                                ) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(AppFont.rounded(size: 20, weight: .medium))
                                        .foregroundStyle(AppColors.trailing)
                                }
                                .buttonStyle(.plain)
                                .simultaneousGesture(TapGesture().onEnded {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                })
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    selectedSanghaForOptions = sangha
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(AppFont.rounded(size: 22, weight: .medium))
                                        .foregroundStyle(AppColors.trailing)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                        Divider()
                            .padding(.vertical, 16)
                        HStack(spacing: 12) {
                            ProfileCard {
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    showInviteSheet = true
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "person.badge.plus")
                                            .font(AppFont.rounded(size: 18, weight: .medium))
                                            .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.008))
                                            .frame(width: 24)
                                        Text(L.string("join_by_code", language: appLanguageStorage))
                                            .font(AppFont.rounded(size: 16, weight: .medium))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                            }
                            .frame(maxWidth: .infinity)
                            ProfileCard {
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    showCreateSangha = true
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "plus.circle")
                                            .font(AppFont.rounded(size: 18, weight: .medium))
                                            .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.008))
                                            .frame(width: 24)
                                        Text(L.string("create_sangha", language: appLanguageStorage))
                                            .font(AppFont.rounded(size: 16, weight: .medium))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .background(AppColors.background)
        .navigationTitle(L.string("profile_visibility", language: appLanguageStorage))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await load()
        }
        .onAppear {
            Task { await load() }
        }
        .onDisappear {
            NotificationCenter.default.post(name: .profileVisibilityDidChange, object: nil)
        }
        .sheet(isPresented: $showInviteSheet) {
            ProfileVisibilityInviteSheet(onJoined: { sangha in
                if !mySanghas.contains(where: { $0.id == sangha.id }) {
                    mySanghas.insert(sangha, at: 0)
                    memberCountBySanghaId = memberCountBySanghaId.merging([sangha.id: 1]) { _, new in new }
                }
                Task {
                    await load()
                    NotificationCenter.default.post(name: .profileVisibilityDidChange, object: nil)
                }
            })
        }
        .sheet(item: $selectedSanghaForOptions) { sangha in
            GroupOptionsSheet(
                sangha: sangha,
                onPauseVisibility: {
                    selectedSanghaForOptions = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showSwitchToPrivateAlert = true
                    }
                },
                onLeaveGroup: {
                    sanghaToLeave = selectedSanghaForOptions
                    selectedSanghaForOptions = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showLeaveGroupAlert = true
                    }
                },
                onDismiss: { selectedSanghaForOptions = nil }
            )
        }
        .sheet(isPresented: $showCreateSangha) {
            CreateSanghaSheet(onCreated: { sangha in
                if !mySanghas.contains(where: { $0.id == sangha.id }) {
                    mySanghas.insert(sangha, at: 0)
                    memberCountBySanghaId = memberCountBySanghaId.merging([sangha.id: 1]) { _, new in new }
                }
                if myMembership == nil, let userId = SupabaseService.shared.currentUserId {
                    myMembership = SanghaMemberRow(
                        sanghaId: sangha.id,
                        userId: userId,
                        joinedAt: Date(),
                        role: "creator",
                        isVisible: true
                    )
                }
                Task {
                    await load()
                    NotificationCenter.default.post(name: .profileVisibilityDidChange, object: nil)
                }
            })
        }
        .alert(L.string("switch_to_private_confirm", language: appLanguageStorage), isPresented: $showSwitchToPrivateAlert) {
            Button(L.string("cancel", language: appLanguageStorage), role: .cancel) { }
            Button(L.string("done", language: appLanguageStorage)) {
                optimisticVisibility = false
                Task {
                    do {
                        try await SanghaService.shared.setVisibility(visible: false)
                        await load()
                        NotificationCenter.default.post(name: .profileVisibilityDidChange, object: nil)
                        await MainActor.run { optimisticVisibility = nil }
                    } catch {
                        await MainActor.run {
                            optimisticVisibility = true
                            visibilityError = error.localizedDescription
                        }
                    }
                }
            }
        } message: {
            Text(L.string("switch_to_private_confirm_message", language: appLanguageStorage))
        }
        .alert(L.string("error", language: appLanguageStorage), isPresented: .init(
            get: { visibilityError != nil },
            set: { if !$0 { visibilityError = nil } }
        )) {
            Button(L.string("done", language: appLanguageStorage)) {
                visibilityError = nil
            }
        } message: {
            if let err = visibilityError {
                Text(err)
            }
        }
        .alert(L.string("leave_group_confirm", language: appLanguageStorage), isPresented: $showLeaveGroupAlert) {
            Button(L.string("cancel", language: appLanguageStorage), role: .cancel) {
                sanghaToLeave = nil
            }
            Button(L.string("leave_group", language: appLanguageStorage), role: .destructive) {
                guard let sangha = sanghaToLeave else { return }
                Task {
                    try? await SanghaService.shared.leaveSangha(sanghaId: sangha.id)
                    mySanghas.removeAll { $0.id == sangha.id }
                    var updatedCounts = memberCountBySanghaId
                    updatedCounts.removeValue(forKey: sangha.id)
                    memberCountBySanghaId = updatedCounts
                    if mySanghas.isEmpty { myMembership = nil }
                    sanghaToLeave = nil
                    NotificationCenter.default.post(name: .profileVisibilityDidChange, object: nil)
                }
            }
        } message: {
            Text(L.string("leave_group_confirm_message", language: appLanguageStorage))
        }
    }

    private func handleSwitcherTap() {
        if isVisible {
            showSwitchToPrivateAlert = true
        } else if !mySanghas.isEmpty {
            optimisticVisibility = true
            Task {
                do {
                    try await SanghaService.shared.setVisibility(visible: true)
                    await load()
                    NotificationCenter.default.post(name: .profileVisibilityDidChange, object: nil)
                    await MainActor.run { optimisticVisibility = nil }
                } catch {
                    await MainActor.run { optimisticVisibility = false }
                }
            }
        } else {
            showInviteSheet = true
        }
    }

    private func load() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let sanghas = try await SanghaService.shared.fetchMySanghas()
            let membership = try await SanghaService.shared.fetchMyMembership()
            let sanghaIds = sanghas.map(\.id)
            let counts = try await SanghaService.shared.fetchMemberCounts(for: sanghaIds)
            await MainActor.run {
                mySanghas = sanghas
                myMembership = membership
                memberCountBySanghaId = counts
            }
        } catch {
            await MainActor.run {
                mySanghas = []
                myMembership = nil
                memberCountBySanghaId = [:]
            }
        }
    }
}

private struct GroupOptionsSheet: View {
    let sangha: SanghaRow
    @AppStorage("appLanguage") private var appLanguageStorage = ""
    let onPauseVisibility: () -> Void
    let onLeaveGroup: () -> Void
    let onDismiss: () -> Void

    private let accentOrange = AppColors.rejoyOrange

    private var inviteMessage: String {
        String(format: L.string("invite_message", language: appLanguageStorage), sangha.inviteCode)
    }

    var body: some View {
        NavigationStack {
            List {
                ShareLink(
                    item: inviteMessage,
                    subject: Text("\(L.string("sangha", language: appLanguageStorage)): \(sangha.name)")
                ) {
                    HStack(spacing: 16) {
                        Image(systemName: "square.and.arrow.up")
                            .font(AppFont.rounded(size: 20, weight: .medium))
                            .foregroundStyle(accentOrange)
                            .frame(width: 28)
                        Text(L.string("invite_to_group", language: appLanguageStorage))
                            .font(AppFont.rounded(size: 18, weight: .regular))
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)
                Button {
                    onPauseVisibility()
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "eye.slash")
                            .font(AppFont.rounded(size: 20, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 28)
                        Text(L.string("pause_my_visibility", language: appLanguageStorage))
                            .font(AppFont.rounded(size: 18, weight: .regular))
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)
                Button {
                    onLeaveGroup()
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(AppFont.rounded(size: 20, weight: .medium))
                            .foregroundStyle(.red)
                            .frame(width: 28)
                        Text(L.string("leave_group", language: appLanguageStorage))
                            .font(AppFont.rounded(size: 18, weight: .regular))
                            .foregroundStyle(.red)
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle(sangha.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.string("cancel", language: appLanguageStorage)) {
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(280)])
    }
}

private struct GroupCardSkeleton: View {
    @State private var opacity: CGFloat = 0.4

    var body: some View {
        ProfileCard {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray4).opacity(opacity))
                        .frame(width: 120, height: 18)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray4).opacity(opacity * 0.8))
                        .frame(width: 80, height: 14)
                }
                Spacer(minLength: 0)
                Circle()
                    .fill(Color(.systemGray4).opacity(opacity))
                    .frame(width: 22, height: 22)
            }
            .padding(.vertical, 4)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                opacity = 0.7
            }
        }
    }
}

extension Notification.Name {
    static let profileVisibilityDidChange = Notification.Name("profileVisibilityDidChange")
}
