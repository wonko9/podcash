import SwiftUI

struct EpisodeRowView: View {
    let episode: Episode

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Podcast artwork (always use podcast icon, not episode-specific)
            CachedAsyncImage(url: URL(string: episode.podcast?.artworkURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.2))
                    .overlay {
                        Image(systemName: "mic")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(episode.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundStyle(episode.isPlayed ? .secondary : .primary)

                // Metadata row
                HStack(spacing: 8) {
                    if let date = episode.publishedDate {
                        Text(date.relativeFormatted)
                    }

                    if let duration = episode.duration {
                        Text("•")
                        Text(duration.formattedDuration)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                // Progress indicator if partially played
                if episode.playbackPosition > 0 && !episode.isPlayed {
                    ProgressView(value: progressValue)
                        .tint(.accentColor)
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: 12) {
                // Star button
                Button {
                    episode.isStarred.toggle()
                    // Auto-download when starring
                    if episode.isStarred && episode.localFilePath == nil {
                        DownloadManager.shared.download(episode)
                    }
                } label: {
                    Image(systemName: episode.isStarred ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundStyle(episode.isStarred ? .yellow : .secondary)
                }
                .buttonStyle(.plain)

                // Download button
                if episode.localFilePath != nil {
                    Button {
                        DownloadManager.shared.deleteDownload(episode)
                    } label: {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                } else if let progress = episode.downloadProgress {
                    Button {
                        DownloadManager.shared.cancelDownload(episode)
                    } label: {
                        CircularProgressView(progress: progress)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        DownloadManager.shared.download(episode)
                    } label: {
                        Image(systemName: "arrow.down.circle")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .opacity(episode.isPlayed ? 0.7 : 1.0)
    }

    private var progressValue: Double {
        guard let duration = episode.duration, duration > 0 else { return 0 }
        return episode.playbackPosition / duration
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 2)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

#Preview {
    let episode = Episode(
        guid: "123",
        title: "Episode Title That Might Be Long",
        audioURL: "https://example.com/audio.mp3",
        episodeDescription: "Description",
        duration: 3600,
        publishedDate: Date()
    )
    return List {
        EpisodeRowView(episode: episode)
    }
}
