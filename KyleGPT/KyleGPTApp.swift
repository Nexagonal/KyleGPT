import SwiftUI
import UserNotifications
import UIKit

// App config is now handled by Secrets.swift

// --- APP DELEGATE ---
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        UIApplication.shared.registerForRemoteNotifications()
        
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                NotificationCenter.default.post(name: NSNotification.Name("DebugLog"), object: "✅ Permission Granted")
            } else {
                NotificationCenter.default.post(name: NSNotification.Name("DebugLog"), object: "❌ Permission Denied")
            }
        }
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        UserDefaults.standard.set(tokenString, forKey: "deviceToken")
        
        if let email = UserDefaults.standard.string(forKey: "currentUserEmail"), !email.isEmpty {
            registerTokenWithPi(email: email, token: tokenString)
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationCenter.default.post(name: NSNotification.Name("DebugLog"), object: "❌ Token Error: \(error.localizedDescription)")
    }
    
    func registerTokenWithPi(email: String, token: String) {
        guard let url = URL(string: "\(AppConfig.serverURL)/register-device") else { return }
        var request = APIClient.shared.authenticatedRequest(url: url, method: "POST")
        
        let body: [String: String] = ["email": email, "token": token]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        APIClient.shared.dataTask(with: request) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse {
                NotificationCenter.default.post(name: NSNotification.Name("DebugLog"), object: "✅ Pi Response: \(httpResponse.statusCode)")
            }
        }
    }
    
    // --- UPDATED LOGIC ---
    // This tells iOS: "If the app is open, do NOTHING."
    // Notifications will now only show if the app is minimized or closed.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // We pass an empty list [] to suppress the banner, sound, and badge while foregrounded.
        completionHandler([])
    }
}

// --- MAIN ENTRY POINT ---
@main
struct KyleGPTApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainContentView()
        }
    }
}
