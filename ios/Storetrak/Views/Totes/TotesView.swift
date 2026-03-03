import SwiftUI

struct TotesView: View {
    @EnvironmentObject var appState: AppState
    @State private var roomFilter: String? = nil  // nil = all
    @State private var searchQuery = ""
    @State private var editingTote: Tote? = nil
    @State private var selectedItem: Item? = nil
    @State private var showMoveSheet: String? = nil
    @State private var showAddTote = false

    var filteredTotes: [Tote] {
        if let r = roomFilter { return appState.totes.filter { $0.room_id == r } }
        return appState.totes
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Room filter strip
                    if !appState.rooms.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                RoomChip(label: "All", count: appState.totes.count, isActive: roomFilter == nil) {
                                    roomFilter = nil
                                }
                                ForEach(appState.rooms) { room in
                                    let cnt = appState.totes.filter { $0.room_id == room.id }.count
                                    RoomChip(label: room.name, count: cnt, isActive: roomFilter == room.id) {
                                        roomFilter = room.id
                                    }
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                        }
                        .background(Color.bg)
                    }

                    ScrollView {
                        VStack(spacing: 10) {
                            if appState.rooms.isEmpty {
                                EmptyStateView(icon: "🏠", title: "No Rooms Yet", subtitle: "Go to Rooms tab to add your first room.")
                            } else if filteredTotes.isEmpty {
                                EmptyStateView(icon: "📦", title: "No Totes", subtitle: "Tap + to create a tote.")
                            } else {
                                ForEach(filteredTotes) { tote in
                                    ToteCard(
                                        tote: tote,
                                        onEditTote: { editingTote = tote },
                                        onOpenItem: { selectedItem = $0 },
                                        onMoveItem: { showMoveSheet = $0 }
                                    )
                                }
                            }
                        }
                        .padding(14)
                    }
                    .refreshable { await appState.loadAll() }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Totes")
                        .font(.system(size: 22, weight: .bold))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundColor(.textPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddTote = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(.accent)
                            .font(.system(size: 18, weight: .medium))
                    }
                }
            }
        }
        .sheet(item: $editingTote) { tote in
            EditToteSheet(tote: tote, isPresented: Binding(
                get: { editingTote != nil },
                set: { if !$0 { editingTote = nil } }
            ))
            .environmentObject(appState)
        }
        .sheet(item: $selectedItem) { item in
            ItemDetailSheet(item: item)
                .environmentObject(appState)
        }
        .sheet(isPresented: Binding(
            get: { showMoveSheet != nil },
            set: { if !$0 { showMoveSheet = nil } }
        )) {
            if let id = showMoveSheet, let item = appState.items.first(where: { $0.id == id }) {
                MoveItemSheet(item: item, isPresented: Binding(
                    get: { showMoveSheet != nil },
                    set: { if !$0 { showMoveSheet = nil } }
                ))
                .environmentObject(appState)
            }
        }
        .sheet(isPresented: $showAddTote) {
            AddToteSheet(isPresented: $showAddTote)
                .environmentObject(appState)
        }
    }
}

struct RoomChip: View {
    let label: String
    let count: Int
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(label).font(.system(size: 12, weight: .medium))
                Text("\(count)")
                    .font(.system(size: 9, design: .monospaced))
                    .opacity(0.65)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(isActive ? Color.accent : Color.surface)
            .foregroundColor(isActive ? .black : .textPrimary)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isActive ? Color.accent : Color.border, lineWidth: 1)
            )
            .cornerRadius(20)
        }
    }
}

struct ToteCard: View {
    @EnvironmentObject var appState: AppState
    let tote: Tote
    let onEditTote: () -> Void
    let onOpenItem: (Item) -> Void
    let onMoveItem: (String) -> Void

    @State private var newItemName = ""
    @State private var newItemCat = "other"
    @FocusState private var inputFocused: Bool

    var toteItems: [Item] { appState.items.filter { $0.tote_id == tote.id } }
    var room: Room? { appState.room(for: tote) }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                ToteBadge(id: tote.id)
                Text(tote.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text("\(toteItems.count)×")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.textDim)
                Button(action: onEditTote) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15))
                        .foregroundColor(.textMuted)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .background(Color.surface2)

            Divider().background(Color.border)

            // Meta
            HStack {
                Text("📍 \(tote.shelf ?? "No location set")\(room != nil ? " · \(room!.name)" : "")")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.textMuted)
                Spacer()
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 5)
            .background(Color.surface2)

            Divider().background(Color.border)

            // Items
            if toteItems.isEmpty {
                Text("EMPTY — add items below")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.textDim)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
            } else {
                FlowLayout(spacing: 5) {
                    ForEach(toteItems) { item in
                        ItemChip(item: item, onTap: { onOpenItem(item) }, onMove: { onMoveItem(item.id) })
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }

            Divider().background(Color.border)

            // Add row
            HStack(spacing: 6) {
                TextField("Add item...", text: $newItemName)
                    .font(.system(size: 14))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.bg)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.border, lineWidth: 1))
                    .cornerRadius(6)
                    .focused($inputFocused)
                    .submitLabel(.done)
                    .onSubmit { Task { await addItem() } }

                CategoryPickerButton(selection: $newItemCat)

                Button("ADD") { Task { await addItem() } }
                    .font(.system(size: 11, weight: .bold)).tracking(1)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.accent)
                    .foregroundColor(.black)
                    .cornerRadius(5)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(Color.surface)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.border, lineWidth: 1))
        .cornerRadius(10)
    }

    func addItem() async {
        let name = newItemName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        newItemName = ""
        await appState.addItem(name: name, category: newItemCat, toteId: tote.id)
    }
}

struct ItemChip: View {
    let item: Item
    let onTap: () -> Void
    let onMove: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(CATS[item.category]?.color ?? CATS["other"]!.color)
                .frame(width: 7, height: 7)
            Text(item.name)
                .font(.system(size: 12))
                .lineLimit(1)
            Button(action: onMove) {
                Text("↗")
                    .font(.system(size: 13))
                    .foregroundColor(.textMuted)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.surface2)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.border, lineWidth: 1))
        .cornerRadius(5)
        .onTapGesture(perform: onTap)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Text(icon).font(.system(size: 36)).opacity(0.3)
            Text(title.uppercased())
                .font(.system(size: 16, weight: .bold)).tracking(2).foregroundColor(.textMuted)
            Text(subtitle).font(.system(size: 12)).foregroundColor(.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}
