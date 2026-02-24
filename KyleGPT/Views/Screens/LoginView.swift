import SwiftUI

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @Binding var isGodMode: Bool
    @Binding var currentUserEmail: String
    @Binding var idToken: String
    
    @State private var email = ""
    @State private var code = ""
    @State private var isCodeSent = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var animateIn = false
    @State private var isSuccessMessage = false
    @FocusState private var focusedField: Field?

    enum Field: Hashable { case email, code }

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            VStack(spacing: 10) {
                Text("KyleGPT").font(.system(size: 40, weight: .bold, design: .monospaced)).foregroundColor(.primary)
                Text("Lyfe prompts, Kyle answers.").font(.system(size: 15, weight: .medium, design: .monospaced)).foregroundColor(.secondary).opacity(0.7)
            }.opacity(animateIn ? 1 : 0).offset(y: animateIn ? 0 : 10)

            VStack(spacing: 15) {
                if !isCodeSent {
                    TextField("Email Address", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding().background(Color(UIColor.secondarySystemGroupedBackground).opacity(0.6))
                        .cornerRadius(16).focused($focusedField, equals: .email).submitLabel(.go)
                        .onSubmit { if !email.isEmpty { requestCode() } }
                } else {
                    Text("Sent to \(email)").font(.caption).foregroundColor(.secondary)
                    
                    ZStack {
                        HStack(spacing: 10) {
                            ForEach(0..<6, id: \.self) { index in
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(code.count == index && focusedField == .code ? Color.primary : Color.primary.opacity(0.1), lineWidth: 2)
                                        .background(Color(UIColor.secondarySystemGroupedBackground).opacity(0.6).clipShape(RoundedRectangle(cornerRadius: 12)))
                                        .frame(height: 55)
                                    
                                    if index < code.count {
                                        let charIndex = code.index(code.startIndex, offsetBy: index)
                                        Text(String(code[charIndex])).font(.title2).bold()
                                    }
                                }
                            }
                        }
                        
                        TextField("", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .foregroundColor(.clear)
                            .accentColor(.clear)
                            .tint(.clear)
                            .background(Color.white.opacity(0.001))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .focused($focusedField, equals: .code)
                            .onChange(of: code) { newValue in
                                let filtered = newValue.filter { $0.isNumber }
                                if filtered != newValue { code = filtered }
                                if code.count > 6 { code = String(code.prefix(6)) }
                                if code.count == 6 { verifyCode() }
                            }
                    }
                    .frame(height: 55)
                    .onTapGesture { focusedField = .code }
                }
            }.padding(.horizontal, 35).offset(y: animateIn ? 0 : 15)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(isSuccessMessage ? .green : .red)
                    .font(.caption).padding(.horizontal).multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            VStack(spacing: 16) {
                Button(action: {
                    Haptic.impact(.medium)
                    if !isCodeSent { requestCode() }
                    else { verifyCode() }
                }) {
                    Group {
                        if isLoading { ProgressView().tint(.primary) }
                        else { Text(isCodeSent ? "Verify & Sign In" : "Send Code").font(.headline).foregroundColor(.primary) }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(.ultraThinMaterial).cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                }
                .padding(.horizontal, 35).disabled((!isCodeSent && email.isEmpty) || (isCodeSent && code.isEmpty) || isLoading)

                if isCodeSent {
                    Button(action: {
                        Haptic.impact(.light); errorMessage = ""; isSuccessMessage = false
                        withAnimation(.easeInOut(duration: 0.3)) { isCodeSent = false; code = "" }
                    }) {
                        Text("Change email address")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                } else {
                    Button(action: {
                        Haptic.impact(.medium)
                        signInAsGuest()
                    }) {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.questionmark.fill")
                            Text("Chat as Guest")
                        }
                        .font(.headline).foregroundColor(.primary)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    }
                    .padding(.horizontal, 35).disabled(isLoading)
                }
            }.offset(y: animateIn ? 0 : 20)
            
            HStack(spacing: 4) {
                Link("Terms of Service", destination: URL(string: "https://namgostar.com/wp-content/uploads/2026/02/terms.html")!)
                Text("·").foregroundColor(.secondary)
                Link("Privacy Policy", destination: URL(string: "https://namgostar.com/wp-content/uploads/2026/02/privacy.html")!)
            }
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(.secondary.opacity(0.7))
            .offset(y: animateIn ? 0 : 20)
            
            Spacer()
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
        .onAppear { withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.2)) { animateIn = true } }
    }

    func requestCode() {
        guard !email.isEmpty else { return }
        
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if !isValidEmail(trimmed) {
            Haptic.notification(.warning)
            self.errorMessage = "Please enter a valid email address."
            return
        }
        
        focusedField = nil; isLoading = true; errorMessage = ""; isSuccessMessage = false
        
        guard let url = URL(string: "\(AppConfig.serverURL)/auth/request-code") else { return }
        var r = URLRequest(url: url); r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["email": trimmed])
        
        URLSession.shared.dataTask(with: r) { d, res, err in
            DispatchQueue.main.async {
                self.isLoading = false
                if let err = err {
                    Haptic.notification(.error); self.errorMessage = "Network error: \(err.localizedDescription)"
                    return
                }
                if let http = res as? HTTPURLResponse, http.statusCode != 200 {
                    Haptic.notification(.error)
                    if let d = d, let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let errorMsg = json["error"] as? String {
                        self.errorMessage = errorMsg
                    } else {
                        self.errorMessage = "Failed to send code (Status \(http.statusCode))"
                    }
                    return
                }
                Haptic.notification(.success)
                withAnimation { self.isCodeSent = true; self.focusedField = .code }
                self.isSuccessMessage = true
                self.errorMessage = "Code sent! Check your messages or server console."
            }
        }.resume()
    }
    
    struct VerifyCodeResponse: Codable {
        let customToken: String
        let email: String
        let uid: String
        let nickname: String?
        let isNewUser: Bool
    }

    func verifyCode() {
        guard !code.isEmpty else { return }
        guard !isLoading else { return } 
        
        focusedField = nil; isLoading = true; errorMessage = ""; isSuccessMessage = false
        
        guard let url = URL(string: "\(AppConfig.serverURL)/auth/verify-code") else {
            isLoading = false
            return
        }
        var r = URLRequest(url: url); r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["email": email, "code": code])
        
        URLSession.shared.dataTask(with: r) { d, res, error in
            if let error = error {
                DispatchQueue.main.async { self.isLoading = false; Haptic.notification(.error); self.errorMessage = "Network error: \(error.localizedDescription)" }
                return
            }
            
            guard let d = d else {
                DispatchQueue.main.async { self.isLoading = false; Haptic.notification(.error); self.errorMessage = "Empty server response." }
                return
            }
            
            if let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let errorMsg = json["error"] as? String {
                DispatchQueue.main.async { self.isLoading = false; Haptic.notification(.error); self.errorMessage = errorMsg }
                return
            }
            
            guard let verifyRes = try? JSONDecoder().decode(VerifyCodeResponse.self, from: d) else {
                DispatchQueue.main.async { self.isLoading = false; Haptic.notification(.error); self.errorMessage = "Invalid response payload from server." }
                return
            }
            
            self.exchangeCustomTokenForIdToken(customToken: verifyRes.customToken, email: verifyRes.email, nickname: verifyRes.nickname, isNewUser: verifyRes.isNewUser)
            
        }.resume()
    }
    
    func exchangeCustomTokenForIdToken(customToken: String, email: String, nickname: String?, isNewUser: Bool) {
        guard let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=\(AppConfig.apiKey)") else {
            isLoading = false
            return
        }
        var r = URLRequest(url: url); r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["token": customToken, "returnSecureToken": true])
        
        URLSession.shared.dataTask(with: r) { d, _, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    Haptic.notification(.error); self.errorMessage = "Exchange error: \(error.localizedDescription)"
                    return
                }
                guard let d = d else {
                    Haptic.notification(.error); self.errorMessage = "Failed to sign in securely (no data)."
                    return
                }
                
                let auth: AuthResponse
                do {
                    auth = try JSONDecoder().decode(AuthResponse.self, from: d)
                } catch {
                    let raw = String(data: d, encoding: .utf8) ?? "unknown"
                    Haptic.notification(.error)
                    self.errorMessage = "Decoding Error: \(error.localizedDescription)\nPayload: \(raw)"
                    return
                }
                
                self.currentUserEmail = email
                self.idToken = auth.idToken
                UserDefaults.standard.set(auth.refreshToken, forKey: "refreshToken")
                
                if let nn = nickname, !nn.isEmpty, !isNewUser {
                    UserDefaults.standard.set(nn, forKey: "userNickname")
                    UserDefaults.standard.set(false, forKey: "needsNickname")
                } else {
                    UserDefaults.standard.set(true, forKey: "needsNickname")
                }
                
                CryptoManager.shared.generateKeyPairIfNeeded()
                CryptoManager.shared.uploadPublicKey()
                
                Haptic.notification(.success)
                
                if email.lowercased() == AppConfig.adminEmail.lowercased() || auth.email?.lowercased() == AppConfig.adminEmail.lowercased() { 
                    self.isGodMode = true 
                } else { 
                    self.isLoggedIn = true 
                }
            }
        }.resume()
    }
    
    struct GuestAuthResponse: Codable {
        let customToken: String
        let uid: String
    }
    
    func signInAsGuest() {
        guard !isLoading else { return }
        focusedField = nil; isLoading = true; errorMessage = ""; isSuccessMessage = false
        
        guard let url = URL(string: "\(AppConfig.serverURL)/auth/guest") else {
            isLoading = false
            return
        }
        var r = URLRequest(url: url)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: r) { d, res, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    Haptic.notification(.error); self.errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                guard let d = d else {
                    Haptic.notification(.error); self.errorMessage = "Empty server response."
                    return
                }
                
                if let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let errorMsg = json["error"] as? String {
                    Haptic.notification(.error); self.errorMessage = errorMsg
                    return
                }
                
                let guestRes: GuestAuthResponse
                do {
                    guestRes = try JSONDecoder().decode(GuestAuthResponse.self, from: d)
                } catch {
                    let raw = String(data: d, encoding: .utf8) ?? "unknown"
                    Haptic.notification(.error)
                    self.errorMessage = "Decoding Error: \(error.localizedDescription)\nPayload: \(raw)"
                    return
                }
                
                UserDefaults.standard.set(true, forKey: "isGuestMode")
                
                self.exchangeCustomTokenForIdToken(
                    customToken: guestRes.customToken, 
                    email: guestRes.uid, 
                    nickname: nil, 
                    isNewUser: true
                )
            }
        }.resume()
    }
}
