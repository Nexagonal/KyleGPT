import SwiftUI

struct GodModeUserRowView: View {
    let user: AdminChatsResponse.AdminUser
    @AppStorage("adminActiveChatId") private var adminActiveChatId = ""
    
    var body: some View {
        let unreadCount = user.chats.filter { $0.isUnread && $0.chatId != adminActiveChatId }.count
        let chatSuffix = user.chats.count == 1 ? "" : "s"
        
        NavigationLink(destination: AdminUserChatsView(user: user)) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(user.nickname)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                        Text(user.userEmail)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Text("\(user.chats.count) chat\(chatSuffix)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                Spacer()
                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }
        }
    }
}

struct GodModeDashboard: View {
    let logoutAction: () -> Void
    @State private var adminUsers: [AdminChatsResponse.AdminUser] = []
    @State private var dashTimer: Timer?
    @AppStorage("adminActiveChatId") private var adminActiveChatId = ""
    
    @State private var isExporting = false
    @State private var documentToShare: URL?
    @State private var showShareSheet = false

    var body: some View {
        NavigationView {
            List {
                ForEach(adminUsers, id: \.userEmail) { user in
                    GodModeUserRowView(user: user)
                }
            }
            .navigationTitle("KylePi Control")
            .toolbar { 
                ToolbarItem(placement: .navigationBarTrailing) { 
                    HStack {
                        ServerStatusIndicator()
                        if isExporting {
                            ProgressView().tint(.primary).padding(.horizontal, 8)
                        } else {
                            Button(action: exportAllChats) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        Button("Log Out", action: logoutAction) 
                    }
                } 
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = documentToShare {
                    ActivityViewController(activityItems: [url])
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear { fetchAllChats(); dashTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in fetchAllChats() } }
        .onDisappear { dashTimer?.invalidate(); dashTimer = nil }
    }

    func exportAllChats() {
        isExporting = true
        let group = DispatchGroup()
        for user in adminUsers {
            group.enter()
            CryptoManager.shared.fetchAndDeriveKey(forEmail: user.userEmail) { _ in group.leave() }
        }
        
        group.notify(queue: .global(qos: .userInitiated)) {
            guard let url = URL(string: "\(AppConfig.serverURL)/export") else { 
                DispatchQueue.main.async { self.isExporting = false }
                return 
            }
            let request = APIClient.shared.authenticatedRequest(url: url)
            APIClient.shared.dataTask(with: request) { d, _, _ in
                defer { DispatchQueue.main.async { self.isExporting = false } }
                guard let d = d, let res = try? JSONDecoder().decode(FirestoreResponse.self, from: d), let docs = res.documents else { return }
                
                var csvText = "Timestamp,Room,Sender,Message\n"
                
                for doc in docs {
                    guard let f = doc.fields else { continue }
                    let room = f.room?.asString ?? "Unknown"
                    let isKyle = f.isKyle?.asBool ?? false
                    let rawText = f.text?.asString ?? ""
                    let ts = f.timestamp?.asDouble ?? 0.0
                    
                    let decryptedText = CryptoManager.shared.decrypt(rawText, fromPeer: room) ?? rawText
                    let safeText = decryptedText.replacingOccurrences(of: "\"", with: "\"\"").replacingOccurrences(of: "\n", with: " ")
                    let dateStr = DateFormatter.localizedString(from: Date(timeIntervalSince1970: ts), dateStyle: .short, timeStyle: .medium)
                    
                    csvText += "\"\(dateStr)\",\"\(room)\",\"\(isKyle ? "KyleGPT" : room)\",\"\(safeText)\"\n"
                }
                
                let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("KyleGPT_Export_\(Int(Date().timeIntervalSince1970)).csv")
                do {
                    try csvText.write(to: fileURL, atomically: true, encoding: .utf8)
                    DispatchQueue.main.async {
                        self.documentToShare = fileURL
                        self.showShareSheet = true
                    }
                } catch { print("Export Error: \(error)") }
            }
        }
    }

    func fetchAllChats() {
        guard let url = URL(string: "\(AppConfig.serverURL)/chats/all") else { return }
        let request = APIClient.shared.authenticatedRequest(url: url)
        APIClient.shared.dataTask(with: request) { d, _, _ in
            guard let d = d else { return }
            do {
                var res = try JSONDecoder().decode(AdminChatsResponse.self, from: d)
                DispatchQueue.main.async {
                    let activeId = self.adminActiveChatId
                    if !activeId.isEmpty {
                        for i in 0..<res.users.count {
                            for j in 0..<res.users[i].chats.count {
                                if res.users[i].chats[j].chatId == activeId {
                                    res.users[i].chats[j].isUnread = false
                                }
                            }
                        }
                    }
                    self.adminUsers = res.users
                }
            } catch {
                let raw = String(data: d, encoding: .utf8) ?? "unknown"
                DispatchQueue.main.async {
                    self.adminUsers = [] 
                    print("Admin JSON Error: \(error)\nPayload: \(raw)")
                }
            }
        }
    }
}

struct AdminUserChatsView: View {
    let user: AdminChatsResponse.AdminUser
    @AppStorage("adminActiveChatId") private var adminActiveChatId = ""

    var body: some View {
        List {
            ForEach(user.chats, id: \.chatId) { chat in
                NavigationLink(destination: AdminChatDetailView(chat: chat, userEmail: user.userEmail)) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill((chat.isUnread && chat.chatId != adminActiveChatId) ? Color.blue : Color.clear)
                            .frame(width: 8, height: 8)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(chat.title)
                                .font(.system(size: 15, weight: (chat.isUnread && chat.chatId != adminActiveChatId) ? .semibold : .regular, design: .monospaced))
                                .lineLimit(1)
                            HStack(spacing: 8) {
                                Text("\(chat.messageCount) msg\(chat.messageCount == 1 ? "" : "s")")
                                if chat.deletedByUser {
                                    Text("(deleted by user)")
                                        .foregroundColor(.red.opacity(0.7))
                                }
                            }
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(formatDate(chat.latestMessageTimestamp > 0 ? chat.latestMessageTimestamp : chat.createdAt))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle(user.userEmail)
        .navigationBarTitleDisplayMode(.inline)
    }

    func formatDate(_ ts: Double) -> String {
        let f = DateFormatter()
        let date = Date(timeIntervalSince1970: ts)
        if Calendar.current.isDateInToday(date) { f.timeStyle = .short; f.dateStyle = .none }
        else { f.dateStyle = .short; f.timeStyle = .short }
        return f.string(from: date)
    }
}

struct AdminChatDetailView: View {
    let chat: AdminChatsResponse.AdminChat
    let userEmail: String
    @AppStorage("adminActiveChatId") private var adminActiveChatId = ""

    var body: some View {
        ChatRoomView(
            roomName: userEmail,
            chatId: chat.chatId,
            isGodModeActive: true,
            logoutAction: {}
        )
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { adminActiveChatId = chat.chatId }
        .onDisappear { if adminActiveChatId == chat.chatId { adminActiveChatId = "" } }
    }
}
