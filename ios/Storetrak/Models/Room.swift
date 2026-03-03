import Foundation

struct Room: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var code: String
}
