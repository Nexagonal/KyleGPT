import Foundation

struct FirestoreResponse: Codable { let documents: [FirestoreDocument]? }
struct FirestoreDocument: Codable { let name: String?; let fields: FirestoreFields? }
struct FirestoreValue: Codable {
    let stringValue: String?; let booleanValue: Bool?; let doubleValue: Double?; let integerValue: String?
    var asDouble: Double {
        if let d = doubleValue { return d }
        if let i = integerValue, let d = Double(i) { return d }
        if let s = stringValue, let d = Double(s) { return d }
        return 0.0
    }
    var asString: String { return stringValue ?? integerValue ?? "" }
    var asBool: Bool { return booleanValue ?? false }
}
struct FirestoreFields: Codable {
    let text: FirestoreValue?; let isKyle: FirestoreValue?; let timestamp: FirestoreValue?
    let room: FirestoreValue?; let imageBase64: FirestoreValue?; let lastActive: FirestoreValue?
    let chatId: FirestoreValue?
}
struct StatusResponse: Codable { let fields: FirestoreFields? }
struct AuthResponse: Codable { 
    let idToken: String
    let email: String?
    let localId: String?
    let refreshToken: String 
    let expiresIn: String?
    let isNewUser: Bool?
}

struct ChatCreateResponse: Codable { let chatId: String; let title: String }
struct ChatListResponse: Codable {
    let chats: [ChatJSON]
    struct ChatJSON: Codable {
        let chatId: String; let userEmail: String; let title: String
        let createdAt: Double; let deletedByUser: Int
        let isUnread: Bool?
    }
}
struct AdminChatsResponse: Codable {
    var users: [AdminUser]
    struct AdminUser: Codable {
        let userEmail: String; let nickname: String; let latestActivity: Double; var chats: [AdminChat]
    }
    struct AdminChat: Codable {
        let chatId: String; let title: String; let createdAt: Double
        let deletedByUser: Bool; let latestMessageTimestamp: Double
        let messageCount: Int; var isUnread: Bool
    }
}
