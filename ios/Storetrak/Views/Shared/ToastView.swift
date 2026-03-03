import SwiftUI

struct ToastView: View {
    let message: ToastMessage

    var body: some View {
        Text(message.text)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.surface3)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color, lineWidth: 1)
            )
            .cornerRadius(10)
    }

    var color: Color {
        switch message.type {
        case .success: return .success
        case .error: return .danger
        case .info: return .textMuted
        }
    }
}
