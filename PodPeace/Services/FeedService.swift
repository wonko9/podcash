import Foundation
@preconcurrency import FeedKit
import SwiftData

// Wrapper to make FeedKit's Result Sendable
private struct SendableResult: @unchecked Sendable {
    let value: Result<Feed, ParserError>
}

/// Service for fetching and parsing podcast RSS feeds
final class FeedService: @unchecked Sendable {
    nonisolated(unsafe) static let shared = FeedService()
    private init() {}

    /// Fetches and parses a podcast feed, returning a new Podcast with episodes
    func fetchPodcast(from urlString: String) async throws -> (podcast: Podcast, episodes: [Episode]) {
        guard let url = URL(string: urlString) else {
            throw FeedError.invalidURL
        }

        let parser = FeedParser(URL: url)
        // FeedKit's Result type is not Sendable, wrap it to make it safe
        let wrappedResult = await withUnsafeContinuation { (continuation: UnsafeContinuation<SendableResult, Never>) in
            parser.parseAsync { result in
                continuation.resume(returning: SendableResult(value: result))
            }
        }
        let result = wrappedResult.value

        switch result {
        case .success(let feed):
            let (podcast, episodes) = try parseFeed(feed, feedURL: urlString)

            // Always try to find iTunes ID and public feed URL for better sharing
            // This is especially important for private feeds, but useful for all podcasts
            await findPublicFeed(for: podcast)
            
            // Look up iTunes episode IDs for better sharing (async, don't block)
            if let itunesID = podcast.itunesID {
                Task {
                    await lookupEpisodeIDs(for: episodes, podcastID: itunesID)
                }
            }

            return (podcast, episodes)
        case .failure(let error):
            throw FeedError.parsingFailed(error.localizedDescription)
        }
    }

    /// Fetches a podcast feed with conditional HTTP headers (ETag/If-Modified-Since)
    /// Returns nil if the feed has not been modified (304 response)
    private func fetchPodcastConditional(
        from urlString: String,
        etag: String?,
        lastModified: String?
    ) async throws -> (podcast: Podcast, episodes: [Episode], etag: String?, lastModified: String?)? {
        guard let url = URL(string: urlString) else {
            throw FeedError.invalidURL
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        // Add conditional headers if we have them
        if let etag = etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        if let lastModified = lastModified {
            request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeedError.parsingFailed("Invalid response")
        }

        // 304 Not Modified - feed hasn't changed
        if httpResponse.statusCode == 304 {
            return nil
        }

        guard httpResponse.statusCode == 200 else {
            throw FeedError.parsingFailed("HTTP \(httpResponse.statusCode)")
        }

        // Extract caching headers from response
        let newETag = httpResponse.value(forHTTPHeaderField: "ETag")
        let newLastModified = httpResponse.value(forHTTPHeaderField: "Last-Modified")

        // Parse the feed data
        let parser = FeedParser(data: data)
        // FeedKit's Result type is not Sendable, wrap it to make it safe
        let wrappedResult = await withUnsafeContinuation { (continuation: UnsafeContinuation<SendableResult, Never>) in
            parser.parseAsync { result in
                continuation.resume(returning: SendableResult(value: result))
            }
        }
        let result = wrappedResult.value

        switch result {
        case .success(let feed):
            let (podcast, episodes) = try parseFeed(feed, feedURL: urlString)
            return (podcast, episodes, newETag, newLastModified)
        case .failure(let error):
            throw FeedError.parsingFailed(error.localizedDescription)
        }
    }

    /// Look up iTunes episode IDs for episodes to enable proper episode sharing
    private func lookupEpisodeIDs(for episodes: [Episode], podcastID: String) async {
        let logger = AppLogger.feed
        logger.debug("[Episode ID Lookup] Looking up episode IDs for podcast \(podcastID)")
        
        // Look up the first few episodes (don't overwhelm the API)
        let episodesToLookup = Array(episodes.prefix(10))
        
        for episode in episodesToLookup {
            // Skip if we already have an iTunes episode ID
            if episode.itunesEpisodeID != nil {
                continue
            }
            
            do {
                if let episodeID = try await PodcastLookupService.shared.lookupEpisodeID(
                    podcastID: podcastID,
                    episodeTitle: episode.title,
                    publishedDate: episode.publishedDate
                ) {
                    episode.itunesEpisodeID = episodeID
                    logger.debug("[Episode ID Lookup] Found iTunes episode ID for '\(episode.title)': \(episodeID)")
                }
            } catch {
                logger.error("[Episode ID Lookup] Failed to lookup episode ID for '\(episode.title)': \(error.localizedDescription)")
            }
        }
    }
    
    /// Searches iTunes to find and store the podcast's iTunes ID and public feed URL
    /// This enables episode sharing via Apple Podcasts URLs
    private func findPublicFeed(for podcast: Podcast) async {
        let logger = AppLogger.feed
        
        do {
            // Strategy 1: Try to look up by feed URL directly (most reliable)
            logger.debug("[iTunes Lookup] Attempting feed URL lookup for: \(podcast.feedURL)")
            if let result = try? await PodcastLookupService.shared.lookupPodcastByFeedURL(podcast.feedURL) {
                // Verify the title matches reasonably well
                let normalizedPodcastTitle = podcast.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let normalizedResultTitle = result.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Only use this result if titles are similar
                if normalizedPodcastTitle.contains(normalizedResultTitle) || 
                   normalizedResultTitle.contains(normalizedPodcastTitle) ||
                   normalizedPodcastTitle == normalizedResultTitle {
                    podcast.itunesID = result.id
                    logger.info("[iTunes Lookup] ✓ Found iTunes ID via feed URL lookup: \(result.id) (Podcast: '\(result.title)')")
                    
                    if let feedURL = result.feedURL {
                        podcast.publicFeedURL = feedURL
                        logger.debug("[iTunes Lookup] Stored public feed URL: \(feedURL)")
                    }
                    return
                } else {
                    logger.warning("[iTunes Lookup] Feed URL matched but titles don't match: '\(podcast.title)' vs '\(result.title)'")
                }
            }
            
            // Strategy 2: Fall back to title-based search
            logger.debug("[iTunes Lookup] Feed URL lookup failed, trying title search: '\(podcast.title)'")
            let results = try await PodcastLookupService.shared.searchPodcasts(query: podcast.title)
            logger.debug("[iTunes Lookup] Found \(results.count) results")

            // Find a match with the same or very similar title
            let normalizedTitle = podcast.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedFeedURL = podcast.feedURL.lowercased()

            for result in results {
                let resultTitle = result.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let resultFeedURL = result.feedURL?.lowercased() ?? ""
                
                logger.debug("[iTunes Lookup] Comparing '\(normalizedTitle)' with '\(resultTitle)'")
                
                // First priority: exact feed URL match (most reliable)
                if !resultFeedURL.isEmpty && normalizedFeedURL == resultFeedURL {
                    podcast.itunesID = result.id
                    logger.info("[iTunes Lookup] ✓ Found iTunes ID via feed URL match for '\(podcast.title)': \(result.id)")
                    
                    if let feedURL = result.feedURL {
                        podcast.publicFeedURL = feedURL
                        logger.debug("[iTunes Lookup] Stored public feed URL: \(feedURL)")
                    }
                    return
                }

                // Second priority: title match
                if resultTitle == normalizedTitle ||
                   resultTitle.contains(normalizedTitle) ||
                   normalizedTitle.contains(resultTitle) {
                    // Store iTunes ID for episode sharing
                    podcast.itunesID = result.id
                    logger.info("[iTunes Lookup] ✓ Found iTunes ID via title match for '\(podcast.title)': \(result.id)")
                    
                    if let feedURL = result.feedURL {
                        podcast.publicFeedURL = feedURL
                        logger.debug("[iTunes Lookup] Stored public feed URL: \(feedURL)")
                    }
                    return
                }
            }
            
            logger.warning("[iTunes Lookup] ✗ No iTunes match found for '\(podcast.title)'")
            logger.debug("[iTunes Lookup] Feed URL was: \(podcast.feedURL)")
        } catch {
            logger.error("[iTunes Lookup] Failed to search iTunes for '\(podcast.title)': \(error.localizedDescription)")
        }
    }

    /// Refreshes all podcasts in the library
    /// - Returns: Total number of new episodes added across all podcasts
    @MainActor
    func refreshAllPodcasts(context: ModelContext) async -> Int {
        let descriptor = FetchDescriptor<Podcast>()
        guard let podcasts = try? context.fetch(descriptor) else { return 0 }

        var totalNew = 0
        for podcast in podcasts {
            if let count = try? await refreshPodcast(podcast, context: context) {
                totalNew += count
            }
        }
        return totalNew
    }

    /// Refreshes a specific list of podcasts
    /// - Returns: Total number of new episodes added
    @MainActor
    func refreshPodcasts(_ podcasts: [Podcast], context: ModelContext) async -> Int {
        var totalNew = 0
        for podcast in podcasts {
            if let count = try? await refreshPodcast(podcast, context: context) {
                totalNew += count
            }
        }
        return totalNew
    }

    /// Refreshes an existing podcast, adding new episodes
    @MainActor
    func refreshPodcast(_ podcast: Podcast, context: ModelContext) async throws -> Int {
        let logger = AppLogger.feed

        // Store feed URL before async call to avoid accessing podcast from wrong thread
        let feedURL = podcast.feedURL
        let podcastTitle = podcast.title
        
        // Always do a full fetch (HTTP caching disabled - was causing missed episodes)
        let (_, newEpisodes) = try await fetchPodcast(from: feedURL)

        logger.info("[\(podcastTitle)] Fetched \(newEpisodes.count) episodes")

        // Access podcast.episodes only once and extract GUIDs
        let existingGUIDs = Set(podcast.episodes.map { $0.guid })
        var addedCount = 0
        var newlyAddedEpisodes: [Episode] = []

        for episode in newEpisodes {
            if !existingGUIDs.contains(episode.guid) {
                episode.podcast = podcast
                podcast.episodes.append(episode)
                context.insert(episode)
                addedCount += 1
                newlyAddedEpisodes.append(episode)
                logger.info("[\(podcastTitle)] NEW: \(episode.title)")
            }
        }

        if addedCount == 0 {
            logger.info("[\(podcastTitle)] No new episodes")
        } else {
            logger.info("[\(podcastTitle)] Added \(addedCount) new episode(s)")
            // Save immediately so @Query observers update in real-time
            try? context.save()
        }

        podcast.lastRefreshed = Date()

        // Check if auto-download is enabled for this podcast or any of its folders
        let shouldAutoDownload = podcast.autoDownloadNewEpisodes || isInAutoDownloadFolder(podcast, context: context)

        // Auto-download new episodes if enabled
        if shouldAutoDownload {
            await MainActor.run {
                for episode in newlyAddedEpisodes {
                    // Check network preference for auto-downloads (skip confirmation for background refresh)
                    let result = DownloadManager.shared.checkDownloadAllowed(episode, isAutoDownload: true, context: context)
                    if case .started = result {
                        DownloadManager.shared.download(episode)
                    }
                    // Note: .wifiOnly will block, .askOnCellular treated as blocked for auto-downloads
                }

                // Enforce per-podcast limit after downloads start
                DownloadCleanupService.shared.enforcePerPodcastLimit(for: podcast, context: context)
            }
        }

        return addedCount
    }

    private func parseFeed(_ feed: Feed, feedURL: String) throws -> (podcast: Podcast, episodes: [Episode]) {
        switch feed {
        case .rss(let rssFeed):
            return parseRSSFeed(rssFeed, feedURL: feedURL)
        case .atom(let atomFeed):
            return parseAtomFeed(atomFeed, feedURL: feedURL)
        case .json(let jsonFeed):
            return parseJSONFeed(jsonFeed, feedURL: feedURL)
        }
    }

    private func parseRSSFeed(_ feed: RSSFeed, feedURL: String) -> (podcast: Podcast, episodes: [Episode]) {
        let podcast = Podcast(
            feedURL: feedURL,
            title: feed.title ?? "Untitled Podcast",
            author: feed.iTunes?.iTunesAuthor ?? feed.managingEditor,
            artworkURL: feed.iTunes?.iTunesImage?.attributes?.href ?? feed.image?.url,
            podcastDescription: feed.description
        )

        let episodes = (feed.items ?? []).compactMap { item -> Episode? in
            guard let audioURL = item.enclosure?.attributes?.url ?? findAudioURL(in: item) else {
                return nil
            }

            let guid = item.guid?.value ?? audioURL

            let episode = Episode(
                guid: guid,
                title: item.title ?? "Untitled Episode",
                audioURL: audioURL,
                episodeDescription: item.description ?? item.content?.contentEncoded,
                duration: parseDuration(item.iTunes?.iTunesDuration),
                publishedDate: item.pubDate,
                artworkURL: item.iTunes?.iTunesImage?.attributes?.href
            )
            
            // Extract episode link for sharing
            episode.episodeLink = item.link
            
            return episode
        }

        return (podcast, episodes)
    }

    private func parseAtomFeed(_ feed: AtomFeed, feedURL: String) -> (podcast: Podcast, episodes: [Episode]) {
        let podcast = Podcast(
            feedURL: feedURL,
            title: feed.title ?? "Untitled Podcast",
            author: feed.authors?.first?.name,
            artworkURL: feed.logo,
            podcastDescription: feed.subtitle?.value
        )

        let episodes = (feed.entries ?? []).compactMap { entry -> Episode? in
            guard let audioURL = entry.links?.first(where: {
                $0.attributes?.type?.contains("audio") == true
            })?.attributes?.href else {
                return nil
            }

            let episode = Episode(
                guid: entry.id ?? audioURL,
                title: entry.title ?? "Untitled Episode",
                audioURL: audioURL,
                episodeDescription: entry.summary?.value ?? entry.content?.value,
                publishedDate: entry.published ?? entry.updated
            )
            
            // Extract episode link for sharing (first non-audio link)
            episode.episodeLink = entry.links?.first(where: {
                $0.attributes?.type?.contains("audio") != true
            })?.attributes?.href
            
            return episode
        }

        return (podcast, episodes)
    }

    private func parseJSONFeed(_ feed: JSONFeed, feedURL: String) -> (podcast: Podcast, episodes: [Episode]) {
        let podcast = Podcast(
            feedURL: feedURL,
            title: feed.title ?? "Untitled Podcast",
            author: feed.author?.name,
            artworkURL: feed.icon ?? feed.favicon,
            podcastDescription: feed.description
        )

        let episodes = (feed.items ?? []).compactMap { item -> Episode? in
            guard let audioURL = item.attachments?.first(where: {
                $0.mimeType?.contains("audio") == true
            })?.url else {
                return nil
            }

            let episode = Episode(
                guid: item.id ?? audioURL,
                title: item.title ?? "Untitled Episode",
                audioURL: audioURL,
                episodeDescription: item.contentHtml ?? item.contentText,
                duration: item.attachments?.first?.durationInSeconds.map { TimeInterval($0) },
                publishedDate: item.datePublished
            )
            
            // Extract episode link for sharing
            episode.episodeLink = item.url
            
            return episode
        }

        return (podcast, episodes)
    }

    private func findAudioURL(in item: RSSFeedItem) -> String? {
        // Some feeds put audio in media content
        if let mediaContent = item.media?.mediaContents?.first(where: {
            $0.attributes?.type?.contains("audio") == true
        }) {
            return mediaContent.attributes?.url
        }
        return nil
    }

    private func parseDuration(_ duration: TimeInterval?) -> TimeInterval? {
        duration
    }

    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString)
    }

    /// Checks if a podcast is in any folder that has auto-download enabled
    private func isInAutoDownloadFolder(_ podcast: Podcast, context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Folder>(
            predicate: #Predicate { $0.autoDownloadNewEpisodes == true }
        )

        guard let autoDownloadFolders = try? context.fetch(descriptor) else {
            return false
        }

        // Check if any auto-download folder contains this podcast
        for folder in autoDownloadFolders {
            if folder.podcasts.contains(where: { $0.feedURL == podcast.feedURL }) {
                return true
            }
        }

        return false
    }
}

enum FeedError: LocalizedError {
    case invalidURL
    case parsingFailed(String)
    case noAudioContent

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid feed URL"
        case .parsingFailed(let reason):
            return "Failed to parse feed: \(reason)"
        case .noAudioContent:
            return "No audio content found in feed"
        }
    }
}
