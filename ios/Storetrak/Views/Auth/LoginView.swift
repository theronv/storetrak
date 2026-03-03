import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var isRegister = false
    @State private var errorMsg = ""
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 0) {
                    Text("STRTRAK")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.accent)
                        .tracking(4)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 22)

                    Text(isRegister ? "Create Account" : "Sign In")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.textMuted)
                        .tracking(2)
                        .textCase(.uppercase)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 20)

                    if !errorMsg.isEmpty {
                        Text(errorMsg)
                            .font(.system(size: 13))
                            .foregroundColor(.danger)
                            .padding(9)
                            .frame(maxWidth: .infinity)
                            .background(Color.danger.opacity(0.12))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.danger.opacity(0.3), lineWidth: 1))
                            .cornerRadius(7)
                            .padding(.bottom, 12)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        StLabel(text: "Email")
                        TextField("you@example.com", text: $email)
                            .stField()
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .textContentType(.emailAddress)
                            .submitLabel(.next)
                    }
                    .padding(.bottom, 12)

                    VStack(alignment: .leading, spacing: 5) {
                        StLabel(text: "Password")
                        SecureField("••••••••", text: $password)
                            .stField()
                            .textContentType(isRegister ? .newPassword : .password)
                            .submitLabel(.done)
                            .onSubmit { Task { await submit() } }
                    }
                    .padding(.bottom, 16)

                    Button(action: { Task { await submit() } }) {
                        if isLoading {
                            ProgressView().tint(.black).frame(maxWidth: .infinity, minHeight: 42)
                        } else {
                            Text(isRegister ? "Register" : "Sign In")
                                .font(.system(size: 13, weight: .bold))
                                .tracking(1)
                                .textCase(.uppercase)
                                .frame(maxWidth: .infinity, minHeight: 42)
                        }
                    }
                    .background(Color.accent)
                    .foregroundColor(.black)
                    .cornerRadius(8)
                    .disabled(isLoading)

                    HStack {
                        Spacer()
                        Text(isRegister ? "Already have an account? " : "Don't have an account? ")
                            .font(.system(size: 12))
                            .foregroundColor(.textMuted)
                        Button(isRegister ? "Sign In" : "Register") {
                            isRegister.toggle()
                            errorMsg = ""
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.accent)
                        Spacer()
                    }
                    .padding(.top, 14)
                }
                .padding(24)
                .background(Color.surface)
                .overlay(
                    VStack {
                        Rectangle().fill(Color.accent).frame(height: 2)
                        Spacer()
                    }
                )
                .cornerRadius(12)
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .toast($appState.toast)
    }

    func submit() async {
        errorMsg = ""
        guard !email.isEmpty, !password.isEmpty else {
            errorMsg = "Email and password required"; return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let token = isRegister
                ? try await APIClient.register(email: email, password: password)
                : try await APIClient.login(email: email, password: password)
            AuthManager.shared.save(token: token)
            appState.isLoggedIn = true
            await appState.loadAll()
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}
