import SwiftUI

struct MoveItemSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let item: Item
    @Binding var isPresented: Bool
    @State private var destToteId: String
    @State private var isMoving = false

    init(item: Item, isPresented: Binding<Bool>) {
        self.item = item
        _isPresented = isPresented
        _destToteId = State(initialValue: item.tote_id ?? "")
    }

    var body: some View {
        ZStack { Color.surface.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Capsule().fill(Color.borderBright).frame(width: 36, height: 4).frame(maxWidth: .infinity)
                    .padding(.top, 8).padding(.bottom, 16)

                Text("Move Item").font(.system(size: 17, weight: .bold)).tracking(2).textCase(.uppercase)
                    .foregroundColor(.accent).padding(.bottom, 12)

                Text(item.name)
                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.textMuted)
                    .padding(.bottom, 12)

                FieldView(label: "Destination Tote") {
                    Picker("", selection: $destToteId) {
                        Text("— Inbox (unsorted) —").tag("")
                        ForEach(appState.totes) { t in
                            Text("\(t.id) — \(t.displayName)").tag(t.id)
                        }
                    }
                    .pickerStyle(.menu).tint(.textPrimary)
                    .frame(maxWidth: .infinity).padding(11).background(Color.bg)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.border, lineWidth: 1)).cornerRadius(8)
                }

                HStack(spacing: 8) {
                    Button("Cancel") { isPresented = false }
                        .buttonStyle(StButtonStyle(variant: .ghost))
                    Button(isMoving ? "..." : "Move →") {
                        Task { await move() }
                    }
                    .buttonStyle(StButtonStyle(variant: .primary)).disabled(isMoving)
                }
                .padding(.top, 18)
                Spacer()
            }
            .padding(18)
        }
        .presentationDetents([.medium])
    }

    func move() async {
        isMoving = true
        let dest = destToteId.isEmpty ? nil : destToteId
        await appState.moveItems([item.id], to: dest)
        isMoving = false
        isPresented = false
    }
}
