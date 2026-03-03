import SwiftUI

struct ToastMessage: Identifiable {
    let id = UUID()
    let text: String
    let type: ToastType
    enum ToastType { case success, error, info }
}

enum Tab { case inbox, totes, rooms, stats }

@MainActor
class AppState: ObservableObject {
    @Published var rooms: [Room] = []
    @Published var totes: [Tote] = []
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var toast: ToastMessage? = nil
    @Published var activeTab: Tab = .inbox
    @Published var selectedInboxIds: Set<String> = []
    @Published var isLoggedIn: Bool = AuthManager.shared.isLoggedIn

    func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let r: [Room] = APIClient.request("GET", path: "rooms")
            async let t: [Tote] = APIClient.request("GET", path: "totes")
            async let i: [Item] = APIClient.request("GET", path: "items")
            (rooms, totes, items) = try await (r, t, i)
        } catch APIError.unauthorized {
            AuthManager.shared.clear()
            isLoggedIn = false
        } catch {
            showToast(error.localizedDescription, type: .error)
        }
    }

    func addItem(name: String, category: String, toteId: String?) async {
        struct Body: Encodable { let name: String; let category: String; let tote_id: String?; let qty: Int }
        do {
            let item: Item = try await APIClient.request("POST", path: "items",
                body: Body(name: name, category: category, tote_id: toteId, qty: 1))
            items.append(item)
            showToast("Added to \(toteId == nil ? "inbox" : "tote")", type: .success)
        } catch {
            showToast(error.localizedDescription, type: .error)
        }
    }

    func saveItem(_ item: Item) async {
        struct Body: Encodable {
            let name: String; let category: String; let tote_id: String?
            let qty: Int; let value: Double?; let make: String?; let model: String?
            let year: String?; let serial: String?; let notes: String?; let image_url: String?
        }
        do {
            let updated: Item = try await APIClient.request("PATCH", path: "items/\(item.id)",
                body: Body(name: item.name, category: item.category, tote_id: item.tote_id,
                           qty: item.qty, value: item.value, make: item.make, model: item.model,
                           year: item.year, serial: item.serial, notes: item.notes, image_url: item.image_url))
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                items[idx] = updated
            }
            showToast("Saved", type: .success)
        } catch {
            showToast(error.localizedDescription, type: .error)
        }
    }

    func deleteItem(_ id: String) async {
        do {
            try await APIClient.send("DELETE", path: "items/\(id)")
            items.removeAll { $0.id == id }
            showToast("Deleted", type: .success)
        } catch {
            showToast(error.localizedDescription, type: .error)
        }
    }

    func moveItems(_ ids: [String], to toteId: String?) async {
        struct Body: Encodable { let ids: [String]; let tote_id: String? }
        do {
            try await APIClient.send("PATCH", path: "items", body: Body(ids: ids, tote_id: toteId))
            for id in ids {
                if let idx = items.firstIndex(where: { $0.id == id }) {
                    items[idx].tote_id = toteId
                }
            }
            selectedInboxIds.removeAll()
            showToast("\(ids.count) item\(ids.count == 1 ? "" : "s") moved", type: .success)
        } catch {
            showToast(error.localizedDescription, type: .error)
        }
    }

    func addRoom(name: String, code: String) async {
        struct Body: Encodable { let name: String; let code: String }
        do {
            let room: Room = try await APIClient.request("POST", path: "rooms", body: Body(name: name, code: code))
            rooms.append(room)
            rooms.sort { $0.name < $1.name }
            showToast("\"\(name)\" added", type: .success)
        } catch {
            showToast(error.localizedDescription, type: .error)
        }
    }

    func deleteRoom(_ id: String) async {
        do {
            try await APIClient.send("DELETE", path: "rooms/\(id)")
            let gone = totes.filter { $0.room_id == id }.map { $0.id }
            rooms.removeAll { $0.id == id }
            totes.removeAll { $0.room_id == id }
            items.removeAll { gone.contains($0.tote_id ?? "") }
            showToast("Room deleted", type: .success)
        } catch {
            showToast(error.localizedDescription, type: .error)
        }
    }

    func addTote(id: String, roomId: String, name: String, shelf: String?) async {
        struct Body: Encodable { let id: String; let room_id: String; let name: String; let shelf: String? }
        do {
            let tote: Tote = try await APIClient.request("POST", path: "totes",
                body: Body(id: id, room_id: roomId, name: name, shelf: shelf))
            totes.append(tote)
            showToast("\(id) created", type: .success)
        } catch {
            showToast(error.localizedDescription, type: .error)
        }
    }

    func saveTote(_ tote: Tote) async {
        struct Body: Encodable { let name: String?; let shelf: String?; let room_id: String? }
        do {
            let updated: Tote = try await APIClient.request("PATCH", path: "totes/\(tote.id)",
                body: Body(name: tote.name, shelf: tote.shelf, room_id: tote.room_id))
            if let idx = totes.firstIndex(where: { $0.id == tote.id }) {
                totes[idx] = updated
            }
            showToast("Tote updated", type: .success)
        } catch {
            showToast(error.localizedDescription, type: .error)
        }
    }

    func deleteTote(_ id: String) async {
        do {
            try await APIClient.send("DELETE", path: "totes/\(id)")
            totes.removeAll { $0.id == id }
            items.removeAll { $0.tote_id == id }
            showToast("Tote deleted", type: .success)
        } catch {
            showToast(error.localizedDescription, type: .error)
        }
    }

    func showToast(_ text: String, type: ToastMessage.ToastType = .info) {
        toast = ToastMessage(text: text, type: type)
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if toast?.text == text { toast = nil }
        }
    }

    // Helpers
    func room(for tote: Tote) -> Room? { rooms.first { $0.id == tote.room_id } }
    func tote(for item: Item) -> Tote? { totes.first { $0.id == item.tote_id } }
    var inboxItems: [Item] { items.filter { $0.tote_id == nil } }

    func nextToteNum(roomId: String) -> String {
        let nums = totes.filter { $0.room_id == roomId }.compactMap { tote -> Int? in
            guard let m = tote.id.range(of: #"-(\d+)$"#, options: .regularExpression) else { return nil }
            return Int(tote.id[m].dropFirst())
        }
        return String(format: "%02d", (nums.max() ?? 0) + 1)
    }
}
