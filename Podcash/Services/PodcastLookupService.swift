import Foundation

/// Service for resolving podcast URLs and searching for podcasts
final class PodcastLookupService {
    static let shared = PodcastLookupService()
    private init() {}

    // MARK: - URL Resolution

    /// Resolves various podcast URL formats to an RSS feed URL
    func resolveToRSSFeed(url urlString: String) async throws -> String {
        let normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Already an RSS feed URL
        if isLikelyRSSFeed(normalized) {
            return normalized
        }

        // Apple Podcasts URL
        if let appleID = extractApplePodcastID(from: normalized) {
            return try await resolveApplePodcast(id: appleID)
        }

        // Pocket Casts URL
        if normalized.contains("pca.st") {
            return try await resolvePocketCasts(url: normalized)
        }

        // Overcast URL (bonus)
        if normalized.contains("overcast.fm") {
            if let appleID = extractOvercastAppleID(from: normalized) {
                return try await resolveApplePodcast(id: appleID)
            }
        }

        // Assume it's a direct RSS URL
        return normalized
    }

    // MARK: - Search

    /// Search for podcasts using Apple's iTunes Search API
    func searchPodcasts(query: String) async throws -> [PodcastSearchResult] {
        guard !query.isEmpty else { return [] }

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://itunes.apple.com/search?term=\(encoded)&media=podcast&limit=25"

        guard let url = URL(string: urlString) else {
            throw LookupError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(iTunesSearchResponse.self, from: data)

        return response.results.map { result in
            PodcastSearchResult(
                id: String(result.collectionId),
                title: result.collectionName,
                author: result.artistName,
                artworkURL: result.artworkUrl600 ?? result.artworkUrl100,
                feedURL: result.feedUrl
            )
        }
    }

    // MARK: - Apple Podcasts Resolution

    private func resolveApplePodcast(id: String) async throws -> String {
        let urlString = "https://itunes.apple.com/lookup?id=\(id)&entity=podcast"

        guard let url = URL(string: urlString) else {
            throw LookupError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(iTunesLookupResponse.self, from: data)

        guard let result = response.results.first, let feedURL = result.feedUrl else {
            throw LookupError.feedNotFound
        }

        return feedURL
    }

    private func extractApplePodcastID(from url: String) -> String? {
        // Format: https://podcasts.apple.com/us/podcast/podcast-name/id1234567890
        // Or: https://itunes.apple.com/podcast/id1234567890
        if let range = url.range(of: "/id") {
            let afterID = url[range.upperBound...]
            let id = afterID.prefix(while: { $0.isNumber })
            if !id.isEmpty {
                return String(id)
            }
        }
        return nil
    }

    // MARK: - Pocket Casts Resolution

    private func resolvePocketCasts(url urlString: String) async throws -> String {
        // Pocket Casts URLs can be:
        // https://pca.st/podcast/abc123
        // https://pca.st/abc123
        // https://pockets.casts.com/podcasts/abc123

        guard let url = URL(string: urlString) else {
            throw LookupError.invalidURL
        }

        // Fetch the page and look for RSS feed in meta tags or page content
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        // Check for redirect - Pocket Casts might redirect to the actual podcast page
        if let httpResponse = response as? HTTPURLResponse,
           let location = httpResponse.value(forHTTPHeaderField: "Location") {
            return try await resolvePocketCasts(url: location)
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw LookupError.feedNotFound
        }

        // Look for RSS feed URL in the page
        if let feedURL = extractRSSFromHTML(html) {
            return feedURL
        }

        // Look for Apple Podcasts link and resolve that
        if let appleURL = extractApplePodcastsLink(from: html),
           let appleID = extractApplePodcastID(from: appleURL) {
            return try await resolveApplePodcast(id: appleID)
        }

        throw LookupError.feedNotFound
    }

    private func extractRSSFromHTML(_ html: String) -> String? {
        // Look for RSS link in meta tags
        // <link rel="alternate" type="application/rss+xml" href="..." />
        let patterns = [
            #"<link[^>]*type=["\']application/rss\+xml["\'][^>]*href=["\']([^"\']+)["\']"#,
            #"<link[^>]*href=["\']([^"\']+)["\'][^>]*type=["\']application/rss\+xml["\']"#,
            #"["\']feedUrl["\']\s*:\s*["\']([^"\']+)["\']"#,
            #"rss[_-]?feed[_-]?url["\']?\s*[:=]\s*["\']([^"\']+)["\']"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                return String(html[range])
            }
        }

        return nil
    }

    private func extractApplePodcastsLink(from html: String) -> String? {
        let pattern = #"https://podcasts\.apple\.com/[^"'\s]+"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let range = Range(match.range, in: html) {
            return String(html[range])
        }
        return nil
    }

    // MARK: - Overcast Resolution

    private func extractOvercastAppleID(from url: String) -> String? {
        // Format: https://overcast.fm/itunes1234567890
        if let range = url.range(of: "itunes") {
            let afterItunes = url[range.upperBound...]
            let id = afterItunes.prefix(while: { $0.isNumber })
            if !id.isEmpty {
                return String(id)
            }
        }
        return nil
    }

    // MARK: - Helpers

    private func isLikelyRSSFeed(_ url: String) -> Bool {
        let lowercased = url.lowercased()
        return lowercased.contains("/rss") ||
               lowercased.contains("/feed") ||
               lowercased.contains(".rss") ||
               lowercased.contains(".xml") ||
               lowercased.contains("format=rss") ||
               lowercased.contains("feed.") ||
               lowercased.contains("/atom")
    }
}

// MARK: - Models

struct PodcastSearchResult: Identifiable {
    let id: String
    let title: String
    let author: String?
    let artworkURL: String?
    let feedURL: String?
}

enum LookupError: LocalizedError {
    case invalidURL
    case feedNotFound
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .feedNotFound:
            return "Could not find RSS feed for this podcast"
        case .networkError(let message):
            return message
        }
    }
}

// MARK: - iTunes API Response Models

private struct iTunesSearchResponse: Codable {
    let resultCount: Int
    let results: [iTunesPodcast]
}

private struct iTunesLookupResponse: Codable {
    let resultCount: Int
    let results: [iTunesPodcast]
}

private struct iTunesPodcast: Codable {
    let collectionId: Int
    let collectionName: String
    let artistName: String?
    let artworkUrl100: String?
    let artworkUrl600: String?
    let feedUrl: String?
}
