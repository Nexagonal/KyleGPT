import SwiftUI
import UIKit

func obfuscateEmail(_ email: String) -> String {
    let parts = email.split(separator: "@")
    guard parts.count == 2 else { return email }
    let username = String(parts[0])
    let domain = String(parts[1])
    if username.count <= 3 { return email }
    let firstChar = username.first!
    let lastChar = username.last!
    return "\(firstChar)\(lastChar)@\(domain)"
}

func isValidEmail(_ email: String) -> Bool {
    let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
    return emailPred.evaluate(with: email)
}

extension UIImage {
    func resized(toWidth width: CGFloat) -> UIImage? {
        let canvasSize = CGSize(width: width, height: CGFloat(ceil(width / size.width * size.height)))
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: canvasSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    var active: Bool
    
    func body(content: Content) -> some View {
        if active {
            content
                .overlay(
                    GeometryReader { geo in
                        Color.white.opacity(0.5)
                            .mask(
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(stops: [
                                                .init(color: .clear, location: 0.3),
                                                .init(color: .white, location: 0.5),
                                                .init(color: .clear, location: 0.7)
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .rotationEffect(.degrees(30))
                                    .offset(x: -geo.size.width + (phase * geo.size.width * 3))
                            )
                    }
                    .mask(content)
                )
                .onAppear {
                    withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        } else {
            content
        }
    }
}

extension View {
    func shimmer(active: Bool = true) -> some View { modifier(ShimmerModifier(active: active)) }
}
