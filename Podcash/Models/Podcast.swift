import Foundation
import SwiftData

@Model
final class Podcast {
    @Attribute(.unique) var feedURL: String
    var title: String
    var author: String?
    var artworkURL: String?
    var podcastDescription: String?

    // Per-podcast settings
    var playbackSpeedOverride: Double?  // nil = use global setting
    var autoDownloadCount: Int = 0       // 0 = disabled

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \Episode.podcast)
    var episodes: [Episode] = []

    @Relationship(inverse: \Folder.podcasts)
    var folders: [Folder] = []

    // Metadata
    var dateAdded: Date = Date()
    var lastRefreshed: Date?

    init(
        feedURL: String,
        title: String,
        author: String? = nil,
        artworkURL: String? = nil,
        podcastDescription: String? = nil
    ) {
        self.feedURL = feedURL
        self.title = title
        self.author = author
        self.artworkURL = artworkURL
        self.podcastDescription = podcastDescription
    }
}
