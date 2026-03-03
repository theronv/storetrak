import SwiftUI

struct ItemDetailSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let item: Item

    @State private var name: String
    @State private var category: String
    @State private var qty: Int
    @State private var value: String
    @State private var make: String
    @State private var model: String
    @State private var year: String
    @State private var serial: String
    @State private var notes: String
    @State private var imageUrl: String
    @State private var toteId: String
    @State private var isSaving = false

    init(item: Item) {
        self.item = item
        _name = State(initialValue: item.name)
        _category = State(initialValue: item.category)
        _qty = State(initialValue: item.qty)
        _value = State(initialValue: item.value.map { String($0) } ?? "")
        _make = State(initialValue: item.make ?? "")
        _model = State(initialValue: item.model ?? "")
        _year = State(initialValue: item.year ?? "")
        _serial = State(initialValue: item.serial ?? "")
        _notes = State(initialValue: item.notes ?? "")
        _imageUrl = State(initialValue: item.image_url ?? "")
        _toteId = State(initialValue: item.tote_id ?? "")
    }

    var body: some View {
        ZStack {
            Color.surface.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Capsule().fill(Color.borderBright).frame(width: 36, height: 4).frame(maxWidth: .infinity)
                        .padding(.top, 6)

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(item.name)
                            .font(.system(size: 17, weight: .bold)).tracking(2).textCase(.uppercase)
                            .foregroundColor(.accent)

                        Menu {
                            ForEach(CATS_ORDER, id: \.self) { key in
                                Button {
                                    category = key
                                } label: {
                                    Text(CATS[key]?.label ?? key)
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(CATS[category]?.color ?? CATS["other"]!.color)
                                    .frame(width: 7, height: 7)
                                Text((CATS[category]?.label ?? category).uppercased())
                                    .font(.system(size: 9, design: .monospaced))
                                    .tracking(1.5)
                                    .foregroundColor(.textMuted)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8))
                                    .foregroundColor(.textDim)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((CATS[category]?.color ?? CATS["other"]!.color).opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke((CATS[category]?.color ?? CATS["other"]!.color).opacity(0.35), lineWidth: 1)
                            )
                            .cornerRadius(4)
                        }
                    }
                    .padding(.bottom, 4)

                    FieldView(label: "Item Name") {
                        TextField("e.g. DeWalt Drill", text: $name).stField()
                    }

                    HStack(spacing: 10) {
                        FieldView(label: "Category") {
                            Picker("", selection: $category) {
                                ForEach(CATS_ORDER, id: \.self) { k in
                                    Text(CATS[k]?.label ?? k).tag(k)
                                }
                            }
                            .pickerStyle(.menu).tint(.textPrimary)
                            .frame(maxWidth: .infinity).padding(11)
                            .background(Color.bg)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.border, lineWidth: 1))
                            .cornerRadius(8)
                        }
                        FieldView(label: "Value ($)") {
                            TextField("0.00", text: $value).stField().keyboardType(.decimalPad)
                        }
                        FieldView(label: "QTY") {
                            HStack {
                                Button("-") { if qty > 1 { qty -= 1 } }
                                    .foregroundColor(.accent).font(.system(size: 18, weight: .bold))
                                Spacer()
                                Text("\(qty)").font(.system(size: 15, design: .monospaced)).foregroundColor(.textPrimary)
                                Spacer()
                                Button("+") { qty += 1 }
                                    .foregroundColor(.accent).font(.system(size: 18, weight: .bold))
                            }
                            .padding(11).background(Color.bg)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.border, lineWidth: 1))
                            .cornerRadius(8)
                        }
                    }

                    HStack(spacing: 10) {
                        FieldView(label: "Make / Brand") {
                            TextField("e.g. DeWalt", text: $make).stField()
                        }
                        FieldView(label: "Model") {
                            TextField("e.g. DCD777", text: $model).stField()
                        }
                    }

                    HStack(spacing: 10) {
                        FieldView(label: "Year") {
                            TextField("e.g. 2021", text: $year).stField().keyboardType(.numberPad)
                        }
                        FieldView(label: "Serial / ID") {
                            TextField("Optional", text: $serial).stField()
                        }
                    }

                    FieldView(label: "Notes") {
                        TextEditor(text: $notes)
                            .frame(minHeight: 70)
                            .padding(11).background(Color.bg)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.border, lineWidth: 1))
                            .cornerRadius(8)
                            .foregroundColor(.textPrimary)
                    }

                    FieldView(label: "Image URL") {
                        TextField("Paste image URL...", text: $imageUrl).stField()
                    }

                    if let url = URL(string: imageUrl), !imageUrl.isEmpty {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFit()
                                .frame(maxHeight: 160)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.border, lineWidth: 1))
                        } placeholder: { ProgressView().tint(.accent) }
                    }

                    Divider().background(Color.border)

                    Text("LOCATION")
                        .font(.system(size: 10, design: .monospaced)).foregroundColor(.textMuted).tracking(1)

                    FieldView(label: "Current Tote") {
                        Picker("", selection: $toteId) {
                            Text("— Inbox (unsorted) —").tag("")
                            ForEach(appState.totes) { tote in
                                Text("\(tote.id) — \(tote.displayName)").tag(tote.id)
                            }
                        }
                        .pickerStyle(.menu).tint(.textPrimary)
                        .frame(maxWidth: .infinity).padding(11)
                        .background(Color.bg)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.border, lineWidth: 1))
                        .cornerRadius(8)
                    }

                    HStack(spacing: 8) {
                        Button("Delete") {
                            Task {
                                await appState.deleteItem(item.id)
                                dismiss()
                            }
                        }
                        .buttonStyle(StButtonStyle(variant: .danger))

                        Button("Cancel") { dismiss() }
                            .buttonStyle(StButtonStyle(variant: .ghost))

                        Button(isSaving ? "..." : "Save") {
                            Task { await save() }
                        }
                        .buttonStyle(StButtonStyle(variant: .primary))
                        .disabled(isSaving)
                    }
                    .padding(.top, 6)
                }
                .padding(18)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    func save() async {
        guard !name.isEmpty else { appState.showToast("Item name required", type: .error); return }
        isSaving = true
        var updated = item
        updated.name = name
        updated.category = category
        updated.qty = qty
        updated.value = Double(value)
        updated.make = make.isEmpty ? nil : make
        updated.model = model.isEmpty ? nil : model
        updated.year = year.isEmpty ? nil : year
        updated.serial = serial.isEmpty ? nil : serial
        updated.notes = notes.isEmpty ? nil : notes
        updated.image_url = imageUrl.isEmpty ? nil : imageUrl
        updated.tote_id = toteId.isEmpty ? nil : toteId
        await appState.saveItem(updated)
        isSaving = false
        dismiss()
    }
}

struct FieldView<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            StLabel(text: label)
            content()
        }
    }
}

enum StButtonVariant { case primary, ghost, danger }

struct StButtonStyle: ButtonStyle {
    let variant: StButtonVariant
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold)).tracking(1).textCase(.uppercase)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(bg(configuration.isPressed))
            .foregroundColor(fg)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(border, lineWidth: 1))
            .cornerRadius(8)
    }
    func bg(_ pressed: Bool) -> Color {
        switch variant {
        case .primary: return pressed ? Color(hex: "d48f00") : .accent
        case .ghost: return Color.surface2
        case .danger: return Color.danger.opacity(0.12)
        }
    }
    var fg: Color {
        switch variant {
        case .primary: return .black
        case .ghost: return .textMuted
        case .danger: return .danger
        }
    }
    var border: Color {
        switch variant {
        case .primary: return .clear
        case .ghost: return .border
        case .danger: return Color.danger.opacity(0.25)
        }
    }
}
