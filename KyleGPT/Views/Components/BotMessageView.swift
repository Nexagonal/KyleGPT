import SwiftUI

struct BotMessageView: View {
    let message: Message
    let showActionsSuite: Bool
    let timeString: String
    let fullClusterText: String
    
    @State private var displayedText = ""
    @State private var typewritingDone = false
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let b64 = message.imageBase64, let data = Data(base64Encoded: b64), let uiImg = UIImage(data: data) {
                Image(uiImage: uiImg).resizable().scaledToFit().frame(maxWidth: 250).cornerRadius(12)
            }
            if !message.text.isEmpty {
                Text(displayedText)
                    .foregroundColor(.primary.opacity(0.8))
                    .font(.system(size: 16, weight: .regular, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if showActionsSuite && typewritingDone {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 18) {
                        Button(action: { Haptic.impact(.light) }) { Image(systemName: "hand.thumbsup") }
                        Button(action: { Haptic.impact(.light) }) { Image(systemName: "hand.thumbsdown") }
                        Button(action: {
                            Haptic.impact(.medium)
                            UIPasteboard.general.string = fullClusterText
                            withAnimation { didCopy = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { didCopy = false } }
                        }) { Image(systemName: didCopy ? "checkmark" : "doc.on.doc") }
                    }
                    .font(.system(size: 13)).foregroundColor(.secondary.opacity(0.7))
                    Text(timeString).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundColor(.secondary.opacity(0.5))
                }
                .transition(.opacity.animation(.easeIn(duration: 0.3)))
            }
        }
        .padding(.trailing, 40)
        .task {
            let isOld = Date().timeIntervalSince1970 - message.timestamp > 5
            if isOld {
                displayedText = message.text
                typewritingDone = true
                return
            }
            if displayedText == message.text { return }
            
            displayedText = ""
            let generator = UIImpactFeedbackGenerator(style: .soft); generator.prepare()
            var charIndex = 0
            for char in message.text {
                guard !Task.isCancelled else { break }
                let randomDelay = UInt64(Double.random(in: 15...35) * 1_000_000)
                try? await Task.sleep(nanoseconds: randomDelay)
                displayedText.append(char)
                if charIndex % 3 == 0 { generator.impactOccurred(intensity: 0.4) }
                charIndex += 1
            }
            withAnimation(.easeIn(duration: 0.2)) { typewritingDone = true }
        }
    }
}
