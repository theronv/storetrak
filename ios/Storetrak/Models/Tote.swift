import Foundation

struct Tote: Identifiable, Codable, Hashable {
    let id: String
    var room_id: String?
    var name: String?
    var shelf: String?

    var displayName: String { name ?? id }
}
