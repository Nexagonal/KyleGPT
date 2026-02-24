import SwiftUI

struct PresenceIndicator: View {
    let isPresent: Bool
    @State private var phraseIndex = 0
    @State private var isPulsing = false
    @State private var phraseTimer: Timer?
    let idlePhrases = ["Waiting for KyleGPT...", "This may take a minute...", "Notifying KyleGPT...", "Thanks for your patience..."]

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(isPresent ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2))
                    .frame(width: 8)
                    .scaleEffect(isPulsing ? 2.5 : 1.0)
                    .opacity(isPulsing ? 0.0 : 0.6)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isPulsing)
                Circle().fill(isPresent ? Color.blue : Color.gray)
                    .frame(width: 8).opacity(isPresent ? 1 : 0.4)
            }
            Text(isPresent ? "Thinking..." : idlePhrases[phraseIndex])
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .animation(.none, value: phraseIndex)
        }
        .padding(.vertical, 10).padding(.horizontal, 16)
        .background(.ultraThinMaterial).clipShape(Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.05), lineWidth: 1))
        .onAppear {
            isPulsing = true
            phraseTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.4)) { phraseIndex = (phraseIndex + 1) % idlePhrases.count }
            }
        }
        .onDisappear { phraseTimer?.invalidate(); phraseTimer = nil }
    }
}
