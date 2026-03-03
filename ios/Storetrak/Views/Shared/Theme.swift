import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }

    static let bg           = Color(hex: "0f0f0f")
    static let surface      = Color(hex: "181818")
    static let surface2     = Color(hex: "222222")
    static let surface3     = Color(hex: "2a2a2a")
    static let border       = Color(hex: "2e2e2e")
    static let borderBright = Color(hex: "484848")
    static let accent       = Color(hex: "f0a500")
    static let accentDim    = Color(hex: "f0a500").opacity(0.13)
    static let textPrimary  = Color(hex: "ece8e0")
    static let textMuted    = Color(hex: "787878")
    static let textDim      = Color(hex: "444444")
    static let success      = Color(hex: "4caf78")
    static let danger       = Color(hex: "c95c5c")
}

let CATS: [String: (label: String, color: Color)] = [
    "tools":       ("Tools",       Color(hex: "e05c00")),
    "electronics": ("Electronics", Color(hex: "4a9eff")),
    "cables":      ("Cables",      Color(hex: "7c4aff")),
    "hardware":    ("Hardware",    Color(hex: "aaaaaa")),
    "craft":       ("Craft",       Color(hex: "e04aaa")),
    "seasonal":    ("Seasonal",    Color(hex: "4caf78")),
    "clothing":    ("Clothing",    Color(hex: "c89b4a")),
    "other":       ("Other",       Color(hex: "555555")),
]
let CATS_ORDER = ["tools","electronics","cables","hardware","craft","seasonal","clothing","other"]

struct StField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(11)
            .background(Color.bg)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.border, lineWidth: 1))
            .foregroundColor(.textPrimary)
            .font(.system(size: 15))
    }
}

extension View {
    func stField() -> some View { modifier(StField()) }
}

struct StLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor(.textMuted)
            .tracking(1.5)
    }
}

struct CategoryPickerButton: View {
    @Binding var selection: String

    var body: some View {
        Menu {
            ForEach(CATS_ORDER, id: \.self) { key in
                Button { selection = key } label: {
                    Text(CATS[key]?.label ?? key)
                }
            }
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(CATS[selection]?.color ?? CATS["other"]!.color)
                    .frame(width: 7, height: 7)
                Text(CATS[selection]?.label ?? selection)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundColor(.textPrimary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(Color.bg)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.border, lineWidth: 1))
            .cornerRadius(6)
        }
    }
}

struct ToteBadge: View {
    let id: String
    var body: some View {
        Text(id)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(.accent)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.accent.opacity(0.13))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.accent.opacity(0.32), lineWidth: 1))
            .cornerRadius(4)
    }
}
