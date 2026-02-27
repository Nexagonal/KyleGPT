import SwiftUI

struct ChatContainerView: View {
    let roomName: String
    @Binding var currentChatId: String
    let logoutAction: () -> Void
    @AppStorage("userNickname") private var userNickname = ""
    @AppStorage("isGuestMode") private var isGuestMode = false
    
    @State private var showChatHistory = false
    @State private var chatList: [Chat] = []
    @State private var chatToDelete: Chat?
    @State private var showDeleteConfirm = false
    @State private var chatToRename: Chat?
    @State private var showRenameAlert = false
    @State private var renameText = ""
    
    @State private var showRenameUserAlert = false
    @State private var renameUserText = ""
    
    @State private var showDeleteAccountConfirm = false
    @State private var isDeletingAccount = false

    private let pollTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    private let sidebarWidth: CGFloat = 300
    @State private var sidebarDragOffset: CGFloat = 0
    @State private var inputBarHeight: CGFloat = 88 

    struct InputHeightKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                ChatRoomView(
                    roomName: roomName,
                    chatId: currentChatId,
                    inputHeight: $inputBarHeight,
                    isGodModeActive: false,
                    logoutAction: logoutAction,
                    onShowHistory: {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        fetchChats()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showChatHistory.toggle() }
                    },
                    onChatTitleUpdated: { fetchChats() },
                    onNewChatCreated: { newId in
                        if isGuestMode {
                            for chat in chatList {
                                deleteChat(chat)
                            }
                        }
                        currentChatId = newId
                        fetchChats()
                    },
                    onNewChat: {
                        Haptic.impact(.medium)
                        if isGuestMode {
                            for chat in chatList { deleteChat(chat) }
                        }
                        currentChatId = ""
                    }
                )
                .id(currentChatId)
                .frame(width: geo.size.width)
                .offset(x: showChatHistory ? sidebarWidth + sidebarDragOffset : max(0, sidebarDragOffset))
                .disabled(showChatHistory)

                Color.black.opacity(
                    showChatHistory || sidebarDragOffset > 0
                        ? 0.35 * (showChatHistory
                            ? min(1, (sidebarWidth + sidebarDragOffset) / sidebarWidth)
                            : min(1, sidebarDragOffset / sidebarWidth))
                        : 0
                )
                .frame(width: geo.size.width)
                .offset(x: showChatHistory ? sidebarWidth + sidebarDragOffset : max(0, sidebarDragOffset))
                .ignoresSafeArea()
                .allowsHitTesting(showChatHistory || sidebarDragOffset > 0)
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showChatHistory = false }
                }

                sidebarView(bottomInset: geo.safeAreaInsets.bottom)
                    .frame(width: sidebarWidth)
                    .offset(x: showChatHistory ? sidebarDragOffset : -sidebarWidth + max(0, sidebarDragOffset))
            }
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        let horizontal = value.translation.width
                        if showChatHistory {
                            sidebarDragOffset = min(0, horizontal)
                        } else {
                            if value.startLocation.x < 40 {
                                sidebarDragOffset = max(0, min(sidebarWidth, horizontal))
                            }
                        }
                    }
                    .onEnded { value in
                        let velocity = value.predictedEndTranslation.width - value.translation.width
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            if showChatHistory {
                                if sidebarDragOffset < -80 || velocity < -200 {
                                    showChatHistory = false
                                }
                            } else {
                                if sidebarDragOffset > 80 || velocity > 200 {
                                    showChatHistory = true
                                    fetchChats()
                                }
                            }
                            sidebarDragOffset = 0
                        }
                    }
            )
        }
        .alert("Delete Chat", isPresented: $showDeleteConfirm, presenting: chatToDelete) { chat in
            Button("Delete", role: .destructive) { deleteChat(chat) }
            Button("Cancel", role: .cancel) {}
        } message: { chat in
            Text("Are you sure you want to delete \"\(chat.title)\"? This cannot be undone.")
        }
        .alert("Rename Chat", isPresented: $showRenameAlert) {
            TextField("Chat name", text: $renameText)
            Button("Save") {
                if let chat = chatToRename, !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                    renameChat(chat, newTitle: renameText.trimmingCharacters(in: .whitespaces))
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Change Nickname", isPresented: $showRenameUserAlert) {
            TextField("New Nickname", text: $renameUserText)
            Button("Save") {
                if !renameUserText.trimmingCharacters(in: .whitespaces).isEmpty {
                    renameUser(newNickname: renameUserText.trimmingCharacters(in: .whitespaces))
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete Account", isPresented: $showDeleteAccountConfirm) {
            Button("Delete and Erase All Data", role: .destructive) {
                deleteAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to permanently delete your account and all associated data? This action cannot be undone.")
        }
        .onReceive(pollTimer) { _ in fetchChats() }
    }

    func sidebarView(bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Chats")
                    .font(.system(size: 28, weight: .bold))
                Spacer()
                Button(action: {
                    Haptic.impact(.medium)
                    if isGuestMode {
                        for chat in chatList { deleteChat(chat) }
                    }
                    currentChatId = ""
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showChatHistory = false }
                }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 60)
            .padding(.bottom, 8)

            if isGuestMode {
                VStack(spacing: 6) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.yellow)
                        Text("Guest Mode Active").font(.system(size: 13, weight: .bold, design: .monospaced))
                    }
                    Text("You cannot save multiple chats. Creating a new chat will delete your current one. Sign out and create an account to save history.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
                .padding(.vertical, 10)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    HStack {
                        Text("RECENTS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.7))
                            .tracking(0.5)
                        Spacer()
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 2)

                    ForEach(chatList) { chat in
                        let isActive = chat.id == currentChatId

                        Button(action: {
                            Haptic.impact(.light)
                            if let idx = chatList.firstIndex(where: { $0.id == chat.id }) {
                                chatList[idx].isUnread = false
                            }
                            currentChatId = chat.id
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showChatHistory = false }
                        }) {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(chat.title)
                                        .font(.system(size: 14, weight: (chat.isUnread || isActive) ? .semibold : .regular))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Text(formatDate(chat.createdAt))
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }

                                Spacer(minLength: 4)

                                if chat.isUnread {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 8, height: 8)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(isActive ? 0.12 : 0.05), radius: isActive ? 8 : 3, y: 2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(
                                        isActive ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.08),
                                        lineWidth: isActive ? 1.5 : 0.5
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(action: {
                                chatToRename = chat
                                renameText = chat.title
                                showRenameAlert = true
                            }) {
                                Label("Rename", systemImage: "pencil")
                            }
                            Button(role: .destructive, action: {
                                chatToDelete = chat
                                showDeleteConfirm = true
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
            .mask(
                VStack(spacing: 0) {
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 90)
                }
            )

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 36, height: 36)
                        let initial = userNickname.isEmpty ? String(roomName.prefix(1)) : String(userNickname.prefix(1))
                        Text(initial.uppercased())
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(userNickname.isEmpty ? "User" : userNickname)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text(obfuscateEmail(roomName))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Menu {
                        Button(action: {
                            renameUserText = userNickname
                            showRenameUserAlert = true
                        }) {
                            Label("Change Nickname", systemImage: "pencil")
                        }
                        
                        if !isGuestMode {
                            Button(role: .destructive, action: {
                                showDeleteAccountConfirm = true
                            }) {
                                Label("Delete Account", systemImage: "trash")
                            }
                        }
                        
                        Button(role: .destructive, action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showChatHistory = false }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { logoutAction() }
                        }) {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal).padding(.vertical, 10)
            }
            .frame(height: (inputBarHeight > 0 ? inputBarHeight : 88) + 5, alignment: .top)
        }
        .background(.ultraThinMaterial)
        .ignoresSafeArea(edges: .bottom)
    }

    func formatDate(_ ts: Double) -> String {
        let f = DateFormatter()
        let date = Date(timeIntervalSince1970: ts)
        if Calendar.current.isDateInToday(date) { f.timeStyle = .short; f.dateStyle = .none }
        else { f.dateStyle = .medium; f.timeStyle = .short }
        return f.string(from: date)
    }

    func fetchChats() {
        guard let url = URL(string: "\(AppConfig.serverURL)/chats?userEmail=\(roomName)") else { return }
        let request = APIClient.shared.authenticatedRequest(url: url)
        APIClient.shared.dataTask(with: request) { d, _, _ in
            guard let d = d, let res = try? JSONDecoder().decode(ChatListResponse.self, from: d) else { return }
            let chats = res.chats.map {
                let forceRead = ($0.chatId == self.currentChatId)
                return Chat(id: $0.chatId, title: $0.title, userEmail: $0.userEmail, createdAt: $0.createdAt,
                     deletedByUser: $0.deletedByUser == 1, isUnread: forceRead ? false : ($0.isUnread ?? false))
            }
            DispatchQueue.main.async { self.chatList = chats }
        }
    }

    func deleteChat(_ chat: Chat) {
        guard let url = URL(string: "\(AppConfig.serverURL)/chats/\(chat.id)/delete") else { return }
        var r = APIClient.shared.authenticatedRequest(url: url, method: "PATCH")
        r.httpBody = try? JSONSerialization.data(withJSONObject: [:])
        APIClient.shared.dataTask(with: r) { _, _, _ in
            DispatchQueue.main.async {
                self.chatList.removeAll { $0.id == chat.id }
                if self.currentChatId == chat.id {
                    self.currentChatId = ""
                }
            }
        }
    }

    func renameChat(_ chat: Chat, newTitle: String) {
        guard let url = URL(string: "\(AppConfig.serverURL)/chats/\(chat.id)/title") else { return }
        var r = APIClient.shared.authenticatedRequest(url: url, method: "PATCH")
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["title": newTitle])
        APIClient.shared.dataTask(with: r) { _, _, _ in
            DispatchQueue.main.async {
                if let idx = self.chatList.firstIndex(where: { $0.id == chat.id }) {
                    let truncated = newTitle.count <= 28 ? newTitle : String(newTitle.prefix(25)) + "..."
                    self.chatList[idx].title = truncated
                }
            }
        }
    }

    func renameUser(newNickname: String) {
        let trimmed = newNickname.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        guard let url = URL(string: "\(AppConfig.serverURL)/user/nickname") else { return }
        var r = APIClient.shared.authenticatedRequest(url: url, method: "POST")
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["nickname": trimmed])
        APIClient.shared.dataTask(with: r) { _, res, _ in
            DispatchQueue.main.async {
                if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                    self.userNickname = trimmed
                }
            }
        }
    }

    func deleteAccount() {
        guard let url = URL(string: "\(AppConfig.serverURL)/account") else { return }
        var r = APIClient.shared.authenticatedRequest(url: url, method: "DELETE")
        APIClient.shared.dataTask(with: r) { _, _, _ in
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showChatHistory = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { logoutAction() }
            }
        }
    }
}
