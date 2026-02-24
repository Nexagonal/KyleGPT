import SwiftUI

struct ServerStatusIndicator: View {
    @State private var isServerUp: Bool = true
    @State private var isChecking: Bool = true
    @State private var isPulsing: Bool = false
    
    let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isChecking ? Color.yellow : (isServerUp ? Color.green : Color.red))
                    .frame(width: 8, height: 8)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0.0 : 0.3)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isPulsing)
                
                Circle()
                    .fill(isChecking ? Color.yellow : (isServerUp ? Color.green : Color.red))
                    .frame(width: 8, height: 8)
                    .shadow(color: (isChecking ? Color.yellow : (isServerUp ? Color.green : Color.red)).opacity(0.6), radius: 3)
            }
            
            Text(isChecking ? "Connecting..." : (isServerUp ? "Server Online" : "Server Offline"))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.075), lineWidth: 0.5))
        .onAppear { 
            checkStatus()
            isPulsing = true
        }
        .onReceive(timer) { _ in checkStatus() }
    }
    
    func checkStatus() {
        guard let url = URL(string: "\(AppConfig.serverURL)/health") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        
        URLSession.shared.dataTask(with: request) { _, response, _ in
            DispatchQueue.main.async {
                self.isChecking = false
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    withAnimation(.easeInOut(duration: 0.3)) { self.isServerUp = true }
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) { self.isServerUp = false }
                }
            }
        }.resume()
    }
}
