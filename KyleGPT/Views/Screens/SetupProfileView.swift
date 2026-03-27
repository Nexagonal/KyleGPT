import SwiftUI

struct SetupProfileView: View {
    @AppStorage("needsNickname") private var needsNickname = true
    @State private var nickname = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            VStack(spacing: 12) {
                Text("What should KyleGPT call you?").font(.system(size: 16, weight: .bold, design: .monospaced))
            }
            
            VStack(spacing: 16) {
                TextField("Nickname", text: $nickname)
                    .padding().background(Color(UIColor.secondarySystemGroupedBackground).opacity(0.8))
                    .cornerRadius(16).focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit { saveNickname() }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage).font(.caption).foregroundColor(.red)
                }
                
                Button(action: saveNickname) {
                    Group {
                        if isLoading { ProgressView().tint(.primary) }
                        else { Text("Continue").font(.headline).foregroundColor(.primary) }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(.ultraThinMaterial).cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                }
                .disabled(nickname.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }
            .padding(.horizontal, 35)
            Spacer()
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isFocused = true }
        }
    }
    
    func saveNickname() {
        let trimmed = nickname.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        isLoading = true; errorMessage = ""
        guard let url = URL(string: "\(AppConfig.serverURL)/user/nickname") else { return }
        var r = APIClient.shared.authenticatedRequest(url: url, method: "POST")
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["nickname": trimmed])
        
        APIClient.shared.dataTask(with: r) { d, res, _ in
            DispatchQueue.main.async {
                self.isLoading = false
                if let http = res as? HTTPURLResponse, http.statusCode != 200 {
                    self.errorMessage = "Failed to save nickname. Try again."
                    Haptic.notification(.error)
                    return
                }
                Haptic.notification(.success)
                UserDefaults.standard.set(trimmed, forKey: "userNickname")
                withAnimation { self.needsNickname = false }
            }
        }
    }
}
