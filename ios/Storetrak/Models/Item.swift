import Foundation

struct Item: Identifiable, Codable, Hashable {
    let id: String
    var user_id: String
    var tote_id: String?
    var name: String
    var category: String
    var qty: Int
    var value: Double?
    var make: String?
    var model: String?
    var year: String?
    var serial: String?
    var notes: String?
    var image_url: String?
}
