import SwiftUI

struct ContentView: View {
    private var playerManager = AudioPlayerManager.shared
    private var refreshManager = RefreshManager.shared
    @State private var showNowPlaying = false

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Global refresh status banner
                if refreshManager.isRefreshing {
                    RefreshStatusBanner()
                }

                TabView {
                LibraryView()
                    .tabItem {
                        Label("Library", systemImage: "books.vertical")
                    }

                DownloadsView()
                    .tabItem {
                        Label("Downloads", systemImage: "arrow.down.circle")
                    }

                StarredView()
                    .tabItem {
                        Label("Starred", systemImage: "star")
                    }

                QueueView()
                    .tabItem {
                        Label("Queue", systemImage: "list.bullet")
                    }

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }

            if playerManager.currentEpisode != nil {
                MiniPlayerView(showNowPlaying: $showNowPlaying)
                    .padding(.bottom, 49) // Standard tab bar height
            }
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView()
        }
    }
}

#Preview {
    ContentView()
}
