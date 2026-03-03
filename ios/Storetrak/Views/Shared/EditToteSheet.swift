import SwiftUI

struct EditToteSheet: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool

    let tote: Tote
    @State private var name: String
    @State private var shelf: String
    @State private var roomId: String
    @State private var isSaving = false

    init(tote: Tote, isPresented: Binding<Bool>) {
        self.tote = tote
        _isPresented = isPresented
        _name = State(initialValue: tote.name ?? "")
        _shelf = State(initialValue: tote.shelf ?? "")
        _roomId = State(initialValue: tote.room_id ?? "")
    }

    var body: some View {
        ZStack { Color.surface.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Capsule().fill(Color.borderBright).frame(width: 36, height: 4).frame(maxWidth: .infinity)
                    .padding(.top, 8).padding(.bottom, 16)

                Text("Edit Tote").font(.system(size: 17, weight: .bold)).tracking(2).textCase(.uppercase)
                    .foregroundColor(.accent).padding(.bottom, 16)

                FieldView(label: "Tote Name") {
                    TextField("", text: $name).stField()
                }
                .padding(.bottom, 12)

                FieldView(label: "Shelf / Location") {
                    TextField("Shelf 2, Top shelf…", text: $shelf).stField()
                }
                .padding(.bottom, 12)

                FieldView(label: "Move to Room") {
                    Picker("", selection: $roomId) {
                        ForEach(appState.rooms) { r in
                            Text("\(r.name) (\(r.code))").tag(r.id)
                        }
                    }
                    .pickerStyle(.menu).tint(.textPrimary)
                    .frame(maxWidth: .infinity).padding(11).background(Color.bg)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.border, lineWidth: 1)).cornerRadius(8)
                }

                Divider().background(Color.border).padding(.vertical, 12)

                HStack(spacing: 8) {
                    Button("Delete Tote") {
                        Task { await appState.deleteTote(tote.id); isPresented = false }
                    }
                    .buttonStyle(StButtonStyle(variant: .danger))

                    Button("Cancel") { isPresented = false }
                        .buttonStyle(StButtonStyle(variant: .ghost))

                    Button(isSaving ? "..." : "Save") { Task { await save() } }
                        .buttonStyle(StButtonStyle(variant: .primary)).disabled(isSaving)
                }
                .padding(.top, 6)
                Spacer()
            }
            .padding(18)
        }
        .presentationDetents([.medium, .large])
    }

    func save() async {
        guard !name.isEmpty else { appState.showToast("Name required", type: .error); return }
        isSaving = true
        var updated = tote
        updated.name = name
        updated.shelf = shelf.isEmpty ? nil : shelf
        updated.room_id = roomId.isEmpty ? nil : roomId
        await appState.saveTote(updated)
        isSaving = false
        isPresented = false
    }
}
