import SwiftUI

struct StatsView: View {
    @EnvironmentObject var appState: AppState

    var inboxCount: Int { appState.items.filter { $0.tote_id == nil }.count }
    var sortedItems: [Item] { appState.items.filter { $0.tote_id != nil } }

    var catCounts: [(key: String, label: String, color: Color, count: Int)] {
        var counts: [String: Int] = [:]
        appState.items.forEach { counts[$0.category, default: 0] += 1 }
        return CATS_ORDER.compactMap { k in
            guard let c = counts[k], c > 0, let cat = CATS[k] else { return nil }
            return (key: k, label: cat.label, color: cat.color, count: c)
        }.sorted { $0.count > $1.count }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        // KPI grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            StatCard(label: "Rooms", value: appState.rooms.count)
                            StatCard(label: "Totes", value: appState.totes.count)
                            StatCard(label: "Items", value: sortedItems.count)
                            StatCard(label: "Inbox", value: inboxCount)
                        }

                        // Category breakdown
                        VStack(alignment: .leading, spacing: 12) {
                            Text("BY CATEGORY")
                                .font(.system(size: 9, design: .monospaced))
                                .tracking(2).foregroundColor(.textDim)

                            if catCounts.isEmpty {
                                Text("No items yet")
                                    .font(.system(size: 12)).foregroundColor(.textDim)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 8)
                            } else {
                                let maxCount = catCounts.map(\.count).max() ?? 1
                                ForEach(catCounts, id: \.key) { cat in
                                    HStack(spacing: 10) {
                                        Circle().fill(cat.color).frame(width: 8, height: 8)
                                        Text(cat.label).font(.system(size: 13)).foregroundColor(.textPrimary)
                                        Spacer()
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                RoundedRectangle(cornerRadius: 2).fill(Color.border).frame(height: 4)
                                                RoundedRectangle(cornerRadius: 2).fill(cat.color)
                                                    .frame(width: geo.size.width * CGFloat(cat.count) / CGFloat(maxCount), height: 4)
                                            }
                                        }
                                        .frame(width: 70, height: 4)
                                        Text("\(cat.count)")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.textMuted)
                                            .frame(width: 22, alignment: .trailing)
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.surface)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.border, lineWidth: 1))
                        .cornerRadius(10)
                    }
                    .padding(14)
                }
                .refreshable { await appState.loadAll() }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Overview")
                        .font(.system(size: 22, weight: .bold)).tracking(2).textCase(.uppercase)
                        .foregroundColor(.textPrimary)
                }
            }
        }
    }
}

struct StatCard: View {
    let label: String
    let value: Int

    var body: some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(.accent)
            Text(label.uppercased())
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.textMuted)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.surface)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.border, lineWidth: 1))
        .cornerRadius(10)
    }
}
