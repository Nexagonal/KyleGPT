import Foundation

struct Message: Identifiable, Equatable {
    var id: String
    let text: String
    let isKyle: Bool
    let timestamp: Double
    let room: String
    let imageBase64: String?
    var isPending: Bool = false
    var chatId: String = ""
}
