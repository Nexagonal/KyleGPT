import SwiftUI

enum KyleGPTModel: String, CaseIterable {
    case v1 = "KyleGPT 1.0"
    case auto = "KyleGPT Auto"
}

struct ModelSelectorView: View {
    @State private var showDropdown = false
    @State private var selectedModel: KyleGPTModel = .v1

    var body: some View {
        Button(action: {
            Haptic.impact(.light)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { showDropdown.toggle() }
        }) {
            HStack(spacing: 4) {
                Text("KyleGPT").font(.headline).fontWeight(.semibold).foregroundColor(.primary)
                Text("1.0").font(.headline).fontWeight(.light).foregroundColor(.primary.opacity(0.45))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.6))
                    .rotationEffect(.degrees(showDropdown ? 180 : 0))
            }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topLeading) {
            if showDropdown {
                modelDropdown
                    .offset(y: 46)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
                    .zIndex(100)
            }
        }
    }

    var modelDropdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(KyleGPTModel.allCases, id: \.self) { model in
                let isSelected = selectedModel == model
                let isDisabled = model == .auto
                Button(action: {
                    guard !isDisabled else { return }
                    Haptic.impact(.medium)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selectedModel = model; showDropdown = false
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold)).foregroundColor(.primary)
                            .opacity(isSelected ? 1 : 0).frame(width: 14)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(model.rawValue).font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(isDisabled ? .secondary.opacity(0.4) : .primary)
                            if isDisabled {
                                Text("Coming soon").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary.opacity(0.4))
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 11).contentShape(Rectangle())
                }
                .disabled(isDisabled)
                if model != KyleGPTModel.allCases.last { Divider().opacity(0.5).padding(.leading, 38) }
            }
        }
        .frame(width: 210)
        .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.07), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
    }
}
