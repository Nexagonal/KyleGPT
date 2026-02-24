import SwiftUI

struct ChatRoomView: View {
    let roomName: String
    var chatId: String = ""
    var inputHeight: Binding<CGFloat>? = nil
    let isGodModeActive: Bool
    let logoutAction: () -> Void
    var onShowHistory: (() -> Void)? = nil
    var onChatTitleUpdated: (() -> Void)? = nil
    var onNewChatCreated: ((String) -> Void)? = nil
    var onNewChat: (() -> Void)? = nil
    @State private var messages: [Message] = []
    @State private var pollingTimer: Timer?
    @State private var heartbeatTimer: Timer?
    @State private var isAdminPresent = false
    @State private var isUserScrolling = false
    @State private var hasSentFirstMessage = false
    @State private var e2eeReady = false
    
    private var peerEmail: String {
        (isGodModeActive ? roomName : "admin@kylegpt.com").lowercased()
    }
    @FocusState private var inputFocused: Bool
    
    @State private var inputText = ""
    @State private var imageBase64ToSend: String?
    @State private var uiImagePreview: UIImage?

    var databaseURL: String {
        if !chatId.isEmpty {
            return "\(AppConfig.serverURL)/messages?chatId=\(chatId)"
        }
        return "\(AppConfig.serverURL)/messages?room=\(roomName)"
    }
    var statusURL: String { "\(AppConfig.serverURL)/status?room=\(roomName)" }

    struct LocalInputHeightKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
    }

    var sortedMessages: [Message] { messages.sorted(by: { $0.timestamp < $1.timestamp }) }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        inputFocused = false
                    }

                if messages.isEmpty {
                    EmptyStateView()
                        .transition(.opacity.animation(.easeInOut(duration: 1.0)))
                        .contentShape(Rectangle())
                        .onTapGesture { inputFocused = false }
                } else {
                    ScrollView {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill").font(.caption2)
                            Text("Messages are end-to-end encrypted.")
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.05), lineWidth: 0.5))
                        .padding(.top, 16)
                        .padding(.horizontal, 40)
                        
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(0 ..< sortedMessages.count, id: \.self) { i in
                                let msg = sortedMessages[i]
                                let isGrouped = i > 0 && sortedMessages[i - 1].isKyle == msg.isKyle && (msg.timestamp - sortedMessages[i - 1].timestamp) < 120
                                let showExtras = shouldShowClusterExtras(for: i, in: sortedMessages)

                                if msg.isKyle {
                                    HStack(alignment: .bottom, spacing: 8) {
                                        BotMessageView(
                                            message: msg,
                                            showActionsSuite: showExtras,
                                            timeString: formatTime(msg.timestamp),
                                            fullClusterText: getFullClusterText(for: i, in: sortedMessages)
                                        )
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, isGrouped ? 2 : 20)
                                    .id(msg.id)
                                } else {
                                    UserMessageCell(message: msg, showExtras: showExtras, isGrouped: isGrouped, timeString: formatTime(msg.timestamp))
                                        .id(msg.id)
                                }
                            }

                            if sortedMessages.last?.isKyle == false {
                                HStack {
                                    PresenceIndicator(isPresent: isAdminPresent)
                                    Spacer()
                                }
                                .padding(.leading, 16).padding(.top, 8)
                            }
                            Color.clear.frame(height: 1).id("bottom_anchor")
                        }
                        .padding(.vertical, 20)
                        .contentShape(Rectangle())
                        .onTapGesture { inputFocused = false }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: messages) { _ in
                        guard !isUserScrolling else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom_anchor", anchor: .bottom) }
                        }
                    }
                    .onChange(of: inputFocused) { focused in
                        if focused {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom_anchor", anchor: .bottom) }
                            }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                if !isGodModeActive {
                    HStack {
                        if let showHistory = onShowHistory {
                            Button(action: {
                                Haptic.impact(.light)
                                showHistory()
                            }) {
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            .padding(.trailing, 8)
                        }
                        ModelSelectorView()
                        
                        Spacer()
                        ServerStatusIndicator()
                            .padding(.trailing, 4)
                        
                        if let newChat = onNewChat {
                            Button(action: { newChat() }) {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(width: 36, height: 36)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                            }
                        }
                    }
                    .padding(.horizontal).padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .overlay(Divider(), alignment: .bottom)
                }
            }
            .safeAreaInset(edge: .bottom) {
                ChatInputBar(
                    inputText: $inputText,
                    imageBase64ToSend: $imageBase64ToSend,
                    uiImagePreview: $uiImagePreview,
                    inputFocused: _inputFocused,
                    onSend: handleSend
                )
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
                .background(GeometryReader { geo in
                    Color.clear.preference(key: LocalInputHeightKey.self, value: geo.size.height)
                })
                .onPreferenceChange(LocalInputHeightKey.self) { h in
                    DispatchQueue.main.async { inputHeight?.wrappedValue = h }
                }
            }
        }
        .onAppear {
            messages = []; hasSentFirstMessage = false
            CryptoManager.shared.fetchAndDeriveKey(forEmail: peerEmail) { success in
                DispatchQueue.main.async {
                    self.e2eeReady = success
                    self.e2eeFailed = !success
                    self.processMessages()
                    if !success {
                        print("⚠️ E2EE: Key exchange failed for \(peerEmail), messages will be unencrypted")
                    }
                }
            }
            
            if !chatId.isEmpty {
                fetchRoomMessages()
                startPolling()
                markChatAsRead()
            }
            
            if isGodModeActive { startHeartbeat() }
        }
        .onDisappear { pollingTimer?.invalidate(); heartbeatTimer?.invalidate() }
        .overlay(alignment: .top) {
            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.vertical, 8).padding(.horizontal, 16)
                    .background(Color.red.opacity(0.9))
                    .cornerRadius(20)
                    .shadow(radius: 4)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { withAnimation { errorMessage = nil } }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            withAnimation { errorMessage = nil }
                        }
                    }
                    .zIndex(100)
            }
        }
    }

    func markChatAsRead() {
        guard !chatId.isEmpty else { return }
        let endpoint = isGodModeActive ? "read" : "user-read"
        guard let url = URL(string: "\(AppConfig.serverURL)/chats/\(chatId)/\(endpoint)") else { return }
        var r = APIClient.shared.authenticatedRequest(url: url, method: "PATCH")
        r.httpBody = try? JSONSerialization.data(withJSONObject: [:])
        APIClient.shared.fire(request: r)
    }

    func formatTime(_ time: Double) -> String {
        let f = DateFormatter(); f.timeStyle = .short; return f.string(from: Date(timeIntervalSince1970: time))
    }
    func shouldShowClusterExtras(for index: Int, in sorted: [Message]) -> Bool {
        guard index < sorted.count - 1 else { return true }
        let current = sorted[index]; let next = sorted[index + 1]
        return current.isKyle != next.isKyle || (next.timestamp - current.timestamp) > 120
    }
    func getFullClusterText(for index: Int, in sorted: [Message]) -> String {
        let senderIsKyle = sorted[index].isKyle
        var cluster: [Message] = [sorted[index]]; var i = index - 1
        while i >= 0 {
            let prev = sorted[i]
            if prev.isKyle == senderIsKyle && (sorted[i + 1].timestamp - prev.timestamp) < 120 {
                cluster.insert(prev, at: 0); i -= 1
            } else { break }
        }
        return cluster.map { $0.text }.joined(separator: "\n")
    }
    
    func handleSend() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || imageBase64ToSend != nil else { return }
        Haptic.impact(.medium)
        
        if chatId.isEmpty {
            let capturedText = text
            let capturedImage = imageBase64ToSend
            inputText = ""; imageBase64ToSend = nil; uiImagePreview = nil
            createChatThenSend(text: capturedText, image: capturedImage)
            return
        }
        
        let newMsg = Message(id: UUID().uuidString, text: text, isKyle: isGodModeActive,
                             timestamp: Date().timeIntervalSince1970, room: roomName,
                             imageBase64: imageBase64ToSend, isPending: true, chatId: chatId)
        withAnimation(.easeInOut(duration: 0.3)) { messages.append(newMsg) }
        sendMessageToPi(message: newMsg)
        inputText = ""; imageBase64ToSend = nil; uiImagePreview = nil
        
        if !isGodModeActive && !hasSentFirstMessage && !text.isEmpty {
            hasSentFirstMessage = true
            let title = text.count <= 28 ? text : String(text.prefix(25)) + "..."
            if let titleUrl = URL(string: "\(AppConfig.serverURL)/chats/\(chatId)/title") {
                var tr = APIClient.shared.authenticatedRequest(url: titleUrl, method: "PATCH")
                tr.httpBody = try? JSONSerialization.data(withJSONObject: ["title": title])
                APIClient.shared.fire(request: tr)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onChatTitleUpdated?() }
        }
    }
    
    func createChatThenSend(text: String, image: String?) {
        guard let url = URL(string: "\(AppConfig.serverURL)/chats") else { return }
        var r = APIClient.shared.authenticatedRequest(url: url, method: "POST")
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["userEmail": roomName])
        APIClient.shared.dataTask(with: r) { d, _, _ in
            guard let d = d, let resp = try? JSONDecoder().decode(ChatCreateResponse.self, from: d) else { return }
            let newChatId = resp.chatId
            
            let newMsg = Message(id: UUID().uuidString, text: text, isKyle: self.isGodModeActive,
                                 timestamp: Date().timeIntervalSince1970, room: self.roomName,
                                 imageBase64: image, isPending: true, chatId: newChatId)
            self.sendMessageToPi(message: newMsg)
            
            if !text.isEmpty {
                let title = text.count <= 28 ? text : String(text.prefix(25)) + "..."
                if let titleUrl = URL(string: "\(AppConfig.serverURL)/chats/\(newChatId)/title") {
                    var tr = APIClient.shared.authenticatedRequest(url: titleUrl, method: "PATCH")
                    tr.httpBody = try? JSONSerialization.data(withJSONObject: ["title": title])
                    APIClient.shared.fire(request: tr)
                }
            }
            
            DispatchQueue.main.async {
                self.onNewChatCreated?(newChatId)
            }
        }
    }

    func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in sendHeartbeat() }
    }
    func sendHeartbeat() {
        guard let url = URL(string: statusURL) else { return }
        var r = APIClient.shared.authenticatedRequest(url: url, method: "PATCH")
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["fields": ["lastActive": ["doubleValue": Date().timeIntervalSince1970]]])
        APIClient.shared.fire(request: r)
    }
    func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in fetchRoomMessages(); fetchStatus() }
    }
    func fetchStatus() {
        guard let url = URL(string: statusURL) else { return }
        let request = APIClient.shared.authenticatedRequest(url: url)
        APIClient.shared.dataTask(with: request) { d, _, _ in
            guard let d = d,
                  let doc = try? JSONDecoder().decode(StatusResponse.self, from: d),
                  let last = doc.fields?.lastActive?.asDouble else { return }
            DispatchQueue.main.async { self.isAdminPresent = (Date().timeIntervalSince1970 - last) < 10 }
        }
    }
    @State private var errorMessage: String?

    func sendMessageToPi(message: Message) {
        guard let url = URL(string: "\(AppConfig.serverURL)/messages?documentId=\(message.id)") else { return }
        var r = APIClient.shared.authenticatedRequest(url: url, method: "POST")
        
        let textToSend: String
        if e2eeReady, let encrypted = CryptoManager.shared.encrypt(message.text, forPeer: peerEmail) {
            textToSend = encrypted
        } else {
            textToSend = message.text
        }
        
        var f: [String: Any] = [
            "text": ["stringValue": textToSend],
            "isKyle": ["booleanValue": message.isKyle],
            "timestamp": ["doubleValue": message.timestamp],
            "room": ["stringValue": message.room],
            "chatId": ["stringValue": message.chatId]
        ]
        if let b64 = message.imageBase64 {
            if e2eeReady, let encImg = CryptoManager.shared.encryptImage(b64, forPeer: peerEmail) {
                f["imageBase64"] = ["stringValue": encImg]
            } else {
                f["imageBase64"] = ["stringValue": b64]
            }
        }
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["fields": f])
        
        APIClient.shared.dataTask(with: r) { _, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    Haptic.notification(.error)
                    self.errorMessage = "Failed to send: \(error.localizedDescription)"
                }
                return
            }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                DispatchQueue.main.async {
                    Haptic.notification(.error)
                    self.errorMessage = "Server error: \(http.statusCode)"
                }
            }
        }
    }

    @State private var rawDocs: [FirestoreDocument] = []
    @State private var e2eeFailed = false

    func fetchRoomMessages() {
        guard let url = URL(string: databaseURL) else { return }
        let request = APIClient.shared.authenticatedRequest(url: url)
        APIClient.shared.dataTask(with: request) { d, _, _ in
            guard let d = d,
                  let res = try? JSONDecoder().decode(FirestoreResponse.self, from: d),
                  let docs = res.documents else { return }
            
            DispatchQueue.main.async {
                self.rawDocs = docs
                self.processMessages()
            }
        }
    }

    func processMessages() {
        if !e2eeReady && !e2eeFailed { return }

        let msgs = rawDocs.compactMap { doc -> Message? in
            guard let f = doc.fields else { return nil }
            let rawText = f.text?.asString ?? ""
            let rawImage = f.imageBase64?.asString
            
            let decryptedText = CryptoManager.shared.decrypt(rawText, fromPeer: self.peerEmail) ?? rawText
            let decryptedImage: String?
            if let img = rawImage, !img.isEmpty {
                decryptedImage = CryptoManager.shared.decryptImage(img, fromPeer: self.peerEmail) ?? img
            } else {
                decryptedImage = rawImage
            }
            
            return Message(id: doc.name ?? UUID().uuidString,
                           text: decryptedText,
                           isKyle: f.isKyle?.asBool ?? false,
                           timestamp: f.timestamp?.asDouble ?? 0.0,
                           room: f.room?.asString ?? "",
                           imageBase64: decryptedImage,
                           chatId: f.chatId?.asString ?? "")
        }
        
        if msgs.contains(where: { !$0.isKyle }) { self.hasSentFirstMessage = true }
        let pending = self.messages.filter { m in !msgs.contains(where: { $0.id == m.id }) }
        let final = (msgs + pending).sorted(by: { $0.timestamp < $1.timestamp })
        if self.messages.isEmpty && !final.isEmpty { withAnimation { self.messages = final } }
        else { self.messages = final }
    }
}
