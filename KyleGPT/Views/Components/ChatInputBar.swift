import SwiftUI

struct ChatInputBar: View {
    @Binding var inputText: String
    @Binding var imageBase64ToSend: String?
    @Binding var uiImagePreview: UIImage?
    @FocusState var inputFocused: Bool
    var onSend: () -> Void
    
    @State private var showingAttachmentActionSheet = false
    @State private var showingImagePicker = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var pickedImage: UIImage? = nil

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            if let preview = uiImagePreview {
                HStack {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: preview).resizable().scaledToFill()
                            .frame(width: 80, height: 80).clipShape(RoundedRectangle(cornerRadius: 12)).padding(8)
                        Button(action: {
                            withAnimation { uiImagePreview = nil; imageBase64ToSend = nil }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.6).clipShape(Circle()))
                        }.padding(4)
                    }
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: uiImagePreview != nil)
            }

            HStack(alignment: .center, spacing: 12) {
                Button(action: { showingAttachmentActionSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                }
                .confirmationDialog("Attach Photo", isPresented: $showingAttachmentActionSheet, titleVisibility: .visible) {
                    Button("Camera") {
                        imageSourceType = .camera
                        showingImagePicker = true
                    }
                    Button("Photo Library") {
                        imageSourceType = .photoLibrary
                        showingImagePicker = true
                    }
                    Button("Cancel", role: .cancel) { }
                }

                TextField("Message...", text: $inputText, axis: .vertical)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.ultraThinMaterial).cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    .lineLimit(1...5)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit { if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { onSend() } }

                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                        .opacity((inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && imageBase64ToSend == nil) ? 0.3 : 1.0)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && imageBase64ToSend == nil)
            }
            .padding(.horizontal).padding(.vertical, 10)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $pickedImage, sourceType: imageSourceType)
                .onDisappear {
                    if let img = pickedImage { uiImagePreview = img; processImage(img); pickedImage = nil }
                }
        }
    }
    
    func processImage(_ image: UIImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            let res = image.resized(toWidth: 600) ?? image
            let b64 = res.jpegData(compressionQuality: 0.3)?.base64EncodedString()
            DispatchQueue.main.async { self.imageBase64ToSend = b64 }
        }
    }
}
