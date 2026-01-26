import SwiftUI
import SwiftData

struct AddPodcastView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Add Method", selection: $selectedTab) {
                    Text("Search").tag(0)
                    Text("URL").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if selectedTab == 0 {
                    SearchPodcastView(onAdd: addPodcast)
                } else {
                    URLPodcastView(onAdd: addPodcast)
                }
            }
            .navigationTitle("Add Podcast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func addPodcast(feedURL: String) async throws {
        // Check if already subscribed
        let descriptor = FetchDescriptor<Podcast>(
            predicate: #Predicate { $0.feedURL == feedURL }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            throw AddPodcastError.alreadySubscribed(existing.title)
        }

        // Fetch and save podcast
        let (podcast, episodes) = try await FeedService.shared.fetchPodcast(from: feedURL)

        modelContext.insert(podcast)
        for episode in episodes {
            episode.podcast = podcast
            modelContext.insert(episode)
        }
        podcast.episodes = episodes

        await MainActor.run {
            dismiss()
        }
    }
}

// MARK: - Search Tab

private struct SearchPodcastView: View {
    let onAdd: (String) async throws -> Void

    @State private var searchText = ""
    @State private var results: [PodcastSearchResult] = []
    @State private var isSearching = false
    @State private var isAdding = false
    @State private var errorMessage: String?
    @State private var addingID: String?

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if results.isEmpty && !isSearching && !searchText.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search term")
                )
            }

            ForEach(results) { result in
                SearchResultRow(
                    result: result,
                    isAdding: addingID == result.id,
                    onAdd: { await addResult(result) }
                )
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "Search podcasts")
        .onChange(of: searchText) { _, newValue in
            Task {
                await performSearch(query: newValue)
            }
        }
        .overlay {
            if isSearching && results.isEmpty {
                ProgressView("Searching...")
            }
        }
    }

    private func performSearch(query: String) async {
        guard !query.isEmpty else {
            results = []
            return
        }

        // Debounce
        try? await Task.sleep(for: .milliseconds(300))
        guard query == searchText else { return }

        isSearching = true
        errorMessage = nil

        do {
            results = try await PodcastLookupService.shared.searchPodcasts(query: query)
        } catch {
            errorMessage = error.localizedDescription
        }

        isSearching = false
    }

    private func addResult(_ result: PodcastSearchResult) async {
        guard let feedURL = result.feedURL else {
            errorMessage = "No RSS feed available for this podcast"
            return
        }

        addingID = result.id
        errorMessage = nil

        do {
            try await onAdd(feedURL)
        } catch let error as AddPodcastError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        addingID = nil
    }
}

private struct SearchResultRow: View {
    let result: PodcastSearchResult
    let isAdding: Bool
    let onAdd: () async -> Void

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: result.artworkURL ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure, .empty:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.2))
                        .overlay {
                            Image(systemName: "mic")
                                .foregroundStyle(.secondary)
                        }
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.headline)
                    .lineLimit(2)

                if let author = result.author {
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                Task { await onAdd() }
            } label: {
                if isAdding {
                    ProgressView()
                        .frame(width: 60)
                } else {
                    Text("Add")
                        .frame(width: 60)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAdding || result.feedURL == nil)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - URL Tab

private struct URLPodcastView: View {
    let onAdd: (String) async throws -> Void

    @State private var feedURL: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                TextField("Podcast URL", text: $feedURL)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            } footer: {
                Text("Supports RSS feeds, Apple Podcasts links, and Pocket Casts links.")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(action: addPodcast) {
                    HStack {
                        if isLoading {
                            ProgressView()
                            Text("Adding...")
                        } else {
                            Text("Add Podcast")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(feedURL.isEmpty || isLoading)
            }
        }
    }

    private func addPodcast() {
        var urlString = feedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://\(urlString)"
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                // Resolve URL to RSS feed
                let resolvedURL = try await PodcastLookupService.shared.resolveToRSSFeed(url: urlString)
                try await onAdd(resolvedURL)
            } catch let error as AddPodcastError {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Errors

enum AddPodcastError: LocalizedError {
    case alreadySubscribed(String)

    var errorDescription: String? {
        switch self {
        case .alreadySubscribed(let title):
            return "Already subscribed to \(title)"
        }
    }
}

#Preview {
    AddPodcastView()
        .modelContainer(for: Podcast.self, inMemory: true)
}
