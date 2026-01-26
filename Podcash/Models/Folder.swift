import Foundation
import SwiftData

@Model
final class Folder {
    var id: UUID = UUID()
    var name: String
    var colorHex: String?
    var sortOrder: Int = 0

    @Relationship
    var podcasts: [Podcast] = []

    var dateCreated: Date = Date()

    init(name: String, colorHex: String? = nil) {
        self.name = name
        self.colorHex = colorHex
    }
}
