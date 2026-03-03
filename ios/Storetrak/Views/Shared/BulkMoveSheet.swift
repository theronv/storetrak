import SwiftUI

struct BulkMoveSheet: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    @State private var destToteId = ""
    @State private var isMoving = false

    var body: some View {
        ZStack { Color.surface.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Capsule().fill(Color.borderBright).frame(width: 36, height: 4).frame(maxWidth: .infinity)
                    .padding(.top, 8).padding(.bottom, 16)

                Text("Bulk Move").font(.system(size: 17, weight: .bold)).tracking(2).textCase(.uppercase)
                    .foregroundColor(.accent).padding(.bottom, 12)

                let count = appState.selectedInboxIds.count
                Text("Moving \(count) item\(count == 1 ? "" : "s") to:")
                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.textMuted).padding(.bottom, 12)

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
                    Button(isMoving ? "..." : "Move All →") {
                        Task { await move() }
                    }
                    .buttonStyle(StButtonStyle(variant: .primary)).disabled(isMoving || destToteId.isEmpty)
                }
                .padding(.top, 18)
                Spacer()
            }
            .padding(18)
        }
        .presentationDetents([.medium])
    }

    func move() async {
        guard !destToteId.isEmpty else { appState.showToast("Select a destination", type: .error); return }
        isMoving = true
        await appState.moveItems(Array(appState.selectedInboxIds), to: destToteId)
        isMoving = false
        isPresented = false
    }
}
