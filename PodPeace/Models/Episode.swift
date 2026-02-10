import Foundation
import SwiftData

@Model
final class Episode: @unchecked Sendable {
    @Attribute(.unique) var guid: String
    var title: String
    var episodeDescription: String?
    var audioURL: String
    var duration: TimeInterval?
    var publishedDate: Date?
    var artworkURL: String?  // Episode-specific artwork, falls back to podcast

    // Playback state
    var isPlayed: Bool = false
    var playbackPosition: TimeInterval = 0

    // User actions
    var isStarred: Bool = false

    // Download state
    var localFilePath: String?      // nil = not downloaded, stores just filename (not full path)
    var downloadProgress: Double?   // nil = not downloading, 0-1 = in progress

    /// Returns the full file URL for the downloaded episode
    var localFileURL: URL? {
        guard let filename = localFilePath else { return nil }
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let downloadsPath = documentsPath.appendingPathComponent("Downloads", isDirectory: true)
        return downloadsPath.appendingPathComponent(filename)
    }

    // Relationships
    var podcast: Podcast?

    @Relationship(deleteRule: .cascade)
    var queueItems: [QueueItem] = []

    init(
        guid: String,
        title: String,
        audioURL: String,
        episodeDescription: String? = nil,
        duration: TimeInterval? = nil,
        publishedDate: Date? = nil,
        artworkURL: String? = nil
    ) {
        self.guid = guid
        self.title = title
        self.audioURL = audioURL
        self.episodeDescription = episodeDescription
        self.duration = duration
        self.publishedDate = publishedDate
        self.artworkURL = artworkURL
    }

    /// Returns episode artwork URL, or falls back to podcast artwork
    var displayArtworkURL: String? {
        artworkURL ?? podcast?.artworkURL
    }

    // Episode link (from RSS feed, if available)
    var episodeLink: String?
    
    // iTunes episode ID (looked up from iTunes API)
    var itunesEpisodeID: String?

    /// The URL to use when sharing this episode
    var shareURL: String {
        let logger = AppLogger.data
        
        // Log podcast information for debugging
        if let podcast = podcast {
            logger.debug("[Share] Episode '\(self.title)' from podcast '\(podcast.title)' (Feed: \(podcast.feedURL))")
        } else {
            logger.debug("[Share] Episode '\(self.title)' has no associated podcast")
        }
        
        // 1. Prefer episode-specific link from RSS feed if available
        if let episodeLink = episodeLink, !episodeLink.isEmpty {
            logger.debug("[Share] Using RSS episode link for '\(self.title)': \(episodeLink)")
            return episodeLink
        }
        
        // 2. Try to construct Apple Podcasts episode URL using iTunes ID
        if let podcast = podcast,
           let itunesID = podcast.itunesID,
           !itunesID.isEmpty {
            // Apple Podcasts episode URL format: https://podcasts.apple.com/podcast/id{podcastID}?i={episodeID}
            
            logger.debug("[Share] Episode '\(self.title)' - GUID: \(self.guid), iTunes ID: \(itunesID)")
            
            // First, try using the stored iTunes episode ID (if we've looked it up before)
            if let itunesEpisodeID = itunesEpisodeID, !itunesEpisodeID.isEmpty {
                let url = "https://podcasts.apple.com/podcast/id\(itunesID)?i=\(itunesEpisodeID)"
                logger.debug("[Share] Using stored iTunes episode ID: \(url)")
                return url
            } else {
                logger.debug("[Share] No stored iTunes episode ID for '\(self.title)' (itunesEpisodeID is nil)")
            }
            
            // Try to extract a valid episode ID from the GUID
            // Valid episode IDs are typically 9-11 digits long
            if let episodeID = extractEpisodeID(from: guid) {
                let url = "https://podcasts.apple.com/podcast/id\(itunesID)?i=\(episodeID)"
                logger.debug("[Share] Generated Apple Podcasts episode URL from GUID: \(url)")
                return url
            }
            
            // If we can't extract a valid episode ID, just share the podcast URL
            // (Better than sharing a broken link)
            // Note: The app can look up the real episode ID in the background
            let url = "https://podcasts.apple.com/podcast/id\(itunesID)"
            logger.debug("[Share] Could not extract valid episode ID from GUID, using podcast URL: \(url)")
            return url
        }
        
        // 3. Fall back to podcast share URL
        // Note: This shares the podcast page, not the specific episode
        let fallbackURL = podcast?.shareURL ?? ""
        logger.debug("[Share] No iTunes ID available for '\(self.title)', using fallback: \(fallbackURL)")
        return fallbackURL
    }

    /// Whether this episode can be shared
    var canShare: Bool {
        !shareURL.isEmpty
    }
    
    /// Extracts a valid Apple Podcasts episode ID from a GUID
    /// Episode IDs are typically 9-11 digit numbers
    private func extractEpisodeID(from guid: String) -> String? {
        // Pattern 1: Look for a standalone number that's 9-11 digits (typical episode ID length)
        let pattern = "\\b(\\d{9,11})\\b"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: guid, range: NSRange(guid.startIndex..., in: guid)),
           let range = Range(match.range(at: 1), in: guid) {
            return String(guid[range])
        }
        
        // Pattern 2: If GUID is purely numeric and reasonable length, use it
        let numericOnly = guid.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if numericOnly.count >= 9 && numericOnly.count <= 11 {
            return numericOnly
        }
        
        // Pattern 3: Look for the last sequence of 9+ digits (often the episode ID)
        let allNumbers = guid.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .filter { !$0.isEmpty && $0.count >= 9 && $0.count <= 11 }
        if let lastNumber = allNumbers.last {
            return lastNumber
        }
        
        return nil
    }
}
