import SwiftUI

struct RoomsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAddRoom = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 8) {
                        if appState.rooms.isEmpty {
                            EmptyStateView(icon: "🏠", title: "No Rooms", subtitle: "Add your first room to get started.")
                                .padding(.top, 40)
                        } else {
                            let toteRoom: [String: String] = Dictionary(uniqueKeysWithValues:
                                appState.totes.compactMap { t in t.room_id.map { (t.id, $0) } }
                            )
                            let itemsPerRoom: [String: Int] = appState.items.reduce(into: [:]) { acc, item in
                                guard let tid = item.tote_id, let rid = toteRoom[tid] else { return }
                                acc[rid, default: 0] += 1
                            }

                            ForEach(appState.rooms) { room in
                                let toteCount = appState.totes.filter { $0.room_id == room.id }.count
                                let itemCount = itemsPerRoom[room.id] ?? 0
                                RoomCard(room: room, toteCount: toteCount, itemCount: itemCount) {
                                    Task { await appState.deleteRoom(room.id) }
                                }
                            }
                        }
                    }
                    .padding(14)
                }
                .refreshable { await appState.loadAll() }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Rooms")
                            .font(.system(size: 22, weight: .bold)).tracking(2).textCase(.uppercase)
                            .foregroundColor(.textPrimary)
                        Text("\(appState.rooms.count) ROOMS · \(appState.totes.count) TOTES")
                            .font(.system(size: 10, design: .monospaced)).foregroundColor(.textMuted)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddRoom = true }) {
                        Image(systemName: "plus").foregroundColor(.accent).font(.system(size: 18, weight: .medium))
                    }
                }
            }
        }
        .sheet(isPresented: $showAddRoom) {
            AddRoomSheet(isPresented: $showAddRoom).environmentObject(appState)
        }
    }
}

struct RoomCard: View {
    let room: Room
    let toteCount: Int
    let itemCount: Int
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(room.code)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.accent)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(Color.accent.opacity(0.13))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.accent.opacity(0.32), lineWidth: 1))
                .cornerRadius(5)

            VStack(alignment: .leading, spacing: 2) {
                Text(room.name).font(.system(size: 15, weight: .semibold)).foregroundColor(.textPrimary)
                Text("\(toteCount) TOTE\(toteCount == 1 ? "" : "S") · \(itemCount) ITEMS")
                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.textMuted)
            }

            Spacer()

            Button("Delete") {
                onDelete()
            }
            .font(.system(size: 11, weight: .bold)).tracking(1)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.danger.opacity(0.12))
            .foregroundColor(.danger)
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.danger.opacity(0.25), lineWidth: 1))
            .cornerRadius(5)
        }
        .padding(14)
        .background(Color.surface)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.border, lineWidth: 1))
        .cornerRadius(10)
    }
}
