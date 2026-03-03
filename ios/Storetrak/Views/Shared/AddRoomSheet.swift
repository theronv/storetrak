import SwiftUI

struct AddRoomSheet: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var code = ""
    @State private var isAdding = false

    var body: some View {
        ZStack { Color.surface.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Capsule().fill(Color.borderBright).frame(width: 36, height: 4).frame(maxWidth: .infinity)
                    .padding(.top, 8).padding(.bottom, 16)

                Text("Add Room").font(.system(size: 17, weight: .bold)).tracking(2).textCase(.uppercase)
                    .foregroundColor(.accent).padding(.bottom, 16)

                FieldView(label: "Room Name") {
                    TextField("Garage, Basement, Attic…", text: $name).stField()
                        .submitLabel(.next)
                }
                .padding(.bottom, 12)

                FieldView(label: "Short Code (3–4 letters)") {
                    TextField("GAR, BSM, ATT…", text: $code)
                        .stField()
                        .textInputAutocapitalization(.characters)
                        .onChange(of: code) { _, v in code = String(v.uppercased().prefix(4)) }
                        .submitLabel(.done)
                        .onSubmit { Task { await submit() } }
                }

                Text("Used to generate IDs like GAR-01")
                    .font(.system(size: 11)).foregroundColor(.textDim).padding(.top, 4).padding(.bottom, 12)

                HStack(spacing: 8) {
                    Button("Cancel") { isPresented = false }
                        .buttonStyle(StButtonStyle(variant: .ghost))
                    Button(isAdding ? "..." : "Add Room") { Task { await submit() } }
                        .buttonStyle(StButtonStyle(variant: .primary)).disabled(isAdding)
                }
                Spacer()
            }
            .padding(18)
        }
        .presentationDetents([.medium])
    }

    func submit() async {
        let n = name.trimmingCharacters(in: .whitespaces)
        let c = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard !n.isEmpty, !c.isEmpty else { appState.showToast("Fill in both fields", type: .error); return }
        if appState.rooms.contains(where: { $0.code == c }) {
            appState.showToast("Code already in use", type: .error); return
        }
        isAdding = true
        await appState.addRoom(name: n, code: c)
        isAdding = false
        isPresented = false
    }
}
