import SwiftUI
import UIKit

struct InboxView: View {
    @EnvironmentObject var appState: AppState
    @State private var newItemName = ""
    @State private var newItemCategory = "other"
    @State private var showBulkMove = false
    @State private var showMoveSheet: String? = nil   // item id
    @State private var selectedItem: Item? = nil

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Bulk bar
                    if !appState.selectedInboxIds.isEmpty {
                        HStack {
                            Text("\(appState.selectedInboxIds.count) SELECTED")
                                .font(.system(size: 14, weight: .bold))
                            Spacer()
                            Button("CANCEL") { appState.selectedInboxIds.removeAll() }
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.black.opacity(0.15))
                                .cornerRadius(6)
                            Button("MOVE TO TOTE →") { showBulkMove = true }
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.black.opacity(0.15))
                                .cornerRadius(6)
                        }
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.accent)
                        .foregroundColor(.black)
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            // Add input
                            HStack(spacing: 8) {
                                TextField("Scan or type item name...", text: $newItemName)
                                    .padding(9)
                                    .background(Color.bg)
                                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.border, lineWidth: 1))
                                    .cornerRadius(7)
                                    .submitLabel(.done)
                                    .onSubmit { Task { await addItem() } }

                                CategoryPickerButton(selection: $newItemCategory)

                                Button("ADD") { Task { await addItem() } }
                                    .font(.system(size: 13, weight: .bold))
                                    .tracking(1)
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Color.accent)
                                    .foregroundColor(.black)
                                    .cornerRadius(8)
                            }
                            .padding(10)
                            .background(Color.surface)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accent.opacity(0.32), lineWidth: 1))
                            .cornerRadius(10)

                            Text("TAP TO EDIT · LONG-PRESS TO SELECT FOR BULK MOVE")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.textDim)
                                .tracking(1)

                            if appState.inboxItems.isEmpty {
                                VStack(spacing: 8) {
                                    Text("📥").font(.system(size: 36)).opacity(0.3)
                                    Text("INBOX EMPTY").font(.system(size: 16, weight: .bold)).tracking(2).foregroundColor(.textMuted)
                                    Text("Type an item above to add it unsorted.")
                                        .font(.system(size: 12)).foregroundColor(.textDim)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                            } else {
                                FlowLayout(spacing: 6) {
                                    ForEach(appState.inboxItems) { item in
                                        InboxChip(
                                            item: item,
                                            isSelected: appState.selectedInboxIds.contains(item.id),
                                            onTap: { selectedItem = item },
                                            onLongPress: { toggleSelect(item.id) },
                                            onMove: { showMoveSheet = item.id }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(14)
                    }
                    .refreshable { await appState.loadAll() }
                }
            }
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Text("Inbox").font(.system(size: 22, weight: .bold)).tracking(2).textCase(.uppercase)
                        Text("\(appState.inboxItems.count) UNSORTED")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.textMuted)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign Out") {
                        AuthManager.shared.clear()
                        appState.rooms = []
                        appState.totes = []
                        appState.items = []
                        appState.isLoggedIn = false
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.textMuted)
                }
            }
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
        .sheet(isPresented: $showBulkMove) {
            BulkMoveSheet(isPresented: $showBulkMove)
                .environmentObject(appState)
        }
    }

    func toggleSelect(_ id: String) {
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
        if appState.selectedInboxIds.contains(id) {
            appState.selectedInboxIds.remove(id)
        } else {
            appState.selectedInboxIds.insert(id)
        }
    }

    func addItem() async {
        let name = newItemName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        newItemName = ""
        await appState.addItem(name: name, category: newItemCategory, toteId: nil)
    }
}

struct InboxChip: View {
    let item: Item
    let isSelected: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onMove: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(CATS[item.category]?.color ?? CATS["other"]!.color)
                .frame(width: 7, height: 7)
            Text(item.name)
                .font(.system(size: 13))
                .lineLimit(1)
            Button(action: onMove) {
                Text("📦")
                    .font(.system(size: 13))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accent.opacity(0.13) : Color.surface2)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(isSelected ? Color.accent : Color.border, lineWidth: 1)
        )
        .cornerRadius(5)
        .onTapGesture(perform: onTap)
        .onLongPressGesture(minimumDuration: 0.5, perform: onLongPress)
    }
}

// Simple flow layout for wrapping chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0; var y: CGFloat = 0; var rowH: CGFloat = 0
        for sv in subviews {
            let sz = sv.sizeThatFits(.unspecified)
            if x + sz.width > width && x > 0 { y += rowH + spacing; x = 0; rowH = 0 }
            rowH = max(rowH, sz.height); x += sz.width + spacing
        }
        return CGSize(width: width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX; var y = bounds.minY; var rowH: CGFloat = 0
        for sv in subviews {
            let sz = sv.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX && x > bounds.minX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            sv.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            rowH = max(rowH, sz.height); x += sz.width + spacing
        }
    }
}
