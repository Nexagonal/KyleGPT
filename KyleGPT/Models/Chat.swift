import Foundation

struct Chat: Identifiable, Equatable {
    var id: String
    var title: String
    let userEmail: String
    let createdAt: Double
    var deletedByUser: Bool
    var isUnread: Bool = false
}
