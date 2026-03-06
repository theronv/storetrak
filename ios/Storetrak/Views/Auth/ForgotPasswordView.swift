import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .requestCode
    @State private var email = ""
    @State private var code = ""
    @State private var newPassword = ""
    @State private var errorMsg = ""
    @State private var isLoading = false

    enum Step { case requestCode, enterCode }

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

                    Text(step == .requestCode ? "Reset Password" : "Enter Reset Code")
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

                    if step == .requestCode {
                        VStack(alignment: .leading, spacing: 5) {
                            StLabel(text: "Email")
                            TextField("you@example.com", text: $email)
                                .stField()
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .textContentType(.emailAddress)
                                .submitLabel(.done)
                                .onSubmit { Task { await requestCode() } }
                        }
                        .padding(.bottom, 16)

                        Button(action: { Task { await requestCode() } }) {
                            if isLoading {
                                ProgressView().tint(.black).frame(maxWidth: .infinity, minHeight: 42)
                            } else {
                                Text("Send Reset Code")
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

                    } else {
                        VStack(alignment: .leading, spacing: 5) {
                            StLabel(text: "Reset Code")
                            TextField("e.g. A3F9B2C1", text: $code)
                                .stField()
                                .autocapitalization(.allCharacters)
                                .autocorrectionDisabled()
                                .submitLabel(.next)
                        }
                        .padding(.bottom, 12)

                        VStack(alignment: .leading, spacing: 5) {
                            StLabel(text: "New Password")
                            SecureField("Min 8 characters", text: $newPassword)
                                .stField()
                                .textContentType(.newPassword)
                                .submitLabel(.done)
                                .onSubmit { Task { await resetPassword() } }
                        }
                        .padding(.bottom, 16)

                        Button(action: { Task { await resetPassword() } }) {
                            if isLoading {
                                ProgressView().tint(.black).frame(maxWidth: .infinity, minHeight: 42)
                            } else {
                                Text("Reset Password")
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
                    }

                    HStack {
                        Spacer()
                        Button(step == .requestCode ? "Back to Sign In" : "Resend Code") {
                            if step == .requestCode { dismiss() } else { step = .requestCode; errorMsg = "" }
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
    }

    func requestCode() async {
        errorMsg = ""
        guard !email.isEmpty else { errorMsg = "Email required"; return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await APIClient.forgotPassword(email: email)
            step = .enterCode
        } catch {
            // Always move to next step — server never reveals if email exists
            step = .enterCode
        }
    }

    func resetPassword() async {
        errorMsg = ""
        guard !code.isEmpty, !newPassword.isEmpty else { errorMsg = "Code and new password required"; return }
        guard newPassword.count >= 8 else { errorMsg = "Password must be at least 8 characters"; return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await APIClient.resetPassword(email: email, token: code.lowercased(), password: newPassword)
            // Auto sign-in
            let token = try await APIClient.login(email: email, password: newPassword)
            AuthManager.shared.save(token: token)
            dismiss()
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}
