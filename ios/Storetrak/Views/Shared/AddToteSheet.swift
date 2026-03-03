import SwiftUI

struct AddToteSheet: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    @State private var roomId = ""
    @State private var toteName = ""
    @State private var shelf = ""
    @State private var isAdding = false

    var toteIdPreview: String {
        guard let room = appState.rooms.first(where: { $0.id == roomId }) else {
            return "Select a room to preview ID"
        }
        return "ID: \(room.code)-\(appState.nextToteNum(roomId: roomId))"
    }

    var body: some View {
        ZStack { Color.surface.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Capsule().fill(Color.borderBright).frame(width: 36, height: 4).frame(maxWidth: .infinity)
                    .padding(.top, 8).padding(.bottom, 16)

                Text("New Tote").font(.system(size: 17, weight: .bold)).tracking(2).textCase(.uppercase)
                    .foregroundColor(.accent).padding(.bottom, 16)

                if appState.rooms.isEmpty {
                    Text("Add a room first before creating totes.")
                        .font(.system(size: 14)).foregroundColor(.textMuted)
                    Button("Cancel") { isPresented = false }
                        .buttonStyle(StButtonStyle(variant: .ghost)).padding(.top, 12)
                } else {
                    FieldView(label: "Room") {
                        Picker("", selection: $roomId) {
                            Text("Select a room…").tag("")
                            ForEach(appState.rooms) { r in
                                Text("\(r.name) (\(r.code))").tag(r.id)
                            }
                        }
                        .pickerStyle(.menu).tint(.textPrimary)
                        .frame(maxWidth: .infinity).padding(11).background(Color.bg)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.border, lineWidth: 1)).cornerRadius(8)
                        .onAppear { if roomId.isEmpty, let first = appState.rooms.first { roomId = first.id } }
                    }
                    .padding(.bottom, 12)

                    FieldView(label: "Tote Name (optional)") {
                        TextField("Power Tools, Holiday Decor…", text: $toteName).stField()
                    }
                    .padding(.bottom, 12)

                    FieldView(label: "Shelf / Location") {
                        TextField("Shelf 2, Top shelf…", text: $shelf).stField()
                            .submitLabel(.done).onSubmit { Task { await submit() } }
                    }
                    .padding(.bottom, 12)

                    Text(toteIdPreview)
                        .font(.system(size: 12, design: .monospaced)).foregroundColor(.accent)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(Color.accent.opacity(0.13))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.accent.opacity(0.32), lineWidth: 1))
                        .cornerRadius(7).padding(.bottom, 12)

                    HStack(spacing: 8) {
                        Button("Cancel") { isPresented = false }
                            .buttonStyle(StButtonStyle(variant: .ghost))
                        Button(isAdding ? "..." : "Create Tote") { Task { await submit() } }
                            .buttonStyle(StButtonStyle(variant: .primary)).disabled(isAdding || roomId.isEmpty)
                    }
                }
                Spacer()
            }
            .padding(18)
        }
        .presentationDetents([.medium, .large])
    }

    func submit() async {
        guard let room = appState.rooms.first(where: { $0.id == roomId }) else {
            appState.showToast("Select a room", type: .error); return
        }
        let toteId = "\(room.code)-\(appState.nextToteNum(roomId: roomId))"
        let name = toteName.trimmingCharacters(in: .whitespaces).isEmpty ? toteId : toteName.trimmingCharacters(in: .whitespaces)
        isAdding = true
        await appState.addTote(id: toteId, roomId: roomId, name: name, shelf: shelf.isEmpty ? nil : shelf)
        isAdding = false
        isPresented = false
    }
}
