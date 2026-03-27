import SwiftUI

struct UserMessageCell: View {
    let message: Message
    let showExtras: Bool
    let isGrouped: Bool
    let timeString: String
    
    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                VStack(alignment: .trailing) {
                    if let b64 = message.imageBase64,
                       let data = Data(base64Encoded: b64),
                       let uiImg = UIImage(data: data) {
                        Image(uiImage: uiImg).resizable().scaledToFit()
                            .frame(maxWidth: 200).cornerRadius(12).padding(.bottom, 4)
                    }
                    if !message.text.isEmpty { Text(message.text).foregroundColor(.primary) }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                .shimmer(active: message.isPending)
                .opacity(message.isPending ? 0.7 : 1.0)

                if showExtras && !message.isPending {
                    Text(timeString)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8).padding(.bottom, 8)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, isGrouped ? 2 : 20)
    }
}
