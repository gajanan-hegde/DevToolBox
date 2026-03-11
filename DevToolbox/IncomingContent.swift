import Foundation

struct IncomingContent: Codable, Hashable {
    let id: UUID
    let content: String
    let candidates: [Tool]
}
