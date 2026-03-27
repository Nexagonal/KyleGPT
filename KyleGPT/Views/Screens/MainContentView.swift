import SwiftUI

struct MainContentView: View {
    @AppStorage("currentUserEmail") private var currentUserEmail = ""
    @AppStorage("idToken") private var idToken = ""
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("isGodMode") private var isGodMode = false
    @AppStorage("needsNickname") private var needsNickname = false
    @AppStorage("currentChatId") private var currentChatId = ""
    @AppStorage("isGuestMode") private var isGuestMode = false

    var body: some View {
        Group {
            if isGodMode { GodModeDashboard(logoutAction: logout) }
            else if isLoggedIn {
                if needsNickname {
                    SetupProfileView()
                } else {
                    ChatContainerView(
                        roomName: currentUserEmail,
                        currentChatId: $currentChatId,
                        logoutAction: logout
                    )
                    .onAppear { currentChatId = "" }
                }
            }
            else {
                LoginView(
                    isLoggedIn: $isLoggedIn, isGodMode: $isGodMode,
                    currentUserEmail: $currentUserEmail, idToken: $idToken
                )
            }
        }.tint(.primary)
    }

    func logout() {
        DispatchQueue.main.async {
            self.isLoggedIn = false
            self.isGodMode = false
            self.isGuestMode = false
            self.currentUserEmail = ""
            self.idToken = ""
            self.currentChatId = ""
            
            UserDefaults.standard.removeObject(forKey: "idToken")
            UserDefaults.standard.removeObject(forKey: "refreshToken")
            UserDefaults.standard.synchronize()
        }
    }
}
